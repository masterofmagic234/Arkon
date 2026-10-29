extends Node3D
## Contained stone sluices and a visibly pressure-operated acorn-store shutter.
var gate_open:=0.0
var active:=false
var access_granted:=false
var gate: Node3D
var moving_water: Node3D
var installed_parts: Node3D
var gate_body: StaticBody3D
var world: Node3D
var piston_rod: MeshInstance3D
var pressure_needle: Node3D
var _initialized:=false
var batches: Dictionary={}
func setup(garden_world: Node3D,restored: bool) -> void:
    world=garden_world;name="Waterworks";_build_channels();_build_store();_build_control();_flush()
    gate_open=1.0 if restored else 0.0;active=restored;access_granted=restored;_initialized=true;_present()
func _physics_process(delta: float) -> void:
    if not _initialized:return
    # Once the hydraulic latch is lifted it stays latched for a fair encounter.
    if active and access_granted:gate_open=move_toward(gate_open,1.0,delta*.45)
    _present()
func set_state(running: bool,parts_fitted: bool) -> void:
    active=running;moving_water.visible=running;installed_parts.visible=parts_fitted
func set_access(granted: bool) -> void:
    # The gallery patrol carries the service release. Once latched, the
    # hydraulic leaf remains raised even if presentation is refreshed later.
    access_granted=access_granted or granted
func _present() -> void:
    gate.position.y=gate_open*3.7
    if is_instance_valid(gate_body):gate_body.position.y=gate_open*3.7
    moving_water.visible=active
    if is_instance_valid(piston_rod):
        piston_rod.scale.y=maxf(.02,gate_open*3.7);piston_rod.position=Vector3(3.1,9.7+gate_open*1.85,-33.5)
    if is_instance_valid(pressure_needle):pressure_needle.rotation.z=lerpf(1.1,-1.1,1.0 if active else 0.0)
func _build_channels() -> void:
    var stone=world.mats.trim;var bed=_mat(Color("273f3c"))
    moving_water=Node3D.new();moving_water.name="ContainedFlow";add_child(moving_water)
    var water=world.mats.water.duplicate();water.set_shader_parameter("stream_mode",1.0)
    var path=[Vector2(48,-70),Vector2(47,-52),Vector2(44,-35),Vector2(45,-17),Vector2(44,-4),Vector2(40,10),Vector2(34,19),Vector2(18.7,23)]
    # Short terrain-following segments sit inside masonry troughs, including
    # vertical terrace spillways. No blue ribbons cross open space or steps.
    for segment in range(path.size()-1):
        var a: Vector2=path[segment];var b: Vector2=path[segment+1];var n=maxi(1,ceili(a.distance_to(b)/1.0))
        for j in range(n):
            var p=a.lerp(b,float(j)/n);var q=a.lerp(b,float(j+1)/n)
            var y0: float=world.surface_height_at(p.x,p.y)+.10;var y1: float=world.surface_height_at(q.x,q.y)+.10
            var v0=Vector3(p.x,y0,p.y);var v1=Vector3(q.x,y1,q.y);var side=Vector2(q.y-p.y,p.x-q.x).normalized()*.42
            _ribbon(moving_water,v0,v1,side*.82,water)
            var foundation=BoxMesh.new();foundation.size=Vector3(.94,.16,v0.distance_to(v1)+.03)
            _append(self,foundation,Transform3D(Basis.looking_at((v1-v0).normalized(),Vector3.UP),(v0+v1)*.5-Vector3.UP*.12),stone)
            _ribbon(self,v0-Vector3.UP*.035,v1-Vector3.UP*.035,side,bed)
            for sign_ in [-1,1]:
                var shift=Vector3(side.x,0,side.y)*sign_
                var middle=(v0+v1)*.5+shift+Vector3.UP*.06
                var mesh=BoxMesh.new();mesh.size=Vector3(.12,.20,v0.distance_to(v1)+.03)
                _append(self,mesh,Transform3D(Basis.looking_at((v1-v0).normalized(),Vector3.UP),middle),stone)
    # The last outlet is a real downward-facing pipe at the reflecting pool rim.
    var pipe=CylinderMesh.new();pipe.top_radius=.16;pipe.bottom_radius=.16;pipe.height=2.6;pipe.radial_segments=12
    _append(self,pipe,Transform3D(Basis(Vector3.FORWARD,PI*.5),Vector3(20.1,3.24,23)),_mat(Color("53655f")))
func _ribbon(parent: Node3D,a: Vector3,b: Vector3,side: Vector2,mat: Material) -> void:
    var off=Vector3(side.x,0,side.y);var pts=[a-off,a+off,b-off,b+off];var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for k in [0,1,2,1,3,2]:st.set_normal(Vector3.UP);st.set_uv(Vector2(0 if k%2==0 else 1,0 if k<2 else 1));st.add_vertex(pts[k])
    st.generate_normals();_append(parent,st.commit(),Transform3D.IDENTITY,mat)
func _build_store() -> void:
    var iron=_mat(Color("4b5b5b"));var stone=world.mats.trim
    var base=Vector3(0,7,-36)
    for x in [-2.4,2.4]:
        _solid(base+Vector3(x,1.2,0),Vector3(.20,2.4,5.1),"StoreSide")
    for i in range(13):_box(self,base+Vector3(-2.4+i*.4,1.3,-2.5),Vector3(.10,2.6,.10),iron)
    _solid(base+Vector3(0,1.2,-2.5),Vector3(4.9,2.4,.20),"StoreBack")
    # Side panels are separated vertical bars, while physics seals the gaps.
    for x in [-2.4,2.4]:
        for z in range(10):_box(self,base+Vector3(x,1.3,-2.3+z*.5),Vector3(.10,2.6,.10),iron)
    gate=Node3D.new();gate.name="HydraulicStoreGate";add_child(gate)
    for x in range(13):_box(gate,base+Vector3(-2.4+x*.4,1.35,2.5),Vector3(.075,2.7,.09),iron)
    for y in [.25,2.5]:_box(gate,base+Vector3(0,y,2.5),Vector3(4.95,.11,.12),iron)
    gate_body=_solid(base+Vector3(0,1.35,2.5),Vector3(4.95,2.7,.16),"StoreGateCollider")
    # Collision body's local origin is at root: its shape is offset to the leaf.
    gate_body.position=Vector3.ZERO
    _box(self,base+Vector3(-2.8,3.4,2.5),Vector3(.36,6.8,.4),stone)
    _box(self,base+Vector3(2.8,3.4,2.5),Vector3(.36,6.8,.4),stone)
    _box(self,base+Vector3(0,6.8,2.5),Vector3(6.0,.42,.45),stone)
    # The pressure line and moving ram make the lock's cause/effect explicit.
    var line=[Vector2(23,19),Vector2(25,8),Vector2(9,8),Vector2(9,-18),Vector2(5,-23),Vector2(3.1,-33.5)]
    for i in range(line.size()-1):
        var a: Vector2=line[i];var b: Vector2=line[i+1];var steps=maxi(1,ceili(a.distance_to(b)/1.5))
        for j in range(steps):
            var p=a.lerp(b,float(j)/steps);var q=a.lerp(b,float(j+1)/steps)
            var v0=Vector3(p.x,world.surface_height_at(p.x,p.y)+.16,p.y);var v1=Vector3(q.x,world.surface_height_at(q.x,q.y)+.16,q.y)
            var pipe=CylinderMesh.new();pipe.top_radius=.075;pipe.bottom_radius=.075;pipe.height=v0.distance_to(v1);pipe.radial_segments=8
            _append(self,pipe,Transform3D(Basis(Quaternion(Vector3.UP,v0.direction_to(v1))),(v0+v1)*.5),iron)
    var barrel=CylinderMesh.new();barrel.top_radius=.14;barrel.bottom_radius=.14;barrel.height=2.7;barrel.radial_segments=12
    _append(self,barrel,Transform3D(Basis.IDENTITY,Vector3(3.1,8.35,-33.5)),iron)
    var rod=CylinderMesh.new();rod.top_radius=.065;rod.bottom_radius=.065;rod.height=1.0;rod.radial_segments=12
    piston_rod=MeshInstance3D.new();piston_rod.name="HydraulicPistonRod";piston_rod.mesh=rod;piston_rod.material_override=_mat(Color("adb9af"));piston_rod.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(piston_rod)
    _box(gate,Vector3(2.8,9.6,-33.5),Vector3(.8,.23,.17),iron)
func _build_control() -> void:
    var case_mat=_mat(Color("5a6b66"));var brass=_mat(Color("c09c5e"))
    _box(self,Vector3(23,3.75,19),Vector3(1.35,1.5,.45),case_mat)
    var gauge=TorusMesh.new();gauge.inner_radius=.11;gauge.outer_radius=.15;gauge.rings=16;gauge.ring_segments=6
    _append(self,gauge,Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(23,4.32,19.28)),brass)
    pressure_needle=Node3D.new();pressure_needle.name="PressureGaugeNeedle";pressure_needle.position=Vector3(23,4.32,19.29);add_child(pressure_needle)
    _box(pressure_needle,Vector3(0,.055,0),Vector3(.022,.13,.025),brass)
    installed_parts=Node3D.new();installed_parts.name="FittedPumpFuse";add_child(installed_parts)
    var part=preload("res://scripts/botanical_service_parts.gd").build(0);part.position=Vector3(23,3.9,19.27);part.scale=Vector3.ONE*.75;installed_parts.add_child(part)
func _mat(color: Color) -> StandardMaterial3D:
    var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.85;return m
func _box(parent: Node3D,p: Vector3,size: Vector3,mat: Material) -> void:
    var mesh=BoxMesh.new();mesh.size=size;_append(parent,mesh,Transform3D(Basis.IDENTITY,p),mat)
func _solid(p: Vector3,size: Vector3,title: String) -> StaticBody3D:
    var body=StaticBody3D.new();body.name=title;body.collision_layer=1;var shape=BoxShape3D.new();shape.size=size;var cs=CollisionShape3D.new();cs.position=p;cs.shape=shape;body.add_child(cs);add_child(body);return body

func _append(parent: Node3D,mesh: Mesh,transform_: Transform3D,mat: Material) -> void:
    var key=str(parent.get_instance_id())+":"+str(mat.get_instance_id())
    if not batches.has(key):
        var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        batches[key]={"parent":parent,"material":mat,"surface":surface}
    var surface: SurfaceTool=batches[key].surface;surface.append_from(mesh,0,transform_)
func _flush() -> void:
    for record in batches.values():
        var surface: SurfaceTool=record.surface;surface.index()
        var node=MeshInstance3D.new();node.mesh=surface.commit();node.material_override=record.material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC;record.parent.add_child(node)
    batches.clear()
