# Botanical garden — read the latest version section before older handoffs

## Android 1.42: 1.40 garden on Compatibility (latest)

The owner's latest instruction explicitly replaces the earlier Forward+ constraint:
use 1.40 as the base and move to Compatibility with maximum visual preservation.
The base is97c20eb3c344d8c10356f664f0c850c4519aaece. All1.41 edge-depth variants,
shader swapping and its expanded diagnostic were removed. Both desktop/Android
production profiles now request gl_compatibility; Android version1.42/code43.
Stable package/signing identity and existing save formats remain unchanged.

All37 mesh resources, foliage atlas, source transforms/density, baked scene/GI/
lossless lightmap array are unchanged from1.40. Original shadows, MSAA2 and pixel
cap remain. Lightmaps/probes run natively in GL. The offline baker still requires
Vulkan; no new bake or dummy-backend serialization is performed for this port.

Custom garden materials now decode sRGB inputs, combine them in linear space and
encode ALBEDO for GL; Forward+ retains its original linear computations. The HDR
sky uses a GL-specific ShaderMaterial to avoid decoding already-linear radiance.
A garden-local CameraAttributesPractical exposure.75 and environment contrast.8 /
saturation.85 soften sRGB light accumulation; sky energy compensates exposure.
There is no fitted LUT or screenshot-based runtime effect. Characters retain the
matte materials from1.40; environment/camera changes are scoped to the garden.

Cross-renderer fidelity is approximate. GL's sRGB additive lights, LDR highlights,
shadow filtering and glass compositing differ. Nine frozen real-engine camera
pairs, including both P60 poses and both squirrel types, retain identical MSAA,
scales and source geometry. Local mean absolute RGB difference is13.84–17.06/255.
The new comparison checks mean error≤24/255, mean-channel drift≤18/255 and mean
luminance drift≤.06, as well as550 calls/260k triangles and ≤1% LOD count variation.
It is not a pixel-identity test. Original Forward+ geometry gates remain unchanged.

19/19 headless checks and native Compatibility menu/canvas/race/diner checks pass.
Native GL lighting/geometry/probe restoration, race, pursuit, airframe depth and
intro video checks also pass locally. Signed Android CI/export is required before
release. Report the final source/merge tree and verified artifacts in PR11.
Keep draft. No device FPS improvement is established until an actual P60 run.

Owner's measured1.40 result at(-16,3,35.3), pitch-1.2/yaw51.3: bake8.1FPS /
122.1ms GPU; original light5.2FPS /192.3ms; no foliage59.9FPS /13.5ms.
The GL diagnostic retains six supported stages, avoids the Forward+ compositor,
and restores lighting, visibility, MSAA and pause/input state after every stage.

## Android 1.40: actual baked indirect lighting (historical)

The owner measured 1.39 at the same P60 pose: reconstructed foliage 5.4 FPS /
182.3 ms GPU versus original cards 2.7 FPS / 369.6 ms. This confirms roughly
twice the GPU throughput from geometry, while remaining far below playable FPS.
They explicitly requested actual baking next. Forward+ must remain enabled.

Real Godot LightmapGI assets now cover 121 deterministic static sources. The
final scene partitions receivers into 231 meshes on a 48-meter grid, preserving
their original UV2 charts/atlas bindings and every full-detail triangle. This
recovers native frustum culling after merging instanced geometry. World-space
color meshes use default one-display-pixel LOD error (subpixel at capped internal
3D resolution). Original source instances retain the original optimized/culled
solar-shadow geometry in SHADOWS_ONLY mode, with exact visibility and cast mode
restoration for comparison. Repeated branches, rocks and cylindrical props keep
their original instanced color geometry/LODs and receive baked probes, like
foliage and characters. Their prepared UV2 receivers remain hidden. Leaf
color/shadow geometry stays as in 1.39.

The bake contains sky occlusion and one indirect-light bounce, 901 light probes,
and nine 512x512 nondirectional lightmap layers. Sunlight/shadows remain realtime;
sun, fog, atlas textures, MSAA2 and Android pixel cap retain their values. Garden
characters and repeated foliage use the probe volume. Production disables SSAO,
removing the SSAO normal/roughness prepass requirement. Lighting intentionally
changes and requires review of the actual A/B frames; do not claim pixel identity
with 1.39 or a playable P60 result before another device measurement.

Runtime loads assets/level1/botanical/lighting/garden.scn and garden.lmbake.
Lightmaps use lossless half-float storage (~18 MiB GPU) to preserve gradients;
desktop compressed HDR caused long llvmpipe decoder compilation. Offline source,
intermediate individual meshes, editor plugin and signing tools are excluded
from APK. Maps are real engine output, not screenshots or generated artwork.

Rebuild with tools/bake_botanical_lighting.py and native Godot 4.7.2/Vulkan/display.
Imports finish in a separate editor run before invoking the real native Bake
Lightmaps button. Never finalize/re-save LightmapGIData with dummy headless
rendering: that backend discards probe arrays. Finalization verifies 901 probe
samples, source coverage and unchanged full-detail triangle totals. Normals of
merged nonuniformly scaled meshes use inverse transpose. See lighting/README.md
for bake settings and the coarse bake-only foliage occluder approximation.

Diagnostics compare baked production, original 1.39 lighting, baked + SSAO,
baked + normal prepass, no foliage and UI, at one frozen camera. All bindings,
visibility/shadow modes, SSAO, compositor and input restore afterward. Existing
geometry fidelity benchmarks explicitly retain original lighting on both sides;
new lighting captures separately show the intentional lighting change and both
squirrel types. Retain complete garden and later-level validation. PR stays draft.

Owner rejected the eight separately loaded areas and chose concept B, the
botanical garden. Level1 now uses botanical_garden.gd / botanical_world.gd:
ONE continuously resident scene with real terraced terrain, central stairs,
side ramps, reflecting pool, conservatory, upper orchard and pavilion. No
active region selection, automatic portals or SceneFlow calls between garden
landmarks. The inherited director supplies weapon/basic input helpers; its old
regional state and travel methods are unused.
`game.tscn` loads the new director. Core weapon/touch/health helpers are reused.

GardenState stores all partial objectives, valves, mirrors, seeds, companion
progress, guardian outcome, player checkpoint/resources and defeated guards in
atomic schema1 user://botanical_garden.json. Retry keeps objectives and returns
to safe entrance; menu Continue resumes; New Adventure clears it. Old Woodland
checkpoints are separate and do not define the new level.

Quest: restore real visible irrigation, collect three specimens, reflect the
beam through two physically oriented mirrors to the conservatory flower, then
resolve the guardian. Escorting the actual Scout allows a peaceful outcome;
without the escort, a two-phase guardian fight is available. Six acorns are
collected only afterward. Only the original entrance car advances to Level2.

Native botanical_visual captures actual production geometry/lighting/GLBs.
Clean frames hide UI/weapon and freeze actors. Desktop overview disables
geometry distance limits and is not a phone budget. Gameplay uses native UI,
scene-local MSAA2 and a 1280x720 3D pixel cap; settings restore on exit. Current
fixture limits are 300 calls/550k triangles INCLUDING shadows/UI. Device FPS
is unmeasured. The concept is richer than the current render: do not claim an
exact visual match or approval of the implementation. Keep PR11 in draft until
the owner reviews the real result; do not merge automatically.

botanical_playthrough uses production input, gravity, hitscan, real stairs,
ramps and one scene instance to complete objectives and return to the car.
--combat drives the alternative guardian fight. botanical_rules_test checks
negative solutions, independent destinations, partial saves, retry, touch map,
menu resume, profile restoration and New Adventure. Retain intro/race/diner gates.

Android1.33/code34. A stable PUBLIC TEST debug keystore is pinned from now on.
Older1.31/1.32 APKs had unrelated ephemeral signatures and require removal before
installing this test version. Future debug builds preserve this test key. It is
not a store/release signing key. Verify matching CI/source/artifacts in PR11.

## Android 1.34 optimization follow-up (read before the 1.33 numbers above)

Owner approved the actual 1.33 garden appearance, but reports a slideshow on the
phone and requires the same visuals. 1.34/code35 retains geometry placements,
all foliage, materials' appearance, lighting/SSAO/fog, MSAA2 and the existing
921600-pixel cap. No lower-resolution mode or density/distance reduction.

botanical_rendering.gd keeps the original MultiMesh batches, bounds and native
visibility-distance hysteresis. Typed twelve-meter clusters select a visible
instance prefix using the camera frustum plus a conservative swept sunlight
volume: offscreen geometry that can cast an onscreen shadow stays. Buffers only
upload on visibility changes; static cameras do no culling work. Fully restoring
the original buffers is tested. Headless dummy rendering skips this GPU-only work.
The scene enables terrain occlusion and restores the old viewport setting on exit.

Full-detail meshes are preserved in generated resources with subpixel LODs
(lod_bias4), including terraced ground and small botanical objects. Their welded,
position-only shadow meshes retain ALL matching LOD levels; omitting those levels
crashes the native renderer. Regenerate resources with the exact Godot editor:
`godot --headless --path . --script tools/prepare_botanical_meshes.gd`.
Garden triplanar shading retains the StandardMaterial mapping/TBN/PBR values;
zero-weight projections and unused default-texture samples are avoided. Explicit
texture gradients retain mip selection at projection branches.

Local fixed-view comparison to unoptimized 1.33: about 68–86% fewer submitted
triangles in the five forward garden views, without extra draws. Other views
include 30% at the reverse entrance and 81% at the eastern ramp. Eight captured
images pass strict pixel-difference checks (mean <0.07 on a 0–255 scale; at most
0.0016% of pixels differ by >8). Native gameplay budget is now300calls/160ktris
INCLUDING shadows/UI. Timings on llvmpipe improved about16% in aggregate in the
preliminary comparison; this is NOT a phone FPS measurement. A native moving-view
culling test measures ~1.35ms median on this machine, restoring all22077 instances.

Native benchmark --reference uses the original 1.33 rendering path. CI gates
both raw image fidelity and reduced geometry; shared software-GPU timings are
advisory. All17 headless campaign gates plus native rendering/lifecycle/FPS
checks remain. Pause shows the last five active seconds of wall-clock FPS;
paused time and Godot's capped simulation delta cannot inflate that number.

Android export is now RELEASE, still signed with the SAME deliberately PUBLIC
TEST key as1.33. It updates1.33 in place and preserves its checkpoint. Pinning
this development-test identity is deliberate; this is not a store signing key.
No new permission, network access or telemetry. PR11 remains draft; do not merge
unless the owner requests it. Phone FPS after optimization is still unmeasured.

Target device is Huawei P60 (owner supplied). Mobile rendering also caps at60FPS
while preserving a lower host cap; it restores the prior cap on exit. This avoids
unnecessary90/120Hz thermal load without changing image quality. FPS gains on
that actual device still require its post-update measurement.

## 1.35 / code36 — P60 performance is NOT resolved yet

The owner reports2–3FPS in the last-five-seconds counter even while stationary
for20–30seconds. Treat this as actual feedback, never as an old-build mistake.
The1.34 release and reduced geometry did not establish adequate device FPS.
Do not claim the phone performance problem has been fixed without its new result.

The Adreno depth-prepass-exclusion hypothesis was checked against the exact
engine source ed1daf0bf001b61586d9930840f2f1394092c079 and rejected: the vendor
list is consumed in GLES3 storage/config.cpp, not the shipped Forward+ Vulkan
path. The override was removed before delivery. Do NOT present it as a fix or
repeat this hypothesis.1.35 uses SSAO quality1, retaining the prior
radius/intensity/blur and passing initial strict pixel checks.
Reference captures explicitly use the original SSAO quality2.1.35 also excludes
application-background/resume gaps from the FPS counter.

Pause → ДИАГНОСТИКА FPS runs a reversible30–60second rendering probe beneath an
opaque overlay, with gameplay paused and underlying touch/map input blocked.
It reports actual GPU name/backend,3D scale, effective depth-prepass setting,
frame cap/VSync, active-game FPS and timed stages: ordinary paused scene, SSAO
off, shadows off, foliage hidden, UI-only and UI-only without VSync. GPU and render
CPU timestamps are included where available. Pipeline compilations are marked.
Everything restores, including rendering, VSync, foliage visibility and HUD input.
The owner can copy the report; it also saves only locally as garden-performance.json.
No network permission/telemetry is added. If1.35 is still slow, obtain that real
phone report before guessing at another expensive feature. A fast paused scene
with slow active gameplay suggests CPU/gameplay work; slow paused3D but fast UI
suggests rendering; slow UI that improves without VSync suggests presentation.

Mobile Vulkan and OpenGL Compatibility were tested locally as alternatives.
Both materially change lighting/color (MAE~20 and~34 respectively), so neither
is selected in the shipped configuration. Desktop timing is not device evidence.
New probe restoration/background-gap tests pass; native full probe also completes
and restores the scene. Retain all18 headless gates and native campaign checks.

Exact-engine evidence for the rejected vendor-list hypothesis:
https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/gles3/storage/config.cpp
The report depth flag is the project setting, not proof of an actual GPU pass.
The1.35 release is a hardware-diagnostic follow-up; adequate P60 FPS remains
unconfirmed. Do not claim this build alone fixes the reported slideshow.

## 1.36 / code37 — actual P60 GPU report, targeted candidate (not confirmed fixed)

The owner supplied the actual1.35 results in a screenshot. Backend is
forward_plus, GPU Adreno(TM)730, window2582x1220, scale.541, limit60, VSync1.
Active game2.0FPS. Paused full2.0FPS /GPU516.2ms /renderCPU17.7ms;
SSAO off11.5FPS /87.0ms /8.2ms; shadows off2.0FPS /506.6ms /5.0ms;
foliage hidden30.2FPS /31.9ms /5.9ms; UI59.3FPS /2.3ms /.6ms;
UI without VSync59.8FPS /2.2ms /.4ms. Header says "depth setting", matching
the final3ec058a1.35 build. There is no backend fallback or2FPS limiter.
These independent ablations isolate GPU rendering with foliage and SSAO;
they do NOT distinguish the normal/roughness prepass, MSAA resolve and AO
compute/filter cost. Do not claim a particular driver bug is established.

New candidate reorders surviving foliage instances near to far within each
original MultiMesh. It preserves every transform, material, alpha threshold,
native distance bound/hysteresis, shadow caster, density and MSAA2/SSAO/pixel
cap. Integer distance keys sort in native code. Upload on visibility changes
or one-meter movement only; a fixed camera never uploads. Camera turns retain
conservative culling. This targets avoidable cutout overdraw, but local software
GPU improvement is small and says nothing conclusive about P60 performance.

Diagnostics now have9stages: production, original foliage order, SSAOoff,
resolved normal/depth prepass without AO, MSAAoff with AO retained, shadowsoff,
foliageoff, UI, UIwithoutVSync. The normal-only stage uses a no-op pre-opaque
CompositorEffect requesting normal/roughness+resolved depth. It does no drawing
or compute. Original compositor, MSAA and sort setting restore on completion,
cancel and destruction, alongside the existing state/input restoration. All
changes stay under the opaque pause overlay; they are not production presets.
The new report distinguishes unchanged production quality from masked tests.

Tests verify the complete multiset of visible cutout transforms, near/far
order, no fixed-view uploads, original buffer restoration, all new diagnostic
state restoration and the existing18headless campaign gates. The eight-view
sorting trial relative to1.35 has maximumMAE.00453/255 and.018375% pixels
differing by>8, within the unchanged strict image thresholds;7views are exact
or virtually exact. Final CI validation and artifact identity belong in the
PR description after completion. Keep PR11 draft. Hardware FPS is unresolved
until the new P60 production/A-B measurements arrive. Do not merge or claim
that the reported2–3FPS has been fixed.

## 1.37 / code38 — pause fix, matte coats and canopy render path

The owner reports1.36 still runs about3FPS, and the pause menu opens for one
second then resumes by itself, so the new hardware diagnostic was inaccessible.
Visual preservation remains the priority, but the owner explicitly requests
reducing the oily shine on the squirrels. Hardware performance is NOT confirmed
fixed; do not dismiss this feedback or claim measured P60 improvement.

Android pause failure was reproduced through real queued input: raw ScreenTouch
opened pause, then the same finger's delayed emulated mouse release activated
the GUI button and toggled it back. Pause icon now opens pause idempotently;
Continue/Escape explicitly resume. Tests dispatch the delayed mouse sequence
through Window.push_input, enter/cancel the real botanical diagnostic, and use
Continue. This changes no menu layout. Other map/mute handlers are out of scope.

Scout/tank materials now use uniformroughness.92, metallic0, specular.10, with
imported metallic/roughness maps disabled. Existing specular-disabled mode only
removed direct highlights: sky reflections still used F0 from oldspecular.5.
Albedo/normal textures, colors, geometry, rigs and animations remain intact.
Material override independence and retained authored texture detail are tested.

Foliage uses paired reverse-winding faces with the SAME original normals/UVs,
and cull_back. Godot already flips NORMAL for cull_disabled before the old shader
flipped it back; removing both flips preserves the accepted lighting and shadow
normal bias. Every original card/transform remains; no density/distance/pixel
cap/MSAA2/sun-shadow reduction or renderer switch is introduced.

Only far-only large tree canopy (leaf0) batches move to a binary, depth-writing
alpha color pass after opaque AO, avoiding their overlapping cards in the
normal/roughness prepass. Nearby batches retain original opaque contact shading:
the closest distance to each ORIGINAL fixed batch AABB uses40m enter/45m exit
hysteresis. Every source starts opaque; any nearby part retains the whole batch.
No original bounds, distance hysteresis, draw batches or transforms are split.
Shadow-only masked instances share exactly the same MultiMesh and
bounds/hysteresis, preserving every original sun shadow. Architecture, ivy,
flowers and ground keep the opaque SSAO path. Far canopy participation in
screen-space AO is omitted; this is accepted only after the UNCHANGED strict
raw frame thresholds passed. Do not describe per-leaf AO as mathematically
identical, or this software-GPU validation as phone performance evidence.
Canopy material priority-1 places its binary depth-writing color before glass
and other default-priority translucent surfaces. This restores the original
opaque-before-glass order without depending on a whole batch's center distance.

Culling skips shared shadow proxies as separate records, but retains offscreen
canopy shadow casters. Diagnostics hide/restore both canopy color and shadow
proxies. Native tests check matching canopy/shadow instance data, distance
hysteresis, both windings and original positions/normals/colors/UVs, no duplicate
instance uploads, plus existing full-buffer/FPS lifecycle checks.

Paired native trial:8 original cameras pass (maxMAE.028671/255, at most.04825%
pixels differ by>8). Four extra glass/water cameras against original reference
also pass (maxMAE.033932/255, max.007938% pixels differ by>8). Final source CI
still repeats the existing eight-view fidelity/workload gates, full nine-stage
probe, campaign paths and APK export. Final artifact identity belongs in PR11
after verification. Keep draft; do not merge. Actual1.37 P60 FPS remains required.

CI1085 correctly blocked the first all-canopy alpha version: entrance-reverse
had.10975% pixels differing by>8 against the original MEDIUM-AO reference, just
above the unchanged.1% limit. The1756 pixels were on a close tree, NOT actor or
water animation. Near-batch opaque routing above addresses the real shading
difference; do not relax the gate or freeze motion to hide it. Direct comparison
of the revised reverse view to this machine's existing1.36 image is.007307/255
mean with.001188% pixels differing by>8. Cross-machine raw captures are not a
valid comparison: CI and this executor have broader raster/texture differences.
The final CI repeats the full same-machine reference comparison before delivery.


## 1.38 / code39 — preserve coverage, isolate alpha fetches

Actual P60 1.37 report (camera0,1.6,65, pitch-5/yaw-4, FOV65):
full2.5FPS/396.8GPUms/3.7renderCPUms; unsorted2.2/446.6;
SSAOoff7.6/129.3; normal-prepass-without-SSAO2.6/381.6;
MSAAoff2.7/364.8; shadows-off2.5/394.2; foliage-off59.1/15.3;
UI60/1.0. Normal prepass with foliage is the main measured expense;
this does NOT prove which driver/sampler operation is responsible.
1.37 pause fix makes measurements accessible; P60 performance still unresolved.

The new foliage shaders fetch coverage from a cached single-channel R8 texture
extracted at load from the ACTUAL platform-imported atlas after decompression.
All original alpha bytes at ALL existing mip levels are preserved; no mip
regeneration, source-PNG masking, altered filtering, density, transforms or
lighting changes. Fragment discard retains the .38 threshold. Depth/normal
variants can discard from one channel without fetching the RGB color block;
color still uses the original imported atlas and anisotropic filtering. Far
canopy routing, shadow proxies, nearby AO and the rest of rendering stay intact.
Mask is generated once per atlas, shared by color/shadow materials; decode
failure falls back to the original atlas-alpha sampling. About2MiB additional
GPU mask storage (1536x1024 plus original mips), no per-frame generation.
The explicit-discard version was pixel-identical to alpha-scissor in the
fixed P60 camera trial. Disabling anisotropy was rejected because it changed
5.49% of image pixels by >8, far beyond the unchanged fidelity gate.

Diagnostic adds atlas-alpha fetch and tree-canopies-hidden stages (11 total),
with exact restoration of captured shader identities as well as visibility/input.
This allows P60 to compare the one-channel path against atlas alpha, and
separate tree cards from smaller plants without applying a gameplay preset.
Native tests compare every decoded mask byte against its source alpha across
all mip levels, cache/material sharing, and probe cleanup. CI repeats existing
strict raw image/workload gates and campaign checks. No P60 speedup is claimed
until the new build is measured. Keep draft PR11; do not merge automatically.

Production mask shaders have no runtime atlas-alpha branch: normal/depth
variants cannot speculatively fetch the color block. The diagnostic uses
a separate atlas-alpha shader variant and restores the original shader RID.

## 1.39 / code40 — authorized foliage geometry reconstruction

The owner selects geometry reconstruction and permits all necessary lighting
bake preparation, explicitly retaining Forward+. Latest P60 1.38: camera
(-51.6,6.4,-2.5), pitch-21/yaw-62.6; full268.7GPUms, atlas-alpha268.5,
no-canopy154.5, SSAOoff120.9, normals-without-SSAO238.8, MSAAoff236.1,
shadows-off254.3, foliage-off16.0. Mask bandwidth/sorting did not solve it.

Offline authored-alpha contour baking now creates six ArrayMeshes with seven
coverage LODs (256 through4 texels per tile). Each has a true opaque interior
surface (no alpha sampler/discard) plus a narrow, shaped alpha-tested fringe.
Original textures, atlas mapping, flat original normals, colors, placements,
Forward+, MSAA2/pixel cap, sun and SSAO remain. 24m spatial batches replace
48m foliage groups; their LOD bias accounts for the largest instance scale.
This lets opaque geometry reject hidden layers early; no authored plant/card
instances are dropped. This is not a claim that internal card planes were
physically removed. New contours/LOD boundaries are intentionally not pixel
identical to sampled rectangular cards.

Original paired quad meshes independently cast sun shadows. The color buffer
contains camera-visible clusters; shadows retain the original conservative
union of visible and offscreen casters, with unchanged bounds/ranges. Their
separate prefixes are checked as exact multisets; proxies never enter camera
rendering/culling twice.
The old far-canopy alpha/AO omission is no longer applied: reconstructed
canopy keeps original opaque contact shading at every distance. Lighting
baking is authorized but has NOT been applied or claimed; this change keeps
lighting fixed so geometry can be evaluated independently.

Generators: pip install Pillow numpy shapely mapbox-earcut; run
`python tools/build_botanical_foliage.py --output=/tmp/foliage.json`, then
`godot --headless --path . --script tools/prepare_botanical_foliage.gd -- /tmp/foliage.json`.
Generated six compressed .res files are shipped; Python/geometry libraries are
offline dependencies only, not game/CI-runtime dependencies.

The phone diagnostic now samples six relevant stages, including original
cards on the SAME frozen camera/lighting/batches. Switching meshes/materials
never changes shadow buffers or gameplay. Older ablations remain covered by
restoration tests, but are not all re-run on the phone.

Benchmark records projected card area weighted by chosen-LOD core/fringe area.
This is a workload ESTIMATE, not actual shader invocations or phone FPS.
Preliminary views leave about15–25% of original card area alpha-tested. Local
software-GPU timings are SLOWER, not evidence of a P60 improvement. Actual
hardware A/B remains required; do not call the 3FPS problem solved.

Visual validation explicitly separates intentional foliage reconstruction
from regressions: actual engine foliage masks delimit that region (4px AO
margin). Outside it the old MAE<=.2/255 and pixel>8<=.1% bounds remain. Overall
reconstruction has MAE<=1/255 and pixel>8<=1% bounds, with BEFORE/AFTER images
for review. This replaces the old globally pixel-identical-card assumption;
do not describe it as unchanged global fidelity thresholds. Workload gates
now bound500 calls/260k reported triangles and require at least65% estimated
masked-area reduction. More geometry/two surfaces are intentional; lower
triangle/draw counts alone are not the optimization goal. Keep PR11 draft.

Final CI includes the original eight views plus both actual P60 camera poses,
with2582x1220 output and the same .541 3D scale for the latter two. Preliminary
8view geometry comparison: maxMAE .323/255, max.878% pixels>8; outside actual
foliage masks maxMAE .088/255, max.007% pixels>8. These are the explicitly
changed reconstruction gates above, not the old globally strict gate.
