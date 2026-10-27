# Android 1.45 — park departure manga interstitial

Owner requested an additional black-and-white manga cinematic: Carolina drives
the existing240 out of the park; squirrels speak their own language; a commander
orders pursuit, helicopter launch and recovery of the acorns at any cost. The
owner explicitly selected squeaks/chattering with Russian subtitles.

Keep the existing1.44 bedroom intro, its17lines, media and controls intact.
Compatibility, garden1.43, baked lighting and existing pursuit/diner remain.

The new26s film has four intentional cuts: departure0–6, scouts6–11.5,
commander11.5–20, helicopter20–26. Actual model renders guide the240S13,
scout/tank species and ORЕХ-1 silhouettes. Carolina uses the1.44 illustrated
likeness. The commander is a distinct capped/headset officer based on the tank
anatomy, so either peaceful/defeated guardian outcome remains coherent.

Runtime assets live in assets/cinematics/park_escape: film.ogv, audio.ogg and
timeline.json. The timeline controls six independent Russian speaker/caption
cues; there are no baked text bubbles or spoken Russian words. Runtime uses
decoded video position as master clock and keeps its separate SFX soundtrack
synchronized. Pause/background pauses both; return requires explicit resume.
Sound respects existing SFX settings. Skip/end routes to Level2 exactly once.

SCENES gains park_escape; CAMPAIGN does not. A successful Level1 completion is
recorded before the interstitial; no start_new_run/reset occurs. Boarding now
saves the rewarded car checkpoint; it is cleared only once Level2 has really
arrived. Rewarded resumes restore six ephemeral GameState acorns. This closes
the new force-close window during playback without introducing a save format.
Direct menu/debug Level2 launch remains direct. Race radio subtitle pronouns
are corrected to refer to Carolina consistently.

Generated art/video/audio sources and safe provenance belong under
art/intro/park_escape145, already excluded by art/intro/.gdignore and APK export.
Never include the owner's original portraits or signed service URLs. Neutral
grayscale video conversion removes slight warm tint in generated keyframes.
Use tools/prepare_park_escape_video.py for staged assembly and pinned-master
Theora conversion; tools/prepare_park_escape_audio.py reproduces the soundtrack.
The audio was checked for decoding/timing/levels/clipping; model audio-input is
unavailable, so do not falsely claim subjective listening or species recognition.

Do not apply the old intro's cross-boundary continuity metric to the manga's
intentional editorial cuts, and do not change the old intro thresholds. Retain
new real-media subtitle/audio/pause/skip/handoff and interrupted-save checks,
existing full playthroughs and native checks. Final source/merge tree, CI and
APK signature/hash evidence belongs in draft PR11. Do not merge automatically.
