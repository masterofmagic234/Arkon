> Superseded for Level 1 geometry and current release by
> `HANDOFF_2026-10-21_ESTATE_REBUILD.md` (Android 1.27/code28).
> The mechanics below remain background; old coordinates and gate ordering do not.

# Level 1 — moonlit heist, Android 1.26 / code 27

Repository: masterofmagic234/Arkon. Branch: fix/level2-final-game-flow.
PR 11 remains open; do not merge automatically. Read this file before the
older Level 1 handoff. Verify the actual branch SHA and its matching Actions
run before claiming a current APK. Final release CI/artifact evidence belongs
in PR 11's description, so recording it does not create another untested HEAD.

The starting head was e7e270b9ebd5d9f52d9e31708e290690141589f1, with successful
Actions #1043. The first heist commit d1569332647ac7f323940d26d7a481435338a1d2
passed Actions #1045 (39499542537). Follow-up e5ca34ecf04d219615f653c1b6d4ecff6e4d6b82
adds the final controls, noncombat balance, records and rendering work. Recheck
the release commit rather than treating either earlier run as its validation.

## Playable loop

The old decoration/extra-guard pass retained almost the same activity throughout
the park. Level 1 now has several different tasks and an actual return escape:

- Entrance: learn quiet movement, physical dash, sound and the optional bell.
  The parked 240SX is now at cell (5,32), beside the original entrance.
- Moon garden: three mechanical lenses must read MOON / LEAF / MOON, in order.
  A physical hint and the current objective give the sequence. Wrong states
  are reversible; matching all three releases Acorn03's visible seal.
- Gallery: two sweeping security footprints identify an exposed player after
  an 0.8 s warning. Real masonry interrupts their sight rays. Sabotage the
  relay at (41,6) to permanently stop both sweeps and release Acorn04.
- Legendary oak: release the seal at (38,24) to free Acorn06. The existing
  runner can still carry an uncollected, unlocked acorn; defeating it or its
  bounded carry timeout releases the real pickup.
- Six acorns and the existing three opened gates start the return escape.
  Two pre-existing entrance sentries activate with the original warning.
  Return through the opened park to the actual boarding Area3D. A 65 s
  escape bonus is optional; running out of bonus time never fails the level.
- Optional gardener notes and supply caches reward exploration. The final
  result includes score, time, notes and a play-style rank. Personal best is
  persisted in the existing settings file and shown in the level menu.

There are still exactly 14 finite enemies: the original five and the original
nine encounter guards. No respawns, infinite waves, kill quotas, increased HP,
changed gun cadence or extra collision layers were introduced. Campaign flow
remains intro/menu -> Level 1 -> Level 2 -> Level 3 -> menu.

## Ownership and commands

- game.gd retains acorns, keys, three real gates and the campaign handoff.
- level1_heist.gd owns local heist state, focus validation, actions, alarm,
  scanning, noise dispatch and scoring. Presentation reads it; SignalBus
  continues carrying global facts/audio rather than serving as a locator.
- level1_heist_data.gd is the authored device/footprint source shared with
  Props' physics and the existing Recast navigation bake. Every new device is
  on walkable ground. Devices are not remotely usable: reach, view direction
  and actual world-ray clearance are checked before activating.
- E interacts, C toggles quiet movement, Shift dashes. Phone has separate
  contextual action, quiet and dash controls beside the existing move/look/fire.
  Explicit finger ownership rejects foreign releases and duplicate emulated
  mouse events. Pause/focus loss releases both new and existing controls.
- Quiet movement is 55% walking speed with a lowered eye position; identification
  range is shorter, especially on grass. Distant guards have a facing cone and
  a brief identification delay. Close contact remains dangerous.
- Dash uses the production CharacterBody3D collision path: 0.24 s at 11.5 m/s,
  3 s cooldown, no invulnerability or teleport. It is noisy.
- Sound priority: gunshot > bell > ordinary alarm/dash > footsteps. Open gates
  connect sound responses between sectors; closed gates cannot order a guard
  into another sector. Bells direct existing guards to the false sound source,
  provide a brief opportunity to slip away beyond 3 m, and have a 12 s cooldown.
  A gunshot overrides the distraction; a footstep does not immediately erase it.
- Relay/oak work needs 2/3 s total. Leaving reach/LOS, firing, damage or a dash
  interrupts it. Accumulated work is retained; pause freezes it. Completion and
  rewards occur once. Unlocking rechecks actual overlaps so a player already
  standing in a sealed pickup does not have to leave and re-enter its Area3D.
- Forced escape alarm is excluded from the infiltration rank, so the stealth
  rank remains attainable. The saved best score never decreases on a retry.

## Presentation and rendering

New mechanical silhouettes, colored glass/inlays, seals, status markers and
security footprints use shared resources and bounded geometry. No new dynamic
lights, viewport, World3D, fullscreen effect or downloaded art pack was added.
The prior four park palettes, pond, architecture, fireflies and attached
legendary-oak lanterns remain. Four deterministic small synthesized OGG cues
are reproducible with tools/generate_heist_audio.py.

Static bench/lamp/trim primitives sharing a material are combined within their
existing spatial block. Every transformed triangle/normal is preserved; moving
pickups and gates, masonry occluders and foliage batches remain separate.
Trees retain authored full-detail surfaces and gain renderer-selected index LODs
through ImporterMesh. Existing guards also stop distant simulation beyond 32 m.

At the same frozen native Forward+/1280x720 poses, original 1.25 -> final heist:

| View | Draw submissions | Primitives |
| --- | --- | --- |
| Entrance | 564 -> 527 | 436382 -> 310600 |
| Pond | 202 -> 212 | 189704 -> 143170 |
| Golden oak | 174 -> 182 | 192722 -> 156326 |

New interactive objects add some submissions at the pond/oak; there is no claim
of a reduction at every view. The entrance has about 29% less geometry despite
the added mechanisms/relocated sentries. LOD comparison retained the full visual
composition; sampled images were effectively unchanged. Software Vulkan counts
are diagnostics, not phone FPS, battery, touch-feel or device compatibility proof.

## Validation and continuing

- Keep the prior 18 behavior gates and all renderer/race/intro/export gates.
  CI adds the focused heist fixture and a complete no-shot input route, for 20
  behavior gates. It also adds native heist/phone-aspect captures before export.
- All three full Level 1 routes use real movement, aiming, legal fire, E/local
  production commands, physics pickups, gate tweens and actual car boarding.
  They do not teleport actors or override health/ammo/progress. Main/exploration
  routes reached Level 2; the noncombat route also reached it with zero shots
  and health remaining. These are automated drivers, not human difficulty or
  completion-time estimates.
- Focused fixtures cover locked/already-overlapping pickups, wrong/right lenses,
  range/wall rejection, real sweep exposure and wall cover, interrupted/resumed
  work, pause, sight/quiet behavior, live-guard distraction/priority/cooldown,
  actual GUI touch ownership/emulated-mouse rejection, physical dash/walls,
  defeat shutdown and settings persistence without losing audio preferences.
- Local full regression, native Forward+ and Compatibility scene/color checks,
  and native heist frames at 1280x720, 960x540 and 1600x720 passed. Final matching
  release CI and the actual APK manifest/packed resources must still be checked.
- Android remains arm64 debug, package com.acornhunter.carolina, filename
  build/AcornHunter-MoonlightSprint.apk, Forward+ on desktop and Android,
  non-HDR 2D. Release is 1.26/code 27. Intro and Level 2/3 gameplay are retained.
- Stage authored paths only. Ignore incidental .import/UID/GLB texture extraction,
  .godot caches, screenshots and scratch logs. Do not copy those into the repo.
- After current-head CI passes, get device feedback on play rhythm, readable
  hints, thumb reach and actual FPS; do not equate native software rendering
  with that acceptance. Fix build/runtime/progression before further art work.
