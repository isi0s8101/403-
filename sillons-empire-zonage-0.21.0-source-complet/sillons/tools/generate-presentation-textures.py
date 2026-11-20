#!/usr/bin/env python3
"""Textures originales périodiques 512px. Dépendances de génération seulement : numpy, Pillow."""
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]/'game'/'textures'
N=512
rng=np.random.default_rng(1332026)
y,x=np.mgrid[0:N,0:N]/float(N)
def noise():
    out=np.zeros((N,N),float)
    for octave,amp in [(2,.42),(4,.24),(9,.14),(20,.08),(47,.045),(111,.025)]:
        for _ in range(5):
            a,b=rng.integers(-octave,octave+1,2)
            phase=rng.uniform(0,2*np.pi)
            out+=amp*np.sin(2*np.pi*(a*x+b*y)+phase)/5
    return out
n=noise(); micro=rng.normal(0,0.022,(N,N))
for name,base,rough in [('grass',[.32,.39,.21],.93),('soil',[.34,.27,.18],.96),('sand',[.60,.53,.39],.88),('rock',[.38,.39,.36],.89)]:
    field=noise(); height=field+micro
    rgb=np.array(base)[None,None,:]*(1+n[:,:,None]*.38+field[:,:,None]*.27)+micro[:,:,None]
    if name=='grass':
        fibers=np.sin(x*2*np.pi*135+field*14)*np.sin(y*2*np.pi*89+field*8)
        rgb+=fibers[:,:,None]*np.array([.012,.023,.006])
        height+=fibers*.025
    if name=='rock':
        cracks=np.exp(-np.abs(np.sin((x+y*.23)*2*np.pi*6+field*5))*23)
        rgb-=cracks[:,:,None]*.06
        height-=cracks*.09
    if name=='sand':
        rgb+=np.sin(y*2*np.pi*22+field*6)[:,:,None]*.014
    rgba=np.dstack([np.clip(rgb,0,1),np.clip(rough+field*.12,.65,1)])
    Image.fromarray(np.uint8(rgba*255),'RGBA').save(ROOT/(name+'_pbr.png'),optimize=True)
height=n*.25+micro*.2
nx=(np.roll(height,1,1)-np.roll(height,-1,1))*4
ny=(np.roll(height,1,0)-np.roll(height,-1,0))*4
normal=np.dstack([nx,ny,np.ones_like(nx)])
normal/=np.linalg.norm(normal,axis=2,keepdims=True)
Image.fromarray(np.uint8(np.clip(normal*.5+.5,0,1)*255),'RGB').save(ROOT/'terrain_normal.png',optimize=True)
detail=np.clip(.88+n*.14+micro*.35,0,1)
Image.fromarray(np.uint8(detail*255),'L').save(ROOT/'surface_detail.png',optimize=True)
print('PRESENTATION_TEXTURES=PASS files=6 resolution=512 seed=1332026')
