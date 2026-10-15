extends RefCounted
# Fixed-step pursuit authority. Rendering, sound and HUD only observe this state.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const STRIP_WIDTH := 5.2
const STRIP_OFFSET := 1.7
const APPROACH_SECONDS := 2.4
const FALL_SECONDS := .75
var clock := 0.0
var phase: StringName = &"idle"
var phase_time := 0.0
var cooldown := 12.0
var helicopter_x := 0.0
var helicopter_z := 0.0
var helicopter_height := 9.0
var helicopter_yaw := 0.0
var helicopter_bank := 0.0
var previous_helicopter_position := Vector3.ZERO
var previous_clock := 0.0
var safe_side := -1.0
var drops := 0
var spike_hits := 0
var ram_hits := 0
var warning_serial := 0
var impact_serial := 0
var strips: Array[Dictionary]=[]
var attack_cursor := 0
var _attack_switch := 0.0
var _previous: Array[Vector2]=[]
var _contact_cooldowns := [0.0,0.0,0.0]
var _drop_z := 0.0
var _drop_offset := 0.0

func prepare(delta: float,state,player,ais: Array) -> void:
    _previous.clear();_previous.append(Vector2(player.world_x,player.world_z))
    for ai in ais: _previous.append(Vector2(ai.car.world_x,ai.car.world_z))
    var active: bool=state.race_started and not state.race_finished and state.race_time>7 and player.speed>8 and strips.is_empty()
    _attack_switch-=delta if active else 0.0
    if _attack_switch<=0 and active:
        attack_cursor=(attack_cursor+1)%maxi(1,ais.size());_attack_switch=6.0
    for i in range(ais.size()):
        ais[i].pursuit_allowed=active and i==attack_cursor
        ais[i].evasion_lane=INF
        for strip in strips:
            var ahead: float=float(strip.z)-ais[i].car.world_z
            if ahead> -7 and ahead<250: ais[i].evasion_lane=-signf(float(strip.offset))*2.8
        _contact_cooldowns[i]=maxf(0,float(_contact_cooldowns[i])-delta)

func tick(delta: float,state,player,ais: Array,track: PackedFloat32Array) -> void:
    if not state.race_started or state.race_finished: return
    previous_clock=clock
    previous_helicopter_position=Vector3(helicopter_x,helicopter_height,helicopter_z)
    clock+=delta
    if state.race_time>7: _contacts(player,ais)
    _advance_strips(delta,player,ais)
    if phase==&"idle":
        cooldown=maxf(0,cooldown-delta)
        if cooldown<=0 and player.speed>18 and player.world_z>350:
            var z: float=player.world_z+maxf(180,player.speed*4.0+45)
            if safe_drop_zone(z,track) and strips.is_empty(): _begin(player,z,track)
        return
    phase_time+=delta
    var strip: Dictionary=strips[-1] if not strips.is_empty() else {}
    if strip.is_empty() and phase!=&"depart": stop();return
    var z: float=_drop_z
    var center := Math.track_center_x(z/40,track)
    helicopter_yaw=atan2(Math.track_center_slope(z/40,track),40)
    if phase==&"approach":
        var t := smoothstep(0,APPROACH_SECONDS,phase_time)
        helicopter_z=lerpf(z-65,z,t)
        helicopter_x=lerpf(center-safe_side*18,center+_drop_offset,t)
        helicopter_height=lerpf(13,7.2,t)
        helicopter_bank=lerpf(-safe_side*.26,0,t)
        if phase_time>=APPROACH_SECONDS:
            phase=&"drop";phase_time=0;strip.falling=true
    elif phase==&"drop":
        helicopter_bank=0
        if phase_time>=FALL_SECONDS:
            phase=&"depart";phase_time=0
            strip.armed=true;strip.falling=false;strip.age=0.0;drops+=1
    else:
        var t := smoothstep(0,4.0,phase_time)
        helicopter_z=z+t*120
        helicopter_x=center+_drop_offset+safe_side*t*55
        helicopter_height=7.2+t*18;helicopter_bank=safe_side*.30
        if phase_time>=4.0:
            phase=&"idle";phase_time=0;cooldown=20.0

func _begin(player,z: float,track: PackedFloat32Array) -> void:
    # Lock the lane immediately; the helicopter never follows a late dodge.
    var blocked_side := 1.0 if player.lateral_offset>=0 else -1.0
    if warning_serial%2==1 and absf(player.lateral_offset)<.6: blocked_side=-blocked_side
    safe_side=-blocked_side
    phase=&"approach";phase_time=0;warning_serial+=1
    _drop_z=z;_drop_offset=blocked_side*STRIP_OFFSET
    strips.append({"z":z,"offset":blocked_side*STRIP_OFFSET,"width":STRIP_WIDTH,"age":0.0,"armed":false,"falling":false,"spent":false})
    helicopter_z=z-65;helicopter_x=Math.track_center_x(z/40,track)-safe_side*18
    helicopter_height=13;helicopter_bank=-safe_side*.26
    previous_helicopter_position=Vector3(helicopter_x,helicopter_height,helicopter_z)

func _advance_strips(delta: float,player,ais: Array) -> void:
    var cars: Array=[player]
    for ai in ais: cars.append(ai.car)
    for strip in strips:
        strip.age+=delta
        if not strip.armed: continue
        # Swept wheel crossing on the physical fixed step, including rear-grid
        # offset. Looking at the strip or entering its warning never hits it.
        var near: float=float(strip.z)-2.2
        var far: float=float(strip.z)+2.2
        for i in range(cars.size()):
            var car=cars[i]
            var mask: int=strip.get("hit_mask",0)
            if mask&(1<<i): continue
            var old: Vector2=_previous[i] if i<_previous.size() else Vector2(car.world_x,car.world_z)
            if maxf(old.y,car.world_z)<near or minf(old.y,car.world_z)>far: continue
            var t := clampf((float(strip.z)-old.y)/maxf(.0001,car.world_z-old.y),0,1)
            var crossing_x: float=lerpf(old.x,car.world_x,t)-car.road_center_at(float(strip.z))
            var half: float=float(strip.width)*.5
            # Actual tire tracks, not the entire body/whole road. Pursuers must
            # also evade their own unit's spikes; there is no enemy immunity.
            if absf(crossing_x-.72-float(strip.offset))<=half or absf(crossing_x+.72-float(strip.offset))<=half:
                strip.hit_mask=mask|(1<<i);car.hit_spikes()
                if i==0: strip.spent=true;spike_hits+=1;impact_serial+=1
    for i in range(strips.size()-1,-1,-1):
        if player.world_z>float(strips[i].z)+18 or float(strips[i].age)>23:
            strips.remove_at(i)

func _contacts(player,ais: Array) -> void:
    if _previous.size()!=ais.size()+1: return
    for i in range(ais.size()):
        var other=ais[i].car
        if player.speed<5 or other.speed<5: continue
        var start := (_previous[0]-_previous[i+1])/Vector2(1.85,4.6)
        var end := Vector2(player.world_x-other.world_x,player.world_z-other.world_z)/Vector2(1.85,4.6)
        var step := end-start
        var t := clampf(-start.dot(step)/maxf(step.length_squared(),.000001),0,1)
        if start.lerp(end,t).length_squared()>1 or _contact_cooldowns[i]>0: continue
        var direction := signf(player.world_x-other.world_x)
        if direction==0: direction=1.0 if i%2==0 else -1.0
        var side_hit := absf(player.world_z-other.world_z)<3.8
        player.apply_side_impact(direction*(3.5 if side_hit else 1.5),.045 if side_hit else .065)
        other.apply_side_impact(-direction*2.8,.06)
        ais[i].recover_from_ram()
        _contact_cooldowns[i]=1.6;ram_hits+=1;impact_serial+=1

static func safe_drop_zone(z: float,track: PackedFloat32Array) -> bool:
    if z<500 or z>Data.route_length()-350: return false
    if z>Data.TUNNEL_START-480 and z<Data.TUNNEL_END+340: return false
    if absf(Data.road_grade(z))>.035: return false
    return Math.safe_corner_speed(z/40,track,Data.PLAYER_MAX_SPEED,Data.NFS_MAX_HEADING_YAW,Data.CORNER_GRIP_ACCEL)>Data.PLAYER_MAX_SPEED*.78

func stop() -> void:
    phase=&"idle";strips.clear();cooldown=12.0;phase_time=0

func warning_text(player) -> String:
    if player.puncture_remaining>0: return "ШИНЫ ПОВРЕЖДЕНЫ · ВОССТАНОВЛЕНИЕ %.1f С"%player.puncture_remaining
    for strip in strips:
        var distance: float=float(strip.z)-player.world_z
        if distance>=-3 and not strip.spent:
            return "ВЕРТОЛЁТ · ШИПЫ %d М · %s"%[maxi(0,roundi(distance)),"← УХОДИ ВЛЕВО" if safe_side<0 else "УХОДИ ВПРАВО →"]
    return ""
