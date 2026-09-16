# ACORN HUNTER — Technical Baseline

## Baseline

**Working visual baseline:** the Android build currently proven to render the wall pipeline correctly after the full-texture material fix.

**Baseline commit before documentation:** `0cf767e6a90ba4cec5f5cf2667e01fa2e5278d8b`

This is the technical baseline for the next wall-art phase.

## Must remain unchanged

- Canonical Level 1 map: 20×14 cells.
- Cell size: 1.8 units.
- Wall collision: one 1.8 × 2.6 × 1.8 solid volume per wall cell.
- Player movement and controls.
- HUD and mission system.
- Minimap.
- Squirrel gameplay/combat cycle.
- Acorns and pickups.
- Trees and other existing gameplay/world systems.
- 4K Milky Way night sky and twinkle.

## Wall-art direction

Replace the temporary technical wall textures with six genuinely designed, complete wall textures:

1. Mossy Stone
2. Overgrown Ivy
3. Brick & Stone
4. Wooden Fence
5. Ruined Temple
6. Autumn

Each wall style is a complete seamless surface texture. **Do not use 4096×512 eight-panel atlases.** Do not stretch the old 512×512 panels into larger textures.

Target source resolution: 2048×2048 or higher where practical.

## Decoration rule

Signs, lanterns, banners, flowers, barrels, emblems and other unique props must be separate scene objects/decorations. They must not be baked into a repeating wall-texture atlas.

## Engineering rule

Use the currently proven direct full-texture material/rendering path. Improve one wall-art component at a time and build/test after each change. Do not change map geometry, collision or gameplay while working on wall art.

## Current visual result

The current working screenshot proves the texture-rendering path works, but the visible textures are temporary technical patterns and are **not** considered final art.
