extends RefCounted
# Route architecture and roadside plants use the same projection as vehicles.
const Data=preload("res://scripts/race_level_data.gd")
var wheat: Texture2D
func setup(host: Node2D) -> void:
    wheat=host._tex("res://assets/level2/wheat_tuft.png")
func project(host: Node2D,x: float,z: float,height: float,vp: Vector2) -> Vector2:
    var at: float=host.player_car.track_phase()
    var depth: float=host._world_to_camera(x-host._camera_world_x(at),z-float(host.player_car.world_z)+host._behind()).y
    var p: Vector2=host.project_ground(x,z-float(host.player_car.world_z),vp)
    var up := Vector2.UP.rotated(-float(host.camera_state.roll) if host.camera_state!=null else 0.0)
    return p+up*height*host._camera_projection_scale(depth)*vp.x*host.ROAD_SCREEN_SCALE
func line(host: Node2D,a: Vector3,b: Vector3,color: Color,thickness: float,vp: Vector2) -> void:
    var p := project(host,a.x,a.z,a.y,vp)
    var q := project(host,b.x,b.z,b.y,vp)
    var depth: float = maxf((a.z+b.z)*.5-float(host.player_car.world_z)+host._behind(),1)
    host.draw_line(p,q,color,maxf(.7,host._camera_projection_scale(depth)*vp.x*.75*thickness),true)
func surface(host: Node2D,points: Array[Vector3],color: Color,vp: Vector2) -> void:
    var projected := PackedVector2Array()
    for p in points: projected.append(project(host,p.x,p.z,p.y,vp))
    host.draw_colored_polygon(projected,color)
func draw(host: Node2D,vp: Vector2) -> void:
    var origin: float=host.player_car.world_z
    # Stable object IDs are world indices, including the strip behind the car.
    var first := floori(origin/16.0)
    for i in range(40,-2,-1):
        var index := first+i
        var z := index*16.0
        var dist := z-origin
        if dist+host._behind()<.7 or dist>640: continue
        var center: float=host._smooth_track_x(z/40.0)
        var sector := Data.sector_at(z)
        if sector==1: _field(host,center,z,index,vp)
        elif sector==0: _forest(host,center,z,index,vp)
        elif sector==4: _city(host,center,z,index,vp)
    _bridge(host,vp)
    _tunnel(host,vp)
    _route_boards(host,vp)
func _field(host: Node2D,center: float,z: float,index: int,vp: Vector2) -> void:
    for side: float in [-1,1]:
        for row in range(4):
            var x := center+side*(8.8+row*6.0)
            var dist := z-float(host.player_car.world_z)
            var depth: float=host._world_to_camera(x-host._camera_world_x(host.player_car.track_phase()),dist+host._behind()).y
            if depth<1: continue
            var scale_: float=host._camera_projection_scale(depth)*vp.x*.75
            var p: Vector2=host.project_ground(x,dist,vp)
            var fog := smoothstep(70,550,dist)
            var tint := Color("aa9f6c").lerp(Color("344852"),fog)
            host._draw_billboard(wheat,p.x,p.y,scale_*6.4,scale_*1.35,tint)
        # Warm timber fence gives fields a clear depth cue beside the asphalt.
        var nx: float=host._smooth_track_x((z+16)/40.0)+side*7.8
        var x := center+side*7.8
        var tint := Color("968375").lerp(Color("2b4050"),smoothstep(60,500,z-float(host.player_car.world_z)))
        line(host,Vector3(x,0,z),Vector3(x,1.15,z),tint,.12,vp)
        for h: float in [.43,.88]: line(host,Vector3(x,h,z),Vector3(nx,h,z+16),tint,.09,vp)
func _forest(host: Node2D,center: float,z: float,index: int,vp: Vector2) -> void:
    for side: float in [-1,1]:
        for row in range(2):
            var x := center+side*(12+row*12+sin(index*1.74+row)*2.0)
            var dist := z-float(host.player_car.world_z)
            var depth: float=host._world_to_camera(x-host._camera_world_x(host.player_car.track_phase()),dist+host._behind()).y
            if depth<1: continue
            var size_: float=host._camera_projection_scale(depth)*vp.x*.75
            var p: Vector2=host.project_ground(x,dist,vp)
            var tex: Texture2D=host.pine_texture if (index+row)%3!=0 else host.oak_texture
            var height := 10.0+sin(index*.75+row)*2.0
            host._draw_billboard(tex,p.x,p.y,size_*8.0,size_*height,Color("80998c").lerp(Color("263d50"),smoothstep(90,600,dist)))
        # Varied ferns/tufts are visible as part of the verge, rather than an
        # empty dark plane. Silhouettes use the authored wheat cutout sparsely.
        if index%2==0:
            var x := center+side*7.2
            var p: Vector2=host.project_ground(x,z-float(host.player_car.world_z),vp)
            var size_: float=host._camera_projection_scale(z-float(host.player_car.world_z)+host._behind())*vp.x*.75
            host._draw_billboard(wheat,p.x,p.y,size_*2.5,size_*.75,Color("607b6b"))
func _city(host: Node2D,center: float,z: float,index: int,vp: Vector2) -> void:
    if index%3!=0: return
    for side: float in [-1,1]:
        var x := center+side*12.0
        var dist := z-float(host.player_car.world_z)
        var depth: float=host._world_to_camera(x-host._camera_world_x(host.player_car.track_phase()),dist+host._behind()).y
        if depth<1: continue
        var scale_: float=host._camera_projection_scale(depth)*vp.x*.75
        var p: Vector2=host.project_ground(x,dist,vp)
        host._draw_billboard(host.lamp_texture,p.x,p.y,scale_*1.8,scale_*8.0,Color("b5c1c8"))
        var head := project(host,x,z,7.2,vp)
        host.draw_circle(head,maxf(1.4,scale_*.11),Color("ffe1a8"))
        host.draw_circle(head,maxf(2,scale_*.27),Color(1,.74,.36,.09))
        # Plane trees and planted roadside beds soften the city approach.
        if index%6==0: host._draw_billboard(host.oak_texture,p.x+side*scale_*4,p.y,scale_*7.8,scale_*10.0,Color("7b9182"))
func _bridge(host: Node2D,vp: Vector2) -> void:
    var origin: float=host.player_car.world_z
    var first := maxi(130,floori((origin-4)/16.0))
    var last := mini(169,ceili((origin+680)/16.0))
    for index in range(last,first-1,-1):
        var z := maxf(index*16.0,origin-4.6)
        var next_z := minf((index+1)*16.0,2720.0)
        if z-origin+host._behind()<.8: continue
        var center: float=host._smooth_track_x(z/40.0)
        var next_center: float=host._smooth_track_x(next_z/40.0)
        var fog := smoothstep(100,680,z-origin)
        var steel := Color("728b9a").lerp(Color("253f52"),fog)
        for side: float in [-1,1]:
            var x := center+side*5.5
            var nx := next_center+side*5.5
            surface(host,[Vector3(x,0,z),Vector3(nx,0,next_z),Vector3(nx,.48,next_z),Vector3(x,.48,z)],Color("526a7c").lerp(Color("233e51"),fog),vp)
            for h: float in [.72,1.15]: line(host,Vector3(x,h,z),Vector3(nx,h,next_z),steel,.065,vp)
            line(host,Vector3(x,.45,z),Vector3(x,1.22,z),steel,.085,vp)
            if index%2==0:
                line(host,Vector3(x,1.15,z),Vector3(x,1.15,z+1.1),Color("eed8a3"),.12,vp)
        # A tied-arch bridge: repeated steel portals and longitudinal stringers.
        if index%4==2:
            for side: float in [-1,1]:
                var x := center+side*6.0
                line(host,Vector3(x,0,z),Vector3(x,6.8,z),steel,.27,vp)
                line(host,Vector3(x,6.8,z),Vector3(center+side*3.6,9.2,z),steel,.27,vp)
                line(host,Vector3(center+side*3.6,9.2,z),Vector3(center,9.8,z),steel,.27,vp)
                var far_center: float=host._smooth_track_x((z+64)/40.0)
                if z+64<2720:
                    line(host,Vector3(x,6.8,z),Vector3(far_center+side*6,6.8,z+64),steel,.18,vp)
                    line(host,Vector3(x,1,z),Vector3(far_center+side*6,6.8,z+64),steel,.10,vp)
func _tunnel(host: Node2D,vp: Vector2) -> void:
    var origin: float=host.player_car.world_z
    var first := maxi(170,floori((origin-4.0)/16.0))
    var last := mini(219,ceili((origin+720.0)/16.0))
    for index in range(last,first-1,-1):
        var z := maxf(index*16.0,origin-4.6)
        var nz := minf((index+1)*16.0,3520.0)
        if z-origin+host._behind()<.6: continue
        var center: float=host._smooth_track_x(z/40.0)
        var nc: float=host._smooth_track_x(nz/40.0)
        # An actual continuous projected cross-section. Walls/roof cannot
        # randomly vanish at the current segment boundary.
        for arc in range(8):
            var a := float(arc)*PI/8
            var b := float(arc+1)*PI/8
            var x1 := cos(a)*6.1;var y1 := .2+sin(a)*5.9
            var x2 := cos(b)*6.1;var y2 := .2+sin(b)*5.9
            var shade := Color("192730") if arc in [2,3,4,5] else Color("37454d")
            if index%2==0: shade=shade.lightened(.035)
            surface(host,[Vector3(center+x1,y1,z),Vector3(nc+x1,y1,nz),Vector3(nc+x2,y2,nz),Vector3(center+x2,y2,z)],shade,vp)
            line(host,Vector3(center+x1,y1,z),Vector3(center+x2,y2,z),Color("586267"),.065,vp)
        for side: float in [-1,1]:
            for h: float in [.18,.70,1.05]: line(host,Vector3(center+side*6.0,h,z),Vector3(nc+side*6.0,h,nz),Color("627074") if h>.5 else Color("ccb681"),.065,vp)
            var lamp := project(host,center+side*4.5,z,4.0,vp)
            var depth: float = z-origin+host._behind()
            var size_: float = host._camera_projection_scale(depth)*vp.x*.75
            host.draw_line(lamp-Vector2(size_*.22,0),lamp+Vector2(size_*.22,0),Color("ffe2ad"),maxf(1,size_*.05),true)
            host.draw_circle(lamp,maxf(2,size_*.23),Color(1,.76,.4,.07))
    # Heavy stone portals frame both ends. The near entrance is only culled
    # after its entire visible arch has moved past the camera.
    for z: float in [2720.0,3520.0]:
        var dist := z-origin
        if dist+host._behind()<.6 or dist>850: continue
        var c: float=host._smooth_track_x(z/40)
        var rim := Color("8a9696").lerp(Color("344b58"),smoothstep(120,850,dist))
        for side: float in [-1,1]:
            surface(host,[Vector3(c+side*6.1,0,z),Vector3(c+side*9,0,z),Vector3(c+side*9,8,z),Vector3(c+side*6.1,6.1,z)],rim,vp)
        surface(host,[Vector3(c-9,8,z),Vector3(c+9,8,z),Vector3(c+6.1,6.1,z),Vector3(c-6.1,6.1,z)],rim.darkened(.2),vp)
func _route_boards(host: Node2D,vp: Vector2) -> void:
    for sector in range(1,5):
        var z: float=Data.SECTOR_STARTS[sector]-140.0
        var dist := z-float(host.player_car.world_z)
        if dist+host._behind()<.7 or dist>420: continue
        var center: float=host._smooth_track_x(z/40)
        var x := center+7.2
        var p := project(host,x,z,2.4,vp)
        var size_: float=host._camera_projection_scale(dist+host._behind())*vp.x*.75
        line(host,Vector3(x,0,z),Vector3(x,2.45,z),Color("8a9c9c"),.09,vp)
        var rect := Rect2(p-Vector2(1.3,.48)*size_,Vector2(2.6,.96)*size_)
        if not rect.intersects(Rect2(Vector2.ZERO,vp)): continue
        host.draw_style_box(_board_style(),rect)
        if size_>10:
            var font := ThemeDB.fallback_font
            var label: String=["","ПОЛЯ  140м","МОСТ  140м","ТОННЕЛЬ  140м","ГОРОД  140м"][sector]
            host.draw_string(font,p+Vector2(-1.1,.10)*size_,label,HORIZONTAL_ALIGNMENT_LEFT,2.3*size_,maxi(8,roundi(size_*.22)),Color("d9e7d7"))
var _style: StyleBoxFlat
func _board_style() -> StyleBoxFlat:
    if _style==null:
        _style=StyleBoxFlat.new();_style.bg_color=Color("264b49");_style.border_color=Color("a1beb0");_style.set_border_width_all(1);_style.set_corner_radius_all(2)
    return _style
