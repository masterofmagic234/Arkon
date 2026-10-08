# Blender game assets

This directory is the asset workshop for Arkon.

## Structure

- `blender/assets/*.py` — one Blender Python generator per game asset.
- `.github/workflows/build-camry-traffic.yml` — builds every asset generator in CI with Blender 4.5.14 and publishes the resulting `.blend` files as a GitHub Actions artifact.

## Adding a new model

1. Add a new generator under `blender/assets/`, for example `taxi_traffic.py`.
2. Keep it self-contained and use Blender's Python API.
3. Save the resulting file to `BLENDER_ASSET_OUTPUT` when that variable is present:
   ```python
   import os
   output = os.environ.get("BLENDER_ASSET_OUTPUT", os.path.join(os.getcwd(), "asset.blend"))
   bpy.ops.wm.save_as_mainfile(filepath=output)
   ```
4. Push the branch. CI will build all generators and publish `blender-game-assets`.
5. Inspect the generated `.blend` locally before integrating the asset into Godot.

The current `camry_traffic.py` is the first reusable asset generator and is intended for incoming traffic in Level 2. It is Toyota Camry XV70-inspired rather than an exact factory scan.
