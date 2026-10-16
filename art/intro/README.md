# Continuous illustrated intro sources

Five fixed ImageGen drawings supply one room, Carolina, Darina with her plush
toy, and two localized blink references. The likeness photograph is private
and is not included. `tools/animate_intro.py` registers only the blink regions
and animates smooth body joints, alternating planted feet/contact shadows,
duvet occlusion and one continuous camera. No per-frame image generation or
changing head drawings are used.

```sh
python3 tools/animate_intro.py --assets art/intro --output /tmp/intro-masters
```

Requires Python, numpy, opencv-python-headless and FFmpeg. `--preview` generates
diagnostic stills. Review the motion before replacing root MP4s and updating
their pinned hashes. All sections use 30 fps: 121, 125, 121 and 121 frames.
Adjacent sections share boundary poses; both reading loops have equal endpoints.
This authoring directory is excluded from Godot import and APK export.
