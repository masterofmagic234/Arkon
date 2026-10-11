extends SceneTree
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
func _init() -> void: call_deferred("_run")
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
    _touch(71,game.move_joystick.get_global_rect().get_center(),true)
    _touch(72,game.aim_joystick.get_global_rect().get_center()+Vector2(45,0),true)
    for frame in range(12000):
        # SceneFlow leaves the physics flush before replacing the scene; the
        # current scene is legitimately null for one frame during that handoff.
        if current_scene==null:
            await process_frame
            continue
        if not is_instance_valid(game) or current_scene.scene_file_path=="res://menu.tscn":
            if root.get_node("GameState").is_completed(&"level3") and current_scene.scene_file_path=="res://menu.tscn":
                print("LEVEL 3 PLAYTHROUGH: PASS — all 10 live guards, order, return and actual menu transition; ",_shots[0]," shots; ",_rooms.size()," rooms; ",float(frame)/60," simulation seconds")
                current_scene.queue_free()
                await process_frame;await process_frame
                root.get_node("AudioManager").shutdown()
                OS.delay_msec(80)
                quit(0)
            else: _fail("invalid final campaign transition")
            return
        if game._player_dead: _fail("player died on the input-driven route");return
        if game._level_complete_started:
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
        # Supplies are reached physically and use the real Area2D collection.
        if player.ammo==0 and player.current_weapon!=&"bat":
            var nearest: Level3Pickup
            var best := INF
            for pickup in game.pickups_root.get_children():
                if pickup.kind!=&"ammo": continue
                var distance := player.global_position.distance_to(pickup.global_position)
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
        if visible_enemy and _next_shot<=0 and not _firing:
            _touch(73,game.fire_button.get_global_rect().get_center(),true)
            _firing=true;_fire_release=3;_next_shot=35
        if game._find_nearest_closed_door()!=null: _action()
        if _target==null and player.global_position.distance_to(goal)<32: _action()
        if frame%600==0: print("LEVEL 3 ROUTE: ",frame/60," s guards=",game._enemies_alive," hp=",player.health," ammo=",player.ammo," position=",player.global_position," target=",_target.name if _target!=null else "order/exit")
        await physics_frame
    _fail("route exceeded its 200-second simulation limit")
