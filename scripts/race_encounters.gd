extends RefCounted
## Authored roadblocks and continuously approaching civilian Camrys.
## Every visible vehicle is a solid body in the same swept contact solve.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const Body=preload("res://scripts/race_encounter_body.gd")
const TRAFFIC_COUNT := 6
const DRAW_DISTANCE := 480.0
const RECYCLE_BEHIND := 800.0
const GAP_WIDTH := 3.2
var traffic: Array=[]
var roadblocks: Array[Dictionary]=[]
var previous: Array[Vector2]=[]
var clock := 0.0
var traffic_hits := 0
var impact_log: Array[Dictionary]=[]
var roadblock_hits := 0
var roadblocks_passed := 0
var warning_serial := 0
var collision_notice := ""
var collision_notice_time := 0.0
var contact_cooldowns: Dictionary={}
var enabled := true
var _pattern: Array=[]
var _track := PackedFloat32Array()
var _spawn_serial := 0

func setup(pattern: Array,track: PackedFloat32Array) -> void:
    _pattern=pattern;_track=track;traffic.clear();roadblocks.clear();previous.clear()
    clock=0;traffic_hits=0;roadblock_hits=0;roadblocks_passed=0;warning_serial=0;impact_log.clear()
    collision_notice="";collision_notice_time=0;contact_cooldowns.clear();_spawn_serial=0;enabled=true
    for i in range(TRAFFIC_COUNT):
        var car:=Body.new();car.serial=i;car.cruise_speed=[24.0,27.0,22.0,29.0,25.0,23.0][i]
        car.place(620+i*230,-2.45+[-.15,.15,0.0][i%3],track);traffic.append(car)
    for i in range(5):
        var desired: float=[1250.0,2740.0,4440.0,6970.0,8170.0][i]
        var selected: float=-INF
        for delta in range(0,401,40):
            var candidate: float=desired+delta
            if safe_roadblock(candidate,track):selected=candidate;break
        if not is_finite(selected):continue
        roadblocks.append({"id":i,"z":selected,"gap_center":[1.25,-1.25,0.0,1.25,-1.25][i],"gap_width":GAP_WIDTH,"cars":[],"passed":false,"warning":false})

static func safe_roadblock(z: float,track: PackedFloat32Array) -> bool:
    if z<800 or z>Data.route_length()-480:return false
    if z>Data.BRIDGE_START-200 and z<Data.BRIDGE_END+180:return false
    if z>Data.TUNNEL_START-360 and z<Data.TUNNEL_END+260:return false
    if absf(Data.road_grade(z))>.025:return false
    return Math.safe_corner_speed(z/40,track,Data.PLAYER_MAX_SPEED,Data.NFS_MAX_HEADING_YAW,Data.CORNER_GRIP_ACCEL)>Data.PLAYER_MAX_SPEED*.76

func _build_block(block: Dictionary) -> void:
    var left: float=block.gap_center-GAP_WIDTH*.5
    var right: float=block.gap_center+GAP_WIDTH*.5
    # Crosswise cars leave a visible 3.2m opening, including the mesh's
    # overhang beyond its contact footprint. Both stay inside field fences.
    var positions: Array[float]=[left-2.48,right+2.48]
    for i in range(positions.size()):
        var car:=Body.new();car.serial=100+int(block.id)*10+i
        car.place(block.z,positions[i],_track,true);block.cars.append(car)

func prepare(delta: float,state,player,ais: Array,radio) -> void:
    previous.clear()
    if not enabled or not state.race_started or state.race_finished:return
    clock+=delta;collision_notice_time=maxf(0,collision_notice_time-delta)
    for key in contact_cooldowns:contact_cooldowns[key]=maxf(0,float(contact_cooldowns[key])-delta)
    for car in traffic:
        if car.world_z<player.world_z-RECYCLE_BEHIND:
            _spawn_serial+=1
            # Recycling is farther behind than either camera's visible prop
            # range; new traffic starts beyond the complete front draw range.
            car.place(player.world_z+680+(_spawn_serial%3)*170,car.cruise_lane,_track)
        car.snapshot()
        car.lane=car.cruise_lane;car.desired_speed=car.cruise_speed
        for block in roadblocks:
            var from_city_side: float=car.world_z-float(block.z)
            if from_city_side>20 and from_city_side<250 and player.world_z<float(block.z)+200:
                # Civilian drivers see the police cars and brake onto their
                # outer shoulder. The advertised gap never spawns head-on
                # traffic while the player is committed to that one opening.
                car.lane=-5.3
                car.desired_speed=minf(car.desired_speed,maxf(0,(from_city_side-30)*.3))
        car.tick(delta,_pattern,_track)
    for block in roadblocks:
        var ahead: float=block.z-player.world_z
        if block.cars.is_empty() and ahead<700 and ahead> -RECYCLE_BEHIND:_build_block(block)
        for car in block.cars:car.snapshot();car.tick(delta,_pattern,_track)
        if not block.warning and ahead<600 and ahead>0:
            block.warning=true;warning_serial+=1
            var side: String="справа" if float(block.gap_center)>.5 else ("слева" if float(block.gap_center)<-.5 else "по центру")
            radio.say("roadblock-%d"%block.id,"ДУПЛО · ЗАГРАЖДЕНИЕ","Заграждение готово! Хвостам: оставить проход %s. Таю не выпускать!"%side,1,2,8)
        if not block.passed and ahead< -8:
            block.passed=true;roadblocks_passed+=1
        if ahead< -RECYCLE_BEHIND:block.cars.clear()
    for car in active_bodies():previous.append(car.old_position)
    # Air/ground tactics yield a deliberate approach corridor instead of
    # stacking an unavoidable spike rack across the roadblock's sole gap.
    for ai in ais:
        ai.traffic_obstacles.clear()
        for civilian in traffic:
            var distance: float=civilian.world_z-ai.car.world_z
            if distance> -12 and distance<300:ai.traffic_obstacles.append(Vector2(civilian.lateral_offset,distance))
        for block in roadblocks:
            var ai_ahead: float=float(block.z)-ai.car.world_z
            # The escort must clear the opening with its OWN body before it
            # can resume attacks. The player's earlier crossing is not enough.
            if ai_ahead<260 and ai_ahead> -9:
                if ai.busy():ai.recover_from_ram()
                ai.pursuit_allowed=false
                ai.evasion_lane=float(block.gap_center)
                ai.support_gap=-9.0-ai.pursuit_role*3
                break

func air_attack_clear(player,drop_z: float) -> bool:
    for block in roadblocks:
        if float(block.z)>player.world_z-60 and absf(float(block.z)-drop_z)<280:return false
    return true

func active_bodies() -> Array:
    var bodies: Array=[]
    if not enabled:return bodies
    for car in traffic:bodies.append(car)
    for block in roadblocks:
        for car in block.cars:bodies.append(car)
    return bodies

func next_block(player) -> Dictionary:
    for block in roadblocks:
        var ahead: float=block.z-player.world_z
        if not block.passed and ahead>= -5 and ahead<650:return block
    return {}

func contact(pair: Vector2i,cars: Array,player,closing: float) -> bool:
    if pair.x!=0:return false
    var other=cars[pair.y]
    if not other is Body:return false
    var key: int=other.serial
    if float(contact_cooldowns.get(key,0))>0:return false
    contact_cooldowns[key]=2.5
    var side:=signf(player.world_x-other.world_x)
    if side==0:side=1 if other.serial%2==0 else -1
    if closing>8:
        player.apply_side_impact(side*2.8,.12)
        player.speed*=.72 if other.is_roadblock else .66
    if other.is_roadblock:
        roadblock_hits+=1;collision_notice="УДАР О ЗАГРАЖДЕНИЕ · СНИЗЬ СКОРОСТЬ"
    else:
        traffic_hits+=1;collision_notice="СТОЛКНОВЕНИЕ СО ВСТРЕЧНОЙ МАШИНОЙ"
    collision_notice_time=2.0
    if impact_log.size()<24:impact_log.append({"time":clock,"z":player.world_z,"player_lane":player.lateral_offset,"other_lane":other.lateral_offset,"closing_speed":closing,"speed_after":player.speed,"roadblock":other.is_roadblock})
    return true

func warning_text(player) -> String:
    if not enabled:return ""
    var block:=next_block(player)
    if collision_notice_time>0 and (block.is_empty() or float(block.z)-player.world_z>140):return collision_notice
    if not block.is_empty():
        var side: String="СПРАВА →" if float(block.gap_center)>.5 else ("← СЛЕВА" if float(block.gap_center)<-.5 else "ПО ЦЕНТРУ")
        return "БЕЛИЧЬЕ ЗАГРАЖДЕНИЕ · %d М · ПРОЕЗД %s"%[maxi(0,roundi(float(block.z)-player.world_z)),side]
    if collision_notice_time>0:return collision_notice
    if player.lateral_offset<-.8:
        for car in traffic:
            var ahead: float=car.world_z-player.world_z
            if ahead>0 and ahead<160:return "ВСТРЕЧНАЯ ПОЛОСА · ВЕРНИСЬ ВПРАВО →"
    return ""

func stop() -> void:
    enabled=false;traffic.clear();roadblocks.clear();previous.clear()
    contact_cooldowns.clear();collision_notice_time=0
