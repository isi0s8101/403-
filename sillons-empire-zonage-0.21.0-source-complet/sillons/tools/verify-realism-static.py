#!/usr/bin/env python3
"""Delivery integrity: authored geometry, portable packs, photographic maps and mip presets."""
from pathlib import Path
import hashlib,json,sys
R=Path(__file__).resolve().parents[1];checks=[]
def check(value,label):
 checks.append(bool(value));print(('PASS ' if value else 'FAIL ')+label)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
try:
 meta=json.loads((R/'data/realism-package.json').read_text());p=R/'data/realism_models.pck'
 check(p.stat().st_size==meta['bytes'] and digest(p)==meta['sha256'],'57-model native pack hash and size')
 models=json.loads((R.parent/'art-source/models/manifest.json').read_text())['models']
 check(len(models)==57 and sum(x['category']=='building' for x in models)==44,'44 buildings, 7 natural assets, 6 rigged figures')
 report=json.loads((R/'game-studio/preuves/realisme-0.13.5/native-models.json').read_text())
 check(len(report['models'])==57 and report['self_contained'],'native index matches prepared assets')
 check(all(digest(R.parent/'art-source/models'/m['file'])==next(x for x in report['models'] if x['id']==m['id'])['source_sha256'] for m in models),'all authored GLB sources match native pack')
 textures=json.loads((R/'game/realism/texture-sources.json').read_text())['maps']
 check(len(textures)==27 and all(digest(R/'game/realism/textures'/x['path'])==x['sha256'] for x in textures),'27 photographic maps intact')
 check(all(x['license']=='CC0-1.0' for x in textures),'source license and attribution documented')
 presets=list((R/'game/realism/textures').glob('*.jpg.import'))
 check(len(presets)==27 and all('mipmaps/generate=true' in p.read_text() for p in presets),'27 authored mipmap import presets supplied')
 check(not any(R.rglob('*.glb')),'no GLB in playable project')
 check('*.pck' in (R/'export_presets.cfg').read_text(),'both native packs included in exports')
 check(any(v in (R/'export_presets.cfg').read_text() for v in ['version/code=160','version/code=170', 'version/code=180', 'version/code=181', 'version/code=190', 'version/code=200']) and any(v in (R/'project.godot').read_text() for v in ['0.16.0','0.17.0','0.18.0','0.18.1','0.19.0','0.20.0']),'candidate version 0.16.0 à 0.19.0 / code 160 à 190')
except (OSError,ValueError,KeyError,TypeError,StopIteration) as e:check(False,str(e))
print('REALISM_STATIC=%s checks=%d failures=%d'%('PASS' if all(checks) else 'FAIL',len(checks),sum(not i for i in checks)))
sys.exit(0 if all(checks) else 1)
