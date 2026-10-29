extends Node3D
## The conservatory has one physical, keyed entrance. The older inner shutter
## still protects the acorn store; both leaves use the same hydraulic release.
const GATE_Z := -22.3
const FLOOR_Y := 7.26
const LEVER := Vector3(4.1,7.0,-20.4)
var leaf: Node3D
var gate_body: StaticBody3D
var gate_halves: Array[Node3D]=[]
var lever_handle: Node3D
var key_indicator: MeshInstance3D
var _surfaces: Dictionary={}
var _glass_points := PackedVector3Array()
var _gate_material: StandardMaterial3D
var _shown_open:=-1.0
var _shown_key:=false
var _shown_release:=false

func setup(world: Node3D) -> void:
    name="KeyedConservatoryEntrance"
    _gate_material=StandardMaterial3D.new();_gate_material.albedo_color=Color("465850");_gate_material.roughness=.78;_gate_material.metallic=.35
    leaf=Node3D.new();leaf.name="OuterKeyedDoubleDoors";add_child(leaf)
    for side in [-1.0,1.0]:
        var half:=Node3D.new();half.name="LeftLeaf" if side<0 else "RightLeaf";half.position=Vector3(side*2.925,0,GATE_Z);leaf.add_child(half);gate_halves.append(half)
        for index in range(8):_box(half,Vector3(-side*(.04+index*.407),FLOOR_Y+2.32,0),Vector3(.065,4.64,.10),_gate_material)
        for y in [.10,1.75,4.55]:_box(half,Vector3(-side*1.4625,FLOOR_Y+y,0),Vector3(2.925,.12,.14),_gate_material)
        var body:=StaticBody3D.new();body.name="KeyedConservatoryGateCollider";body.collision_layer=1;body.collision_mask=0;body.set_meta("conservatory_gate151",true);body.set_meta("audio_surface",&"metal");half.add_child(body)
        var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2.925,4.64,.22);collider.position=Vector3(-side*1.4625,FLOOR_Y+2.32,0);collider.shape=box;body.add_child(collider)
        if gate_body==null:gate_body=body
    # The old shell omits two full front bays. Glazed side returns, fanlight
    # and canopy close that real opening around the moving central leaf.
    for side in [-1.0,1.0]:
        var a:=Vector3(side*3.0,FLOOR_Y,GATE_Z)
        var b:=Vector3(side*4.592201,FLOOR_Y,-23.913445)
        _glazed_quad(a,b,a+Vector3.UP*6,b+Vector3.UP*6,world.mats.glass)
        _beam(a+Vector3.UP*2.0,b+Vector3.UP*2.0,.08,_gate_material)
        _beam(a+Vector3.UP*5.92,b+Vector3.UP*5.92,.10,_gate_material)
        var front0:=Vector3(0,13.25,GATE_Z)
        var front1:=Vector3(side*3.0,13.25,GATE_Z)
        var back0:=Vector3(0,13.25,-23.0)
        var back1:=Vector3(side*4.592201,13.25,-23.913445)
        _glazed_quad(front0,front1,back0,back1,world.mats.glass)
    _glazed_quad(Vector3(-3,11.84,GATE_Z),Vector3(3,11.84,GATE_Z),Vector3(-3,13.25,GATE_Z),Vector3(3,13.25,GATE_Z),world.mats.glass)
    _repair_roof_panels(world.mats.glass)
    _make_lever(world.mats.trim)
    _flush()
    var glass_body:=StaticBody3D.new();glass_body.name="ConservatoryAccessGlazing";glass_body.collision_layer=1;glass_body.set_meta("audio_surface",&"stone");add_child(glass_body)
    var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(_glass_points)
    var collider:=CollisionShape3D.new();collider.shape=shape;glass_body.add_child(collider)
    present(0.0,false,false)

func present(opened: float,has_key: bool,released: bool) -> void:
    if is_equal_approx(opened,_shown_open) and has_key==_shown_key and released==_shown_release:return
    _shown_open=opened;_shown_key=has_key;_shown_release=released
    for index in range(gate_halves.size()):gate_halves[index].rotation.y=opened*PI*.5*(1.0 if index==0 else -1.0)
    lever_handle.rotation.x=lerpf(-.65,.65,1.0 if released else 0.0)
    var material:=key_indicator.material_override as StandardMaterial3D
    material.albedo_color=Color("a1b87b") if released else (Color("cfb777") if has_key else Color("786f57"))

func _repair_roof_panels(glass: Material) -> void:
    # Replace only the deliberately missing panels, using exactly the existing
    # dome vertices. A player dropping from the upper terrace cannot fall into
    # a locked conservatory through a decorative broken-glass opening.
    var center:=Vector3(0,13.2,-35)
    for i in range(24):
        for j in range(10):
            if (i+j)%13!=0:continue
            var points: Array[Vector3]=[]
            for uv in [Vector2(i,j),Vector2(i+1,j),Vector2(i,j+1),Vector2(i+1,j+1)]:
                var angle: float=uv.x*TAU/24;var phi: float=uv.y*PI*.5/10
                points.append(center+Vector3(cos(angle)*12.2*cos(phi),sin(phi)*7.3,sin(angle)*12.2*cos(phi)))
            _glazed_quad(points[0],points[1],points[2],points[3],glass)

func _make_lever(stone: Material) -> void:
    _box(self,LEVER+Vector3(0,.5,0),Vector3(.65,1.0,.60),stone)
    _box(self,LEVER+Vector3(0,1.07,0),Vector3(.8,.14,.72),_gate_material)
    lever_handle=Node3D.new();lever_handle.name="KeyedReleaseLever";lever_handle.position=LEVER+Vector3(0,1.16,0);add_child(lever_handle)
    _box(lever_handle,Vector3(0,.28,0),Vector3(.085,.58,.085),_gate_material)
    _box(lever_handle,Vector3(0,.56,0),Vector3(.38,.12,.13),_gate_material)
    key_indicator=MeshInstance3D.new();key_indicator.name="GalleryKeySlot";var key_plate:=BoxMesh.new();key_plate.size=Vector3(.16,.22,.025);key_indicator.mesh=key_plate
    var brass:=StandardMaterial3D.new();brass.albedo_color=Color("786f57");brass.roughness=.55;key_indicator.material_override=brass;key_indicator.position=LEVER+Vector3(0,.73,.315);key_indicator.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC;key_indicator.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(key_indicator)
    # A visible keyhole, rather than a coloured plate alone, explains why the
    # handle cannot move before the gallery key is recovered.
    var slot:=StandardMaterial3D.new();slot.albedo_color=Color("101817");slot.roughness=.95
    var keyhole:=CylinderMesh.new();keyhole.top_radius=.026;keyhole.bottom_radius=.026;keyhole.height=.012;keyhole.radial_segments=10
    _append(self,keyhole,Transform3D(Basis(Vector3.RIGHT,PI*.5),LEVER+Vector3(0,.768,.335)),slot)
    _box(self,LEVER+Vector3(0,.726,.335),Vector3(.025,.065,.012),slot)
    _solid(LEVER+Vector3(0,.53,0),Vector3(.68,1.06,.66),"ConservatoryLeverPedestal")

func _box(parent: Node3D,at: Vector3,size_: Vector3,material: Material) -> void:
    var mesh:=BoxMesh.new();mesh.size=size_;_append(parent,mesh,Transform3D(Basis.IDENTITY,at),material)

func _beam(a: Vector3,b: Vector3,thickness: float,material: Material) -> void:
    var mesh:=BoxMesh.new();mesh.size=Vector3(thickness,thickness,a.distance_to(b));_append(self,mesh,Transform3D(Basis.looking_at(a.direction_to(b)),(a+b)*.5),material)

func _glazed_quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,material: Material) -> void:
    var points: Array[Vector3]=[a,b,c,d]
    var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index in [0,2,1,1,2,3]:surface.add_vertex(points[index]);_glass_points.append(points[index])
    surface.generate_normals();_append(self,surface.commit(),Transform3D.IDENTITY,material)

func _append(parent: Node3D,mesh: Mesh,at: Transform3D,material: Material) -> void:
    var key:=str(parent.get_instance_id())+":"+str(material.get_instance_id())
    if not _surfaces.has(key):
        var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);_surfaces[key]={"surface":surface,"parent":parent,"material":material}
    _surfaces[key].surface.append_from(mesh,0,at)

func _flush() -> void:
    for record in _surfaces.values():
        var surface: SurfaceTool=record.surface;surface.index()
        var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=record.material;mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;record.parent.add_child(mesh)
    _surfaces.clear()

func _solid(at: Vector3,size_: Vector3,title: String) -> StaticBody3D:
    var body:=StaticBody3D.new();body.name=title;body.collision_layer=1;body.collision_mask=0;body.set_meta("audio_surface",&"metal");add_child(body)
    var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size_;shape.shape=box;shape.position=at;body.add_child(shape);return body
