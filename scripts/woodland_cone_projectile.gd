extends Node3D
## A dodgeable, physically swept cone. Walls stop it before player damage.
var direction := Vector3.FORWARD
var speed := 14.0
var remaining := 25.0
var source: Node3D
var damage := 8
var travelled := 0.0
var hit_player := false
var hit_wall := false
var _query := PhysicsRayQueryParameters3D.new()

func setup(origin: Vector3, target: Vector3, actor: CharacterBody3D, projectile_visual: Node3D = null) -> void:
    global_position=origin;direction=origin.direction_to(target);source=actor
    name="EnemyConeProjectile"
    add_to_group("enemy_cone_projectile")
    if is_instance_valid(projectile_visual):
        projectile_visual.name="ThrownConeVisual"
        projectile_visual.visible=true
        add_child(projectile_visual)
    else:
        var mesh := MeshInstance3D.new()
        var body := SphereMesh.new();body.radius=.09;body.height=.22;body.radial_segments=8;body.rings=4
        mesh.mesh=body
        var material := StandardMaterial3D.new();material.albedo_color=Color("b28b55");material.roughness=.9;material.metallic_specular=.08
        mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(mesh)
    _query.collision_mask=1|4
    _query.exclude=[actor.get_rid()]

func _physics_process(delta: float) -> void:
    var step := minf(remaining,speed*delta)
    _query.from=global_position;_query.to=global_position+direction*step
    var hit := get_world_3d().direct_space_state.intersect_ray(_query)
    if not hit.is_empty():
        global_position=hit.position
        var target: Node=hit.collider
        if target.has_method("take_damage") and target.is_in_group("level1_player"):
            var accepted: bool=target.take_damage(damage,source)
            hit_player=true
            SignalBus.emit_audio_event(&"body_hit" if accepted else &"impact_soft",global_position)
        else:
            hit_wall=true
            var owner_director: Node=source.get("director") if is_instance_valid(source) else null
            var world: Node=owner_director.get("world") if is_instance_valid(owner_director) else null
            SignalBus.emit_audio_event(preload("res://scripts/woodland_audio_surfaces.gd").impact_kind(hit,world),global_position)
        queue_free();return
    global_position=_query.to;remaining-=step;travelled+=step
    rotate_object_local(Vector3.RIGHT,delta*18)
    if remaining<=0:queue_free()
