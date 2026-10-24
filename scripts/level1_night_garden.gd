extends RefCounted
# Authored silhouettes, opaque coloured glass and small luminous inlays. Static
# triangles share two materials in spatial chunks; no new lights or viewports.
const Data = preload("res://scripts/level_data.gd")
const Props = preload("res://scripts/level1_park_props.gd")
const Batch = preload("res://scripts/level1_trail_batch.gd")
const PALETTE := [Color("edc17b"),Color("7ee5df"),Color("ce9ae7"),Color("ffd378")]
const BRONZE := Color("b79761")
const METAL := Color("334a55")
const WOOD := Color("66503e")
var solid := Batch.new()
var glow := Batch.new()
var box := BoxMesh.new()
var sphere := SphereMesh.new()
var cylinder := CylinderMesh.new()
var leaf: ArrayMesh
var root_: Node3D
var triangles := 0

func build(host) -> void:
    root_ = Node3D.new()
    root_.name = "NightGardenLandmarks"
    host.scenery_root.add_child(root_)
    box.size=Vector3.ONE
    sphere.radius=.5;sphere.height=1.0;sphere.radial_segments=8;sphere.rings=4
    cylinder.top_radius=.5;cylinder.bottom_radius=.5;cylinder.height=1.0;cylinder.radial_segments=6;cylinder.rings=0
    leaf=preload("res://scripts/level1_park_detail.gd")._leaf_mesh()
    _entrance()
    _moon_garden()
    _gallery()
    _golden_grove(host.trees.legendary_hangers)
    _path_inlays()
    var lit := StandardMaterial3D.new()
    lit.vertex_color_use_as_albedo=true;lit.vertex_color_is_srgb=true
    lit.roughness=.72;lit.metallic_specular=.25
    solid.finish(root_,"GardenArchitecture",62.0,lit)
    var emission := ShaderMaterial.new()
    emission.shader=preload("res://shaders/level1_garden_inlay.gdshader")
    glow.finish(root_,"GardenLuminousInlay",52.0,emission)
    root_.set_meta("triangle_count",triangles)
    root_.set_meta("landmark_count",4)

func _part(mesh: Mesh, p: Vector3, size_: Vector3, color_: Color, basis_ := Basis.IDENTITY, luminous := false) -> void:
    var target = glow if luminous else solid
    target.add(mesh,Transform3D(basis_*Basis.from_scale(size_),p),color_)
    triangles+=mesh.get_faces().size()/3

func _beam(a: Vector3, b: Vector3, width: float, color_: Color, luminous := false) -> void:
    var d := b-a
    if d.length_squared()<.00001: return
    var y := d.normalized()
    var x := y.cross(Vector3.FORWARD if absf(y.z)<.9 else Vector3.RIGHT).normalized()
    var basis_ := Basis(x,y,x.cross(y))
    _part(cylinder,(a+b)*.5,Vector3(width,d.length(),width),color_,basis_,luminous)

func _arc(center: Vector3, basis_: Basis, radius: float, start: float, end: float, width: float, color_: Color, luminous := false, steps: int = 36) -> void:
    for i in range(steps):
        var a := lerpf(start,end,float(i)/steps)
        var b := lerpf(start,end,float(i+1)/steps)
        _beam(center+basis_*Vector3(cos(a)*radius,sin(a)*radius,0),center+basis_*Vector3(cos(b)*radius,sin(b)*radius,0),width,color_,luminous)

func _string(a: Vector3, b: Vector3, tint: Color, bulbs: int) -> void:
    var last := a
    for i in range(1,bulbs+1):
        var t := float(i)/bulbs
        var p := a.lerp(b,t)+Vector3.DOWN*sin(t*PI)*.55
        _beam(last,p,.025,METAL)
        if i<bulbs:
            _beam(p,p+Vector3.DOWN*.15,.026,BRONZE)
            _part(sphere,p+Vector3.DOWN*.23,Vector3(.12,.17,.12),tint,Basis.IDENTITY,true)
            _part(cylinder,p+Vector3.DOWN*.14,Vector3(.10,.07,.10),BRONZE)
        last=p

func _label(p: Vector3, text_: String, yaw: float, size_: float, color_: Color) -> void:
    var label := Label3D.new()
    label.text=text_;label.font_size=64;label.pixel_size=size_
    label.position=p;label.rotation.y=yaw;label.modulate=color_
    label.outline_size=3;label.no_depth_test=false
    label.visibility_range_end=28.0
    root_.add_child(label)

func _entrance() -> void:
    var p := Data.cell_center_world(Props.PORTAL_CELL)
    var basis_ := Basis(Vector3.UP,Props.PORTAL_YAW)
    for side: float in [-1,1]:
        var at := p+basis_*Vector3(side*2.15,0,0)
        _part(box,at+Vector3.UP*1.65,Vector3(.26,3.3,.26),METAL,basis_)
        _part(box,at+Vector3.UP*.16,Vector3(.35,.32,.35),BRONZE,basis_)
        for y: float in [.42,2.8,3.3]:
            _part(box,at+Vector3.UP*y,Vector3(.33,.09,.33),BRONZE,basis_)
        _part(sphere,at+Vector3.UP*3.55,Vector3(.27,.43,.27),PALETTE[0],basis_,true)
    for depth: float in [-.16,.16]:
        _arc(p+Vector3.UP*3.28+basis_*Vector3(0,0,depth),basis_,2.15,0,PI,.075,BRONZE)
    for i in range(13):
        var a := i*PI/12
        var at := p+Vector3.UP*3.28+basis_*Vector3(cos(a)*2.15,sin(a)*2.15,0)
        _beam(at-basis_*Vector3(0,0,.20),at+basis_*Vector3(0,0,.20),.055,METAL)
    _part(box,p+Vector3.UP*3.56,Vector3(3.15,.51,.13),METAL,basis_)
    for y: float in [3.29,3.83]:
        _part(box,p+Vector3.UP*y,Vector3(3.25,.035,.16),PALETTE[0],basis_,true)
    _label(p+Vector3.UP*3.55+basis_*Vector3(0,0,.083),"ЛУННЫЙ ПАРК",Props.PORTAL_YAW,.004,PALETTE[0])
    _arc(p+Vector3.UP*4.47,basis_,.42,.50,TAU-.50,.09,PALETTE[0],true,24)
    # Cables are anchored to the portal and the first actual oak trunk.
    var oak := Data.cell_center_world(Vector2i(9,28))+Vector3.UP*4.1
    for side: float in [-1,1]:
        _string(p+basis_*Vector3(side*2.15,3.3,0),oak,PALETTE[0],9)

func _moon_garden() -> void:
    var p := preload("res://scripts/level1_park_pond.gd").center()
    var basis_ := Basis(Vector3.UP,-.52)
    _part(cylinder,p+Vector3.UP*.30,Vector3(1.9,.60,1.9),METAL)
    _part(cylinder,p+Vector3.UP*.63,Vector3(2.05,.08,2.05),BRONZE)
    _beam(p+Vector3.UP*.6,p+Vector3.UP*1.4,.22,BRONZE)
    var center := p+Vector3.UP*3.3
    # A deep extruded crescent, tapered at both tips; not a flat billboard.
    var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(40):
        var points: Array[Vector3]=[]
        for depth: float in [-.13,.13]:
            for data: Vector2 in [Vector2(i,0),Vector2(i+1,0),Vector2(i+1,1),Vector2(i,1)]:
                var t := data.x/40.0
                var a := lerpf(-2.13,2.13,t)
                var width := .035+pow(sin(t*PI),.85)*.68
                var radius := 2.55-data.y*width
                points.append(Vector3(-cos(a)*radius,sin(a)*radius,depth))
        var faces := [[0,1,2,3],[7,6,5,4],[4,5,1,0],[3,2,6,7]]
        if i==0: faces.append([0,3,7,4])
        if i==39: faces.append([1,5,6,2])
        for face in faces:
            for k in [face[0],face[1],face[2],face[0],face[2],face[3]]: surface.add_vertex(points[k])
    surface.generate_normals()
    _part(surface.commit(),center,Vector3.ONE,Color("d7bb7a"),basis_)
    var orb := center+basis_*Vector3(.40,0,0)
    _part(sphere,orb,Vector3.ONE*.64,PALETTE[1],Basis.IDENTITY,true)
    _arc(orb,basis_*Basis(Vector3.RIGHT,.65),1.03,0,TAU,.055,BRONZE)
    _arc(orb,basis_*Basis(Vector3.UP,.8),1.17,0,TAU,.035,PALETTE[1],true)
    for i in range(7):
        var a := i*TAU/7
        var at := p+Vector3(cos(a)*3.1,.09,sin(a)*3.1)
        _part(sphere,at,Vector3(.50,.07,.50),Color("507a70"))
        for k in range(5):
            var b := Basis(Vector3.UP,k*TAU/5)*Basis(Vector3.RIGHT,-.55)
            _part(leaf,at+Vector3.UP*.04,Vector3(.45,.4,.45),PALETTE[1],b,true)
    var gazebo := Data.cell_center_world(Vector2i(17,4))
    _arc(gazebo+Vector3.UP*4.18,Basis(Vector3.RIGHT,PI*.5),2.54,0,TAU,.055,PALETTE[1],true,48)
    for i in range(8):
        var a := i*TAU/8
        _beam(gazebo+Vector3(cos(a)*3.12,4.2,sin(a)*3.12),gazebo+Vector3.UP*5.98,.055,BRONZE)
        _string(gazebo+Vector3(cos(a)*2.4,3.35,sin(a)*2.4),gazebo+Vector3(cos(a+TAU/8)*2.4,3.35,sin(a+TAU/8)*2.4),PALETTE[1],5)

func _gallery() -> void:
    var base := Data.cell_center_world(Vector2i(34,5))
    var p := base+Vector3.UP*6.65
    var b := Basis.IDENTITY
    _arc(p,b,1.35,0,TAU,.12,BRONZE)
    _arc(p,b,1.48,0,TAU,.04,PALETTE[2],true)
    for i in range(8):
        var a := i*TAU/8
        var at := p+Vector3(cos(a)*.61,sin(a)*.61,0)
        var petal := b*Basis(Vector3.FORWARD,a-PI*.5)*Basis(Vector3.RIGHT,-PI*.5)
        _part(leaf,at,Vector3(.50,.42,.69),PALETTE[2] if i%2==0 else PALETTE[1],petal,true)
        _beam(p+Vector3(cos(a)*.25,sin(a)*.25,0),p+Vector3(cos(a)*1.28,sin(a)*1.28,0),.04,BRONZE)
    _part(sphere,p,Vector3(.43,.43,.19),PALETTE[0],Basis.IDENTITY,true)
    for side: float in [-1,1]:
        _beam(base+Vector3(side*.90,5.70,0),base+Vector3(side*.90,5.35,0),.09,BRONZE)
    # Ivy and hanging wisteria belong to the existing stone column silhouettes.
    var rng := RandomNumberGenerator.new();rng.seed=151026
    for side: float in [-1,1]:
        var column := Data.cell_center_world(Vector2i(34,5))+Vector3.RIGHT*side*2.5
        for i in range(17):
            var at := column+Vector3(sin(i*.62)*.52,.3+i*.29,.50)
            _part(leaf,at,Vector3(.48,.50,.55),Color("557a68"),Basis(Vector3.UP,i*2.4))
        for i in range(8):
            var at := column+Vector3(rng.randf_range(-.55,.55),4.6,rng.randf_range(-.55,.55))
            for j in range(5):
                _part(sphere,at+Vector3(sin(j)*.06,-j*.17,0),Vector3(.22-j*.025,.26,.20-j*.02),Color("a485c5"))

func _golden_grove(hangers: Array) -> void:
    var oak := Data.cell_center_world(Vector2i(38,27))
    if hangers.size()>2:
        for i in range(hangers.size()):
            var a: Vector3=hangers[i];var b: Vector3=hangers[(i+1)%hangers.size()]
            a.y=4.55;b.y=4.55
            _beam(hangers[i],a,.027,BRONZE)
            _string(a,b,PALETTE[3],6)
    # Radial brass stars sit on the existing solid root island.
    for i in range(9):
        var a := i*TAU/9
        var at := oak+Vector3(cos(a)*.9,.04,sin(a)*.9)
        _part(leaf,at,Vector3(.55,.45,.65),Color("c2a34d"),Basis(Vector3.UP,-a))
    var sign := Data.cell_center_world(Vector2i(37,20))+Vector3(1,2.65,0)
    _arc(sign,Basis.IDENTITY,.35,.5,TAU-.5,.065,PALETTE[3],true,20)

func _path_inlays() -> void:
    for section in range(1,Data.PATH_CELLS.size()):
        var a := Data.cell_center_world(Data.PATH_CELLS[section-1])
        var b := Data.cell_center_world(Data.PATH_CELLS[section])
        var d := a.direction_to(b)
        var side := d.cross(Vector3.UP)
        var basis_ := Basis(side,Vector3.UP,-d)
        var steps := maxi(1,floori(a.distance_to(b)/2.4))
        for i in range(steps):
            var p := a.lerp(b,(i+.5)/steps)
            var color_: Color=PALETTE[Data.episode_at(p)]
            for sign_: float in [-1,1]:
                var at := p+side*sign_*.88+Vector3.UP*.034
                var cell := Data.world_to_cell(at.x,at.z)
                if Data.CANONICAL_MAP[cell.y][cell.x]!="." or Props.contains_point(at+Vector3.UP*.4,.12): continue
                _part(box,at,Vector3(.10,.025,.42),METAL,basis_)
                _part(box,at+Vector3.UP*.016,Vector3(.035,.018,.30),color_*.55,basis_,true)
