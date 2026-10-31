# Android 1.53 — guardian, arrival and readability

Current branch: `fix/level2-final-game-flow`, PR11. Keep it draft; do not merge.
Godot4.7.2, Compatibility, Android1.53/code54. Exact signed build/CI evidence
belongs in PR11 after completion. No Android hardware performance claim.

## Garden

The boss previously used a14m circular leash around its spawn outside the real
arena centre. It could chase/charge down the front staircase, then fail to find
an attack route while armoured. The guardian now keeps the real doorway limit;
retreat remains open to the player. Existing out-of-arena boss positions return
by physical movement, with recovery on blocked contact. Charge facing follows
the announced attack line, rather than sliding velocity. Existing jaw/ears/head
bones carry anticipation, attack and panting expressions; no new actor meshes.

The last tread and upper landing shared a coplanar positive-area overlap. Tread
and foundation depth overshoot also duplicated side faces. Exact face limits
remove those overlaps while preserving110 tread heights and four foundations.

Taya and the240 begin on the outside road. First patrol activation/radio waits
until the player approaches the park; existing earned saves are retained.

An original three-panel illustrated guide pauses at the first earned gate
opening. Explicit Continue/touch or keyboard resumes; no guide replay for an
already-open gate. Keep its responsive bounds and real-input tests.

All14 park lamp faces are cyan/lilac. Four service beacons and two road bollards
use two batched static meshes, including terrain-following additive pools.
The existing six shadowless OmniLights keep their energy/range. No new realtime
lights, shadow maps, viewport or postprocess; the additional geometry has a
small cost and is not claimed literally free on every phone.

Nine new guardian warn/attack/rally PCM takes reuse two generated recordings;
provenance and exact editing recipe are in guardian153/PROVENANCE.json. Existing
hit/defeat, squirrel and foley recordings/mixer limits remain. No fabricated
claim that waveform validation equals subjective listening.

## Pursuit and diner

Vehicle target readiness used to be trusted forever after its first frame.
The existing target now rechecks public state and actual draw acknowledgement,
restores its original world/camera/consumer after silent loss, and does not
reinitialize a healthy target. The initiating Android driver event is unproven.

Taya retains the original authored source strips and8walk poses. Only shoulder
sampling is narrowed, preserving crown, physical radius and muzzle. Burgundy
hair highlights read in native pixels. A small bobbing red world arrow points
to the real current reception/cook/pizza/car target and hides in combat/film.

The user's requested HM2 comparison is delivered separately. It uses actual
frames from the official gameplay trailer and supplied reference; the full
YouTube walkthrough was unavailable and must not be claimed watched.
