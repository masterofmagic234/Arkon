# Quiet Park — Level 1 art direction, Android 1.29 / code30

Repo masterofmagic234/Arkon, branch fix/level2-final-game-flow, PR11. Do not merge
automatically. Baseline 4f3ba82db86255ad1d8e29bf7136bbaa0de86e94, tree
3396c58a20ef8d5ab122930bb5828719ae3f48dd, verified successful Actions #1053
(39557265307), Android1.28/code29. The user's new request is a full visual
redesign: Level2 and Level3 feel minimal, beautiful and cosy; Level1 does not.

## Direction and ownership

Reviewed actual 1.28 native images of the city chase, diner and park. Level1's
photographic masonry/grass, dense crown/sprig detail, heavy borders and floating
HUD panels competed for attention. Rebuild the presentation as a quiet graphic
park: ink blue, lagoon greens, cream and lantern amber. Warm paths guide the eye
through broad calm surfaces, with one large silhouette per area. This is the
newest art direction; older requests for photographed stone are superseded.

level1_cozy_palette.gd owns the environment palette. Flat, matte vertex-lit
materials replace photographic ground, masonry, bark and crown surfaces.
Ground/path/static shaders have no texture samples. No per-fragment noise,
bump map, new light, screen effect or extra viewport was added. The sky uses a
restrained dusk gradient; the small code-native sky SVG supplies water's painted
reflection. No AI-generated bitmap assets were needed. Curated grass is confined
to the four planted focal points instead of scattered across the entire park.
Trees keep their branch/trunk rig but use fewer, larger smooth crown masses and
no decorative alpha sprigs. The gold oak retains real rope/branch anchors.

Natural garden edges and normal cover are 2.05m, making views less enclosed.
Gardener lodge, tower and oak blockers retain 3m support. The canonical cell map,
walkable graph, pickup positions and branches stay unchanged. Generator outputs
collision heights and the same PARK_WALL_HEIGHT used by the visible shell and
occluders. Every visible wall still has physical backing. Gates are 2m, with
matching leaf collider, local visual mesh and moving pivot height. Player-eye
and guard sight rays still hit the real boundary. Do not lower presentation
without updating its physics and conservative occluders in this generator.

The observatory's roof has fewer decorative ribs; bridge rails have fewer
supports and a pale deck; the entrance lintel is slim. Interactions are marked
by a small ring/three leaf lights rather than prison-like bars. Device labels
appear in context. Fireflies, wind/water audio, six acorns, keys, three shortcuts,
puzzles, finite14 guards, normal/quiet routes, scoring and campaign remain.

## Interface

The HUD uses one ink-coloured bottom dock for counts, health/ammo and mobile
controls, with small area/objective text above. The portrait and duplicate
persistent challenge row no longer compete with the scene. Context action,
quiet/dash and pause retain their existing finger ownership and game commands.
Buttons use short labels and scale-aware fonts. The new code-native SVG held
slingshot replaces the old large weapon texture. The route overview borrows
Level2's quiet line-map grammar; undiscovered pickups/guards remain hidden.
Default map labels stay hidden. Pause keeps an opaque readable panel.

## Performance and validation

Retain 1.28's automatic scene-local Android profile: glow off; at most1280x720
3D pixels, native UI, prior lower scale respected and restored before Level2.
Desktop also avoids full-screen glow for the new restrained art direction.
Renderer stays Forward+. Level2/3 art, driving, pursuit, intro and campaign are
not restyled. Software Vulkan is visual/budget evidence, not phone FPS.

All21 headless gates passed locally after the core redraw. The eight affected
estate/park/heist/polish/normal/exploration/quiet/full-flow gates passed again
with the lower gate colliders. Native11-view captures verify the real art and
small/wide mobile control layouts. Physical outward-wall checks, body-sized
navigation, 6500 water samples and input-driven routes remain in use. Generator
--check must pass. Native mobile budget remains <=260 calls /150k triangles.
Exact final native counters and matching successful CI/APK evidence belong in
PR11's body; do not add a new source commit merely to record release evidence.

Read this file and LEVEL1_PHONE.md before older estate/visual handoffs. Verify
actual branch HEAD and matching Actions run before claiming any current APK.
