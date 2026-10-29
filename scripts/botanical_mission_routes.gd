extends Node3D
## Scene-local pressure bridge: the original garden, bake and planting stay intact.
var opened:=0.0
var powered:=false
var leaves: Array[Node3D]=[]
var crossing_shapes: Array[CollisionShape3D]=[]
var closed_shapes: Array[CollisionShape3D]=[]
var director: Node3D
var _batches: Dictionary={}

func setup(owner_: Node3D,restored: bool) -> void:
    director=owner_;name="HydraulicPondShortcut"
    var wood=_mat(Color("706b50"));var iron=_mat(Color("485953"));var brass=_mat(Color("b49a5f"))
    # Fixed approaches land on the authored terrain on both sides of the pool.
    _deck(self,Vector3(0,3.35,10),Vector3(0,3.90,13),4.2,wood,true)
    _deck(self,Vector3(0,3.90,34),Vector3(0,.08,45),4.2,wood,true)
    for end in [13.0,34.0]:
        var leaf=Node3D.new();leaf.position=Vector3(0,3.90,end);add_child(leaf);leaves.append(leaf)
        var direction=1.0 if end<20 else -1.0
        _deck(leaf,Vector3.ZERO,Vector3(0,0,direction*10.5),4.2,wood,false)
        for side in [-1,1]:
            for step in range(8):
                var z=direction*(.3+step*1.4)
                _box(leaf,Vector3(side*2.0,.5,z),Vector3(.09,1.0,.09),iron)
            _box(leaf,Vector3(side*2.0,1.0,direction*5.25),Vector3(.10,.10,10.5),brass)
    for side in [-1,1]:
        var body=StaticBody3D.new();body.name="PressureBridgeRail";body.collision_layer=1;add_child(body)
        var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.14,1.05,21)
        shape.shape=box;shape.position=Vector3(side*2.0,4.42,23.5);shape.disabled=true;body.add_child(shape);crossing_shapes.append(shape)
    for z in [12.5,34.5]:
        for side in [-1,1]:
            _box(self,Vector3(side*2.35,3.55,z),Vector3(.6,1.4,.8),iron)
            var ram=CylinderMesh.new();ram.top_radius=.12;ram.bottom_radius=.12;ram.height=1.6;ram.radial_segments=8
            var mesh=MeshInstance3D.new();mesh.mesh=ram;mesh.material_override=brass;mesh.position=Vector3(side*2.35,4.4,z);_visual(mesh);add_child(mesh)
    var sign=Label3D.new();sign.text="СЛУЖЕБНЫЙ МОСТ";sign.font_size=22;sign.pixel_size=.0025;sign.position=Vector3(0,4.9,11);sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.visibility_range_end=8;add_child(sign)
    _flush();powered=restored;opened=1.0 if restored else 0.0;_present()
    var paths: Array=director.world.get_meta("audio_paths",[])
    paths.append({"points":[Vector2(0,10),Vector2(0,45)],"half_width":2.1,"surface":&"wood"})
    director.world.set_meta("audio_paths",paths)

func set_powered(value: bool) -> void:powered=value

func _physics_process(delta: float) -> void:
    if powered:opened=move_toward(opened,1.0,delta*.42)
    _present()

func _present() -> void:
    for i in range(leaves.size()):leaves[i].rotation.x=(1.0-opened)*deg_to_rad(-74 if i==0 else 74)
    for shape in crossing_shapes:
        var disabled=opened<.995
        if shape.disabled!=disabled:shape.set_deferred("disabled",disabled)
    for shape in closed_shapes:
        var disabled=opened>=.995
        if shape.disabled!=disabled:shape.set_deferred("disabled",disabled)

func _deck(parent: Node3D,a: Vector3,b: Vector3,width: float,material: Material,fixed: bool) -> void:
    var vector=b-a;var basis=Basis(Quaternion(Vector3.FORWARD,vector.normalized()))
    var center=(a+b)*.5-Vector3.UP*.11
    var size_=Vector3(width,.22,a.distance_to(b)+.06)
    var deck=BoxMesh.new();deck.size=size_;_append(parent,deck,Transform3D(basis,center),material)
    var body=StaticBody3D.new();body.name="PressureBridgeDeck";body.collision_layer=1;body.set_meta("audio_surface",&"wood")
    # Moving leaves use their final, horizontal physical footprint. They only
    # become walkable when the two visible leaves have fully met.
    var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size_;shape.shape=box
    if fixed:
        shape.position=center;shape.basis=basis;parent.add_child(body)
    else:
        shape.position=parent.position+center;shape.basis=basis;add_child(body);shape.disabled=true;crossing_shapes.append(shape)
    body.add_child(shape)
    if not fixed:
        # The raised wooden leaf is solid too. Without this physical face the
        # fixed approach lets a player drop onto the old solid pond volume.
        # Attaching the collider to the leaf keeps it aligned during lowering;
        # the horizontal deck takes over only when the crossing is fully open.
        var raised_body=StaticBody3D.new();raised_body.name="ClosedPressureBridgeLeaf";raised_body.collision_layer=1;raised_body.set_meta("audio_surface",&"wood");parent.add_child(raised_body)
        var raised_shape=CollisionShape3D.new();raised_shape.shape=box;raised_shape.position=center;raised_shape.basis=basis;raised_body.add_child(raised_shape);closed_shapes.append(raised_shape)

func _mat(color: Color) -> StandardMaterial3D:
    var material=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.86;return material

func _box(parent: Node3D,at: Vector3,size_: Vector3,material: Material) -> void:
    var box=BoxMesh.new();box.size=size_;_append(parent,box,Transform3D(Basis.IDENTITY,at),material)

func _append(parent: Node3D,mesh: Mesh,at: Transform3D,material: Material) -> void:
    var key=str(parent.get_instance_id())+":"+str(material.get_instance_id())
    if not _batches.has(key):
        var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        _batches[key]={"parent":parent,"material":material,"surface":surface}
    var surface: SurfaceTool=_batches[key].surface;surface.append_from(mesh,0,at)

func _flush() -> void:
    for record in _batches.values():
        var surface: SurfaceTool=record.surface;surface.index()
        var mesh=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=record.material;_visual(mesh);record.parent.add_child(mesh)
    _batches.clear()

func _visual(mesh: MeshInstance3D) -> void:
    mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
