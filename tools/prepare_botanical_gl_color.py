#!/usr/bin/env python3
"""Bake the existing garden GL leaf tint into RGB; alpha stays byte-identical.

Offline only. The runtime coverage mask still comes from the original imported
atlas and its platform mip chain. Run before Godot import; Pillow is sufficient.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/level1/botanical'

def prepare():
    source = Image.open(ASSETS / 'foliage_atlas.png').convert('RGBA')
    channels = source.split()
    result = []
    for channel, tint in zip(channels[:3], (.62, .76, .62)):
        lut = []
        for value in range(256):
            c = value / 255
            linear = c * (c * (c * .305306011 + .682171111) + .012522878) * tint
            lut.append(round(max(0, min(1, 1.055 * linear ** (1 / 2.4) - .055)) * 255))
        result.append(channel.point(lut))
    output = Image.merge('RGBA', (*result, channels[3]))
    assert output.getchannel('A').tobytes() == source.getchannel('A').tobytes()
    output.save(ASSETS / 'foliage_color_gl.png', optimize=True)
    print('BOTANICAL GL COLOR: baked RGB; original alpha preserved')

if __name__ == '__main__':
    prepare()
