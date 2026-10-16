extends RefCounted
# Bounded projected road geometry; uses the same lens, road height and clipping
# as the course. At most one active stinger, no full-screen shader pass.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const RaceProjection=preload("res://scripts/race_projection.gd")

static func draw(host,pursuit,vp: Vector2) -> void:
    if pursuit==null or Data.sector_at(host.player_car.world_z)==4: return
    for strip in pursuit.strips:
        var z: float=strip.z
        var distance: float=z-host.player_car.world_z
        if distance< -4 or distance>400 or not _visible(host,z): continue
        var center:=Math.track_center_x(z/40,host.track_x)
        var x: float=center+strip.offset
        var half: float=strip.width*.5
        var pulse := .55+.45*sin(pursuit.clock*8)
        if not strip.armed:
            _quad(host,x-half,x+half,z-2,z+2,.04,Color(1,.36,.08,.22+pulse*.12),vp)
            for side: float in [-1,1]:
                _quad(host,x+side*half-.055,x+side*half+.055,z-2.5,z+2.5,.05,Color(1,.65,.18,.9),vp)
        # A falling folded strip is visible before the sharp deployed rack.
        var height := .07
        var rack_z: float=z;var rack_x: float=x
        if strip.falling:
            var t:=clampf(pursuit.phase_time/pursuit.FALL_SECONDS,0,1)
            var release: Vector3=strip.get("release",Vector3(x,6.0,z))
            rack_z=lerpf(release.z,z,t);rack_x=lerpf(release.x,x,t)
            height=lerpf(release.y,.07,t*t)
        if strip.armed or strip.falling:
            _quad(host,rack_x-half,rack_x+half,rack_z-.23,rack_z+.23,height,Color("29353a") if not strip.spent else Color("36393a"),vp)
            for i in range(12):
                var sx: float=rack_x-half+.16+float(i)*(float(strip.width)-.32)/11.0
                _surface(host,[Vector3(sx-.12,height,rack_z-.21),Vector3(sx,height+.31,rack_z),Vector3(sx+.12,height,rack_z+.21)],Color("d9e2df") if not strip.spent else Color("6a7475"),vp)
            for side: float in [-1,1]:
                _quad(host,rack_x+side*(half-.12)-.10,rack_x+side*(half-.12)+.10,rack_z-.29,rack_z+.29,height+.02,Color("e7a33e"),vp)
        # Green road chevrons point into a physically wide, unblocked corridor.
        if not strip.spent:
            var gap_x: float=center+pursuit.safe_side*2.8
            for i in range(3):
                var at: float=z-5-float(i)*3.2
                _surface(host,[Vector3(gap_x-.55,.04,at-.8),Vector3(gap_x,.04,at+.65),Vector3(gap_x+.55,.04,at-.8),Vector3(gap_x,.04,at-.1)],Color(.48,.94,.77,.72),vp)
    if pursuit.phase!=&"idle" and _visible(host,pursuit.helicopter_z):
        var z: float=pursuit.helicopter_z
        var x: float=pursuit.helicopter_x
        for ring in range(4):
            var radius:=1.0-float(ring)*.23
            var points: Array[Vector3]=[]
            for i in range(20):
                var a:=i*TAU/20.0;points.append(Vector3(x+cos(a)*2.3*radius,.025,z+sin(a)*4.5*radius))
            # Road height bends the footprint over crests. Project planar
            # triangles instead of a warped outline that can cross itself.
            for i in range(points.size()):
                _surface(host,[Vector3(x,.025,z),points[i],points[(i+1)%points.size()]],Color(.92,.94,.70,.014+float(ring)*.009),vp)

static func _quad(host,left: float,right: float,near_: float,far_: float,y: float,color: Color,vp: Vector2) -> void:
    _surface(host,[Vector3(left,y,near_),Vector3(left,y,far_),Vector3(right,y,far_),Vector3(right,y,near_)],color,vp)
static func _surface(host,points: Array[Vector3],color: Color,vp: Vector2) -> void:
    var polygon:=RaceProjection.surface(host,points,vp)
    if polygon.size()<3: return
    var area:=0.0
    for i in range(polygon.size()): area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
    # Edge-on ground at the horizon has no rasterizable area.
    if absf(area)>.02: host.draw_colored_polygon(polygon,color)
static func _visible(host,z: float) -> bool:
    var player=host.player_car
    var start_z: float=player.world_z-host._behind()
    if z<=start_z: return false
    var h: float=host.get_viewport_rect().size.y*host.PLAYFIELD_FRACTION
    var eye_height: float=(h-host._horizon(h))*6.0/(.84*host.get_viewport_rect().size.x*.75)
    var start_y: float=Data.road_height(player.world_z)-host._behind()*Data.road_grade(player.world_z)+eye_height
    var end_y:=Data.road_height(z)+.06
    for i in range(1,17):
        var t:=float(i)/17
        if Data.road_height(lerpf(start_z,z,t))>lerpf(start_y,end_y,t)+.02: return false
    return true
