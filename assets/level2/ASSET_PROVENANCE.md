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
