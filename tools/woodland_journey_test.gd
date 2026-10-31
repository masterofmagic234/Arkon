extends SceneTree
## The first-clearing gate separately drives its complete mission. This driver
## continues through all seven new areas using production movement and hitscan.
var game: Node3D
var player: Node3D
var failed := ""
var visited: Array[int]=[]
func _init() -> void:call_deferred("run")
func run() -> void:
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    var save=load("res://scripts/woodland_journey_state.gd").new();save.completed.assign([0]);save.region=1
    _check(save.save_checkpoint(),"checkpoint write failed")
    change_scene_to_file("res://game.tscn");await _settle()
    _bind();_check(game.region_index==1 and game.journey.completed==[0],"new area did not restore the clearing checkpoint")
    visited.append(1)
    # Escort: stay with the actual animated scout, never advance its counters.
    for i in range(6500):
        if game.regional.guide_step==4:break
        var guide: Node3D=game.regional.guide
        var direction: Vector3=guide.position-player.position;direction.y=0
        if direction.length()>2.2:_move(direction.normalized())
        else:_release()
        await physics_frame
    _release();_check(game.regional.guide_step==4,"escort never reached the compass")
    await _walk(Vector3(16,0,-19));_interact();await physics_frame
    _check(game.regional.complete,"compass pickup failed")
    await _next()
    # Real sluice gate blocks the bridge until the valve pattern is correct.
    _check(game.world.bridge_gate!=null,"mill bridge started open")
    await _walk(Vector3(-16,0,9));_interact();await physics_frame
    await _walk(Vector3(16,0,9));_interact();await physics_frame
    _check(game.regional._valves_correct() and game.world.bridge_gate==null,"sluices did not lower the bridge")
    await _walk(Vector3(0,0,9));await _walk(Vector3(0,0,-10));await _walk(Vector3(0,0,-19));_interact();await physics_frame
    _check(game.regional.complete,"mill key not recovered")
    await _walk(Vector3(0,0,-25));await _next()
    # Physical reflection directions, not simply pressing every mirror once.
    await _walk(Vector3(-12,0,-.8));_interact();await physics_frame
    await _walk(Vector3(12,0,-.8));_interact();await physics_frame;_interact();await physics_frame
    _check(game.regional.light_reaches_flower,"reflected beam missed the flower")
    await _walk(Vector3(12,0,-17));_interact();await physics_frame
    _check(game.regional.complete,"solar seal pickup failed")
    await _walk(Vector3(12,0,-24));await _next()
    # Traverse the actual suspended route; crouching braces against gusts.
    await _walk(Vector3(-20,0,12))
    player.toggle_quiet()
    for point in game.world.RAVINE_ROUTE:await _walk(point)
    await _walk(Vector3(20,0,-18));_interact();await physics_frame
    _check(game.regional.complete,"rope did not open the ravine's return path")
    player.toggle_quiet();await _next()
    # The camp permits combat; independent AI tests also cover quiet sight/noise.
    await _walk(Vector3(-18,0,16));_interact();await physics_frame
    await _walk(Vector3(-23,0,-5));_interact();await physics_frame
    for point in [Vector3(-25,0,-25),Vector3(27,0,-25),Vector3(27,0,-10),Vector3(23,0,-10)]:await _walk(point)
    _interact();await physics_frame
    for point in [Vector3(27,0,-25),Vector3(0,0,-25),Vector3(0,0,-20)]:await _walk(point)
    _interact();await physics_frame
    _check(game.regional.complete and game.regional.crates.count(true)==3,"camp caches were not recovered")
    await _walk(Vector3(0,0,-26));await _next()
    # Actual target hitboxes consume slingshot shots in the shown order.
    await _walk(Vector3(0,0,6))
    var target_nodes=get_nodes_in_group("woodland_target")
    for symbol in [0,1,2,1]:
        var target: Node3D=target_nodes[symbol]
        _aim(target.global_position);player.request_fire()
        for i in range(14):await physics_frame
    _check(game.regional.complete and game.regional.rune_step==4,"rune sequence did not open the circle")
    await _walk(Vector3(26,0,6));await _next()
    # Final guardian has a real second phase, including the ground shockwave.
    await _walk(Vector3(0,0,11));_interact();await physics_frame
    _check(game.stage=="cache" and game.tank.max_hp==12,"ancient guardian did not start")
    await _walk(Vector3(0,0,-1))
    var stomp_seen=false
    for i in range(4000):
        if game.tank.defeated:break
        if game.mission_failed:_fail("final guardian defeated the driver");return
        var tank=game.tank;var direction=Vector3.ZERO
        _aim(tank.position+Vector3.UP*1.15)
        if tank.state in ["windup","charge"]:direction=tank._charge_direction.cross(Vector3.UP).normalized()
        elif tank.state in ["stomp_windup","shockwave"]:
            stomp_seen=true;direction=tank.position.direction_to(player.position);direction.y=0
            if player.dash_cooldown<=0:player.request_dash()
        elif tank.state=="recover":player.request_fire()
        elif player.position.distance_to(tank.position)>8:direction=player.position.direction_to(tank.position);direction.y=0
        _move(direction.normalized());await physics_frame
    _release();_check(game.tank.defeated and stomp_seen,"final encounter skipped its second phase or did not finish")
    await _walk(Vector3(0,0,-18));_interact();await physics_frame
    _check(game.journey.completed.size()==8 and game.regional.complete,"final acorns did not complete the eight-location journey")
    await _next(0)
    _check(game.journey.completed.size()==8,"shortcut lost journey progress")
    await _walk(game.EXIT);_interact();await _settle()
    _check(current_scene.scene_file_path=="res://scenes/level2.tscn","only the full journey may lead to Level2")
    _check(root.get_node("GameState").is_completed(&"level1"),"full level completion was not persisted")
    print("WOODLAND JOURNEY: PASS visited=",visited," escort, sluices, reflected beam, wind bridge, camp, real runes, two-phase guardian, checkpoints and final car")
    current_scene.queue_free();current_scene=null;await _settle()
    await load("res://tools/level3_test_teardown.gd").drain_audio(self);quit(0)
func _bind() -> void:game=current_scene;player=game.player
func _settle() -> void:
    for i in range(12):await physics_frame
func _next(target: int=-1) -> void:
    var expected=game.region_index+1 if target<0 else target
    await _walk(game.NEXT_TRAIL);_interact();await _settle();_bind()
    _check(game.region_index==expected,"trail did not lead to the expected area")
    visited.append(game.region_index)
    _check(not root.get_node("GameState").is_completed(&"level1"),"journey completed the level too early")
func _walk(target: Vector3) -> void:
    for i in range(2200):
        if game.mission_failed:_fail("defeated on route to "+str(target));return
        var direction: Vector3=target-player.position;direction.y=0
        if direction.length()<1.2:_release();return
        var aiming=false
        for guard in game.guards:
            if not guard.is_tank and not guard.defeated and guard.position.distance_to(player.position)<16:
                _aim(guard.position+Vector3.UP*.9);player.request_fire();aiming=true;break
        if not aiming:
            player.look_at(Vector3(target.x,player.position.y,target.z));player.camera.rotation=Vector3.ZERO
        _move(direction.normalized());await physics_frame
    _fail("blocked walking to %s at %s"%[target,player.position])
func _aim(at: Vector3) -> void:
    player.look_at(Vector3(at.x,player.position.y,at.z));player.camera.look_at(at)
func _move(direction: Vector3) -> void:
    var local: Vector3=player.global_basis.inverse()*direction
    for pair in [["l1_move_forward",-local.z],["l1_move_backward",local.z],["l1_move_left",-local.x],["l1_move_right",local.x]]:Input.action_press(pair[0],maxf(0,pair[1]))
func _release() -> void:
    for action in ["l1_move_forward","l1_move_backward","l1_move_left","l1_move_right"]:Input.action_release(action)
func _interact() -> void:
    var event=InputEventAction.new();event.action="l1_interact";event.pressed=true;Input.parse_input_event(event)
    var up=InputEventAction.new();up.action="l1_interact";up.pressed=false;Input.parse_input_event(up)
func _check(ok: bool,why: String) -> void:
    if not ok:_fail(why)
func _fail(why: String) -> void:
    _release();push_error("WOODLAND JOURNEY: "+why);quit(1)
