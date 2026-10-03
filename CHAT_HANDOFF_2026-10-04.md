# ACORN HUNTER — CHAT HANDOFF 2026-10-04

## Why this file exists
This is the authoritative handoff for continuing ACORN HUNTER development in a new ChatGPT conversation. Read this file first, then inspect the current GitHub state before changing code.

## Repository
- GitHub: masterofmagic234/Arkon
- Main branch: main
- Current development PR: #11
- PR title: Finalize Level 2 math and restore full game flow
- PR branch: fix/level2-final-game-flow
- Godot: 4.7.2
- Android target, GL Compatibility
- Workflow: .github/workflows/android_build.yml

## Architecture principles
Core rule:
"Facts — globally. Commands — locally. State — at owner. Presentation — subscriber."

Expanded:
Scenes → Components → Local Commands → Global Facts → Independent Presentation.

SignalBus is the global gameplay fact/event contract. Do NOT turn it into a Service Locator.
Commands remain local to the scene/actor that owns them.

## Intended game flow
Boot
→ Level 1
→ collect acorns / complete mission
→ Level 2
→ player finishes
→ Level 3
→ all enemies cleared
→ menu.tscn

No cinematic/cutscene gate.

## Important merged PRs
1. L3 PackedScenes/components: 38870639139228eea985a2dfde073268b9423da
2. InputMap L3 refactor
3. L3 Event Bus: 6b5155787a79fd7dbca54c624daa4412145c20ca
4. L1 audio Event Bus / scene-owned FX pool: 7bca40943d80799246a7cfd84197b713b33414a0
5. Unified SignalBus contracts: d3511e2063087b9a4...
6. L1 smoke harness hotfix: 4272d168e94823cb333fdf560f8b48236644c550
7. L1 autonomous actor refactor: 6a7ea0bfc4ca37af2d41b3c1cbc136337fbaca68
8. L1 presentation/input architecture: 489bc1199335191f7293cc4707f12d554e19071e

PR #9 and PR #10 were superseded/closed.

## SignalBus contract
Expected global facts include:
- mission_changed(level_id, status)
- level_completed(level_id)
- entity_damaged(entity, amount, source)
- health_changed(entity, current_hp, max_hp)
- entity_died(entity)
- entity_stunned(entity, duration)
- weapon_changed(entity, weapon_id, current_ammo)
- combat_event(kind, position)
- item_collected(item_kind, item_id, amount, collector)
- object_interacted(object_id, state)
- enemy_defeated(enemy)
- show_message(text, duration)
- audio_event(kind, position)

## PR #11 current state
Latest code commit before the stuck CI run:
f47766c05142d807d54f11756a55e9f6f4b08eed

PR #11 is still open. Do NOT merge until CI is genuinely green and APK is successfully produced.

## CI incident
Workflow run #37:
- Run ID: 37139191666
- Job: validate-and-build
- Job ID: 111249908393
- Head: f47766c05142d807d54f11756a55e9f6f4b08eed
- Final conclusion: CANCELLED
- It was stuck for about 6 hours.
- Therefore the previous assumption that it was merely still running was wrong.

User explicitly wants a finished GREEN build and an Android APK, not another endless CI run.

The latest GitHub annotations shown by the user:
- 3 errors
- 2 warnings
- validate-and-build exit code 1
- validate-and-build exit code 124
- warning: Node.js 20 is deprecated; actions/checkout@v4, actions/setup-java@v4, actions/upload-artifact@v4, android-actions/setup-android@v3 are being forced to Node.js 24
- warning: setup-java v4 is deprecated and should migrate to setup-java@v5
- sha256:5c6aa51cba0bbb9c3a5b50d26c97d4b8c6df18a24c864cbbd9ac27cd6b2fd609

Important: Node 20 deprecation is a warning, not the root cause by itself. Exit code 124 indicates timeout/hang somewhere. Inspect the actual job logs/steps before guessing.

## Workflow current intent
.android_build.yml should:
1. checkout
2. Java 17
3. Android SDK
4. Godot 4.7.2
5. import project
6. L2 smoke
7. full game flow smoke
8. export debug Android APK
9. upload APK artifact

Earlier obsolete Android SDK package "tools" caused a failure and was removed. Current setup uses:
android-actions/setup-android@v3 with packages: platform-tools
then sdkmanager platform-tools, platforms;android-35, build-tools;35.0.0

The workflow has been repeatedly edited to get past environment setup. Do not casually rewrite working setup steps.

## Recent CI fixes already made
- project.godot main scene corrected to res://game.tscn
- tools/full_game_flow_smoke_test.gd corrected to use res://game.tscn
- scripts/level1_player.gd: removed obsolete _reset_joystick()
- scripts/minimap_view.gd: removed duplicate _ready()
- scripts/level1_enemy.gd: WorldCollision.is_wall call reduced from obsolete 6 args to 2
- scripts/world_collision.gd: LevelData preload added, with class_name WorldCollision declared before the preload
- scenes/level1_key.tscn rewritten with valid resources
- scenes/level1_pinecone.tscn rewritten with valid resources
- game.tscn corrected from wrong pinecone ext-resource reference to 26_l1_pine
- L2 smoke test changed from standalone SceneTree script to a normal Godot scene:
  tools/level2_smoke_test.tscn
  tools/level2_smoke_test.gd extends Node and runs in project context
- L2 smoke obtains SignalBus through:
  get_tree().root.get_node_or_null("SignalBus")
- L2 smoke uses get_tree().root instead of standalone root
- L2 smoke uses ResourceLoader.exists(scene_path) for L1 path checks
- race_math.gd got explicit float typing for Godot 4.7 static inference issues

## Critical next steps
1. Inspect current .github/workflows/android_build.yml on PR branch.
2. Inspect the cancelled run #37 job steps/logs if still available. Job ID 111249908393.
3. Identify the exact step causing timeout/exit 124 and the 3 errors.
4. Fix the root cause in GitHub, preferably with a small targeted commit.
5. Modernize action versions while touching workflow:
   - actions/checkout@v5 if supported by current repository environment
   - actions/setup-java@v5
   - actions/upload-artifact@v4 or current supported version
   - android-actions/setup-android@v3 may still be current; do not change blindly.
6. Avoid long-running/hanging smoke tests. Any headless test must terminate deterministically.
7. Trigger a fresh workflow run from the fixed branch.
8. Verify all steps green.
9. Verify Android APK artifact exists.
10. Only then tell the user the build is green / ready to download.
11. Do NOT merge PR #11 until the user has a successful APK test, unless the user explicitly asks to merge earlier.

## L2 math target
- authoritative lateral_offset
- world_x derived from road center
- arcade centrifugal drift
- Catmull-Rom centerline/tangent in race_math.gd
- no runtime closure-error bending
- fixed 60 Hz simulation inside _process
- visual interpolation
- exponential drag damping
- pseudo-3D renderer consumes racer state
- AI reads player movement component itself
- RaceDirector handles countdown/start, ranking, mission completion

## L1 final architecture target
- Level1Environment owns environment setup
- Level1MobileInput attached to HUD converts UI touch into InputMap actions, no Player reference
- Level1Player reads movement actions directly
- MinimapView event-driven, only polls moving player marker every ~0.10 sec
- game.gd owns progression, not presentation/environment

## L2 renderer context
scripts/race_renderer_pseudo3d.gd:
- FAR_SEGMENTS=120
- HORIZON_FRACTION=0.42
- ROAD_SCREEN_SCALE=1.9
- ROAD_WORLD_WIDTH=9.0
- SEGMENT_WORLD_LEN=1.8
- draw_h=496
Keep recent texture/grass/emission innovations; do not revert them while fixing CI.

## L3 current context
- Hotline Miami-like convenience store/night setting
- dialogue currently disabled
- larger player/enemies
- weapon visible idle/walk
- only moving walk animation
- 360-degree facing
- slower bullets
- sub-pixel rotation/movement
- blood puddles
- recent audit concerns: player red modulate reset, door collision timing, dialogue freeze vs melee AI, bat LOS, audio pool, component architecture/Event Bus
- L1 squirrel work includes a 3D rigged squirrel replacement; previous issues: no skeletal animation, one-direction facing, levitation/deformation, Godot import crashes. Android FPS must be considered.

## Working style
- GitHub-first. Make changes in repository; do not ask user to manually copy files.
- Be explicit about what was actually checked.
- Never claim CI is green without verifying the workflow run.
- Never claim an APK exists without verifying the artifact.
- User is frustrated with repeated CI loops; prioritize deterministic fixes over broad refactors.
