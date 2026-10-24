# Level 3 — overhead pixel squirrels, Android 1.17 / code 18

Read this first. Repository masterofmagic234/Arkon, branch
fix/level2-final-game-flow, PR 11. Do not merge. Started from actual published
HEAD cc487dd0c9f8b088dd1139a609e9d483ee821edf, successful Actions #1017.
The user requested Level 3 opponents in the same existing style and clothing,
but visibly squirrels from overhead. They did not request combat/layout changes.

## Implementation

- Grey squirrel heads, visible ears and broad curled tails are combined with
  every original eight-frame gunman/bat/butcher strip. The original clothing,
  weapons and frame poses remain. The two existing resting/body-pool poses
  gain a closed-eyed squirrel head and flattened bushy tail too.
- scripts/level3_squirrel_skins.gd selects the prepared skins. Level3Enemy
  changes only the walking and resting sprite paths. Existing 9fps walking,
  gunman offset, bat/butcher quarter-turn, 0.78 scale, idle/windup/stun/death,
  hitboxes, weapons, damage, AI, doors, mission and campaign remain unchanged.
- Final atlases have 80px padded frames. Their centres exactly preserve the
  original actor origin so padding cannot shift aim/contact positions.
  Runtime still uses one AnimatedSprite2D per actor and the existing shared
  immutable frame/texture caches. No extra layers, lights, nodes or updates.
- Built-in ImageGen created the pixel anatomy from the existing sprite style
  and grey Level 1 squirrel reference. Immutable source, exact prompt and
  processing notes are in assets/level3/squirrels/ASSET_PROVENANCE.md.
  tools/bake_level3_squirrels.gd prepares the final PNG strips offline through
  deterministic trimming, hard alpha, palette conversion and frame assembly.
  Source files from the original asset pack are unedited. Generated anatomy
  source/bake manifest stay in the repository and are excluded from Android.

## Verification

- The existing thirteen behavior gates include actual Level 3 mission input,
  live combat, order pickup, return and menu transition. The first new-art
  playthrough still defeated all ten live guards with 15 shots, 76 HP, and
  completed in 73.783 simulated seconds. This is an automated driver result.
- Level 3 smoke also rejects human fallback paths, missing walking frames,
  a changed 9fps cadence, a lost nearest pixel filter or duplicated frame
  resources among enemies of the same role.
- tools/level3_squirrel_capture.gd stages the three actual production roles,
  renders all eight walking frames at four headings, then captures the actual
  warning/stun/resting presentation. --original permits the same-pose supplied
  human sprite reference. These are staged visual QA, not a gameplay replay.
- Same-host native Compatibility/Mesa samples match original draw/primitive
  counters: lineup 38/916, warning 50/1426, stun 47/1330, resting 33/724.
  Larger transparent texture canvases still add some sampling area. Do not
  infer phone FPS or claim unchanged GPU cost from equal draw counts.
- Standard level3_capture.gd inspects eight whole-level/mobile views. Existing
  world and combat art are retained. Phone FPS and user art acceptance remain
  unmeasured. No Level 1/2 implementation or tuning changed.

## Packaging and continuation

Android is arm64 debug, package com.acornhunter.carolina, version 1.17/code 18,
existing build/AcornHunter-MoonlightSprint.apk. Verify the final remote branch
HEAD, successful matching Actions run and APK before delivery. Do not claim a
green build from an older SHA. Keep current CI and the thirteen behavior gates.
Read HANDOFF_2026-10-15.md for Level 1 and HANDOFF_2026-10-13_SPRINT.md for race
history. Stage only authored files and the four deliberate new texture imports.

The prior checkout was a worktree whose parent .git was reclaimed during the
pause. A fresh isolated checkout was created at the verified published HEAD;
no uncommitted work was discarded. Local runtime/captures are scratch, not
game assets. Keep tested changes published in small targeted commits.
