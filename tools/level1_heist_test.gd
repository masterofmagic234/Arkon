extends SceneTree
# Focused fixtures stage actors. The separate complete playthrough uses only
# production input, real pickups, legal shots and actual car boarding.
const Data=preload("res://scripts/level_data.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
var game: Node3D
var heist: Node3D
var player: Node3D
var camera: Camera3D
var failed := false

func _init() -> void: call_deferred("_run")
func check(value: bool, line: String) -> void:
    if not value: failed=true; push_error("LEVEL1 HEIST: "+line)
func frames(count_: int) -> void:
    for i in range(count_): await physics_frame
func stage(device: Node3D, offset := Vector3(0,.9,1.8)) -> void:
    player.global_position=device.global_position+offset
    player.rotation=Vector3.ZERO
    camera.look_at(heist.interaction_point(device))
func press_e() -> void:
    var key := InputEventKey.new(); key.physical_keycode=KEY_E; key.pressed=true
    Input.parse_input_event(key)
    var up := InputEventKey.new(); up.physical_keycode=KEY_E
    Input.parse_input_event(up)
func touch(index: int, at: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new(); event.index=index; event.position=at; event.pressed=pressed
    root.push_input(event,true)

func _run() -> void:
    root.get_node("GameState").sfx_muted=true
    root.get_node("GameState").music_muted=true
    game=load("res://game.tscn").instantiate(); root.add_child(game); current_scene=game
    await frames(8)
    heist=game.heist; player=game.player; camera=game.camera
    for enemy in get_nodes_in_group("level1_enemy"): enemy.set_physics_process(false)
    game.encounters.set_physics_process(false)
    var acorn: Node3D=game.get_node("Acorn03")
    player.global_position=acorn.global_position+Vector3.UP*.3
    await frames(5)
    check(is_instance_valid(acorn) and game.collected==0,"A sealed exhibit is collectible before its puzzle")
    var dial: Node3D=heist.get_node("MoonDial1")
    check(not heist.request_interact(),"A device accepts commands outside reach")
    stage(dial)
    press_e(); await frames(2)
    check(dial.value==1 and not heist.moon_solved,"E does not turn exactly the focused lens")
    check(acorn.has_meta("heist_locked"),"One lens alone unlocks the exhibit")
    dial=heist.get_node("MoonDial2"); stage(dial); press_e(); await frames(2); press_e(); await frames(2)
    dial=heist.get_node("MoonDial3"); stage(dial); press_e(); await frames(2)
    check(heist.moon_solved and not acorn.has_meta("heist_locked"),"The readable lunar sequence does not release the real pickup")
    player.global_position=acorn.global_position+Vector3.UP*.3
    await frames(6)
    check(game.collected==1 and not is_instance_valid(acorn),"An unlocked exhibit cannot be physically recovered")
    var overlap: Node3D=game.get_node("Acorn06")
    player.global_position=overlap.global_position+Vector3.UP*.3
    await frames(4)
    check(game.collected==1,"Standing in a sealed pickup bypasses its lock")
    heist._unlock("Acorn06"); await frames(4)
    check(game.collected==2 and not is_instance_valid(overlap),"Releasing a seal around an already-overlapping player leaves the pickup stuck")
    print("HEIST CHECK: locked pickup, remote rejection, E-driven three-lens puzzle, actual recovery")

    game.get_node("Level1Layout/Doors/Door02").open()
    await frames(35)
    heist.set_physics_process(false)
    heist.clock=(TAU-2.1)/.48
    player.global_position=heist.scanners[1].position+Vector3(-5,.9,0)
    var scan_alarm: float=heist.alarm
    for i in range(12): heist._update_scanners(.1)
    check(heist.scan_exposure>=.8 and heist.alarm>scan_alarm,"An exposed player in the moving sweep does not raise alarm")
    heist.clock=(TAU+asin((atan2(3.6,-7.2)-PI*.5)/1.18)-2.1)/.48
    player.global_position=Data.cell_center_world(Vector2i(72,19))+Vector3.UP*.9
    scan_alarm=heist.alarm
    for i in range(12): heist._update_scanners(.1)
    check(heist.scan_exposure==0 and is_equal_approx(heist.alarm,scan_alarm),"A security sweep identifies a player through solid gallery masonry")
    heist.set_physics_process(true)
    print("HEIST CHECK: live sweep identifies an exposed player; actual masonry interrupts the beam")
    var relay: Node3D=heist.get_node("GalleryRelay")
    stage(relay); await frames(7); heist.ui._refresh()
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    var interact_point: Vector2=heist.ui.prompt.get_global_rect().get_center()
    touch(7,interact_point,true); await frames(1); touch(7,interact_point,false); await frames(39)
    var progress: float=heist.action_progress
    root.get_node("PauseManager").set_paused(true)
    await frames(90)
    check(is_equal_approx(progress,heist.action_progress),"Pause advances a timed interaction")
    check(not player.request_dash() and not heist.request_interact(),"Gameplay commands work while paused")
    root.get_node("PauseManager").resume()
    player.global_position+=Vector3.RIGHT*4
    await frames(2)
    check(heist.action==null and not relay.used and game.get_node("Acorn04").has_meta("heist_locked"),"Walking away does not cancel sabotage without granting its reward")
    check(relay.work_progress>0 and relay.work_progress<2,"Interrupted work is lost rather than retained")
    stage(relay); press_e(); await frames(30)
    player.take_damage(8)
    await frames(2)
    check(heist.action==null and not relay.used,"Taking damage does not interrupt sabotage")
    stage(relay); press_e(); await frames(125)
    check(heist.gallery_disabled and relay.used and not game.get_node("Acorn04").has_meta("heist_locked"),"A complete sabotage does not disable security and release the exhibit")
    check(not heist.request_interact(),"A spent relay can be farmed")
    print("HEIST CHECK: touch command; timed sabotage freezes on pause, cancels on movement/damage, completes once")

    # Real sight rays reject a device across a solid masonry cell.
    var old_position: Vector3=relay.position
    relay.used=false; relay.position=Data.cell_center_world(Vector2i(65,22))+Vector3.LEFT*1.1
    player.global_position=Data.cell_center_world(Vector2i(65,22))+Vector3(1.1,.9,0)
    camera.look_at(heist.interaction_point(relay))
    check(heist.find_focus()==null,"A prompt is offered through a wall")
    relay.position=old_position; relay.used=true

    # Crouching is useful out of sight, but does not make close contact safe.
    var guard: Node3D=game.get_node("Squirrel01")
    guard.global_position=Data.cell_center_world(Vector2i(29,47))+Vector3.UP*.95
    player.global_position=guard.global_position+Vector3(0,0,5)
    guard.squirrel_3d_visual._face_direction(Vector3.BACK)
    guard.suspicion=0; player.quiet_mode=true
    for i in range(12): heist.guard_can_see(guard,true,5,.1)
    check(guard.suspicion==0,"Quiet movement at range does not reduce identification")
    player.quiet_mode=false
    var saw := false
    for i in range(12): saw=heist.guard_can_see(guard,true,5,.1) or saw
    check(saw,"An exposed player cannot be identified")
    guard.suspicion=0
    for i in range(12): heist.guard_can_see(guard,false,2,.1)
    check(guard.suspicion==0,"A blocked line of sight identifies the player")
    guard.suspicion=0; guard.squirrel_3d_visual._face_direction(Vector3.FORWARD)
    for i in range(12): heist.guard_can_see(guard,true,5,.1)
    check(guard.suspicion==0,"The facing cone identifies a quiet target behind the sentry")

    var bell: Node3D=heist.get_node("BellEntry")
    guard.global_position=bell.global_position+Vector3(4,.95,0); guard.set_physics_process(true)
    stage(bell); var alarm_before: float=heist.alarm
    press_e(); await frames(2)
    check(guard.investigation.distance_to(bell.global_position+Vector3.UP*.95)<.1 and guard.investigation_time>0,"The bell does not divert a live patrol to the false source")
    check(heist.alarm<=alarm_before+.1 and bell.cooldown>0,"A distraction incorrectly reports the player's position")
    heist._on_audio(&"footstep",player.global_position)
    check(guard.investigation.distance_to(bell.global_position+Vector3.UP*.95)<.1,"A single footstep instantly overrides the bell's false source")
    var distractions: int=heist.distractions
    press_e(); await frames(1)
    check(heist.distractions==distractions,"A bell ignores its cooldown")
    heist.make_noise(player.global_position,24,7)
    check(guard.investigation.distance_to(Vector3(player.position.x,.95,player.position.z))<.1,"A gunshot fails to override a distraction")
    guard.set_physics_process(false)
    print("HEIST CHECK: cover and facing; quiet movement; exposed identification; real-patrol distraction and cooldown")

    player.global_position=Data.cell_center_world(Vector2i(22,53))+Vector3.UP*.9
    player.rotation=Vector3.ZERO; player.quiet_mode=false
    var start: Vector3=player.global_position
    heist.ui.set_process(false); heist.ui.quiet.visible=true; heist.ui.dash.visible=true
    var point: Vector2=heist.ui.quiet.get_global_rect().get_center()
    touch(8,point,true); await frames(1); touch(10,point,false); await frames(1)
    check(not player.quiet_mode,"A foreign finger release activates the quiet button")
    touch(8,point,false); await frames(1)
    check(player.quiet_mode,"A real quiet-button touch does not toggle quiet movement")
    for pressed_: bool in [true,false]:
        var mouse := InputEventMouseButton.new(); mouse.button_index=MOUSE_BUTTON_LEFT; mouse.position=point; mouse.pressed=pressed_; mouse.device=InputEvent.DEVICE_ID_EMULATION
        root.push_input(mouse,true)
    check(player.quiet_mode,"Emulated mouse events activate a touched action twice")
    touch(11,point,true); root.get_node("PauseManager").set_paused(true)
    root.get_node("PauseManager").resume(); touch(11,point,false)
    check(player.quiet_mode,"A touch held across pause activates after resume")
    point=heist.ui.dash.get_global_rect().get_center()
    touch(9,point,true); await frames(1); touch(9,point,false)
    heist.ui.set_process(true)
    await frames(20)
    check(player.global_position.distance_to(start)>1.8 and player.global_position.distance_to(start)<3.0,"Shift does not produce a bounded physical dash")
    check(not player.request_dash(),"Dash cooldown can be bypassed")
    await frames(185)
    # Face the canonical wall; movement must stop at its actual collider.
    player.global_position=Data.cell_center_world(Vector2i(23,42))+Vector3.UP*.9
    player.rotation.y=-PI*.5
    Input.action_press("l1_dash"); await frames(1); Input.action_release("l1_dash"); await frames(20)
    check(Data.world_to_cell(player.position.x,player.position.z).x==23,"Dash tunnels through a masonry wall")
    check(player.get_hp()==92,"Dash grants or removes health")
    print("HEIST CHECK: production Shift, cooldown, physical wall stop, no health changes")

    # Finish is a score challenge, never a timer softlock.
    heist.begin_escape(); heist.begin_escape()
    heist.escape_elapsed=70
    await frames(2)
    check(not game.mission_failed and heist.result_line().contains("очков"),"A missed escape bonus prevents finishing")
    heist.infiltration_peak=0; heist.shots=0; heist.peak_alarm=100
    check(heist.result_rank()=="ПРИЗРАК ПАРКА","The mandatory escape alarm makes the stealth rank impossible")
    var guard_count: int=get_nodes_in_group("level1_enemy").size()
    check(guard_count==14,"Heist creates unbounded reinforcements")
    player.health.force_kill(); await frames(2)
    check(not heist.available() and not heist.ui.visible and not heist.request_interact(),"Failure leaves heist input or UI active")
    game.queue_free(); await frames(4); await Teardown.drain_audio(self)
    var state: Node=root.get_node("GameState")
    var previous_score: int=state.level1_best_score
    var previous_rank: String=state.level1_best_rank
    state.record_level1(previous_score+50,"TEST")
    state.record_level1(previous_score+20,"LOWER")
    state.load_settings()
    check(state.level1_best_score==previous_score+50 and state.level1_best_rank=="TEST" and state.music_muted,"Personal best fails persistence/monotonicity or overwrites audio settings")
    state.level1_best_score=previous_score; state.level1_best_rank=previous_rank; state.save_settings()
    if failed: quit(1)
    else: print("LEVEL1 HEIST TEST: PASS"); quit(0)
