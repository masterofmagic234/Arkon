# ORЕХ-1 pursuit assets

The aircraft is original code-authored geometry in
`scripts/race_squirrel_helicopter.gd`: shared primitive meshes, an original
tapered tail mesh and flat intake fins. The acorn emblems are geometry; no
external model, logo, texture or game asset is used. The helicopter/spike
mechanic was requested as an homage to NFS Hot Pursuit, not an asset port.

`rotor.wav`, `radio.wav` and `impact.wav` are original deterministic 22,050 Hz,
16-bit mono PCM synthesized offline by `tools/generate_pursuit_audio.py`.
The generator uses integer-cycle harmonics, deterministic noise and envelopes.
Total source duration is 3.25 seconds / 143,458 bytes including WAV headers.
No recordings, external samples or runtime synthesis are used.

`chatter.ogg` adds original nonverbal squirrel radio voices: nine 3.2-second
slots (three patrol, three dispatcher, three pilot takes), 22,050 Hz mono
Vorbis. `tools/generate_squirrel_radio.py` synthesizes voiced harmonics,
vowel-like resonances, chitter/clicks, breath and radio squelch offline using
deterministic seeds, then encodes with ffmpeg. No speech recording, external
sample, voice clone or runtime synthesis is involved. The subtitle dialogue
and callsigns are original Russian writing in `scripts/race_radio.gd`.
The director owns the single channel and exact clip offsets; tactical events
interrupt idle banter, stale requests expire and replies require a spoken
request. SFX mute/volume and scene pause apply to the radio; subtitles also
remain available when the player mutes sound.
