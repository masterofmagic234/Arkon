## Android 1.12 scenery atlas

`scenery_atlas.png` is prepared by `tools/prepare_scenery_atlas.py` from the
existing pine, oak, wheat and street-lamp cutouts. Images are fit into padded
512-pixel cells with Lanczos resampling; original sources are unchanged.
Cyrillic location/neon shop signs are native text/geometry rendered with the
DejaVu Sans font. Atlas uses mipmaps and VRAM compression. One atlas permits
real far-to-near ordering of foliage and solid architecture within each shared
mesh surface. Houses, retaining portals and forest cover are code-authored
world geometry. The old mountain is not instantiated by the race renderer.

# Live Camry replacement — Android 1.11

The current runtime uses the newer user archive from the branch root,
`toyota_camry_2018_point_tuned_clean.rar`, replacing the historical sprite bake
below. Original RAR SHA256: `e893dbff97f80866de61e37032b165e2b3fca0141ec58d436c711c1cdce8bf09`.
Its sole extracted GLB is unchanged, SHA256 `69532ee1e7817a046ec961a5672248ee3ea9ac0d79b14115cec739a8a934a5d0`, 28,991,604 bytes,
63,813 triangles, 140 static meshes and the supplied 8192px albedo/normal maps.
The uploaded archive remains unchanged in Git.

`tools/prepare_camry_runtime.py` bakes node transforms and joins the exact
triangles and UVs into one mesh with three surfaces: body, rear lenses, front
lenses. No triangle simplification or colour change. The supplied textures are
resampled with Lanczos to 2048px JPEG (quality 95); lens-only emission masks
are derived from their supplied red/white pixels. Explicit runtime images use
mipmaps and desktop/Android VRAM compression. Runtime GLB SHA256 `895392105cecb84d10364c0276e4757a83e9715662230b214f813490fa1c7b52`.

All three rivals are live continuously yawed 3D models in the existing player
viewport and World3D, using the sole existing shared camera. Rear emission is
1.2 while driving and smoothly reaches 7.0 while that rival brakes; headlights
remain on, with physical asphalt light pools. Ground/portal/tunnel view-ray
clipping hides individual fragments behind the actual opaque environment.
The old nine-angle atlases are excluded from the 1.11 APK. No image generation
or external stock assets were used for this replacement.

The mountain now uses a wider asymmetric rocky massif, dominant-plane rock
mapping, stone retaining faces, outcrops and sparse foothill trees. Far and near
road/scenery batches straddle the real portal plane; the foreground road and
bridge cover distant rock, while the rock covers distant terrain outside the
opening. Raised cutting faces stay above the verge. Rock texture provenance
below remains applicable.

---

# Moonlight Sprint assets

The Camry is the exact user-supplied `toyota_camry_2018_glass_wipers_corrected.glb` (9,885,488 bytes; 511,281 triangles). `source/camry-source.zip` contains that original file unchanged. SHA256: `59c578ae7527e1c8fcc795d9217fafb186e31b10b20b1532f5e0c86653bbaba6`.

`tools/bake_race_camry.gd` opens the archived GLB directly through GLTFDocument and renders nine rear angles in running-light and brake-light states. The real `Camry_tail`/`Camry_lamp` materials are emissive. The source geometry is not simplified. Runtime uses the transparent atlas with numeric ground anchors, projected shadows and real world-space headlight pools, preserving mobile cost at one sprite per opponent. The 5.4 metre orthographic frame is distinct from the actual 4.86 metre car length. Source archive/model caches are excluded from Android exports.

`wheat_tuft.png`: new generated transparent vegetation, built-in ImageGen, 13 October 2026. Production copy resized to 512×512 with alpha preserved, mipmaps and Android VRAM compression. Original generated image retained in the conversation. Exact prompt:

> Use case: stylized-concept. Asset type: transparent production vegetation sprite for a polished real-time night driving game. Create ONE isolated natural golden wheat clump, about 18 gracefully curved tall slender stalks with botanically recognizable mature ears of wheat and a few green-gold narrow leaves. It will be instanced in rows in roadside wheat fields, viewed in perspective from a low driving camera. Front orthographic view, cohesive tuft, subtly varied heights, airy spaces between stalks, fully visible roots touching the bottom with no ground slab. Premium natural game art, softly realistic tactile straw and wheat ears, restrained warm straw gold with muted olive stems, neutral diffuse lighting without baked cast shadow or night tint, believable thickness and fine detail readable at small sizes. Clump fills 88% of the square with clean generous transparent margin. Entire background and spaces between stalks genuinely transparent. No scenery, sky, panel, frame, label, text or watermark. One tuft only, no atlas.

All trees, lamps, existing textures and 240SX remain the project's supplied assets. Bridge/tunnel/fences are new projection geometry, shared with the main car camera. New park flowers, ferns, urns and ivy are volumetric meshes made in Godot, spatially combined with one shared material. No new external stock assets were downloaded.
# Mountain and location signs — Android 1.10, 2026-10-13

`mountain_rock.jpg` is a new game material generated with the built-in ImageGen
tool (generate mode, `transparent_background=false`). Original source retained:
`exec-ce5f1e30-9c71-43b4-b802-a640a65f8a14.png`, SHA256
`3ce09969e5ea0943945c560a15ae78342e77ce388beae599b77265231c7867ab`.
Runtime copy: 1024x1024 RGB JPEG, quality 93, SHA256
`f2e409cd06b7334641aa4b1aa9ccde4bb1cb7a533984ec051b5d4a2a19e16d51`.
It uses mipmaps and Android VRAM compression; natural slopes reuse the existing
park meadow material. World-space perspective texture coordinates avoid smeared
near rock and stretched cutting slopes. The source image is kept unchanged.

Exact generation prompt:

Use case: stylized-concept. Asset type: seamless square albedo texture for a real-time driving game's rocky mountain terrain, 1024x1024. Primary request: naturally weathered slate-grey limestone CLIFF ROCK, not constructed masonry. Flat orthographic surface fully filling the image. Irregular interlocking broad fractured rock plates and mineral strata, smaller chipped edges, finely tactile stone grain, subtle pale grey veins and restrained dark sage lichen in some cracks. Muted cool grey, taupe-grey and desaturated olive variation, readable medium values under moonlight. Realistic game-material quality with subtle painterly softness compatible with detailed tree billboards and an older racing game. Completely seamless on all four edges, neutral soft diffuse albedo lighting, no directional shadows or bright highlights, no overall lighting gradient. Natural organic fractures at mixed angles and scales, no repeated rectangular blocks, no bricks, no mortar, no regular grid. No landscape, sky, mountain silhouette, tunnel, road, trees, text, watermark, border, vignette or perspective. Texture only.

`location_signs.png` is a deterministic 512x640 RGB atlas: five 512x128 boards,
bold DejaVu Sans lettering rendered once at 38px and 24px for the secondary line.
It is not generated art. Text: ЗОЛОТЫЕ ПОЛЯ, ЛУННЫЙ МОСТ, ГОРНЫЙ СПУСК,
ГОРНЫЙ ТОННЕЛЬ, ОГНИ ГОРОДА. Four approach boards say `140 м →`; the city
board is after the exit and says `ГОРОД`. Mipmaps and Android VRAM compression
are enabled. Glyph pixels stay stable instead of generating tiny new font sizes
while a sign passes. An input-transparent HUD notice preserves reading time.

# Forest cutting and distinct outskirts — Android 1.13, 2026-10-14

`race_outskirts.gd` authors independent lots as cached world-space geometry;
no downloaded stock assets, new model viewport or new generated artwork.
Existing pine/oak/lamp/wheat cutouts remain unchanged. `scenery_atlas.png`
(2048x1536 RGBA, mipmapped Android compression) is reproducible with
`tools/prepare_scenery_atlas.py`: existing cutouts, six location names,
eight DejaVu Sans neon shop labels and a solid white color-sampling tile.
Labels: МАРКЕТ 24, КАФЕ • 24, АВТОСЕРВИС, АПТЕКА, ЦВЕТЫ, ПЕКАРНЯ,
АРКАДА, ДИНЕР • 24. Source city panorama and moon images remain unchanged;
the moon's runtime placement matches the halo already drawn in the panorama.

# Distinct scenic complexes — Android 1.14, 2026-10-14

`race_landmarks.gd` authors eight separate location complexes into the existing
cached scenic atlas mesh. Boxes, timber beams, barn cross-bracing, pitched roofs,
8-sided grain cylinders, glass panels, tent canvas, lookout tower, forecourt
canopy/pumps/pricing and diner details are repo-native geometry. No downloaded
models, generated stock images, extra worlds or per-object processing nodes.
`prepare_scenery_atlas.py` retains existing cutouts/shop/location art and adds
nine DejaVu Sans labels in the previously unused left-bottom region: ЛЕСНИЧЕСТВО,
КЕМПИНГ • СОСНЫ, УСАДЬБА • ЗОЛОТЫЕ ПОЛЯ, ЭЛЕВАТОР, СМОТРОВАЯ ПЛОЩАДКА,
ЛЕСНОЙ ПРИЮТ, LUNA OIL • 24, NIGHT DINER, 95 • 98 • ДИЗЕЛЬ. Same 2048x1536,
mipmap/Android compression settings. City and moon source pixels stay unchanged.
