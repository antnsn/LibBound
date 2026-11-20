"""Painted emblems for the Bound addons, with Pillow only (no numpy).

Each addon's tools/make_media.py draws its shapes as masks (white on black, "L" images, at 4x
the final size) and paints them here: a fill that runs from a light to a dark colour, a bevel
from the shape's own height (light from the top left), a gloss on the lit edge, a glow around
it. The result reads like a painted icon instead of line art. Lightbound's paladin icon is the
bar to clear.

    from paint import Canvas, mask, rays, radial_disc
    cv = Canvas(1024)
    m = mask(1024); ImageDraw.Draw(m).ellipse(...)
    cv.glow(m, (120, 255, 80), radius=40, strength=0.8)
    cv.paint(m, top=(200, 255, 160), bottom=(30, 90, 20), bevel=14)
    cv.image(256)   # RGBA at the final size
"""
import math

from PIL import Image, ImageChops, ImageDraw, ImageFilter


def mask(s):
    return Image.new("L", (s, s), 0)


def _lut(fn):
    return [max(0, min(255, int(fn(v)))) for v in range(256)]


def _gradient(s, top, bottom, y0=0.0, y1=1.0):
    """Vertical gradient from top to bottom colour between y0 and y1 (fractions of s)."""
    g = Image.new("RGB", (1, s))
    for y in range(s):
        t = min(1.0, max(0.0, (y / s - y0) / max(1e-6, y1 - y0)))
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g.resize((s, s))


def _bbox_y(m):
    box = m.getbbox()
    if not box:
        return 0.0, 1.0
    return box[1] / m.size[1], box[3] / m.size[1]


class Canvas:
    def __init__(self, s):
        self.s = s
        self.img = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    def _put(self, rgb, alpha):
        layer = Image.merge("RGBA", (*rgb.split(), alpha))
        self.img = Image.alpha_composite(self.img, layer)

    def glow(self, m, colour, radius, strength=1.0):
        """A soft light around (and behind) the shape."""
        a = m.filter(ImageFilter.GaussianBlur(radius)).point(_lut(lambda v: v * strength))
        self._put(Image.new("RGB", (self.s, self.s), colour), a)

    def shadow(self, m, radius=12, dx=6, dy=10, strength=0.7):
        """A drop shadow below the shape, so it sits above what is behind it."""
        a = m.filter(ImageFilter.GaussianBlur(radius)).point(_lut(lambda v: v * strength))
        a = ImageChops.offset(a, dx, dy)
        self._put(Image.new("RGB", (self.s, self.s), (0, 0, 0)), a)

    def paint(self, m, top, bottom, bevel=10, light=0.9, dark=0.75, gloss=0.6, rim=None, alpha=1.0):
        """Fill the mask with a top-to-bottom gradient (over the shape's own height), then light it:
        the edge facing the top left catches light, the one facing the bottom right falls into
        shadow, a gloss sits on the brightest part. rim: an optional thin outline colour."""
        s = self.s
        y0, y1 = _bbox_y(m)
        fill = _gradient(s, top, bottom, y0, y1)
        if bevel:
            h = m.filter(ImageFilter.GaussianBlur(bevel))
            d = max(1, int(bevel * 0.5))
            a = ImageChops.offset(h, d, d)       # height seen from the top left
            b = ImageChops.offset(h, -d, -d)
            shade = ImageChops.subtract(a, b, scale=1.0, offset=128)
            lit = shade.point(_lut(lambda v: (v - 128) * 2 * light))
            dim = shade.point(_lut(lambda v: (128 - v) * 2 * dark))
            fill = Image.composite(Image.new("RGB", (s, s), (255, 255, 255)), fill, lit)
            fill = Image.composite(Image.new("RGB", (s, s), (0, 0, 0)), fill, dim)
            if gloss:
                g = shade.point(_lut(lambda v: (v - 160) * 4 * gloss))
                fill = Image.composite(Image.new("RGB", (s, s), (255, 255, 255)), fill, g)
        if rim:
            edge = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(5)))
            fill = Image.composite(Image.new("RGB", (s, s), rim), fill, edge)
        self._put(fill, m.point(_lut(lambda v: v * alpha)))

    def light(self, m, colour, alpha=1.0):
        """Add light (screen-like): for rays, sparks and cores that should glow, not sit on top."""
        layer = Image.new("RGB", (self.s, self.s), colour)
        a = m.point(_lut(lambda v: v * alpha))
        base = self.img.convert("RGB")
        added = ImageChops.add(base, Image.composite(layer, Image.new("RGB", (self.s, self.s)), a))
        keep = self.img.getchannel("A")
        out = Image.merge("RGBA", (*added.split(), ImageChops.lighter(keep, a)))
        self.img = out

    def cut(self, m):
        """Erase the canvas where the mask is white (gaps between overlapping parts)."""
        a = ImageChops.subtract(self.img.getchannel("A"), m)
        self.img.putalpha(a)

    def image(self, size):
        return self.img.resize((size, size), Image.LANCZOS)


def rays(s, n, inner, outer, width, cx=None, cy=None, long_every=2, short=0.7):
    """A burst of n tapered rays from inner to outer (fractions of s); every other one shorter."""
    import math
    cx = s / 2 if cx is None else cx
    cy = s / 2 if cy is None else cy
    m = mask(s)
    d = ImageDraw.Draw(m)
    for k in range(n):
        a = k * 2 * math.pi / n
        r1 = outer if k % long_every == 0 else inner + (outer - inner) * short
        w = width * (1 if k % long_every == 0 else 0.7)
        p0 = (cx + math.cos(a - w) * s * inner, cy + math.sin(a - w) * s * inner)
        p1 = (cx + math.cos(a) * s * r1, cy + math.sin(a) * s * r1)
        p2 = (cx + math.cos(a + w) * s * inner, cy + math.sin(a + w) * s * inner)
        d.polygon([p0, p1, p2], fill=255)
    return m.filter(ImageFilter.GaussianBlur(s * 0.004))


def ring(s, r_out, r_in, cx=None, cy=None):
    m = mask(s)
    d = ImageDraw.Draw(m)
    cx = s / 2 if cx is None else cx
    cy = s / 2 if cy is None else cy
    d.ellipse([cx - s * r_out, cy - s * r_out, cx + s * r_out, cy + s * r_out], fill=255)
    d.ellipse([cx - s * r_in, cy - s * r_in, cx + s * r_in, cy + s * r_in], fill=0)
    return m


def disc(s, r, cx=None, cy=None):
    m = mask(s)
    cx = s / 2 if cx is None else cx
    cy = s / 2 if cy is None else cy
    ImageDraw.Draw(m).ellipse([cx - s * r, cy - s * r, cx + s * r, cy + s * r], fill=255)
    return m


def radial_disc(cv, r, inner, outer):
    """A disc filled from inner colour (middle) to outer colour (edge): the emblem's ground."""
    import math
    s = cv.s
    steps = 48
    for k in range(steps):
        t = k / (steps - 1)
        rr = r * (1 - t)
        col = tuple(int(outer[i] + (inner[i] - outer[i]) * t) for i in range(3))
        m = disc(s, rr)
        cv._put(Image.new("RGB", (s, s), col), m)
    return disc(s, r)


def poly(s, points, blur=0.0):
    m = mask(s)
    ImageDraw.Draw(m).polygon([(x * s, y * s) for x, y in points], fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur * s)) if blur else m


def union(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = ImageChops.lighter(out, m)
    return out


def minus(a, b):
    return ImageChops.subtract(a, b)


def shrink(m, px):
    return m.filter(ImageFilter.MinFilter(px * 2 + 1))


def grow(m, px):
    return m.filter(ImageFilter.MaxFilter(px * 2 + 1))


def lick(s, cx, base, height, width, lean=0.0, wiggle=0.0):
    """One tongue of flame (fractions of s): a round foot at base, sides that taper to a pointed
    tip `height` above it, leaning by `lean` with an S-wiggle. Union several for a fire."""
    import math
    left, right = [], []
    n = 40
    for k in range(n + 1):
        t = k / n
        hw = width * (1 - t) ** 1.5 * (1 + 1.2 * t) * (1 - 0.25 * (1 - t) ** 6)
        x = cx + lean * t * t + wiggle * math.sin(t * math.pi * 1.5)
        y = base - height * t
        left.append((x - hw, y)); right.append((x + hw, y))
    foot = [(cx + math.cos(a) * width, base + math.sin(a) * width * 1.0)
            for a in [math.pi * k / 16 for k in range(17)]]
    # the foot runs from the right side (angle 0) round the bottom to the left (angle pi)
    pts = right[::-1] + foot + left
    return poly(s, pts)


def sparkle(s, x, y, r):
    """A four-pointed glint."""
    w = r * 0.18
    return union(poly(s, [(x - r, y), (x, y - w), (x + r, y), (x, y + w)]),
                 poly(s, [(x, y - r), (x + w, y), (x, y + r), (x - w, y)]))


def leaf(s, x0, y0, angle, length, width, bend=0.0):
    """An elongated leaf/feather from (x0, y0) along angle (radians, 0 = right, y down)."""
    ca, sa = math.cos(angle), math.sin(angle)
    left, right = [], []
    for k in range(31):
        t = k / 30
        hw = width * math.sin(math.pi * t) ** 0.7 * (1 - 0.3 * t)
        off = bend * math.sin(math.pi * t)
        ax, ay = x0 + ca * length * t - sa * off, y0 + sa * length * t + ca * off
        left.append((ax - sa * hw, ay + ca * hw)); right.append((ax + sa * hw, ay - ca * hw))
    return poly(s, left + right[::-1])


def bar(s, x0, y0, x1, y1, w):
    a = math.atan2(y1 - y0, x1 - x0)
    nx, ny = -math.sin(a) * w, math.cos(a) * w
    return poly(s, [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)])

