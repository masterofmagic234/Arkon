# Moon Park nature material pass

Created with the built-in ImageGen tool on 2026-10-11. Original generated images were kept; runtime files are resized and format-converted copies. No prior assets are overwritten. RGB materials are 1024 x 1024 JPEG (quality 94); the RGBA silhouette cluster is 512 x 512 PNG. All six runtime texture resources use mipmaps and Android VRAM compression. `park_meadow_tuft.svg` is a new code-authored vector asset with filled curved blades; it is not generated raster art.

The wall uses world-space coordinates; the meadow tiles at 2.6 metres. Bark UVs use physical arc length. Canopies use three triplanar samples at a fixed 1.25 m scale to avoid pinched sphere UV poles. Bark, ground and masonry use one albedo sample each. Opaque crowns and alpha-tested edge clusters have separate distance budgets (76 m / 42 m). Existing wall_zone textures, gravel and wall-top bushes keep their previous materials.

## park_outer_limestone.jpg

Source: `exec-2aee8e0b-8de0-4f19-becf-c01bc2b436ce.png`

Generation prompt:

Use case: production texture for a real-time 3D game. Create ONE perfectly seamless square albedo texture, 1024x1024, for the main exterior garden walls of a romantic old moonlit park. Flat orthographic front view of elegant weathered pale grey-green limestone ashlar masonry, straight horizontal courses and staggered narrow mortar joints. Around six courses vertically, varied large rectangular blocks, carefully aligned true masonry, gently rounded time-worn stone edges, tactile fine-grained limestone, small pores, faint mineral flecks, subtle warm chalk and cool sage variation. Restrained dark olive moss only in a few narrow joints, never covering the stone faces. Quiet large stone faces and fine rich detail. Premium realistic hand-crafted game material, slightly painterly softness. Neutral diffuse evenly lit albedo, no directional light or baked highlights or shadows; light readable midtones, saturation low, enough contrast to read under blue moonlight and warm park lanterns. Continue exact course heights across both side edges; top and bottom also tile continuously; no overall gradient or dark vignette or border. No irregular wavy bricks, no rubble, no plants in front, no perspective, no scene, no text, no watermark. Image fills frame entirely, production-ready stone surface only.

## park_meadow.jpg

Source: `exec-71d963cd-991b-4824-872a-db18b6f4ded6.png`

Generation prompt:

Use case: production seamless albedo texture for a premium real-time 3D game. Generate a square 1024x1024 flat top-down ORTHOGRAPHIC grass lawn surface for an enchanting old park. Image covers approximately 2.6 by 2.6 metres of actual ground. Beautiful fine short living grass blades form a soft dense natural meadow carpet, mixed forest green, muted sage and olive-green, understated soft moss between fine grass, tiny occasional dried straw and very sparse little oak leaf fragments barely noticeable. Grass dominates over 90 percent. Fine realistic blade texture, natural intertwined directions, intimate tactile detail, low-to-moderate contrast, quiet even overall green midtone, subtle small organic variations with no recognisable large motifs. Premium physically plausible game albedo with subtle painterly softness. Uniform neutral diffuse lighting so the actual game moon and lamps provide all lighting. Seamless on all four edges, no border, no big dark bare soil patches, no oversized clover leaves, no flowers, no stones, no directional shadows, no gloss, no baked lights, no vignetting, no perspective, no text or watermark. Flat material texture filling frame only, not a landscape photograph.

## park_oak_bark.jpg

Source: `exec-7b38f4bd-eac5-45e4-ac37-7b3a237588fb.png`

Generation prompt:

Use case: production seamless bark albedo texture for a beautiful real-time 3D game. One square 1024x1024 orthographic flat frontal surface of mature English oak bark. Natural subtly twisting VERTICAL fissures and interwoven raised ridges, organic narrow plates, believable medium scale, finely detailed dry rough grey-brown oak bark, warm taupe silver-grey ridge faces, dark umber recesses, very restrained tiny sage lichen flecks. Elegant living old park tree rather than dead wood. Neutral evenly diffuse lit albedo, no directional lighting or shadows, no shining highlights, no painted moonlight. Excellent detail, physically believable game art with slight hand-crafted painterly softness. Midtone readable, never pitch black. Seamlessly tileable left/right and top/bottom, visually continuous ridges at borders, no large unique knot or central seam, no horizontal rings or cut end-grain, no green blanket, no trunk silhouette, no branches, no perspective, no border, no text or watermark. Texture only fills frame.

## park_oak_canopy.jpg

Source: `exec-bfccf383-9db3-4468-96b1-fd608fa47652.png`

Generation prompt:

Use case: seamless oak canopy albedo for a premium real-time 3D game. Create ONE square 1024x1024 completely filled flat texture of many small overlapping English oak leaves in a dense living tree canopy. Botanically clear softly lobed oak leaf shapes and fine veins, alternating natural directions, varied subtle green tones: muted fresh forest green and soft grey sage, occasional olive tips, fresh appealing healthy leaves. Leaves medium-small, roughly 12 to 16 leaf lengths across the texture, dense richly layered coverage, quiet non-repeating variation, leaf edges visible but no harsh black gaps. No large central shapes. Premium realistic game art with subtle painterly softness. Albedo neutral soft diffuse even illumination, readable medium green values, no baked sunlight or directional shading, no shiny highlights or bright lime colors. Flat surface only, no tree scene, no branch trunk, no skyline. Perfectly seamlessly tile on all four edges, no vignette, no border, no perspective, no text or watermark. Opaque foliage material filling the frame entirely.

## park_oak_cluster.png

Source: `exec-82fdc568-7e46-487a-8fd4-5a3c76383ae3.png`

Generation prompt:

Use case: alpha-cutout foliage cluster texture for a premium real-time 3D game tree. Create ONE isolated beautiful airy small English oak twig with about 16 to 22 botanically correct softly lobed oak leaves, arranged in a pleasing irregular roughly rounded cluster with several small transparent gaps. Small slender branching twig, leaves spread naturally in several directions, some tilted with varied sizes, fresh muted forest green and silver sage green, fine elegant leaf veins. Excellent realistic leaf shapes and tactile detail, slight painterly softness compatible with premium game environment art. Soft neutral diffuse illumination, no directional shadow or rimlight, clear midtones. Cluster occupies around 85 percent of square image with generous completely transparent margin all around. All background and the gaps between leaves MUST be fully transparent, clean alpha edges, no white or grey matte. One cluster only, front orthographic view, no second cluster, no atlas or panels, no pot or ground or tree trunk, no text or watermark. This is a production transparent RGBA sprite for small leaf groups at the silhouette of a 3D tree canopy.
