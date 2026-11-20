#!/usr/bin/env python3
"""Regenerate original, tileable mobile terrain maps (J2.1-C).

Build-time only: Python 3, NumPy, SciPy, Pillow. The Godot project uses the
pre-generated PNGs directly and needs no Python dependencies at runtime.
"""
from pathlib import Path
import numpy as np
from scipy.ndimage import gaussian_filter
from PIL import Image

SIDE = 512
OUT = Path(__file__).resolve().parent.parent / 'game' / 'textures'
OUT.mkdir(parents=True, exist_ok=True)

def noise(rng, sigma):
    x = rng.normal(size=(SIDE, SIDE)).astype(np.float32)
    x = gaussian_filter(x, sigma, mode='wrap')
    x -= x.mean()
    x /= max(float(x.std()), 0.00001)
    return x


def save(name, rgb, roughness):
    a = np.zeros((SIDE, SIDE, 4), dtype=np.uint8)
    a[:, :, :3] = np.uint8(np.clip(rgb, 0., 1.) * 255.)
    a[:, :, 3] = np.uint8(np.clip(roughness, 0., 1.) * 255.)
    Image.fromarray(a, 'RGBA').save(OUT / name, optimize=True)


def material(name, seed, low, high, base_rough, vein=0.):
    rng = np.random.default_rng(seed)
    c = noise(rng, 24.) * .38 + noise(rng, 9.) * .3 + noise(rng, 2.) * .22 + noise(rng, .65) * .10
    c = np.clip(.5 + .22 * c, .08, .92)
    lo = np.array(low, dtype=np.float32)
    hi = np.array(high, dtype=np.float32)
    rgb = lo + c[..., None] * (hi - lo)
    fine = noise(rng, 1.3)
    rgb += (fine * .019)[..., None]
    if vein:
        fractures = np.exp(-np.abs(noise(rng, 7.) + noise(rng, 1.5) * .1) * 8.)
        rgb -= vein * fractures[..., None]
    rough = base_rough + np.clip(noise(rng, 4.), -1.5, 1.5) * .025
    save(name, rgb, rough)

material('grass_pbr.png', 201, (.105,.18,.07), (.38,.44,.18), .92)
material('soil_pbr.png', 202, (.18,.115,.065), (.47,.31,.17), .95)
material('sand_pbr.png', 203, (.35,.30,.21), (.68,.59,.40), .87)
material('rock_pbr.png', 204, (.19,.20,.20), (.52,.51,.45), .81, .075)

rng = np.random.default_rng(205)
h = noise(rng, 16.) * .22 + noise(rng, 4.) * .30 + noise(rng, 1.0) * .48
# Godot NORMAL_MAP: tangent +X, +Y, +Z encoded [0,1].
dy, dx = np.gradient(h)
vec = np.stack((-dx * 1.6, -dy * 1.6, np.ones_like(h)), axis=2)
vec /= np.maximum(np.linalg.norm(vec, axis=2, keepdims=True), .0001)
norm = np.zeros((SIDE, SIDE, 4), dtype=np.uint8)
norm[:, :, :3] = np.uint8(np.clip((vec + 1) * .5, 0, 1) * 255)
norm[:, :, 3] = 255
Image.fromarray(norm, 'RGBA').save(OUT / 'terrain_normal.png', optimize=True)
print('Generated five original seamless J2.1-C textures in', OUT)
