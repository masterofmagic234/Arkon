extends SceneTree
const Teardown = preload("res://tools/level3_test_teardown.gd")
# Full route through the real scene: only ScreenTouch/Drag/Key input drives the
# player. No actor teleports, health/ammo/progress overrides or completion facts.
var game: Level3Store
var _target: Level3Enemy
var _path := PackedVector2Array()
var _waypoint := 0
var _path_goal := Vector2.INF
var _path_timer := 0
var _firing := false
var _fire_release := 0
var _next_shot := 0
var _next_action := 0
var _shots := [0]
var _rooms: Dictionary = {}
var _story_phases: Dictionary = {}
var _dialogue_delay := 0
var _touches_started := false
var _last_phase: StringName = &""
var _watch_mode := false
var _snapshots_dir := ""
var _native_captures: Dictionary = {}
func _init() -> void:
    _watch_mode = OS.get_cmdline_user_args().has("--watch")
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--snapshots="): _snapshots_dir = arg.trim_prefix("--snapshots=")
    if not _snapshots_dir.is_empty(): DirAccess.make_dir_recursive_absolute(_snapshots_dir)
    call_deferred("_run")
func _touch(id: int, point: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index=id;event.position=point;event.pressed=pressed
    root.push_input(event,true)
func _drag(id: int, point: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index=id;event.position=point
    root.push_input(event,true)
func _move(vector: Vector2) -> void:
    var radius := game.move_joystick.active_radius
    var value := Vector2.ZERO if vector.length()<0.01 else vector.normalized()*(0.12+vector.length()*0.88)*radius
    _drag(71,game.move_joystick.get_global_rect().get_center()+value)
func _aim(vector: Vector2) -> void:
    _drag(72,game.aim_joystick.get_global_rect().get_center()+vector.normalized()*game.aim_joystick.active_radius*0.96)
func _action() -> void:
    if _next_action>0: return
    var point := game.action_button.get_global_rect().get_center()
    _touch(74,point,true);_touch(74,point,false)
    _next_action=20
func _walk(goal: Vector2) -> Vector2:
    if _path_timer<=0 or goal.distance_to(_path_goal)>35:
        _path=game.navigation.path(game.player.global_position,goal)
        _waypoint=1 if _path.size()>1 else 0
        _path_timer=24
        _path_goal=goal
    while _waypoint<_path.size() and game.player.global_position.distance_to(_path[_waypoint])<2.7: _waypoint+=1
    if _waypoint>=_path.size():
        var direct := goal-game.player.global_position
        return direct.normalized()*minf(1,direct.length()/14.0) if direct.length()>3 else Vector2.ZERO
    var vector := _path[_waypoint]-game.player.global_position
    return vector.normalized()*minf(1,vector.length()/14.0)
func _choose_target() -> void:
    _target=null
    var best := INF
    for enemy in game._enemies:
        var route := game.navigation.path(game.player.global_position,enemy.global_position)
        if route.is_empty(): continue
        var score := float(route.size())
        if score<best:
            _target=enemy
            best=score
func _fail(message: String) -> void:
    push_error("LEVEL 3 PLAYTHROUGH: "+message)
    if is_instance_valid(game):
        print("player=",game.player.global_position," hp=",game.player.health," ammo=",game.player.ammo," remaining=",game._enemies_alive," shots=",_shots[0])
    quit(1)
func _run() -> void:
    root.size=Vector2i(1280,720)
    game=load("res://scenes/level3_store.tscn").instantiate()
    root.add_child(game);current_scene=game
    for i in range(8): await physics_frame
    if not game.navigation.ready: _fail("navigation unavailable");return
    game.hud.mobile_active=true;game.hud._layout()
    game.player.fire_requested.connect(func(_a,_b,_c): _shots[0]+=1)
    for frame in range(22000):
        # Actual boarding/fade/loading can outlive the diner node. Wait on
        # that handoff by wall time without spending the ordinary gameplay
        # route's22000physics-step budget on empty resource-loading frames.
        if current_scene==null or not is_instance_valid(game) or current_scene.scene_file_path in ["res://scenes/ending_cutscene.tscn","res://menu.tscn"]:
            await _finish_campaign_route(frame)
            return
        if game._player_dead: _fail("player died on the input-driven route");return
        if game._level_complete_started:
            await _finish_campaign_route(frame)
            return
        await _capture_native_state()
        var phase: StringName = game.mission.phase
        _story_phases[phase] = true
        if phase != _last_phase:
            _last_phase = phase
            _touches_started = false
            _target = null
            _path_timer = 0
            _path_goal = Vector2.INF
        if game.dialogue.is_active():
            _touches_started = false
            if _watch_mode and not game.dialogue._fully_revealed:
                _dialogue_delay = maxi(90, game.dialogue.text_label.text.length()*3)
                await physics_frame
                continue
            _dialogue_delay -= 1
            if _dialogue_delay <= 0:
                var key := InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;root.push_input(key,true)
                key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=false;root.push_input(key,true)
                _dialogue_delay = 14
            await physics_frame
            continue
        if game.mission.controls_locked():
            if frame%600==0:
                print("LEVEL3 CINEMATIC: ",frame/60," phase=",phase," actors=",game._enemies.size())
                for staged in game._enemies: print("stage ",staged.name," pos=",staged.position," goal=",staged.staging_path[0] if not staged.staging_path.is_empty() else Vector2.ZERO)
            _touches_started = false
            await physics_frame
            continue
        if not _touches_started:
            _touch(71,game.move_joystick.get_global_rect().get_center(),true)
            _touch(72,game.aim_joystick.get_global_rect().get_center()+Vector2(45,0),true)
            _touches_started = true
        if phase != &"assault":
            _path_timer -= 1;_next_action -= 1
            var story_goal: Vector2 = game.mission.RECEPTION
            if phase in [&"kitchen", &"cleared", &"pizza"]: story_goal=game._scaled_cell_world(Level3StoreData.ORDER_CELL)
            elif phase == &"exit": story_goal=game.mission.car.to_global(game.mission.car.boarding_socket)
            _move(_walk(story_goal));_aim(game.player.global_position.direction_to(story_goal))
            if not game.mission.interaction().is_empty() or (phase==&"pizza" and game.player.global_position.distance_to(story_goal)<32): _action()
            if game._find_nearest_closed_door()!=null: _action()
            if frame%600==0: print("LEVEL 3 STORY ROUTE: ",frame/60," s phase=",phase," position=",game.player.global_position," goal=",story_goal)
            await physics_frame
            continue
        _path_timer-=1;_next_shot-=1;_next_action-=1;_fire_release-=1
        if _firing and _fire_release<=0:
            _touch(73,game.fire_button.get_global_rect().get_center(),false)
            _firing=false
        var player := game.player
        _rooms[Level3StoreData.room_at(player.global_position/1.5)["id"]]=true
        if _target==null or _target.state==Level3Enemy.State.DEAD: _choose_target()
        # React to the nearest visible threat, including a melee guard approaching
        # from a different room while the previous target is still alive.
        var threat: Level3Enemy
        var threat_distance := 300.0
        for enemy in game._enemies:
            var distance := player.global_position.distance_to(enemy.global_position)
            if distance<threat_distance and game.has_line_of_sight(player.global_position,enemy.global_position):
                threat=enemy;threat_distance=distance
        if threat!=null: _target=threat
        var goal := player.global_position
        var aim := player.get_aim_direction()
        var visible_enemy := false
        if _target!=null:
            goal=_target.global_position
            var distance := player.global_position.distance_to(goal)
            visible_enemy=distance<340 and game.has_line_of_sight(player.global_position,goal)
            aim=player.global_position.direction_to(goal+_target.velocity*(distance/650.0))
        else: goal=game._scaled_cell_world(Level3StoreData.EXIT_CELL if game.order_collected else Level3StoreData.ORDER_CELL)
        # Pick up a reserve before engaging ten moving guards; twelve initial
        # rounds leave no margin for ordinary misses at a different render rate.
        # Both this preparation and any later refill walk to a real Area2D.
        if (player.ammo==0 or (_shots[0]==0 and player.ammo<=12)) and player.current_weapon!=&"bat":
            var nearest: Level3Pickup
            var best := INF
            for pickup in game.pickups_root.get_children():
                if pickup.kind!=&"ammo" or pickup.consumed: continue
                var route := game.navigation.path(player.global_position,pickup.global_position)
                if route.is_empty(): continue
                var distance := float(route.size())
                if distance<best: nearest=pickup;best=distance
            if nearest!=null:
                goal=nearest.global_position
                visible_enemy=false
            else: _fail("route exhausted its ammunition");return
        if player.health<=50:
            var kit: Level3Pickup
            var best_kit := INF
            for pickup in game.pickups_root.get_children():
                if pickup.kind!=&"medkit": continue
                var route := game.navigation.path(player.global_position,pickup.global_position)
                if not route.is_empty() and route.size()<best_kit:
                    kit=pickup;best_kit=route.size()
            if kit!=null: goal=kit.global_position
        var movement := _walk(goal)
        if visible_enemy and _target.global_position.distance_to(player.global_position)<230 and player.health>50:
            movement=Vector2.ZERO
            if _target._windup>0 or (not _target.ranged and _target.global_position.distance_to(player.global_position)<130):
                var strafe := aim.orthogonal()
                if not game.is_body_path_clear(player.global_position,player.global_position+strafe*22): strafe=-strafe
                if game.is_body_path_clear(player.global_position,player.global_position+strafe*22): movement=strafe*0.8
        _move(movement);_aim(aim)
        # Touch drags update the HUD immediately, but the production director
        # copies aim to the player on its render tick. At30Hz two physics ticks
        # can run before that copy; don't fire using the previous rendered aim.
        var aim_committed := player.get_aim_direction().dot(aim)>.9998
        if visible_enemy and aim_committed and _next_shot<=0 and not _firing:
            _touch(73,game.fire_button.get_global_rect().get_center(),true)
            _firing=true;_fire_release=3;_next_shot=35
        if game._find_nearest_closed_door()!=null: _action()
        if _target==null and player.global_position.distance_to(goal)<32: _action()
        if frame%600==0: print("LEVEL 3 ROUTE: ",frame/60," s guards=",game._enemies_alive," hp=",player.health," ammo=",player.ammo," position=",player.global_position," target=",_target.name if _target!=null else "order/exit")
        await physics_frame
    _fail("route exceeded its 366-second simulation limit")

func _wait_for_scene_ready(path: String, timeout_msec: int = 30000) -> bool:
    var flow := root.get_node("SceneFlow")
    var deadline := Time.get_ticks_msec()+timeout_msec
    while Time.get_ticks_msec()<deadline:
        var loader: Variant=flow.get("loading_screen")
        if is_instance_valid(loader) and bool(loader.get("failed")):
            _fail("loading failure while waiting for "+path)
            return false
        if current_scene!=null and current_scene.scene_file_path==path and not bool(flow.get("_transitioning")) and bool(flow.call("_scene_ready",current_scene)):
            return true
        await _transition_frame()
    _fail("timed out waiting for ready scene "+path)
    return false

func _finish_campaign_route(frame: int) -> void:
    if not await _wait_for_scene_ready("res://scenes/ending_cutscene.tscn"):return
    if not root.get_node("GameState").is_completed(&"level3") or current_scene.scene_file_path!="res://scenes/ending_cutscene.tscn":
        _fail("automatic boarding did not reach the nightmare ending")
        return
    if not _story_phases.has(&"boarding"): _fail("left without automatic car boarding");return
    var ending: Node=current_scene
    if not bool(ending.get("ready_for_playback")) or not ending.has_method("skip_to_credits") or not ending.has_method("finish_to_menu"):
        _fail("ending did not become ready with credits controls");return
    ending.call("skip_to_credits")
    var credits: Control=ending.get("_credits")
    if credits==null or not credits.visible:_fail("ending skip bypassed credits");return
    ending.call("finish_to_menu")
    if not await _wait_for_scene_ready("res://menu.tscn"):return
    print("LEVEL 3 PLAYTHROUGH: PASS — street/reception/kitchen portrait dialogue, real van drift and ten physical deployments, window/flashbang, live assault, shocked employee, pizza and automatic240 boarding into nightmare ending, credits and menu; ",_shots[0]," shots; ",_rooms.size()," rooms; ",float(frame)/60," simulation seconds")
    var menu: Node=current_scene;current_scene=null;menu.queue_free()
    await process_frame;await process_frame
    await Teardown.drain_audio(self)
    quit(0)

func _transition_frame() -> void:
    await process_frame
    if DisplayServer.get_name()!="headless":
        call_deferred("_force_transition_draw")
        await RenderingServer.frame_post_draw

func _force_transition_draw() -> void:
    RenderingServer.force_draw(true)

func _capture_native_state() -> void:
    if _snapshots_dir.is_empty(): return
    var key := String(game.mission.phase)
    if game.dialogue.is_active():
        if not game.dialogue._fully_revealed: return
        key += "-line-%02d" % game.dialogue._index
    elif game.mission.phase == &"arrival":
        if game.mission.clock < 1.5: return
    elif game.mission.phase == &"deployment":
        if game.mission.deployment_count < 10: return
    elif game.mission.phase == &"breach":
        if game.mission.clock < 1.0: return
    elif game.mission.phase == &"boarding":
        if game.mission.clock < .8: return
    if _native_captures.has(key): return
    _native_captures[key] = true
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(_snapshots_dir.path_join(key + ".png"))
