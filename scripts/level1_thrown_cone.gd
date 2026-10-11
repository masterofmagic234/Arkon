extends Node3D
class_name Level1ThrownCone

var velocity := Vector3.ZERO
var life := 3.0
var source: Node

func launch(origin: Vector3, target: Vector3, owner_: Node) -> void:
    position = origin
    source = owner_
    velocity = origin.direction_to(target)*9.0
    var shape := SphereMesh.new()
    shape.radius = 0.17
    shape.height = 0.42
    shape.radial_segments = 8
    shape.rings = 4
    var mesh := MeshInstance3D.new()
    mesh.mesh = shape
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.64,0.32,0.12)
    material.emission_enabled = true
    material.emission = Color(1.0,0.36,0.06)
    material.emission_energy_multiplier = 0.6
    mesh.material_override = material
    add_child(mesh)
    add_to_group("level1_projectile")

func _physics_process(delta: float) -> void:
    life -= delta
    if life <= 0:
        queue_free()
        return
    var next := global_position+velocity*delta
    var ray := PhysicsRayQueryParameters3D.create(global_position,next,5)
    var hit := get_world_3d().direct_space_state.intersect_ray(ray)
    if not hit.is_empty():
        var body: Node = hit.collider
        if body.has_method("is_level1_player"):
            if body.take_damage(8,source):
                SignalBus.emit_audio_event(&"damage",global_position)
        queue_free()
        return
    global_position = next
    rotation.x += delta*8.0
    rotation.z += delta*6.0
