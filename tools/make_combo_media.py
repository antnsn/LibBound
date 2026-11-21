"""Makes an addon's combo point textures from a painted pip (TGA, 64x64, for LibBound's ComboBar).

    python3 LibBound/tools/make_combo_media.py ART.png ADDON/Media

ComboPoint.tga: the art trimmed to its painted part and centred on a square (the game greys it for
an empty point). ComboGlow.tga: the pip's outline grown and blurred, white on alpha (the game tints
it and adds it behind a lit pip; the pip fills 3/5 of it).
"""
import os
import sys
from PIL import Image, ImageFilter


def combo_point(art, size=64):
    img = Image.open(art).convert("RGBA")
    img = img.crop(img.getchannel("A").getbbox())
    w, h = img.size
    side = max(w, h)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(img, ((side - w) // 2, (side - h) // 2))
    return sq.resize((size, size), Image.LANCZOS)


def combo_glow(art, size=64):
    shape = combo_point(art, size).getchannel("A")
    small = shape.resize((size * 3 // 5, size * 3 // 5), Image.LANCZOS)  # room round the edge to glow into
    a = Image.new("L", (size, size), 0)
    a.paste(small, ((size - small.width) // 2, (size - small.height) // 2))
    a = a.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(5))
    a = a.point(lambda v: min(255, int(v * 1.6)))
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(a)
    return out


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    art, media = sys.argv[1], sys.argv[2]
    for name, img in (("ComboPoint", combo_point(art)), ("ComboGlow", combo_glow(art))):
        path = os.path.join(media, name + ".tga")
        img.save(path)
        print("wrote", path, img.size)
