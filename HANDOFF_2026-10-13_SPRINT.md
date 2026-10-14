# Current follow-up — Android 1.13 / code 14, 2026-10-14

Supersedes historical handling and scenery notes below. Started from verified
branch HEAD `56af0f487ab867b580685b175d3318d2cadbdb4c`, Actions #1009 success.
Branch stays `fix/level2-final-game-flow`, PR 11. Do not merge. Verify the final
published HEAD and its matching successful CI/artifact before APK delivery.

## Result of the six phone reports

- Touch steering uses an exact critically damped spring; the chassis has a
  filtered yaw rate. Speed-dependent steering lock also changes smoothly when
  braking or hitting a rail. Front lock rises from 27.5 to 36.7 degrees at rest
  and from 11.5 to 19.5 degrees at top speed. Actual animated wheel angle now
  determines heading authority. Keep nose-bound camera, manual world-X,
  60 Hz physics / shared interpolated display poses, drivetrain and 219 cap.
  Grip still requires braking for the compact corners; normal steering is quiet.
- Ground mesh, sprite roots and sightlines share a finite-width embankment /
  retaining-cut profile. Upright billboard polygons use the shared lens/roll.
  Close terrain probes and conservative crest clipping hide foliage behind
  nearer earth/asphalt, rather than drawing trees over the foreground road.
- Removed the separate 200 m wide floating roof patches. Continuous narrow
  underground earth uses the existing ground material, perspective depth and
  outdoor grass lighting, behind the actual vault lining. Mouths meet level
  earth with stone/concrete arch trim; panelled retaining walls cover the full
  descent/exit ramp, with continuous caps. No mountain at runtime.
- City moon follows the source panorama halo UV (.737, .158) through the same
  yaw, parallax, scale and wrapping as the city. The separate high forest moon
  fades away as the city comes in. Moon size follows the halo region.
- Twenty independent staggered lots use distinct dimensions, setbacks,
  heights, colors, roofs and facade layouts. Eight available shop signs; the
  actual lots include at least five distinct shop identities and five building
  forms. Warm/dark windows, shutters, mullions/sills, porches/steps, chimneys,
  balcony, roof utilities, fences, mailboxes, planted yards, parking bays,
  storefront stock/shelves, awnings, benches, bins and pavement boards are
  authored into one cached atlas batch. Signs face correctly on both sides.
  Small details stop past 130 m; primary architecture/windows remain to 480 m.
  Closed box faces cull away from the camera. Existing scenery budgets retained.

## Verification and delivery

All eleven behavioral fixtures pass locally; 99 geometry poses retain the
2400 triangle / 4000 transformed-point / 14 surface caps. Distinct-lot/shop
regression, steering step/reversal/noise, 35 degree stationary lock, 60/120 Hz
consistency and real full-speed versus braked corner checks pass. Nominal
production-input sprint: 209.75 s, seven sectors, rivals 0% offroad, fourth
of four, actual Continue loads Level 3. Finish stays physical, not timed.
Native Compatibility checks pass: 124/124 live interpolated display poses,
503 confirmed visible-asphalt foliage probes on two forest grades, five
bridge/approach road depth poses, closed portal hides a rival / open vault
shows it. Native phone-aspect captures inspect forest, mouth, detailed lots
and the halo under yaw. These validate geometry/pixels/continuity, not phone
FPS, speaker behavior or the user's acceptance of the new steering feel.

Export arm64 debug, package `com.acornhunter.carolina`, 1.13 / code 14. CI keeps
Ubuntu 24.04 / modern Mesa, eleven behavior gates before export/upload and the
bounded native gate. Publish targeted commits with one final ref update.
Restore unrelated import stubs only after native QA; reimport before any
subsequent native checks. Keep original Camry assets and the user's root RAR.
Deliver only the matching successful final-head artifact, verifying ZIP digest,
APK manifest/version/package/ABI/resource remaps before saving the APK.

---

# Current follow-up — Android 1.12 / code 13

Supersedes the historical 1.11 notes below. Start was verified HEAD
`1134d9f87767893e90cec740e6cb659badcae461`, successful Actions #1007.
Branch remains `fix/level2-final-game-flow`, PR 11. Deliver the matching
successful final-head artifact after ZIP digest and APK manifest checks.

## User feedback and resulting behavior

- Fixed stepped 240SX motion: physics remains 60 Hz, but the road, sole
  shared camera, player mesh/wheels and all rivals consume the same
  interpolated presentation poses. Input, collision, rank and audio remain
  authoritative. The car world disables Node3D double interpolation. Manual
  capture/geometry tools suspend physics and explicitly bind the live state.
- Route has 222 segments / 8.88 km, ten compact corners, 81% straight
  segments. Corners are separated by acceleration straights. Speed-dependent
  heading and a real lateral-acceleration yaw limit require braking rather
  than only producing endless slip. No automatic player centerline following.
  219 km/h cap, four-speed automatic and acceleration remain unchanged.
  Nominal input drive: 209.87 s, all seven sectors, 0% rival offroad samples,
  actual Continue reaches Level 3. The test driver finishes fourth; winning is
  not automatic. This is calibration, not a forced timer or human lap time.
- Tire squeal now reflects slip/excess steering demand or heavy braking,
  rather than normal high-speed steering position. Moderate steering is quiet;
  hard fast steering/braking retain sound and stationary tires stay silent.
- Removed the mountain from runtime. A flat forest covers a tunnel sunk 10 m
  below ground. The bridge ends at 4080 m, a forest connector reaches level
  ground, then the final 300 m descend between retaining walls. Tunnel roof
  remains under earth; concrete mouths have real openings and straight buffers.
- Scenery sprites and solid architecture share an atlas and one ordered
  surface per distance range. Trees are painted before closer bridge members,
  houses and fences. CPU sightlines clip vegetation below intervening terrain
  and bridge deck; forest trees are omitted inside the vault. Original cutouts
  are reused at 512 px with mipmaps/VRAM compression; no new generated tree art.
- The moon is raised to the top of the playfield and reduced in apparent size.
  The city panorama retains its source aspect ratio and stable physical size.
- Seven sectors: forest 0; fields 1520; bridge 3120–4080; forest descent
  4080–5120; underground tunnel 5120–6400; outskirts 6400–7440; city to 8880.
  Outskirts contain pitched-roof homes, street-facing warm windows/shutters,
  shops with cyan/pink/green Cyrillic neon signs, trim, doors and street lamps.
  Houses begin beyond the exit ramp rather than being buried beside it.
- Swept barriers now also sample intervening Z boundaries; moving from outside
  a portal to an endpoint inside its curved tube cannot tunnel through its face.

## Validation and packaging

All eleven behavioral fixtures passed locally. Geometry checks cover 99 views,
including the new outskirts, at three sizes/headings under existing budgets.
Motion regression checks 120 Hz intermediate poses and quiet gentle steering;
the same full-speed corner meets the rail without braking and is clean with
an early brake. Native CI fixture now uses `--fixed-fps 120`: the actual live
physics/process/model path advanced on all 124 sampled display frames, with
model and world using one pose. This is a clock/continuity check, not phone FPS.
Native pixel comparisons retain foreground road depth and closed/open portal
rival occlusion. Final native captures inspect bridge, forest ramp, tunnel and
outskirts. Device FPS and user acceptance of steering remain unmeasured.

Android arm64 debug, `com.acornhunter.carolina`, 1.12 / code 13. Preserve the
Camry from the user's root RAR and its real 63,813-triangle models. CI remains
Ubuntu 24.04 / Mesa 25, eleven behavior gates before export/upload, bounded
native checks after artifact upload, branch concurrency. Do not reintroduce
the Ubuntu 22.04/Mesa 23 software-rendering timeout. Stage authored paths only;
restore unrelated import stubs after native QA. Do not merge PR 11.

---

# Current follow-up — Android 1.11 / code 12

Read this section first; the historical 1.10 notes below are superseded where
specified. Started from verified published HEAD
`47524cb2450915d45e71e3fd5a7cdcd09935b758` (user added the new Camry RAR), with
successful Actions #994/#995. Branch remains `fix/level2-final-game-flow`, PR 11.
Route checkpoint `5a6e6b2`; mountain/depth checkpoint `f2d5a5c`; the live Camry
and packaging commit includes this updated document. Recheck the actual final
branch HEAD, its Actions conclusion and artifact before claiming green CI/APK.

## Result

- 235 physical segments / 9.40km, one Forest → Fields → Bridge → Descent →
  Tunnel → City sprint. 20 manually driven bends instead of 12. Normal shifts
  56m over 6–7 segments, hairpins 72m over 7; physical heading authority .58
  retains the existing speed-sensitive steering, stop lock and swept walls.
  The main camera still follows the exact nose direction. Gas-only stops at
  the first bend; no automatic world-X following. 219km/h and drivetrain unchanged.
- New boundaries: fields 2080m; bridge 4080–5040; descent 5040–6080;
  tunnel 6080–7360; city 7360–9400. Actual elevation, scenery, notices, shader
  field tint, minimap, AI and ranking share the authored route. Extending the
  original scenic blocks alone would have weakened corners, so their spans
  remain compact and additional bends/straights provide length.
- Nominal production-input drive is 210.10 simulated seconds headless and
  210.37 native GL, first of four, 0% AI offroad. Target 210 seconds is a
  calibration check, not a forced timer finish. Human time depends on driving.
  Existing MP3 measures 255.768 seconds; the user's intended 3:30 music is the
  route target, and this pass does not trim/replace the current music source.
- Distant and foreground ground/architecture are split at the exact mountain
  portal plane. Distant road/tube stay behind the actual rock hole; foreground
  asphalt, bridge deck and steel members stay in front. No doubled full-screen
  ground-shader discard pass: each triangle belongs to one distance batch.
- The mountain is a broad asymmetric rocky massif with receding contours,
  dominant-plane texture mapping and a separate raised cutting: graded stone
  banks/retaining faces, outcrops, subdued grass and sparse hillside pines.
  Cached geometry and near/viewport clipping are retained. Entry/exit holes
  and solid roof/side barriers remain physically clear/opaque.
- New Camry from the user's root RAR is actual live 3D geometry, 63,813 original
  triangles per car. Static parts are batched to three surfaces, normal/albedo
  retained at 2K with mipmaps and VRAM compression. Three rivals share the
  player's single existing viewport, camera and World3D; the viewport now spans
  the playfield. Continuous world yaw, authentic size/ground contact, physical
  grade and independent running/brake emission replace nine atlas angles.
  Per-fragment terrain/mouth/vault ray tests prevent see-through rivals.
  Asset hashes/process are in assets/level2/ASSET_PROVENANCE.md.

## Verified locally

All eleven existing headless fixtures pass with a strict parser/runtime/ERROR
check: four park fixtures, vehicle smoke/drivetrain/barriers, complete 3:30
sprint, park/race geometry, two diner fixtures, input/finish regressions and
full campaign/second cycle. Real Continue reaches Level 3. 81 scenery poses at
three sizes/yaws remain finite/clipped under 2400 triangles, 4000 transformed
points and 14 surfaces. Live model tests verify all three rivals, one camera,
physical proportions, ground projection across grade/yaw and separate brake lamps.
Native Compatibility inspection covers 34 views plus nine final approach/turn
captures after cutting/compression. Native pixel regression compares frames
with/without mountain and rivals: foreground bridge/approach road remains
unchanged, rival behind closed rock disappears, rival through the hole appears.
The native gate runs after successful APK export/upload in CI using Xvfb;
all eleven behavioral gates still precede export. Its failures still fail the
workflow, but do not discard an otherwise built artifact. The initial
CI attempt stalled at that step; the follow-up bounds package installation,
forces termination after the native deadline, uses the verified 1600x900
virtual desktop and drains native resources on assertion failure. Pixel
coordinates follow the actual viewport. It passes locally on both 1280x720
and 1600x900 desktops after import. Per-branch concurrency cancels outdated
push/PR runs when the corrected head is published. Verify the latest run;
the older stalled attempt is not a successful APK build. The bounded attempt
also timed out before its first framebuffer check on CI Mesa 23/LLVM 15,
while local Mesa 25/LLVM 20 completed. The rival occlusion shader now uses a
uniform loop bound and a single final discard instead of 35 expanded discard
branches. The same native occlusion assertions pass locally after this change;
verify its actual CI result before claiming the driver issue resolved. Native
capture additionally unpauses Xvfb startup and forces a fresh rendered frame
before synchronous readback, rather than awaiting a post-draw signal from an
inactive/static virtual window. Setup-frame markers distinguish model setup
from framebuffer capture. All original occlusion assertions are retained. Run #1003 advanced frames
at 24–30 seconds each on Mesa 23 llvmpipe, exhausting the 60-second cap.
The fixture now disables automatic rendering, draws only each actual pixel
comparison at 640×360, suspends the vehicle viewport for road probes and
hides the unrelated player mesh for rival probes. Runtime rendering is
unchanged. Native deadline is 180 seconds with forced termination; verify
the latest result before claiming successful CI. Run #1005 exported/uploaded
the APK after all eleven behavioral gates passed, but native comparison frames
still took 8–20 seconds with the vehicle viewport disabled and timed out before
the rival assertions. CI now uses Ubuntu 24.04, matching the native Ubuntu
24.04/Mesa 25/LLVM 20 local host instead of Ubuntu 22.04/Mesa 23/LLVM 15.
The game code and native assertions are unchanged by this runner update.

Rendering submission timings in the scratch native budget report exclude GPU
and device FPS. True 3D traffic and a larger shared viewport change GPU cost;
phone FPS/touch feel and human acceptance of corner/art changes are unmeasured.
Do not infer phone performance from software renderer counters.

## Packaging/continuation

Android arm64 debug, package com.acornhunter.carolina, 1.11 / code 12,
`build/AcornHunter-MoonlightSprint.apk`. Eleven behavioral gates precede export. The native depth gate follows
artifact upload and still fails the workflow on errors. Old traffic atlases and source/cache models
are excluded. Preserve the user's root RAR. Stage exact authored paths only;
never include generated embedded textures, UIDs or .godot caches. New explicit
Camry JPEG/scene imports are intentional. Restore unrelated import stub
changes only after local native QA, then reimport before future native runs.
Do not merge PR 11 or publish elsewhere without request. Deliver only the
successful final-head artifact after checking its ZIP digest and APK manifest.

---

# Arkon — Moonlight Sprint and living park, 13 October 2026

## Current follow-up — Android 1.10 / code 11

Starting published HEAD `b0d632fbb0d7b339c68185f03d65724e9b4b3ed4`, Actions
#990/#991 successful. User accepted 1.9 phone FPS, but reported straight-looking
road despite the map, too few corners, an abruptly appearing ugly mountain,
unreadable high-speed location names and stretched city after tunnel exit.
Read this section before the historical notes below. Curve checkpoint:
`a49544fafef0752ad77a3b5a2867eebcdecdccb9`; this renderer/packaging patch follows
it. Recheck actual final branch HEAD and matching successful Actions before
claiming green CI or delivering an artifact. Old runs do not certify new code.

### Changes

- 1.9 restored lateral amplitudes but kept 10–12 segment scenic blocks, making
  road slopes much flatter than the former 5–7 segment arcs. Restore compact
  arcs, calibrate normal shift to 34m (hairpins remain 40m), and author twelve
  physical corners: forest 3, fields 4, descent 1, tunnel 2, city 2. Bridge stays
  straight. Same 120 segments / 4.8km, balanced lateral sum, sector boundaries,
  grades, physical finish, 0.38 heading authority, 219km/h cap and swept walls.
  Original player steering and nose-bound main camera retain their owners.
  Driver must brake for compact corners; no world-X assistance or depth-only
  curvature distortion. Regression measures every bend's physical slope and
  actual mesh deflection (at least 1.8 local road half-widths), not minimap marks.
- Replace the flat eight-facet mountain with cached irregular curved contours,
  real receding slopes, stone portal and terrain-following grass cutting.
  New ImageGen rock material is a 1024px mipmapped/VRAM-compressed RGB texture;
  grass reuses the existing meadow. Perspective world coordinates keep rock
  and shallow banks from streaking. One material sample per surface. Separate
  entrance/exit batches give correct depth order: entry rock hides the far
  tube outside its actual opening; interior walls cover exit rock. Foreground
  trees stay in front. No extra 3D world/model viewport or per-frame world-geometry authoring.
- Mountain is considered from 2.6km and gradually fades through distant mist;
  it is independent of the 480m small-prop cutoff. Near portal remains opaque
  and both holes physically clear. Source/atlas pixels and exact ImageGen prompt,
  hashes, mode and runtime paths are in assets/level2/ASSET_PROVENANCE.md.
- Bigger road boards use a fixed bold RGB atlas instead of shrinking/changing
  runtime font sizes. Projected board/UV clipping preserves complete labels.
  A non-interactive high-contrast HUD notice spans 300m before to 110m after a
  sector boundary (about 5.85 simulated seconds at maximum speed), so names
  remain readable while passing. City board stands 40m outside the tunnel;
  the bridge descent board is mounted above its parapet. Notices ignore touch
  input, pause and results lifecycle remains under existing presentation owner.
- City panorama keeps its source aspect ratio and constant height at a given
  viewport/lens zoom. Grade moves the horizon without resizing buildings.
  Outside sky/city is visible through the actual mouth during the final 200m
  of the tunnel, rather than first appearing at exit. Opacity is fully up by
  then. Deep tunnel still has an opaque dark background and closed vault.

### Validation

All eleven existing headless fixtures pass locally without parser/runtime
errors: four park fixtures, race smoke/drivetrain/barriers and natural sprint,
park/race geometry, two diner fixtures, second-pass input and full campaign/
second cycle. Natural production-input run: 117.77 simulated seconds, first
of four, 0% AI offroad. Native GL production-input run: 118.02 simulated seconds,
first of four, 0% AI offroad and actual Continue into diner. These are test-driver times, not human lap times. Gas-only still stops at the first bend
without world-X/yaw assistance; steering recovery and rotated-body contacts pass.

Native GL Compatibility captures inspect 33 poses: curve entry/apex/exit,
fields hairpin, tunnel bend, both wall-side steering views, distant/near/passing
mountain, city before/at/after exit and location board before/during/after passing.
Geometry regression covers all twelve bends, 81 elevated clipping poses, at
most 11 active scenery surfaces, bounded 2400 projected architecture triangles/
4000 transformed points, real mountain openings, camera matching and stable
city proportions. Production presentation checks readable notices at 219km/h
and ensure they cannot steal steering touches. Smooth distant mountain geometry
is already present before the old scenery cutoff, with continuous opacity.

CPU script submission, native GL Compatibility 1280x720, 22-frame median after
warmup, final code. These numbers exclude GPU/device FPS and are host timings;
phone feedback explicitly accepted the 1.9 baseline, not this untested APK.
| World Z | CPU submission, ms | Scenery surfaces | Architecture triangles |
| ---: | ---: | ---: | ---: |
| 580 | 5.45 | 5 | 408 |
| 1500 | 7.63 | 4 | 1004 |
| 2340 | 6.78 | 6 | 1092 |
| 3210 | 8.46 | 2 | 1630 |
| 3500 | 6.33 | 1 | 750 |
| 3800 | 5.86 | 1 | 758 |

The tunnel interior retains one architecture surface and 103 total host draw
calls at measured interior poses. Approach adds a mountain surface rather than
hundreds of individual commands. Existing cached projection, indexed batches,
224m tunnel detail range and road row budget are retained. User acceptance of
new corner feel/art and actual phone FPS after these additions remains pending.

### Packaging and continuation

Export arm64 debug, package com.acornhunter.carolina, version **1.10 / code 11**,
existing build/AcornHunter-MoonlightSprint.apk. Same workflow/runtime and eleven
pre-export checks. Deliver only a successful final-head artifact and verify ZIP
digest, APK manifest/package/version/architecture. Update local branch to the
published API commit. Do not merge PR #11 or publish elsewhere without request.

Stage authored paths explicitly. New texture/atlas .import files are intentional
mipmap/VRAM settings; other generated imports, extracted GLB textures, UIDs and
.godot caches stay uncommitted. Restore unrelated imports only AFTER native QA,
then reimport before future local checks. Scratch was pruned before this pass;
repo was recovered from GitHub and runtime from the official release ZIP with
verified SHA256. Native runner requires loopback TCP (Unix listeners unavailable)
and current extracted Xvfb libraries. Native scratch runner/reports are disposable;
Git-backed source and delivered APK are durable. Historical notes below describe
superseded corner counts, mountain geometry, labels, city sizing and versions.

## Historical P0 recovery — Android 1.9 / code 10

User reported severe Level 2/tunnel lag, automatic corner following, almost
transparent/passable walls and an unsupported tunnel tube. Starting published
HEAD was `d61eb54eda0b0b5bd0d4a910832dc224e17f84a5`, Android 1.8, with
successful Actions #988/#989. Those old checks did not cover these regressions.
Manual driving/physical walls checkpoint is
`8de91e45f210e1702314311ed9a96eca3967997a`; renderer recovery follows it in this
patch. Recheck the actual final branch HEAD and matching successful Actions
before downloading/delivering an APK; earlier successful runs are insufficient.

### Driving and collisions

- Restored the pre-scenery-rework shifts (26m normal, 40m hairpin) and maximum
  heading 0.38. Removed view-dependent curvature distortion. Retain exact
  nose-bound camera yaw, grounded 240SX, original speed-sensitive steering,
  powertrain/219km/h cap, 4.8km sprint and all six locations/grades.
- Removed the moving-edge clamp that carried world X around bends under gas
  alone. Only actual steering/contact changes world X. A swept body meets
  outside curve rails, field fences, bridge parapets, tunnel walls and closed
  parts of the portal. Frontal contact stops progress instead of moving the
  car with the road. Impact loses speed; deliberate steering permits recovery.
  Shared barrier dimensions include rotated-body and vaulted-roof clearance.
- The follow camera boom remains inside the tunnel at the wall without
  rotating independently of the nose. Gas-only negative check stops at the
  first bend with unchanged world X/yaw; both-side live production driving,
  swept high-speed body/portal impacts and recovery checks pass.

### Bounded rendering and mountain

- Static scenery points/faces/rails/billboards are authored once in 16m groups.
  Every unique visible point receives one cached affine camera transform and
  lens per frame. Texture/opaque geometry uses indexed mesh batches rather
  than hundreds of independent per-face canvas commands. Road/verge share
  the cached transform and precomputed clipping planes. Distant log sampling,
  near/screen clipping and endpoint thickness remain intact.
- Six measured poses use 1–4 scenery surfaces. The tunnel interior uses one
  opaque architecture surface and a 224m visibility range; its walls reach
  the ground, have alpha 1 and dark interior fog/sky. Exterior entrance rock
  is omitted when the camera enters, preventing it from painting over the
  vault. Textures and opaque batches are reused, no extra 3D viewport.
- Both tunnel mouths have actual holes surrounded by a thick stone portal,
  faceted rock face and receding mountain slope. Subdivided ground-following
  talus rises along both road verges. Foreground trees draw in front of the
  distant mountain, with a clear cutting before the opening.
- CI geometry checks cover 81 elevated poses at three landscape sizes and
  headings: finite/bounded passing beams, at most 9 scenery surfaces, at most
  2400 projected architecture triangles/4000 transformed points, opaque wall
  colours, matching car/scenery projection, clear mountain openings and solid
  surrounding rock. Nose-follow camera is checked near both tunnel walls.

### Measurements and validation

Native GL Compatibility, same host, 1280x720, median CPU script submission
from 22 frames after warmup. The old-geometry baseline already had restored
handling and no curve distortion, so it isolates geometry preparation rather
than reproducing exact published 1.8 frame time. GPU cost/device FPS excluded.

| World Z / location | Old geometry, ms | Batched geometry, ms |
| --- | ---: | ---: |
| 580 / forest | 23.00 | 5.80 |
| 1500 / fields | 27.52 | 5.82 |
| 2340 / bridge | 27.11 | 6.17 |
| 3210 / portal approach | 60.46 | 7.70 |
| 3500 / tunnel | 56.67 | 5.51 |
| 3800 / tunnel bend | 38.08 | 5.59 |

All eleven headless fixtures passed locally: four park fixtures, race smoke
and natural sprint, park/race geometry, two diner fixtures, second-pass input
and complete campaign/second cycle. Park polish initially timed out publishing
navigation while competing QA processes ran; its isolated rerun passed without
changing park code. CI runs fixtures sequentially. Native production driving
completed all six sectors, 83.85 simulated seconds, first of four, 0% AI offroad,
actual Continue into Level 3. Native captures inspect 19 poses including both
wall-side steering views and near/passing portal. Phone FPS, touch/steering feel
and final user acceptance remain unmeasured; do not claim a device FPS result.

Export: arm64 debug, package `com.acornhunter.carolina`, version **1.9 / code
10**, filename `build/AcornHunter-MoonlightSprint.apk`. Existing eleven CI
checks precede export; workflow/runtime/concurrency unchanged. Deliver only
an artifact from the successful final HEAD and check its archive hash, manifest
version/package and architecture. Update local branch to the published API
commit before finishing. Stage authored paths only, excluding generated import
stubs, embedded model textures, UIDs and caches; restore unrelated imports only
AFTER final local QA, and reimport before future native checks.

Do not run two native fixtures simultaneously with the scratch runner: its
Xvfb display selection races, producing host X11 startup failure. The native
runner/software rendering and reports are reproducible scratch QA; Git-backed
source and the delivered APK are persisted independently. Notes below describe
historical 1.8/1.7, including their superseded turn sizes and tunnel renderer.

## Historical follow-up — Android 1.8 / code 9

User's new screenshots/feedback: coloured boxes intersect squirrels; courtyard
gravel ends at a wall; oak lantern hangers are unreadable; race turns feel
straight; passing sign/fence/bridge connectors stretch/disappear; bridge needs
an uphill approach and a separate downhill road before the tunnel.

Start of this pass was verified published HEAD `4f085c9ef1bfd91e2368f242aade4dd99bcd2f45`,
Actions #984/#985 successful. Park fixes were published separately as
`0ce29483dbf421fc8ed53af0518601f75bc60a6c`; PR Actions #987 successful.
The following race patch includes this updated document. Recheck its actual
branch HEAD, matching Actions run and APK artifact; the older CI results do
not certify this new patch.

### Resulting changes

- Removed the standalone BoxMesh "accessories" from all squirrel roles. Their
  rig, role behaviour and authored size differences remain intact.
- Opened courtyard cells (29,8)/(29,9) in the layout generator, canonical map
  and authored physics scene. A real stone semicircular arch frames the gravel
  crossing; its overhead mesh collision leaves a 1.8m player capsule clear.
  No opening is an invisible wall or a full-height occluder. Added a direct
  physical capsule crossing to the existing park polish check.
- Oak tree generation exposes actual yawed branch ends. Seven 6.5cm ropes
  reach those ends, with brass anchors and framed lanterns. All static parts
  use existing spatial batches. Native arch, squirrel and oak views inspected.
- RaceProjection clips camera-space geometry against the near plane and
  viewport BEFORE dividing by depth. Connecting rails taper using each end's
  actual yawed depth. Authored bridge/tunnel Z endpoints remain fixed; passing
  camera position no longer drags their near ends along. Roadside signs and
  posts use the same geometry and include world indices behind the car.
- Nonplanar architecture quads are split into authored triangles before
  clipping; submission uses bounded triangle primitives, avoiding the native
  polygon triangulation failures reproduced during the fix.
- Normal bends now shift 120m rather than 26m; physical steering authority is
  calibrated to follow them, with existing speed-sensitive response, low-speed
  lock, road-width margin, powertrain and 219km/h cap. The actual route's peak
  tangent exceeds 23 degrees. Shared distant curvature emphasis also applies
  to the road, scenery, cars and rival light pools, while the local wheel-contact
  area stays physical. Main camera yaw is still the actual player nose yaw.
- The original 128 ground rows had a final unsampled strip of approximately
  330→2400m. Logarithmic depth sampling retains 128 rows and samples the whole
  visible route; the regression rejects gaps above 150m. Ground triangles carry
  inverse depth so texture/light positions also work on slopes. Verge frustum
  clipping and far-to-near submission prevent behind-camera explosions.
- Shared smooth elevation profile: climb from 1640m into bridge at 2080m,
  elevated bridge ends at 2720m; 560m forested connector with descent into
  tunnel at 3280m; tunnel exits at 4080m, followed by the city and 4800m finish.
  There are six HUD sectors including "ГОРНЫЙ СПУСК". Camera consumes shared
  height/grade; road, portals, fences, vegetation and rivals share that ground.

### Verification and continuation

All eleven existing headless fixtures passed locally. After the final shared
curvature presentation change, all five affected fixtures passed again:
Level2 smoke/drivetrain, natural full sprint, park/race geometry, second-pass
input/results and complete campaign/second cycle. The race visits all six
sectors, finishes naturally, keeps rival offroad samples at 0%, freezes results
and loads the diner through the actual Continue button. 0–100 remains 8.067
simulated seconds; four-speed automatic and 219km/h cap pass.

Geometry regression probes 81 elevated views (nine positions × three landscape
sizes × three headings), finite bounded passing connectors, rear-plane culling,
road sampling, physical bends and bridge/tunnel grade/separation. Native GL
Compatibility captures inspect fifteen race views and a natural complete
production-controller race. These are software-host checks, not phone FPS,
speaker/touch testing or final user acceptance of corner feel.

Export keeps package `com.acornhunter.carolina`, arm64, existing
`build/AcornHunter-MoonlightSprint.apk`; version is **1.8 / code 9**. The workflow
continues to run eleven fixtures before export, on ubuntu-22.04, Godot 4.7.2,
Java 17/Android 35, without changing concurrency. Deliver only a successful
artifact whose run has the current branch HEAD. Obtain new phone feedback for
the arch, rope readability, passing connectors, corner feel and grades.

The older sprint notes below describe the 1.7 starting point; their sector
boundaries/version are historical after this follow-up. Stage authored files
explicitly; leave generated imports, embedded textures and caches uncommitted.

Branch `fix/level2-final-game-flow`, PR 11. Started from published `86ae0351260fdb1dbf9492d3bdecef0ed13c3664` (Android 1.6). User explicitly requested park music/planting/foliage fixes, supplied the Camry GLB, and authorized a scenic point-to-point race with bridge, tunnel, wheat fields and forest. Preserve the existing NFS camera, grounded 240SX, drivetrain and diner.

## Changes

- Park silence was reproducible: registering the music player started it, then assigning a duplicated stream stopped it. Stream/loop setup now precedes registration. Existing saved mute is respected; start/mute/resume is regression-tested.
- Removed path pebbles and tiny leaf litter. New volumetric flowers, fern borders, ten carved urns, blooms and trailing ivy use static spatial batches, one shared material, no per-petal nodes or updates. Urn footprints participate in the same physics/navigation exclusions as benches. Grass/path clearance and the complete mission route pass.
- Wall foliage now sits above the masonry cap, with conservative bounds including scaled shader displacement. Native inspection also reproduced disappearing nearby outer masonry caused by self-occlusion. Wall batches ignore occlusion while trees/other scenery retain spatial and occlusion culling.
- Level 2 is one open 120-segment / 4.8 km sprint: forest 0–960m, wheat 960–2080m, bridge 2080–2720m, tunnel 2720–3520m, city to 4800m. Continuous clamped centerline, unwrapped physical progress, rear grid / 7m spacing, real physical finish stripe, percent/distance HUD and open minimap. Crossing canonical segment wrap 21m before the rear-grid car reaches the stripe cannot finish the race.
- Architecture/plants are projected with the shared player camera. Bridge includes deck parapets, rails, reflectors, steel portals/stringers and animated water. Tunnel has a continuous vaulted cross-section, ribs, barriers, rhythmic lamps and portals. Fields have wheat rows/timber fencing; forest and city have dense planted verges. Objects select their own world-location sector, so future scenery is visible in advance.
- Roadside props include indices behind the car and survive until leaving the camera view; signs use stable world indices, avoiding relative-index toggling. Obsolete duplicate tree/headlight draw paths removed.
- Real uploaded Camry is preserved unchanged in `assets/level2/source/camry-source.zip`, verified byte-for-byte against the attachment. It has 511,281 triangles, so `tools/bake_race_camry.gd` loads the archived GLB directly and bakes 9 rear angles × running/braking states into one transparent atlas. No extra runtime 3D worlds. Actual imported lamp materials emit light; opponent headlight pools use their world position/heading. Original source/cache folders are excluded from Android export.
- Both cars retain running rear lamps at night and much stronger red braking. 240SX emissive texture uses multiply, preventing yellow/white saturation. The player's overlay now samples physical track phase too, fixing a cropped body on bends after the grid-offset correction.
- New wheat bitmap generated with built-in ImageGen; exact prompt/mode and source hashes in `assets/level2/ASSET_PROVENANCE.md`. Project copy 512px with alpha, mipmaps and Android compression.

## Validation and honest limits

Eleven complete headless fixtures passed locally without parser/runtime errors: park smoke/physics/polish/full route; car dynamics; natural full sprint; park/race geometry budget; diner smoke/full live mission; multitouch/focus/finish/combat regressions; full campaign and second-cycle flow. Natural sprint visits all five sectors, finishes in 83.57 simulated seconds, first of four, with 0% AI offroad samples, and uses the actual Continue button to load Level 3. These are test-driver results, not human lap times.

Native GL Compatibility captures inspect eleven park poses and twelve sprint views, including Camry running/braking, bridge/tunnel approach/inside/exit, fields, forest, city and finish. Remaining timing/device caveat: Mesa llvmpipe is a software renderer. Same-pose park calls were close to 1.6 (entry 549→554; pond 205→205; pavilion 144→144; golden oak 232→233), with increased visible masonry in courtyard/ruins after the culling fix. Actual phone FPS, speaker quality and touch feel still require device testing. Do not invent phone performance claims.

Android export is arm64 debug, package `com.acornhunter.carolina`, version **1.7 / code 8**, filename `build/AcornHunter-MoonlightSprint.apk`. All 11 CI checks precede export. Verify the exact current branch HEAD, workflow conclusion and artifact before delivery. Earlier park checkpoint `a33f16dd47ee7693cca9a6cda3a3d09e51d73896` introduced a headless MultiMesh-bound assertion that read identity transforms from Dummy RenderingServer; final assertion uses the exact conservative source bounds uploaded by build. Always prefer the latest completed workflow.

## Workflow continuation

The workspace can prune across user pauses. Keep targeted changes committed and published. Godot runtime executable was truncated to 44MB across a pause and segfaulted before main; restoring the intact downloaded ZIP restored the correct 146,414,384-byte executable. That was a host-runtime issue, not a game crash. Native runner and intermediate captures belong to scratch. Deliverable APK and visual overview are persisted separately; repository files are Git-backed.

Godot import generates many untracked caches, embedded model textures and UIDs. Stage explicit authored paths only. Restore unrelated tracked import stub / extracted `assets/squirrel_mobile.png` changes after final QA. Original Camry ZIP is lossless, user attachment remains unchanged. The source is not imported or triangulated at game startup.
