# Tank squirrel — supplied by the project owner, 24 October 2026

The attachment `fantasy+creature+3d+model.glb` is the user's new tank squirrel.
Its embedded generator is Tripo. The unmodified source is retained at
`source/tank_original.glb` (SHA-256
`d9b96ed3bebbfb8c45461684ed594327ca7817e51fce29f8b7c7125937dde794`).
Source contains one weighted mesh/material, 18,457 triangles, a 78-joint rig,
three 2048px texture maps and no authored animation clips.

Runtime `tank_squirrel.glb` retains that original character, UVs and weighted
skeleton. Offline preparation welds coincident UV-split vertices (preserving per-corner UVs) and reduces the mesh to 7,013 triangles and the three
maps to 1024px, then encodes embedded maps as JPEG quality94 without chroma
subsampling. Its size is 2,150,372 bytes. No generated replacement anatomy or
paint-over was used. The source folder has `.gdignore`, so original working
files are not imported or packaged into the Android build.

Rebuild with Python3 + Pillow and Blender4.3.2:

```sh
python3 tools/prepare_tank_squirrel.py
```

`Squirrel3DVisual` normalizes floor placement and configured height, uses the
supplied rig's principal head/spine/limb joints for procedural locomotion and
hit/stun reactions, and leaves twist/finger helper joints untouched. These are
procedural runtime poses; the attachment did not include animation clips.
Its source has no separate tail bones, so the tail retains its supplied shape.
Materials keep base color and normal detail with matte, nonmetallic fur.
