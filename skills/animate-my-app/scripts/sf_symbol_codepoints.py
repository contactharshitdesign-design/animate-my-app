"""Finds the SF Pro character for SF Symbol names by shape, so Figma (or any app) can draw the real symbol as text
in the "SF Pro" font. Usage: render the names first with sf_symbol_bitmap.swift <outDir>/want <names…>, then
python3 sf_symbol_codepoints.py <outDir>  →  <outDir>/codepoints.json. Needs /Library/Fonts/SF-Pro.ttf, numpy,
Pillow and fonttools (pip install --user fonttools). Check the result by eye: it draws nothing itself."""
import sys, os, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont
S = sys.argv[1]; N = 40
def norm(im):
    a = np.asarray(im.convert('L'), dtype=np.float32); ink = a < 128
    ys, xs = np.where(ink)
    if len(xs) == 0: return None
    crop = ink[ys.min():ys.max()+1, xs.min():xs.max()+1]; h, w = crop.shape; s = max(h, w)
    pad = np.zeros((s, s), dtype=np.uint8); pad[(s-h)//2:(s-h)//2+h, (s-w)//2:(s-w)//2+w] = crop * 255
    return (np.asarray(Image.fromarray(pad).resize((N, N), Image.BILINEAR), dtype=np.float32) / 255.0, w / h)
want = {fn[:-4]: norm(Image.open(f'{S}/want/{fn}')) for fn in sorted(os.listdir(S + '/want'))}
font = ImageFont.truetype('/Library/Fonts/SF-Pro.ttf', 96)
glyphs = []
for cp in (cp for cp in TTFont('/Library/Fonts/SF-Pro.ttf').getBestCmap() if cp >= 0x100000):
    im = Image.new('L', (200, 200), 255); ImageDraw.Draw(im).text((20, 20), chr(cp), font=font, fill=0)
    r = norm(im)
    if r: glyphs.append((cp, r[0], r[1]))
G = np.stack([g[1].ravel() for g in glyphs]); Ga = np.array([g[2] for g in glyphs])
out = {}
for name, r in want.items():
    if not r: continue
    d = ((G - r[0].ravel()) ** 2).mean(axis=1) + 0.05 * np.abs(np.log(Ga / r[1]))
    out[name] = glyphs[int(d.argmin())][0]
json.dump(out, open(S + '/codepoints.json', 'w'), indent=1); print(json.dumps(out))
