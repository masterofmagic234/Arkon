# Arkon — Moonlight Sprint and living park, 13 October 2026

## Current follow-up — Android 1.8 / code 9

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
