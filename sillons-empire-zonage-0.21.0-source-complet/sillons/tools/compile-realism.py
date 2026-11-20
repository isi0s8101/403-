#!/usr/bin/env python3
"""Rebuild the native realism pack on a development computer, never on Android."""
from pathlib import Path, PurePosixPath
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--godot',default=os.environ.get('GODOT_BIN','godot'))
 parser.add_argument('--replace',action='store_true')
 parser.add_argument('--output',type=Path,default=ROOT/'data/realism_models.pck')
 args=parser.parse_args()
 binary=shutil.which(args.godot)
 if not binary:parser.error('Godot 4.7.2 required.')
 source=ROOT.parent/'art-source/models';output=args.output.absolute()
 if output.is_symlink():parser.error('Symbolic output rejected.')
 output.parent.mkdir(parents=True,exist_ok=True)
 if output.exists() and not args.replace:parser.error('Pack already supplied; use --replace only after editing geometry.')
 manifest=json.loads((source/'manifest.json').read_text())
 if len(manifest['models'])!=57:parser.error('57 authored models expected.')
 with tempfile.TemporaryDirectory(prefix='sillons-realism-') as temporary:
  stage=Path(temporary);project=stage/'project';(project/'models').mkdir(parents=True)
  (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Realism build"\n[animation]\ncompatibility/default_parent_skeleton_in_mesh_instance_3d=true\n[rendering]\nrenderer/rendering_method="mobile"\n')
  shutil.copyfile(source/'manifest.json',project/'models/manifest.json')
  for item in manifest['models']:
   name=item['file'];p=PurePosixPath(name)
   if not re.fullmatch('[a-z][a-z0-9_]+',item['id']):raise ValueError('Invalid model identity')
   if p.is_absolute() or '..' in p.parts or '\\' in name or ':' in name or len(p.parts)!=1:raise ValueError('Invalid source name')
   shutil.copyfile(source/name,project/'models'/name)
  shutil.copyfile(ROOT/'tools/prepare-realism.gd',project/'prepare.gd')
  packed=stage/'realism.pck'
  commands=[['--editor','--quit'],['--script','res://prepare.gd','--',str(stage/'native'),str(packed)]]
  for index,command in enumerate(commands,1):
   result=subprocess.run([binary,'--headless','--path',str(project)]+command,capture_output=True,text=True,timeout=600)
   log=result.stdout+result.stderr;(output.parent/('realism-build-step-%d.log'%index)).write_text(log)
   if result.returncode or any(x in log for x in ['SCRIPT ERROR','Parse Error','Compile Error','\nERROR:']):raise RuntimeError('Build failed at step %d; previous pack preserved'%index)
  if output.exists():shutil.copyfile(output,output.with_name(output.name+'.'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'.bak'))
  os.replace(packed,output)
  metadata={'schema':1,'file':output.name,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'bytes':output.stat().st_size,'models':57,'source':'art-source/models/manifest.json'}
  temp=output.parent/'realism-package.json.tmp';temp.write_text(json.dumps(metadata,indent=2)+'\n');os.replace(temp,output.parent/'realism-package.json')
  print('REALISM_BUILD=PASS',output)
if __name__=='__main__':main()
