extends RefCounted
# Authored once into the existing atlas mesh; no extra scene nodes/viewports.
const Data=preload("res://scripts/race_level_data.gd")
var batch
var host
var center := 0.0
var at := 0.0
var side := 1.0
var frontage := 15.0
var signature: Dictionary={}

func build(scenery,renderer,z: float,index: int,side_: float) -> Dictionary:
    batch=scenery;host=renderer;side=side_
    var seed_ := posmod(index*index*31+index*113+(487 if side<0 else 1009),4093)
    at=z+(-12 if side<0 else 17)+sin(seed_*.73)*6
    center=host._smooth_track_x(at/40)
    frontage=12.5+posmod(seed_,5)*1.45
    var kind := posmod(seed_/3,7)
    var shop := kind in [0,2,5]
    var half := 5.0+posmod(seed_/5,5)*.65
    var depth := 7.0+posmod(seed_/11,4)*1.7
    var floors := 1 if shop else (1 if kind==1 else 2)
    var height := (3.8 if shop else 3.0*floors)+posmod(seed_/7,3)*.22
    var wall: Color=[Color("977d64"),Color("768c86"),Color("80758e"),Color("a28c72"),Color("66818d"),Color("9b7973"),Color("78826a")][posmod(seed_,7)]
    var roof: Color=[Color("394652"),Color("65454a"),Color("425951"),Color("675b49")][posmod(seed_/2,4)]
    var variant := posmod(seed_/4,8)
    signature={"z":at,"side":side,"frontage":frontage,"half":half,"depth":depth,"floors":floors,"kind":kind,"variant":variant,"wall":wall,"roof":roof}
    # Paved yard, path, plinth and receding walls before all facade details.
    _quad([Vector3(-4,.025,-half-2),Vector3(depth+.7,.025,-half-2),Vector3(depth+.7,.025,half+2),Vector3(-4,.025,half+2)],Color("4a565a"))
    _quad([Vector3(4.9-frontage,.04,-1),Vector3(.2,.04,-1),Vector3(.2,.04,1),Vector3(4.9-frontage,.04,1)],Color("7b8279"))
    _box(Vector3(0,0,-half),Vector3(depth,.32,half),Color("59625e"))
    _box(Vector3(0,.32,-half),Vector3(depth,height,half),wall)
    for y: float in [.38,height-.18]: _line(Vector3(-.025,y,-half),Vector3(-.025,y,half),Color("c4b9a0"),.10)
    if shop:
        _shop(half,depth,height,variant,seed_,wall)
    else:
        _home(half,depth,height,floors,kind,seed_,roof,wall)
    _end_facade(half,depth,height,floors,shop,variant,seed_,wall)
    _yard(half,depth,shop,kind,seed_)
    return signature

func _end_facade(half: float,depth: float,height: float,floors: int,shop: bool,variant: int,seed_: int,wall: Color) -> void:
    var face_z := -half-.07
    for y: float in [.40,height-.18]: _line(Vector3(.04,y,face_z),Vector3(depth-.04,y,face_z),wall.lightened(.28),.10)
    for x: float in [.15,depth-.15]: _line(Vector3(x,.4,face_z),Vector3(x,height,face_z),wall.lightened(.22),.15)
    for floor_ in range(floors):
        for i in range(3):
            var x := depth*(.22+i*.28)
            var y := .9+floor_*3
            var width := depth*.19
            var glow := Color("62868f") if shop else (Color("e1bc87") if (seed_+i+floor_)%3 else Color("344d5e"))
            _quad([Vector3(x-width*.5,y,face_z-.015),Vector3(x+width*.5,y,face_z-.015),Vector3(x+width*.5,y+1.65,face_z-.015),Vector3(x-width*.5,y+1.65,face_z-.015)],glow)
            for h: float in [y-.06,y+.85,y+1.7]: _line(Vector3(x-width*.5-.06,h,face_z-.04),Vector3(x+width*.5+.06,h,face_z-.04),Color("b1b6a6"),.055)
            _line(Vector3(x,y,face_z-.04),Vector3(x,y+1.65,face_z-.04),Color("909a97"),.065)
    if shop:
        var ids := PackedInt32Array()
        for p in [Vector3(.7,2.95,face_z-.07),Vector3(depth-.7,2.95,face_z-.07),Vector3(depth-.7,3.75,face_z-.07),Vector3(.7,3.75,face_z-.07)]: ids.append(batch._point(_world(p)))
        batch._group.boards.append({"ids":ids,"left":center+side*(frontage+(.7 if side>0 else depth-.7)),"top":Data.road_height(at)+3.75,"width":depth-1.4,"height":.80,"row":-variant-1,"region":batch.atlas_region(Rect2(1024,544+variant*112,1024,112))})

func _world(p: Vector3) -> Vector3:
    return Vector3(center+side*(frontage+p.x),p.y,at+p.z)
func _quad(points: Array[Vector3],color: Color,normal: Vector3=Vector3.ZERO) -> void:
    var previous: bool=batch.author_detail
    if (points[1]-points[0]).length()*(points[-1]-points[0]).length()<.5: batch.author_detail=true
    var world: Array[Vector3]=[]
    for p in points: world.append(_world(p))
    batch.surface(host,world,color,Vector2.ZERO,Vector3(normal.x*side,normal.y,normal.z))
    batch.author_detail=previous
func _line(a: Vector3,b: Vector3,color: Color,width: float=.07) -> void:
    var previous: bool=batch.author_detail;batch.author_detail=true
    batch.line(host,_world(a),_world(b),color,width,Vector2.ZERO)
    batch.author_detail=previous
func _box(a: Vector3,b: Vector3,color: Color) -> void:
    var previous: bool=batch.author_detail
    var extent := b-a
    if extent.x<2 and extent.y<1.5 and extent.z<4: batch.author_detail=true
    _quad([Vector3(b.x,a.y,a.z),Vector3(b.x,a.y,b.z),Vector3(b.x,b.y,b.z),Vector3(b.x,b.y,a.z)],color.darkened(.18),Vector3.RIGHT)
    for u: float in [a.z,b.z]: _quad([Vector3(a.x,a.y,u),Vector3(b.x,a.y,u),Vector3(b.x,b.y,u),Vector3(a.x,b.y,u)],color.darkened(.12 if u==b.z else .24),Vector3(0,0,-1 if u==a.z else 1))
    _quad([Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z)],color.lightened(.08),Vector3.UP)
    _quad([Vector3(a.x,a.y,a.z),Vector3(a.x,a.y,b.z),Vector3(a.x,b.y,b.z),Vector3(a.x,b.y,a.z)],color,Vector3.LEFT)
    batch.author_detail=previous
func _window(u: float,y: float,width: float,height: float,seed_: int,shutters: bool=false) -> void:
    var lit := posmod(seed_,4)!=0
    _quad([Vector3(-.055,y-.10,u-width*.5-.10),Vector3(-.055,y-.10,u+width*.5+.10),Vector3(-.055,y+height+.10,u+width*.5+.10),Vector3(-.055,y+height+.10,u-width*.5-.10)],Color("c0b79f"))
    var glass := Color("dfbd84") if lit else Color("304957")
    _quad([Vector3(-.08,y,u-width*.5),Vector3(-.08,y,u+width*.5),Vector3(-.08,y+height,u+width*.5),Vector3(-.08,y+height,u-width*.5)],glass)
    for edge: float in [-1,1]:
        _line(Vector3(-.09,y,u+edge*width*.36),Vector3(-.09,y+height,u+edge*width*.36),Color("74685f"),.09)
        if shutters:
            _box(Vector3(-.13,y-.08,u+edge*(width*.5+.35)-.18),Vector3(-.08,y+height+.08,u+edge*(width*.5+.35)+.18),Color("45635f"))
    _line(Vector3(-.10,y,u),Vector3(-.10,y+height,u),Color("596169"),.055)
    _line(Vector3(-.10,y+height*.55,u-width*.5),Vector3(-.10,y+height*.55,u+width*.5),Color("596169"),.055)
    _box(Vector3(-.25,y-.16,u-width*.55),Vector3(-.04,y-.07,u+width*.55),Color("b4b0a0"))

func _home(half: float,depth: float,height: float,floors: int,kind: int,seed_: int,roof: Color,wall: Color) -> void:
    var ridge := height+1.6+posmod(seed_/13,4)*.25
    if kind==6:
        _box(Vector3(-.45,height-.05,-half-.45),Vector3(depth+.45,height+.42,half+.45),roof)
        _box(Vector3(depth*.65,height+.42,-half*.5),Vector3(depth*.65+1.3,height+1.25,-half*.5+1),Color("879391"))
    else:
        _quad([Vector3(-.4,height,-half-.45),Vector3(-.4,height,half+.45),Vector3(-.4,ridge,0)],wall.lightened(.05))
        for edge: float in [-1,1]:
            _quad([Vector3(-.45,height,edge*(half+.5)),Vector3(depth+.45,height,edge*(half+.5)),Vector3(depth+.45,ridge,0),Vector3(-.45,ridge,0)],roof.darkened(.2 if edge>0 else 0))
            for strip in range(1,4):
                var u := edge*(half+.5)*strip/4
                var y := lerpf(ridge,height,float(strip)/4)+.03
                _line(Vector3(-.42,y,u),Vector3(depth+.4,y,u),roof.lightened(.14),.045)
        _box(Vector3(depth*.65,height,-half*.4),Vector3(depth*.65+.9,ridge+.6,-half*.4+.75),Color("725953"))
        _window(0,height+.15,1.05,.70,seed_+17)
    var count := 3 if half>6 else 2
    for floor_ in range(floors):
        for i in range(count):
            var u := lerpf(-half+1.4,half-1.4,float(i)/maxf(count-1,1))
            if floor_==0 and absf(u)<1.4: continue
            _window(u,1.0+floor_*3,1.25+posmod(seed_,3)*.14,1.45,seed_+i+floor_*7,kind in [1,3])
    var door_u := -.8 if seed_%2 else 1.0
    _box(Vector3(-.14,.35,door_u-.65),Vector3(-.06,2.65,door_u+.65),Color("33464d"))
    _window(door_u,1.6,.7,.6,seed_+3)
    for step in range(3): _box(Vector3(-1.7+step*.4,.03,door_u-1.2),Vector3(-.15,.12+step*.1,door_u+1.2),Color("777c73"))
    _box(Vector3(-2.0,2.65,door_u-1.6),Vector3(.15,2.88,door_u+1.6),roof)
    for edge: float in [-1,1]: _line(Vector3(-1.6,.12,door_u+edge*1.3),Vector3(-1.6,2.72,door_u+edge*1.3),Color("bdafa0"),.13)
    if floors==2 and kind==4:
        _box(Vector3(-1.5,3.05,-2),Vector3(-.02,3.26,2),Color("7b8685"))
        for u: float in [-2,-1,0,1,2]: _line(Vector3(-1.45,3.26,u),Vector3(-1.45,4.05,u),Color("839a9a"),.055)
        _line(Vector3(-1.45,4.05,-2),Vector3(-1.45,4.05,2),Color("a1b0a9"),.07)
    # Visible side window, utilities and a porch lamp.
    var end := -half-.06
    _quad([Vector3(depth*.45,1.2,end),Vector3(depth*.45+1.5,1.2,end),Vector3(depth*.45+1.5,2.6,end),Vector3(depth*.45,2.6,end)],Color("cdb78b"))
    _box(Vector3(-.22,2.2,door_u+1.15),Vector3(-.08,2.7,door_u+1.45),Color("f4d497"))
    _box(Vector3(-.18,.8,half-1.1),Vector3(-.06,1.25,half-.7),Color("718182"))

func _shop(half: float,depth: float,height: float,variant: int,seed_: int,wall: Color) -> void:
    var neon: Color=[Color("6ff2bc"),Color("fb90be"),Color("7ddcf3"),Color("91e797"),Color("efafd6"),Color("f5c879"),Color("a9a0ff"),Color("f0a070")][variant]
    _box(Vector3(-.4,height,-half-.35),Vector3(depth+.35,height+.4,half+.35),wall.darkened(.35))
    _box(Vector3(depth*.6,height+.4,half*.25),Vector3(depth*.6+1.7,height+1.0,half*.25+1.2),Color("8d9795"))
    var door_u := -half*.55 if variant%2 else half*.5
    for u: float in [-half*.65,0,half*.65]:
        if absf(u-door_u)<1.3: continue
        var w := half*.49
        _quad([Vector3(-.05,.48,u-w*.5),Vector3(-.05,.48,u+w*.5),Vector3(-.05,2.8,u+w*.5),Vector3(-.05,2.8,u-w*.5)],Color("47717a").lerp(neon,.18))
        # Shelves and individual display stock sit behind glass mullions.
        for row in range(2):
            _line(Vector3(-.07,.9+row*.8,u-w*.43),Vector3(-.07,.9+row*.8,u+w*.43),Color("c7bca6"),.10)
            for item in range(3):
                var stock_u := u+(item-1)*w*.26
                _quad([Vector3(-.08,1.02+row*.8,stock_u-.14),Vector3(-.08,1.02+row*.8,stock_u+.14),Vector3(-.08,1.37+row*.8,stock_u+.14),Vector3(-.08,1.37+row*.8,stock_u-.14)],[Color("daaf82"),Color("b5d1ad"),Color("dd98ac")][posmod(seed_+item+row,3)])
        _line(Vector3(-.10,.48,u),Vector3(-.10,2.8,u),Color("aeb9b4"),.08)
    _box(Vector3(-.12,.14,door_u-.62),Vector3(-.04,2.7,door_u+.62),Color("72929a"))
    _line(Vector3(-.15,1.2,door_u+.37),Vector3(-.15,1.7,door_u+.37),Color("e7d9b5"),.055)
    # Street-facing neon reads along the road, using the authored atlas region.
    var ids := PackedInt32Array()
    for p in [Vector3(-.15,2.95,-half+.15),Vector3(-.15,2.95,half-.15),Vector3(-.15,3.75,half-.15),Vector3(-.15,3.75,-half+.15)]: ids.append(batch._point(_world(p)))
    batch._group.boards.append({"ids":ids,"left":at+(half-.15 if side>0 else -half+.15),"top":Data.road_height(at)+3.75,"width":(half*2-.3)*(-1 if side>0 else 1),"height":.80,"row":-variant-1,"axis":"z","region":batch.atlas_region(Rect2(1024,544+variant*112,1024,112))})
    if variant in [0,1,4,5,7]:
        for stripe in range(8):
            var a := -half+stripe*half*.25
            _quad([Vector3(-.16,2.86,a),Vector3(-1.8,2.42,a),Vector3(-1.8,2.42,a+half*.25),Vector3(-.16,2.86,a+half*.25)],neon.darkened(.20) if stripe%2 else Color("cec7ac"))
            _quad([Vector3(-1.8,2.42,a),Vector3(-1.8,2.2,a),Vector3(-1.8,2.2,a+half*.25),Vector3(-1.8,2.42,a+half*.25)],neon.darkened(.35))
    elif variant==2:
        _box(Vector3(-.20,.1,-half+1),Vector3(-.06,2.85,-half+4.8),Color("4a545b"))
        for y: float in [.7,1.2,1.7,2.2]: _line(Vector3(-.22,y,-half+1),Vector3(-.22,y,-half+4.8),Color("81969e"),.075)
        _box(Vector3(-2.5,.05,half+1),Vector3(-1.5,.85,half+1.8),Color("546570"))
    else:
        _line(Vector3(-.15,2.88,-half),Vector3(-.15,2.88,half),neon,.09)
    for edge: float in [-1,1]:
        _box(Vector3(-.16,.05,edge*half-.12),Vector3(-.06,height,edge*half+.12),wall.lightened(.18))
    # Warm entry light, steps, bollards and a pavement display board.
    _box(Vector3(-1.1,.03,door_u-.9),Vector3(-.1,.18,door_u+.9),Color("9c9e8a"))
    _line(Vector3(-3,0,-half-.6),Vector3(-3,.85,-half-.6),neon,.15)
    _box(Vector3(-3.4,.1,half+.7),Vector3(-3.1,1.25,half+1.65),Color("263f47"))
    for i in range(3): _line(Vector3(-3.42,.85+i*.12,half+.85),Vector3(-3.42,.85+i*.12,half+1.5),neon,.035)

func _yard(half: float,depth: float,shop: bool,kind: int,seed_: int) -> void:
    if shop:
        for u: float in [-half*.55,half*.55]:
            for edge: float in [-1,1]: _line(Vector3(-4,.055,u+edge*1.05),Vector3(-2,.055,u+edge*1.05),Color("a7ad99"),.09)
        if kind==2:
            for u: float in [-half-2,half+2]:
                _box(Vector3(-3,.04,u-.75),Vector3(-2.1,.55,u+.75),Color("8b6c5b"))
                _box(Vector3(-2.9,.55,u-.65),Vector3(-2.2,.92,u+.65),Color("638361"))
        else:
            _box(Vector3(-3.4,.04,-half-1.7),Vector3(-2.4,.75,-half-1.0),Color("3e6561"))
            if seed_%2:
                _box(Vector3(-3.5,.50,half+1),Vector3(-2.5,.67,half+3),Color("9a876b"))
                for u: float in [half+1.2,half+2.8]: _line(Vector3(-3.3,0,u),Vector3(-3.3,.55,u),Color("445b60"),.10)
    else:
        var fence := Color("718376") if seed_%2 else Color("a8997f")
        var yard_front := -4.0
        for u in range(-int(half)-2,int(half)+3,2):
            if absf(u)<2: continue
            _line(Vector3(yard_front,0,u),Vector3(yard_front,.95,u),fence,.11)
        for edge: float in [-1,1]:
            for y: float in [.35,.75]: _line(Vector3(yard_front,y,edge*2),Vector3(yard_front,y,edge*(half+2)),fence,.08)
            _line(Vector3(yard_front,.75,edge*(half+2)),Vector3(depth,.75,edge*(half+2)),fence,.08)
        _box(Vector3(-4.35,.8,half+1),Vector3(-3.95,1.15,half+1.65),Color("7b8e92"))
        _line(Vector3(-4.15,0,half+1.3),Vector3(-4.15,.8,half+1.3),Color("66777b"),.10)
        var tree := _world(Vector3(depth*.5,0,half+4))
        batch._sprite(tree,host.oak_texture,5.5,7.5+kind*.3,Color("879d85"))
        for u: float in [-half+1,half-1]:
            _box(Vector3(-2.6,.03,u-.7),Vector3(-1.8,.42,u+.7),Color("756655"))
            _box(Vector3(-2.5,.42,u-.6),Vector3(-1.9,.65,u+.6),Color("698768"))
            for flower in range(3): _line(Vector3(-2.3,.67,u-.4+flower*.4),Vector3(-2.3,.82,u-.4+flower*.4),Color("cfafa1") if seed_%2 else Color("d0c387"),.15)
