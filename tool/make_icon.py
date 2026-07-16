#!/usr/bin/env python3
"""Regenerate assets/icon/icon.png (the neuron mark, all circles).

Needs Pillow. After editing, run `dart run flutter_launcher_icons` to refresh
the native launcher icons.
"""
from pathlib import Path

from PIL import Image, ImageDraw

S = 4  # supersample factor; drawn at 4096 and downscaled for crisp edges
YELLOW = "#FFD21E"
INK = "#1A1A22"

img = Image.new("RGB", (1024 * S, 1024 * S), YELLOW)
d = ImageDraw.Draw(img)

def px(*pts):
    return [(x * S, y * S) for x, y in pts]

def node(cx, cy, r):
    d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=INK)

stroke = 40 * S
d.line(px((512, 790), (512, 540)), fill=INK, width=stroke)  # stem
d.line(px((512, 540), (512, 270)), fill=INK, width=stroke)  # center branch
d.line(px((512, 540), (330, 390)), fill=INK, width=stroke)  # left branch
d.line(px((512, 540), (694, 390)), fill=INK, width=stroke)  # right branch
node(512, 540, 22)  # joint
node(512, 250, 58)  # top node
node(330, 390, 50)  # left node
node(694, 390, 50)  # right node
node(512, 790, 72)  # soma

out = Path(__file__).resolve().parent.parent / "assets" / "icon" / "icon.png"
img.resize((1024, 1024), Image.LANCZOS).save(out)
print(f"wrote {out}")
