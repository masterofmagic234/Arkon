# ACORN HUNTER — V22 Illustrated Walls

Based on `ACORN_HUNTER_V20_WALLSETS_V4.zip`.

## What changed
- Added six long-form illustrated night wall strips derived from the new `WALL ILLUSTRATION SETS v2 — NIGHT EDITION` art sheet.
- The sheet itself is included as `assets/wallsets_v2_night_edition_sheet.png` for art direction, but is **not** used as a runtime texture.
- The six runtime strips are placed as thin visual overlay planes over existing wall faces.
- Both sides of qualifying wall runs receive the visual treatment, so the artwork is visible from either direction.
- Long perimeter runs receive distinct signature styles; shorter runs rotate deterministically through all six styles.

## Preserved
- 107 canonical wall cells
- existing wall meshes and collision shapes
- existing map/layout
- player, enemy, pickup, HUD, minimap, mission, audio and sky systems
- V20 modular controller architecture

## Important
This is a visual layer only. No `MapWall_*` node position, mesh, collision shape or collision layer was modified.

Godot runtime/device execution is not available in this build environment, so this package is statically validated rather than runtime-tested.
