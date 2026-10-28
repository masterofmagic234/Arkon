# Android 1.48 — performance-first Level 1

The owner measured 1.47 on a Samsung S23 Ultra / Adreno 740 at 38.8 FPS in
game, with a 3088×1440 window, 0.455 3D scale and MSAA2. The paused baseline
was 44.3 FPS; hiding vegetation reached 59.9 FPS under the 60 FPS limit.
Later single-order MSAA/shadow controls were slower and are not reliable
evidence of those features' individual cost.

The owner's latest instruction explicitly supersedes the previous rigid
foliage/card, transform and pixel-identity requirements: prioritize Level 1
performance while retaining its recognizable night-garden appearance where
practical. Real distance LODs, reduced distant density, cheaper shading and
changed foliage shadows are authorized. Preserve quest logic, collisions,
saves, readable landmarks, characters, weapons, sound, both cinematics and the
other two levels. Keep Compatibility.

## Real baseline and implementation

The performance baseline is the actual released 1.47 source
`0d858100521e0a0a7de3e201dc2ea3aaa978fd06`, tree
`e755835fb9e4b4887a8356354f0ca54e8051932f`. The old 1.33 Forward+ reference
is not an Android 1.47 performance baseline.

The old renderer submitted 77 overlapping cards per ordinary tree crown and
81 per cypress, with separate opaque/edge surfaces and original-card shadow
proxies. It repeatedly reordered and uploaded large instance buffers while
moving. The 1.48 implementation replaces this with immutable spatial foliage
chunks, much cheaper middle/distant opaque crowns and distance-dependent 3D
undergrowth. Explicit `reference_147` mode retains the real original renderer
and materials for reversible comparisons; it is not the default.

Production vegetation no longer casts real-time shadows. Near cards keep
their authored atlas silhouettes; middle/far crowns use simpler opaque
volumes. Grounded 3D herbs have less geometry and reduced distant density.
The saved evening GI and architecture shadows remain. Unsupported foliage
shapes retain their original geometry and material, including all 38 lily
pads beneath the pond flowers.

Fast terrain and architectural materials must be applied to actual visible
baked receivers. Their materials live on mesh surfaces, often with a null
node material override; terrain shaders may be embedded in the baked scene.
Changing only an external shader or hidden source batch does not optimize
the visible garden. Retain the existing 231 receiver meshes, UV2 bindings,
baked GI, collision bodies and source identifiers.

The render pixel cap remains 921600 pixels and MSAA2 for the matched baseline
comparison. Targeted shader/geometry changes provide the speedup rather than
silently lowering the comparison resolution. No change to other levels'
renderer configuration is implied.

## Measurements and limitations

Use balanced warmed 1.47/1.48 comparisons, the same camera/pixel count/MSAA
and actual render-fenced frames. Include moving-camera CPU/buffer costs,
submitted draw calls/triangles, screenshots and shader/runtime error checks.
Do not replace performance acceptance with relaxed image-error thresholds.

Godot 4.7.2 GLES3 enables vertex lighting when requested by a material; older
4.2 documentation saying it is ignored does not describe this engine.
MultiMesh instances share mesh LOD selection from the whole AABB, making
physical spatial chunks important. Compatibility does not support the
Forward+ visibility-range fade modes; do not assume they provide hysteresis.

GLES3 disables its depth prepass for Adreno by default. Isolated software
benchmarks use startup `driver/depth_prepass/enable=false` in both versions
to match that configuration. A runtime ProjectSettings edit is too late.
Do not place a temporary benchmark `override.cfg` in the shared project or
ship it in Android. This does not turn llvmpipe timing into Adreno timing.

Phone diagnostics compare returned baselines, repeat controls in reversed
order and report sample counts, shader warmup, spread and drift. Gameplay FPS
is kept separate from an explicitly uncapped paused diagnostic test. Restore
the original frame cap, VSync, camera, profile, input and render state on
completion, cancellation, focus loss or resize.

Final release evidence belongs in draft PR11: source/merge tree, all three CI
jobs, actual official artifact digests and independently verified signed APK.
Godot remains 4.7.2; Android is 1.48 / code49 with the existing package and
certificate. Do not merge automatically. Actual device FPS requires a phone
measurement; software rendering alone cannot establish it.
