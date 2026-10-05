extends Node3D
class_name Level1GrassGenerator

const LevelData = preload("res://scripts/level_data.gd")
const GRASS_HEIGHT := 0.52
const GRASS_HALF_WIDTH := 0.23

@export_category("Grass Settings")
@export var grass_mesh: Mesh
@export var grass_texture: Texture2D = preload("res://assets/grass_tuft_carolina.svg")
@export_range(2, 12, 1) var density_per_cell: int = 8
@export var position_jitter: float = 0.82
@export var scale_range: Vector2 = Vector2(0.80, 1.18)
@export_range(4, 28, 1) var chunk_cells_x: int = 14
@export_range(4, 15, 1) var chunk_cells_z: int = 8
@export var alpha_scissor_threshold: float = 0.46
@export var wind_strength: float = 0.008
@export var wind_speed: float = 1.25
@export var visibility_end: float = 24.0
@export var random_seed: int = 1747

var _field_count := 0
var _instance_count := 0

func _ready() -> void:
    call_deferred("_generate")

func get_field_count() -> int:
    return _field_count

func get_instance_count() -> int:
    return _instance_count

func _generate() -> void:
    if get_node_or_null("GrassFields") != null:
        return

    if grass_texture == null:
        push_warning("[Grass] Missing grass texture; skipping 3D grass.")
        return

    var scene_root := get_parent().get_parent() as Node3D
    var layout := scene_root.get_node_or_null("Level1Layout") as Node3D
    if layout == null:
        push_warning("[Grass] Level1Layout not found; skipping 3D grass.")
        return

    var source_mesh := grass_mesh if grass_mesh != null else _build_cross_mesh()
    if source_mesh == null:
        push_warning("[Grass] Could not build grass mesh.")
        return

    var shader := load("res://shaders/level1_grass.gdshader") as Shader
    if shader == null:
        push_warning("[Grass] Missing grass shader; skipping 3D grass.")
        return

    var material := ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("albedo_tex", grass_texture)
    material.set_shader_parameter("alpha_scissor_threshold", alpha_scissor_threshold)
    material.set_shader_parameter("grass_height", GRASS_HEIGHT)
    material.set_shader_parameter("wind_strength", wind_strength)
    material.set_shader_parameter("wind_speed", wind_speed)
    material.set_shader_parameter("wind_scale", 0.19)

    var fields_root := Node3D.new()
    fields_root.name = "GrassFields"
    add_child(fields_root)

    var map := LevelData.CANONICAL_MAP
    var chunks_x := int(ceil(float(LevelData.MAP_WIDTH) / float(chunk_cells_x)))
    var chunks_z := int(ceil(float(LevelData.MAP_HEIGHT) / float(chunk_cells_z)))
    var rng := RandomNumberGenerator.new()
    rng.seed = random_seed

    for chunk_z in range(chunks_z):
        for chunk_x in range(chunks_x):
            var transforms: Array[Transform3D] = []

            var x0 := chunk_x * chunk_cells_x
            var x1 := mini((chunk_x + 1) * chunk_cells_x, LevelData.MAP_WIDTH)
            var z0 := chunk_z * chunk_cells_z
            var z1 := mini((chunk_z + 1) * chunk_cells_z, LevelData.MAP_HEIGHT)

            for z in range(z0, z1):
                var row: String = map[z]
                for x in range(x0, x1):
                    if x >= row.length() or row[x] != ".":
                        continue

                    var cell_center_x := LevelData.MAP_WORLD_ORIGIN.x + (float(x) + 0.5) * LevelData.CELL_SIZE
                    var cell_center_z := LevelData.MAP_WORLD_ORIGIN.y + (float(z) + 0.5) * LevelData.CELL_SIZE

                    for i in range(density_per_cell):
                        var offset_x := rng.randf_range(-position_jitter, position_jitter)
                        var offset_z := rng.randf_range(-position_jitter, position_jitter)
                        var position := Vector3(
                            cell_center_x + offset_x,
                            0.025,
                            cell_center_z + offset_z
                        )
                        var rotation_y := rng.randf_range(0.0, TAU)
                        var uniform_scale := rng.randf_range(scale_range.x, scale_range.y)
                        transforms.append(
                            Transform3D(
                                Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * uniform_scale),
                                position
                            )
                        )

            if transforms.is_empty():
                continue

            var multi_mesh := MultiMesh.new()
            multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
            multi_mesh.mesh = source_mesh
            multi_mesh.instance_count = transforms.size()

            for i in transforms.size():
                multi_mesh.set_instance_transform(i, transforms[i])

            var instance := MultiMeshInstance3D.new()
            instance.name = "Grass_%02d_%02d" % [chunk_x, chunk_z]
            instance.multimesh = multi_mesh
            instance.material_override = material
            instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            instance.visibility_range_end = visibility_end
            instance.visibility_range_end_margin = 3.0
            instance.extra_cull_margin = 0.25

            var chunk_world_left := LevelData.MAP_WORLD_ORIGIN.x + float(x0) * LevelData.CELL_SIZE
            var chunk_world_top := LevelData.MAP_WORLD_ORIGIN.y + float(z0) * LevelData.CELL_SIZE
            var chunk_world_width := float(x1 - x0) * LevelData.CELL_SIZE
            var chunk_world_depth := float(z1 - z0) * LevelData.CELL_SIZE
            multi_mesh.custom_aabb = AABB(
                Vector3(chunk_world_left - 0.6, -0.05, chunk_world_top - 0.6),
                Vector3(chunk_world_width + 1.2, GRASS_HEIGHT + 0.12, chunk_world_depth + 1.2)
            )

            fields_root.add_child(instance)
            _field_count += 1
            _instance_count += transforms.size()

    print(
        "[Grass] 3D grass generated: %d fields, %d clumps, density=%d, height=%.2fm, chunk=%dx%d"
        % [_field_count, _instance_count, density_per_cell, GRASS_HEIGHT, chunk_cells_x, chunk_cells_z]
    )

func _build_cross_mesh() -> ArrayMesh:
    var vertices := PackedVector3Array([
        Vector3(-GRASS_HALF_WIDTH, 0.0, 0.0),
        Vector3(GRASS_HALF_WIDTH, 0.0, 0.0),
        Vector3(GRASS_HALF_WIDTH * 0.82, GRASS_HEIGHT, 0.0),
        Vector3(-GRASS_HALF_WIDTH * 0.82, GRASS_HEIGHT, 0.0),

        Vector3(0.0, 0.0, -GRASS_HALF_WIDTH),
        Vector3(0.0, 0.0, GRASS_HALF_WIDTH),
        Vector3(0.0, GRASS_HEIGHT, GRASS_HALF_WIDTH * 0.82),
        Vector3(0.0, GRASS_HEIGHT, -GRASS_HALF_WIDTH * 0.82),
    ])

    var uvs := PackedVector2Array([
        Vector2(0.0, 1.0),
        Vector2(1.0, 1.0),
        Vector2(1.0, 0.0),
        Vector2(0.0, 0.0),

        Vector2(0.0, 1.0),
        Vector2(1.0, 1.0),
        Vector2(1.0, 0.0),
        Vector2(0.0, 0.0),
    ])

    var indices := PackedInt32Array([
        0, 1, 2, 0, 2, 3,
        1, 0, 3, 1, 3, 2,
        4, 5, 6, 4, 6, 7,
        5, 4, 7, 5, 7, 6,
    ])

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh
