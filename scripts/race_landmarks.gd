extends RefCounted
# Static, textured architecture. Interior detail and neon falloff are baked;
# only silhouettes, real overhangs, supports and yard props need geometry.
const Data=preload("res://scripts/race_level_data.gd")
var batch
var host
var center := 0.0
var at := 0.0
var side := 1.0
var frontage := 13.0
var base_y := 0.0
var tile := 0

func build_landmark(scenery,renderer,z: float,side_: float,kind: String) -> Dictionary:
    batch=scenery;host=renderer;at=z;side=side_
    center=host._smooth_track_x(z/40)
    tile=["ranger","camp","farm","grain","lookout","forest_stop","fuel","diner"].find(kind)
    frontage=27 if kind=="lookout" else (16 if kind=="farm" else 13)
    var half: float={"ranger":14,"camp":18,"farm":24,"grain":19,"lookout":9,"forest_stop":15,"fuel":23,"diner":20}[kind]
    var depth: float={"ranger":12,"camp":20,"farm":22,"grain":18,"lookout":10,"forest_stop":12,"fuel":26,"diner":17}[kind]
    for dz in range(-int(half),int(half)+1,4):
        frontage=maxf(frontage,12+side*(host._smooth_track_x((z+dz)/40)-center))
    base_y=Data.ground_height(frontage+3,z)
    var first_face: int=batch._group.faces.size()
    var first_point: int=batch._group.points.size()
    batch.author_ground_clip=true
    match kind:
        "ranger": _ranger()
        "camp": _camp()
        "farm": _farm()
        "grain": _grain()
        "lookout": _lookout()
        "forest_stop": _forest_stop()
        "fuel": _fuel()
        "diner": _diner()
    batch.author_ground_clip=false
    var x1 := center+side*(frontage-3);var x2 := center+side*(frontage+depth)
    return {"z":z,"sector":Data.sector_at(z),"kind":kind,"side":side,"material":tile,"faces":batch._group.faces.size()-first_face,"points":batch._group.points.size()-first_point,"bounds":Rect2(minf(x1,x2),at-half,absf(x2-x1),half*2)}

func _world(p: Vector3) -> Vector3:
    return Vector3(center+side*(frontage+p.x),base_y+p.y-Data.road_height(at+p.z),at+p.z)
func _normal(n: Vector3) -> Vector3: return Vector3(n.x*side,n.y,n.z)
func _quad(points: Array[Vector3],color: Color,normal: Vector3=Vector3.ZERO) -> void:
    var world: Array[Vector3]=[]
    for p in points: world.append(_world(p))
    batch.surface(host,world,color,Vector2.ZERO,_normal(normal))
func _skin(points: Array[Vector3],region: Rect2,normal: Vector3=Vector3.ZERO,tint: Color=Color.WHITE) -> void:
    var world: Array[Vector3]=[]
    for p in points: world.append(_world(p))
    batch.textured_surface(world,region,tint,_normal(normal))
func _line(a: Vector3,b: Vector3,color: Color,width: float=.08,detail: bool=true) -> void:
    batch.author_detail=detail
    batch.line(host,_world(a),_world(b),color,width,Vector2.ZERO)
    batch.author_detail=false
func _box(a: Vector3,b: Vector3,color: Color) -> void:
    _quad([Vector3(a.x,a.y,a.z),Vector3(a.x,a.y,b.z),Vector3(a.x,b.y,b.z),Vector3(a.x,b.y,a.z)],color,Vector3.LEFT)
    _quad([Vector3(b.x,a.y,b.z),Vector3(b.x,a.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,b.y,b.z)],color.darkened(.3),Vector3.RIGHT)
    for u: float in [a.z,b.z]: _quad([Vector3(a.x,a.y,u),Vector3(b.x,a.y,u),Vector3(b.x,b.y,u),Vector3(a.x,b.y,u)],color.darkened(.16),Vector3(0,0,-1 if u==a.z else 1))
    _skin([Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z)],_material(0),Vector3.UP)
func _facade(crop: Rect2=Rect2(0,0,1,1)) -> Rect2:
    var pixels := Rect2((tile%2)*768+4,1536+(tile/2)*256+4,760,248)
    return batch.atlas_region(Rect2(pixels.position+pixels.size*crop.position,pixels.size*crop.size))
func _material(index: int) -> Rect2:
    return batch.atlas_region(Rect2(1538,1538+index*256,508,252))
func _street(x: float,u: float,half: float,low: float,high: float,region: Rect2) -> void:
    # Subdivide long walls to keep affine texture interpolation unobtrusive
    # on close oblique approaches. End walls are separate physical surfaces.
    for part in range(4):
        var a := u+lerpf(-half,half,float(part)/4)*(-side)
        var b := u+lerpf(-half,half,float(part+1)/4)*(-side)
        var uv := Rect2(region.position+Vector2(region.size.x*part/4,0),Vector2(region.size.x/4,region.size.y))
        _skin([Vector3(x,low,a),Vector3(x,low,b),Vector3(x,high,b),Vector3(x,high,a)],uv,Vector3.LEFT)
func _hall(x: float,u: float,depth: float,half: float,low: float,height: float) -> void:
    _street(x,u,half,low,low+height,_facade())
    for edge: float in [-1,1]:
        _skin([Vector3(x,low,u+edge*half),Vector3(x+depth,low,u+edge*half),Vector3(x+depth,low+height,u+edge*half),Vector3(x,low+height,u+edge*half)],_facade(Rect2(.04,.18,.42,.82)),Vector3(0,0,edge))
    _quad([Vector3(x+depth,low,u-half),Vector3(x+depth,low,u+half),Vector3(x+depth,low+height,u+half),Vector3(x+depth,low+height,u-half)],Color("253440"),Vector3.RIGHT)
    _roof(x-.6,u,depth+1.2,half+.6,low+height,.28)
func _roof(x: float,u: float,depth: float,half: float,y: float,thickness: float) -> void:
    _box(Vector3(x,y,u-half),Vector3(x+depth,y+thickness,u+half),Color("172532"))
    _street(x-.01,u,half,y,y+thickness,_facade(Rect2(0,.03,1,.18)))
func _label(u: float,y: float,width: float,height: float,row: int,x: float=0) -> void:
    var ids := PackedInt32Array()
    for p in [Vector3(x,y,u-width*.5),Vector3(x,y,u+width*.5),Vector3(x,y+height,u+width*.5),Vector3(x,y+height,u-width*.5)]: ids.append(batch._point(_world(p)))
    batch._group.boards.append({"ids":ids,"left":at+u+(width*.5 if side>0 else -width*.5),"top":base_y+y+height,"width":width*(-1 if side>0 else 1),"height":height,"row":0,"axis":"z","ground_clip":true,"region":batch.atlas_region(Rect2(0,1056+row*48,1024,48))})
func _pad(half: float,depth: float) -> void:
    _skin([Vector3(-3,.04,-half),Vector3(depth,.04,-half),Vector3(depth,.04,half),Vector3(-3,.04,half)],_material(3),Vector3.UP,Color("809099"))
func _lamp(x: float,u: float,height: float=4.8) -> void:
    _line(Vector3(x,.08,u),Vector3(x,height,u),Color("384e62"),.13,false)
    _line(Vector3(x,height,u),Vector3(x-.9,height,u),Color("384e62"),.12,false)
    _line(Vector3(x-1.1,height-.05,u-.3),Vector3(x-1.1,height-.05,u+.3),Color("ffd49c"),.12,false)
func _bench(x: float,u: float) -> void:
    batch.author_detail=true
    _box(Vector3(x,.45,u-1.6),Vector3(x+.7,.62,u+1.6),Color("58606a"))
    for y: float in [.78,1.05]: _line(Vector3(x+.64,y,u-1.6),Vector3(x+.64,y,u+1.6),Color("9b8670"),.14)
    for edge: float in [-1,1]:
        _line(Vector3(x+.25,.04,u+edge*1.25),Vector3(x+.25,.5,u+edge*1.25),Color("253946"),.12)
        _line(Vector3(x+.64,.5,u+edge*1.25),Vector3(x+.64,1.15,u+edge*1.25),Color("354552"),.08)
    batch.author_detail=false
func _drum(x: float,u: float,radius: float,height: float) -> void:
    var cap: Array[Vector3]=[]
    for i in range(10):
        var a := i*TAU/10;var b := (i+1)*TAU/10
        var p := Vector3(x+cos(a)*radius,.12,u+sin(a)*radius)
        var q := Vector3(x+cos(b)*radius,.12,u+sin(b)*radius)
        _skin([p,q,q+Vector3.UP*height,p+Vector3.UP*height],_facade(Rect2(0,0,.16,1)),Vector3(cos((a+b)*.5),0,sin((a+b)*.5)),Color("9eabbc"))
        cap.append(p+Vector3.UP*height)
        _line(p+Vector3.UP*(height-.1),q+Vector3.UP*(height-.1),Color("8adce8"),.10)
        _quad([p+Vector3.UP*height,q+Vector3.UP*height,Vector3(x,height+1.5,u)],Color("294451"))
    _quad(cap,Color("253747"),Vector3.UP)

func _ranger() -> void:
    _pad(14,12)
    _box(Vector3(.7,.1,-8.6),Vector3(8,.32,8.6),Color("46505b"))
    _hall(1,0,6.5,8,.32,5.6)
    _label(0,4.65,10,.48,0,.97)
    _box(Vector3(1,.25,9.5),Vector3(6,1.05,12.5),Color("253947"))
    _bench(-1,-10);_bench(-1,10)
    _lamp(-1,-12);_lamp(8,11)
func _camp() -> void:
    _pad(18,20)
    for u: float in [-13,13]:
        _hall(11,u,5,3.5,.22,2.8)
        _skin([Vector3(10.5,3.1,u-3.9),Vector3(16.5,3.1,u-3.9),Vector3(16.5,4.4,u+3.9),Vector3(10.5,4.4,u+3.9)],_material(1),Vector3(0,7.8,-1.3).normalized())
    _hall(2,0,7,7.5,.25,4.7)
    _label(0,4.12,9,.42,1,1.96)
    _bench(-1,-5);_bench(-1,5)
    _lamp(-1,-12);_lamp(8,12)
func _farm() -> void:
    _pad(24,22)
    for u: float in [-17,17]: _hall(12,u,7,4,.22,3.8)
    _hall(3,0,12,11,.25,7.8)
    _label(0,4.62,12,.53,2,2.96)
    for edge: float in [-1,1]:
        _skin([Vector3(2.5,8.1,edge*11.6),Vector3(15.5,8.1,edge*11.6),Vector3(15.5,10.5,0),Vector3(2.5,10.5,0)],_material(1),Vector3(0,11.6,edge*2.4).normalized(),Color("b4a98d"))
    _box(Vector3(-2,.1,-12),Vector3(1,.4,12),Color("46505b"))
    _lamp(-1,-20,6);_lamp(-1,20,6)
func _grain() -> void:
    _pad(19,18)
    for u: float in [-10,0,10]: _drum(10,u,2.9,11.5)
    _hall(1,-5,5,6.5,.20,4.3)
    _label(-5,3.7,9,.4,3,.96)
    _lamp(-1,14,6)
func _lookout() -> void:
    _pad(9,10)
    for x: float in [2,7]:
        for u: float in [-4,4]: _box(Vector3(x-.18,.1,u-.18),Vector3(x+.18,9.7,u+.18),Color("324655"))
    for u: float in [-4,4]: _line(Vector3(2,.4,u),Vector3(7,9.5,u),Color("536c76"),.13,false)
    _box(Vector3(1.2,9.3,-5),Vector3(8,9.65,5),Color("3b4c5b"))
    _hall(1.3,0,6.6,5,9.65,3.9)
    _label(0,12.83,8,.38,4,1.26)
    _line(Vector3(.6,.2,-5.5),Vector3(.6,9.6,-5.5),Color("6adbe8"),.14,false)
    _lamp(-1,7)
func _forest_stop() -> void:
    _pad(15,12)
    _hall(2,0,8,7,.20,4.4)
    _label(0,3.85,10,.38,5,1.96)
    _skin([Vector3(-2,3.8,-10),Vector3(9,4.8,-10),Vector3(9,4.8,10),Vector3(-2,3.8,10)],_material(0),Vector3.UP)
    _quad([Vector3(-2,3.75,10),Vector3(9,4.75,10),Vector3(9,4.75,-10),Vector3(-2,3.75,-10)],Color("283542"),Vector3.DOWN)
    _line(Vector3(-2,3.8,-10),Vector3(-2,3.8,10),Color("79dbde"),.11,false)
    for u: float in [-10,10]: _box(Vector3(8.4,.1,u-.16),Vector3(8.7,4.8,u+.16),Color("344552"))
    _bench(-1,-5);_bench(-1,5);_lamp(-1,-13)
func _fuel() -> void:
    _pad(23,26)
    _hall(18,0,7,10,.20,4.6)
    _label(0,4.05,12,.44,6,17.96)
    _roof(-1.5,0,17,15,5.5,.62)
    _quad([Vector3(-1.5,5.48,15),Vector3(15.5,5.48,15),Vector3(15.5,5.48,-15),Vector3(-1.5,5.48,-15)],Color("263c4d"),Vector3.DOWN)
    _label(0,5.65,15,.32,6,-1.54)
    _line(Vector3(-1.56,5.56,-15),Vector3(-1.56,5.56,15),Color("6ef0ff"),.10,false)
    for u: float in [-15,15]: _line(Vector3(-1.5,5.56,u),Vector3(15.5,5.56,u),Color("59deec"),.10,false)
    for x: float in [2,13]:
        for u: float in [-11,11]: _box(Vector3(x-.22,.12,u-.22),Vector3(x+.22,5.5,u+.22),Color("304454"))
    for u: float in [-8,8]:
        _quad([Vector3(3,5.47,u-1.5),Vector3(10,5.47,u-1.5),Vector3(10,5.47,u+1.5),Vector3(3,5.47,u+1.5)],Color("cae1e4"),Vector3.DOWN)
        _box(Vector3(4.5,.10,u-2.2),Vector3(9.5,.28,u+2.2),Color("59616c"))
        for x: float in [5.2,8.2]:
            _box(Vector3(x,.28,u-.6),Vector3(x+.75,2.2,u+.6),Color("273c50"))
            var pump := (0 if u<0 else 2)+(0 if x<7 else 1)
            _skin([Vector3(x-.015,.28,u-.6),Vector3(x-.015,.28,u+.6),Vector3(x-.015,2.2,u+.6),Vector3(x-.015,2.2,u-.6)],batch.atlas_region(Rect2(1536+pump*128,2048,128,256)),Vector3.LEFT)
    _box(Vector3(-2,.15,-21),Vector3(-1.3,6.9,-17),Color("132839"))
    _label(-19,5.0,4,.48,6,-2.04);_label(-19,3.65,4,.40,8,-2.04)
    _lamp(12,-21,6.5);_lamp(12,21,6.5)
func _diner() -> void:
    _pad(20,17)
    _hall(2,0,9,10,.25,4.6)
    for edge: float in [-1,1]:
        _skin([Vector3(2,.25,edge*10),Vector3(4,.25,edge*12),Vector3(4,4.85,edge*12),Vector3(2,4.85,edge*10)],_facade(Rect2(.08,.12,.3,.88)),Vector3(-.707,0,.707*edge))
        _skin([Vector3(4,.25,edge*12),Vector3(11,.25,edge*12),Vector3(11,4.85,edge*12),Vector3(4,4.85,edge*12)],_facade(Rect2(.25,.12,.6,.88)),Vector3(0,0,edge))
    _skin([Vector3(1.5,5.15,-10),Vector3(3.5,5.15,-12.5),Vector3(11.5,5.15,-12.5),Vector3(11.5,5.15,12.5)],_material(0),Vector3.UP)
    _skin([Vector3(1.5,5.15,-10),Vector3(11.5,5.15,12.5),Vector3(3.5,5.15,12.5),Vector3(1.5,5.15,10)],_material(0),Vector3.UP)
    _label(0,4.21,13,.45,7,1.96)
    for y: float in [.35,4.85]: _line(Vector3(1.8,y,-10),Vector3(1.8,y,10),Color("ff78b7"),.09,false)
    _bench(-1,-6);_bench(-1,6);_lamp(-1,-17);_lamp(-1,17)
