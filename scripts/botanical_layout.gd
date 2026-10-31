extends RefCounted
## One X/Z authority for paving, planting, furniture and water clearance.
const STAIR_FLIGHTS := [
    [Vector3(-24,0,45),Vector3(-24,3,25),12.0,24],
    [Vector3(24,0,45),Vector3(24,3,25),12.0,24],
    [Vector3(0,3,12),Vector3(0,7,-14),20.0,32],
    [Vector3(0,7,-52),Vector3(0,12,-72),13.0,30],
]
const PATHS := [
    [Vector2(0,67.2),Vector2(0,49)],
    [Vector2(0,49),Vector2(-24,49),Vector2(-24,23),Vector2(-38,20),Vector2(-44,14),Vector2(-62,14),Vector2(-62,-20),Vector2(-56,-35),Vector2(-60,-51),Vector2(-54,-62),Vector2(-54,-74),Vector2(-44,-88)],
    [Vector2(0,49),Vector2(24,49),Vector2(24,23),Vector2(38,20),Vector2(44,14),Vector2(62,14),Vector2(62,-20),Vector2(56,-35),Vector2(60,-51),Vector2(55,-63),Vector2(55,-71),Vector2(57,-74),Vector2(62,-78),Vector2(62,-91.5),Vector2(47,-91.5)],
    [Vector2(-62,-20),Vector2(-22,-18),Vector2(0,-18),Vector2(22,-18),Vector2(62,-20)],
    [Vector2(-44,-88),Vector2(-20,-88),Vector2(0,-86),Vector2(22,-88),Vector2(35,-91),Vector2(47,-91.5)],
    [Vector2(-24,23),Vector2(-25,12.8),Vector2(-6.0,12.8)],
    [Vector2(0,-18),Vector2(0,-21.4)],
    [Vector2(-56,-35),Vector2(-38,-35)],
    [Vector2(35,-91),Vector2(35,-79),Vector2(37.5,-79)],
    [Vector2(6.0,12.8),Vector2(25,12.8),Vector2(25,19),Vector2(30,19)],
]
## The east promenade narrows to3m through the real wall/pavilion passage.
const PATH_HALF_WIDTHS := [2.5,2.2,1.5,2.5,2.5,1.0,2.5,1.8,1.0,1.0]
const CHANNEL_POINTS := [Vector2(48,-70),Vector2(47,-52),Vector2(44,-35),Vector2(45,-17),Vector2(44,-4),Vector2(40,10),Vector2(34,19),Vector2(18.7,23)]
const CHANNEL_HALF_WIDTH := .52
const VEHICLE_COURT := Rect2(-6,68,12,14)
## Arrive on the outside street, then approach the garden through its gateway.
const ENTRY_PLAYER_SPAWN := Vector3(-4,.735,91.3)
const ENTRY_CAR_POSITION := Vector3(-4,.035,94)
const ENTRY_CAR_YAW := PI*.5
const LAMP_POSTS := [Vector2(-11,54),Vector2(11,54),Vector2(-23,8),Vector2(23,8),Vector2(-41,-22.5),Vector2(41,-22.5),Vector2(-43,-76),Vector2(37,-77)]
const EVENING_LAMPS := [Vector2(-7,55),Vector2(21,20),Vector2(-41,-29),Vector2(7,-22),Vector2(-42,-81),Vector2(47,-79)]
const BENCHES := [
    [Vector2(-9,56.5),PI*.5],[Vector2(9,56.5),-PI*.5],
    [Vector2(-45,20),PI*.5],[Vector2(45,20),-PI*.5],
    [Vector2(-52,-24),-PI*.5],[Vector2(52,-24),PI*.5],
    [Vector2(-44,-92),0.0],
]
const BENCH_SPURS := [
    [Vector2(0,56.5),Vector2(-7.8,56.5)],
    [Vector2(0,56.5),Vector2(7.8,56.5)],
    [Vector2(-38,20),Vector2(-43.8,20)],
    [Vector2(38,20),Vector2(43.8,20)],
    [Vector2(-60.4,-24),Vector2(-53.2,-24)],
    [Vector2(60.4,-24),Vector2(53.2,-24)],
    [Vector2(-44,-88),Vector2(-44,-90.8)],
]
## Keys retain the original RNG draw order, not unsafe original coordinates.
const BED_KEYS := [52,40,6,-5,-48,-82]
const BEDS := {
    52:{"z":55.0,"x":17.0,"size":Vector2(10,5)},
    40:{"z":32.0,"x":40.0,"size":Vector2(8,4)},
    -48:{"z":-48.0,"x":23.0,"size":Vector2(10,5)},
    -82:{"z":-78.0,"x":23.0,"size":Vector2(10,5)},
}
const HEDGE_BEDS := [Rect2(-37,-26.5,24,2),Rect2(13,-26.5,24,2),Rect2(-37,-44.5,24,2),Rect2(13,-44.5,24,2),Rect2(-16,59.65,10,2),Rect2(6,59.65,10,2)]
const OUTLOOK_BEDS := [Rect2(-39,-14.5,12,5),Rect2(27,-14.5,12,5)]
const SERVICE_RECTS := [Rect2(27.4,10.4,1.2,1.2),Rect2(22.2,18.5,1.6,1.0),Rect2(21.3,6.3,1.4,1.4),Rect2(10.8,42.4,2.4,1.2),Rect2(31.4,14.5,1.2,3.0),Rect2(35.5,6.4,3.0,1.2),Rect2(-29,16.8,2,1.4),Rect2(-15.5,-22.5,1,1)]
static var _segments: Array = []

static func all_paths() -> Array:
    var routes: Array=[]
    for i in range(PATHS.size()):routes.append({"points":PATHS[i],"half_width":PATH_HALF_WIDTHS[i],"id":"main_%d"%i})
    for i in range(BENCH_SPURS.size()):routes.append({"points":BENCH_SPURS[i],"half_width":1.1,"id":"bench_%d"%i})
    return routes

static func stair_footprint(flight: Array) -> Rect2:
    var a: Vector3=flight[0];var b: Vector3=flight[1]
    return Rect2(a.x-float(flight[2])*.5-2.0,b.z-2.0,float(flight[2])+4.0,a.z+2.0-(b.z-2.0))

static func bench_pad(spec: Array) -> PackedVector2Array:
    var center: Vector2=spec[0];var yaw: float=spec[1]
    var polygon:=PackedVector2Array()
    for local in [Vector2(-1.9,-.85),Vector2(1.9,-.85),Vector2(1.9,1.65),Vector2(-1.9,1.65)]:
        polygon.append(center+Vector2(cos(yaw)*local.x+sin(yaw)*local.y,-sin(yaw)*local.x+cos(yaw)*local.y))
    return polygon

static func bed_rects() -> Array[Rect2]:
    var result: Array[Rect2]=[]
    for key in BED_KEYS:
        if not BEDS.has(key):continue
        var spec: Dictionary=BEDS[key];var size_: Vector2=spec.size
        for side in [-1,1]:result.append(Rect2(Vector2(side*float(spec.x),float(spec.z))-size_*.5,size_))
    result.append_array(HEDGE_BEDS);result.append_array(OUTLOOK_BEDS)
    return result

static func _prepare_segments() -> void:
    if not _segments.is_empty():return
    for route in all_paths():
        for i in range(route.points.size()-1):_segments.append([route.points[i],route.points[i+1],float(route.half_width)])

static func _near_segments(point: Vector2,points: Array,distance: float) -> bool:
    for i in range(points.size()-1):
        if point.distance_to(Geometry2D.get_closest_point_to_segment(point,points[i],points[i+1]))<distance:return true
    return false

static func ground_allowed(point: Vector2,radius: float=1.0) -> bool:
    _prepare_segments()
    for segment in _segments:
        if point.distance_to(Geometry2D.get_closest_point_to_segment(point,segment[0],segment[1]))<float(segment[2])+radius+.18:return false
    for flight in STAIR_FLIGHTS:
        if stair_footprint(flight).grow(radius+.18).has_point(point):return false
    for lamp in LAMP_POSTS+EVENING_LAMPS:
        if point.distance_to(lamp)<radius+.35:return false
    for rect in SERVICE_RECTS:
        if rect.grow(radius+.12).has_point(point):return false
    for rect in bed_rects():
        if rect.grow(radius+.12).has_point(point):return false
    for bench in BENCHES:
        var pad:=bench_pad(bench)
        if Geometry2D.is_point_in_polygon(point,pad):return false
        for i in range(pad.size()):
            if point.distance_to(Geometry2D.get_closest_point_to_segment(point,pad[i],pad[(i+1)%pad.size()]))<radius+.18:return false
    if _near_segments(point,CHANNEL_POINTS,CHANNEL_HALF_WIDTH+radius+.25):return false
    if Vector2(point.x/20.0,(point.y-23)/11.0).length()<1.0+radius*.045:return false
    if point.distance_to(Vector2(0,-35))<13.0+radius:return false
    if point.distance_to(Vector2(47,-79))<9.4+radius:return false
    if Rect2(-36,-41,72,16).grow(radius).has_point(point):return false
    if Rect2(-98,90,196,8).grow(radius).has_point(point):return false
    if Rect2(-6,70,12,20).grow(radius).has_point(point):return false
    # Loose shrubs cannot take root on the actual boulder faces or their bank.
    if absf(point.x)>13-radius and absf(point.x)<54+radius and point.y> -15-radius and point.y< -3+radius:return false
    return true

static func plant_point(point: Vector2,radius: float=1.0) -> Vector2:
    if ground_allowed(point,radius):return point
    for ring in range(1,19):
        var distance:=float(ring)*.8
        for spoke in range(12):
            var angle:=float(spoke)*TAU/12
            var candidate:=point+Vector2(cos(angle),sin(angle))*distance
            if ground_allowed(candidate,radius):return candidate
    return Vector2.INF

static func describe() -> Dictionary:
    return {"paths":all_paths(),"stairs":STAIR_FLIGHTS,"channel":CHANNEL_POINTS,"channel_half_width":CHANNEL_HALF_WIDTH,"vehicle_court":VEHICLE_COURT,"benches":BENCHES,"lamps":LAMP_POSTS,"evening_lamps":EVENING_LAMPS,"soil_beds":bed_rects(),"policy":"Actual terrain-triangle paving; stairs/landings cut out once; soil/pots separate from masonry; final footprint clearance for every loose root."}
