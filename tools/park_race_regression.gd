extends SceneTree
# Real scene budgets and geometry consistency, independent of host FPS.
const Teardown=preload("res://tools/level3_test_teardown.gd")
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const RaceProjection=preload("res://scripts/race_projection.gd")
const SceneryChecks=preload("res://tools/race_scenery_checks.gd")
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
        if String(node.name).begins_with("ParkGardenDetail"):
            detail_count+=1
            if node.mesh.get_surface_count()!=1: push_error("PARK/RACE: trail surface fragmentation");quit(1);return
            if detail_material==null: detail_material=node.material_override
            elif detail_material!=node.material_override: push_error("PARK/RACE: trail material fragmentation");quit(1);return
    if detail_count==0 or detail_count>24: push_error("PARK/RACE: excessive trail batches");quit(1);return
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
        if car.physical_progress(level.controller.track_pattern.size())>0 or absf(car.track_phase()-car.physical_progress(level.controller.track_pattern.size()))>.0001:
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
            if yaw==0.0:
                var uv: PackedVector2Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
                for i in range(2,uv.size(),2):
                    if 1.0/uv[i].y-1.0/uv[i-2].y>150.0:
                        push_error("PARK/RACE: a long unsampled strip erases distant turns/grades");quit(1);return
    if Data.TUNNEL_START-Data.BRIDGE_END<500 or Data.road_grade(1850)<=.04 or Data.road_grade(3080)>=-.08:
        push_error("PARK/RACE: missing bridge climb, separated approach or tunnel descent");quit(1);return
    var peak_heading := 0.0
    for i in range(level.controller.track_pattern.size()*4):
        peak_heading=maxf(peak_heading,absf(atan2(Math.track_center_slope(float(i)/4.0,level.controller.track_x),Data.SEGMENT_HEIGHT)))
    if peak_heading<.05:
        push_error("PARK/RACE: authored track has lost its physical bends");quit(1);return
    var player=level.controller.player
    var portal_failure := SceneryChecks.portal_geometry(level.renderer)
    if not portal_failure.is_empty(): push_error(portal_failure);quit(1);return
    for z: float in [420,1460,2075,2360,2718,3070,3278,3500,4078]:
        player.world_z=z;player.world_x=Math.track_center_x(z/40.0,level.controller.track_x)
        player.lateral_offset=0
        var canonical := (z+float(player.grid_world_z_offset))/40.0
        player.segment_index=floori(canonical);player.segment_progress=canonical-floor(canonical)
        for dimensions in [Vector2(960,540),Vector2(1280,720),Vector2(1600,720)]:
            for yaw: float in [-.65,0,.65]:
                player.heading_yaw=yaw;level.camera_state.reset(player)
                var scenery_failure := SceneryChecks.frame_geometry(level.renderer,dimensions)
                if not scenery_failure.is_empty(): push_error(scenery_failure);quit(1);return
                level.renderer.road_mesh.update(level.renderer,dimensions)
                var arrays: Array=level.renderer.road_mesh.verge.surface_get_arrays(0)
                for vertex in arrays[Mesh.ARRAY_VERTEX]:
                    if not vertex.is_finite() or vertex.x<-.02 or vertex.x>dimensions.x+.02 or vertex.y<-.02 or vertex.y>dimensions.y*level.renderer.PLAYFIELD_FRACTION+.02:
                        push_error("PARK/RACE: roadside ground crossed the camera without clipping");quit(1);return
                var c: float=player.world_x
                var ribbon := RaceProjection.ribbon(level.renderer,Vector3(c-5,.8,z-20),Vector3(c-5,.8,z+32),.10,dimensions)
                for vertex in ribbon:
                    if not vertex.is_finite() or not Rect2(Vector2(-.02,-.02),Vector2(dimensions.x+.04,dimensions.y*level.renderer.PLAYFIELD_FRACTION+.04)).has_point(vertex):
                        push_error("PARK/RACE: a passing connector exploded outside the playfield");quit(1);return
                var rear := RaceProjection.surface(level.renderer,[Vector3(c-1,0,z-40),Vector3(c+1,0,z-40),Vector3(c,2,z-40)],dimensions)
                if not rear.is_empty():
                    push_error("PARK/RACE: geometry behind the camera remains projected");quit(1);return
    for side: float in [-1,1]:
        var z := 3500.0
        player.world_z=z;player.segment_index=floori((z+player.grid_world_z_offset)/40)
        player.segment_progress=(z+player.grid_world_z_offset)/40-player.segment_index
        player.lateral_offset=side*(Data.TUNNEL_BODY_CLEAR_X-.85)
        player.world_x=Math.track_center_x(z/40,level.controller.track_x)+player.lateral_offset
        player.heading_yaw=-side*Data.NFS_MAX_HEADING_YAW
        level.camera_state.reset(player)
        var camera_z: float=z-level.camera_state.behind_distance
        var camera_x: float=level.renderer._camera_world_x(player.track_phase())
        if absf(camera_x-Math.track_center_x(camera_z/40,level.controller.track_x))>Data.TUNNEL_RADIUS-.24:
            push_error("PARK/RACE: follow camera passes through the tunnel wall");quit(1);return
    print("PARK/RACE CHECK: 81 elevated viewpoints; at most 9 scenery surfaces; clipped opaque walls; clear mountain openings; shared camera; bridge climb and 560m separated descent")
    if level.renderer.traffic_frames.size()!=9 or level.renderer.traffic_brake_frames.size()!=9 or level.renderer.traffic_feet.size()!=9:
        push_error("PARK/RACE: rival angles/anchors incomplete");quit(1);return
    level.queue_free()
    for i in range(3): await process_frame
    await Teardown.drain_audio(self)
    print("PARK/RACE REGRESSION: PASS — shared garden surfaces; occluders inside real walls; physical grid/ranking; finite road at 3 viewports/3 headings; 9 Camry angles, 2 lamp states")
    quit(0)
