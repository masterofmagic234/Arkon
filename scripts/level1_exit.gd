extends Node3D
class_name Level1Exit

const Rig = preload("res://scripts/race_240sx_rig.gd")
var ready_to_leave := false
var rig: RefCounted

func _ready() -> void:
    add_to_group("level1_exit")
    position = LevelData.park_position("Exit")
    var model := load("res://240_sx_nfs_pro_street.glb").instantiate() as Node3D
    model.name = "Parked240SX"
    add_child(model)
    # Duplicate materials before enabling lamps: the Level 2 source resource
    # must retain its own presentation state when the campaign advances.
    for node in model.find_children("*","MeshInstance3D",true,false):
        for i in range(node.mesh.get_surface_count()):
            var material: Material = node.get_active_material(i)
            if material: node.set_surface_override_material(i,material.duplicate())
    var bounds := AABB()
    var first := true
    for node in model.find_children("*","MeshInstance3D",true,false):
        var box: AABB = node.get_aabb()
        var transform_: Transform3D = model.global_transform.affine_inverse()*node.global_transform
        for x in [box.position.x,box.end.x]:
            for y in [box.position.y,box.end.y]:
                for z in [box.position.z,box.end.z]:
                    var p: Vector3 = transform_*Vector3(x,y,z)
                    if first:
                        bounds = AABB(p,Vector3.ZERO)
                        first = false
                    else: bounds = bounds.expand(p)
    rig = Rig.new()
    rig.build(model)
    var scale_ := 4.5/maxf(bounds.size.x,bounds.size.z)
    model.scale = Vector3.ONE*scale_
    model.position.y = -bounds.position.y*scale_+0.02
    model.rotation.y = PI
    var trigger := Area3D.new()
    trigger.name = "BoardingArea"
    trigger.collision_layer = 0
    trigger.collision_mask = 4
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 2.8
    shape.shape = sphere
    shape.position.y = 0.9
    trigger.add_child(shape)
    add_child(trigger)
    trigger.body_entered.connect(_on_body_entered)
    for x: float in [-0.7,0.7]:
        var light := SpotLight3D.new()
        light.position = Vector3(x,0.55,-2.0)
        light.rotation_degrees.x = -7.0
        light.light_color = Color(1.0,0.88,0.62)
        light.light_energy = 2.0
        light.spot_range = 15.0
        light.spot_angle = 35.0
        light.shadow_enabled = false
        add_child(light)

func _on_body_entered(body: Node3D) -> void:
    if not body.has_method("is_level1_player"): return
    var game := get_parent()
    if game.exit_ready: game.call_deferred("_on_exit_reached")
    else: SignalBus.show_message.emit("Машина ждёт. Сначала — шесть жёлудей и три ключа.",2.4)
