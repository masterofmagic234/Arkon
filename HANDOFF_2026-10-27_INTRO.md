# Android 1.44 — new intro heroine and filmed motion

The owner provided five bedroom storyboard stills and three private likeness
photos. Replace only the adult heroine on the left, following those references,
while preserving the existing interactive intro. Do not claim literal biometric
identity or replace likeness review with low-resolution frame-delta checks.

Runtime remains `scripts/intro_cinematic_v2.gd`, unchanged: four silent OGVs,
17 original Russian lines, reading loops in slots1/3, automatic slots0/2,
held-texture decoder handoff and0.12s blend, Skip, and the same Level1 handoff.
The four canonical root MP4 names and121/125/121/121 frames at30fps remain.
Godot consumes1280x720 Theora, generated/hash-checked by the existing converter.
Compatibility, the1.43 garden, lighting and gameplay remain as before.

Five new ImageGen keyframes use one room/camera. Frame3's original perspective
is normalized to the other room views; its waking pose is retained. The heroine
has loose near-black roots/curtain fringe and burgundy lengths, with facial
proportions guided by the private portraits. Pajamas, child, cat, plush and room
follow the storyboard. Static ghost-garland differences were corrected before
animation. The private reference photographs must stay out of git and APK.

Four Runway image-to-video sources provide actual filmed/generated body motion,
not the former rigid cutout/joint animation. Source IDs, prompts, hashes and the
accepted asset mapping belong in `art/intro/runway144/authoring.json`. Raw sources
and generated keyframes are retained there for reproducible offline assembly;
the whole authoring directory remains excluded from import/export. Rejected
trials stay in scratch and must not be promoted.

`tools/prepare_runway_intro.py` stages candidate MP4s outside the root and never
changes the approved sources or manifest automatically. It retimes real motion,
fits aspect without stretching, interpolates24/25fps footage to30 when needed,
and anchors shared endpoints. Natural reading loops are preferred; optional
short-window ping-pong remains a fallback requiring explicit visual inspection.
It validates both MP4 and actual q9 Theora against the unchanged thresholds:
boundary/reading seam<0.8, adjacent-frame gray delta<2.5, timeline±1frame and
at least90% decoded pictures. Preserve these checks.

Visual QA must inspect faces, eyes/gaze, hands, child steps, hair/duvet occlusion
and room objects throughout each shot, including dense blink/tail samples.
One rejected opening passed numerical checks while opening oversized blueish
eyes toward camera near its tail; it must never be shipped. Two earlier reading
trials were rejected for large pose/expression changes. A green motion metric
alone is not visual approval.

After visual/numerical approval, promote the four staged MP4s and update all
manifest hashes, artwork metadata and authoring provenance together. Keep17
dialogue lines and the runtime script intact. Use the retained headless/native
intro test, full CI, stable Android signature and artifact inspection before
delivery. Final source/merge tree, accepted media hashes, CI and APK evidence
belong in draft PR11. No automatic merge; P60 game FPS is not re-measured here.

Local signoff: all five generated keyframes and four accepted raw takes pass
visual/provenance/privacy review; final retimed transition2 passes dense
face/step/join review. Strict MP4/q9Theora, then ORIGINAL production headless
and native intro tests pass on the promoted root movies. Native maximum motion
is2.483523/255 in opening0 and2.359138 in transition2; retain original2.5 gate.
The helper's explicit --time-map2 and all accepted hashes are in authoring.json
and art/intro/README.md. Trial scene-detector/interpolation-order hypotheses
were disproven and are not retained as implementation changes. Only the smooth
local timing map is used. Final CI/signature/package evidence belongs in PR11.
