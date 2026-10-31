extends "res://scripts/woodland_world.gd"
## The same woodland material language, with a different authored footprint
## and landmark in each area. Only the current area exists in the scene tree.
var region_index := 1
var shortcut_open := false
var water_surface: Node3D
var wheel: Node3D
var bridge_gate: StaticBody3D
var mirrors: Array[Node3D]=[]
var beam_nodes: Array[Node3D]=[]
const RAVINE_ROUTE=[Vector3(-20,0,12),Vector3(-20,0,-2),Vector3(20,0,-2),Vector3(20,0,-14)]

func build() -> void:
    if built:return
    built=true;rng.seed=24102026+region_index*157;scenery_root=self
    _resources()
    for id in ["wood","wood_light","roof"]:
        materials[id].albedo_texture=BARK;materials[id].uv1_triplanar=true;materials[id].uv1_world_triplanar=true;materials[id].uv1_scale=Vector3.ONE*.4
    _lighting();_area_floor();_edges();_regional_forest()
    match region_index:
        1:_orchard()
        2:_mill()
        3:_greenhouse()
        4:_ravine()
        5:_camp()
        6:_stone_circle()
        7:_ancient_grove()
    _travel_paths(region_index)
    _merge_paths()
    _bake_contacts();_flush()
    add_to_group("woodland_world")
    if not get_viewport().size_changed.is_connected(_mobile_profile):get_viewport().size_changed.connect(_mobile_profile)
    _mobile_profile()


func _area_floor() -> void:
    if region_index not in [2,4]:_floor();return
    var edge=8.6 if region_index==4 else 7.6
    var south=8.6 if region_index==4 else 1.6
    for pair in [[-70.0,-edge],[south,70.0]]:
        var node=MeshInstance3D.new();var mesh=PlaneMesh.new();mesh.size=Vector2(140,pair[1]-pair[0]);mesh.subdivide_width=18;mesh.subdivide_depth=8
        node.mesh=mesh;node.position.z=(pair[0]+pair[1])*.5;node.material_override=materials.ground;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
    _collider(Vector3(0,-.2,0),Vector3(76,.4,64),false,"ContinuousForestFloor")
    var depth=5.0 if region_index==4 else 1.0
    for z in [-edge,south]:_batch("box","stone",Vector3(0,-depth*.5,z),Vector3(76,depth,.6))

func _edges() -> void:
    for x in [-37,37]:_collider(Vector3(x,2,0),Vector3(2,4,64),true,"ForestEdge")
    _route_edge(-31,26);_route_edge(31,-26)
    for x in [-34,34]:
        for z in range(-26,29,9):_batch("sphere","stone",Vector3(x,.5,z),Vector3(4,1.8,3),Basis(Vector3.UP,z*.3))
    _sign(Vector3(-5,1.8,23),preload("res://scripts/woodland_journey_state.gd").TITLES[region_index],.2)

func _regional_forest() -> void:
    for x in [-32,32]:
        for z in range(-26,29,7):
            var p=Vector3(x+rng.randf_range(-1,1),0,z)
            trees.plant(self,p,rng.randf_range(8,12),false,false)
            contact_blobs.append(Vector4(p.x,p.z,2,.3))
    for z in [-29,29]:
        for x in range(-26,29,8):
            if absf(x)<6:continue
            if (z<0 and absf(x-26)<5) or (z>0 and absf(x+26)<5):continue
            trees.plant(self,Vector3(x,0,z),rng.randf_range(9,13),false,false)
    for i in range(16):
        var angle=i*TAU/16
        trees.plant(self,Vector3(cos(angle)*45,0,sin(angle)*39),rng.randf_range(11,15),false,true)
    for p in [Vector3(-28,0,16),Vector3(29,0,12)]:
        trees.plant(self,p,10,false,false)
        _collider(p+Vector3.UP*2,Vector3(1,4,1),true,"ForegroundTrunk")
    var fern=_fern_mesh();meshes.fern=fern
    for i in range(100):
        var p=Vector3(rng.randf_range(-34,34),0,rng.randf_range(-28,28))
        if absf(p.x)<26 and absf(p.z)<25:continue
        _batch("fern","fern",p,Vector3.ONE*rng.randf_range(.4,.9),Basis(Vector3.UP,rng.randf()*TAU))

func _trail(points: Array[Vector3],width:=2.2) -> void:_ribbon(points,width)

func _orchard() -> void:
    _trail([Vector3(0,0,25),Vector3(-10,0,12),Vector3(-15,0,0),Vector3(0,0,-10),Vector3(15,0,-16),Vector3(0,0,-26)])
    materials.apple=_mat(Color("b26c45"));materials.beehive=_mat(Color("c09a61"))
    for x in [-22,-10,10,22]:
        for z in [-17,-2,12]:
            if x==10 and z==-17:continue # Leave the guide's final bend physically clear.
            var p=Vector3(x,0,z)
            trees.plant(self,p,5.5+float(posmod(x+z,3)),false,false)
            _collider(p+Vector3.UP*1.5,Vector3(.6,3,.6),true,"OrchardTrunk")
            for i in range(5):
                var angle=i*TAU/5
                _batch("sphere","apple",p+Vector3(cos(angle)*1.4,3.7+sin(angle)*.25,sin(angle)*1.4),Vector3.ONE*.22)
    for p in [Vector3(-26,0,6),Vector3(25,0,-7)]:
        _batch("cylinder","wood",p+Vector3.UP*.5,Vector3(1,.9,1))
        _batch("sphere","beehive",p+Vector3.UP*1.2,Vector3(1,.7,1))
    _bench(Vector3(5,0,17),.3)
    _sign(Vector3(-5,1.8,16),"РАЗВЕДЧИК ПОКАЖЕТ ТРОПУ\nНе оставляйте его далеко позади.",0)

func _mill() -> void:
    _trail([Vector3(0,0,25),Vector3(0,0,11),Vector3(0,0,3)])
    _trail([Vector3(-18,0,9),Vector3(0,0,12),Vector3(18,0,9)])
    _trail([Vector3(0,0,-9),Vector3(0,0,-25)])
    water_surface=_dynamic_box(self,Vector3(0,-.02,-3),Vector3(68,.025,9),materials.water)
    water_surface.name="SluiceWaterLevel"
    _collider(Vector3(-20,.5,-3),Vector3(34,1,9),true,"MillRiverBank")
    _collider(Vector3(14,.5,-3),Vector3(22,1,9),true,"MillRiverBank")
    _collider(Vector3(33,.5,-3),Vector3(8,1,9),true,"MillRiverBank")
    # A narrow public footbridge keeps the forest route open. The sluice
    # puzzle still controls the mill bridge and access to its quest reward.
    for z in range(-8,4):_batch("box","wood_light",Vector3(27,.035,z),Vector3(4,.07,.85))
    for x in [25.0,29.0]:
        _batch("box","wood",Vector3(x,.65,-2.5),Vector3(.12,1.3,12))
    _sign(Vector3(27,1.8,7),"ЛЕСНАЯ ТРОПА\nПешеходный мост",0)
    for z in range(-8,4):_batch("box","wood_light",Vector3(0,.035,z),Vector3(5,.07,.85))
    for x in [-2.5,2.5]:
        _batch("box","wood",Vector3(x,.7,-2.5),Vector3(.12,1.4,12))
    bridge_gate=StaticBody3D.new();bridge_gate.name="RaisedBridgeBarrier";bridge_gate.collision_layer=1
    var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(5,2,.4);shape.shape=box;shape.position=Vector3(0,1,3.7)
    bridge_gate.add_child(shape);add_child(bridge_gate)
    _dynamic_box(bridge_gate,Vector3(0,1.2,3.7),Vector3(4.8,2.4,.16),materials.wood_light,Basis(Vector3.RIGHT,-.22))
    _batch("box","wood",Vector3(20,2.5,-12),Vector3(9,5,8))
    for side in [-1,1]:_batch("box","roof",Vector3(20+side*2.4,5.6,-12),Vector3(5.7,.18,9),Basis(Vector3.FORWARD,side*-.4))
    _batch("box","stone",Vector3(20,.15,-12),Vector3(9.5,.3,8.5))
    for x in [17.3,20.0,22.7]:
        _batch("box","iron",Vector3(x,2.6,-7.92),Vector3(1.5,1.8,.07))
        _batch("box","lamp",Vector3(x,2.6,-7.87),Vector3(1.25,1.55,.03))
        for side in [-1,1]:_batch("box","wood_light",Vector3(x+side*.7,2.6,-7.83),Vector3(.12,1.85,.08))
    for y in [.7,1.4,2.1,2.8,3.5,4.2]:_batch("box","wood_light",Vector3(20,y,-7.85),Vector3(9,.04,.07))
    _collider(Vector3(20,2.5,-12),Vector3(9,5,8),true,"WatermillBuilding")
    wheel=Node3D.new();wheel.name="WorkingWaterWheel";wheel.position=Vector3(14.8,2.4,-9);add_child(wheel)
    var ring=TorusMesh.new();ring.inner_radius=2.0;ring.outer_radius=2.2;ring.rings=28;ring.ring_segments=6
    var mesh=MeshInstance3D.new();mesh.mesh=ring;mesh.rotation.z=PI*.5;mesh.material_override=materials.wood_light;wheel.add_child(mesh)
    for i in range(10):
        var angle=i*TAU/10
        _dynamic_box(wheel,Vector3(0,cos(angle)*1.7,sin(angle)*1.7),Vector3(.6,.22,1.1),materials.wood,Basis(Vector3.RIGHT,angle))
        _dynamic_box(wheel,Vector3(0,cos(angle)*1.0,sin(angle)*1.0),Vector3(.12,2,.14),materials.wood_light,Basis(Vector3.RIGHT,angle))
    _sign(Vector3(0,1.9,14),"ШЛЮЗЫ\nОткрыт · Закрыт · Открыт.",0)

func _greenhouse() -> void:
    _trail([Vector3(0,0,25),Vector3(-12,0,12),Vector3(-12,0,-2),Vector3(12,0,-2),Vector3(12,0,-18),Vector3(0,0,-26)])
    materials.glass=_mat(Color(.48,.67,.61,.16));materials.glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    for x in [-24,24]:
        for z in [-17,-7,3,13]:
            _batch("cylinder","iron",Vector3(x,3,z),Vector3(.16,6,.16))
    for z in [-17,-7,3,13]:
        _beam(Vector3(-24,6,z),Vector3(0,9,z),.12,"iron")
        _beam(Vector3(0,9,z),Vector3(24,6,z),.12,"iron")
    for x in [-24,24]:_batch("box","glass",Vector3(x,3,-2),Vector3(.03,6,30))
    for x in [-18,-5,5,19]:
        for z in [-12,6]:
            _batch("box","stone",Vector3(x,.3,z),Vector3(3,.6,4))
            _batch("sphere","fern_light",Vector3(x,.85,z),Vector3(2.6,.8,3.5))
            _collider(Vector3(x,.4,z),Vector3(3,.8,4),true,"PlantingBed")
    for p in [Vector3(-12,0,-2),Vector3(12,0,-2)]:
        var pivot=Node3D.new();pivot.name="SunMirror";pivot.position=p+Vector3.UP*2;add_child(pivot);mirrors.append(pivot)
        _dynamic_box(pivot,Vector3.ZERO,Vector3(2.1,2.4,.1),materials.iron)
        var polished=_mat(Color("b3d0cb"));polished.metallic=.5;polished.roughness=.16
        _dynamic_box(pivot,Vector3(0,0,.08),Vector3(1.8,2.1,.03),polished)
        var mirror_body=StaticBody3D.new();mirror_body.collision_layer=1;mirror_body.collision_mask=0
        var mirror_shape=CollisionShape3D.new();var mirror_box=BoxShape3D.new();mirror_box.size=Vector3(2.1,2.4,.15)
        mirror_shape.shape=mirror_box;mirror_body.add_child(mirror_shape);pivot.add_child(mirror_body)
        _batch("cylinder","brass",p+Vector3.UP*.7,Vector3(.16,1.4,.16))
    _batch("sphere","lamp",Vector3(-12,2,17),Vector3.ONE*.5)
    _batch("cylinder","brass",Vector3(12,.25,-17),Vector3(2.2,.5,2.2))
    _batch("cylinder","fern",Vector3(12,1,-17),Vector3(.08,2,.08))
    for i in range(7):
        var angle=i*TAU/7
        _batch("sphere","cream",Vector3(12+cos(angle)*.43,1.94,-17+sin(angle)*.43),Vector3(.55,.16,.38),Basis(Vector3.UP,-angle))
    _batch("sphere","lamp",Vector3(12,2,-17),Vector3.ONE*.32)
    _sign(Vector3(-7,1.8,17),"СТЕКЛЯННЫЙ САД\nСледуй за солнечным лучом.",0)

func _ravine() -> void:
    _batch("box","water",Vector3(0,-4.7,0),Vector3(69,.035,17))
    for x in [-31,31]:
        _batch("sphere","stone",Vector3(x,1,0),Vector3(7,3,20))
    for i in range(RAVINE_ROUTE.size()-1):
        var a: Vector3=RAVINE_ROUTE[i];var b: Vector3=RAVINE_ROUTE[i+1]
        var direction=a.direction_to(b);var turn=Basis(Quaternion(Vector3.FORWARD,direction))
        for n in range(ceili(a.distance_to(b))):
            var p=a+direction*(float(n)+.5)
            _batch("box","wood_light",p+Vector3.UP*.04,Vector3(3.0,.08,.85),turn)
        for side in [-1,1]:
            var offset=direction.cross(Vector3.UP)*side*1.55
            _beam(a+offset+Vector3.UP*.9,b+offset+Vector3.UP*.9,.045,"wood")
    _trail([Vector3(0,0,25),Vector3(-10,0,19),Vector3(-20,0,12)])
    _trail([Vector3(20,0,-14),Vector3(15,0,-20),Vector3(0,0,-26)])
    _sign(Vector3(-13,1.8,17),"МОСТЫ КАЧАЕТ ВЕТРОМ\nТихий шаг помогает держать равновесие.",0)
    for p in [Vector3(-23,0,10),Vector3(23,0,-13)]:_lamp_post(p)

func _camp() -> void:
    _trail([Vector3(0,0,25),Vector3(-18,0,16),Vector3(-22,0,0),Vector3(-10,0,-18),Vector3(0,0,-26)])
    _trail([Vector3(-18,0,16),Vector3(20,0,13),Vector3(23,0,-10),Vector3(0,0,-18)])
    for p in [Vector3(-15,0,-5),Vector3(15,0,2),Vector3(10,0,-19)]:
        for side in [-1,1]:_batch("box","roof",p+Vector3(side*1.4,1.5,0),Vector3(3.5,.12,6),Basis(Vector3.FORWARD,side*-.70))
        _collider(p+Vector3.UP*.8,Vector3(4,1.6,5.5),true,"CanvasTent")
    for p in [Vector3(-7,0,8),Vector3(7,0,8),Vector3(-8,0,-12),Vector3(22,0,-17)]:
        _batch("box","wood",p+Vector3.UP*.7,Vector3(3,1.4,2))
        _collider(p+Vector3.UP*.7,Vector3(3,1.4,2),true,"CampCrateCover")
    _batch("cylinder","iron",Vector3(0,3,-10),Vector3(.18,6,.18))
    _batch("box","brass",Vector3(0,6,-10),Vector3(1.3,.5,.5))
    _sign(Vector3(-7,1.8,20),"ЛАГЕРЬ СБОРЩИКОВ\nКолокол отвлекает. Укрытия скрывают.",0)

func _stone_circle() -> void:
    _trail([Vector3(0,0,25),Vector3(0,0,6),Vector3(0,0,-25)])
    _clearing()
    for i in range(8):
        if i==2:continue # The southern standing-stone gap is the walkable entrance.
        var angle=i*TAU/8
        var p=Vector3(cos(angle)*19,0,-5+sin(angle)*19)
        _batch("sphere","stone",p+Vector3.UP*2.6,Vector3(2.4,5.6,2),Basis(Vector3.UP,angle))
        _collider(p+Vector3.UP*2.6,Vector3(1.7,5.2,1.5),true,"StandingStone")
    _sign(Vector3(0,1.8,14),"ПАМЯТЬ ЛЕСА\nЛИСТ → ЛУНА → ЖЁЛУДЬ → ЛУНА",0)

func _ancient_grove() -> void:
    _trail([Vector3(0,0,25),Vector3(0,0,10),Vector3(0,0,1)])
    _clearing();_oak()
    for x in [-25,25]:
        for z in [-18,-3,12]:
            trees.plant(self,Vector3(x,0,z),12,false,false)
    for p in [Vector3(-14,0,2),Vector3(14,0,2)]:
        _batch("sphere","stone",p+Vector3.UP*.8,Vector3(3,1.6,2))
        _collider(p+Vector3.UP*.7,Vector3(2.8,1.4,1.8),true,"RootArenaCover")
    _sign(Vector3(-7,1.8,17),"СЕРДЦЕ ЛЕСА\nТри печати разбудят древнего стража.",0)

func _dynamic_box(parent: Node3D,p: Vector3,size_: Vector3,mat: Material,turn:=Basis.IDENTITY) -> MeshInstance3D:
    var node=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=size_;node.mesh=mesh;node.position=p;node.basis=turn;node.material_override=mat
    parent.add_child(node);return node

func open_bridge() -> void:
    if is_instance_valid(bridge_gate):bridge_gate.queue_free();bridge_gate=null

func set_light_beams(segments: Array) -> void:
    for node in beam_nodes:node.queue_free()
    beam_nodes.clear()
    for segment in segments:
        var a: Vector3=segment[0];var b: Vector3=segment[1]
        var node=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=.025;mesh.bottom_radius=.025;mesh.height=a.distance_to(b);mesh.radial_segments=6
        node.mesh=mesh;node.position=(a+b)*.5;node.basis=Basis(Quaternion(Vector3.UP,a.direction_to(b)))
        node.material_override=materials.lamp;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);beam_nodes.append(node)

func _sign(p: Vector3,text_: String,yaw: float) -> void:
    _batch("box","wood",p,Vector3(3.6,.9,.14),Basis(Vector3.UP,yaw))
    for x in [-1.25,1.25]:_batch("cylinder","wood",p+Basis(Vector3.UP,yaw)*Vector3(x,-p.y*.5,0),Vector3(.12,p.y,.12))
    var label=Label3D.new();label.name="RegionalTrailSign";label.text=text_;label.font_size=32;label.pixel_size=.0045
    label.width=700;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    label.position=p+Basis(Vector3.UP,yaw)*Vector3(0,0,.09);label.rotation.y=yaw
    label.modulate=Color("e6d8b5");label.outline_size=0;label.no_depth_test=false
    add_child(label)

func open_ravine_shortcut() -> void:
    if shortcut_open:return
    shortcut_open=true
    for z in range(-9,10):_dynamic_box(self,Vector3(0,.04,z),Vector3(3,.08,.85),materials.wood_light)
    for x in [-1.55,1.55]:_dynamic_box(self,Vector3(x,.8,0),Vector3(.045,.045,19),materials.wood)
