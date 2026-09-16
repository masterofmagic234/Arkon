extends RefCounted

# Presentation-only helpers for world sprites.
# Gameplay state remains owned by game.gd.

func hide_pickup(node: MeshInstance3D) -> void:
    if node != null:
        node.visible = false

func apply_squirrel_stunned(node: MeshInstance3D) -> void:
    if node == null:
        return
    var stunned_texture := load("res://assets/squirrel_stunned.png")
    if stunned_texture != null and node.mesh is QuadMesh:
        var base_mat := (node.mesh as QuadMesh).material as StandardMaterial3D
        if base_mat != null:
            var unique_mat := base_mat.duplicate() as StandardMaterial3D
            unique_mat.albedo_texture = stunned_texture
            node.set_surface_override_material(0, unique_mat)
    node.rotation.z = deg_to_rad(-7.0)
    node.scale = Vector3(1.0, 0.78, 1.0)

func animate_squirrel(node: MeshInstance3D, phase: float) -> void:
    if node != null:
        node.rotation.z = sin(Time.get_ticks_msec() * 0.003 + phase) * 0.03
