# Opening movie

The four reviewed Full HD MP4 masters are at the repository root. Their hashes,
chronological order, FPS and exact frame counts live in
`assets/intro_video_manifest.json`.

Run `python3 tools/prepare_intro_videos.py` before importing/exporting the game.
It generates silent 1280x720 Theora videos here for Godot and validates every
output. `--check` validates an existing build. Generated OGVs/compiled.json are
not source assets to commit. The Android workflow performs this step itself.

Carolina's new face/hair uses 24 ImageGen-authored pose keys and the original
video motion. The original reference photograph is not published. The optional
`tools/redraw_intro.py` authoring script takes the separately delivered source
archive and original videos from commit cbbb2c055385ff238da2e4030f8d0bae55879f7d.
See HANDOFF_2026-10-16_CAROLINA.md for provenance and runtime details.
