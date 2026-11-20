#!/usr/bin/env python3
"""0.17 — Assemble la planche des 10 âges (captures réelles) avec les contrastes mesurés par lab/ui_theme_test.gd.
Usage : python3 -I tools/assemble-planche-017.py <dossier-captures> <contrastes.json> <sortie.png>"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

folder, table_path, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
table = json.loads(table_path.read_text(encoding='utf-8'))
roman = ['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X']
W, H = 800, 370
font_path = Path(__file__).resolve().parents[1] / 'interface/fonts/FiraSans-SemiBold.ttf'
font = ImageFont.truetype(str(font_path), 26)
small = ImageFont.truetype(str(font_path), 20)
sheet = Image.new('RGB', (W * 2 + 30, (H + 60) * 10 + 20), (12, 14, 18))
d = ImageDraw.Draw(sheet)
for age in range(1, 11):
    y = 10 + (age - 1) * (H + 60)
    info = table.get(str(age), {})
    d.text((14, y + 8), 'Âge %s — %s' % (roman[age], info.get('nom', '')), fill=(240, 240, 240), font=font)
    d.text((620, y + 12), 'contraste texte min %.2f:1 · éléments graphiques min %.2f:1' % (info.get('texte_min', 0), info.get('icones_min', 0)), fill=(170, 200, 210), font=small)
    for col, mode in enumerate(('planche', 'planche_civ')):
        path = folder / ('%s-%02d.png' % (mode, age))
        x0 = 10 + col * (W + 10)
        if path.is_file():
            img = Image.open(path).convert('RGB').resize((W, H), Image.LANCZOS)
            sheet.paste(img, (x0, y + 48))
        else:
            # Capture absente : cadre vide annoncé honnêtement (contrastes toujours mesurés par la recette).
            d.rectangle((x0, y + 48, x0 + W - 1, y + 48 + H - 1), outline=(90, 96, 104), width=2)
            d.text((x0 + 24, y + 48 + H // 2 - 14), 'capture non réalisée (NOT_RUN)', fill=(150, 156, 164), font=small)
sheet.save(out, optimize=True)
print('PLANCHE=PASS', out, sheet.size)
