extends RefCounted
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")

static func run(level) -> String:
    var overlay=level.car_3d_overlay
    var traffic=overlay.traffic
    if traffic.models.size()!=3 or traffic.rear_materials.size()!=3:
        return "Three live Camry-derived rivals or their individual brake lamps are missing"
    if overlay.world_root.find_children("*","Camera3D",true,false).size()!=1:
        return "Rivals created independent cameras instead of sharing the player camera"
    for model in traffic.models:
        var visual: MeshInstance3D=model.get_child(0)
        if visual.mesh.get_surface_count()!=3 or visual.get_parent().get_parent()!=overlay.world_root:
            return "Camry-derived traffic is not a batched live model in the shared vehicle world"
    if traffic.fitted_size.z<4.8 or traffic.fitted_size.z>4.95 or traffic.fitted_size.x<1.6:
        return "Camry has incorrect physical proportions"
    var player=level.controller.player
    for z: float in [90,Data.BRIDGE_START+360,Data.TUNNEL_START-150,Data.TUNNEL_START+220,Data.TUNNEL_END+100]:
        _place(player,z,level)
        for yaw: float in [-.45,0,.45]:
            player.heading_yaw=yaw;level.camera_state.reset(player)
            for i in range(3):
                var rival=level.controller.ais[i].car
                _place(rival,z+18+i*13,level);rival.brake_in=0
                rival.heading_yaw=atan2(Math.track_center_slope(rival.world_z/40,level.controller.track_x),40)
            level._process(1)
            for i in range(3):
                var model: Node3D=traffic.models[i]
                var rival=level.controller.ais[i].car
                var local_point: Vector2= overlay.camera.unproject_position(model.global_position)
                var actual: Vector2=overlay.position+overlay.pivot_offset+(local_point-overlay.pivot_offset).rotated(overlay.rotation)
                var expected: Vector2=level.renderer.project_ground(rival.world_x,rival.world_z-player.world_z,level.get_viewport_rect().size)
                if actual.distance_to(expected)>.25:
                    return "A live Camry ground contact disagrees with the main camera: %.3fpx"%actual.distance_to(expected)
                if absf(model.rotation.y+rival.heading_yaw)>.0001:
                    return "Camry rotates in discrete atlas steps instead of its physical heading"
                if absf(float(traffic.rear_materials[i].get_shader_parameter("lamp_energy"))-1.2)>.01:
                    return "Night running lamps are absent"
    level.controller.ais[0].car.brake_in=1
    level._process(1)
    if float(traffic.rear_materials[0].get_shader_parameter("lamp_energy"))<6.9 or float(traffic.rear_materials[1].get_shader_parameter("lamp_energy"))>1.3:
        return "Braking fails to brighten only the braking rival's rear lamps"
    print("RACE TRAFFIC: PASS — three live Camry-derived models; 3 surfaces each; continuous heading; camera/ground projection; individual running/brake lamps")
    return ""

static func _place(car,z: float,level) -> void:
    var canonical: float=(z+car.grid_world_z_offset)/40
    car.segment_index=floori(canonical);car.segment_progress=canonical-car.segment_index
    car.world_z=z;car.lateral_offset=0;car.world_x=Math.track_center_x(z/40,level.controller.track_x)
