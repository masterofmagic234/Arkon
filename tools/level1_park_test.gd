extends SceneTree
const Data = preload("res://scripts/level_data.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    root.get_node("GameState").sfx_muted = true
    var game: Node = load("res://game.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    for i in range(8): await physics_frame
    var player: Node = game.get_node("Player")
    var enemies := get_nodes_in_group("level1_enemy")
    for enemy in enemies: enemy.set_physics_process(false)
    if not game.get_node("Level1Environment").park_ready:
        _fail("Park did not build")
        return
    # Compare the actual physics server with the grid at interior samples,
    # rather than asserting that one implementation repeats another formula.
    var query := PhysicsPointQueryParameters3D.new()
    query.collision_mask = 1
    query.collide_with_areas = false
    for y in range(Data.MAP_HEIGHT):
        for x in range(Data.MAP_WIDTH):
            var cell := Vector2i(x,y)
            if Data.DOOR_CELLS.has(cell): continue
            for offset in [Vector2(-0.60,-0.60),Vector2(0.60,-0.60),Vector2(-0.60,0.60),Vector2(0.60,0.60)]:
                var center := Data.cell_center_world(cell)
                query.position = Vector3(center.x+offset.x,0.40,center.z+offset.y)
                var solid: bool = not player.get_world_3d().direct_space_state.intersect_point(query,1).is_empty()
                if solid != (Data.CANONICAL_MAP[y][x]=="#") or Data.world_to_cell(query.position.x,query.position.z)!=cell:
                    _fail("Physics/grid mismatch at %s, %s" % [cell,offset])
                    return
    print("PARK CHECK: collision grid matches 6,900 physics samples")
    var map: RID = player.get_world_3d().navigation_map
    # Navigation mesh updates run on a worker; fixed-fps tests can otherwise
    # reach the query before the initial region has been committed.
    for i in range(120):
        if not NavigationServer3D.map_get_path(map,player.position,Data.park_position("Acorn01"),true).is_empty(): break
        OS.delay_msec(1)
        await physics_frame
    var pairs := 0
    for y in range(2,Data.MAP_HEIGHT-2):
        for x in range(2,Data.MAP_WIDTH-3):
            var a := Vector2i(x,y)
            var b := a+Vector2i.RIGHT
            if Data.CANONICAL_MAP[y][x]!="." or Data.CANONICAL_MAP[y][x+1]!="." or Data.DOOR_CELLS.has(a) or Data.DOOR_CELLS.has(b): continue
            var path := NavigationServer3D.map_get_path(map,Data.cell_center_world(a),Data.cell_center_world(b),true)
            pairs += 1
            if path.is_empty() or path[-1].distance_to(Data.cell_center_world(b))>0.1:
                _fail("Disconnected neighbouring nav cells: %s -> %s" % [a,b])
                return
    print("PARK CHECK: ",pairs," neighbouring nav pairs reachable")
    var before_gate := Data.park_position("Player")
    var after_gate := Data.cell_center_world(Vector2i(14,15))
    var closed_path := NavigationServer3D.map_get_path(map,before_gate,after_gate,true)
    if not closed_path.is_empty() and closed_path[-1].distance_to(after_gate)<1.0:
        _fail("Closed first gate can be bypassed")
        return
    var camera := player.get_node("Camera3D") as Camera3D
    var reticle := game.get_node("HUD/ParkReticle") as Control
    if (reticle.position+reticle.size*0.5).distance_to(root.get_visible_rect().size*0.5)>0.01:
        _fail("Reticle does not match screen centre")
        return
    player.global_position = Data.cell_center_world(Vector2i(14,27))+Vector3.UP*0.9
    player.rotation = Vector3.ZERO
    camera.rotation = Vector3.ZERO
    var target: Node = game.get_node("Squirrel01")
    target.global_position = Data.cell_center_world(Vector2i(14,24))+Vector3.UP*0.95
    for i in range(3): await physics_frame
    var ammo: int = player.ammo
    player.request_fire()
    for i in range(13): await physics_frame
    player.request_fire()
    for i in range(2): await physics_frame
    if not target.defeated or player.ammo!=ammo-2:
        _fail("Two legal hits did not stun the scout")
        return
    print("PARK CHECK: centred hitscan and legal fire cadence")
    # Drive through a real Area3D; old tests invoked the handler outside physics.
    var item: Node = load("res://scenes/level1_acorn.tscn").instantiate()
    item.name = "PhysicsPickupProbe"
    item.item_id = &"PhysicsPickupProbe"
    item.position = player.position+Vector3(0,-0.3,-2.6)
    game.add_child(item)
    var count: int = game.collected
    Input.action_press("l1_move_forward")
    for i in range(25): await physics_frame
    Input.action_release("l1_move_forward")
    await physics_frame
    if game.collected != count+1:
        _fail("Physical pickup did not emit exactly one collection")
        return
    print("PARK CHECK: physical pickup lifecycle")
    # The thief must carry the actual item, then release it on a real hit.
    var thief: Node = game.get_node("Squirrel04")
    var stolen: Node = game.get_node("Acorn04")
    thief.global_position = Data.park_position("Squirrel04",0.95)
    thief.set_physics_process(true)
    for i in range(120):
        await physics_frame
        if thief.carried_acorn == stolen: break
    if thief.carried_acorn != stolen:
        print("THIEF DEBUG: map=",thief.navigation_agent.get_navigation_map()," world=",map," iteration=",NavigationServer3D.map_get_iteration_id(thief.navigation_agent.get_navigation_map())," next=",thief.navigation_agent.get_next_path_position()," velocity=",thief.velocity," path=",thief.navigation_agent.get_current_navigation_path())
        _fail("Thief did not steal: pos=%s goal=%s dir=%s nav_end=%s item=%s" % [thief.position,thief.ai.goal,thief.desired_dir,thief.navigation_agent.is_navigation_finished(),stolen.position])
        return
    thief.take_damage(1,player)
    for i in range(2): await physics_frame
    if stolen.get_parent()!=game or stolen.has_meta("carried") or not stolen.monitoring:
        _fail("Stunned thief did not release a collectible acorn")
        return
    print("PARK CHECK: actual theft and recovery")
    # A throw is warned before launch, can be dodged, hits a stationary player
    # and cannot pass through courtyard walls.
    var thrower: Node = game.get_node("Squirrel03")
    thrower.global_position = Data.cell_center_world(Vector2i(34,14))+Vector3.UP*0.95
    player.global_position = Data.cell_center_world(Vector2i(38,14))+Vector3.UP*0.9
    player.rotation = Vector3.ZERO
    camera.rotation = Vector3.ZERO
    thrower.set_physics_process(true)
    for i in range(20):
        await physics_frame
        if thrower.attack_windup>0: break
    if thrower.attack_windup<=0 or not thrower.warning_ring.visible or not get_nodes_in_group("level1_projectile").is_empty():
        _fail("Thrower has no warning before launch")
        return
    var hp: int = player.get_hp()
    var launched := false
    Input.action_press("l1_move_backward")
    for i in range(40): await physics_frame
    Input.action_release("l1_move_backward")
    for i in range(70):
        await physics_frame
        launched = launched or not get_nodes_in_group("level1_projectile").is_empty()
    if not launched or player.get_hp()!=hp:
        _fail("Locked throw could not be dodged")
        return
    player.global_position = Data.cell_center_world(Vector2i(38,14))+Vector3.UP*0.9
    thrower.ai.attack_cooldown = 0
    for i in range(125):
        await physics_frame
        if player.get_hp()<hp: break
    thrower.set_physics_process(false)
    if player.get_hp()!=hp-8:
        _fail("Swept cone did not damage a stationary player")
        return
    hp = player.get_hp()
    player.global_position = Data.cell_center_world(Vector2i(32,14))+Vector3.UP*0.9
    var blocked_cone: Node = load("res://scripts/level1_thrown_cone.gd").new()
    game.add_child(blocked_cone)
    blocked_cone.launch(Data.cell_center_world(Vector2i(32,11))+Vector3.UP*1.3,player.global_position+Vector3.UP*0.35,thrower)
    for i in range(60): await physics_frame
    if is_instance_valid(blocked_cone) or player.get_hp()!=hp:
        _fail("Cone travelled through a solid courtyard wall")
        return
    print("PARK CHECK: warned throw, dodge, swept hit and wall blocking")
    player.global_position = Data.cell_center_world(Vector2i(14,27))+Vector3.UP*0.9
    # Real viewport GUI routing with three fingers: movement, camera, fire.
    # A second touch inside the stick must not steal the first finger's ID.
    var hud: Node = game.get_node("HUD")
    hud.joystick.visible = true
    hud.knob.visible = true
    hud.fire_button.visible = true
    hud.look_area.visible = true
    player.desktop_mode = false
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    var joystick_point: Vector2 = hud.joystick.position+hud.joystick.size*0.5+Vector2(38,-38)
    var look_point := Vector2(770,350)
    var fire_point: Vector2 = hud.fire_button.position+hud.fire_button.size*0.5
    _touch(0,joystick_point,true)
    _touch(1,look_point,true)
    var yaw: float = player.rotation.y
    var pitch: float = camera.rotation.x
    var drag := InputEventScreenDrag.new()
    drag.index = 1
    drag.position = look_point+Vector2(35,24)
    drag.relative = Vector2(35,24)
    root.push_input(drag,true)
    _touch(3,joystick_point,true)
    if hud.joystick_touch_id!=0 or hud.look_touch_id!=1 or absf(player.rotation.y-yaw)<0.1 or absf(camera.rotation.x-pitch)<0.05:
        _fail("Move/look touch ownership or vertical look failed")
        return
    var held_ammo: int = player.ammo
    _touch(2,fire_point,true)
    for i in range(26): await physics_frame
    if hud.fire_touch_id!=2 or player.ammo>held_ammo-2 or not Input.is_action_pressed("l1_move_forward"):
        _fail("Simultaneous move/look/held fire failed")
        return
    _touch(2,fire_point,false)
    _touch(1,look_point,false)
    _touch(0,joystick_point,false)
    _touch(3,joystick_point,false)
    if hud.fire_held or hud.joystick_touch_id!=-1 or hud.look_touch_id!=-1 or Input.is_action_pressed("l1_move_forward"):
        _fail("Touch release left input stuck")
        return
    print("PARK CHECK: three-finger move/look/fire and clean release")
    player.desktop_mode = true
    player.rotation = Vector3.ZERO
    camera.rotation = Vector3.ZERO
    # Isolate the final-pickup contract in a fixture; it must leave control with
    # the player until boarding, rather than immediately replacing the scene.
    game.collected = 5
    game.doors_opened.assign([&"Door01",&"Door02",&"Door03"])
    var final: Node = load("res://scenes/level1_acorn.tscn").instantiate()
    final.item_id = &"FinalPhysicsProbe"
    final.position = player.position+Vector3(0,-0.3,-2.6)
    game.add_child(final)
    Input.action_press("l1_move_forward")
    for i in range(25): await physics_frame
    Input.action_release("l1_move_forward")
    if not game.exit_ready or game.mission_complete or not player.input_enabled or current_scene!=game:
        _fail("Final pickup did not unlock a playable walk to the car")
        return
    print("PARK CHECK: final pickup retains player control until boarding")
    root.get_node("PauseManager").toggle()
    if not game.get_node("HUD/PausePanel").visible:
        _fail("Pause has no visible interface")
        return
    root.get_node("PauseManager").resume()
    print("PARK CHECK: visible pause and resume")
    game.queue_free()
    for i in range(3): await process_frame
    root.get_node("AudioManager").shutdown()
    OS.delay_msec(40)
    print("LEVEL1 PARK TEST: PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error("LEVEL1 PARK TEST: "+reason)
    quit(1)

func _touch(index: int, point: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = point
    event.pressed = pressed
    root.push_input(event,true)
