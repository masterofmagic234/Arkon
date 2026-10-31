extends SceneTree
## Drive the shipped mission with production movement, interaction and hitscan.
var game: Node3D
var player: Node3D
var failure := ""
var charges_seen := 0
var recovered_shots := 0
var last_state := ""

func _init() -> void: call_deferred("_run")

func _run() -> void:
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").sfx_muted=true
    change_scene_to_file("res://game.tscn")
    for i in range(8): await physics_frame
    game=current_scene; player=game.player
    if not game.ready_for_play: return _fail("new mission did not boot")
    game.interact()
    if game.stations_lit!=0: return _fail("interaction worked from outside range")
    var reverse := "--reverse-order" in OS.get_cmdline_user_args()
    var route := [Vector3(-10,0,15),Vector3(-19,0,4),Vector3(-22,0,-7),Vector3(-15,0,-14),Vector3(0,0,-18),Vector3(15,0,-12),Vector3(22,0,0)]
    if reverse: route=[Vector3(10,0,16),Vector3(22,0,0),Vector3(17,0,-11),Vector3(0,0,-18),Vector3(-15,0,-14),Vector3(-22,0,-7)]
    for point in route:
        if not await _walk(point): return _fail(failure)
        _interact_input(); await physics_frame
        if game.mission_failed: return _fail("player died on woodland route")
    if game.stations_lit!=3 or game.stage!="cache": return _fail("nonlinear objectives did not unlock encounter")
    if not await _walk(Vector3(4,0,-5)): return _fail(failure)
    for i in range(3000):
        if game.tank.defeated: break
        if game.mission_failed: return _fail("tank fight killed input driver")
        var tank=game.tank
        _observe_tank()
        _aim(tank.global_position+Vector3.UP*1.15)
        var direction := Vector3.ZERO
        if tank.state in ["windup","charge"]:
            direction=tank._charge_direction.cross(Vector3.UP).normalized()
            # Move toward the central arena instead of against its outer walls.
            if Vector2(player.position.x+direction.x*4,player.position.z+direction.z*4+12).length()>13: direction=-direction
        elif tank.state=="recover":
            var before: int=tank.hp
            player.request_fire()
            if before>tank.hp: recovered_shots+=1
        else:
            var distance: float=Vector2(player.position.x-tank.position.x,player.position.z-tank.position.z).length()
            if distance>8: direction=player.position.direction_to(tank.position); direction.y=0
        _move(direction)
        await physics_frame
    _release()
    if not game.tank.defeated: return _fail("tank not defeated by actual recovery-window hitscan")
    for i in range(4): await physics_frame
    if charges_seen==0 or game.stage!="reward": return _fail("encounter skipped its attack or reward state")
    if not await _walk(game.CACHE): return _fail(failure)
    _interact_input(); await physics_frame
    if not game.journey.completed.has(0): return _fail("clearing did not unlock its next trail")
    if not await _walk(Vector3(20,0,-20)): return _fail(failure)
    if not await _walk(game.NEXT_TRAIL): return _fail(failure)
    _interact_input()
    for i in range(24): await physics_frame
    if current_scene.scene_file_path!="res://game.tscn" or current_scene.region_index!=1:return _fail("clearing did not lead into the second location")
    if root.get_node("GameState").is_completed(&"level1"):return _fail("a single location incorrectly completed the whole level")
    print("WOODLAND PLAYTHROUGH: PASS order=", "reverse" if reverse else "normal", " charge_cycles=",charges_seen)
    current_scene.queue_free()
    for i in range(3): await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    quit(0)

func _walk(target: Vector3) -> bool:
    for i in range(1500):
        if game.mission_failed: failure="player defeated on route to %s" % target; _release(); return false
        _observe_tank()
        var direction: Vector3=target-player.position; direction.y=0
        if direction.length()<1.25: _release(); return true
        var aimed:=false
        for guard in game.guards:
            if not guard.is_tank and not guard.defeated and guard.position.distance_to(player.position)<17:
                _aim(guard.position+Vector3.UP*.9); player.request_fire(); aimed=true; break
        if not aimed:
            player.look_at(Vector3(target.x,player.position.y,target.z)); player.camera.rotation=Vector3.ZERO
        _move(direction.normalized())
        await physics_frame
    failure="movement blocked on route to %s at %s" % [target,player.position]; _release(); return false

func _observe_tank() -> void:
    if game.tank.state=="windup" and last_state!="windup": charges_seen+=1
    last_state=game.tank.state

func _aim(at: Vector3) -> void:
    player.look_at(Vector3(at.x,player.position.y,at.z))
    player.camera.look_at(at)

func _move(direction: Vector3) -> void:
    var local: Vector3=player.global_basis.inverse()*direction
    Input.action_press("l1_move_forward",maxf(0,-local.z)); Input.action_press("l1_move_backward",maxf(0,local.z))
    Input.action_press("l1_move_left",maxf(0,-local.x)); Input.action_press("l1_move_right",maxf(0,local.x))

func _release() -> void:
    for action in ["l1_move_forward","l1_move_backward","l1_move_left","l1_move_right"]: Input.action_release(action)

func _interact_input() -> void:
    var event:=InputEventAction.new(); event.action="l1_interact"; event.pressed=true; Input.parse_input_event(event)
    var up:=InputEventAction.new(); up.action="l1_interact"; up.pressed=false; Input.parse_input_event(up)

func _fail(reason: String) -> void:
    _release(); push_error("WOODLAND PLAYTHROUGH: "+reason); quit(1)
