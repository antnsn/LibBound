#!/usr/bin/env python3
"""Cut a Bound addon's frames out of the screenshots "/<addon> shots" took (LibBound's Shots.lua).

The shots command saves, per skin, which screenshot shows what and where each frame sat
(fractions of the screen) in the addon's own saved variables (db.shots). After a /reload this
script finds those screenshots by their time stamp and writes the crops:

  the addon's own skin -> <out>/<name>.png             (the docs' own screenshots)
  other skins          -> <out>/skins/<skin>/<name>.png
  frames in the unlocked shot -> .../frames/<frame>.png next to them
  the CurseForge gallery -> <addon>/docs/curseforge/1_<name>.png, 2_..., in upload order, each
                            under 2 MB (a bigger one becomes a JPEG); --no-gallery skips it

Chat windows (other players' names and messages) are pixelated first.

Usage: crop_shots.py ADDON [--out DIR] [--sv FILE] [--screens DIR] [--skin NAME] [--dry-run]
  (from Interface/AddOns: python3 LibBound/tools/crop_shots.py Spiritbound)
"""
import argparse
import datetime
import glob
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))  # _forever_
PAD = 4  # pixels around each crop
HIDE_PAD = 10  # pixels around each pixelated chat window
BLOCK = 14  # size of a pixelation block
FULL_WIDTH = 1920  # a whole-screen shot is saved at most this wide (a 3440 px screen is 6 MB)
MATCH_SECONDS = 3  # a shot's file may be stamped a moment after /bk shots noted the time


# Lua table reader for WoW saved variables: only what the client writes
# (strings, numbers, booleans, nil, nested tables with ["key"] = or [n] = or bare values).
class LuaReader:
    TOKEN = re.compile(r'\s*(?:--[^\n]*\n?\s*)*'
                       r'("(?:[^"\\]|\\[\s\S])*"|\[|\]|\{|\}|=|,|;|-?[\d.]+(?:[eE][-+]?\d+)?|[A-Za-z_]\w*)')

    def __init__(self, text):
        self.text, self.pos = text, 0

    def peek(self):
        m = self.TOKEN.match(self.text, self.pos)
        return m.group(1) if m else None

    def next(self):
        m = self.TOKEN.match(self.text, self.pos)
        if not m:
            raise ValueError("unexpected input at %d" % self.pos)
        self.pos = m.end()
        return m.group(1)

    def value(self):
        t = self.next()
        if t == "{":
            return self.table()
        if t.startswith('"'):
            return self.unescape(t[1:-1])
        if t in ("true", "false"):
            return t == "true"
        if t == "nil":
            return None
        return float(t) if any(c in t for c in ".eE") else int(t)

    @staticmethod
    def unescape(s):
        def rep(m):
            c = m.group(1)
            if c.isdigit():
                return chr(int(c))
            return {"n": "\n", "t": "\t", "r": "\r", "\n": "\n"}.get(c, c)
        return re.sub(r'\\(\d{1,3}|.)', rep, s, flags=re.S)

    def table(self):
        out, n = {}, 1
        while self.peek() != "}":
            if self.peek() == "[":
                self.next()
                key = self.value()
                self.next()  # ]
                self.next()  # =
                out[key] = self.value()
            else:
                out[n] = self.value()
                n += 1
            if self.peek() in (",", ";"):
                self.next()
        self.next()  # }
        return out

    def assignments(self):
        out = {}
        while self.peek() is not None:
            name = self.next()
            self.next()  # =
            out[name] = self.value()
        return out


def as_list(t):
    return [t[i] for i in sorted(k for k in t if isinstance(k, int))] if isinstance(t, dict) else []


def addon_info(addon):
    """The addon's saved-variables name (from its .toc) and its own skin (Core.lua's defaults)."""
    folder = os.path.join(GAME, "Interface", "AddOns", addon)
    toc = open(os.path.join(folder, addon + ".toc"), encoding="utf-8", errors="replace").read()
    m = re.search(r"^## SavedVariables:\s*(\w+)", toc, re.M)
    if not m:
        sys.exit("%s.toc has no SavedVariables line." % addon)
    core = open(os.path.join(folder, "Core.lua"), encoding="utf-8", errors="replace").read()
    skin = re.search(r'\bskin\s*=\s*"(\w+)"', core)
    return m.group(1), (skin.group(1) if skin else None), folder


def find_sv(addon):
    files = glob.glob(os.path.join(GAME, "WTF", "Account", "*", "SavedVariables", addon + ".lua"))
    files += glob.glob(os.path.join(GAME, "WTF", "Account", "*", "*", "*", "SavedVariables", addon + ".lua"))
    with_shots = [f for f in files if '["shots"]' in open(f, encoding="utf-8", errors="replace").read()]
    if not with_shots:
        sys.exit("no %s saved variables with screenshots yet: run its shots command, then /reload." % addon)
    return max(with_shots, key=os.path.getmtime)


def stamp(s):
    return datetime.datetime.strptime(s, "%m%d%y_%H%M%S")


def screenshots(folder):
    out = []
    for f in glob.glob(os.path.join(folder, "WoWScrnShot_*.png")):
        m = re.search(r"WoWScrnShot_(\d{6}_\d{6})", os.path.basename(f))
        if m:
            out.append((stamp(m.group(1)), f))
    return out


def pixelate(img, rects):
    """Blur other players' chat out of the screenshot: coarse blocks over each rect."""
    W, H = img.size
    for r in rects:
        box = (max(0, round(r["x"] * W) - HIDE_PAD), max(0, round(r["y"] * H) - HIDE_PAD),
               min(W, round((r["x"] + r["w"]) * W) + HIDE_PAD), min(H, round((r["y"] + r["h"]) * H) + HIDE_PAD))
        if box[2] <= box[0] or box[3] <= box[1]:
            continue
        part = img.crop(box)
        small = part.resize((max(1, part.width // BLOCK), max(1, part.height // BLOCK)), Image.BILINEAR)
        img.paste(small.resize(part.size, Image.NEAREST), box)
    return img


def shrink(img):
    if img.width <= FULL_WIDTH:
        return img
    return img.resize((FULL_WIDTH, round(img.height * FULL_WIDTH / img.width)), Image.LANCZOS)


def crop(img, r):
    W, H = img.size
    box = (max(0, round(r["x"] * W) - PAD), max(0, round(r["y"] * H) - PAD),
           min(W, round((r["x"] + r["w"]) * W) + PAD), min(H, round((r["y"] + r["h"]) * H) + PAD))
    return img.crop(box)


GALLERY_LIMIT = 2 * 1024 * 1024  # CurseForge takes images up to 2 MB
IMAGE_REF = re.compile(r"screenshots/([\w./-]+?\.png)")


def doc_images(text):
    """The screenshots a docs page shows, relative to docs/screenshots, in page order."""
    return IMAGE_REF.findall(text)


def gallery_order(shots, docs):
    """The CurseForge gallery: the unlocked frames first, then each shot in the order it was taken,
    each options page followed by the single frames the docs show next to it. Frames no docs page
    shows are left out. shots: the shot names; docs: {page: [image, ...]} (doc_images)."""
    order = ["frames-unlocked"] + [s for s in shots if s != "frames-unlocked"] if "frames-unlocked" in shots else list(shots)
    out = []
    for name in order:
        img = name + ".png"
        if img in out:
            continue
        out.append(img)
        if name.startswith("options-"):
            for page in sorted(docs):
                if img in docs[page]:
                    for r in docs[page]:  # its frames, and a whole shot shown with it (travel)
                        if r not in out and (r.startswith("frames/") or
                                             (r[:-4] in shots and not r.startswith("options-"))):
                            out.append(r)
    return out


def write_gallery(src, images, out, limit=GALLERY_LIMIT):
    """Copy images (relative to src) into out as 1_name, 2_name, ...; one over the limit becomes a JPEG
    small enough. Clears out first. Returns the file names written."""
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        os.remove(os.path.join(out, f))
    names = []
    for i, rel in enumerate(images, 1):
        path = os.path.join(src, rel)
        if not os.path.exists(path):
            continue
        base = "%d_%s" % (i, os.path.basename(rel))
        if os.path.getsize(path) <= limit:
            Image.open(path).save(os.path.join(out, base), optimize=True)
        else:
            base = base[:-4] + ".jpg"
            img = Image.open(path).convert("RGB")
            while True:  # lower the quality, then the size, until it fits
                for q in (92, 85, 75, 60, 45):
                    img.save(os.path.join(out, base), quality=q, optimize=True)
                    if os.path.getsize(os.path.join(out, base)) <= limit:
                        break
                if os.path.getsize(os.path.join(out, base)) <= limit:
                    break
                img = img.resize((round(img.width * 0.8), round(img.height * 0.8)), Image.LANCZOS)
        names.append(base)
    return names


def gallery(folder, shots):
    """docs/curseforge from docs/screenshots: numbered in upload order, each under 2 MB."""
    docs_dir = os.path.join(folder, "docs")
    docs = {}
    for root, _, files in os.walk(docs_dir):
        for f in files:
            if f.endswith(".md"):
                docs[os.path.relpath(os.path.join(root, f), docs_dir)] = doc_images(
                    open(os.path.join(root, f), encoding="utf-8", errors="replace").read())
    out = os.path.join(docs_dir, "curseforge")
    names = write_gallery(os.path.join(docs_dir, "screenshots"), gallery_order(shots, docs), out)
    print("CurseForge gallery -> %s (%d files)" % (out, len(names)))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("addon", help="the addon's folder name, e.g. Spiritbound")
    ap.add_argument("--out", help="where to write (default: <addon>/docs/screenshots)")
    ap.add_argument("--sv", help="the addon's saved variables file (default: the newest one with screenshots)")
    ap.add_argument("--screens", default=os.path.join(GAME, "Screenshots"))
    ap.add_argument("--skin", help="only this skin")
    ap.add_argument("--dry-run", action="store_true", help="show what would be written")
    ap.add_argument("--no-gallery", action="store_true", help="don't rebuild docs/curseforge")
    a = ap.parse_args()

    db_name, own_skin, folder = addon_info(a.addon)
    a.out_given = bool(a.out)
    a.out = a.out or os.path.join(folder, "docs", "screenshots")
    sv = a.sv or find_sv(a.addon)
    data = LuaReader(open(sv, encoding="utf-8", errors="replace").read()).assignments()
    runs = (data.get(db_name) or {}).get("shots") or {}
    files = screenshots(a.screens)
    used, missing = set(), 0
    for skin, run in sorted(runs.items()):
        if a.skin and skin != a.skin:
            continue
        base = a.out if skin == own_skin else os.path.join(a.out, "skins", skin)
        print("%s (taken %s) -> %s" % (skin, run.get("at", "?"), base))
        for shot in as_list(run.get("list")):
            at = stamp(shot["at"])
            near = [(abs((t - at).total_seconds()), f) for t, f in files
                    if f not in used and -1 <= (t - at).total_seconds() <= MATCH_SECONDS]
            if not near:
                print("  %-28s no screenshot near %s" % (shot["name"], at))
                missing += 1
                continue
            f = min(near)[1]
            used.add(f)
            rects = shot.get("rects") or {}
            writes = []
            if rects.get("main") or shot.get("full"):
                writes.append((os.path.join(base, shot["name"] + ".png"), rects.get("main")))
            else:
                print("  %-28s the frame wasn't shown, skipped" % shot["name"])
            writes += [(os.path.join(base, "frames", k.lower() + ".png"), r)
                       for k, r in sorted(rects.items()) if k != "main"]
            if a.dry_run:
                for path, _ in writes:
                    print("  %-28s %s -> %s" % (shot["name"], os.path.basename(f), os.path.relpath(path, a.out)))
                continue
            img = pixelate(Image.open(f).convert("RGB"), as_list(shot.get("hide")))
            for path, r in writes:
                os.makedirs(os.path.dirname(path), exist_ok=True)
                out = crop(img, r) if r else shrink(img)
                out.save(path, optimize=True)
            print("  %-28s %d file(s)" % (shot["name"], len(writes)))
    own = runs.get(own_skin)
    if own and not a.dry_run and not a.no_gallery and not a.out_given and (not a.skin or a.skin == own_skin):
        gallery(folder, [shot["name"] for shot in as_list(own.get("list"))])
    if missing:
        sys.exit("%d screenshot(s) not found in %s" % (missing, a.screens))


if __name__ == "__main__":
    main()
