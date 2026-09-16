class_name WallSystem
extends RefCounted

const LevelData = preload("res://scripts/level_data.gd")

# Full wall textures. The source art is authored as complete 2048x2048 SVGs,
# then rasterized to PNG during CI so Android never has to import the SVGs.
# No atlas, no eight-panel strip, and no shader-based sampling.
const WallTextures := [
    preload("res://assets/wall_mossy_stone_full.png"),
    preload("res://assets/wall_overgrown_full.png"),
    preload("res://assets/wall_brick_stone_full.png"),
    preload("res://assets/wall_wood_fence_full.png"),
    preload("res://assets/wall_ruined_temple_full.png"),
    preload("res://assets/wall_autumn_full.png")
]

static func rebuild(root: Node3D) -> void:
    for node in root.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := node as MeshInstance3D
        if mesh_instance == null:
            continue
        if mesh_instance.name.begins_with("IllustratedWall"):
            mesh_instance.visible = false
        elif mesh_instance.name == "Mesh" and mesh_instance.get_parent() != null and mesh_instance.get_parent().name.begins_with("MapWall"):
            mesh_instance.visible = false

    for node in root.find_children("*", "StaticBody3D", true, false):
        var legacy_wall := node as StaticBody3D
        if legacy_wall == null or not legacy_wall.name.begins_with("MapWall"):
            continue
        legacy_wall.collision_layer = 0
        legacy_wall.collision_mask = 0

    var old_root := root.get_node_or_null("CanonicalWalls")
    if old_root != null:
        old_root.free()

    var walls_root := Node3D.new()
    walls_root.name = "CanonicalWalls"
    root.add_child(walls_root)

    var wall_cells: Dictionary = {}
    for row in range(LevelData.MAP_HEIGHT):
        var row_data: String = LevelData.CANONICAL_MAP[row]
        for column in range(LevelData.MAP_WIDTH):
            if row_data[column] == "1":
                wall_cells[Vector2i(column, row)] = true

    var wall_count := 0
    var face_count := 0

    for row in range(LevelData.MAP_HEIGHT):
        for column in range(LevelData.MAP_WIDTH):
            var cell := Vector2i(column, row)
            if not wall_cells.has(cell):
                continue

            var wall := StaticBody3D.new()
            wall.name = "Wall_%02d_%02d" % [row, column]
            wall.position = Vector3(-17.1 + float(column) * LevelData.CELL_SIZE, 1.3, -11.7 + float(row) * LevelData.CELL_SIZE)
            wall.collision_layer = LevelData.WORLD_LAYER
            wall.collision_mask = 0
            walls_root.add_child(wall)

            var collision := CollisionShape3D.new()
            collision.name = "Collision"
            var shape := BoxShape3D.new()
            shape.size = Vector3(LevelData.CELL_SIZE, 2.6, LevelData.CELL_SIZE)
            collision.shape = shape
            wall.add_child(collision)

            if not wall_cells.has(Vector2i(column + 1, row)):
                _add_face(wall, column, row, Vector3(0.905, 0.0, 0.0), Vector3(0.0, -PI * 0.5, 0.0))
                face_count += 1
            if not wall_cells.has(Vector2i(column - 1, row)):
                _add_face(wall, column, row, Vector3(-0.905, 0.0, 0.0), Vector3(0.0, PI * 0.5, 0.0))
                face_count += 1
            if not wall_cells.has(Vector2i(column, row + 1)):
                _add_face(wall, column, row, Vector3(0.0, 0.0, 0.905), Vector3.ZERO)
                face_count += 1
            if not wall_cells.has(Vector2i(column, row - 1)):
                _add_face(wall, column, row, Vector3(0.0, 0.0, -0.905), Vector3(0.0, PI, 0.0))
                face_count += 1

            wall_count += 1

    print("ACORN HUNTER: native PNG full-texture wall rebuild; solid_cells=", wall_count, "; rendered_vertical_faces=", face_count)

static func _add_face(parent: StaticBody3D, column: int, row: int, offset: Vector3, rotation: Vector3) -> void:
    var face := MeshInstance3D.new()
    face.name = "Face"

    var quad := QuadMesh.new()
    quad.size = Vector2(LevelData.CELL_SIZE, 2.6)
    face.mesh = quad
    face.position = offset
    face.rotation = rotation

    var style_index := _wall_location_style(column, row)
    var material := StandardMaterial3D.new()
    material.albedo_texture = WallTextures[style_index]
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    material.roughness = 1.0
    material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    face.material_override = material
    parent.add_child(face)

static func _wall_location_style(column: int, row: int) -> int:
    var zone_column := 0 if column <= 6 else (1 if column <= 12 else 2)
    var zone_row := 0 if row <= 6 else 1
    return zone_row * 3 + zone_column
