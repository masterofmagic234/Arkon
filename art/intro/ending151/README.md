# Ending, version 1.51

The ending reuses the opening's canonical room, not a separately generated room.
`assets/cinematics/ending151/room.png` is the exact byte copy of
`art/intro/runway144/keyframes/01-sleep.png` (SHA-256
`6baa5984fb110c6bfab3a992d8157d129c3b52a01a7ed5721cb2149e6a25344f`).
The engine applies a lights-off grade and darkens the original visible lamps and
monitors. Furniture, window, door, cat, portraits and decor retain their original
positions. The camera pushes toward that same window at runtime.

New full-resolution waking and phone poses were made with ImageGen from the
same plate/reference. Only the explicit bed/person polygon in
`scripts/ending_cutscene.gd` is drawn from those pictures. A separate small
blanket patch removes the phone when it is in her hands. The acorn craft on the
desk and squirrel outside the glass are transparent props. Original indoor
leaves are drawn in front of the squirrel, from the canonical room texture.
The generated source assets and provenance hashes are recorded in
`assets/cinematics/ending151/provenance.json`; no AI-rendered lettering is used.

The exact exchange with Данил and narration/subtitles are engine text. Three
Runway audio tasks are already complete; `audio/` retains their MP3 sources and
the runtime directory has mono Vorbis versions with measured durations and
hashes. Rebuilding or rerunning tests never submits new paid generation tasks.

Opening video source bytes and filmed motion remain unchanged. A bounded
adult-garment shader changes the pink cloth to charcoal/plum with a subtle moon
pattern. Twelve tracked garment-outline vertices and a separate four-point lit-cuff
band follow the selected poses. A tracked face ellipse and bare-arm capsule
protect exposed skin. Independent face, arm, wall/pillow and child probes remain
unchanged in all twelve accepted native frame pairs. The native
`intro_pajamas151_test.gd` compares each recoloured frame to the identical paused
decoded original frame, across all four takes, and captures them for review.

Validation:

- `tools/ending_cinematic151_test.gd`: canonical room identity, full scene stages,
  exact messages, real pause/mute controls, sound resources, mobile fitting,
  skip to credits and exactly one menu transition. `--visual` produces review
  frames of every story beat; these acceptance frames are explicitly staged.
- `tools/intro_pajamas151_test.gd`: four approved MP4 source hashes, then native
  decoding and same-frame garment comparisons when `--visual` is supplied.
- `tools/intro_cinematic_test.gd`: existing interactive four-clip continuity,
  reading loops, 17 dialogue lines, skip and actual garden handoff.

Accepted local review: `ending-final` has thirteen native frames, zero changed
room samples outside the authorized person/removed-phone patches, and measured
local typing motion. `pajamas-cuff-final` has twelve raw/changed native pairs;
body and warm-cuff pink probes reach zero while face, bare arm, child and
protected room samples retain their original pixels. These are local checks;
the release CI captures and signed APK remain separate delivery gates.
