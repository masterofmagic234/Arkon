extends "res://scripts/race_outskirts.gd"
# Distinct location architecture, authored into the same cached scenic mesh.
var base_y := 0.0
func build_landmark(scenery,renderer,z: float,side_: float,kind: String) -> Dictionary:
    batch=scenery;host=renderer;at=z;side=side_
    center=host._smooth_track_x(z/40)
    frontage=27 if kind=="lookout" else (16 if kind=="farm" else 13)
    var half: float={"ranger":14,"camp":15,"farm":24,"grain":18,"lookout":9,"forest_stop":15,"fuel":23,"diner":20}[kind]
    var depth: float={"ranger":12,"camp":13,"farm":22,"grain":17,"lookout":10,"forest_stop":12,"fuel":25,"diner":17}[kind]
    # Setback follows the whole frontage on bends, not only its middle.
    # Even the nearest yard edge remains beyond the driveable ribbon/rail.
    for dz in range(-int(half),int(half)+1,4):
        frontage=maxf(frontage,12+side*(host._smooth_track_x((z+dz)/40)-center))
    base_y=Data.ground_height(frontage+3,z)
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
    return {"z":z,"sector":Data.sector_at(z),"kind":kind,"side":side,"bounds":Rect2(minf(x1,x2),at-half,absf(x2-x1),half*2)}

func _world(p: Vector3) -> Vector3:
    # A level lot keeps its real elevation while the road below it changes.
    return Vector3(center+side*(frontage+p.x),base_y+p.y-Data.road_height(at+p.z),at+p.z)

func _label(u: float,y: float,width: float,height: float,row: int,x: float=0) -> void:
    var ids := PackedInt32Array()
    for p in [Vector3(x,y,u-width*.5),Vector3(x,y,u+width*.5),Vector3(x,y+height,u+width*.5),Vector3(x,y+height,u-width*.5)]: ids.append(batch._point(_world(p)))
    batch._group.boards.append({"ids":ids,"left":at+u+(width*.5 if side>0 else -width*.5),"top":base_y+y+height,"width":width*(-1 if side>0 else 1),"height":height,"row":0,"axis":"z","region":Rect2(0,(1056.0+row*48)/1536,.5,48.0/1536)})

func _end_label(x: float,u: float,y: float,width: float,height: float,row: int) -> void:
    var ids := PackedInt32Array()
    for p in [Vector3(x-width*.5,y,u),Vector3(x+width*.5,y,u),Vector3(x+width*.5,y+height,u),Vector3(x-width*.5,y+height,u)]: ids.append(batch._point(_world(p)))
    batch._group.boards.append({"ids":ids,"left":center+side*(frontage+x)-width*.5,"top":base_y+y+height,"width":width,"height":height,"row":0,"region":Rect2(0,(1056.0+row*48)/1536,.5,48.0/1536)})

func _pad(width: float,depth: float,color: Color) -> void:
    _quad([Vector3(-3,.04,-width),Vector3(depth,.04,-width),Vector3(depth,.04,width),Vector3(-3,.04,width)],color)
func _lamp(x: float,u: float,height: float=5) -> void:
    _line(Vector3(x,.06,u),Vector3(x,height,u),Color("78848b"),.13)
    _line(Vector3(x,height,u),Vector3(x-.9,height,u),Color("78848b"),.12)
    _box(Vector3(x-1.2,height-.15,u-.25),Vector3(x-.6,height+.06,u+.25),Color("f4d8a0"))
func _gable(x: float,u: float,depth: float,half: float,height: float,rise: float,color: Color) -> void:
    _quad([Vector3(x-.3,height,u-half-.4),Vector3(x-.3,height,u+half+.4),Vector3(x-.3,height+rise,u)],color.darkened(.18))
    for edge: float in [-1,1]:
        _quad([Vector3(x-.4,height,u+edge*(half+.5)),Vector3(x+depth+.4,height,u+edge*(half+.5)),Vector3(x+depth+.4,height+rise,u),Vector3(x-.4,height+rise,u)],color.darkened(.2 if edge>0 else 0))
func _cylinder(x: float,u: float,radius: float,low: float,high: float,color: Color) -> void:
    var cap: Array[Vector3]=[]
    for i in range(8):
        var a := i*TAU/8;var b := (i+1)*TAU/8
        var p := Vector3(x+cos(a)*radius,low,u+sin(a)*radius)
        var q := Vector3(x+cos(b)*radius,low,u+sin(b)*radius)
        _quad([p,q,q+Vector3.UP*(high-low),p+Vector3.UP*(high-low)],color.darkened(.07*(i%4)))
        cap.append(p+Vector3.UP*(high-low))
    _quad(cap,color.lightened(.08))
func _fence(width: float,depth: float,color: Color) -> void:
    for u in range(-int(width),int(width)+1,3):
        if absf(u)<3: continue
        _line(Vector3(-2,.05,u),Vector3(-2,1.35,u),color,.11)
    for edge: float in [-1,1]:
        for y: float in [.5,1.05]:
            _line(Vector3(-2,y,edge*3),Vector3(-2,y,edge*width),color,.09)
            _line(Vector3(-2,y,edge*width),Vector3(depth,y,edge*width),color,.09)
func _bench(x: float,u: float) -> void:
    _box(Vector3(x,.55,u-1.8),Vector3(x+.65,.75,u+1.8),Color("92765a"))
    _box(Vector3(x+.55,.75,u-1.8),Vector3(x+.75,1.25,u+1.8),Color("92765a"))
    for edge: float in [-1,1]: _line(Vector3(x+.25,.05,u+edge*1.5),Vector3(x+.25,.65,u+edge*1.5),Color("4c6369"),.13)

func _ranger() -> void:
    _pad(14,12,Color("4d594e"))
    # Steep A-frame timber ranger station, porch and a stacked firewood yard.
    _box(Vector3(1,.2,-5),Vector3(8,3.4,5),Color("795d46"))
    _gable(1,0,7,5,3.4,4.6,Color("385b53"))
    for y in range(1,7): _line(Vector3(.95,.25+y*.45,-5),Vector3(.95,.25+y*.45,5),Color("af8e63"),.10)
    _box(Vector3(.85,.2,-1),Vector3(.98,2.8,1),Color("38484a"))
    for u: float in [-3.5,3.5]:
        _quad([Vector3(.8,1.3,u-.8),Vector3(.8,1.3,u+.8),Vector3(.8,2.65,u+.8),Vector3(.8,2.65,u-.8)],Color("e0bd83"))
        _line(Vector3(.75,1.3,u),Vector3(.75,2.65,u),Color("5c6355"),.07)
    _box(Vector3(-1.6,.12,-4),Vector3(1,.4,4),Color("9a8061"))
    for u: float in [-4,4]: _line(Vector3(-1.3,.4,u),Vector3(-1.3,3,u),Color("b29c76"),.16)
    _label(0,2.9,8,.65,0,.7)
    for row in range(3):
        for log_ in range(4-row): _box(Vector3(3,.15+row*.5,8+log_*.65),Vector3(7,.55+row*.5,8.5+log_*.65),Color("8d7050").darkened(.06*log_))
    _bench(-.5,-9);_lamp(-1,7,4)
    _fence(14,12,Color("8f7b5e"))

func _camp() -> void:
    _pad(15,13,Color("4c5749"))
    # Canvas tents and a timber picnic shelter, never a residential house.
    for u: float in [-9,8]:
        var canvas := Color("bd9862") if u<0 else Color("6d948e")
        _quad([Vector3(2,.15,u-2.8),Vector3(2,.15,u+2.8),Vector3(2,3.3,u)],canvas)
        for edge: float in [-1,1]: _quad([Vector3(2,.15,u+edge*2.8),Vector3(6,.15,u+edge*2.8),Vector3(6,3.3,u),Vector3(2,3.3,u)],canvas.darkened(.17))
        _quad([Vector3(1.94,.15,u-.65),Vector3(1.94,.15,u+.65),Vector3(1.94,2.65,u)],Color("273f43"))
        _line(Vector3(1.9,3.3,u),Vector3(.5,.1,u-3.5),Color("c5bfa3"),.03)
    for x: float in [2,9]:
        for u: float in [-3.5,3.5]: _line(Vector3(x,.2,u),Vector3(x,4,u),Color("988469"),.22)
    _gable(1.7,0,7.6,4,4,1,Color("466760"))
    for u: float in [-2,2]: _bench(4,u)
    _box(Vector3(3.6,1, -2),Vector3(5.1,1.2,2),Color("aa926c"))
    _cylinder(-.6,10,1.1,.10,.40,Color("69776c"))
    for i in range(6): _box(Vector3(-.9,.42,9.2+i*.23),Vector3(-.2,.58,9.35+i*.23),Color("805d43"))
    _label(0,3.8,8,.65,1,1.6);_lamp(-1,-6,4)

func _farm() -> void:
    _pad(24,22,Color("67705a"));_fence(23,22,Color("d0bc97"))
    # Red agricultural barn with cross-braced doors, glass conservatory,
    # grain silo, working yard and a compact green tractor.
    _box(Vector3(3,.15,-8),Vector3(15,6.2,8),Color("9b5a48"))
    for u: float in [-8.4,8.4]: _quad([Vector3(2.6,6.2,u),Vector3(15.4,6.2,u),Vector3(9,9.4,u)],Color("af7560"))
    for x: float in [2.6,15.4]: _quad([Vector3(x,6.2,-8.5),Vector3(x,6.2,8.5),Vector3(9,9.4,8.5),Vector3(9,9.4,-8.5)],Color("485e59"))
    _quad([Vector3(5.5,.2,-8.08),Vector3(12.5,.2,-8.08),Vector3(12.5,4.4,-8.08),Vector3(5.5,4.4,-8.08)],Color("68463d"))
    _line(Vector3(5.6,.3,-8.12),Vector3(12.4,4.35,-8.12),Color("dfd2b2"),.16)
    _line(Vector3(12.4,.3,-8.12),Vector3(5.6,4.35,-8.12),Color("dfd2b2"),.16)
    _quad([Vector3(8,6.6,-8.45),Vector3(10,6.6,-8.45),Vector3(10,7.8,-8.45),Vector3(8,7.8,-8.45)],Color("e3c38d"))
    _end_label(9,-8.16,4.8,10,.8,2)
    for u in range(-8,9,2): _line(Vector3(2.95,.3,u),Vector3(2.95,6.15,u),Color("b17a5c"),.06)
    for u: float in [-3.3,3.3]:
        _quad([Vector3(2.8,.2,u-2.8),Vector3(2.8,.2,u+2.8),Vector3(2.8,4.5,u+2.8),Vector3(2.8,4.5,u-2.8)],Color("633f38"))
        _line(Vector3(2.75,.25,u-2.7),Vector3(2.75,4.5,u+2.7),Color("dfd2b2"),.13)
        _line(Vector3(2.75,.25,u+2.7),Vector3(2.75,4.5,u-2.7),Color("dfd2b2"),.13)
    _label(0,5.1,13,.8,2,2.7)
    _cylinder(11,15,2.5,.1,10.6,Color("a9b4ae"))
    for y: float in [2,5,8]: _cylinder(11,15,2.55,y,y+.14,Color("697e82"))
    for u: float in [-19,-16,-13]:
        _box(Vector3(5,.2,u-1.2),Vector3(17,2.5,u+1.2),Color("527c77"))
        _gable(5,u,12,1.2,2.5,1.1,Color("91b1a2"))
        for x in range(5,18,3): _line(Vector3(x,.3,u-1.23),Vector3(x,2.5,u-1.23),Color("c1c9b7"),.07)
    _box(Vector3(-1,.8,10),Vector3(2.5,1.7,12),Color("54846a"))
    _box(Vector3(1.4,1.7,10.2),Vector3(2.9,3.0,11.8),Color("668b8d"))
    for x: float in [-.2,2.5]:
        for u: float in [9.7,12.3]: _cylinder(x,u,.55,.2,1.0,Color("2b3c43"))
    _lamp(-1,-12,6);_lamp(1,14,6)
    for u: float in [-22,22]: _box(Vector3(-2,.15,u-.7),Vector3(-1,1,u+.7),Color("7e8866"))

func _grain() -> void:
    _pad(18,17,Color("626b60"))
    for u: float in [-9,0,9]:
        _cylinder(9,u,3,.15,11.8,Color("879b9c"))
        for i in range(8):
            var a := i*TAU/8;var b := (i+1)*TAU/8
            _quad([Vector3(9+3.2*cos(a),11.8,u+3.2*sin(a)),Vector3(9+3.2*cos(b),11.8,u+3.2*sin(b)),Vector3(9,14.2,u)],Color("536c75"))
    for u: float in [-9,0,9]:
        _line(Vector3(5.9,.2,u),Vector3(5.9,11.8,u),Color("c2c8b4"),.12)
        for y in range(1,12): _line(Vector3(5.8,y,u-.35),Vector3(5.8,y,u+.35),Color("c2c8b4"),.055)
    _line(Vector3(9,12,-9),Vector3(9,12,9),Color("c1bfa5"),.24)
    _box(Vector3(-1,.15,-4),Vector3(3,2.8,4),Color("968d75"))
    _label(0,2,7,.65,3,-1.05);_lamp(-2,12,6)

func _lookout() -> void:
    _pad(9,10,Color("586558"))
    for x: float in [1,7]:
        for u: float in [-4,4]: _line(Vector3(x,.2,u),Vector3(x,11,u),Color("8b765a"),.3)
    for y: float in [1,5,9]:
        for u: float in [-4,4]: _line(Vector3(1,y,u),Vector3(7,y+3,u),Color("a68b66"),.14)
    _box(Vector3(.2,10.6,-5),Vector3(8,11,5),Color("a68e6e"))
    _gable(0,0,8.4,5.4,14,2.1,Color("486c63"))
    for u: float in [-5,5]:
        _line(Vector3(.2,11,u),Vector3(.2,14,u),Color("a68b66"),.22)
        _line(Vector3(8,11,u),Vector3(8,14,u),Color("a68b66"),.22)
    for u in range(-5,6): _line(Vector3(.1,11,u),Vector3(.1,12.2,u),Color("bdb49a"),.06)
    _line(Vector3(.1,12.2,-5),Vector3(.1,12.2,5),Color("bdb49a"),.10)
    _label(0,12.5,9,.7,4,-.08)
    for y in range(11): _line(Vector3(1,y+.5,-4.6),Vector3(3,y+.5,-4.6),Color("aa9169"),.08)

func _forest_stop() -> void:
    _pad(15,12,Color("58665a"))
    for x: float in [1,8]:
        for u: float in [-5,5]: _line(Vector3(x,.2,u),Vector3(x,4.2,u),Color("929b84"),.21)
    _gable(.6,0,8,6,4.2,1.5,Color("466e65"))
    _box(Vector3(7,.3,-5),Vector3(7.4,3.7,5),Color("69827b"))
    for u: float in [-3,3]: _bench(5,u)
    _label(0,3.7,10,.7,5,.5)
    _box(Vector3(-1,.2,9),Vector3(1,2.2,11),Color("667b70"))
    _quad([Vector3(-1.06,.8,9.15),Vector3(-1.06,.8,10.85),Vector3(-1.06,1.9,10.85),Vector3(-1.06,1.9,9.15)],Color("b3c4a2"))
    _lamp(-1,-8,4)

func _fuel() -> void:
    _pad(23,25,Color("596970"))
    var neon := Color("7cdfe8")
    for x: float in [2,13]:
        for u: float in [-11,11]:
            _box(Vector3(x-.3,.15,u-.3),Vector3(x+.3,5.6,u+.3),Color("aebfc0"))
    # Broad forecourt canopy, neon fascia and four actual pump islands.
    _box(Vector3(-1.5,5.5,-15),Vector3(15.5,6.1,15),Color("405e72"))
    _quad([Vector3(-1.5,5.49,-15),Vector3(15.5,5.49,-15),Vector3(15.5,5.49,15),Vector3(-1.5,5.49,15)],Color("b2c4ba"),Vector3.DOWN)
    _box(Vector3(-1.6,5.6,-15.15),Vector3(15.6,5.9,-15.02),neon)
    _box(Vector3(-1.6,5.6,-15),Vector3(-1.45,5.8,15),neon)
    _label(0,5.95,18,.8,6,-1.7)
    _end_label(7,-15.2,6,15,.9,6)
    for u: float in [-8,8]: _box(Vector3(4,5.40,u-1.8),Vector3(10,5.48,u+1.8),Color("eee3bb"))
    for u: float in [-8,8]:
        _box(Vector3(5,.1,u-2.4),Vector3(9,.35,u+2.4),Color("bbc1b4"))
        for x: float in [5.6,8.1]:
            _box(Vector3(x,.35,u-.65),Vector3(x+.75,2.15,u+.65),Color("839da6"))
            _box(Vector3(x-.04,1.3,u-.50),Vector3(x+.03,1.95,u+.50),Color("a6e4df"))
            _line(Vector3(x,1.5,u+.65),Vector3(x-.35,.6,u+.85),Color("263d48"),.065)
    _box(Vector3(19,.2,-11),Vector3(25,4.4,11),Color("547185"))
    for u in range(-9,10,3):
        _quad([Vector3(18.94,.7,u-1.2),Vector3(18.94,.7,u+1.2),Vector3(18.94,3.5,u+1.2),Vector3(18.94,3.5,u-1.2)],Color("bdd4b5"))
    _box(Vector3(-2,.15,-21),Vector3(-1.4,7.5,-16),Color("39576b"))
    _label(-18.5,5.2,5,1.3,6,-2.05)
    _label(-18.5,3.4,4.7,.7,8,-2.08)
    for u in range(-12,13,6): _line(Vector3(-2,.06,u),Vector3(1,.06,u),Color("c5cebb"),.09)
    _lamp(12,-21,7);_lamp(12,21,7)

func _diner() -> void:
    _pad(20,17,Color("616c77"))
    # Streamlined metal/glass diner with rounded corner fins and patio.
    _box(Vector3(2,.2,-11),Vector3(12,4,11),Color("7897a4"))
    _box(Vector3(1.5,4,-11.5),Vector3(12.5,4.5,11.5),Color("455c75"))
    for u in range(-9,10,3):
        _quad([Vector3(1.95,.9,u-1.25),Vector3(1.95,.9,u+1.25),Vector3(1.95,3,u+1.25),Vector3(1.95,3,u-1.25)],Color("e0b09c"))
        _line(Vector3(1.9,2,u-1.25),Vector3(1.9,2,u+1.25),Color("aabbbd"),.07)
    for y: float in [.5,3.6,4.3]: _line(Vector3(1.4,y,-11.5),Vector3(1.4,y,11.5),Color("f09ac6"),.1)
    _label(0,4.4,17,.9,7,1.3)
    for u: float in [-13,13]:
        _cylinder(7,u,1.4,.1,4.5,Color("617fa1"))
        _line(Vector3(5.55,4.4,u-1.2),Vector3(5.55,4.4,u+1.2),Color("92dceb"),.12)
    for u: float in [-6,6]:
        _cylinder(-1,u,.9,.8,1.05,Color("b0aba2"))
        _bench(-2.5,u-1.5)
    _lamp(-2,-17,5);_lamp(-2,17,5)
