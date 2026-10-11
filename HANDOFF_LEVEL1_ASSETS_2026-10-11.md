# Arkon — Moon Park with existing assets, 2026-10-11

Repository: masterofmagic234/Arkon.
Variant branch: fix/level1-park-existing-assets.
Base: fix/level2-final-game-flow at 881e6a14b2653d3e6e1f00b33259477235a8e9a1.
Godot 4.7.2, GL Compatibility, Android arm64.

The user liked the new Moon Park and requested a separate branch that uses
more of the project's existing artwork. This variant preserves its authored
map, collision/navigation, live encounters, input, sound, pickup recovery and
car boarding/campaign transition. The base branch is a separate comparison.
This handoff records implementation facts, not a future development roadmap.

## Existing artwork integrated

- floor_zone_1(1).jpg through floor_zone_4(1).jpg cover the four park quarters.
  Each floor pixel samples one texture. Quarter boundaries lie under dividing
  hedges; the original continuous gravel ribbon crosses the gates.
- wall_zone1.png through wall_zone4.png supply stone/ivy surfaces appropriate
  to each quarter. World-space coordinates keep scale consistent across walls,
  arch, gate pillars and the statue plinth.
- assets/oak_tree.png supplies painted foliage on the volume of the nearby
  3D trees. The crown region excludes the illustrated trunk/roots. The golden
  oak receives a warm colour treatment through its own material.
- The original full oak and assets/pine_tree.png supply the distant forest.
  Fixed-Y cutout billboards are batched in spatial MultiMeshes with alpha
  scissor, mipmaps, distance culling and source-image margin compensation.
  The near landmarks retain actual 3D trunks and branching geometry.
- assets/hedge_wall_0.png supplies the hedges. Grass remains the existing
  assets/grass_tuft_carolina.svg on lit, wind-animated crossed geometry.
- Meshy_AI_Acorn_Guardian_0923182156_texture (1).glb is the garden monument.
  Bounds normalize its height and seat it on the pedestal. Its materials are
  duplicated before applying patina. The original files remain byte-identical.
- Existing sky, moon, weapon, portrait, rigged squirrel and 240SX remain in use.
  No new artwork or external assets were downloaded for this variant.

scripts/level1_park_assets.gd owns source references/material factories and the
statue normalization. scripts/level1_environment.gd composes the park.
shaders/level1_asset_surface.gdshader uses one texture sample and real lighting;
level1_foliage.gdshader samples the original oak crown. Source resources remain
read-only, so other levels retain their own material state.

## Verification and export

Local Godot import, Level 1/2 smoke, park physics/touch regression, complete
input-driven playthrough with all enemies active and full campaign flow passed.
The driver collected all six acorns/three keys, opened all gates, recovered
carried loot and boarded the car to reach Level 2 with ten actual shots. It
does not teleport or override health/ammo/progression. Native GL Compatibility
capture uses tools/level1_capture.gd, now including the garden monument view.

The map/collision layout is inherited byte-identically from the tested base.
CI runs the same checks before Android export. Verify the variant's actual
HEAD, Actions run and artifact before reporting build success.

Output: build/AcornHunter-MoonPark-Assets.apk, version 1.2/code 3.
Package: com.acornhunter.carolina.parkassets; label: ACORN HUNTER — Assets.
It installs beside the original package for visual comparison, with independent
saved settings/progression. This is an Android debug build.

Native rendering was checked via Xvfb/Mesa at 1280 x 720; it establishes
presentation, not phone FPS or human first-play duration. Phone performance
has not been measured.
