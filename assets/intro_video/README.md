# Opening movie

The four reviewed Full HD MP4 masters are at the repository root. Their hashes,
chronological order, FPS and exact frame counts live in
`assets/intro_video_manifest.json`.

Run `python3 tools/prepare_intro_videos.py` before importing/exporting the game.
It generates silent 1280x720 Theora videos here for Godot and validates every
output. `--check` validates an existing build. Generated OGVs/compiled.json are
not source assets to commit. The Android workflow performs this step itself.

Version 3 uses one room and fixed character layers from `art/intro`, animated
by `tools/animate_intro.py`. All sections use 30 fps. Adjacent sections share
their boundary poses; both reading loops have equal endpoints. The build now
checks decoded frame deltas, scene boundaries and loop seams. The likeness
photograph is private. See HANDOFF_2026-10-16_CAROLINA.md for current details.
