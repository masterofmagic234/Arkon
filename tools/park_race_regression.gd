extends SceneTree
# Real scene budgets and geometry consistency, independent of host FPS.
const Teardown=preload("res://tools/level3_test_teardown.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var park: Node3D=load("res://game.tscn").instantiate()
    root.add_child(park);current_scene=park
    for i in range(5): await process_frame
    var scenery: Node3D=park.get_node("Level1Environment/ParkScenery")
    var detail_count := 0
    var detail_material: Material
    for node in scenery.get_children():
        if String(node.name).begins_with("ParkTrailDetail"):
            detail_count+=1
            if node.mesh.get_surface_count()!=1: push_error("PARK/RACE: trail surface fragmentation");quit(1);return
            if detail_material==null: detail_material=node.material_override
            elif detail_material!=node.material_override: push_error("PARK/RACE: trail material fragmentation");quit(1);return
    if detail_count==0 or detail_count>18: push_error("PARK/RACE: excessive trail batches");quit(1);return
    var occluder: ArrayOccluder3D=scenery.get_node("OpaqueParkWalls").occluder
    var point := PhysicsPointQueryParameters3D.new();point.collision_mask=1
    var space := park.get_world_3d().direct_space_state
    for vertex in occluder.get_vertices():
        point.position=vertex
        if space.intersect_point(point,1).is_empty():
            push_error("PARK/RACE: invisible occluder outside a real wall");quit(1);return
    park.queue_free()
    for i in range(4): await process_frame
    var level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    for i in range(4): await process_frame
    level.set_process(false);level.set_physics_process(false)
    # Every rival's physical start offset participates in rank, road centre
    # and presentation; no imaginary start-line progress at the grid's rear.
    for ai in level.controller.ais:
        var car=ai.car
        if car.physical_progress(80)>=0 or absf(car.track_phase()-car.physical_progress(80))>.0001:
            push_error("PARK/RACE: grid offset missing from physical progress");quit(1);return
        var center := preload("res://scripts/race_math.gd").track_center_x(car.track_phase(),level.controller.track_x)
        if absf(car.world_x-center-car.lateral_offset)>.0001:
            push_error("PARK/RACE: rival is not on its drawn road");quit(1);return
    for dimensions in [Vector2(960,540),Vector2(1280,720),Vector2(1600,720)]:
        for yaw in [-.30,0.0,.30]:
            level.camera_state.yaw_offset=yaw
            level.camera_state.roll=yaw*.04
            level.renderer.road_mesh.update(level.renderer,dimensions)
            var mesh: ArrayMesh=level.renderer.road_mesh.road
            if mesh.get_surface_count()!=1: push_error("PARK/RACE: road fragments into surfaces");quit(1);return
            for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
                if not vertex.is_finite(): push_error("PARK/RACE: nonfinite projected ground");quit(1);return
    if level.renderer.traffic_frames.size()!=9 or level.renderer.traffic_feet.size()!=9:
        push_error("PARK/RACE: rival angles/anchors incomplete");quit(1);return
    level.queue_free()
    for i in range(3): await process_frame
    await Teardown.drain_audio(self)
    print("PARK/RACE REGRESSION: PASS — 18 shared trail surfaces; occluders inside real walls; physical grid/ranking; finite road at 3 viewports/3 headings; 9 rival angles")
    quit(0)
