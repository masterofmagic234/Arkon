# ACORN HUNTER — V20

Based directly on V19.

Changes:
- canonical 20x14 map scaled to 1.8 world units per cell for a larger playable space;
- procedural night sky via Godot Environment + Sky + ProceduralSkyMaterial;
- world sprites use QuadMesh materials with billboard mode instead of manual look_at rotation;
- squirrel combat is canon: 2 HP each; first hit wounds, second hit defeats the enemy and swaps to squirrel_stunned.png;
- stunned squirrels stop moving and remain visible as the friendly non-gory defeated state;
- minimap updated for scaled map.
