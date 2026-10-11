extends Node3D
class_name Level1Navigation

const LevelData = preload("res://scripts/level_data.gd")
var region: NavigationRegion3D

func setup() -> void:
    if region == null:
        region = NavigationRegion3D.new()
        region.name = "Level1NavigationRegion"
        add_child(region)
        SignalBus.object_interacted.connect(_on_gate_changed)
    rebuild()

func _on_gate_changed(_id: StringName, state: StringName) -> void:
    if state == &"opened":
        call_deferred("rebuild")

func rebuild() -> void:
    var mesh := NavigationMesh.new()
    var vertices := PackedVector3Array()
    var corners: Dictionary = {}
    var closed: Array[Vector2i] = []
    for gate in get_tree().get_nodes_in_group("level1_door"):
        if not gate.is_open:
            closed.append(LevelData.world_to_cell(gate.global_position.x, gate.global_position.z))
    for y in range(LevelData.MAP_HEIGHT):
        for x in range(LevelData.MAP_WIDTH):
            var cell := Vector2i(x, y)
            if LevelData.CANONICAL_MAP[y][x] == "#" or closed.has(cell):
                continue
            var polygon := PackedInt32Array()
            for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
                var corner: Vector2i = cell + offset
                if not corners.has(corner):
                    corners[corner] = vertices.size()
                    vertices.append(Vector3(
                        LevelData.MAP_WORLD_ORIGIN.x + (float(corner.x) - 0.5) * LevelData.CELL_SIZE,
                        0.0,
                        LevelData.MAP_WORLD_ORIGIN.y + (float(corner.y) - 0.5) * LevelData.CELL_SIZE))
                polygon.append(corners[corner])
            mesh.add_polygon(polygon)
    mesh.vertices = vertices
    region.navigation_mesh = mesh
