extends RefCounted

# Presentation-only helpers for world sprites.
# Gameplay state remains owned by game.gd.

const SquirrelTypes = preload("res://scripts/squirrel_types.gd")

const NORMAL_TEXTURES := {
    SquirrelTypes.Kind.SCOUT: "res://assets/squirrel_scout.png",
    SquirrelTypes.Kind.THROWER: "res://assets/squirrel_thrower.png",
    SquirrelTypes.Kind.TANK: "res://assets/squirrel_tank.png",
    SquirrelTypes.Kind.THIEF: "res://assets/squirrel_thief.png",
    SquirrelTypes.Kind.RUNNER: "res://assets/squirrel_runner.png",
}

const STUNNED_TEXTURES := {
    SquirrelTypes.Kind.SCOUT: "res://assets/squirrel_scout_stunned.png",
    SquirrelTypes.Kind.THROWER: "res://assets/squirrel_thrower_stunned.png",
    SquirrelTypes.Kind.TANK: "res://assets/squirrel_tank_stunned.png",
    SquirrelTypes.Kind.THIEF: "res://assets/squirrel_thief_stunned.png",
    SquirrelTypes.Kind.RUNNER: "res://assets/squirrel_runner_stunned.png",
}

func hide_pickup(node: MeshInstance3D) -> void:
    if node != null:
        node.visible = false

func apply_squirrel_type(node: MeshInstance3D, kind: int) -> void:
    if node == null or not node.mesh is QuadMesh:
        return
    var texture_path: String = str(NORMAL_TEXTURES.get(kind, NORMAL_TEXTURES[SquirrelTypes.Kind.SCOUT]))
    _apply_texture(node, texture_path)

func apply_squirrel_stunned(node: MeshInstance3D, kind: int = SquirrelTypes.Kind.SCOUT) -> void:
    if node == null:
        return
    var texture_path: String = str(STUNNED_TEXTURES.get(kind, STUNNED_TEXTURES[SquirrelTypes.Kind.SCOUT]))
    if node.mesh is QuadMesh:
        _apply_texture(node, texture_path)
    node.rotation.z = deg_to_rad(-7.0)
    node.scale = Vector3(1.0, 0.78, 1.0)

func _apply_texture(node: MeshInstance3D, texture_path: String) -> void:
    var texture := load(texture_path)
    if texture == null:
        return
    var quad := node.mesh as QuadMesh
    var base_mat := quad.material as StandardMaterial3D
    if base_mat == null:
        return
    var unique_mat := base_mat.duplicate() as StandardMaterial3D
    unique_mat.albedo_texture = texture
    node.set_surface_override_material(0, unique_mat)

func animate_squirrel(node: MeshInstance3D, phase: float) -> void:
    if node != null:
        node.rotation.z = sin(Time.get_ticks_msec() * 0.003 + phase) * 0.03
