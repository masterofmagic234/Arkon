# Level 3 — complete squirrel rigs and motion

The three enemies are entirely new overhead pixel characters. The earlier
human-body/head-and-tail composite is superseded. No original human body or
walking/resting frame is used by these animations. Grey fur, pale muzzles,
tufted ears, short furry paws and curled tails carry the Level 1 squirrel
identity into the existing flat, black-outline Level 3 pixel style.

## Authorship and sources

Built-in ImageGen was used (reference-guided generation/editing, transparent
background, no CLI/API fallback). Its chosen outputs are copied unchanged:

- `source/rig_parts.png`: three rows of torso, head, tail, hind paw, forepaw
  and held weapon, respectively lean ivory/teal gunman, athletic blue-grey
  bat squirrel and broad ivory/ochre butcher with a cleaver.
- `source/rest_heads.png`: matching closed-eye heads for stun and fall.
- `source/rig_prompt.txt` and `source/rest_prompt.txt`: exact final prompts.

The style reference was a nearest-neighbour enlargement of the supplied
Level 3 gunman, bat, butcher and resting sprites. The species reference was
our grey Level 1 squirrel (`tools/level1_capture.gd`, `13-squirrel` view).
The previous three-guard in-level capture supplied scale/background context.
The generated rig sheet itself was the reference for the closed-eye edit.
Original supplied asset-pack files under `assets/level3/source` are unedited.

## Offline rig and runtime clips

`tools/bake_level3_squirrels.gd` trims the generated parts, converts their
alpha to hard edges, downsamples to native pixels and maps the result to a
16-colour palette. It composes transformed parts into ready-made PNG strips.
This is cutout rigging and deterministic pixel-format preparation, not
manually painted replacement art. `source/rig_manifest.json` records source
and output SHA-256 hashes, crop regions, part sizes and every frame's bounds.
All frames use an 80x80 transparent canvas, body origin (40,40), facing right.
Two pixels of clear padding are required on every edge.

| Clip, for each of three roles | Frames | Motion |
| --- | --- | --- |
| idle | 8 | Breathing, small head movement, resting tail sway |
| walk | 12 | Alternating hind paws, body compression/twist, delayed tail |
| windup | 8 | Braced paws, raised tail, weapon pullback and approach to contact |
| attack | 6 | Pistol recoil or melee contact, sweep and recovery |
| stun | 4 | Closed eyes, rocking body and loose tail |
| fall | 6 | Connected animal body tips over, weapon drops, tail settles |

There are 132 new complete poses in eighteen runtime PNGs, named
`{gunman,melee,butcher}_{clip}_strip{count}.png`. No old human-frame atlas is
loaded. Gunman steps are cautious, bat movement is springier, and the broader
butcher has a slower, heavier stride. All runtime textures are lossless,
nearest-filtered, with no mipmaps. Generation sources are excluded from APK.

`level3_squirrel_skins.gd` caches one immutable SpriteFrames resource per role.
`level3_squirrel_animator.gd` selects a baked pose without runtime compositing,
extra sprite nodes or automatic animation playback. Signed travel advances
paws: one cycle per 30 world pixels for gunman, 28 for bat, 42 for butcher.
Retreat reverses the cycle; stopping selects idle. The windup pose is scrubbed
directly against the actual .48s gun/.34s melee combat timer. Damage/shot still
comes only from Level3Enemy, followed by .18/.26/.30s visual recovery. Stun
interrupts recovery and pending attack. Fall settles after .36s, then holds.
World/dialogue pause freezes all motion. Death continues its visual fall
while health/colliders/mission state are already resolved as before.

Combat balance, hitboxes, navigation, doors, ten-guard roster, mission, map,
player input and all Level 1/2 content are unchanged. The previous gunman
sprite offset and bat/butcher quarter-turn are removed because all new rigs
share a consistent body origin and heading. Runtime scale remains .78.

## Verification

`tools/level3_animation_test.gd` checks equal-distance step placement across
speeds/timesteps, reverse walking, idle, pause, actual gun/melee windup and
single impact timing, recovery interruption, no late attack after stun and
settled death. The existing smoke and input-driven mission tests remain.

`tools/level3_squirrel_capture.gd` renders the actual three production actors:
44 poses at four headings, warning, stun and fall. `--record` adds a staged
228-frame, 24fps animation preview in the real level; it is not a gameplay
replay. Standard `tools/level3_capture.gd` checks eight level/mobile views.
Native captures use Compatibility/Mesa software rendering; they do not
establish performance on the user's phone.

## Exact prompts

### Full rig atlas

Use case: stylized-concept.
Asset type: production modular pixel sprite atlas for a 2D overhead action game, three completely redesigned grey squirrel enemy rigs.
Input 1 is the strict pixel-style reference: small chunky top-down sprites, black 1-pixel outlines, flat white/grey clothes and limited colours. Input 2 is squirrel identity only: grey animal with pale belly, tufted ears, short paws, huge curled bushy tail. Do not copy its 3D rendering. Input 3 shows the current in-game scale and floor.
Create one transparent PNG atlas of ISOLATED rig parts, precisely SIX equal columns and THREE equal rows (18 separate parts, evenly centered one per cell with generous transparent padding). No text or grid.
Every part is seen from DIRECTLY ABOVE, intended to face RIGHT. Uniform logical pixel size across all cells, about a 192x96 logical-pixel sheet enlarged with nearest-neighbour. Hard square pixels, tiny limited flat palette, no antialiasing.
Columns, left to right:
1. Animal TORSO only: compact grey pear-shaped squirrel body with round haunches, short neck socket at RIGHT, tail socket at LEFT; no head, no paws, no tail, no weapon. A small cropped vest/apron on the back, grey fur clearly visible around it. NOT a human chest, no trousers.
2. Squirrel HEAD only: muzzle points RIGHT, two pointed tufted ears visible on the upper and lower rear edges, grey fur, pale cream snout, tiny black nose, dark little eyes; strict overhead with readable animal silhouette.
3. Bushy curled squirrel TAIL only: narrow root at RIGHT-center, large C-shaped plume curving LEFT and UP, grey shaded in three chunky colour clusters. Big bold squirrel silhouette. Not a flat leaf or fish tail.
4. Single rear HIND PAW only: short bent furry haunch tapering to a small long-toed foot pointing RIGHT; grey fur, pale toe tips, overhead; no human boot.
5. Single FOREPAW only: short furry forearm with a little pale gripping paw at RIGHT, grey fur, overhead.
6. WEAPON only: isolated, horizontal, grip near LEFT and dangerous end RIGHT.
ROW 1: lean cautious pistol squirrel: small ivory shoulder vest with muted teal collar, compact grey body; small black pistol with long suppressor.
ROW 2: athletic bat squirrel: grey body with a cropped dark blue-grey vest and ivory shoulder stripe; slightly wider tail; warm amber wooden baseball bat, narrow grip LEFT, broad head RIGHT.
ROW 3: heavy butcher squirrel: broader round grey body with short ivory apron and muted ochre straps, larger head/haunch/paw/tail; short broad steel cleaver, dark handle LEFT.
Keep squirrel identity strong even without clothing. These replace ALL the old human bodies, not just heads and tails. Every row is a coherent complete character rig, each separated part must be intact and uncropped. All cells have the same empty transparent gutter, no parts touching. No assembled characters, no full-body duplicates, no floor, cast shadows, labels, borders, smooth illustration, 3D shading or gradients. Genuinely transparent background.

### Closed-eye heads

Use case: identity-preserve. Production pixel animation rig asset. The reference is our selected 3-row squirrel parts atlas. Create ONLY the three HEAD parts from column 2 of that atlas, preserving their exact squirrel designs, muzzle shapes, grey palette, tufted ears and overhead-right-facing orientation. Change their eyes to CLOSED in a peaceful unconscious/resting expression. Arrange three isolated heads horizontally in three equal cells, row order left to right pistol squirrel, bat squirrel, heavy butcher squirrel (slightly bigger). No bodies, paws, tails, weapons, text, frames or shadows. Same chunky native pixel clusters, one pixel black outline, flat restrained colours, hard pixel edges. Render like a 96x32 logical-pixel strip enlarged with nearest-neighbour; no smoothing or 3D. Each complete head centered with plenty of genuine transparent padding. This is for the fall/stunned animation, not a new character design.
