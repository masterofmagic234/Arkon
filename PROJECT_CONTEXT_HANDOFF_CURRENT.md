# ACORN HUNTER — CURRENT PROJECT HANDOFF
## Canonical snapshot: 2026-09-23

> This file is the current continuity snapshot for a new ChatGPT chat.
> Read it before changing the repository.
>
> Repository: `masterofmagic234/Arkon`
> Branch: `main`
> Engine: Godot 4.7.x (CI currently uses Godot 4.7 stable)
> Renderer: GL Compatibility
> Target: Android
>
> The older `PROJECT_CONTEXT_HANDOFF.md` remains valuable for historical context.
> This file is the **current state snapshot** and overrides stale historical details when they conflict.

---

## 1. WORKING RELATIONSHIP / DEVELOPMENT MODE

The user expects the assistant to act as Lead Game Developer / Technical Director / Programmer.

Communication:
- Russian.
- Direct, practical, concrete.
- Prefer implementation over abstract discussion.
- When the user says «делай», proceed with the repository changes directly.
- Do not ask the user to paste code when the GitHub connector can inspect/edit the repo.
- Work in small, testable commits.
- After meaningful work report: what changed, commit SHA, build/Actions status, and remaining runtime verification.

Critical trust rule:
- Never claim an APK, scene, gameplay feature, or visual change is working unless there is current evidence.
- GitHub Actions passing means the CI checks passed; it does not replace Android runtime verification.

---

## 2. GAME IDENTITY

ACORN HUNTER is a personal, absurd action game centered on Carolina, Darina, acorns, and squirrels.

Core tone:
- affectionate;
- ridiculous;
- unexpectedly cinematic;
- the premise is intentionally taken completely seriously.

Core story grammar:
`Дарине нужна поделка → нужны жёлуди → Каролина идёт за желудями → белки мешают → ситуация эскалирует → синяя Ока → безумная гонка → оказывается кошмаром → белки всё равно существуют`

Keep the Carolina/Darina/acorn/squirrel mythology and humor.

Do not publish private Telegram/contact information or private correspondence into the public repository.

---

## 3. PROTECTED GAME FLOW

The established flow is:

`TITLE → INTRO CUTSCENE → LEVEL 1`

Historically this chain worked on the user's Android phone and should not be broken by unrelated changes.

Project main scene is currently:
`res://scenes/level3_store.tscn`

That does **not** mean Level 1 is irrelevant: Level 1 is an actively edited/tested scene, but the current project launch target remains Level 3 unless explicitly changed.

---

## 4. LEVEL 1 — CURRENT DESIGN DIRECTION

The user has explicitly asked to redesign Level 1 using the supplied wide linear concept image.

The desired level is:
- much larger than the original 20×14 map;
- strongly linear in progression;
- visually varied;
- divided into sequential zones;
- more interesting for the player;
- uses keys and locked/openable doors;
- includes lanterns/lights;
- includes acorns and squirrels;
- includes environmental landmarks and a central/secret water area;
- progression should feel like a journey rather than a compact symmetric maze.

The supplied reference image communicates this progression:
1. Start / tutorial.
2. First enemies.
3. First key.
4. First locked door.
5. Central/open area.
6. Secret area.
7. Harder corridors.
8. Final zone / exit.

Do not literally copy another game's map. Use the reference as an original layout brief / design target.

### Level 1 presentation
- Night forest / park.
- Fixed-height first-person camera.
- Wolfenstein-style spirit, but implemented in Godot 3D.
- No free vertical look.
- Mobile-friendly controls.
- Detailed walls/hedges.
- Warm lantern accents against blue-green night atmosphere.

---

## 5. LEVEL 1 CURRENT TECHNICAL MAP STATE

Current `scripts/level_data.gd` was expanded from the old 20×14 map.

Current constants include:
- `MAP_WIDTH = 56`
- `MAP_HEIGHT = 15`
- `CELL_SIZE = 1.8`
- `MAP_WORLD_ORIGIN = Vector2(-50.4, -13.5)`
- `ACORN_COUNT = 6`
- `KEY_COUNT = 3`
- `DOOR_NAMES = ["Door01", "Door02", "Door03"]`
- `DOOR_CELLS = [Vector2i(19, 6), Vector2i(35, 6), Vector2i(48, 6)]`

Current canonical map is a 56×15 ASCII map stored in `LevelData.CANONICAL_MAP`.

Do not invent a new map while forgetting this current data. Inspect the actual file first.

---

## 6. LEVEL 1 CURRENT EDITABLE SCENE

Current scene:
`res://scenes/level1_layout.tscn`

Structure:
- `Level1Layout`
  - `Floor`
  - `Walls`
  - `Props`
  - `Pickups`
  - `Enemies`
  - `Decor`
  - `Doors`

The latest rebuilt layout currently contains approximately:
- 481 wall bodies;
- 6 acorns;
- 3 keys;
- 3 doors;
- 13 lantern nodes;
- 5 squirrels;
- 2 water areas;
- fake pine cone;
- decorative trees.

The scene uses:
- `scripts/level1_layout_editor.gd`
- `scripts/level1_door.gd`

The Level 1 layout remains intended to be editable in the Godot editor.

---

## 7. LEVEL 1 KEYS / DOORS

Current controller:
`scripts/level1_door.gd`

A door has:
- a pivot;
- an animatable leaf;
- collision;
- a key icon;
- an exported required key id;
- a tweened open animation.

Current authored doors:
- `Door01` → key 1
- `Door02` → key 2
- `Door03` → key 3

Current Level 1 coordinator logic in `scripts/game.gd`:
- detects nearby key pickups;
- hides collected keys;
- increments `keys_held`;
- detects nearby locked doors;
- uses the matching key to open the door.

The intended gameplay rule is **matching-key progression**:
- key 1 opens door 1;
- key 2 opens door 2;
- key 3 opens door 3.

Do not replace this with arbitrary key consumption without preserving the progression order.

---

## 8. LEVEL 1 LANTERNS

The new layout uses the existing repository lantern asset:
`res://street_lamp.png`

Lanterns are authored in `Decor` and include:
- billboard sprite;
- warm OmniLight3D;
- local warm illumination;
- emission.

Do not invent a new lantern asset when the existing one works.

---

## 9. LEVEL 1 COLLISION / WORLD QUERIES

Updated:
- `scripts/world_collision.gd`
- `scripts/world_queries.gd`

They now use:
`LevelData.MAP_WORLD_ORIGIN`

Do not revert to the old hard-coded `+10` / `+7` cell mapping from the original 20×14 map.

Important architectural limitation:
- AI/world collision is still partly data-driven from `LevelData.CANONICAL_MAP`.
- Moving an authored wall in the editor does not automatically rewrite the canonical ASCII map.
- Do not claim full editor-authoritative pathfinding unless this synchronization is explicitly implemented.

---

## 10. LEVEL 1 GAMEPLAY BASELINE

Main coordinator:
`scripts/game.gd`

Important modules:
- `scripts/game_state.gd`
- `scripts/gameplay_controller.gd`
- `scripts/player_controller.gd`
- `scripts/enemy_controller.gd`
- `scripts/pickup_controller.gd`
- `scripts/presentation_sync.gd`
- query/math helpers
- `scripts/level_data.gd`

Player:
- fixed-height first-person camera;
- mobile joystick;
- fire button;
- weapon/HUD;
- Carolina portrait;
- minimap.

Enemies:
- five squirrel archetypes remain:
  - Scout
  - Tank
  - Thrower
  - Thief
  - Runner

Pickup system still handles acorns and the fake pine cone.

---

## 11. LEVEL 1 CURRENT CI FAILURE — IMPORTANT

Latest current HEAD:
`3320789e5c6422e05beca86c4e3ac2b8fc5fdd1f`

Latest commit:
`ci: wait for Godot imports before smoke tests`

Latest workflow run:
- Run ID: `35837180527`
- Result: **failure**
- Level 2 smoke test: **PASS**
- Level 1 smoke test: **FAIL**

The previous failure occurred because the CI job started the Level 1 smoke test after a timed editor shutdown had aborted Godot's first filesystem scan.

The log showed:
`No loader found for resource: res://assets/grass.png`
and the same transient import error for other PNGs, followed by:
`res://scenes/level1_layout.tscn: Parse Error: [ext_resource] referenced non-existent resource at: res://assets/grass.png`

This is currently a CI/import-order problem to investigate. It is **not evidence that the PNG files are actually missing from GitHub**.

Recent related workflow history:
- `b811f5738db1664ce92deb749d43497344f6d424` — Level 1 expanded layout
- `038da8567663724b4b566242f4a6d14cb61ce271` — lantern path
- `e8e83c618e9978405046e50c3a06f47ccf81ab05` — stale main-scene wall cleanup
- `f6e3e0d0a56b6a91868e77055bf4949fa9c32399` — matching key requirements
- `78c17d06d4e9e0ff3e76b5f1890a1a8b70951771` — extend Godot import wait to 20s

The previous scene parser bug from the editor resource ordering has already been fixed; do not blindly reintroduce it.

### CI synchronization fix just committed
Commit `3320789e5c6422e05beca86c4e3ac2b8fc5fdd1f` replaces the timed editor validation command with Godot 4.7's `--import` mode, which explicitly waits for pending resource imports before quitting. The fix still preserves the existing validation-error grep and does not disable the Level 1 smoke test.

CI result for this new commit has not yet been observed through the available GitHub status API, so do not call the fix verified until a fresh workflow run reports its result.

---

## 12. LEVEL 1 SMOKE TEST

File:
`tools/level1_smoke_test.gd`

It currently checks:
- LevelData setup;
- Level1 layout loads;
- wall count >= 400;
- all six keys exist;
- all three doors exist;
- each door has the matching key requirement;
- lanterns exist;
- six acorns;
- five squirrels;
- pickup collection;
- squirrel spawning;
- squirrel hit/stun behavior;
- collider-to-squirrel mapping.

The test is conceptually correct, but the current CI invocation is racing the initial import scan.

When fixing the failure:
- make the CI wait/retry import completion robustly;
- do not simply disable the smoke test.

---

## 13. LEVEL 1 VISUAL / WORLD SCALE

The previous small map used:
- 20×14 cells;
- 36×25.2m ground;
- 12m camera far clip.

The current expanded map needs larger values.

Current direction already changed:
- camera far distance toward 22m;
- wall batching AABB toward the expanded map dimensions;
- atmospheric particle emission area toward the expanded map.

Do not accidentally restore the old small-world values when working on the new level.

---

## 14. LEVEL 2 CURRENT STATE

Level 2 remains the separate pseudo-3D racing sequence.

Important files:
- `scenes/level2_pseudo3d.tscn`
- `scripts/game_level2_pseudo3d.gd`
- `scripts/race_renderer_pseudo3d.gd`
- `scripts/race_hud_panel_pseudo3d.gd`
- `scripts/race_minimap_nes.gd`
- `scripts/race_controller.gd`
- `scripts/race_state.gd`
- `scripts/race_car_controller.gd`
- `scripts/race_ai_controller.gd`
- `scripts/race_level_data.gd`
- `scripts/race_input.gd`

Current renderer values that should not be casually changed:
- `ROAD_SCREEN_SCALE = 0.75`
- `ROAD_WORLD_WIDTH = 9.0`
- `RENDER_CURVE_SCALE = 0.16`

The current project has already moved roadside props toward world-segment anchoring and perspective scaling.

Do not apply stale prop installers using:
- `FIRST_PROP_OFFSET`
- `PROP_SPACING`
- renderer-index-only identity
- `screen_y < 496.0`

Latest Level 2 CI smoke test in the current failed workflow is still:
`LEVEL2 SMOKE TEST: PASS; track_size=80`

Actual Android visual runtime still needs to be verified before calling Level 2 visually finished.

---

## 15. LEVEL 3 CURRENT STATE

Level 3 is the top-down store scene.

Main files:
- `scenes/level3_store.tscn`
- `scenes/level3_layout.tscn`
- `scripts/level3_store.gd`
- `scripts/level3_enemy.gd`
- `scripts/level3_asset_visual.gd`
- `scripts/level3_door.gd`

Recent Level 3 fixes already completed successfully:
- Butcher sprite path corrected to existing:
  `res://assets/level3/source/Player/sprPigButcher_strip8.png`
- duplicate `SpriteFrames.default` creation removed;
- several Level 3 script warnings were cleaned.

Do not regress the Level 3 door hinge behavior.

---

## 16. INTRO / TITLE

Protected chain:
`TITLE → INTRO → LEVEL 1`

Intro assets and history are documented in the older `PROJECT_CONTEXT_HANDOFF.md`.

Approved bedroom assets include:
- closed-door master;
- matching open-door master;
- Darina source sheet.

Darina should emerge from the doorway, not appear beside the computer.

Do not display the entire Darina source sheet as one sprite.

---

## 16A. LEVEL 1 DESKTOP TEST CONTROLS

For local PC/Godot testing, Level 1 now supports a separate desktop input path:
- W / S — move forward/backward;
- A / D — turn left/right;
- mouse movement — turn the fixed-height camera horizontally;
- left mouse button — fire;
- Esc — release/capture the mouse cursor.

On desktop the mobile joystick and touch fire button are hidden. Android/mobile joystick behavior remains unchanged.

## 16B. LEVEL 1 3D SCOUT STATUS

The uploaded `cartoon squirrel 3d model.glb` is now integrated as the visual for `Squirrel01` / Scout.
- The other four archetypes still use their existing 2D cutouts.
- `scripts/squirrel_3d_visual.gd` loads the GLB at runtime, normalizes it to approximately 1.85m character height, and supports imported AnimationPlayer clips when present.
- If the GLB has a Skeleton3D or separately named parts, the script applies procedural idle/run/stunned motion to bones/parts as a fallback.
- If no rig/animation exists, the whole 3D model still receives readable idle/run/hit/stunned procedural motion.
- `enemy_controller.gd` now triggers the 3D Scout hit reaction.
- `tools/level1_smoke_test.gd` now verifies that the 3D Scout GLB can be loaded.
- The 3D Scout integration is committed, but actual Godot runtime appearance/rig quality still requires local F6 verification.

## 16C. LEVEL 1 SCOUT RIGGED MODEL UPDATE

The newest uploaded Scout asset is `cartoon squirrel 3d model1.glb` in the repository root.
- Level 1 now uses this rigged GLB instead of the earlier static Scout model.
- Scout orientation is controlled by the outer `Squirrel3DVisual` wrapper around the imported model.
- The wrapper rotates on Y toward the AI movement vector, so AnimationPlayer/Skeleton3D root motion cannot pin the character to one viewing direction.
- `MODEL_YAW_OFFSET` is available in `scripts/squirrel_3d_visual.gd` for correcting the asset's imported forward axis without changing gameplay movement.
- Imported clips are preferred when their names contain `idle`, `run`, `hit`, or `stunned`; procedural fallback remains available when a clip is absent.
- The other squirrel archetypes remain 2D until Scout's rigged presentation is confirmed in-game.

## 16D. SCOUT SKELETAL ANIMATION IMPLEMENTATION

Scout 3D animation has been switched from heuristic per-bone procedural posing to explicit runtime AnimationPlayer + Skeleton3D rotation tracks.
- `scripts/squirrel_3d_visual.gd` creates a dedicated AnimationPlayer under the imported GLB.
- Imported/autoplay AnimationPlayer instances are stopped so they cannot fight the gameplay animation.
- Runtime clips: `Scout_Idle`, `Scout_Run`, `Scout_Hit`, `Scout_Stunned`.
- Clips use Godot `Animation.TYPE_ROTATION_3D` tracks targeting actual Skeleton3D bones.
- The previous heuristic code that rotated arbitrary bones/parts has been removed because it caused severe mesh deformation with the new rig.
- Gameplay-facing 360-degree yaw remains on the outer `Squirrel3DVisual` wrapper, independent from the skeleton animation.
- First local F6 verification of the new skeletal clips is still required.

## 16E. SCOUT SCRIPT COMPATIBILITY FIX

The first runtime skeletal-animation implementation used inline typed lambda callbacks and caused Godot 4.7 to fail resolving `squirrel_3d_visual.gd`.
- The script has been rewritten using ordinary GDScript methods for each pose (`_idle_rotation`, `_run_rotation`, `_hit_rotation`, `_stunned_rotation`).
- The runtime animation remains real `AnimationPlayer` + `Animation.TYPE_ROTATION_3D` tracks targeting Skeleton3D bones.
- Latest fix commit: `1ca356b060923bf366196cda092177b7e522932b`.
- The script should now be syntactically compatible with Godot 4.7, but local F6 runtime verification is still required.

## 17. DEVELOPMENT RULES

1. Inspect actual `main` before changing code.
2. Use small commits.
3. Prefer the smallest fix that preserves working behavior.
4. Run/inspect the relevant GitHub Action after important changes.
5. Read logs when a build fails.
6. Never replace evidence with assumptions.
7. Preserve the protected game flow.
8. Do not do giant speculative refactors.
9. Do not blindly port the old raycaster.
10. Do not reintroduce the abandoned fence experiment.
11. Do not use crude placeholder geometry to replace approved artwork.
12. Do not expose private personal material in the public repo.

---

## 18. NEW CHAT START PROCEDURE

At the start of a new chat:

1. Read this file completely.
2. Read the historical `PROJECT_CONTEXT_HANDOFF.md` when historical context matters.
3. Inspect current `main`.
4. Read the real current files relevant to the requested task.
5. Check the newest GitHub Actions run.
6. Reconcile any differences between this document and the repository before making edits.
7. Then implement.

Never start by asking the user to re-explain the project history.

---

## 19. CANONICAL BOOTSTRAP PROMPT

Use the separate file:
`PROJECT_BOOTSTRAP_PROMPT.md`

It is an operational project bootstrap prompt for a new chat.
It is intentionally written as a public project-development prompt and does not reproduce private system/developer instructions.

---

## 20. IMMEDIATE NEXT TASK

The last requested work was:
- redesign Level 1 as a larger, linear, staged journey based on the supplied reference;
- add lanterns;
- add collectible keys;
- implement key-gated doors;
- keep the level interesting and readable.

The current code contains those edits, but CI is still red because of the Godot first-import race.

**The CI import/smoke-test synchronization fix is now committed.**
The next verification gate is a fresh `Build V20 APK` run on the new HEAD. Only after Level 1 smoke test is green should the expanded Level 1 be treated as a stable baseline.

