# Level 2 helicopter appearance cost — Android 1.25 / code 26

Repository masterofmagic234/Arkon, branch fix/level2-final-game-flow, PR 11.
Do not merge automatically. Base: verified head 26a02d6322b3378f32977e8c4f06152c2557d829,
successful Actions #1041 / Android 1.24. User reports low FPS while the new
helicopter appears. Preserve its corrected occlusion, continuous weighted
flight, spikes, normal car handling, radio, car tactics and campaign/intro.

## Root costs and final repair

1.24 introduced a full-resolution Forward+ SubViewport/World3D/camera to
rasterize scenery depth into 24-bit RGB. It rendered alongside the existing
vehicle viewport, encoded/color-corrected every scenery fragment, then every
airframe fragment sampled and decoded that texture. It allocated the target
and bound nine materials at first visible ingress. Aircraft construction also
had 57 MeshInstance3Ds, and the crest-safe ground light used 80 individual
triangle drawing commands with repeated camera/lens calculations.

1.25 has NO additional viewport, world, camera or encoded depth texture.
The same nine projected source meshes now submit zero-alpha depth-only
proxies in the existing vehicle viewport. Existing opaque/transparent cars
render first (normal priorities), proxies at priority 100, solid aircraft at
101 with depth writes and ordinary Z testing, rotor blur at 102 without depth
writes. Source reciprocal depth is transformed into the production camera's
hardware depth. UV alpha/coverage, camera alignment/roll, clipped ground and
the 5 cm depth bias are preserved. No color writes affect the existing cars.
A conservative aircraft screen rectangle rejects fragments before foliage
texture sampling; near-plane crossings use a full rectangle. Two shared
materials replace nine duplicated bindings, and invariant size/transform
uniforms update only on change. Proxies are set up on the first idle/loading
frame and hidden for idle, out-of-frame and tunnel phases. The obsolete
race_airframe_occlusion.gdshaderinc is removed.

Static hull pieces and tail-rotor blades are baked once per existing material
at level load, retaining blade/coning pivots, hub, blur and blinking beacon.
Actual aircraft instances fall from 57 to 20. A local geometry comparison with
the authored model found identical sorted transformed triangle/paint data
(8,338 nondegenerate triangles; full geometry also retained). Unindexed
2-sided ear fins must be indexed before SurfaceTool.append_from; a focused
fixture now guards their triangles, transformed tip and paint preservation.
No art detail, authored palette or flight/rotor animation is removed.

Pursuit ground effects use one reused indexed mesh/draw submission for all
light rings, chevrons and rack parts. One shared camera frame and cached
projected points replace repeated per-triangle camera/lens calculations.
Planar crest-safe geometry, concave chevrons, alpha layers, near/screen
clipping and subpixel degeneracy protection remain. Idle has no submission.

## Validation and release

Local pursuit mechanics (including the new unindexed-fin fixture), full
production-input escape, native foliage/wall/camera-roll occlusion and native
pursuit/rotor/ingress/departure/tunnel/spikes/subtitle checks passed during
implementation. Escape remains 209.73 s, five drops, zero spike hits, three
contacts, three brake checks, 0.000% AI offroad samples and actual Continue.
Final current-head CI is required before claiming the APK is ready.

Native depth checks retain all pixel thresholds and now run at both 1280x720
and 1920x864. They require exactly the existing one vehicle viewport, <=24
actual aircraft meshes, <=2 shared depth materials and hidden idle proxies.
Native moving flight now forces real frames every second/phase transition,
checking one ground submission and a bounded triangle count throughout.
Keep all 18 behavior gates and all prior native renderer/intro/export gates.

Compare real native frames before/after; record final diagnostics/Actions,
matching tested merge tree, APK integrity/version/renderer and compiled
resources in PR metadata. Software-Vulkan timings are diagnostics, not phone
FPS promises. Deliver the verified 1.25 APK. Preserve unrelated local intro
art edits; stage authored files only and ignore incidental import drift.
