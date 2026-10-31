extends RefCounted
# Fixed-step pursuit authority. Rendering, sound and HUD only observe this state.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const Contacts=preload("res://scripts/race_vehicle_contacts.gd")
const Flight=preload("res://scripts/race_helicopter_flight.gd")
const STRIP_WIDTH := 5.2
const STRIP_OFFSET := 1.7
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
var helicopter_pitch := 0.0
var rotor_pitch := 0.0
var rotor_bank := 0.0
var previous_attitude := Vector3.ZERO
var previous_rotor_attitude := Vector3.ZERO
var flight=Flight.new()
var pass_time := 0.0
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
var _entry_position := Vector3.ZERO
var _attack_turn := 0
var has_flight_observer := false
var flight_outside_view := true
var encounters=preload("res://scripts/race_encounters.gd").new()
var radio=preload("res://scripts/race_radio.gd").new()

func prepare(delta: float,state,player,ais: Array) -> void:
    _previous.clear();_previous.append(Vector2(player.world_x,player.world_z))
    for ai in ais: _previous.append(Vector2(ai.car.world_x,ai.car.world_z))
    var active: bool=state.race_started and not state.race_finished and state.race_time>7 and player.speed>8 and strips.is_empty()
    _attack_switch-=delta if active else 0.0
    var busy: bool=not ais.is_empty() and ais[mini(attack_cursor,ais.size()-1)].busy()
    if _attack_switch<=0 and active and not busy:
        _attack_turn+=1
        var want_brake: bool=_attack_turn%2==1
        var best: int=-1;var best_distance:=INF
        for i in range(ais.size()):
            var ai=ais[i]
            if ai.busy() or ai.attack_cooldown>.1 or ai.car.speed<18:continue
            var dz: float=ai.car.world_z-player.world_z
            if want_brake and (not ai._open_road() or dz< -25 or dz>15):continue
            if not want_brake and absf(dz)>12:continue
            if absf(dz)<best_distance:best=i;best_distance=absf(dz)
        attack_cursor=best if best>=0 else (attack_cursor+1)%maxi(1,ais.size())
        _attack_switch=2.3
    for i in range(ais.size()):
        # Dispatch the nearest ready interceptor, retaining one committed
        # ground attack and a body-width escape corridor at a time.
        ais[i].pursuit_allowed=active and i==attack_cursor
        ais[i].attack_kind=&"brake_check" if i==attack_cursor and _attack_turn%2==1 else &"ram"
        ais[i].support_gap=-6.0-i*3 if busy and i!=attack_cursor else -INF
        ais[i].evasion_lane=INF
        for strip in strips:
            var ahead: float=float(strip.z)-ais[i].car.world_z
            if ahead> -7 and ahead<250: ais[i].evasion_lane=-signf(float(strip.offset))*2.8
        _contact_cooldowns[i]=maxf(0,float(_contact_cooldowns[i])-delta)
    encounters.prepare(delta,state,player,ais,radio)

func tick(delta: float,state,player,ais: Array,track: PackedFloat32Array) -> void:
    if not state.race_started or state.race_finished: return
    previous_clock=clock
    previous_helicopter_position=Vector3(helicopter_x,helicopter_height,helicopter_z)
    previous_attitude=Vector3(helicopter_pitch,helicopter_yaw,helicopter_bank)
    previous_rotor_attitude=Vector3(rotor_pitch,helicopter_yaw,rotor_bank)
    clock+=delta
    _contacts(player,ais)
    _advance_strips(delta,player,ais)
    radio.tick(delta,state,player,ais,self,track)
    if phase==&"idle":
        cooldown=maxf(0,cooldown-delta)
        if cooldown<=0 and player.speed>18 and player.world_z>350:
            var z: float=planned_drop_z(player,track)
            var ground_attack := false
            for ai in ais:
                if ai.brake_maneuver(): ground_attack=true
            if not ground_attack and encounters.next_block(player).is_empty() and encounters.air_attack_clear(player,z) and Data.sector_at(player.world_z)!=4 and safe_drop_zone(z,track) and strips.is_empty(): _begin(player,z,track)
        return
    phase_time+=delta
    var strip: Dictionary=strips[-1] if not strips.is_empty() else {}
    if strip.is_empty() and phase!=&"depart": stop(false);return
    if phase in [&"ingress",&"approach"]:
        pass_time=minf(flight.duration,pass_time+delta)
        flight.pass_at(pass_time,delta)
        if phase==&"ingress" and pass_time>=flight.duration*.60: phase=&"approach";phase_time=0
        if pass_time>=flight.duration:
            phase=&"drop";phase_time=0;strip.falling=true
            strip.release=Vector3(flight.position.x,6.0,flight.position.z)
            strip.release_velocity=flight.velocity
    elif phase==&"drop":
        flight.coast(delta)
        if phase_time>=FALL_SECONDS:
            phase=&"depart";phase_time=0
            strip.armed=true;strip.falling=false;strip.age=0.0;drops+=1
    else:
        # Keep flying until the complete aircraft has left the real camera.
        # A fixed-duration bank alone could hide a perfectly visible model.
        flight.depart(delta,safe_side,player.speed)
        if phase_time>=6.0 and (flight_outside_view or not has_flight_observer):
            phase=&"idle";phase_time=0;cooldown=20.0
    _observe_flight()

func planned_drop_z(player,track: PackedFloat32Array) -> float:
    var duration:=Flight.MIN_PASS_SECONDS
    var z: float=player.world_z
    # Include flight, fall AND an actual dodge interval at maximum car speed.
    # Curved ground can require a longer, acceleration-limited air approach.
    for attempt in range(5):
        z=player.world_z+maxf(300,player.speed*(duration+FALL_SECONDS+2.4)+65)
        if not safe_drop_zone(z,track): return z
        _plan_flight(player,z,0,track)
        if flight.duration<=duration+.01: return z
        duration=flight.duration
    return player.world_z+maxf(300,player.speed*(duration+FALL_SECONDS+2.4)+65)

func _plan_flight(player,z: float,offset: float,track: PackedFloat32Array) -> void:
    var start_z: float=player.world_z-35
    _entry_position=Vector3(player.world_x,Data.road_height(start_z)+24,start_z)
    var destination:=Vector3(Math.track_center_x(z/40,track)+offset,Data.road_height(z)+7.2,z)
    flight.plan(_entry_position,destination,FALL_SECONDS,Math.track_center_slope(z/40,track)/40)

func _observe_flight() -> void:
    helicopter_x=flight.position.x;helicopter_z=flight.position.z
    helicopter_height=flight.position.y-Data.road_height(helicopter_z)
    helicopter_yaw=flight.yaw;helicopter_pitch=flight.pitch;helicopter_bank=flight.bank
    rotor_pitch=flight.rotor_pitch;rotor_bank=flight.rotor_bank

func _begin(player,z: float,track: PackedFloat32Array) -> void:
    # Lock the lane immediately; the helicopter never follows a late dodge.
    var blocked_side := 1.0 if player.lateral_offset>=0 else -1.0
    if warning_serial%2==1 and absf(player.lateral_offset)<.6: blocked_side=-blocked_side
    safe_side=-blocked_side
    phase=&"ingress";phase_time=0;warning_serial+=1
    _drop_z=z;_drop_offset=blocked_side*STRIP_OFFSET
    strips.append({"z":z,"offset":blocked_side*STRIP_OFFSET,"width":STRIP_WIDTH,"age":0.0,"armed":false,"falling":false,"spent":false})
    # Start behind the complete camera frustum, already carrying airspeed.
    # The pass never stops at an easing-key boundary or at the release point.
    _plan_flight(player,z,_drop_offset,track);pass_time=0
    _observe_flight()
    previous_attitude=Vector3(helicopter_pitch,helicopter_yaw,helicopter_bank)
    previous_rotor_attitude=Vector3(rotor_pitch,helicopter_yaw,rotor_bank)
    flight_outside_view=true
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
            var along: float=car.world_z-old.y
            var t := clampf((float(strip.z)-old.y)/along,0,1) if absf(along)>.0001 else .5
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
    var cars: Array=[player]
    for ai in ais: cars.append(ai.car)
    var pattern: Array=ais[0].track_pattern if not ais.is_empty() else []
    if pattern.is_empty(): return
    var previous: Array[Vector2]=_previous.duplicate()
    var encounter_cars: Array=encounters.active_bodies()
    # Tests may call pursuit preparation with a deliberately reduced AI list;
    # the same body/position order is used by every solve.
    for index in range(encounter_cars.size()):
        cars.append(encounter_cars[index])
        previous.append(encounters.previous[index] if index<encounters.previous.size() else Vector2(encounter_cars[index].world_x,encounter_cars[index].world_z))
    var speeds: Array[Vector2]=[]
    for car in cars:speeds.append(Contacts.velocity(car))
    var touched := Contacts.solve(cars,previous,pattern,ais[0].track_x)
    for pair in touched:
        if pair.x!=0: continue
        if pair.y>ais.size():
            if encounters.contact(pair,cars,player,(speeds[pair.x]-speeds[pair.y]).length()):impact_serial+=1
            continue
        var i := pair.y-1
        var other=ais[i].car
        if _contact_cooldowns[i]>0: continue
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

func stop(clear_encounters: bool=true) -> void:
    phase=&"idle";strips.clear();cooldown=12.0;phase_time=0;radio.stop()
    if clear_encounters:encounters.stop()

func warning_text(player) -> String:
    var encounter_warning: String=encounters.warning_text(player)
    if not encounter_warning.is_empty():return encounter_warning
    if player.puncture_remaining>0: return "ШИНЫ ПОВРЕЖДЕНЫ · ВОССТАНОВЛЕНИЕ %.1f С"%player.puncture_remaining
    for strip in strips:
        var distance: float=float(strip.z)-player.world_z
        if distance>=-3 and not strip.spent:
            return "ВЕРТОЛЁТ · ШИПЫ %d М · %s"%[maxi(0,roundi(distance)),"← УХОДИ ВЛЕВО" if safe_side<0 else "УХОДИ ВПРАВО →"]
    return ""
