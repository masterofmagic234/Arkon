# Android 1.49 — garden encounters, articulated defeat and animal voices

The owner approved the Level 1 design critique: replace the repeated maintenance
walk with distinct combat situations and an active escape. The owner explicitly
reports excellent 1.48 device FPS and permits more squirrels; do not impose the
previous suggested two/three-actor ceiling as a performance requirement. Groups
and activation timing serve encounter design. Runway sound generation is
authorized. Retain Compatibility and the successful 1.48 foliage/material/GI
implementation. Keep PR11 a draft; do not merge automatically.

## Mission and space

Darina still needs six acorns for a craft. Carolina takes the squirrels' guarded
winter stock. The new route is entry checkpoint combat, nearby pump fuse and
one installation action, pump counterattack, western glass-gallery combat,
guardian, six-acorn pickup and physical interception on the way to the 240.
The existing manga departure then leads into Level 2. No stealth or peaceful
completion is introduced.

The one fuse is at `(28,3,11)` beside the existing pump panel `(23,3,19)`.
There is no mandatory three-part tour or prescribed three-valve combination.
Power starts the contained water and lowers a physical service bridge across
the pond. The gallery's key is earned through its encounter; gallery and pump
completion unlock the hydraulic store gate. The gallery uses the actual west
glasshouse wing and its columns, rather than a second fight on the boss plaza.
Existing central stairs and the open western end provide physical access.

Twenty-four ordinary squirrels and one guardian are prepositioned with stable
IDs0–24 (the original guardian remains3). Entry, pump defenders, pump
counterattack, gallery and escape each have four ordinary actors; the grove
and pavilion have two each and remain optional rewarded encounters. Assault,
flanking, throwing and suppressing roles have distinct engagement behavior.
Readable overlapping attacks replace the global one-attacker queue. The
guardian's visible recovery window closes after its accepted hits and its
second phase must occur in the full input-driven route.

Chapter completion provides an explicit resource reward and checkpoint. Pump
activation also guarantees resources before its counterattack, once only.
Ordinary saving/loading does not manufacture HP/ammunition. Version3 saves
preserve completed encounters, individual defeated IDs, used supplies and retry
snapshots. Versions1/2 retain earned acorns, guardian victories and opened
latches; newly introduced patrols must not revoke completed progress.

The route map and current goal follow actual chapter state. Smaller short
world labels leave interaction prompts and squirrel subtitles readable.

## Defeat and audio

Both supplied squirrel identities retain their actual meshes, texture data,
skin weights/rest hierarchy and sixteen living clips. The old rigid death roll
is replaced by directional articulated clips, with separate limb/head/tail
motion and grounded final poses. Incoming hit direction selects the collapse;
restoring an already defeated actor samples its final rest directly. Settled
bodies stop unnecessary animation updates. Contact/pose evidence and source
identity belong in rig149 provenance and the focused defeat checks.

Six accepted eight-second Runway sound-effect takes cost 48 credits in total;
task IDs, prompts and original MP3 hashes are recorded under
`art/level1/audio149`. Thirty prepared mono44.1kHz/16bit PCM vocals provide
ordinary/guardian warning, attack, pain, defeat and rally variants. The original
35 weapon/footstep/impact/ambience PCM files remain unchanged. Raw authoring
recordings and the audition reel remain excluded from Android.

Animal calls are spatial, varied and limited against overlapping chatter.
Mission captions convey their meaning in Russian. Projected encounter calls
use their own distance/gain policy, restored before pooled voices are reused.
Player shots/damage remain protected; pause, mute and SFX volume still apply.
Recorded native PCM and independent checks provide mixing evidence. File and
waveform checks alone do not establish subjective sound quality.

## Validation and release

Retain unrelated Level2/3, character, weapon, cinematic and audio acceptance.
Rewrite obsolete three-part mission assertions around the new actual rules,
including early reward/departure rejection, migration and checkpoint retry.
Fresh normal-input playthroughs must perform all main battles, actual bridge
traversal, both guardian phases, reward, escape and car-to-film-to-Level2.
Native evidence now samples fights as well as walking; sampled footage is not
a continuous real-time gameplay recording or a phone FPS measurement.

Local 4.7.2 fresh-input native acceptance completed with 77 actual shots,
74 accepted hits, five guardian recovery windows, both phases, all 21 mandatory
actors' animated/settled defeats, all four phase voice events, physical bridge
traversal and car/film/Level2 completion. The 70 sampled720p frames encode to
23.33seconds at3fps; this is not a measured human completion time. Subsequent
non-actionable prompt cleanup and raised-leaf collider fixes are covered by
focused rules/bridge checks; final CI records the route from the committed
source again. Closed leaves block walking/dashing from both approaches, and
powered crossings work both ways without changing the original pond collider.

Final imported rig/defeat, mission state/rules/evening/bridge/AI and vocal checks
passed. Actual native voice PCM verifies left/right calls, protected centred
weapons, limiter, pause/mute, burst/queue recovery and a projected escape call
at61.85m,17.46dB above the recorded ambience. Final common-imported tank poses
were visually reviewed after correcting a forearm twist; the original meshes,
weights, textures, rest hierarchy and sixteen living clips remain exact.

Five native production garden views retain the former500call/260ktriangle
limits, including the expanded actors and new props. Entry measured421calls
and209126triangles. This is workload evidence, not device FPS.

The retained 1.47/1.48 foliage/material ABBA gate isolates the baked world from
campaign actors and new mission props equally in both profiles. This preserves
its original workload/CPU/traffic thresholds while the expanded production
mission receives separate actual-input/native acceptance. Do not describe that
isolated renderer fixture as the complete 25-actor game's FPS.

Android1.49/code50, Godot4.7.2, arm64, the existing package and certificate.
Final source/merge tree, all three CI jobs, four official archive digests/CRCs
and independent actual signed-APK checks must be recorded in PR11 before
delivery. The new package inspector must retain all previous gates and add
actual new death skin/voice PCM/source semantics, without claiming its empty
resource fixture proves full gameplay.
