extends SceneTree
# Input-driven integration run: no actor teleports, progress signals, health,
# ammo or door overrides. Every pickup/shot/boarding goes through game physics.
const Data = preload("res://scripts/level_data.gd")
const Combat = preload("res://scripts/combat_query.gd")
const ROUTE := ["Acorn01","Acorn02","Key01","Door01","Acorn03","Key02","Door02","Acorn04","Key03","Acorn05","Door03","Acorn06","ExitCar"]
const GATE_APPROACH := [Vector2i(12,19),Vector2i(23,8),Vector2i(36,17)]
var game: Node
var player: Node3D
var camera: Camera3D
var targets: Dictionary = {}
var astar := AStarGrid2D.new()
var goal_index := 0
var step_frames := 0
var shots := 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    root.get_node("GameState").sfx_muted = true
    game = load("res://game.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    for i in range(8): await physics_frame
    player = game.get_node("Player")
    camera = player.get_node("Camera3D")
    for id in ROUTE:
        targets[id] = game.get_node_or_null(id)
        if id.begins_with("Door"):
            targets[id] = game.get_node("Level1Layout/Doors/"+id)
    astar.region = Rect2i(0,0,Data.MAP_WIDTH,Data.MAP_HEIGHT)
    astar.cell_size = Vector2.ONE*Data.CELL_SIZE
    astar.offset = Data.MAP_WORLD_ORIGIN
    astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    astar.update()
    for y in range(Data.MAP_HEIGHT):
        for x in range(Data.MAP_WIDTH):
            astar.set_point_solid(Vector2i(x,y),Data.CANONICAL_MAP[y][x]=="#")
    for frame in range(18000):
        await physics_frame
        if current_scene != game:
            _release()
            if current_scene == null: continue
            if current_scene.scene_file_path != "res://scenes/level2.tscn":
                _fail("Unexpected destination: "+current_scene.scene_file_path)
                return
            print("PLAYTHROUGH: Level 2 reached through actual car trigger; simulation=%.1fs shots=%d" % [float(frame)/60.0,shots])
            current_scene.queue_free()
            for i in range(4): await process_frame
            root.get_node("AudioManager").shutdown()
            OS.delay_msec(40)
            print("LEVEL1 PLAYTHROUGH: PASS")
            quit(0)
            return
        if player.get_hp()<=0:
            _fail("Player defeated at %s; shots=%d" % [ROUTE[goal_index],shots])
            return
        step_frames += 1
        if step_frames>3600:
            _fail("Route stalled at %s; pos=%s" % [ROUTE[goal_index],player.position])
            return
        var id: String = ROUTE[goal_index]
        var target: Node3D = targets[id] if is_instance_valid(targets[id]) else null
        var reached := target == null
        if id.begins_with("Door"): reached = target.is_open
        if reached:
            print("PLAYTHROUGH: ",id," collected/opened; hp=",player.get_hp()," ammo=",player.ammo)
            goal_index += 1
            step_frames = 0
            continue
        if game.mission_complete:
            _release()
            continue
        for i in range(Data.DOOR_CELLS.size()):
            var door: Node = targets[Data.DOOR_NAMES[i]]
            astar.set_point_solid(Data.DOOR_CELLS[i],not door.is_open)
        var goal: Vector3 = target.global_position
        if id.begins_with("Door"):
            goal = Data.cell_center_world(GATE_APPROACH[int(id.right(2))-1])
        var from := Data.world_to_cell(player.position.x,player.position.z)
        var to := Data.world_to_cell(goal.x,goal.z)
        var path := astar.get_point_path(from,to)
        if path.is_empty():
            _fail("Unreachable live target %s at %s" % [id,to])
            return
        var waypoint := Vector3(goal.x,player.position.y,goal.z)
        if path.size()>1:
            waypoint = Vector3(path[1].x,player.position.y,path[1].y)
            # Finish the current cell at its centre before turning a tight
            # corner; a body has radius, unlike an AStar point.
            var first := Vector3(path[0].x,player.position.y,path[0].y)
            var segment := waypoint-first
            var sideways := (player.position-first)-segment.normalized()*(player.position-first).dot(segment.normalized())
            if sideways.length()>0.18: waypoint = first
        var direction := player.position.direction_to(waypoint)
        var aim := waypoint+Vector3.UP*0.6
        var nearest := 18.0
        for enemy in get_nodes_in_group("level1_enemy"):
            if enemy.defeated: continue
            var distance: float = enemy.global_position.distance_to(player.global_position)
            if distance >= nearest: continue
            var q := PhysicsRayQueryParameters3D.create(camera.global_position,enemy.global_position+Vector3.UP*0.20,1)
            if not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty(): continue
            nearest = distance
            aim = enemy.global_position+Vector3.UP*0.20
        var delta := aim-camera.global_position
        var wanted_yaw := atan2(-delta.x,-delta.z)
        var wanted_pitch := atan2(delta.y,Vector2(delta.x,delta.z).length())
        var motion: Vector2 = Vector2(-wrapf(wanted_yaw-player.rotation.y,-PI,PI),camera.rotation.x-wanted_pitch)/player.MOUSE_SENSITIVITY
        player.handle_mouse_motion(motion)
        if nearest<18.0:
            var hit := Combat.raycast(player.get_world_3d(),camera)
            var collider: Node = hit.get("collider")
            if collider and collider.get_parent().is_in_group("level1_enemy") and player.fire_cooldown<=0:
                player.request_fire()
                shots += 1
        var local := player.global_basis.inverse()*direction
        _axis("l1_move_left",-local.x)
        _axis("l1_move_right",local.x)
        _axis("l1_move_forward",-local.z)
        _axis("l1_move_backward",local.z)
    _fail("Playthrough timed out")

func _axis(action: StringName, strength: float) -> void:
    if strength>0.01: Input.action_press(action,minf(strength,1.0))
    else: Input.action_release(action)

func _release() -> void:
    for action in ["l1_move_left","l1_move_right","l1_move_forward","l1_move_backward"]:
        Input.action_release(action)

func _fail(reason: String) -> void:
    _release()
    push_error("LEVEL1 PLAYTHROUGH: "+reason)
    quit(1)
