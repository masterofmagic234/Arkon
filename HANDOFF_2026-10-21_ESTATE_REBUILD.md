# Lake estate / helicopter tile-GPU repair

Repo masterofmagic234/Arkon, branch fix/level2-final-game-flow, PR 11.
Do not merge automatically. Start from 04abe6b44fe2029207d62e962c99c1c9bb5a306c,
verified successful Actions #1047 (39501801277), Android 1.26/code27.
The user liked heist mechanics but rejected the old small four-quadrant map.
This work is a replacement of its spatial design, plus a P0 helicopter fix.

## P0 helicopter

The 1.25 shared viewport fix retained nine complete mutable projected scenery
meshes. Shader discards outside the aircraft rectangle do not stop those road,
verge and foliage triangles from entering rasterization; alpha/discard prevents
the usual cheap opaque depth path. This is an unnecessary tile-GPU workload.
Now two dedicated depth meshes consume existing CPU source arrays, with no
mesh readback and no 2D/3D shared mutable mesh. Triangles behind the farthest
part of the aircraft or outside its rectangle are rejected; intersecting ones
are clipped with reciprocal depth, coverage UV and vertex-alpha interpolation.
The mask is rebuilt after the current frame's projection, through an explicit
renderer binding. Inactive/offscreen/tunnel phases have no mask submission.
The model, flight, screen resolution, atlas coverage, bias, camera roll, cars,
rotor blur, radio and spikes are retained. No extra viewport/texture pass.

At native 1920x864 production poses (forest 900m, mountain 4400m, city 7700m),
source triangles 2184/2164/1926 become 153/156/126 (93–94% fewer submitted).
CPU clipping measured 1.3–1.8ms on this host. Software Vulkan total draw/readback
medians with helicopter: 343->361ms, 383->354ms, 300->281ms. Forest is slightly
slower on this CPU renderer; do not claim universal FPS gains or device proof.
The material/submission and raster workload reduction targets the phone issue.
Real phone FPS remains acceptance work, not something measured by this host.

Local pursuit mechanics, C2 flight and full input-driven 8.88km escape pass.
Native Forward+ retains all 12 opaque/foliage/front/back/roll cases across
1280x720 and 1920x864 with original pixel thresholds. The fixture now also
asserts two submissions and CPU-clipped vertices. Moving-flight native checks
assert the same invariant, which the old visual-only tests could not detect.
