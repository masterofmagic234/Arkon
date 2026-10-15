# Forward+ migration — Android 1.19 / code 20

Read this first. Repository masterofmagic234/Arkon, branch
fix/level2-final-game-flow, PR 11. Do not merge. Starts at published
87183d8f5a3043dd16ae174adacfcfe36abbf4d4 (successful Actions #1021).
The user has no PC available and explicitly requested Forward+ now. This
means BOTH the default renderer AND the Android/mobile override, not only PC.

## Change

- project.godot selects forward_plus for both profiles. HDR 2D stays off to
  preserve the existing canvas colors and Level 3 nearest-filter pixel art.
- Android version is 1.19/code 20, same arm64 package/debug signing/output.
- Menu shows version, actual RenderingServer method and actual driver. This
  makes an engine fallback on an unsupported device visible to the player.
- Existing levels, lighting design, materials, geometry, race camera/handling,
  squirrel animation, combat and input are retained. No new expensive effects.
- The first native pair exposed washed-out park colors: source_color uniforms
  were assigned Vector3, which bypasses Color.srgb_to_linear in Godot's RD
  material upload. Sky fog, masonry, timber and canopy now use Color values.
  Authored golden-leaf/water/path/reed/shore/lichen colors also use source_color
  uniforms. Numeric
  palette values and Compatibility appearance are retained.
- Native captures live outside res:// in runner.temp. The Android preset also
  excludes build/*, so QA images/reports cannot enter the exported game.

## Validation contract

Keep all fourteen existing behavior gates. Native CI must explicitly render
with Forward+ / Vulkan and reject fallback; headless behavior checks alone
cannot prove the renderer works. A Compatibility baseline and actual Forward+
capture menu, three park views, cars/tunnel/city and the diner/squirrel cast.
The fixture checks real framebuffer canvas sRGB/alpha and nonblank scene
pixels. Its shots are staged visual fixtures, not gameplay playthroughs.
The existing deeper native race gate now runs Vulkan, including 120 Hz
presentation, road vegetation/rock depth, live-car visibility and portal
occlusion. Both native checks precede Android export. Images/report.json are
uploaded even when a native check fails, so discrepancies can be inspected.

Current revision is being validated; do not claim success until checking its
exact remote HEAD, successful matching Actions run, corresponding PR merge
tree, APK manifest and packed renderer settings. Real software Vulkan draws
do not establish phone GPU compatibility or frame rate. The menu label helps
the user report the mode their own phone actually starts.

Read HANDOFF_2026-10-15_LEVEL3_RIG.md for squirrel rigs,
HANDOFF_2026-10-15.md for the park and HANDOFF_2026-10-13_SPRINT.md for the race.
