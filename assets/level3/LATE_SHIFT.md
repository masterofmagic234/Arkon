# Level 3 — Late Shift / Ночная смена

This pass reuses the project's supplied top-down pixel assets. Furniture,
windows, lamps, arcade cabinets, jukebox strips, food, vehicles and actor
frames come from `assets/level3/source`; their original files are retained.
No external images or music were downloaded for this pass.

## Art and authored geometry

`scripts/level3_store_data.gd` owns the 48 × 32 plan, six room palettes, eight
two-cell doorways, 54 furniture placements, enemies, supplies and objectives.
The warm checkerboard diner and entrance meet a wood-floored arcade/bar;
the tiled kitchen, cold storage and staff room use cooler colors. Rain,
window reflections, parked vehicles, warm table pools and cyan/pink signs
give the rooms a shared nighttime setting.

Generate the collision scene with Godot 4.7.2:

```sh
godot --headless --path . --script res://tools/generate_level3_layout.gd
```

The generator merges wall runs and derives furniture contact shadows and
physical footprints from each supplied frame. It normalizes generated resource
IDs, so repeated runs produce the same scene bytes. Pixel-art variant strips
choose an explicit frame; only actual animation strips animate.

The floor/wall finish is authored in `scripts/level3_layout_floor.gd`: checker
and tile courses, staggered wood seams, supplied `background2.png` grain,
and the supplied brick/hospital wall textures. Bake it using a native renderer:

```sh
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://tools/generate_level3_floor.gd
godot --headless --path . --editor --quit
```

This saves `materials/diner_floor.png` (1088 × 782). The PNG caches immutable
drawing commands, rather than lighting or gameplay geometry: normal live 2D
lights still illuminate it, and doors/physics remain independent. Re-bake after
changing the plan, room floor colors or supplied wall/grain sources.

Native 1280 × 720 staged views on Godot 4.7.2 Compatibility/Mesa llvmpipe
measured 82–118 total draw calls for the six desktop gameplay views, 152 with
mobile controls and 223 for the whole-map overview. The same views before the
bake used approximately 4700–4900 calls. Counters cover world and HUD, not
just the floor. These are frame counters on a software renderer, not phone FPS.
14 shadowless lights share one radial texture. Projectiles cap at 64, effects
at 96 slots, spatial transient voices at 12, and permanent blood at 360 stamps.

## Original audio

`tools/generate_level3_audio.py` synthesizes the 11 mono Vorbis assets offline
with NumPy and ffmpeg (24 kHz, seed 31717): rain, refrigerator hum, pistol,
shotgun, enemy shot, door, glass, step, bat and pickup, plus a 32-second radio
loop. The radio is an original 90 BPM Em/Cmaj7/Am7/Bm7 arrangement of plucked
keys, bass and brushes. It contains no sampled recordings or existing song.

```sh
python3 tools/generate_level3_audio.py
godot --headless --path . --editor --quit
```

The scene owns spatial ambience/radio players and a reusable transient pool.
The listener follows the player; radio, rain and the cold-room hum have distinct
positions/ranges. Shared GameState music/SFX volume and mute preferences apply;
leaving the level stops playback and releases its streams. No Python or ffmpeg
runs in the game or APK.

## Presentation and gameplay checks

`tools/level3_capture.gd` produces eight native views and a frame-budget JSON.
It freezes actors and stages the player/camera for inspection; it is not a
gameplay replay. `tools/level3_smoke_test.gd` checks actual physical routes,
door occupancy, three-finger input, action edges, swept hit/dodge/wall behavior,
bounded effects and defeat. `tools/level3_playthrough.gd` traverses the mission
with real movement/aim/fire/action input and live enemies, collects the order,
returns to the entrance and validates the actual menu transition. It does not
teleport the player or override health, ammo, kills or mission progress.
