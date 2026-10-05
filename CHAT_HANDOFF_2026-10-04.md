# ACORN HUNTER — CHAT HANDOFF 2026-10-05

## Repository / PR
- GitHub: masterofmagic234/Arkon
- Main: main
- PR #11: Finalize Level 2 math and restore full game flow
- Branch: fix/level2-final-game-flow
- Godot 4.7.2, Android, GL Compatibility
- Workflow: .github/workflows/android_build.yml

## Architecture
Core rule: Facts — globally. Commands — locally. State — at owner. Presentation — subscriber.
Scenes -> Components -> Local Commands -> Global Facts -> Independent Presentation.
SignalBus is the global gameplay fact/event contract; do not turn it into a Service Locator.

## Intended game flow
Boot -> Level 1 -> Level 2 -> Level 3 -> menu.tscn. No intro/final cinematic gate.

## PR #11 Level 2 architecture
- Race centerline/world geometry is handled by race_math.gd plus authored track data.
- RaceMovementComponent owns authoritative lateral_offset; world X is derived from road center.
- Arcade centrifugal drift on curves.
- Track heading from authored/world tangent.
- Fixed 60 Hz simulation with interpolated presentation.
- Exponential drag damping.
- No runtime closure-error bending; closed-loop validity is an authoring invariant.
- AI reads racer movement state directly.
- RaceDirector owns countdown/start, ranking, lap/finish handling and Level 2 completion.
- Legacy race_controller/race_car_controller/race_input/race_state/race_queries path was removed.
- Old pseudo-3D Level 2 scene/controller path was removed in this integration.

## Current Level 2 3D integration
- nfs_shift_psp_-_london_short.glb is the authored London track source.
- 240_sx_nfs_pro_street.glb is the current 3D player vehicle.
- level2_racer.tscn and level2_racer_3d.tscn are the racer scenes.
- level2_camera_3d.gd provides the chase camera.
- level2_mobile_input.gd provides mobile race input.
- level2_racer.gd and level2_racer_visual_3d.gd own racer gameplay/presentation.
- game_level2.gd is integrated with the new race actor/director architecture.
- Shared RaceHud and NES-style race minimap remain in use.
- race_audio.gd and race_track_view.gd support race presentation.

## Recent Level 1 visual/regression work present on branch
- Four floor-zone textures: floor_zone_1(1).jpg through floor_zone_4(1).jpg.
- New grass assets: assets/grass_tuft.svg and assets/grass_tuft_carolina.svg.
- MultiMesh-based grass generator with tested instance budget.
- Dedicated night wall shader with triplanar sampling, bottom/contact-AO gradient and preserved vertical texture flip.
- CI smoke tests explicitly protect the wall shader path that was good in CI #199.
- Floor UV scale/emission and squirrel Y stability are regression-tested.

## CURRENT CI WORKFLOW — VERIFIED ON PR BRANCH
android_build.yml currently:
1. actions/checkout@v5
2. actions/setup-java@v5, Java 17
3. android-actions/setup-android@v3
4. sdkmanager: platform-tools, platforms;android-35, build-tools;35.0.0
5. Godot 4.7.2 with export templates
6. Headless project import
7. Level 2 smoke test with a 60-second timeout
8. Full game-flow smoke test with a 60-second timeout
9. Debug Android export to build/AcornHunter-V20.apk
10. Upload APK artifact with 14-day retention
Job timeout: 15 minutes.

The obsolete Android SDK package 'tools' is no longer requested. Do not casually rewrite the Android setup.
APK publication is after both smoke gates, so a successful artifact requires those gates to pass first.

## CI incident still relevant
Previous Run #37:
- Run ID 37139191666
- Job ID 111249908393
- Head f47766c05142d807d54f11756a55e9f6f4b08eed
- CANCELLED after roughly 6 hours
- Exit codes 1 and 124 were seen.
Node/action deprecation messages were warnings, not proof of the root cause.
Never claim green CI without checking the actual run; never claim an APK exists without checking the artifact.

## Smoke tests
Level 2 smoke is now run in project context and has tools/level2_smoke_test.tscn. It checks InputMap, autonomous racer movement, AI/player discovery, closed track, scene loading, 3D racer, 240SX alignment, chase camera, shared HUD and minimap.

Full game flow smoke test checks:
- Level 1 -> Level 2 -> Level 3 -> menu flow
- four Level 1 floor zones, materials, UV/emission
- grass generator and instance budget
- wall shader/material assignments
- camera/fog/glow configuration
- mobile HUD and minimap placement
- oak alpha-scissor material
- real two-hit Level 1 squirrel combat
- squirrel Y-position stability
- CI #199 wall triplanar/vertical-flip shader markers
- Level 2 3D vehicle/chase-camera setup

## Level 1 priorities
- Squirrels must stay vertically grounded.
- Hitboxes/combat must remain functional.
- Preserve CI #199 wall shader triplanar path and vertical flip.
- Preserve four floor zones, UV scale/emission, grass budget and compatibility fog/glow.

## Level 2 priorities
- Get the real London 3D track + 240SX path to a genuinely green Android CI build.
- Then validate actual Android gameplay.
- Preserve the new race architecture and authored track invariants.
- Keep many interesting sharp turns; do not regress track curvature.
- Do not resurrect the deleted legacy controller/state architecture just to make a test pass.

## Level 3 context
Hotline Miami-like convenience store/night setting; dialogue disabled; larger player/enemies; visible weapon; moving walk animation; 360-degree facing; slower bullets; sub-pixel movement/rotation; blood puddles. Audit concerns: player red modulate reset, door collision timing, dialogue freeze vs melee AI, bat LOS, audio pool, component/Event Bus architecture.

## Known gameplay issues from user testing
- L1 squirrels had been visually sunk about halfway into the floor.
- L2 previously showed HUD/gray screen instead of the intended race.
- Squirrel hitboxes needed improvement and squirrels needed to be larger.
- L3 left-stick movement had caused unintended continuous firing.
- L2 needed many sharper turns.
- User wants deeper code-logic investigation before blindly producing another build.

## Working style
GitHub-first. Inspect the actual branch before editing. Prefer small targeted commits. Preserve working visual/logic innovations. Never claim testing that was not performed. Do not merge PR #11 until the user has a successful Android build/test unless explicitly asked to merge earlier.
