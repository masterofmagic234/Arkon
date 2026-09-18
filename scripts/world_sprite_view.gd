extends RefCounted

# Presentation-only helpers for world sprites.
# Gameplay state remains owned by game.gd.

const SquirrelTypes = preload("res://scripts/squirrel_types.gd")

# These are the authoritative NORMAL Adobe-cutout assets used while a squirrel
# is active. Keep these separate from the stunned set so the normal presentation
# can never accidentally fall back to the generic template texture.
const NORMAL_TEXTURES := {
    SquirrelTypes.Kind.SCOUT: preload("res://assets/squirrel_scout.png"),
    SquirrelTypes.Kind.THROWER: preload("res://assets/squirrel_thrower.png"),
    SquirrelTypes.Kind.TANK: preload("res://assets/squirrel_tank.png"),
    SquirrelTypes.Kind.THIEF: preload("res://assets/squirrel_thief.png"),
    SquirrelTypes.Kind.RUNNER: preload("res://assets/squirrel_runner.png"),
}

# These are the authoritative STUNNED Adobe-cutout assets.
const STUNNED_TEXTURES := {
    SquirrelTypes.Kind.SCOUT: preload("res://assets/squirrel_scout_stunned.png"),
    SquirrelTypes.Kind.THROWER: preload("res://assets/squirrel_thrower_stunned.png"),
    SquirrelTypes.Kind.TANK: preload("res://assets/squirrel_tank_stunned.png"),
    SquirrelTypes.Kind.THIEF: preload("res://assets/squirrel_thief_stunned.png"),
    SquirrelTypes.Kind.RUNNER: preload("res://assets/squirrel_runner_stunned.png"),
}

func hide_pickup(node: MeshInstance3D) -> void:
    if node != null:
        node.visible = false

func apply_squirrel_type(node: MeshInstance3D, kind: int) -> void:
    if node == null or not node.mesh is QuadMesh:
        return
    var texture: Texture2D = NORMAL_TEXTURES.get(kind, NORMAL_TEXTURES[SquirrelTypes.Kind.SCOUT])
    _apply_texture(node, texture)
    # Restore the active presentation in case this node previously used the
    # stunned presentation.
    node.rotation.z = 0.0
    node.scale = Vector3.ONE

func apply_squirrel_stunned(node: MeshInstance3D, kind: int = SquirrelTypes.Kind.SCOUT) -> void:
    if node == null:
        return
    var texture: Texture2D = STUNNED_TEXTURES.get(kind, STUNNED_TEXTURES[SquirrelTypes.Kind.SCOUT])
    if node.mesh is QuadMesh:
        _apply_texture(node, texture)
    node.rotation.z = deg_to_rad(-7.0)
    node.scale = Vector3(1.0, 0.78, 1.0)

func _apply_texture(node: MeshInstance3D, texture: Texture2D) -> void:
    if texture == null or not node.mesh is QuadMesh:
        return
    var quad := node.mesh as QuadMesh
    var base_mat := quad.material as StandardMaterial3D
    if base_mat == null:
        return
    var unique_mat := base_mat.duplicate() as StandardMaterial3D
    # All squirrel assets are cutouts. Explicit alpha/culling settings keep the
    # Adobe transparency intact on every archetype, including spawned nodes.
    unique_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    unique_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    unique_mat.albedo_texture = texture
    node.set_surface_override_material(0, unique_mat)

func animate_squirrel(node: MeshInstance3D, phase: float) -> void:
    if node != null:
        node.rotation.z = sin(Time.get_ticks_msec() * 0.003 + phase) * 0.03
