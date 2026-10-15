# Level 3 squirrel cast

The user asked for the current Level 3 opponents to become recognisable as
squirrels from overhead, retaining the existing pixel-art style. This pass
preserves the supplied clothes, held weapons, poses and animation timing.

## Source and processing

- New anatomy was created with the built-in ImageGen tool (transparent output,
  reference-guided generation; no CLI/API fallback). The selected, unchanged
  output is `source/anatomy.png`. It contains an overhead head, curled tail,
  resting head and resting tail in four cells.
- Style reference: enlarged nearest-neighbour first frames from the existing
  gunman, bat, butcher and resting strips listed below. Character reference:
  the existing grey Level 1 squirrel, captured by `tools/level1_capture.gd`
  in its `13-squirrel` view. Its grey fur, pale muzzle and curled tail inform
  the anatomy; its 3D rendering is not the Level 3 art style.
- `tools/bake_level3_squirrels.gd` trims the generated parts, converts them to
  hard-alpha native pixels and a nine-colour palette, then combines them with
  the original frames offline. Heads follow each original head's pixel bob;
  tails move by at most one native pixel per walking pose. Original opaque
  clothes/weapons remain in the composites. Original source files are unedited.
- All 26 output frames use 80px transparent canvases, preserving the original
  frame centre and therefore the existing actor offsets, rotations and scale.
  The padding prevents the curled tails from being cut off during rotation.
- The game loads four ready-made strips through the existing immutable texture
  and SpriteFrames caches. It still draws one AnimatedSprite2D per opponent;
  it does not composite anatomy or allocate animation frames during combat.
- `source/bake_manifest.json` records input/output SHA-256 hashes and all walk
  frame bounds. The generated source and manifest are excluded from Android.

| Runtime output | Original body/weapon poses | Frames |
| --- | --- | --- |
| `walk_gunman_strip8.png` | `source/Combat/Enemy/sprEWalkSilencer_strip8.png` | 8 |
| `walk_melee_strip8.png` | `source/Combat/Enemy/sprEWalkBat_strip8.png` | 8 |
| `walk_butcher_strip8.png` | `source/Player/sprPigButcher_strip8.png` | 8 |
| `resting_strip2.png` | `source/Combat/Enemy/sprEDeadFrontPool_strip2.png` | 2 |

Original paths above are relative to `assets/level3/`. Walking speed stays 9fps;
the existing idle, attack warning, stun tint, death handling, blood, body and
weapon animation ownership remain unchanged.

## Exact built-in ImageGen prompt

Use case: stylized-concept. Asset type: production pixel-art character anatomy atlas for an existing top-down action game. Image 1 is the STRICT style reference: very small overhead 16-bit sprites with flat cream/grey shading, 1 native-pixel black outline, chunky square pixels, about 12 pixels across the head. Preserve this exact restrained low-resolution pixel language. Image 2 is only the squirrel identity reference: grey fur, pale muzzle, two pointed tufted ears, large curled bushy tail; do NOT copy its 3D rendering. Create ONLY four isolated anatomy parts, no bodies or clothing, on one genuinely transparent square canvas arranged as four equal 2x2 cells with ample transparent padding: top-left a grey squirrel head seen STRICTLY FROM DIRECTLY ABOVE, nose pointing RIGHT, ears visibly flanking the rear of the head, pale short rodent muzzle and tiny dark nose, tiny dark side eyes; top-right a bushy GREY SQUIRREL TAIL, curled into a broad C/sweeping plume with a narrow attachment root at its RIGHT edge, the big fluffy arc extending LEFT and slightly upwards, silhouette unmistakably squirrel; bottom-left the SAME overhead squirrel head in a flattened/resting pose, nose RIGHT, eyes closed, no injuries; bottom-right the SAME bushy tail resting sideways, narrow attachment root at RIGHT and broad plume extending LEFT, a slightly flatter silhouette. Render as if the entire canvas is a 64x64 logical-pixel atlas enlarged 16 times with nearest-neighbour: each cell has a 32x32 logical-pixel area, each head about 13x12 logical pixels, upright tail about 21x24 pixels, resting tail about 25x15 pixels. Small palette matching the sprites: near-black outline, dark charcoal-grey fur shadow, medium grey, pale silver highlight, cream muzzle, muted mauve ear interior. Hard pixel edges, few flat colour clusters, absolutely no gradients, soft lighting, 3D shading, antialiasing, sticker white border or cast shadows. No humans, no weapons, no text, no labels, no grid lines, no decorative objects. Four complete uncropped separate parts with consistent scale and EXACT top-down camera so we can keep the original game's clothing, weapons and eight-frame walk cycles unchanged.
