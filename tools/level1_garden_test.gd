extends SceneTree
# Behavioral coverage for the new finite encounters and physical supply cases.
const Data=preload("res://scripts/level_data.gd")
const Props=preload("res://scripts/level1_park_props.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
var game: Node3D
func _init() -> void: call_deferred("_run")
func _run() -> void:
    root.get_node("GameState").sfx_muted=true
    game=load("res://game.tscn").instantiate()
    root.add_child(game);current_scene=game
    for i in range(8): await physics_frame
    var director: Node=game.encounters
    var player=game.player
    for enemy in get_nodes_in_group("level1_enemy"):
        if not String(enemy.name).begins_with("GardenGuard"): enemy.set_physics_process(false)
    var initial_count := get_nodes_in_group("level1_enemy").size()
    if initial_count!=14 or not director.pending.is_empty():
        _fail("Authored finite guard set is missing or wakes before a gate");return
    var capsule := CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.8
    var body := PhysicsShapeQueryParameters3D.new();body.shape=capsule;body.collision_mask=1
    var space: PhysicsDirectSpaceState3D=player.get_world_3d().direct_space_state
    var portal := Data.cell_center_world(Props.PORTAL_CELL)
    var forward := Basis(Vector3.UP,Props.PORTAL_YAW)*Vector3.FORWARD
    for i in range(31):
        body.transform=Transform3D(Basis.IDENTITY,portal+forward*lerpf(-2.0,2.0,i/30.0)+Vector3.UP*.9)
        if not space.intersect_shape(body).is_empty(): _fail("New entrance arch blocks the player's capsule");return
    # Real gate tween -> published fact -> warning. A repeated command cannot
    # create or restart an encounter, and pausing cannot consume its warning.
    var door=game.get_node("Level1Layout/Doors/Door01")
    door.open()
    for i in range(30): await physics_frame
    if not director.pending.has(0): _fail("Gate does not start its warning");return
    var remaining: float=director.pending[0]
    door.open();director.gate_opened(&"Door01")
    root.get_node("PauseManager").set_paused(true)
    for i in range(120): await physics_frame
    if not is_equal_approx(director.pending[0],remaining): _fail("Pause consumes encounter warning");return
    for guard in director.guards[0]:
        if guard.is_physics_processing() or not guard.warning_ring.visible:
            _fail("Guard attacks during warning or has no cue");return
    root.get_node("PauseManager").resume()
    for i in range(120): await physics_frame
    if not director.active.has(0) or not director.pending.is_empty() or get_nodes_in_group("level1_enemy").size()!=initial_count:
        _fail("Warning fails to activate the finite pre-existing guards exactly once");return
    for guard in director.guards[0]:
        if not guard.is_physics_processing(): _fail("Warned guard never wakes");return
        guard.set_physics_process(false)
    print("GARDEN CHECK: physical entrance clearance; finite real-gate encounter; warning survives 2s pause; no duplicates")
    # Each case is approached through ordinary movement and collected by the
    # physics server. Health/ammo caps and re-entry have observable effects.
    var supply: Area3D=director.supplies[0]
    player.global_position=supply.global_position+Vector3(2.6,.9,0)
    player.rotation=Vector3(0,PI*.5,0)
    player.ammo=Data.MAX_AMMO-3
    player.take_damage(10)
    Input.action_press("l1_move_forward")
    for i in range(30): await physics_frame
    Input.action_release("l1_move_forward")
    if director.supply_count!=1 or player.ammo!=Data.MAX_AMMO or player.get_hp()!=100 or not supply.has_meta("opened"):
        _fail("Physical supply pickup fails caps: count=%d ammo=%d hp=%d opened=%s pos=%s target=%s"%[director.supply_count,player.ammo,player.get_hp(),supply.has_meta("opened"),player.position,supply.position]);return
    player.global_position+=Vector3.RIGHT*2.8
    for i in range(4): await physics_frame
    player.ammo-=2
    Input.action_press("l1_move_forward")
    for i in range(35): await physics_frame
    Input.action_release("l1_move_forward")
    if director.supply_count!=1 or player.ammo!=Data.MAX_AMMO-2 or game.collected!=0:
        _fail("Supply can be farmed or changes mission progress");return
    print("GARDEN CHECK: actual supply pickup; capped rewards; no farming; independent mission progress")
    var thrower=director.guards[0][0]
    player.global_position=Data.cell_center_world(Vector2i(21,9))+Vector3.UP*.9
    # Perception now has a facing cone and a brief identification delay.
    # This combat fixture deliberately places the target in the sentry's view.
    thrower.squirrel_3d_visual._face_direction(thrower.global_position.direction_to(player.global_position))
    thrower.ai.pause_timer=1.0
    thrower.set_physics_process(true)
    var warned := false
    for i in range(210):
        await physics_frame
        warned=warned or thrower.attack_windup>0
        if player.get_hp()<100: break
    thrower.set_physics_process(false)
    if not warned or player.get_hp()!=92:
        _fail("New guard cannot warn and damage a stationary player: warned=%s hp=%d pos=%s suspicion=%.2f visible=%s yaw=%.2f state=%s"%[warned,player.get_hp(),thrower.position,thrower.suspicion,thrower.player_visible,thrower.squirrel_3d_visual.rotation.y,thrower.ai.debug_reason]);return
    print("GARDEN CHECK: new sentry actually warns, launches and deals the expected 8 damage")
    var deadline := Time.get_ticks_msec()+12000
    while Time.get_ticks_msec()<deadline:
        if game.level1_navigation.navigation_ready: break
        OS.delay_msec(1);await physics_frame
    if not game.level1_navigation.navigation_ready: _fail("Navigation timed out");return
    var map: RID=player.get_world_3d().navigation_map
    # Patrol endpoints must lie on reachable, physically body-clear ground,
    # including when their sector is still closed by a gate.
    for squad in director.guards:
        for guard in squad:
            var start: Vector3=guard.global_position
            body.transform=Transform3D(Basis.IDENTITY,Vector3(start.x,.9,start.z))
            if not space.intersect_shape(body).is_empty(): _fail("Guard is inside scenery");return
            for cell: Vector2i in guard.patrol_cells:
                var goal := Data.cell_center_world(cell)
                var path := NavigationServer3D.map_get_path(map,start,goal,true)
                if path.is_empty() or path[-1].distance_to(goal)>.1:
                    _fail("Unreachable local patrol: %s -> %s"%[guard.name,cell]);return
    var art: Node3D=game.get_node("Level1Environment/ParkScenery/NightGardenLandmarks")
    var materials: Array=[]
    var surfaces := 0
    for node in art.get_children():
        if node is MeshInstance3D:
            surfaces+=node.mesh.get_surface_count()
            if not materials.has(node.material_override): materials.append(node.material_override)
    if materials.size()!=2 or surfaces>48 or art.get_meta("triangle_count")>35000 or not art.find_children("*","Light3D",true,false).is_empty():
        _fail("Static landmark budget exceeded: materials=%d surfaces=%d triangles=%d"%[materials.size(),surfaces,art.get_meta("triangle_count")]);return
    director.begin_return();director.begin_return()
    if get_nodes_in_group("level1_enemy").size()!=initial_count: _fail("Return alarm respawns guards");return
    player.health.force_kill()
    for i in range(2): await physics_frame
    for squad in director.guards:
        for guard in squad:
            if guard.is_physics_processing(): _fail("Guards keep fighting after defeat");return
    print("GARDEN CHECK: all patrols reachable; architecture %d triangles / %d surfaces / 2 materials; no new lights; defeat stops encounters"%[art.get_meta("triangle_count"),surfaces])
    game.queue_free()
    for i in range(4): await process_frame
    await Teardown.drain_audio(self)
    print("LEVEL1 GARDEN TEST: PASS")
    quit(0)
func _fail(reason: String) -> void:
    Input.action_release("l1_move_forward")
    push_error("LEVEL1 GARDEN: "+reason)
    quit(1)
