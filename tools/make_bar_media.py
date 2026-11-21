"""Makes an addon's resource bar textures (LibBound's PowerBar) from Marius' layered bar art.

    python3 LibBound/tools/make_bar_media.py SRC_DIR ADDON/Media [--prefix RageBar] [--overlay FILE]

SRC_DIR holds the layers, each on the same canvas (1024x128): rage-bar-empty.png (frame and dark
inside), rage-bar-fill.png (the fill at 100%, alone), rage-bar-frame.png (the frame, open inside),
rage-bar-full.png (the glow at full), rage-bar-spark.png (the line at the fill's end, 64x128).
--overlay adds one more layer on top (Dreambound's bear-claws.png) as <prefix>Overlay.

Writes <prefix>Back, Frame, Full, Spark (and Overlay) as TGA at the canvas size, and <prefix>Fill
cut to the fill's own box and stretched to 1024x64 (a status bar texture fills the bar's inside;
the game crops it to the current value). Prints the fill box: PowerBar's default `fill` is it.
"""
import argparse
import os
from PIL import Image


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("media")
    ap.add_argument("--prefix", default="RageBar")
    ap.add_argument("--overlay")
    a = ap.parse_args()

    def load(name):
        return Image.open(os.path.join(a.src, name)).convert("RGBA")

    def save(img, name):
        path = os.path.join(a.media, a.prefix + name + ".tga")
        img.save(path)
        print("wrote", path, img.size)

    fill = load("rage-bar-fill.png")
    box = fill.getchannel("A").getbbox()
    save(load("rage-bar-empty.png"), "Back")
    save(load("rage-bar-frame.png"), "Frame")
    save(load("rage-bar-full.png"), "Full")
    save(load("rage-bar-spark.png"), "Spark")
    save(fill.crop(box).resize((1024, 64), Image.LANCZOS), "Fill")
    if a.overlay:
        save(Image.open(a.overlay).convert("RGBA"), "Overlay")
    print("fill box (left, top, right, bottom) on a %dx%d canvas:" % fill.size, box)


if __name__ == "__main__":
    main()
