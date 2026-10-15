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
