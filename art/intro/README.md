# Illustrated intro authoring — Android 1.44

The current intro uses five new ImageGen storyboard drawings and four selected
Runway image-to-video takes in `runway144/`. The adult woman on the left follows
the owner's three private likeness photographs; the bedroom, child, cat, pink
pajamas and lighting follow the five supplied story references. The third
reference's waking pose is normalized to the common room/camera framing.
Private photographs and signed service URLs are not stored here.

`runway144/authoring.json` records generation inputs, task IDs, prompts, hashes,
visual review and rejected trial IDs. Only accepted generated drawings/video
are retained. The opening starts asleep with an empty doorway, then the child
peeks and the adult wakes; the first dialogue waits in the reclining pose.
The silent transition seats the adult and brings the child/plush to the bed;
the remaining dialogue waits in the seated pose.

## Rebuild reviewed masters

From the repository root, use Python3 and FFmpeg with libx264/libtheora:

```sh
python3 tools/prepare_runway_intro.py \
  --a art/intro/runway144/keyframes/01-sleep.png \
  --b art/intro/runway144/keyframes/04-awake.png \
  --c art/intro/runway144/keyframes/05-seated.png \
  --video0 art/intro/runway144/raw/shot0.mp4 \
  --video1 art/intro/runway144/raw/shot1.mp4 \
  --video2 art/intro/runway144/raw/shot2.mp4 \
  --video3 art/intro/runway144/raw/shot3.mp4 \
  --time-map2 '0.0:0.0,0.3333333333333333:0.266666667,0.6666666666666666:0.439253091,1.0:0.814787625,1.3333333333333333:1.17078679,1.6666666666666667:1.554790384,2.0:1.79,2.3333333333333335:2.2,2.6666666666666665:2.47,3.0:2.7,3.3333333333333335:2.97,3.6666666666666665:3.15,4.0:3.38,4.333333333333333:3.625016833,4.666666666666667:3.733333333,end:end' \
  --output-dir /tmp/intro-144-masters
```

The explicit timing map slows the adult rise and uses the quieter settling
interval for the recovered time, without omitting actions or changing total
duration. First/last endpoint timing is unchanged. Full assembly parameters
are recorded beside the source provenance. The tool
stages candidates; it refuses to replace the canonical root masters. It fits
aspect without stretching, retimes the filmed motion, interpolates temporal
samples as needed and anchors shared endpoint poses with short blends. Reading
loops use naturally cyclic takes. Inspect face, eyes, hands, hair/duvet overlap,
child steps and endpoint blends at full size before promoting any candidate.
The two intermediate keyframes are retained storyboard poses, not extra image
inputs to the accepted opening generation.

After approval, promote all four MP4s under their existing root filenames and
update `assets/intro_video_manifest.json` hashes together. Then run:

```sh
python3 tools/prepare_intro_videos.py
godot --headless --path . --audio-driver Dummy --fixed-fps 60 \
  --script tools/intro_cinematic_test.gd
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --fixed-fps 60 --script tools/intro_cinematic_test.gd -- \
  --visual --output=/tmp/intro-native-review
```

The source/runtime contract remains 121/125/121/121 frames at30fps,1280x720,
with silent media and17 unchanged interactive Russian lines. Slots1/3 loop
while the reader waits; slots0/2 advance automatically. Skip, letterboxing,
decoder handoff and the Level1 transition remain in the unchanged runtime
script. The authoring directory is excluded from Godot import and APK export;
only reviewed q9 Theora outputs are packaged. CI regenerates those videos from
the pinned MP4 hashes.

Offline checks keep boundary/reading seams below0.8 gray levels, adjacent-frame
deltas below2.5, complete timelines and at least90% actual decoded Theora
pictures. Native checks also inspect real rendered RGB motion and interface
behavior. These numerical checks supplement visual review; they cannot prove
identity or anatomy.

## Historical sources

The top-level `room.png`, character/blink cutouts, `animation-report.json` and
`tools/animate_intro.py` describe the previous artwork3 joint-animation
pipeline. They are retained as historical authoring assets and do not rebuild
the artwork4 movies. Use the current source mapping above.
