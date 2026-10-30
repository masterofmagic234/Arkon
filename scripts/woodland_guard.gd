extends CharacterBody3D
# The woodland encounter owns its own patrol/charge state machine. The shared
# player still shoots the real Hitbox3DComponent, so visual changes never turn
# an enemy into a target that cannot be hit.
const Health = preload("res://scripts/components/health_component.gd")
const Hitbox = preload("res://scripts/components/hitbox_3d_component.gd")
const Visual = preload("res://scripts/squirrel_3d_visual.gd")
const Queries = preload("res://scripts/squirrel_queries.gd")
const StepMotion = preload("res://scripts/grounded_step_motion.gd")

var director: Node
var is_tank := false
var final_boss := false
var _restoring := false
var stealth_patrol := false
var hearing_distance := 18.0
var _attack_count := 0
var _shock_hit := false
var patrol_points: Array[Vector3] = []
var spawn_position := Vector3.ZERO
var defeated := false
var state := "patrol"
var hp: int:
    get: return health.current_health if health != null else 0
var max_hp: int:
    get: return health.max_health if health != null else ((14 if final_boss else 8) if is_tank else 3)
var health: HealthComponent
var hitbox: Hitbox3DComponent
var visual: Squirrel3DVisual
var body_shape: CollisionShape3D
var warning_ring: MeshInstance3D
var charge_line: MeshInstance3D
var _warning_material: StandardMaterial3D
var _line_material: StandardMaterial3D
var _timer := 0.0
var _clock := 0.0
var _patrol_index := 0
var _last_seen := Vector3.ZERO
var _memory := 0.0
var _charge_direction := Vector3.FORWARD
var _charge_hit := false
var _blocked_message_timer := 0.0
var _defeat_clock := 0.0
var _stuck_clock := 0.0
var _avoid_sign := 1.0
var encounter_id := -1
var tactical_role := "skirmisher"
var encounter_group := ""
var encounter_active := true
var combat_anchor := Vector3.ZERO
var combat_radius := 0.0
var ranged_enabled := true
var navigation: Node
var _route := PackedVector3Array()
var _route_index := 0
var _route_goal := Vector3.INF
var _route_destination := Vector3.INF
var _tactical_fallbacks := 0
var _route_revision := -1
var _replan := 0.0
var _sense_timer := 0.0
var _sees_player := false
var _ranged_cooldown := 1.1
var _attack_target := Vector3.ZERO
var _search_origin := Vector3.ZERO
var _search_step := 0
var _search_clock := 0.0
var _returning := false
var _animation_elapsed := 0.0
var _decision_count := 0
var _shots_fired := 0
var _fire_released := false
var _melee_swings := 0
var _melee_applied := false
var _route_replans := 0
var _unsticks := 0
var _active_seconds := 0.0
var _distance_walked := 0.0
var _foot_distance := 0.0
var _attack_duration := .65
var _voice_ready: Dictionary={}
var _chatter_cooldown := 10.0
var _recovery_hits := 0
var _second_phase_announced := false
var _relocate_after_shot := false
var _deploying := false
var _deployment_goal := Vector3.ZERO
var _charge_impact_normal := Vector3.ZERO
var _recovery_away := Vector3.ZERO
var _recovery_backoff_remaining := 0.0
var _charge_wall_stops := 0
var _charge_backoff_metres := 0.0
const GUARDIAN_DOOR_LINE := -25.15
const GUARDIAN_HOME := Vector3(0, 7, -33)
var _arena_returns := 0

func _has_guardian_arena() -> bool:
    return final_boss and is_tank and director.get("is_botanical") == true

func _guardian_target(point: Vector3) -> Vector3:
    # The conservatory shell handles its sides. Its open doorway must not let
    # the guardian follow a retreat onto the staircase and strand its wide
    # navigation capsule below the arena floor. The player remains free to leave.
    if _has_guardian_arena() and point.z > GUARDIAN_DOOR_LINE:
        point = Vector3(clampf(point.x, -1.4, 1.4), GUARDIAN_HOME.y, GUARDIAN_DOOR_LINE - 1.3)
    return point

func _ready() -> void:
    add_to_group("level1_enemy")
    add_to_group("woodland_guard")
    spawn_position = global_position
    # Actor bodies live on their own layer. The hitscan mask includes layer2;
    # only the larger hitbox uses it, never the opaque physics capsule.
    collision_layer = 8
    collision_mask = 1 | 8 | 4
    motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
    floor_snap_length = .5
    floor_max_angle = deg_to_rad(52)
    if director.get("guard_navigation") != null: navigation = director.guard_navigation
    body_shape = CollisionShape3D.new()
    body_shape.name = "CollisionShape3D"
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.58 if is_tank else 0.36
    capsule.height = 2.05 if is_tank else 1.45
    body_shape.shape = capsule
    body_shape.position.y = capsule.height * 0.5
    add_child(body_shape)
    health = Health.new()
    health.name = "Health"
    health.max_health = (14 if final_boss else 8) if is_tank else 3
    health.invulnerability_duration = 0.14
    add_child(health)
    health.died.connect(_on_defeated)
    hitbox = Hitbox.new()
    hitbox.name = "Hitbox"
    var hit_shape := CollisionShape3D.new()
    hit_shape.name = "CollisionShape3D"
    var box := BoxShape3D.new()
    box.size = Vector3(1.55, 2.45, 1.45) if is_tank else Vector3(1.1, 1.85, 1.0)
    hit_shape.shape = box
    hit_shape.position.y = box.size.y * 0.5
    hitbox.add_child(hit_shape)
    add_child(hitbox)
    visual = Visual.new()
    visual.name = "Squirrel3DVisual"
    if is_tank:
        visual.model_path = "res://assets/level1/characters/tank_squirrel.glb"
    visual.target_height = 2.4 if is_tank else 1.6
    add_child(visual)
    visual.setup()
    visual.apply_active()
    _make_telegraph()
    if patrol_points.is_empty():
        patrol_points.assign([spawn_position + Vector3(-2,0,0), spawn_position + Vector3(2,0,0)])
    _last_seen = spawn_position
    state = "dormant" if is_tank else "patrol"

func activate_encounter(point: Vector3) -> void:
    if defeated or is_tank:return
    encounter_active=true
    if state=="waiting":state="patrol"
    _sense_timer=0
    _ranged_cooldown=.2+float(posmod(encounter_id,4))*.23
    _chatter_cooldown=8.0+float(posmod(encounter_id,5))*1.6
    if _warning_material!=null:
        match tactical_role:
            "assault":_warning_material.albedo_color=Color("ed8865")
            "flanker":_warning_material.albedo_color=Color("8aceb1")
            "suppressor":_warning_material.albedo_color=Color("94bfdc")
            _: _warning_material.albedo_color=Color("edb06c")
    # Far return-route guards hold their visible post until actual contact.
    if _flat_distance(global_position,point)<34:
        _last_seen=point;_memory=9.0

func _voice(kind: StringName, cooldown:=1.1) -> void:
    # A warning must not suppress the later effort or accepted-hit vocal.
    # The spatial mixer also caps nearby voices and per-kind repetitions.
    if _clock<float(_voice_ready.get(kind,-INF)):return
    _voice_ready[kind]=_clock+cooldown
    SignalBus.emit_audio_event(kind,global_position)

func deploy_to(point: Vector3) -> void:
    # Reinforcements traverse authored service paths into their interception
    # lane. This changes their orders, never their world transform.
    _deployment_goal=point;_deploying=true;_memory=0;_replan=0
    patrol_points.assign([point,point+Vector3(2,0,1)])
    _patrol_index=0

func _make_telegraph() -> void:
    warning_ring = MeshInstance3D.new()
    warning_ring.name = "AttackTell"
    var ring := TorusMesh.new()
    ring.inner_radius = 1.15 if is_tank else 0.68
    ring.outer_radius = 1.25 if is_tank else 0.75
    ring.rings = 24
    ring.ring_segments = 5
    warning_ring.mesh = ring
    warning_ring.position.y = 0.035
    _warning_material = StandardMaterial3D.new()
    _warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _warning_material.albedo_color = Color("edb06c")
    warning_ring.material_override = _warning_material
    warning_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    warning_ring.visible = false
    add_child(warning_ring)
    charge_line = MeshInstance3D.new()
    charge_line.name = "ChargeDirection"
    var line := BoxMesh.new()
    line.size = Vector3(0.14, 0.022, 9.5)
    charge_line.mesh = line
    _line_material = StandardMaterial3D.new()
    _line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _line_material.albedo_color = Color("edb06c")
    charge_line.material_override = _line_material
    charge_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    charge_line.visible = false
    add_child(charge_line)

func _physics_process(delta: float) -> void:
    if get_node("/root/SceneFlow").is_loading_gameplay(): return
    _clock += delta
    _timer = maxf(0.0, _timer - delta)
    _memory = maxf(0.0, _memory - delta)
    _replan = maxf(0.0, _replan-delta)
    _ranged_cooldown = maxf(0.0, _ranged_cooldown-delta)
    _blocked_message_timer = maxf(0.0, _blocked_message_timer - delta)
    _chatter_cooldown=maxf(0,_chatter_cooldown-delta)
    if defeated:
        _defeat_clock += delta
        _animate(delta)
        if visual != null and visual.death_settled():
            # Static rest pose is held by the skinned mesh; no clock, pose
            # evaluation, sensing or gameplay collision remains on a corpse.
            visual.visible = true
            set_physics_process(false)
        return
    var player := _player()
    if player == null or not player.input_enabled or player.get_hp() <= 0:
        velocity = Vector3.ZERO
        _animate(delta)
        return
    if not encounter_active:
        # A chapter trigger gives an order; it does not switch a visible animal
        # on. Reserves patrol their own post and react to nearby real contact.
        _sense_timer-=delta
        if _sense_timer<=0:
            _decision_count+=1
            _sense_timer=.28
            if absf(global_position.y-player.global_position.y)<2.8 and _can_see(player,14.0):
                _wake_encounter(player.global_position)
        if not encounter_active:
            var before_patrol:=global_position
            _reserve_patrol(delta)
            _record_motion(before_patrol,player)
            _animate(delta)
            return
    _sense_timer -= delta
    if _sense_timer <= 0:
        _decision_count += 1
        var distance := _flat_distance(global_position,player.global_position)
        _sense_timer = .16 if distance < 36 else .6
        # The player's cone gun reaches30m. A visible garden defender must
        # react before three free shots can kill it at the old18m boundary.
        _sees_player = _can_see(player, 34.0 if not is_tank else 25.0)
        if _sees_player:
            if _memory <= 0 and not is_tank:
                _voice(&"squirrel_warn",1.8)
                if director.has_method("guard_alerted"): director.guard_alerted(self,player.global_position)
            _last_seen=player.global_position
            _memory=10.0
    if not is_tank and _memory>0 and _chatter_cooldown<=0:
        _voice(&"squirrel_chatter",2.0)
        _chatter_cooldown=9.0+float(posmod(encounter_id,5))*1.4
    var before := global_position
    if is_tank: _update_tank(delta, player)
    else: _update_scout(delta, player)
    # Idle/windup actors still settle onto the real physical floor. No analytic
    # height teleport is allowed to carry a squirrel up a retaining wall.
    if velocity.length_squared() < .001 or state in ["aim","fire","melee","recover","windup","stomp_windup","shockwave"]:
        _settle_floor(delta)
    _record_motion(before,player)
    if _memory > 0: _active_seconds += delta
    _animate(delta)

func _wake_encounter(point: Vector3) -> void:
    if defeated or encounter_active or is_tank:return
    if director.get("encounter_director")!=null:
        director.encounter_director.trigger(encounter_group)
    else:activate_encounter(point)

func _reserve_patrol(delta: float) -> void:
    state="patrol"
    var target: Vector3=patrol_points[_patrol_index]
    if _flat_distance(global_position,target)<.65:
        _patrol_index=(_patrol_index+1)%patrol_points.size()
        target=patrol_points[_patrol_index]
    _walk_towards(target,1.15,delta)
    if velocity.length_squared()<.001:_settle_floor(delta)

func _record_motion(before: Vector3, player: Level1Player) -> void:
    _distance_walked += global_position.distance_to(before)
    var grounded_travel:=Vector2(global_position.x-before.x,global_position.z-before.z).length()
    if is_on_floor() and grounded_travel>.002:
        _foot_distance+=grounded_travel
        var stride:=2.5 if state=="charge" else (1.1 if is_tank else .7)
        if _foot_distance>=stride:
            _foot_distance-=stride
            if global_position.distance_to(player.global_position)<24:
                SignalBus.emit_audio_event(&"enemy_footstep",global_position)

func _settle_floor(delta: float) -> void:
    velocity.x=0;velocity.z=0
    velocity.y=-.7 if is_on_floor() else velocity.y-18.0*delta
    move_and_slide()

func _player() -> Level1Player:
    if not is_instance_valid(director): return null
    return director.player as Level1Player

func _flat_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x-b.x, a.z-b.z).length()

func _can_see(player: Level1Player, distance_limit: float) -> bool:
    if _flat_distance(global_position, player.global_position) > distance_limit: return false
    if stealth_patrol and state not in ["chase","flank","melee"] and velocity.length_squared()>.1:
        var towards=player.global_position-global_position;towards.y=0
        if towards.length()>2 and velocity.normalized().dot(towards.normalized())<.2:return false
    return Queries.visible_from(global_position + Vector3.UP * 1.1, player.global_position + Vector3.UP * 0.3, get_world_3d(), 1)

func _attack_available() -> bool:
    return not director.has_method("guard_attack_allowed") or director.guard_attack_allowed(self)

func _update_scout(delta: float, player: Level1Player) -> void:
    if _deploying:
        if _sees_player or _flat_distance(global_position,_deployment_goal)<2:
            _deploying=false
        else:
            state="investigate"
            _walk_towards(_deployment_goal,4.0,delta)
            return
    if state == "melee":
        velocity=Vector3.ZERO
        if not _melee_applied and _timer<=_attack_duration*(1.0-.60):
            _melee_applied=true;_melee_swings+=1
            _voice(&"squirrel_attack",.7)
            if _flat_distance(global_position,player.global_position)<2.15 and _can_see(player,2.2):player.take_damage(12,self)
            warning_ring.visible=false
        if _timer<=0:state="recover";_timer=.38
        return
    if state == "aim":
        velocity=Vector3.ZERO
        if _timer<=0:
            state="fire";_timer=.52;_attack_duration=.52;_fire_released=false;warning_ring.visible=false
        return
    if state == "fire":
        velocity=Vector3.ZERO
        if not _fire_released and _timer<=.52*(1.0-.42):
            _fire_released=true;_fire_cone()
        if _timer<=0:
            state="recover";_timer=.28 if tactical_role=="suppressor" else .45
            _relocate_after_shot=tactical_role in ["thrower","suppressor"]
        return
    if state == "recover":
        velocity=Vector3.ZERO
        if _timer<=0: state="chase" if _memory>0 else "search"
        return
    var distance := _flat_distance(global_position,player.global_position)
    if _sees_player:
        if distance<1.9 and _attack_available():
            _attack_duration=.72 if tactical_role=="assault" else .92
            state="melee";_timer=_attack_duration;_melee_applied=false;velocity=Vector3.ZERO;warning_ring.visible=true
            _voice(&"squirrel_warn",.6)
            return
        var range_min:=5.0
        var range_max:=29.0
        var aim_time:=.85
        var reload_time:=2.6
        match tactical_role:
            "assault":range_max=0.0
            "flanker","reserve":range_max=17.0;range_min=7.0;aim_time=.8;reload_time=3.8
            "suppressor","lookout":range_min=8.0;aim_time=.66;reload_time=1.65
        if ranged_enabled and distance>range_min and distance<range_max and _ranged_cooldown<=0 and _attack_available():
            state="aim";_timer=aim_time;_attack_duration=aim_time;velocity=Vector3.ZERO
            # Aim is fixed during the visible tell: a moving player can dodge.
            _attack_target=player.global_position+Vector3.UP*.35
            warning_ring.visible=true;_ranged_cooldown=reload_time
            _voice(&"squirrel_warn",.7)
            return
        var target := player.global_position
        state="chase"
        var speed:=3.2
        var towards:=global_position.direction_to(player.global_position);towards.y=0
        var side:=towards.cross(Vector3.UP)*(1 if encounter_id%2==0 else -1)
        if tactical_role=="assault":
            speed=4.2
        elif tactical_role in ["flanker","reserve"] and distance>9:
            # The path graph earns a wide side lane, never a sideways teleport.
            target+=side*5.5
            speed=3.8
            state="flank"
        elif tactical_role in ["thrower","rifleman","suppressor","lookout"]:
            var preferred:=19.0 if tactical_role in ["suppressor","lookout"] else 14.0
            if distance<preferred-3:
                target=global_position-towards*4+side*2
                speed=2.6;state="flank"
            elif distance<preferred+4:
                if _relocate_after_shot:
                    target=global_position+side*2.4
                    speed=2.3;state="flank"
                    if _ranged_cooldown<.7:_relocate_after_shot=false
                else:
                    velocity=Vector3.ZERO
                    return
        elif tactical_role in ["flanker","reserve"]:speed=3.8
        _walk_towards(target,speed,delta)
        return
    if _memory>0 and state!="search":
        state="investigate"
        if _flat_distance(global_position,_last_seen)>1.6:
            _walk_towards(_last_seen,2.1,delta)
        else:
            _start_search()
            _search(delta)
        return
    if state in ["chase","flank","investigate"]: _start_search()
    if state=="search":
        _search(delta)
        return
    state="patrol"
    var target: Vector3=patrol_points[_patrol_index]
    if _flat_distance(global_position,target)<.8:
        _patrol_index=(_patrol_index+1)%patrol_points.size();target=patrol_points[_patrol_index]
    _walk_towards(target,1.25,delta)

func _start_search() -> void:
    if state=="search":return
    state="search";_search_origin=_last_seen;_search_step=0;_search_clock=4.2
    _route_goal=Vector3.INF

func _search(delta: float) -> void:
    _search_clock-=delta
    if _search_clock<=0:
        state="patrol";_memory=0;return
    var angle:=float(_search_step)*TAU/4+encounter_id*.4
    var target:=_search_origin+Vector3(cos(angle),0,sin(angle))*2.2
    if _flat_distance(global_position,target)<.8:_search_step+=1
    _walk_towards(target,1.45,delta)

func _fire_cone() -> void:
    var facing:=global_position.direction_to(_attack_target);facing.y=0
    if facing.length_squared()<.01:facing=Vector3.FORWARD
    var origin:=global_position+Vector3.UP*1.05+facing.normalized()*.46
    if visual.has_method("throw_origin"):origin=visual.call("throw_origin")
    var projectile_visual: Node3D=visual.call("make_thrown_visual") if visual.has_method("make_thrown_visual") else null
    var cone=preload("res://scripts/woodland_cone_projectile.gd").new()
    director.add_child(cone);cone.setup(origin,_attack_target,self,projectile_visual)
    cone.remaining=34.0
    cone.speed=16.0 if tactical_role=="suppressor" else 14.0
    _shots_fired+=1
    SignalBus.emit_audio_event(&"enemy_shoot",origin)

func _update_tank(delta: float, player: Level1Player) -> void:
    if final_boss and hp<=7 and not _second_phase_announced:
        _second_phase_announced=true
        SignalBus.show_message.emit("Страж зовёт на помощь земле: рывок чередуется с круговой волной!",3)
        _voice(&"guardian_rally",1.2)
    if state=="stomp_windup":
        velocity=Vector3.ZERO;warning_ring.scale=Vector3.ONE*6.5
        if _timer<=0:
            state="shockwave";_timer=.65;_shock_hit=false
            _voice(&"guardian_attack",.6)
        return
    if state=="shockwave":
        var radius=1.0+(1.0-_timer/.65)*7.0
        warning_ring.scale=Vector3.ONE*radius/1.25
        if not _shock_hit and absf(_flat_distance(global_position,player.global_position)-radius)<.9 and absf(global_position.y-player.global_position.y)<2.5 and player.dash_time<=0 and _can_see(player,9):
            player.take_damage(20,self);_shock_hit=true
        if _timer<=0:_begin_recovery()
        return
    if state == "dormant":
        velocity = Vector3.ZERO
        if str(director.stage) == "cache":
            state = "stalk";_last_seen=player.global_position;_memory=12
            _timer = 0.6
        elif director.get("is_botanical")==true:
            var target: Vector3=patrol_points[_patrol_index]
            if _flat_distance(global_position,target)<.8:
                _patrol_index=(_patrol_index+1)%patrol_points.size();target=patrol_points[_patrol_index]
            _walk_towards(target,.65,delta)
        return
    if state == "windup":
        velocity = Vector3.ZERO
        var pulse := 1.0 + sin(_clock * 19.0) * 0.08
        warning_ring.scale = Vector3(pulse,1,pulse)
        if _timer <= 0.0:
            state = "charge"
            _timer = .95
            _attack_duration = .95
            _charge_hit = false
            _charge_impact_normal=Vector3.ZERO
            charge_line.visible = false
            _warning_material.albedo_color = Color("e58163")
            _voice(&"guardian_attack",.6)
            if visual != null:visual.face_locked_direction(_charge_direction)
        return
    if state == "charge":
        var vertical:=velocity.y
        var motion:=_charge_direction*10.0*delta
        # Closed doors already supply a real collider. The logical boundary
        # protects only their open passage, where a player may retreat freely.
        var gate_open:bool = _has_guardian_arena() and is_instance_valid(director.get("water_flow")) and director.water_flow.gate_open>=.98
        var doorway_stop:bool = gate_open and _charge_direction.z > 0 and global_position.z + motion.z > GUARDIAN_DOOR_LINE
        if doorway_stop:
            motion *= clampf((GUARDIAN_DOOR_LINE-global_position.z)/maxf(.0001,motion.z),0,1)
        var contact:=_charge_wall_sweep(motion)
        if contact.blocked:
            _charge_impact_normal=contact.normal
            # Keep a real clearance for the navigation capsule. A body stopped
            # at its .001m safe margin is physically legal but inside the route
            # query's wider margin, so it could never plan away from the wall.
            motion=_charge_direction*maxf(0,float(contact.distance)-.04)
        velocity = motion/maxf(delta,.0001)
        velocity.y=-.7 if is_on_floor() else vertical-18.0*delta
        # A charge never stair-steps onto a window sill. Its complete body is
        # swept before normal collision motion, including at oblique pillars.
        move_and_slide()
        var vertical_contact:=global_position.y<player.global_position.y+.9 and global_position.y+2.05>player.global_position.y-.6
        if not _charge_hit and vertical_contact and _flat_distance(global_position,player.global_position)<1.8 and _can_see(player,2.1):
            player.take_damage(24, self)
            _charge_hit = true
        var blocked:=bool(contact.blocked) or _hit_charge_obstacle()
        if _timer <= 0.0 or blocked or doorway_stop or global_position.distance_to(spawn_position) > 15.0:
            if blocked:_charge_wall_stops+=1
            _begin_recovery(_charge_impact_normal if blocked else Vector3.ZERO)
        return
    if state == "recover":
        velocity = Vector3.ZERO
        if _recovery_backoff_remaining>0:
            var before_backoff:=global_position
            _recovery_backoff_remaining=maxf(0,_recovery_backoff_remaining-delta)
            velocity=_recovery_away*1.6
            velocity.y=-.7 if is_on_floor() else -18.0*delta
            move_and_slide()
            _charge_backoff_metres+=_flat_distance(before_backoff,global_position)
        if _timer <= 0.0:
            warning_ring.visible = false
            state = "stalk"
            _timer = 0.75
        return
    # The guardian stays in its arena, but a column breaking LOS now makes
    # it seek a real route instead of freezing indefinitely behind the column.
    if _has_guardian_arena():
        if global_position.z>GUARDIAN_DOOR_LINE+.08:
            if not _returning:_arena_returns+=1
            _returning=true
    elif global_position.distance_to(spawn_position)>14:_returning=true
    if _returning:
        var home:=GUARDIAN_HOME if _has_guardian_arena() else spawn_position
        _walk_towards(home,2.0,delta)
        if _flat_distance(global_position,home)<2.0:
            _returning=false;_replan=0;_timer=.35
        # If an interrupted older fight left the body outside on a bad stair
        # attachment, ordinary floor-settling/backoff earns physical clearance.
        # It opens a real damage window instead of becoming immortal forever.
        elif _stuck_clock>.5:
            _begin_recovery(Vector3(home.x-global_position.x,0,home.z-global_position.z).normalized())
        return
    var distance := _flat_distance(global_position, player.global_position)
    var player_in_arena := not _has_guardian_arena() or player.global_position.z<GUARDIAN_DOOR_LINE+.45
    if _timer<=0 and player_in_arena and _can_see(player,20) and distance<13 and _attack_available():
        if final_boss and hp<=7 and _attack_count%2==1:
            _charge_direction=global_position.direction_to(player.global_position);_charge_direction.y=0;_charge_direction=_charge_direction.normalized()
            state="stomp_windup";_timer=1.35;_attack_duration=1.35;warning_ring.visible=true;charge_line.visible=false;_attack_count+=1
            _warning_material.albedo_color=Color("dfb561")
            SignalBus.show_message.emit("Удар по земле! Отойди от круга или проскочи рывком.",2)
            _voice(&"guardian_warn",.7)
        else:_start_charge(player.global_position)
    else:
        var target:=_guardian_target(player.global_position if _sees_player else _last_seen)
        if _memory<=0:
            target=patrol_points[_patrol_index]
            if _flat_distance(global_position,target)<.8:
                _patrol_index=(_patrol_index+1)%patrol_points.size();target=patrol_points[_patrol_index]
        _walk_towards(target,1.85 if _memory>0 else .85,delta)

func _start_charge(target: Vector3) -> void:
    _charge_direction = (target - global_position)
    _charge_direction.y = 0.0
    if _charge_direction.length_squared() < 0.01: _charge_direction = Vector3.FORWARD
    _charge_direction = _charge_direction.normalized()
    state = "windup"
    _attack_count+=1
    _timer = .95 if hp>7 else .8
    _attack_duration = _timer
    warning_ring.visible = true
    warning_ring.scale = Vector3.ONE
    _warning_material.albedo_color = Color("edb06c")
    charge_line.position = _charge_direction * 4.75 + Vector3.UP * 0.055
    charge_line.rotation.y = atan2(_charge_direction.x, _charge_direction.z)
    charge_line.visible = true
    _voice(&"guardian_warn",.6)
    if visual != null:
        visual.animate_squirrel(0,0,0,_charge_direction,0)

func _hit_charge_obstacle() -> bool:
    # A capsule standing on the physical floor can report its floor contact
    # during recovery. Only a horizontal blocker ends a horizontal charge.
    var normals:=Vector3.ZERO
    for i in range(get_slide_collision_count()):
        var normal := get_slide_collision(i).get_normal()
        if absf(normal.y) < 0.65:
            normals+=Vector3(normal.x,0,normal.z)
    if normals.length_squared()>.001:
        _charge_impact_normal=normals.normalized()
        return true
    return false

func _charge_wall_sweep(motion: Vector3) -> Dictionary:
    # A motion sweep may intentionally ignore a triangle already crossing the
    # initial capsule. Query that actual overlap first, above the floor margin,
    # so a thin/double-sided glass panel cannot be crossed from an invalid start.
    var overlap:=PhysicsShapeQueryParameters3D.new()
    overlap.shape=body_shape.shape
    overlap.transform=body_shape.global_transform
    overlap.transform.origin+=Vector3.UP*.06
    overlap.margin=.045
    overlap.collision_mask=collision_mask
    overlap.exclude=[get_rid()]
    var rest:=get_world_3d().direct_space_state.get_rest_info(overlap)
    if not rest.is_empty() and absf(rest.normal.y)<.65:
        var normal:Vector3=rest.normal;normal.y=0
        return {"blocked":true,"normal":normal.normalized(),"distance":0.0,"initial_overlap":true}
    var parameters:=PhysicsTestMotionParameters3D.new()
    parameters.from=global_transform
    # A floor recovery can otherwise consume the test before its horizontal
    # sweep. Lift the prediction above the floor margin; actual movement still
    # uses the full unlifted body and gravity immediately afterwards.
    parameters.from.origin+=Vector3.UP*.06
    parameters.motion=motion
    parameters.margin=.045
    parameters.max_collisions=8
    parameters.recovery_as_collision=true
    var result:=PhysicsTestMotionResult3D.new()
    if not PhysicsServer3D.body_test_motion(get_rid(),parameters,result):
        return {"blocked":false,"normal":Vector3.ZERO,"distance":motion.length()}
    var normal:=Vector3.ZERO
    for index in range(result.get_collision_count()):
        var candidate:=result.get_collision_normal(index)
        if absf(candidate.y)<.65:normal+=Vector3(candidate.x,0,candidate.z)
    return {"blocked":normal.length_squared()>.001,"normal":normal.normalized(),"distance":clampf(result.get_travel().dot(_charge_direction),0,motion.length())}

func _choose_recovery_direction(normal: Vector3) -> Vector3:
    # A corner can present two walls. Choose a short, physically clear outward
    # sweep with a supported endpoint, rather than repeatedly asking AStar to
    # start from a capsule whose wall clearance is invalid.
    var preferred:=normal.normalized()
    var best:=Vector3.ZERO
    var best_score:=-INF
    var candidates:Array[Vector3]=[preferred,-_charge_direction]
    for index in range(8):
        var angle:=TAU*float(index)/8.0
        candidates.append(Vector3(cos(angle),0,sin(angle)))
    for direction:Vector3 in candidates:
        if direction.length_squared()<.1:continue
        var parameters:=PhysicsTestMotionParameters3D.new()
        parameters.from=global_transform
        parameters.motion=direction*.52
        parameters.margin=safe_margin
        parameters.max_collisions=8
        var result:=PhysicsTestMotionResult3D.new()
        var blocked:=PhysicsServer3D.body_test_motion(get_rid(),parameters,result)
        var distance:=clampf(result.get_travel().dot(direction),0,.52) if blocked else .52
        if distance<.08:continue
        var score:=distance+direction.dot(preferred)*.12
        if is_instance_valid(navigation) and navigation.is_ready:
            var endpoint:Vector3=navigation.ground_goal(global_position+direction*distance)
            if not endpoint.is_finite() or absf(endpoint.y-global_position.y)>.24 or not navigation._open(endpoint,true):continue
        else:
            var ray:=PhysicsRayQueryParameters3D.create(global_position+direction*distance+Vector3.UP*.35,global_position+direction*distance-Vector3.UP*.3,1)
            ray.exclude=[get_rid()]
            var support:=get_world_3d().direct_space_state.intersect_ray(ray)
            if support.is_empty() or support.normal.y<cos(floor_max_angle) or absf(support.position.y-global_position.y)>.24:continue
            if str(support.collider.name)=="PondWaterVolume" or not bool(support.collider.get_meta("walkable_support",true)):continue
        if score>best_score:best_score=score;best=direction
    return best

func _begin_recovery(obstacle_normal:=Vector3.ZERO) -> void:
    velocity = Vector3.ZERO
    state = "recover"
    _recovery_backoff_remaining=.32 if obstacle_normal.length_squared()>.001 else 0.0
    _recovery_away=_choose_recovery_direction(obstacle_normal) if _recovery_backoff_remaining>0 else Vector3.ZERO
    if _recovery_away.length_squared()<.001:_recovery_backoff_remaining=0.0
    # Three well timed hits per opening require several readable attack cycles;
    # the guardian's14HP cannot disappear in a single ten-shot burst.
    _timer = 1.15 if final_boss else 1.8
    _attack_duration = _timer # The authored recovery spans this actual opening.
    _recovery_hits=0
    warning_ring.visible = true
    warning_ring.scale = Vector3.ONE
    _warning_material.albedo_color = Color("a4cda4")
    charge_line.visible = false
    SignalBus.show_message.emit("Страж выдохся — зелёное кольцо! Три точных попадания." if final_boss else "Танк выдохся. Сейчас можно стрелять!",_timer)

func _walk_towards(target: Vector3, speed: float, delta: float) -> void:
    # Gallery defenders keep their glass-wing position. Routes may use its
    # real open ends, but a retreat cannot tow the entire fight to the boss.
    if combat_radius>0:
        var offset:=target-combat_anchor;offset.y=0
        if offset.length()>combat_radius:
            var bounded:=combat_anchor+offset.normalized()*combat_radius
            target.x=bounded.x;target.z=bounded.z
    var destination:=target
    if is_instance_valid(navigation) and navigation.is_ready:
        if _replan<=0 or target.distance_to(_route_goal)>3 or _route_revision!=navigation.revision:
            _route_destination=target
            var flank_order := not is_tank and state=="flank" and tactical_role in ["flanker","reserve"]
            if flank_order:
                var projected: Vector3=navigation.ground_goal(target)
                if projected.is_finite():_route_destination=projected
            _route=navigation.path(global_position,_route_destination,is_tank)
            if _route.is_empty() and flank_order:
                _route=_reachable_flank_route(target)
            _route_index=0;_route_goal=target;_route_revision=navigation.revision
            _replan=.7+posmod(encounter_id,5)*.09;_route_replans+=1
            if _route.size()>1 and navigation.segment_clear(global_position,_route[1],is_tank):_route_index=1
        # A generous distance-only skip clips the inside of a wall corner.
        # Advance only when the next leg is physically traversable too.
        while _route_index<_route.size() and _flat_distance(global_position,_route[_route_index])<.4:
            if _route_index+1<_route.size() and not navigation.segment_clear(global_position,_route[_route_index+1],is_tank):break
            _route_index+=1
        if _route_index<_route.size():destination=_route[_route_index]
        else:destination=_route_destination
        if _route_index>=_route.size() and not navigation.segment_clear(global_position,destination,is_tank):
            velocity=Vector3.ZERO;_stuck_clock+=delta
            if _stuck_clock>.8:
                _replan=0;_stuck_clock=0;_unsticks+=1
                if state in ["patrol","dormant"]:_patrol_index=(_patrol_index+1)%patrol_points.size()
                elif state=="search":_search_step+=1
            return
    var direction:=destination-global_position;direction.y=0
    if direction.length_squared()<.0064:
        velocity=Vector3.ZERO
        return
    direction=direction.normalized()
    # The route already checks the body's complete swept volume. A low
    # horizontal eye ray sees the next stair riser as a wall and steers a
    # squirrel off an otherwise valid staircase. Physical body contacts and
    # bounded replanning handle blockers without that contradictory ray.
    var before:=global_position
    var vertical:=velocity.y
    velocity=direction*speed
    velocity.y=-.7 if is_on_floor() else vertical-18.0*delta
    StepMotion.move(self,delta)
    var moved:=Vector2(global_position.x-before.x,global_position.z-before.z).length()
    if moved<speed*delta*.15:
        _stuck_clock+=delta
        if _stuck_clock>.55:
            _avoid_sign*=-1;_stuck_clock=0;_replan=0;_unsticks+=1
            if state=="patrol":_patrol_index=(_patrol_index+1)%patrol_points.size()
    else:_stuck_clock=0

func _reachable_flank_route(requested: Vector3) -> PackedVector3Array:
    var player := _player()
    if player==null:return PackedVector3Array()
    var lateral := requested-player.global_position;lateral.y=0
    # A lateral order can land inside a newly solid bed or cliff. Try the
    # other shoulder first, then keep pressure on the reachable player lane.
    # This runs only on a failed replan; the actor still walks every metre.
    for goal: Vector3 in [player.global_position-lateral,player.global_position]:
        if combat_radius>0:
            var offset:=goal-combat_anchor;offset.y=0
            if offset.length()>combat_radius:
                var bounded:=combat_anchor+offset.normalized()*combat_radius
                goal.x=bounded.x;goal.z=bounded.z
        goal=navigation.ground_goal(goal)
        if not goal.is_finite():continue
        var route: PackedVector3Array=navigation.path(global_position,goal,false)
        if route.is_empty():continue
        _route_destination=goal
        _tactical_fallbacks+=1
        return route
    return PackedVector3Array()

func investigate(world_position: Vector3) -> void:
    if defeated or is_tank or state in ["melee","aim","fire","recover"]: return
    if _flat_distance(global_position,world_position)>hearing_distance:return
    if not encounter_active:_wake_encounter(world_position)
    _last_seen=world_position;_memory=8.5;state="investigate";_replan=0
    if is_instance_valid(navigation) and navigation.is_ready:
        var points: PackedVector3Array=navigation.path(global_position,world_position,is_tank)
        var length:=0.0
        for i in range(1,points.size()):length+=points[i-1].distance_to(points[i])
        _memory=maxf(_memory,minf(35,length/2.1+3))

func take_damage(amount: int, source: Node = null) -> bool:
    if defeated or health == null: return false
    if is_tank and state != "recover":
        if _blocked_message_timer <= 0.0:
            # The player reports a rejected hit after this call. Explain the
            # armour after that generic miss feedback so the useful instruction
            # remains on screen.
            call_deferred("_explain_armour")
            _blocked_message_timer = 2.0
        return false
    if is_tank and final_boss and _recovery_hits>=3:return false
    if source is Node3D and not is_tank:
        if director.get("encounter_director")!=null:
            director.encounter_director.on_guard_damaged(self,source.global_position)
        elif not encounter_active:activate_encounter(source.global_position)
    if source is Node3D and visual != null and visual.has_method("prepare_impact"):
        visual.prepare_impact(source.global_position)
    var applied := health.apply_damage(amount, source)
    if applied and is_tank:
        _recovery_hits+=1
        if final_boss and _recovery_hits>=3 and not defeated:
            # Close the advertised opening on its final accepted hit. Green
            # never stays on while an invisible per-window armour cap rejects.
            state="stalk";_timer=.75;warning_ring.visible=false
            SignalBus.show_message.emit("Защита сомкнулась. Готовься к следующей атаке!",1.3)
    if applied and not defeated:
        visual.apply_hit()
        if source is Node3D and not is_tank: investigate(source.global_position)
        _voice(&"guardian_hit" if is_tank else &"squirrel_hit",.25)
    return applied

func _explain_armour() -> void:
    if is_inside_tree() and not defeated:
        SignalBus.show_message.emit("Уклонитесь от рывка. Стреляйте, когда танк выдохнется.", 2.0)

func _on_defeated() -> void:
    if defeated: return
    defeated = true
    state = "defeated"
    velocity = Vector3.ZERO
    warning_ring.visible = false
    charge_line.visible = false
    hitbox.collision_layer = 0
    collision_layer = 0
    hitbox.set_deferred("monitorable", false)
    body_shape.set_deferred("disabled", true)
    hitbox.get_node("CollisionShape3D").set_deferred("disabled", true)
    if visual.has_method("apply_defeated"):visual.call("apply_defeated",_restoring)
    else:visual.apply_stunned()
    if not _restoring:SignalBus.emit_audio_event(&"guardian_defeat" if is_tank else &"squirrel_defeat",global_position)

func restore_defeated() -> void:
    _restoring=true;health.force_kill();_restoring=false
    if defeated and visual != null:
        visual.visible = true
        set_physics_process(false)

func _animate(delta: float) -> void:
    if visual == null:return
    var camera:=get_viewport().get_camera_3d()
    var distance:=global_position.distance_to(camera.global_position) if camera!=null else 0.0
    visual.visible=distance<65
    _animation_elapsed+=delta
    if distance>30 and _animation_elapsed<.12:return
    var elapsed:=_animation_elapsed;_animation_elapsed=0
    var flat_velocity:=Vector3(velocity.x,0,velocity.z)
    var direction:=flat_velocity.normalized() if flat_velocity.length_squared()>.01 else Vector3.ZERO
    # A charge's physics can slide along a pillar; that is collision response,
    # never a new attack heading. Keep the animal's face on its announced lane.
    if state in ["windup","charge","stomp_windup","shockwave"] or (is_tank and state=="recover"):direction=_charge_direction
    elif state in ["aim","fire"]:
        direction=global_position.direction_to(_attack_target);direction.y=0
    var phase:float=clampf(1-_timer/_attack_duration,0,1) if state in ["aim","fire","melee","windup","charge","stomp_windup","recover"] else -1.0
    if visual.has_method("set_action"):visual.call("set_action",StringName(state),phase)
    if state=="charge":visual.face_locked_direction(_charge_direction)
    visual.animate_squirrel(_clock,0,flat_velocity.length(),direction,elapsed)
