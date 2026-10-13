# Arkon — Moonlight Sprint and living park, 13 October 2026

## Current follow-up — visible corners checkpoint for Android 1.10

Published starting HEAD `b0d632fbb0d7b339c68185f03d65724e9b4b3ed4` (1.9,
code 10), Actions #990/#991 successful. User accepted phone FPS, but reported
straight-looking road despite the map, too few bends, abruptly appearing ugly
mountain, unreadable high-speed location names and stretched city after exit.

Restoring 26/40m amplitudes in 1.9 missed the former 5–7 segment arc lengths:
scenic sections lasted 10–12 segments, flattening their slopes. This checkpoint
restores compact arcs, adds 12 actual bends instead of four across the six
locations, and gives ordinary arcs a 34m shift so they remain legible with the
nose-bound camera. Hairpin shift stays 40m. Preserve 0.38 heading authority,
manual steering, swept barriers, 219km/h drivetrain and the accepted batching.
Track still has 120 segments / 4.8km, same bridge/tunnel boundaries and grades,
balanced lateral sum and physical finish. Driver must brake for sharper arcs.

New route regression checks every bend's physical slope and projected road
bow (at least 1.8 local half-widths), not just minimap/curve labels. Natural
production-input sprint passes in 117.77 simulated seconds, first of four,
0% AI offroad; gas-only/wall recovery, stationary vehicle, powertrain and full
campaign checks pass. All eleven final-working-tree fixtures passed locally.

Next targeted commit completes smooth textured mountain visibility, large
baked road signs with a readable 219km/h notice and pitch-independent city
proportions. Do not deliver an intermediate version 1.9 APK. Recheck actual
final branch HEAD, matching successful Actions and final 1.10 manifest/artifact.
Historical 1.9/1.8/1.7 notes follow; their curve counts/ranges are superseded.

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
