# Botanical garden assets

Art direction: owner-selected concept B, `art/level1/botanical_concept_B.png`,
generated with ImageGen on 2026-10-25 (`exec-767cf8ca-166f-4094-b8b9-8b9d8a677a7c`).
This is an artistic reference, not an engine screenshot or a promised pixel match.
The environment uses the owner's actual Scout and tank GLB models unchanged.

`foliage_atlas.png`: ImageGen output `exec-b0b56c4b-7072-4e73-8828-a90a3c8ec041`,
2026-10-25, generated for this project using the selected garden concept as a
style reference. The transparent 1536x1024 atlas has six equal cells: oak,
ivy, flowering wisteria, fern, wildflowers and grass. Original RGB/alpha retained;
UV-mapped cutouts are rendered as actual 3D foliage cards. Native frames are
never painted over or passed to ImageGen.

Downloaded Poly Haven material maps and sky are CC0:
- `stone_*`: [Sandstone Blocks 05](https://polyhaven.com/a/sandstone_blocks_05), Rob Tuytel.
- `limestone_*`: [White Sandstone Blocks 02](https://polyhaven.com/a/white_sandstone_blocks_02), Rob Tuytel.
- `soil_color.jpg`: [Forest Floor](https://polyhaven.com/a/forest_floor), eye-candy.xyz.
- `rock_*`: [Rock Wall 16](https://polyhaven.com/a/rock_wall_16), Amal Kumar.
- `garden_sky.hdr`: [Kloofendal 48d Partly Cloudy Puresky](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky).

Maps use the supplied 1K JPEG diffuse/OpenGL normal/roughness data, where used;
the sky uses the supplied 1K Radiance HDR. Mipmaps and desktop/mobile VRAM
compression are explicitly enabled in import metadata. Existing park bark and
meadow albedos are also reused; their creation is recorded in the adjacent
textures/NATURE_MATERIALS.md. All architecture, terrain, branches, ivy placement
and garden routes are authored in `scripts/botanical_world.gd`.

Generated meshes in `meshes/` preserve the authored procedural full-detail geometry and add Godot meshoptimizer LODs plus welded position-only depth/shadow meshes. Rebuild with `tools/prepare_botanical_meshes.gd` using Godot4.7.2; these contain no new third-party art.
