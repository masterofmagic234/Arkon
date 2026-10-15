# Carolina intro redraw — Android 1.22 / code 23

Repository masterofmagic234/Arkon, branch fix/level2-final-game-flow, PR 11.
Do not merge automatically. Starting head cbbb2c055385ff238da2e4030f8d0bae55879f7d
was the successful Android 1.21 squirrel-radio/pursuit release. Preserve that
work, all three levels, the 240SX handling/camera and Forward+ / non-HDR 2D.

The user authorized a high-quality redraw of adult Carolina, at the LEFT of
the existing opening cutscene, using their supplied photograph as likeness
reference. Keep the existing anime/night-bedroom style and Darina at right.
Runway is connected but its Free account had no credits or video model access.
No paid generation, upgrade or trial was used. Built-in ImageGen authored
24 head/pose/expression keys. The original photo is NOT in this repository.

## Delivered artwork and video

All four root MP4s now contain the edited 1920x1080 masters, in original order:
1789650644963: 97 frames / 24 fps (wake-up, silent);
1789649201942: 125 / 30 (dialogue lines 0–4, loops for reading);
1789650878847: 97 / 24 (Darina enters, silent);
1789649329293: 121 / 30 (dialogue lines 5–16, loops for reading).
The 440 original video-track timestamps/frame counts are preserved. Previous
extra MP4 container time came from ignored audio padding. Game videos remain
silent; the 17 existing Russian interactive dialogue lines are unchanged.

Carolina has natural ash/honey light-brown hair and parted bangs, gray-blue
almond eyes, softer adult facial proportions, natural nose and fuller lips.
Pose keys include sleep, rising, head turns, eye rubbing/hand overlap, blinks,
open eyes and the final smile. Original background, Darina, cat, body and
camera footage remain around the edited head. Existing source-video quirks
outside this edit remain; this is not a newly generated entire bedroom movie.

`tools/redraw_intro.py` is an optional offline authoring utility (numpy,
opencv-python-headless, FFmpeg), using the separately delivered
Carolina-Cutscene-Keyframes-v2.zip source archive. Original pre-edit videos
are recoverable at the starting commit above. It tracks original motion,
registers authored heads, uses bounded dense correction and rotoscoped mattes,
and composites one pose at a time. It is NOT a generative video model and the
440 frames are not 440 independently hand-painted drawings. No EbSynth or
Runway video output is represented as used. Do not restore early optical-flow
prototypes: they had stretched hair, double faces or locked closed eyes.

## Runtime and build

The current Android workflow previously omitted the intro conversion step and
1.21 actually contained no OGVs. `tools/prepare_intro_videos.py` now checks the
reviewed MP4 hashes against assets/intro_video_manifest.json, builds four
1280x720 q9 silent Theora clips, and validates frame counts, FPS, duration and
resolution. Outputs/compiled.json are build products; only the directory's
README is authored/staged. Do not commit generated OGVs/import drift/captures.

Menu remains the startup scene, with the three existing direct debug level
buttons. A new START STORY button resets the run and opens the intro through
SceneFlow. Completing/skipping the intro enters Level 1 through SceneFlow too,
keeping GameState.current_level correct. A visible skip button / Escape handles
skipping; incidental taps during silent shots do not skip the story. Click,
touch, Enter/Space advance dialogue. The root/ornamental panels ignore pointer
input so mouse dialogue input really reaches the scene. Active transition fades
are canceled on skip, preventing callbacks from restarting the video.

Video is fitted to 16:9 rather than stretching faces on wide phones. Responsive
22px dialogue text stays inside its panel; title/name text and skip affordance
are clearer. Forward+ and HDR 2D settings are unchanged.

## Validation and delivery

Local Godot 4.7.2 intro test passed: real decoding/natural clip completion,
17 lines through production mouse input, read-time looping, silent transitions,
four landscape layouts including ultrawide, undistorted video, explicit skip,
new-run reset and correct Level 1 handoff. Full campaign regression passed.
The authoring pass inspected all 440 frames and corrected ghosting, hair masks,
key timing, hand/eye poses and artificial sharpness pulsing.

CI keeps all sixteen previous behavior gates and renderer/aircraft checks. It
adds intro behavior and native Forward+/Vulkan video/framebuffer captures before
Android export. Exact published-head CI, merge-tree match, APK/OGV integrity and
native captures must be verified before delivery; final evidence is recorded
in PR metadata alongside the release. Native captures are not a phone FPS test.

Deliver the verified 1.22 APK plus a standalone Full HD visual preview. Preserve
Library identities/version history for previous APK, preview and source archive.
Never publish the original reference photo or private contact information.
