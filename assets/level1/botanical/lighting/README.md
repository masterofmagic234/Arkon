# Offline garden lighting

The deterministic garden has 121 source UV2 receivers, partitioned into 231
runtime meshes on a 48-meter grid with unchanged UV2 charts and atlas bindings.
`garden.scn` and
`garden.lmbake` contain actual Godot LightmapGI data; runtime activates these
receivers in the color pass. Original instanced geometry supplies its original
culled realtime shadows. Forward+ stays active.

The bake contains sky visibility and one indirect-light bounce. Ground, paths
and planar architecture use lightmaps. Repeated foliage, branches, natural rocks,
round architectural props and characters use the baked probe volume, retaining
their original instanced geometry and LODs. Prepared receivers for those props
stay hidden. The original sun
continues to illuminate the garden and cast its original realtime shadows, so
moving squirrels and leaf shadows remain responsive. Runtime SSAO is disabled while the bake is active,
removing its normal/roughness prepass requirement. MSAA2, resolution, foliage
placement, textures, fog and sunlight settings retain their previous values.

Regenerate with Godot 4.7.2's native editor, a display and a Vulkan driver:

```sh
python3 tools/bake_botanical_lighting.py /path/to/godot
```

The generator transforms static geometry into world coordinates and corrects
normals with the inverse transpose for nonuniform scales. It unwraps UV2 at
0.65 world units per texel, then rebuilds mesh LODs. The offline source includes
323 foliage occluder meshes built from the 16-pixel opaque foliage contours.
These are approximations for indirect occlusion; original realtime solar-shadow
geometry is preserved. Occluders have small overlapping receiver charts that
are discarded during finalization. Texture-based bounces are disabled, so
indirect rays use actual triangle intersections instead of those invalid charts.

Bake settings: one bounce, nondirectional lightmaps, 32 rays, JNLM denoising,
2048 maximum atlas size, automatic subdivision 8 plus 748 manual probes (901 total in this bake) along
the playable terrain. These are experimental lighting settings for phone testing;
they do not establish playable device FPS or exact lighting fidelity.

`garden_source.scn` and the intermediate `meshes/` directory are reproducible
offline input and are excluded from Git and the APK. The finalized scene embeds
its 231 receiver meshes. Color meshes use the engine's default one-display-pixel
LOD threshold, subpixel at the capped 3D resolution; full-detail geometry remains
available nearby. The atlas contains nine 512×512 layers stored without
lossy VRAM compression (about 18 MiB RGBA half-float GPU storage), preserving
lighting gradients. Finalization must use a native renderer: Godot's dummy renderer discards
the probe arrays and must never re-save baked data.

`botanical_lighting_test.gd` verifies actual receiver bindings, UV2, textures,
runtime activation, original sun shadows and full A/B restoration. Native runs
also verify probe coverage. `botanical_lighting_capture.gd` captures both lighting
modes with identical cameras for visual review. The existing geometry benchmark
keeps the old lighting on both sides, independently testing the foliage rebuild.
Its original 500-call/260k-triangle gates remain. The separate lighting capture
allows 550 calls for unique UV2 geometry (650 only for the experimental leaf path)
while retaining the 260k triangle ceiling,
including the wide P60 viewport and character closeups.

The 1.40 on-device diagnostic compared the bake with original 1.39 lighting and
separately added SSAO/normal prepasses. The targeted 1.41 diagnostic instead tests
alternative leaf ordering, shadow reception, lighting and filtering against 1.40.
All stages restore production state.
The owner measured 1.39 at 5.4 FPS / 182.3 ms GPU versus 2.7 FPS / 369.6 ms with
original cards at the same camera. For 1.40, P60 measurements at another fixed
pose confirmed 122.1ms GPU / 8.1FPS versus 192.3ms / 5.2FPS with 1.39 lighting.

Diagnostic 1.41 preserves the measured 1.40 gameplay renderer. It tests an
alternative binary leaf depth/color path behind its opaque diagnostic panel.
`botanical_depth_capture.gd` compares that path to 1.40 under the SAME baked light.
Whole-frame limits are MAE .2/255 and no more than .1% of pixels changing by >8.
Its Adreno performance is unmeasured; warmed software timing did not establish a
win. The original path and all quality ablations restore after the diagnostic.
