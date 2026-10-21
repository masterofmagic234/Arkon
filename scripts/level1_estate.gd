extends RefCounted
# Authored macro architecture for the lake estate. All ground-level blockers
# are sourced from Data's collision rectangles or Props' shared footprints.
# Spacious views, recognisable rooflines and deliberate quiet pockets replace
# the dense repeated ornamentation of the old four-square park.
const Data=preload("res://scripts/level_data.gd")
const Props=preload("res://scripts/level1_park_props.gd")
var host

func build_paths(owner_) -> void:
    var material:=ShaderMaterial.new();material.shader=preload("res://shaders/level1_park_path.gdshader")
    material.set_shader_parameter("ground_tex",owner_.DETAIL_TEXTURE)
    var builders: Dictionary={}
    var path_root:=Node3D.new();path_root.name="WindingParkPath";owner_.scenery_root.add_child(path_root)
    for route_index in range(Data.PATH_ROUTES.size()):
        var route: Array=Data.PATH_ROUTES[route_index]
        var left: Array[Vector3]=[];var right: Array[Vector3]=[]
        var distances: Array[float]=[];var distance_:=0.0
        for i in range(route.size()):
            var p:=Data.cell_center_world(route[i])+Vector3.UP*.022
            var a:=Data.cell_center_world(route[maxi(0,i-1)])
            var b:=Data.cell_center_world(route[mini(route.size()-1,i+1)])
            var side: Vector3=(b-a).normalized().cross(Vector3.UP)*(1.6 if route_index==0 else 1.15)
            left.append(p-side);right.append(p+side)
            if i>0: distance_+=p.distance_to(Data.cell_center_world(route[i-1]))
            distances.append(distance_)
        for i in range(1,route.size()):
            var mid: Vector3=(left[i]+right[i]+left[i-1]+right[i-1])*.25
            var key:=Vector2i(floori(mid.x/16),floori(mid.z/16))
            if not builders.has(key):
                var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);builders[key]=st
            var st: SurfaceTool=builders[key]
            for corner: Vector2i in [Vector2i(i-1,0),Vector2i(i,0),Vector2i(i-1,1),Vector2i(i-1,1),Vector2i(i,0),Vector2i(i,1)]:
                st.set_normal(Vector3.UP);st.set_uv(Vector2(corner.y,distances[corner.x]*.24))
                st.add_vertex(left[corner.x] if corner.y==0 else right[corner.x])
    for key in builders:
        var st: SurfaceTool=builders[key];st.index()
        var mesh:=MeshInstance3D.new();mesh.name="Gravel_%s_%s"%[key.x,key.y];mesh.mesh=st.commit()
        mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mesh.visibility_range_end=100;path_root.add_child(mesh)

func build_boundary(owner_) -> void:
    host=owner_
    var walls:=preload("res://scripts/level1_estate_walls.gd").new()
    var tree_cells: Array[Vector2i]=[]
    for y in range(2,Data.MAP_HEIGHT-2):
        for x in range(2,Data.MAP_WIDTH-2):
            var c:=Vector2i(x,y)
            if host._walkable(c) or Data.is_pond(c) or _cover(c): continue
            var exposed:=false
            for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                if host._walkable(c+d): exposed=true
            var p:=Data.cell_center_world(c)
            if exposed:
                var h:=3.05+float(posmod(x*19+y*13,5))*.12
                walls.add_cell(c)
                host._batch("boundary_crown","hedge",p+Vector3.UP*(h+1.2),Vector3(2.7,2.1,2.6))
                host.opaque_walls.append(AABB(p+Vector3(-.88,.02,-.88),Vector3(1.76,2.92,1.76)))
            elif posmod(x*17+y*29,19)==0:
                # Deep border trees stay away from open routes and shores.
                var clear:=true
                for dy in range(-1,2):
                    for dx in range(-1,2):
                        if host._walkable(c+Vector2i(dx,dy)) or Data.is_pond(c+Vector2i(dx,dy)): clear=false
                if clear: tree_cells.append(c)
    walls.finish(host.scenery_root,host.materials.outer_wall)
    for cell in tree_cells:
        host._tree(Data.cell_center_world(cell),7.5+float(posmod(cell.x*7+cell.y,9))*.5,false,true)
    # Deliberate individual silhouettes on existing solid islands.
    host._tree(Data.cell_center_world(Vector2i(28,24)),8.0,false)
    host._tree(Data.cell_center_world(Vector2i(76,9)),10.0,false)

func _cover(cell: Vector2i) -> bool:
    for rect: Rect2i in Data.COVER_RECTS:
        if rect.has_point(cell): return true
    return cell==Vector2i(20,49) or cell==Vector2i(28,24) or cell==Vector2i(76,9)

func build(owner_) -> void:
    host=owner_
    var root_:=Node3D.new();root_.name="EstateLandmarks";host.scenery_root.add_child(root_)
    # Shared resources and spatial batches keep each landmark inexpensive.
    var roof: StandardMaterial3D=host._material(Color("386e77"));roof.metallic=.45;host.materials.estate_roof=roof
    host.materials.lantern_rope=host._material(Color("373a31"))
    var ring:=TorusMesh.new();ring.inner_radius=.88;ring.outer_radius=1.0;ring.rings=32;ring.ring_segments=6
    host.meshes.estate_ring=ring
    _cover_architecture()
    _entrance()
    _tower()
    _observatory(root_)
    _greenhouse(root_)
    _bridges()
    _grove()
    _furniture()
    preload("res://scripts/level1_estate_water.gd").new().build(host)
    _return_wayfinding()
    root_.set_meta("macro_landmarks",4)
    host.scenery_root.set_meta("flower_beds",4)
    host.scenery_root.set_meta("garden_urns",Props.URNS.size())

func _part(shape: String,mat: String,p: Vector3,size_: Vector3,basis_:=Basis.IDENTITY) -> void:
    host._batch(shape,mat,p,size_,basis_)

func _beam(a: Vector3,b: Vector3,width: float,mat: String) -> void:
    var direction:=b-a
    _part("box",mat,(a+b)*.5,Vector3(width,direction.length(),width),Basis(Quaternion(Vector3.UP,direction.normalized())))

func _cover_architecture() -> void:
    for i in range(Data.COVER_RECTS.size()):
        var rect: Rect2i=Data.COVER_RECTS[i]
        if rect.has_point(Data.OAK_CELL) or rect.has_point(Data.TOWER_CELL): continue
        var p: Vector3=(Data.cell_center_world(rect.position)+Data.cell_center_world(rect.end-Vector2i.ONE))*.5
        var width:=Vector2(rect.size)*Data.CELL_SIZE
        var mat: String="wall_4" if Data.episode_at(p)==2 else "outer_wall"
        _part("box",mat,p+Vector3.UP*1.5,Vector3(width.x,3.0,width.y))
        _part("box","stone",p+Vector3.UP*3.02,Vector3(width.x+.16,.16,width.y+.16))
        host.opaque_walls.append(AABB(p-Vector3(width.x*.5-.03,-.02,width.y*.5-.03),Vector3(width.x-.06,2.96,width.y-.06)))
        if i==0:
            # Gardener's lodge is a building-sized cover/reward landmark.
            _part("box","wood",p+Vector3.UP*3.9,Vector3(width.x-.25,1.7,width.y-.25))
            for side: float in [-1,1]:
                _part("box","estate_roof",p+Vector3(side*width.x*.25,4.95,0),Vector3(width.x*.58,.22,width.y+.6),Basis(Vector3.FORWARD,side*-.35))
                _part("box","lamp",p+Vector3(side*(width.x*.5+.02),2.05,0),Vector3(.035,.65,1.0))

func _entrance() -> void:
    var p:=Data.cell_center_world(Props.PORTAL_CELL)
    var turn:=Basis(Vector3.UP,Props.PORTAL_YAW)
    for side: float in [-1,1]:
        _part("box","stone_dark",p+turn*Vector3(side*2.8,1.65,0),Vector3(.36,3.3,.36),turn)
        _part("ball","lamp",p+turn*Vector3(side*2.8,3.65,0),Vector3(.22,.22,.22))
    _part("box","wood",p+Vector3.UP*3.15,Vector3(5.9,.65,.22),turn)
    host._sign(Data.cell_center_world(Vector2i(9,51)),"ПАРК ПОЛУНОЧИ\nМашина ждёт здесь",Props.PORTAL_YAW)
    host._sign(Data.cell_center_world(Vector2i(27,46)),"← ОБСЕРВАТОРИЯ\nМОСТ И РОЩА →",-.25)
    host._sign(Data.cell_center_world(Vector2i(33,21)),"ОРАНЖЕРЕЯ →\nЮЖНАЯ КАЛИТКА ↙",0)
    host._sign(Data.cell_center_world(Vector2i(65,30)),"РОЩА ФОНАРЕЙ\nЧЕРЕЗ ЮЖНЫЕ ВОРОТА",PI)

func _tower() -> void:
    var p:=Data.cell_center_world(Data.TOWER_CELL)
    _part("box","wall_4",p+Vector3.UP*2.5,Vector3(5.4,5,5.4))
    _part("box","stone_dark",p+Vector3.UP*9.2,Vector3(3.5,9,3.5))
    for h: float in [5.1,12.5,15.0]: _part("box","stone",p+Vector3.UP*h,Vector3(4.2,.22,4.2))
    _part("box","wood",p+Vector3.UP*13.7,Vector3(3.8,2.3,3.8))
    for angle in range(4):
        var turn:=Basis(Vector3.UP,angle*PI*.5)
        var center:=p+Vector3.UP*13.8+turn*Vector3(0,0,1.94)
        _part("cylinder","iron",center,Vector3(2.05,.055,2.05),turn*Basis(Vector3.RIGHT,PI*.5))
        _part("estate_ring","brass",center+turn*Vector3(0,0,.04),Vector3.ONE*1.08,turn*Basis(Vector3.RIGHT,PI*.5))
        _part("box","lamp",center+turn*Vector3(.32,0,.08),Vector3(.72,.085,.04),turn)
        _part("box","moon",center+turn*Vector3(0,.38,.09),Vector3(.07,.8,.035),turn)
    _part("trunk","estate_roof",p+Vector3.UP*16.1,Vector3(5.0,2.0,5.0))
    _part("cylinder","brass",p+Vector3.UP*17.8,Vector3(.14,2.0,.14))
    _part("ball","moon",p+Vector3.UP*18.9,Vector3(.55,.55,.55))

func _observatory(parent: Node3D) -> void:
    var p:=Data.cell_center_world(Data.OBSERVATORY_CELL)
    _part("cylinder","stone_dark",p+Vector3.UP*.012,Vector3(11.8,.024,11.8))
    for x: float in [-4.4,4.4]:
        for z: float in [-3.5,3.5]:
            _part("box","wall_4",p+Vector3(x,2.6,z),Vector3(.55,5.2,.55))
            _part("box","brass",p+Vector3(x,4.95,z),Vector3(.75,.18,.75))
    var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for ring in range(7):
        var a:=float(ring)*PI*.5/8;var b:=float(ring+1)*PI*.5/8
        for segment in range(32):
            var c:=segment*TAU/32;var d:=(segment+1)*TAU/32
            var points: Array[Vector3]=[]
            for pair: Vector2 in [Vector2(a,c),Vector2(a,d),Vector2(b,d),Vector2(b,c)]:
                points.append(p+Vector3(cos(pair.y)*cos(pair.x)*5.7,5.2+sin(pair.x)*3.7,sin(pair.y)*cos(pair.x)*5.7))
            for k in [0,2,1,0,3,2]: st.add_vertex(points[k])
    st.generate_normals();st.index()
    var dome:=MeshInstance3D.new();dome.name="ObservatoryDome";dome.mesh=st.commit();dome.material_override=host.materials.estate_roof
    dome.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(dome)
    for segment in range(12):
        var angle:=segment*TAU/12
        for ring in range(8):
            var a:=ring*PI*.5/8;var b:=(ring+1)*PI*.5/8
            _beam(p+Vector3(cos(angle)*cos(a)*5.73,5.22+sin(a)*3.72,sin(angle)*cos(a)*5.73),p+Vector3(cos(angle)*cos(b)*5.73,5.22+sin(b)*3.72,sin(angle)*cos(b)*5.73),.065,"brass")
    _part("estate_ring","brass",p+Vector3.UP*5.2,Vector3(5.75,.7,5.75))
    _part("estate_ring","moon",p+Vector3.UP*9.4,Vector3(1.0,.45,1.0),Basis(Vector3.RIGHT,PI*.5))
    _part("ball","brass",p+Vector3.UP*9.4,Vector3(.42,.42,.42))

func _greenhouse(parent: Node3D) -> void:
    var root_:=Node3D.new();root_.name="GreenhouseFrame";parent.add_child(root_)
    for cell: Vector2i in Props.GALLERY_COLUMNS:
        var p:=Data.cell_center_world(cell)
        _part("box","iron",p+Vector3.UP*2.8,Vector3(.42,5.6,.42))
        _part("box","wall_4",p+Vector3.UP*.35,Vector3(.7,.7,.7))
    for y: int in [10,14,22,26]:
        var a:=Data.cell_center_world(Vector2i(62,y))+Vector3.UP*5.6
        var b:=Data.cell_center_world(Vector2i(74,y))+Vector3.UP*5.6
        var middle: Vector3=(a+b)*.5+Vector3.UP*3
        _beam(a,middle,.17,"iron");_beam(middle,b,.17,"iron")
        _beam(a,b,.10,"brass")
        if y in [10,26]:
            for side: float in [-1,1]:
                var center: Vector3=middle.lerp(a if side<0 else b,.5)
                _part("box","estate_roof",center,Vector3(9.0,.045,1.9),Basis(Vector3.FORWARD,side*-.27))
    for x: int in [62,68,74]:
        var a:=Data.cell_center_world(Vector2i(x,10))+Vector3.UP*(8.6 if x==68 else 5.6)
        var b:=Data.cell_center_world(Vector2i(x,26))+Vector3.UP*(8.6 if x==68 else 5.6)
        _beam(a,b,.16,"iron")
    # Distinctive fractured crest is visible above the cover before entry.
    var p:=Data.cell_center_world(Vector2i(68,10))+Vector3.UP*8.8
    _part("estate_ring","lamp_gallery",p,Vector3(1.6,.35,1.6),Basis(Vector3.RIGHT,PI*.5))

func _bridges() -> void:
    var p:=Data.cell_center_world(Data.RETURN_BRIDGE_CELL)
    _part("box","wood",p+Vector3.UP*.012,Vector3(28.8,.024,8.85))
    for side: float in [-1,1]:
        for height: float in [.45,1.1]: _part("box","wood",p+Vector3(0,height,side*4.35),Vector3(28.8,.10,.12))
        for x in range(-14,15,2): _part("box","wood",p+Vector3(x,.55,side*4.35),Vector3(.16,1.1,.16))
    # Broad eastern causeway is the player's independent second branch.
    for i in range(1,Data.HUB_BRIDGE.size()):
        var a:=Data.cell_center_world(Data.HUB_BRIDGE[i-1]);var b:=Data.cell_center_world(Data.HUB_BRIDGE[i])
        var direction:=a.direction_to(b);var turn:=Basis(Vector3.UP,atan2(-direction.x,-direction.z))
        _part("box","wood",(a+b)*.5+Vector3.UP*.012,Vector3(8.8,.024,a.distance_to(b)+.2),turn)
        for side: float in [-1,1]:
            var offset:=turn*Vector3(side*4.32,0,0)
            _beam(a+offset+Vector3.UP*1.1,b+offset+Vector3.UP*1.1,.12,"wood")
            for step in range(ceili(a.distance_to(b)/2.5)+1):
                var along:=a.lerp(b,float(step)/float(ceili(a.distance_to(b)/2.5)))
                _part("box","wood",along+offset+Vector3.UP*.55,Vector3(.15,1.1,.15),turn)
    # North causeway gets a contrasting pale deck and a long lake view.
    p=Data.cell_center_world(Vector2i(44,16))
    _part("box","stone",p+Vector3.UP*.011,Vector3(16.2,.022,8.8))

func _grove() -> void:
    var p:=Data.cell_center_world(Data.OAK_CELL)
    host._tree(p,18.0,true)
    for i in range(host.trees.legendary_hangers.size()):
        var anchor: Vector3=host.trees.legendary_hangers[i]
        var lantern:=Vector3(anchor.x,4.2+sin(i*1.8)*.6,anchor.z)
        _beam(anchor,lantern+Vector3.UP*.24,.045,"lantern_rope")
        _part("box","lamp",lantern,Vector3(.22,.34,.22))
        for h: float in [-.22,.22]: _part("box","brass",lantern+Vector3.UP*h,Vector3(.38,.075,.38))
    # Quiet outer circuit contrasts with the exposed seal in front of the oak.
    for cell in [Vector2i(52,46),Vector2i(58,57),Vector2i(75,43),Vector2i(72,56)]:
        # These are background silhouettes outside the walkable clearing.
        if not host._walkable(cell): host._tree(Data.cell_center_world(cell),10.0,false,true)

func _furniture() -> void:
    for cell in Props.LAMPS: host._lamp(Data.cell_center_world(cell))
    for bench in Props.BENCHES: host._bench(Props.bench_position(bench),Props.bench_yaw(bench))
    for cell in Props.URNS:
        var p:=Data.cell_center_world(cell)
        _part("trunk","stone",p+Vector3.UP*.45,Vector3(.86,.85,.86))
        _part("ball","leaf_light",p+Vector3.UP*1.0,Vector3(1.0,.55,1.0))
        for i in range(7):
            var angle:=i*TAU/7
            _part("ball","lamp_gallery",p+Vector3(cos(angle)*.32,1.18,sin(angle)*.32),Vector3(.12,.08,.12))

func _return_wayfinding() -> void:
    var root_:=Node3D.new();root_.name="ReturnWayfinding";root_.visible=false;host.scenery_root.add_child(root_)
    var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var route: Array[Vector2i]=[Vector2i(60,47),Vector2i(54,45),Vector2i(49,45),Data.RETURN_BRIDGE_CELL,Vector2i(39,45),Vector2i(33,47),Vector2i(27,48),Vector2i(22,52),Vector2i(17,52),Vector2i(12,54)]
    for i in range(route.size()-1):
        var p:=Data.cell_center_world(route[i])+Vector3.UP*.065
        var forward:=p.direction_to(Data.cell_center_world(route[i+1])+Vector3.UP*.065)
        var right:=forward.cross(Vector3.UP)
        for side: float in [-1,1]:
            var a:=p-forward*.4+right*side*.55;var b:=p+forward*.35
            var normal: Vector3=(b-a).normalized().cross(Vector3.UP)*.08
            for v: Vector3 in [a-normal,b+normal,a+normal,a-normal,b-normal,b+normal]:st.add_vertex(v)
    st.generate_normals()
    var node:=MeshInstance3D.new();node.name="EscapeChevrons";node.mesh=st.commit();node.material_override=host.materials.lamp
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root_.add_child(node)
