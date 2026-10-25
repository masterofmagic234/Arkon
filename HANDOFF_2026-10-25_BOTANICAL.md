# Botanical garden — read before all previous Level1 handoffs

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
