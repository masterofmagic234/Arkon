# Level 2 radio, solid cars and pursuit tactics — Android 1.21 / code 22

Read this first. Repository masterofmagic234/Arkon, branch
fix/level2-final-game-flow, PR 11. Do not merge. Starting verified published
HEAD 791735a078d96a930d4437aeedb8d82114178b5e, green Actions #1027 / 1.20.
The user requests squirrel-language radio/subtitles, pilot replies, genuine
helicopter ingress/egress, solid opponents and overtaking/brake-check tactics.
Earlier authorization covers publication/build. Leave Levels 1 and 3 intact.

## Final behavior

- `race_vehicle_contacts.gd` replaces impulse-only contact detection with
  continuous separating-axis tests for oriented 1.8 x 4.4 m car bodies.
  Swept relative motion catches fast crossings; four constraint iterations
  resolve all six player/AI/AI pairs, even at rest or below 5 speed units.
  Contact velocity is shared; bounded impact/sound cooldowns remain separate
  and never disable solidity. Position correction persists in canonical
  route progress, respecting the grid offsets and barrier sweep. If a rail
  prevents one car moving, the other gets the remaining separation.
  `race_barriers.gd` now supports backward as well as forward sweep sampling.
- The helicopter starts 90 m behind the player at 24 m altitude, flies in
  over four seconds, then performs the existing 2.4 s approach / .75 s drop.
  The target accounts for this flight time: max(300, speed*7.8+65) m ahead.
  The blocked side still locks at the warning, leaving a 3.8 m escape lane.
  Departure continues flying at least six seconds and until a conservative
  8 m aircraft sphere has left the actual shared Camera3D frustum. Only then
  may the aircraft hide. No in-frame fade or fixed-timer disappearance.
  Rendering reports visibility; headless simulation retains a timed fallback.
  Tunnel roof occlusion stays; attacks cannot start with the car in a tunnel.
- One attacker at a time alternates ram attempts with passing/brake checks.
  The passing car uses real steering/throttle to gain >13 m before merging
  into a locked lane within +/-1.4 m of centre. It announces braking for
  1.15 s, brakes at .78 for up to 1.25 s and withdraws. It cannot chase the
  player's late dodge or block both sides. Brake checks exclude the tunnel,
  sharp bends, steep grades and the final 400 m. A pass can time out if it
  fails to earn the lead; there is no passing teleport or speed boost.
  A small passing speed-governor target allowance offsets its deadband on
  gentle curves; actual grip, powertrain, 219 km/h cap and player handling
  are unchanged. Support cars yield behind; air attacks wait for a ground
  maneuver to finish. A car already ahead accelerates through the spike
  escape lane instead of braking to get behind and trapping the player.
- `race_radio.gd` owns a fixed-clock single radio channel: patrol Belka-1/2/3,
  dispatcher Duplo and pilot Orekh-1. Original Russian subtitles describe
  stolen acorns, sectors/direction, ram/pass/braking intentions, air support,
  spike deployment and roadblock requests. Dispatch denies roadblocks due
  to civilian traffic; no nonexistent roadblock is presented as active.
  Pilot replies include ingress, deployment and tunnel visibility. Air
  request/reply variants alternate between attacks. Idle banter fills gaps.
- `chatter.ogg` contains nine original 3.2 s voice takes (28.8 s total),
  offline-synthesized voiced squirrel chatter/clicks/radio squelch. Three
  speaker profiles share one seekable Vorbis atlas and one player. No human
  recording, borrowed game audio or runtime synthesis. Generator/provenance
  are in tools/generate_squirrel_radio.py and assets/level2/pursuit/README.md.
- Subtitles show the active callsign/sentence in a wrapping top-left panel,
  above road warnings and clear of controls/location signs at mobile sizes.
  Radio events have priorities, expiry, six queued messages maximum and
  reply dependencies. Tactical traffic may interrupt idle banter. One voice
  plays at a time and stops before the next atlas take. SFX mute/volume and
  pause apply; muted players retain subtitles. Finish/failure clear both
  queue and subtitle panel; retry/scene exit release state/audio.

## Validation / delivery contract

Local Godot 4.7.2 headless checks: pursuit mechanics, new radio/tactics,
park/race/traffic/drivetrain/camera regression, second-pass touch/finish and
full campaign. New adversarial checks cover stopped/slow/fast/rotated car
contacts, a second crossing during impact cooldown, a bridge rail pin,
non-colliding passing lanes, real-input passing/braking, warning duration,
escape clearance, queue expiry/reply ordering, audio atlas timing, matching
subtitles, three UI sizes, volume/mute/pause/finish/exit.

The complete production-input escape retains the 210 +/-6 s gate and reacts
to actual spike lanes and lead-car warnings by ordinary steering. Current
local result: 210.05 s, five completed drops, zero spike hits, five player
contacts, one genuine overtake/brake check, 0.000% AI offroad samples; actual
Continue reaches the diner. No teleport, immunity or disabled opponents.

Native Forward+/Vulkan checks capture six staged production scenes including
pilot subtitles and a brake check. They verify visible real-framebuffer
geometry, rotors, offscreen ingress/complete egress, tunnel roof occlusion,
continuous high-speed flight and reaction distance with the moving player.
These are staged shots, not a recording or phone performance measurement.

CI adds radio/tactics as the sixteenth behavior gate. Existing paired
whole-game renderer comparisons, native race geometry and expanded aircraft
checks remain before Android export. Captures stay outside res://; build/*
and generation sources remain excluded. Release is Android 1.21/code 22,
arm64 debug, package com.acornhunter.carolina, Forward+ on desktop/mobile.
Final exact-head CI, merge-tree match and APK verification are pending.

Publish small commits to the existing branch using guarded ref update;
never merge PR 11. Verify exact successful head, artifact ZIP digest/CRC,
APK manifest/ABI/project settings, compiled new scripts and voice import,
all eighteen squirrel atlases, and absence of QA captures before delivering.
Save the verified APK/preview through Library. Stage only authored files;
restore incidental import drift only AFTER all local Godot QA is done.
Read HANDOFF_2026-10-15_PURSUIT.md for the original airframe/strip implementation,
HANDOFF_2026-10-15_FORWARD_PLUS.md for renderer/color handling and
HANDOFF_2026-10-15_LEVEL3_RIG.md for unchanged squirrel animation.
