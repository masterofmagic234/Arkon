# Park departure manga · 1.45

A separate 26-second black-and-white film after boarding the 240 in the garden,
before the playable pursuit. Six squirrel utterances use nonverbal squeaks and
chattering with Russian captions rendered by the game. Four shots cover the car
leaving, two scouts reporting, a distinct commander ordering pursuit and the
OREKH-1 helicopter taking off. The commander is not the garden guardian.

The actual car, helicopter and squirrel model references are recorded in
`reference-provenance.json`; rendered vehicle references are in `references/`.
Carolina uses the existing 1.44 illustrated likeness. Private source portraits
and temporary service URLs are deliberately absent. This entire authoring tree
is excluded from engine import and Android export by the existing parent rules.

`authoring.json` pins the reviewed silent H.264 master by SHA256. `raw/` contains
the four original silent video takes; `keyframes/` their reviewed starting art.
Source review and numerical assembly evidence are retained alongside them.

To assemble a new review candidate, without overwriting the approved master:

```sh
python3 tools/prepare_park_escape_video.py --assemble \
  --raw-dir art/intro/park_escape145/raw \
  --output-dir /tmp/park-escape-manga --nearest-shots scouts
```

Scouts preserve crisp original pictures at their retimed manga cadence; blending
that quick gesture had doubled ink outlines around eyes. Other shots retain
temporal blending. The container remains 30 fps, 1280×720, exactly 780 frames.
Cuts at 6, 11.5 and 20 seconds are intentional. Neutral U/V=128 removes warm tint.
A candidate needs visual review before manual master/hash promotion.

CI and local builds convert only the pinned approved master:

```sh
python3 tools/prepare_park_escape_video.py
python3 tools/prepare_park_escape_video.py --check
```

The output is a silent q9 Theora OGV plus generated `compiled.json`; both are
ignored in Git and reproduced during CI. Theora repeat packets for held manga
pictures are legal; validation reconstructs the full 780-frame playback timeline.
The existing bedroom intro, converter and continuity thresholds remain intact.

`audio/` contains six generated creature recordings, safe provenance and
objective timing/level reports. The final accepted mix is the tracked
`assets/cinematics/park_escape/audio.ogg` (26 seconds, stereo, 48 kHz). Reproduce
it into a staging directory with:

```sh
python3 tools/prepare_park_escape_audio.py --output-dir /tmp/park-escape-audio
```

Engine and rotor effects reuse existing game sources. Dialogue is not spoken
Russian. Objective decoding, sync, loudness and clipping checks do not constitute
subjective listening; an actual playable preview is supplied for audition.

The production timeline and six caption cues live in
`assets/cinematics/park_escape/timeline.json`. The runtime uses decoded video
time for captions and separate SFX synchronization, supports pause/skip/sound,
and retains the rewarded garden checkpoint until Level 2 has actually loaded.
