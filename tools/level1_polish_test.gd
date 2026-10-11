extends SceneTree
# Behavioral regressions reproduced during the second park pass.
const Data = preload("res://scripts/level_data.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    root.get_node("GameState").sfx_muted = true
    var game: Node = load("res://game.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    for i in range(15): await physics_frame
    var player: Node = game.get_node("Player")
    for enemy in get_nodes_in_group("level1_enemy"): enemy.set_physics_process(false)
    if not await _verify_environment(game,player): return
    var acorn: Node = game.get_node("Acorn04")
    var pedestal: MeshInstance3D
    for mesh: Node in game.find_children("*","MeshInstance3D",true,false):
        if mesh.scale.is_equal_approx(Vector3(0.95,0.24,0.95)) and Vector2(mesh.global_position.x,mesh.global_position.z).distance_to(Vector2(acorn.global_position.x,acorn.global_position.z))<0.1:
            pedestal = mesh
            break
    if pedestal == null:
        _fail("Acorn has no visible ground pedestal")
        return
    var before := pedestal.global_position
    var thief: Node = game.get_node("Squirrel04")
    thief._carry_acorn(acorn)
    thief.global_position += Vector3.RIGHT*3.0
    if pedestal.global_position.distance_to(before)>0.01 or absf(pedestal.global_position.y-0.12)>0.01:
        _fail("The thief carries the stone pedestal with the acorn")
        return
    thief._drop_acorn()
    print("POLISH CHECK: pedestal stays on the ground during theft/drop")
    var hud: Node = game.get_node("HUD")
    hud.joystick.visible = true
    hud.fire_button.visible = true
    hud.look_area.visible = true
    player.desktop_mode = false
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    var stick_point: Vector2 = hud.joystick.position+hud.joystick.size*0.5+Vector2(0,-38)
    var fire_point: Vector2 = hud.fire_button.position+hud.fire_button.size*0.5
    _touch(0,stick_point,true)
    _touch(1,Vector2(770,350),true)
    _touch(2,fire_point,true)
    if not hud.fire_held or not Input.is_action_pressed("l1_move_forward"):
        _fail("Focus regression did not actually hold movement and fire")
        return
    hud.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
    if Input.is_action_pressed("l1_move_forward") or hud.fire_held or hud.joystick_touch_id!=-1 or hud.look_touch_id!=-1 or hud.fire_touch_id!=-1 or player.fire_requested or not root.get_node("PauseManager").is_paused:
        _fail("Focus loss leaves input held or fails to pause")
        return
    root.get_node("PauseManager").resume()
    var position_before: Vector3 = player.global_position
    var ammo_before: int = player.ammo
    for i in range(20): await physics_frame
    if player.global_position.distance_to(position_before)>0.01 or player.ammo!=ammo_before:
        _fail("Focus resume produces phantom movement or a shot")
        return
    _touch(3,stick_point,true)
    _touch(4,fire_point,true)
    _touch(3,Vector2(640,12),false)
    _touch(4,Vector2(640,12),false,true)
    if Input.is_action_pressed("l1_move_forward") or hud.fire_held:
        _fail("Releasing/cancelling outside a control leaves input held")
        return
    print("POLISH CHECK: focus pause/resume and off-control touch cancellation")
    player.desktop_mode = true
    player.get_node("Camera3D").rotation.x = deg_to_rad(60)
    player.fire_cooldown = 0
    player.request_fire()
    for i in range(12): await physics_frame
    player.request_fire()
    for i in range(5): await physics_frame
    if not hud.hit_marker.visible:
        _fail("An old shot timer erases the fresh shot feedback")
        return
    for i in range(18): await physics_frame
    if hud.hit_marker.visible:
        _fail("Shot feedback never clears")
        return
    print("POLISH CHECK: consecutive shot feedback has independent lifetimes")
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    player.health.force_kill()
    if not game.mission_failed or not hud.mission.visible or hud.look_area.visible or hud.fire_button.visible or hud.fire_held:
        _fail("Defeat leaves active gameplay controls over the result panel")
        return
    if DisplayServer.get_name()!="headless" and Input.get_mouse_mode()!=Input.MOUSE_MODE_VISIBLE:
        _fail("Defeat result cannot be clicked with the desktop cursor")
        return
    root.get_node("PauseManager").set_paused(true)
    root.get_node("PauseManager").resume()
    if DisplayServer.get_name()!="headless" and Input.get_mouse_mode()!=Input.MOUSE_MODE_VISIBLE:
        _fail("Pause resume captures the cursor over a defeat result")
        return
    print("POLISH CHECK: defeat removes gameplay input and keeps result buttons usable")
    game.queue_free()
    for i in range(3): await process_frame
    root.get_node("AudioManager").shutdown()
    print("LEVEL1 POLISH TEST: PASS")
    quit(0)

func _touch(index: int, point: Vector2, pressed: bool, cancelled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = point
    event.pressed = pressed
    event.canceled = cancelled
    root.push_input(event,true)

func _verify_environment(game: Node, player: Node3D) -> bool:
    var water: MeshInstance3D = game.get_node("Level1Environment/ParkScenery/MoonGardenPond/WaterSurface")
    var faces := water.mesh.get_faces()
    var point := PhysicsPointQueryParameters3D.new()
    point.collision_mask=1
    point.collide_with_areas=false
    var space := player.get_world_3d().direct_space_state
    var samples := 0
    for i in range(0,faces.size(),3):
        var a: Vector3 = water.global_transform*faces[i]
        var b: Vector3 = water.global_transform*faces[i+1]
        var c: Vector3 = water.global_transform*faces[i+2]
        if (b-a).cross(c-a).length_squared()<0.00001: continue
        for u in range(7):
            for v in range(7-u):
                var p: Vector3 = a+(b-a)*(float(u)/6.0)+(c-a)*(float(v)/6.0)
                point.position=Vector3(p.x,0.4,p.z)
                samples+=1
                if space.intersect_point(point,1).is_empty():
                    _fail("Visible water lies on walkable ground at %s"%p)
                    return false
    print("POLISH CHECK: ",samples," actual water-triangle samples stay inside the physical shore")
    var map: RID = player.get_world_3d().navigation_map
    for i in range(2000):
        if game.level1_navigation.navigation_ready and NavigationServer3D.map_get_iteration_id(map)>0: break
        OS.delay_msec(1)
        await physics_frame
    var sphere := SphereShape3D.new()
    sphere.radius=0.35
    var sweep := PhysicsShapeQueryParameters3D.new()
    sweep.shape=sphere
    sweep.collision_mask=1
    for route in [[Vector2i(28,11),Vector2i(30,13)],[Vector2i(5,31),Vector2i(9,31)]]:
        var destination := Data.cell_center_world(route[1])
        var path := NavigationServer3D.map_get_path(map,Data.cell_center_world(route[0]),destination,true)
        if path.size()<2 or path[-1].distance_to(destination)>0.1:
            _fail("Corner/bench detour is unreachable")
            return false
        for i in range(1,path.size()):
            sweep.transform=Transform3D(Basis.IDENTITY,Vector3(path[i-1].x,0.4,path[i-1].z))
            sweep.motion=Vector3(path[i].x-path[i-1].x,0,path[i].z-path[i-1].z)
            var result := space.cast_motion(sweep)
            if result[0]<0.999:
                _fail("A body-sized navigation sweep hits a wall/bench: %s -> %s"%[path[i-1],path[i]])
                return false
    point.position=Data.cell_center_world(Vector2i(7,31))+Vector3.UP*0.4
    if space.intersect_point(point,1).is_empty():
        _fail("Bench has no physical collision")
        return false
    print("POLISH CHECK: physical bench and capsule-clear corner/bench navigation")
    var lights := game.get_node("Level1Environment").find_children("*","OmniLight3D",true,false)
    var maximum := 0
    for patch in game.get_node("Level1Environment/ParkScenery/ParkGround").get_children():
        var bounds: AABB = patch.mesh.get_aabb()
        bounds.position+=patch.global_position
        var affecting := 0
        for light in lights:
            var closest: Vector3 = light.global_position.clamp(bounds.position,bounds.end)
            if closest.distance_squared_to(light.global_position)<light.omni_range*light.omni_range:
                affecting+=1
        maximum=maxi(maximum,affecting)
    if maximum>8:
        _fail("Ground patch exceeds Compatibility local-light budget: %d"%maximum)
        return false
    print("POLISH CHECK: ",lights.size()," lanterns, maximum ",maximum," lights per ground patch")
    return true

func _fail(reason: String) -> void:
    push_error("LEVEL1 POLISH TEST: "+reason)
    quit(1)
