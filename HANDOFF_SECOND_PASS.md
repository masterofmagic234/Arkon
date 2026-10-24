# ACORN HUNTER — second pass, 12 October 2026

Continues `HANDOFF_2026-10-12.md` from `61582d834734cffcb1ed293aa7504263e5e27ac3` on `fix/level2-final-game-flow` (PR 11). This is the selected original Moon Park, not the rejected alternate park. The established 240SX rig, camera, powertrain and audio assets are preserved.

## Level 1 — Moon Park

- Recolored and shortened the meadow blades, distributed them in irregular patches: 2995 clumps in 12 fields. Shared spatial batches add rounded path pebbles, fallen leaves and small wildflowers. Placement respects authored walkable cells and the existing prop footprints; no new collision obstacles.
- Scene-owned damage direction, healing and confirmed-hit feedback. No extra camera shake or input changes.
- Correct remaining-acorn guidance after opening all gates, and format the acorn count instead of displaying a raw `%d` placeholder. Release park ambience references on teardown.
- Keep the existing lake, lanterns, wall-top shrubs, oak geometry and refined wall materials. This pass does not claim to replace those assets again.

## Level 2 — night race

- Replace towering bright grass curtains with flat projected meadow verges. Add road reflectors, curve rails/chevrons and a projected checker finish stripe. Tint roadside trees, city and asphalt for the night scene.
- One responsive dashboard: large speed, automatic gear/RPM, lap/place, time/best, visible minimap and turn/offroad cues. Pause and finish panels provide resume/restart/menu and deliberate Continue to Level 3. Finish freezes race timing; lap display never reaches 4/3.
- Independent owned steering/gas/brake touches, off-button release and cancellation. Synthetic mouse events cannot release a finger's pedal. Focus loss clears input and pauses. Break controller references on exit.
- Camera/drivetrain regression remains 0–100 km/h in 8.067 simulated seconds, four-speed automatic, 219 km/h maximum; grounded rig and skid behavior retained.

## Level 3 — Late Shift

- Rebuilt the baked floor with staggered wood boards, subtle grain, entrance/bar/kitchen mats, drains, hazard markings, scuffs and real door thresholds. The supplied room/furniture art and one-texture floor architecture remain.
- Damage/heal/hit feedback; contextual ACTION uses the exact same target resolver as gameplay. Pickup labels show the item; actionable hints update during flavor messages; narrow HUD avoids room-heading overlaps.
- Clamp player/enemy/bottle muzzles to the near side of nearby walls. Automatic pickups require line of sight; a medkit beneath a full-health player is reconsidered after damage.
- Reset the draw transform before each pooled effect, preventing muzzle transforms from shifting later tracers and droplets. Correct bottle-shatter frame timing.
- Ambient/radio volume smoothly attenuates behind actual walls; footsteps vary subtly and transient sounds prefer a free voice. Focus/suspension clears controls.

## Validation

Godot 4.7.2, GL Compatibility. Inspected 11 native park views, five driving captures and eight diner views on Mesa llvmpipe. The native pixel probe `tools/second_pass_visual_test.gd` checks that a tracer stays at its world position after a transformed muzzle. This probe requires a real display or Xvfb, not `--headless`.

Nine behavioral fixtures passed locally: Level 1 smoke, park, polish and input-driven playthrough; Level 2 smoke/vehicle checks; Level 3 smoke and input-driven playthrough; full campaign/second-cycle flow; new `tools/second_pass_test.gd`. The latter covers three driving viewport sizes, independent touches/cancel/focus, actual last-lap boundary and Continue, thin-wall firing, stationary medkit and bounded feedback.

The diner route still defeats all ten live guards in six rooms, collects the order and returns through the actual menu transition: 15 shots and 73.78 simulated seconds. This is an automated route, not human play duration. Its physics fixture checks 6069 actual route sweeps and all eight doors. The park route also reaches the actual car transition.

One parallel local run exposed the park fixture's short wait for asynchronous navigation publication; it now waits up to ten wall-clock seconds and reports a distinct readiness failure. Geometry and body-clearance assertions remain unchanged. Existing campaign/park-route shutdown resource warnings are not new to this pass; diner/new regression fixtures enforce a strict error gate.

Native diner gameplay frames remain 82–118 draw calls, with 152 for the mobile view and 223 for overview. Park native views range 59–281 steady captured calls; the initial warm-up frame is 749. These are desktop software-renderer counters, not Android FPS measurements. Phone performance, speaker balance and physical touchscreen feel still require device testing.

CI runs all nine behavioral fixtures before export. New output: `build/AcornHunter-SecondPass.apk`, arm64, version **1.5 / code 6**, original package `com.acornhunter.carolina`. The workflow exports a debug APK; this is not a signed store release. Verify the successful workflow's head SHA and artifact before delivery.
