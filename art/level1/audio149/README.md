Arkon v1.49 squirrel voice authoring

Six new Runway sound-effect takes,8seconds each,48credits in total. Task IDs,
prompts, original MP3 hashes and costs are pinned in generation.json. Generated
calls are animal vocalizations, not spoken dialogue; mission subtitles convey
their intended meaning separately in Russian.

Run `python3 tools/prepare_woodland_voices149.py` from the repository root to
rebuild30 mono44.1kHz/16bit PCM clips. Dependencies: FFmpeg, NumPy, SciPy.
Runtime uses only the prepared WAVs, never these MP3s. All35 v1.47 prepared WAVs
remain byte-for-byte unchanged. Defeat calls include a very quiet terminal fall
layer from that preserved body/leaf foley.

The squirrel has sharp chirrs, short squeaks and quick chatter. The guardian
uses separately generated lower kuk calls and distress, with recorded chitter
layers for the commanding attack/rally variants. No pitched mechanical cue is
presented as an animal voice. Each of10 actor/event families contains3 different
prepared excerpts. The runtime varies pitch by less than1%, uses shuffle bags,
limits concurrent vocal emitters to3, and allows at most5 vocal starts in1.4s.
One start is reserved for a phase leader, so a group detection chorus cannot
consume the mission cue. A full protected weapon pool can defer one phase call
for at most1.5seconds; it never grows a queue or steals a priority-three cue.

Audition order in audition_reel.wav matches PROVENANCE.json asset order: ordinary
warn, attack, hit, defeat, rally; guardian warn, hit, defeat; then alternating
guardian attack/rally takes. A300ms gap separates every take. The file is a
review artifact and is excluded from the game export through the art directory.

Listening limitation: audio tool content was requested for the source takes,
but this agent runtime reported that it does not support audio input. Subjective
sound quality or absence of unwanted vocal resemblance is therefore not claimed.
Waveforms/spectrograms were inspected, and independent FFmpeg tests verify PCM,
headroom, distinct payloads, onset silence, quiet terminal decays and source pins.
The audition reel is provided for a listening-capable reviewer.

New events through SignalBus.emit_audio_event(kind, world_position):

* squirrel_warn, squirrel_attack, squirrel_hit, squirrel_defeat, squirrel_rally
* guardian_warn, guardian_attack, guardian_hit, guardian_defeat, guardian_rally
* squirrel_chatter (quiet,8s per6m cell; shares the rally anti-repeat bag)
* encounter_entry, encounter_pump, encounter_gallery, encounter_escape (aliases)

Mission code owns the matching subtitle. Vocal events remain positional, obey
the existing pause/mute/SFX-volume controls, share the bounded positional pool,
and retain the scene-local limiter. They cannot steal a higher-priority weapon
or player-damage cue. Occasional search chatter is quieter and carries less
priority than combat reactions. The weapon throw foley remains enemy_shoot.

Only the four encounter aliases use a projected call mix:120m cutoff,16m
reference distance and3dB additional gain. This covers the real escape leader
at(-40,3,11) from the reward position(0,7,-36), around62m away. Regular calls
reset to their own shorter-range mix whenever a pooled emitter is reused.

`tools/woodland_voices149_native.gd` records a staged native mixer audit through
Godot MovieMaker. Its paired independent checker,
`tools/check_woodland_voices149_recording.py`, inspects actual stereo PCM for
vocal panning, protected weapon overload, phase slot/queue recovery, the actual
escape distance, pause and mute. The escape calibration lowers the bed for one
call and compares it to the real preceding ambience, then restores the ambience
for a second controlled comparison. This is an audio test, not a gameplay replay.
