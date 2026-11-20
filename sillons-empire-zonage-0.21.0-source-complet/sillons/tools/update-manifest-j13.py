#!/usr/bin/env python3
"""Régénère game-studio/manifest-j13.sha256 : tous les fichiers du projet Godot suivis par git,
sauf le manifeste lui-même et les preuves non listées jusqu'ici (journaux produits après coup)."""
import hashlib, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
manifest = root / 'game-studio/manifest-j13.sha256'
previous = {line[66:].rstrip('\n') for line in manifest.read_text(encoding='utf-8').splitlines()} if manifest.is_file() else set()
tracked = subprocess.check_output(['git', 'ls-files', '-z', '.'], cwd=root).decode().split('\0')
keep = sorted(p for p in tracked if p and p != 'game-studio/manifest-j13.sha256' and (root / p).is_file()
              and (p in previous or not p.startswith('game-studio/preuves/')))
manifest.write_text(''.join('%s  %s\n' % (hashlib.sha256((root / p).read_bytes()).hexdigest(), p) for p in keep), encoding='utf-8')
print('manifeste J13 : %d fichiers' % len(keep))
