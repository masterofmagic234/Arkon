extends RefCounted
# Original low-poly ORЕХ-1 air unit. One shared vehicle viewport, no lights,
# particles, physics bodies or per-frame mesh generation.
const Data=preload("res://scripts/race_level_data.gd")
var root: Node3D
var rotor: Node3D
var rotor_mount: Node3D
var blade_roots: Array[Node3D]=[]
var tail_rotor: Node3D
var beacon: MeshInstance3D
var meshes: Dictionary={}
var materials: Dictionary={}
var mesh_count := 0
var scenery_depth=preload("res://scripts/race_scenery_depth.gd").new()

func build(world: Node3D) -> void:
    root=Node3D.new();root.name="SquirrelHelicopter";world.add_child(root);root.visible=false
    var ball:=SphereMesh.new();ball.radius=.5;ball.height=1;ball.radial_segments=16;ball.rings=8;meshes.ball=ball
    var box:=BoxMesh.new();meshes.box=box
    var tube:=CylinderMesh.new();tube.top_radius=.5;tube.bottom_radius=.5;tube.height=1;tube.radial_segments=10;meshes.tube=tube
    var cone:=CylinderMesh.new();cone.top_radius=.08;cone.bottom_radius=.5;cone.height=1;cone.radial_segments=10;meshes.cone=cone
    for item in [["shell","28363e",.62,.22],["ivory","d7d6bf",.68,.12],["tail","6b7474",.76,.12],["glass","285866",.20,.18],["metal","131d25",.74,.25],["gold","e6a13e",.58,.24],["red","ff6658",.8,0],["mint","a4ece0",.8,0]]:
        var m:=ShaderMaterial.new();m.shader=preload("res://shaders/race_airframe.gdshader")
        m.set_shader_parameter("paint",Color(item[1]));m.set_shader_parameter("roughness",item[2]);m.set_shader_parameter("metallic",item[3])
        if item[0] in ["red","mint"]: m.set_shader_parameter("emission_energy",2.0)
        materials[item[0]]=m
    _part(root,"ball","shell",Vector3(0,0,0),Vector3(2.8,2.05,4.8))
    _part(root,"ball","ivory",Vector3(0,-.58,.25),Vector3(2.55,.78,3.7))
    _part(root,"ball","glass",Vector3(0,.12,1.42),Vector3(2.54,1.65,2.15))
    # Windshield crossbars and chin/nose give the cabin a clear front heading.
    _beam(root,"ivory",Vector3(0,-.30,2.39),Vector3(0,.75,2.04),.10)
    _beam(root,"ivory",Vector3(-1.04,.15,1.95),Vector3(1.04,.15,1.95),.08)
    _part(root,"ball","shell",Vector3(0,-.48,2.0),Vector3(1.9,.55,1.1))
    for side: float in [-1,1]:
        _part(root,"ball","metal",Vector3(side*.7,.86,-.55),Vector3(.73,.55,1.8))
        _part(root,"ball","metal",Vector3(side*.76,.72,-1.48),Vector3(.43,.43,.31))
        # Ear-shaped intake fins: the squirrel silhouette is part of the craft.
        var ear:=_fin(PackedVector3Array([Vector3(side*.65,.7,.1),Vector3(side*1.18,2.0,-.25),Vector3(side*1.38,.64,-.6)]),materials.ivory)
        root.add_child(ear)
        _beam(root,"gold",Vector3(side*1.25,-.1,-.2),Vector3(side*1.25,-.1,1.0),.07)
        # Landing skids with swept upturned noses, not hanging wheel blocks.
        _beam(root,"metal",Vector3(side*.82,-.55,-1.10),Vector3(side*1.25,-1.52,-1.1),.10)
        _beam(root,"metal",Vector3(side*.82,-.55,1.04),Vector3(side*1.25,-1.52,1.04),.10)
        _beam(root,"ivory",Vector3(side*1.25,-1.55,-2.0),Vector3(side*1.25,-1.55,1.7),.12)
        _beam(root,"ivory",Vector3(side*1.25,-1.55,1.7),Vector3(side*1.25,-1.26,2.05),.12)
        # Solid acorn insignia, cream cap and amber nut, on both cabin flanks.
        _part(root,"ball","gold",Vector3(side*1.37,.06,-.35),Vector3(.10,.57,.42))
        _part(root,"ball","ivory",Vector3(side*1.39,.31,-.35),Vector3(.12,.23,.53))
        _beam(root,"ivory",Vector3(side*1.4,.35,-.35),Vector3(side*1.4,.54,-.45),.07)
    _beam(root,"shell",Vector3(0,.2,-1.3),Vector3(0,.74,-5.8),.48)
    _part(root,"box","ivory",Vector3(0,.70,-4.5),Vector3(2.85,.10,.65))
    _part(root,"box","gold",Vector3(0,.72,-4.5),Vector3(.8,.12,.69))
    # A curled tail fin makes the silhouette recognizably squirrel-themed.
    _tail_fin()
    _beam(root,"metal",Vector3(0,.9,-5.5),Vector3(.42,.9,-5.5),.12)
    tail_rotor=Node3D.new();tail_rotor.position=Vector3(.46,.9,-5.5);root.add_child(tail_rotor)
    for i in range(3):
        var blade:=_part(tail_rotor,"box","metal",Vector3.ZERO,Vector3(.06,1.65,.13));blade.rotation.x=i*TAU/3
    _beam(root,"metal",Vector3(0,.8,-.15),Vector3(0,2.25,-.15),.16)
    rotor_mount=Node3D.new();rotor_mount.position=Vector3(0,2.30,-.15);root.add_child(rotor_mount)
    rotor=Node3D.new();rotor_mount.add_child(rotor)
    _part(rotor,"ball","ivory",Vector3.ZERO,Vector3(.55,.3,.55))
    for i in range(4):
        var blade_root:=Node3D.new();blade_root.rotation.y=i*PI*.5;rotor.add_child(blade_root);blade_roots.append(blade_root)
        _part(blade_root,"box","metal",Vector3(2.35,0,0),Vector3(4.55,.055,.27))
        _part(blade_root,"box","gold",Vector3(4.43,.002,0),Vector3(.38,.065,.28))
    var blur:=MeshInstance3D.new();var disc:=PlaneMesh.new();disc.size=Vector2(9.1,9.1);blur.mesh=disc
    var blur_material:=ShaderMaterial.new();blur_material.shader=preload("res://shaders/race_rotor_blur.gdshader")
    materials.rotor_blur=blur_material;blur.material_override=blur_material
    blur.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;rotor_mount.add_child(blur);mesh_count+=1
    var tail_blur:=MeshInstance3D.new();var tail_disc:=PlaneMesh.new();tail_disc.size=Vector2(1.7,1.7)
    tail_blur.mesh=tail_disc;tail_blur.rotation.z=PI*.5;tail_blur.material_override=blur_material
    tail_blur.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;tail_rotor.add_child(tail_blur);mesh_count+=1
    _part(root,"ball","metal",Vector3(0,-.78,1.5),Vector3(.55,.5,.55))
    _part(root,"ball","mint",Vector3(0,-.98,1.65),Vector3(.35,.12,.3))
    # Reusable stinger dispenser under the belly, with four visible magazines.
    _part(root,"box","metal",Vector3(0,-1.0,-.35),Vector3(1.15,.35,1.9))
    for i in range(4): _part(root,"tube","gold",Vector3((i-1.5)*.24,-1.2,-.35),Vector3(.13,.12,1.3)).rotation.x=PI*.5
    beacon=_part(root,"ball","red",Vector3(0,1.12,-1.65),Vector3(.18,.16,.18))
    # Mesh lettering shares the same per-pixel occlusion as the entire hull.
    var text:=TextMesh.new();text.text="ОРЕХ-1";text.font_size=64;text.pixel_size=.006;text.depth=.004
    var code:=MeshInstance3D.new();code.mesh=text;code.material_override=materials.ivory
    code.position=Vector3(1.43,.08,-1.1);code.rotation.y=PI*.5;code.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(code);mesh_count+=1

func _part(parent: Node3D,shape: String,material: String,p: Vector3,s: Vector3) -> MeshInstance3D:
    var node:=MeshInstance3D.new();node.mesh=meshes[shape];node.material_override=materials[material]
    node.position=p;node.scale=s;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node);mesh_count+=1
    return node

func _beam(parent: Node3D,material: String,a: Vector3,b: Vector3,width: float) -> void:
    var node:=_part(parent,"tube",material,(a+b)*.5,Vector3(width,a.distance_to(b),width))
    node.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))*Basis.from_scale(Vector3(width,a.distance_to(b),width))

func _fin(points: PackedVector3Array,material: Material) -> MeshInstance3D:
    var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index in [0,1,2,2,1,0]: st.add_vertex(points[index])
    st.generate_normals();var node:=MeshInstance3D.new();node.mesh=st.commit();node.material_override=material
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh_count+=1;return node

func _tail_fin() -> void:
    # A continuous tapered plume, rather than an empty white ring. Its hooked
    # profile is the aircraft's squirrel tail / vertical stabilizer.
    var path: Array[Vector3]=[];var radii: Array[float]=[]
    for i in range(21):
        var t:=float(i)/20
        if t<=.6:
            path.append(Vector3(0,.74,-5.7).bezier_interpolate(Vector3(0,1.5,-6.6),Vector3(0,2.8,-6.5),Vector3(0,2.95,-5.7),t/.6))
        else:
            path.append(Vector3(0,2.95,-5.7).bezier_interpolate(Vector3(0,3.05,-4.9),Vector3(0,2.4,-4.65),Vector3(0,2.15,-5.1),(t-.6)/.4))
        radii.append((.14+.32*sin(PI*t))*lerpf(1,.08,pow(t,5)))
    var rings: Array=[];var normals: Array=[]
    for i in range(21):
        var direction: Vector3=(path[mini(i+1,20)]-path[maxi(i-1,0)]).normalized()
        var up:=direction.cross(Vector3.RIGHT).normalized()
        var ring: Array[Vector3]=[];var normal: Array[Vector3]=[]
        for j in range(10):
            var a:=j*TAU/10
            var outward:=Vector3.RIGHT*cos(a)*.85+up*sin(a)
            ring.append(path[i]+outward*radii[i]);normal.append(outward.normalized())
        rings.append(ring);normals.append(normal)
    var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(20):
        for j in range(10):
            var next: int=(j+1)%10
            for index: Vector2i in [Vector2i(i,j),Vector2i(i,next),Vector2i(i+1,j),Vector2i(i,next),Vector2i(i+1,next),Vector2i(i+1,j)]:
                st.set_normal(normals[index.x][index.y]);st.add_vertex(rings[index.x][index.y])
    st.index()
    var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=materials.tail
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(mesh);mesh_count+=1

func sync(host,player,pursuit) -> void:
    if root==null: return
    if pursuit==null or pursuit.phase==&"idle":
        scenery_depth.sync(host.get_parent().car_3d_overlay,host,false,materials)
        root.visible=false;return
    var fraction := Engine.get_physics_interpolation_fraction() if host.get_parent().is_physics_processing() else 1.0
    var position_: Vector3=pursuit.previous_helicopter_position.lerp(Vector3(pursuit.helicopter_x,pursuit.helicopter_height,pursuit.helicopter_z),fraction)
    var rear_x: float=player.world_x+sin(float(player.heading_yaw))*.45
    var rear_z: float=cos(float(player.heading_yaw))*.45
    root.position=Vector3(rear_x-position_.x,host._road_relative_height(position_.z)+position_.y,position_.z-player.world_z-rear_z)
    var previous: Vector3=pursuit.previous_attitude
    var orientation:=Quaternion.from_euler(Vector3(previous.x,-previous.y,-previous.z))
    var next:=Quaternion.from_euler(Vector3(pursuit.helicopter_pitch,-pursuit.helicopter_yaw,-pursuit.helicopter_bank))
    root.quaternion=orientation.slerp(next,fraction)
    previous=pursuit.previous_rotor_attitude
    var disc_previous:=Quaternion.from_euler(Vector3(previous.x,-previous.y,-previous.z))
    var disc_next:=Quaternion.from_euler(Vector3(pursuit.rotor_pitch,-pursuit.helicopter_yaw,-pursuit.rotor_bank))
    rotor_mount.quaternion=root.quaternion.inverse()*disc_previous.slerp(disc_next,fraction)
    for blade in blade_roots: blade.rotation.z=.025+clampf(pursuit.flight.collective-1.0,-.2,.6)*.035
    var camera: Camera3D=host.get_parent().car_3d_overlay.camera
    pursuit.has_flight_observer=true
    pursuit.flight_outside_view=outside_camera(camera)
    # This is roof occlusion, not the flight lifecycle. Open-road missions
    # start outside the tunnel and clear the portal before the car gets there.
    root.visible=Data.sector_at(player.world_z)!=4
    scenery_depth.sync(host.get_parent().car_3d_overlay,host,root.visible and not pursuit.flight_outside_view,materials)
    var clock: float=lerpf(pursuit.previous_clock,pursuit.clock,fraction)
    rotor.rotation.y=clock*43.0
    tail_rotor.rotation.x=clock*64.0
    beacon.visible=fmod(pursuit.clock,.8)<.18

func outside_camera(camera: Camera3D) -> bool:
    var local := camera.to_local(root.global_position)
    var depth := -local.z
    var radius := 8.0 # Contains the complete rotor disk and curled tail.
    if depth+radius<camera.near or depth-radius>camera.far: return true
    var tangent := tan(deg_to_rad(camera.fov)*.5)
    var size: Vector2i=camera.get_viewport().size
    var horizontal := tangent*float(size.x)/maxi(1,size.y)
    return absf(local.x)>depth*horizontal+radius*(1+horizontal) or absf(local.y)>depth*tangent+radius*(1+tangent)
