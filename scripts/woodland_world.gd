extends Node3D
## An authored, compact woodland: one continuous loop, three distinct clearings,
## and a broad arena. This world does not use the former estate cell generator.

const TreeProfiles=preload("res://scripts/level1_park_trees.gd")
const MEADOW=preload("res://assets/level1/textures/park_meadow.jpg")
const LITTER=preload("res://assets/level1/park_ground.png")
const BARK=preload("res://assets/level1/textures/park_oak_bark.jpg")
const LEAVES=preload("res://assets/level1/textures/park_oak_canopy.jpg")
const ROCK=preload("res://assets/level1/textures/park_limestone.jpg")
const STATIONS=[Vector3(-22,0,-7),Vector3(22,0,0),Vector3(0,0,-18)]
const POND_CENTER=Vector3(-27,0,-18)
var blockers: Array[AABB]=[]
var materials: Dictionary={}
var meshes: Dictionary={}
var batches: Dictionary={}
var trees=TreeProfiles.new()
var rng=RandomNumberGenerator.new()
var built=false
var path_layer=0
var previous_3d_scale=-1.0
var mobile_rendering=false
var contact_blobs: Array[Vector4]=[]
var environment: Environment
var scenery_root: Node3D

func build() -> void:
    if built:return
    built=true
    rng.seed=24102026
    scenery_root=self
    _resources()
    _lighting()
    _floor()
    _paths()
    _boundaries()
    _forest()
    _oak()
    _hut()
    _pond()
    _furniture()
    _undergrowth()
    _bake_contacts()
    _flush()
    add_to_group("woodland_world")
    if not get_viewport().size_changed.is_connected(_mobile_profile):
        get_viewport().size_changed.connect(_mobile_profile)
    _mobile_profile()

func _resources() -> void:
    var box=BoxMesh.new();box.size=Vector3.ONE;meshes.box=box
    var cylinder=CylinderMesh.new();cylinder.height=1;cylinder.top_radius=.5;cylinder.bottom_radius=.5;cylinder.radial_segments=10;meshes.cylinder=cylinder
    var sphere=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=12;sphere.rings=6;meshes.sphere=sphere
    var cone=CylinderMesh.new();cone.top_radius=.03;cone.bottom_radius=.5;cone.height=1;cone.radial_segments=10;meshes.cone=cone
    var leaf=SphereMesh.new();leaf.radius=.5;leaf.height=1;leaf.radial_segments=8;leaf.rings=3;meshes.leaf=leaf
    materials.wood=_mat(Color("6b4a31"))
    materials.wood_light=_mat(Color("9a7951"))
    materials.iron=_mat(Color("3b4140"))
    materials.brass=_mat(Color("a18a53"))
    materials.roof=_mat(Color("58685c"))
    materials.cream=_mat(Color("dbc9a7"))
    materials.fern=_mat(Color("46613c"))
    materials.fern_light=_mat(Color("6b7846"))
    materials.fern.cull_mode=BaseMaterial3D.CULL_DISABLED;materials.fern_light.cull_mode=BaseMaterial3D.CULL_DISABLED
    materials.lamp=_mat(Color("ffd99a"));materials.lamp.emission_enabled=true;materials.lamp.emission=Color("ffc276");materials.lamp.emission_energy_multiplier=.8
    materials.stone=_mat(Color("7a7b69"));materials.stone.albedo_texture=ROCK;materials.stone.uv1_scale=Vector3(1.5,1.5,1)
    materials.gravel=_ground(true)
    materials.clearing=_ground(true);materials.clearing.set_shader_parameter("clearing_surface",true)
    materials.ground=_ground(false)
    var water=ShaderMaterial.new();water.shader=preload("res://shaders/woodland/water.gdshader");materials.water=water
    trees.make_resources(self)
    meshes.oak_crown=_canopy_mesh(16,7)
    meshes.oak_crown_far=_canopy_mesh(10,4)
    meshes.canopy_shadow=_canopy_mesh(8,3)
    materials.shadow_canopy=_mat(Color("47513e"))
    var bark=ShaderMaterial.new();bark.shader=preload("res://shaders/woodland/bark.gdshader");bark.set_shader_parameter("bark",BARK);materials.tree_bark=bark
    for id in ["tree_leaf","tree_leaf_light","tree_gold"]:
        var foliage=ShaderMaterial.new();foliage.shader=preload("res://shaders/woodland/foliage.gdshader")
        foliage.set_shader_parameter("leaves",LEAVES)
        foliage.set_shader_parameter("tint",Color("829768") if id=="tree_leaf_light" else Color("657b51"))
        foliage.set_shader_parameter("golden",id=="tree_gold")
        materials[id]=foliage

func _mat(color: Color) -> StandardMaterial3D:
    var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.91;m.metallic_specular=.12
    return m

func _ground(path_surface: bool) -> ShaderMaterial:
    var m=ShaderMaterial.new();m.shader=preload("res://shaders/woodland/ground.gdshader")
    m.set_shader_parameter("meadow",MEADOW);m.set_shader_parameter("leaf_litter",LITTER);m.set_shader_parameter("path_surface",path_surface)
    return m

func _lighting() -> void:
    var sky_material=ProceduralSkyMaterial.new()
    sky_material.sky_top_color=Color("304f74");sky_material.sky_horizon_color=Color("e6c19b")
    sky_material.ground_bottom_color=Color("3a4b49");sky_material.ground_horizon_color=Color("9aa496")
    sky_material.sky_curve=.22;sky_material.sun_angle_max=5
    var sky=Sky.new();sky.sky_material=sky_material
    environment=Environment.new();environment.background_mode=Environment.BG_SKY;environment.sky=sky
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color=Color("a5b7d0");environment.ambient_light_energy=.38
    environment.tonemap_mode=Environment.TONE_MAPPER_ACES
    environment.tonemap_exposure=.95;environment.tonemap_white=4.0
    environment.fog_enabled=true;environment.fog_light_color=Color("a8b6ad");environment.fog_density=.0018;environment.fog_sky_affect=.10
    environment.fog_height=0;environment.fog_height_density=.0
    environment.glow_enabled=false
    var world=WorldEnvironment.new();world.name="WoodlandAtmosphere";world.environment=environment;add_child(world)
    var sun=DirectionalLight3D.new();sun.name="LateAfternoonSun";sun.rotation_degrees=Vector3(-23,-42,0)
    sun.light_color=Color("ffdbab");sun.light_energy=1.65
    sun.shadow_enabled=true
    sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
    sun.directional_shadow_max_distance=28.0
    sun.shadow_bias=.08;sun.shadow_normal_bias=1.0;sun.shadow_opacity=.70
    add_child(sun)

func _floor() -> void:
    var ground=MeshInstance3D.new();ground.name="ForestFloor";var mesh=PlaneMesh.new();mesh.size=Vector2(76,64);mesh.subdivide_width=18;mesh.subdivide_depth=16
    ground.mesh=mesh;ground.material_override=materials.ground;ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ground)
    _collider(Vector3(0,-.2,0),Vector3(76,.4,64),false,"ContinuousForestFloor")

func _paths() -> void:
    var loop: Array[Vector3]=[Vector3(0,0,26),Vector3(-8,0,17),Vector3(-17,0,9),Vector3(-22,0,-7),Vector3(-16,0,-16),Vector3(0,0,-18),Vector3(16,0,-12),Vector3(22,0,0),Vector3(17,0,13),Vector3(8,0,20),Vector3(0,0,26)]
    _ribbon(loop,2.45)
    _ribbon([Vector3(-22,0,-7),Vector3(-10,0,-2),Vector3(0,0,4),Vector3(12,0,3),Vector3(22,0,0)],1.8)
    _ribbon([Vector3(0,0,23),Vector3(0,0,12),Vector3(0,0,1),Vector3(0,0,-2)],2.0)
    # The whole arena uses shallow compacted earth, avoiding noisy ground
    # contrast beneath the tank's charge telegraph.
    _clearing()

func _ribbon(route: Array[Vector3],half_width: float) -> void:
    var centers: Array[Vector3]=[]
    path_layer+=1
    var path_y=.014+float(path_layer)*.004
    for i in range(route.size()-1):
        var count=maxi(4,ceili(route[i].distance_to(route[i+1])/1.5))
        for j in range(count):
            centers.append(route[i].cubic_interpolate(route[i+1],route[maxi(0,i-1)],route[mini(route.size()-1,i+2)],float(j)/count))
    centers.append(route[-1])
    var left: Array[Vector3]=[];var right: Array[Vector3]=[]
    for i in range(centers.size()):
        var tangent=(centers[mini(centers.size()-1,i+1)]-centers[maxi(0,i-1)]).normalized()
        var side=tangent.cross(Vector3.UP)
        var width=half_width*(1.0+sin(float(i)*.21)*.06)
        left.append(centers[i]+Vector3.UP*path_y-side*width)
        right.append(centers[i]+Vector3.UP*path_y+side*width)
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(centers.size()-1):
        var corners=[left[i],left[i+1],right[i],right[i+1]]
        for k in [0,1,2,1,3,2]:
            st.set_normal(Vector3.UP);st.set_uv(Vector2(0.0 if k<2 else 1.0,float(i)));st.add_vertex(corners[k])
    var node=MeshInstance3D.new();node.name="WindingWoodlandTrail";node.mesh=st.commit();node.material_override=materials.gravel;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)

func _boundaries() -> void:
    _collider(Vector3(-37,2,0),Vector3(2,4,64),true,"WestForestBoundary")
    _collider(Vector3(37,2,0),Vector3(2,4,64),true,"EastForestBoundary")
    _collider(Vector3(0,2,-31),Vector3(72,4,2),true,"NorthForestBoundary")
    _collider(Vector3(0,2,31),Vector3(72,4,2),true,"SouthForestBoundary")
    # Boulder outcrops supply physical, legible natural enclosure. The far
    # forest conceals the collision boundary without a tall repeating wall.
    for side in [-1,1]:
        for z in range(-27,30,7):
            var p=Vector3(side*(34.5+rng.randf_range(-.6,.6)),.65,z)
            _batch("sphere","stone",p,Vector3(rng.randf_range(2.6,4.0),rng.randf_range(1.5,2.4),rng.randf_range(2.5,4.0)),Basis(Vector3.UP,rng.randf()*TAU))
    for z in [-29.0,29.0]:
        for x in range(-31,34,8):
            _batch("sphere","stone",Vector3(x,.5,z),Vector3(3.4,1.4,2.6),Basis(Vector3.UP,rng.randf()*TAU))
    # Actual floor-plan blockers all have a readable visible footprint.
    for p in [Vector3(-12,0,9),Vector3(12,0,13),Vector3(-12,0,-24),Vector3(27,0,-23)]:
        _batch("sphere","stone",p+Vector3.UP*.7,Vector3(2.8,1.8,2.2),Basis(Vector3.UP,.4))
        _collider(p+Vector3.UP*.65,Vector3(2.1,1.3,1.7),true,"TrailBoulder")

func _forest() -> void:
    for side in [-1,1]:
        for z in range(-27,30,5):
            var p=Vector3(side*rng.randf_range(31.5,35.0),0,z+rng.randf_range(-1.4,1.4))
            trees.plant(self,p,rng.randf_range(8.0,12.5),false,false)
            contact_blobs.append(Vector4(p.x,p.z,2.1,.30))
    for z in [-28.0,29.0]:
        for x in range(-29,32,5):
            var p=Vector3(x+rng.randf_range(-1.2,1.2),0,z+rng.randf_range(-.5,.5))
            if p.distance_to(Vector3(0,0,25))<8:continue
            trees.plant(self,p,rng.randf_range(8.0,12.0),false,false)
            contact_blobs.append(Vector4(p.x,p.z,2.0,.30))
    var groups=[Vector3(-9,0,13),Vector3(9,0,13),Vector3(-24,0,13),Vector3(-27,0,4),Vector3(-13,0,19),Vector3(24,0,16),Vector3(29,0,9),Vector3(13,0,22),Vector3(-26,0,-24),Vector3(25,0,-15)]
    for p in groups:
        trees.plant(self,p,rng.randf_range(7.5,10.0),false,false)
        contact_blobs.append(Vector4(p.x,p.z,2.0,.33))
        _collider(p+Vector3.UP*2,Vector3(.9,4,.9),true,"OakTrunk")
    # A second ring is visual only behind the collision boundary.
    for i in range(22):
        var angle=float(i)*TAU/22
        var p=Vector3(cos(angle)*45,0,sin(angle)*38)
        trees.plant(self,p,rng.randf_range(11,16),false,true)

func _oak() -> void:
    var p=Vector3(0,0,-27.5)
    trees.plant(self,p,18.0,true,false)
    contact_blobs.append(Vector4(p.x,p.z,4.2,.50))
    _collider(p+Vector3.UP*3,Vector3(2.7,6,2.7),true,"AncientOakTrunk")
    for i in range(trees.legendary_hangers.size()):
        var anchor: Vector3=trees.legendary_hangers[i]
        var bottom=anchor-Vector3.UP*(1.7+float(i%2)*.5)
        _beam(anchor,bottom,.035,"wood")
        _lantern(bottom)
    # Root-buttresses sit behind the objective and outside the combat floor.
    for i in range(5):
        var angle=float(i)*TAU/5
        var q=p+Vector3(cos(angle)*1.7,.35,sin(angle)*1.7)
        _batch("sphere","tree_bark",q,Vector3(2.9,.6,.65),Basis(Vector3.UP,-angle))

func _hut() -> void:
    var p=Vector3(28,0,-1)
    _batch("box","stone",p+Vector3.UP*.16,Vector3(7,.32,6.2))
    for x in [-3.0,3.0]:
        _batch("box","wood",p+Vector3(x,1.7,0),Vector3(.18,3.4,5.4))
    _batch("box","wood",p+Vector3(0,1.7,-2.6),Vector3(6.1,3.4,.18))
    # Front faces west toward its station, with an open timber porch.
    for z in [-2.4,2.4]:
        _batch("cylinder","tree_bark",p+Vector3(-4.0,1.65,z),Vector3(.22,3.3,.22))
    for z in [-1,1]:
        _batch("box","roof",p+Vector3(-.6,3.55,z*1.50),Vector3(8.8,.18,3.5),Basis(Vector3.RIGHT,z*-.30))
    _batch("box","wood_light",p+Vector3(-3.6,.08,0),Vector3(2,.16,5.4))
    _batch("box","cream",p+Vector3(-3.11,2.25,-1.7),Vector3(.025,.8,1.0))
    for z in [-2.6,2.6]:
        for y in [.45,.95,1.45,1.95,2.45,2.95]:
            _batch("box","wood_light",p+Vector3(0,y,z),Vector3(6.15,.07,.22))
    _collider(p+Vector3(.3,1.7,0),Vector3(5.4,3.4,5.2),true,"RangerHut")
    _lantern(p+Vector3(-4,2.6,1.8))
    _sign(Vector3(23,1.85,3.8),"ЛЕСНОЙ ДОЗОР\nТихо. Белки отдыхают.",-PI*.5)

func _pond() -> void:
    # Closed water basin is outside all station routes; its shore is a real
    # collider so no player or tank can walk on a painted water surface.
    _batch("cylinder","water",POND_CENTER+Vector3.UP*.025,Vector3(12,.035,10))
    _collider(POND_CENTER+Vector3.UP*.25,Vector3(12,.5,10),true,"PondWaterBoundary")
    for i in range(22):
        var angle=float(i)*TAU/22
        var p=POND_CENTER+Vector3(cos(angle)*6.2,.19,sin(angle)*5.2)
        _batch("sphere","stone",p,Vector3(1.2,.5,.9),Basis(Vector3.UP,angle))
        if i%2==0:
            for k in range(3):
                var q=p+Vector3(rng.randf_range(-.25,.25),.6,rng.randf_range(-.25,.25))
                _batch("cylinder","fern",q,Vector3(.035,1.2,.035))
    # Short lookout jetty stops before the shore collision.
    _batch("box","wood_light",Vector3(-22,.06,-10.8),Vector3(3,.12,3))
    for side in [-1,1]:
        _batch("box","wood",Vector3(-22+side*1.6,.6,-10.8),Vector3(.1,1.2,3))
    _sign(Vector3(-25,1.7,-6),"ОЗЁРНАЯ ТРОПА\nНе кормите караул.",.3)

func _furniture() -> void:
    for p in [Vector3(-7,0,17),Vector3(-16,0,0),Vector3(14,0,11),Vector3(9,0,-9),Vector3(-10,0,-14)]:
        _lamp_post(p)
    _bench(Vector3(-24,0,-3),.3)
    _bench(Vector3(23,0,8),-1.1)
    for p in [Vector3(-5,0,24),Vector3(5,0,24)]:
        _batch("cylinder","tree_bark",p+Vector3.UP*1.1,Vector3(.2,2.2,.2))
    _batch("box","wood",Vector3(0,2.3,24),Vector3(10.4,.22,.22))
    _sign(Vector3(0,2.5,24),"ЛЕС ЖЁЛУДЕЙ",0)

func _bench(p: Vector3,yaw: float) -> void:
    var turn=Basis(Vector3.UP,yaw)
    for z in [-.28,0,.28]:
        _batch("box","wood_light",p+turn*Vector3(0,.55,z),Vector3(2.4,.12,.20),turn)
    for x in [-.85,.85]:
        _batch("box","iron",p+turn*Vector3(x,.26,0),Vector3(.12,.52,.7),turn)
    for y in [.90,1.17]:
        _batch("box","wood",p+turn*Vector3(0,y,.45),Vector3(2.4,.20,.10),turn)

func _lamp_post(p: Vector3) -> void:
    _batch("cylinder","wood",p+Vector3.UP*1.35,Vector3(.13,2.7,.13))
    _lantern(p+Vector3.UP*2.7)

func _lantern(p: Vector3) -> void:
    _batch("box","lamp",p,Vector3(.24,.35,.24))
    for y in [-.23,.23]:_batch("box","iron",p+Vector3.UP*y,Vector3(.39,.08,.39))
    for x in [-1,1]:
        for z in [-1,1]:_batch("box","iron",p+Vector3(x*.15,0,z*.15),Vector3(.035,.40,.035))

func _sign(p: Vector3,text_: String,yaw: float) -> void:
    _batch("box","wood",p,Vector3(3.6,.9,.14),Basis(Vector3.UP,yaw))
    var label=Label3D.new();label.name="TrailSign";label.text=text_;label.font_size=48;label.pixel_size=.009
    label.position=p+Basis(Vector3.UP,yaw)*Vector3(0,0,.09);label.rotation.y=yaw
    label.modulate=Color("e6d8b5");label.outline_size=0;label.no_depth_test=false
    add_child(label)

func _undergrowth() -> void:
    # Fern clusters stay at planted edges; readable paths and combat floor
    # have no hidden collision or high-frequency scattered grass.
    var fern=_fern_mesh();meshes.fern=fern
    for i in range(480):
        var p=Vector3(rng.randf_range(-34,34),0,rng.randf_range(-28,28))
        if _on_route(p) or p.distance_to(Vector3(0,0,-12))<12:continue
        if p.distance_to(POND_CENTER)<6.6:continue
        if absf(p.x-28)<4 and absf(p.z+1)<4:continue
        _batch("fern","fern_light" if i%3==0 else "fern",p,Vector3.ONE*rng.randf_range(.35,.85),Basis(Vector3.UP,rng.randf()*TAU))
        if i%4==0:
            _batch("sphere","stone",p+Vector3.UP*.08,Vector3(.4,.22,.3),Basis(Vector3.UP,rng.randf()*TAU))

func _on_route(p: Vector3) -> bool:
    if absf(p.x)<3.4:return true
    var loop=[Vector3(0,0,26),Vector3(-8,0,17),Vector3(-17,0,9),Vector3(-22,0,-7),Vector3(-16,0,-16),Vector3(0,0,-18),Vector3(16,0,-12),Vector3(22,0,0),Vector3(17,0,13),Vector3(8,0,20),Vector3(0,0,26)]
    for i in range(loop.size()-1):
        var q=Geometry3D.get_closest_point_to_segment(p,loop[i],loop[i+1])
        if q.distance_to(p)<3.4:return true
    if p.distance_to(Vector3(-22,0,-7))<5 or p.distance_to(Vector3(22,0,0))<5:return true
    return false

func _fern_mesh() -> ArrayMesh:
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(7):
        var angle=float(i)*TAU/7
        var direction=Vector3(cos(angle),0,sin(angle));var side=direction.cross(Vector3.UP)
        var start=Vector3(0,.06,0);var tip=direction*.75+Vector3.UP*(.25+float(i%2)*.13)
        for k in range(4):
            var t=float(k+1)/5;var center=start.lerp(tip,t)+Vector3.UP*sin(t*PI)*.26
            var width=(1.0-t)*.20
            for sign_ in [-1,1]:
                var points=[center-direction*.12,center+side*width*sign_-direction*.14,center+direction*.13]
                for index in [0,2,1]:st.set_normal(Vector3.UP);st.add_vertex(points[index])
    st.index();var mesh=st.commit();var material=materials.fern.duplicate();material.cull_mode=BaseMaterial3D.CULL_DISABLED
    mesh.surface_set_material(0,material)
    return mesh

func _batch(shape: String,material: String,p: Vector3,size_: Vector3,basis_:=Basis.IDENTITY) -> void:
    var key="%s|%s|%d|%d"%[shape,material,floori(p.x/16),floori(p.z/16)]
    if not batches.has(key):batches[key]=[]
    batches[key].append(Transform3D(basis_*Basis.from_scale(size_),p))
    if shape=="oak_crown":
        var proxy_key="canopy_shadow|shadow_canopy|%d|%d"%[floori(p.x/16),floori(p.z/16)]
        if not batches.has(proxy_key):batches[proxy_key]=[]
        batches[proxy_key].append(Transform3D(basis_*Basis.from_scale(size_),p))

func _flush() -> void:
    for key: String in batches:
        var parts=key.split("|");var transforms: Array=batches[key]
        var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=meshes[parts[0]];multi.instance_count=transforms.size()
        for i in range(transforms.size()):multi.set_instance_transform(i,transforms[i])
        var node=MultiMeshInstance3D.new();node.name="Woodland_%s_%s"%[parts[0],parts[1]];node.multimesh=multi;node.material_override=materials[parts[1]]
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if parts[0]=="canopy_shadow":node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
        elif parts[0]=="oak_body_3" or (parts[0]=="box" and parts[1] in ["wood","roof"]):node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        node.visibility_range_end=82;node.visibility_range_end_margin=8
        add_child(node)
    batches.clear()

func _beam(a: Vector3,b: Vector3,width: float,material: String) -> void:
    var d=b-a
    _batch("cylinder",material,(a+b)*.5,Vector3(width,d.length(),width),Basis(Quaternion(Vector3.UP,d.normalized())))

func _collider(center: Vector3,size_: Vector3,record: bool,name_: String) -> void:
    var body=StaticBody3D.new();body.name=name_;body.collision_layer=1;body.collision_mask=0
    var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size_;shape.shape=box;body.add_child(shape);body.position=center;add_child(body)
    if record:
        blockers.append(AABB(center-size_*.5,size_))
        if size_.x<15 and size_.z<15:contact_blobs.append(Vector4(center.x,center.z,maxf(size_.x,size_.z)*.7,.30))

func _mobile_profile() -> void:
    if not OS.has_feature("mobile") and not get_meta("force_mobile_profile",false):return
    var viewport=get_viewport();var size_=Vector2(viewport.get_visible_rect().size)
    if previous_3d_scale<0:previous_3d_scale=viewport.scaling_3d_scale
    var desired=minf(1.0,sqrt(1280.0*720.0/maxf(size_.x*size_.y,1.0)))
    viewport.scaling_3d_scale=minf(previous_3d_scale,desired);mobile_rendering=true

func _exit_tree() -> void:
    if is_instance_valid(get_viewport()):
        if get_viewport().size_changed.is_connected(_mobile_profile):get_viewport().size_changed.disconnect(_mobile_profile)
        if previous_3d_scale>=0:get_viewport().scaling_3d_scale=previous_3d_scale

func _bake_contacts() -> void:
    # Static soft contact shade is baked once on the CPU. This grounds props
    # and trees without shadow-map passes, lights or full-screen effects.
    const SIDE=192
    var image=Image.create(SIDE,SIDE,false,Image.FORMAT_L8)
    image.fill(Color.WHITE)
    for blob: Vector4 in contact_blobs:
        var center=Vector2((blob.x+38.0)/76.0,(blob.y+32.0)/64.0)*SIDE
        var radius=Vector2(blob.z/76.0,blob.z/64.0)*SIDE
        for y in range(maxi(0,floori(center.y-radius.y)),mini(SIDE,ceili(center.y+radius.y)+1)):
            for x in range(maxi(0,floori(center.x-radius.x)),mini(SIDE,ceili(center.x+radius.x)+1)):
                var delta=(Vector2(x,y)-center)/radius
                var weight=maxf(0.0,1.0-delta.length_squared())
                var prior=image.get_pixel(x,y).r
                image.set_pixel(x,y,Color(maxf(.30,prior-weight*weight*blob.w),0,0,1))
    var texture=ImageTexture.create_from_image(image)
    materials.ground.set_shader_parameter("contact_shade",texture)
    materials.gravel.set_shader_parameter("contact_shade",texture)
    materials.clearing.set_shader_parameter("contact_shade",texture)

func _clearing() -> void:
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var center=Vector3(0,.021,-12)
    for i in range(40):
        var a=float(i)*TAU/40;var b=float(i+1)*TAU/40
        var ra=10.5+sin(a*3.0)*.8+cos(a*5.0)*.4
        var rb=10.5+sin(b*3.0)*.8+cos(b*5.0)*.4
        var points=[Vector3.ZERO,Vector3(cos(a)*ra,0,sin(a)*ra),Vector3(cos(b)*rb,0,sin(b)*rb)]
        for j in range(3):
            st.set_normal(Vector3.UP)
            st.set_uv(Vector2(.5,.5)+Vector2(points[j].x,points[j].z)/23.4)
            st.add_vertex(center+points[j])
    var node=MeshInstance3D.new();node.name="OakClearingEarth";node.mesh=st.commit();node.material_override=materials.clearing
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)

func _canopy_mesh(radial: int,bands: int) -> ArrayMesh:
    var sphere=SphereMesh.new();sphere.radius=.5;sphere.height=1.0;sphere.radial_segments=radial;sphere.rings=bands
    var arrays=sphere.get_mesh_arrays()
    var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    for i in range(vertices.size()):
        var v=vertices[i]
        var lobe=1.0+.085*sin(v.x*11.0+v.y*4.0)*cos(v.z*9.0)+.035*sin(v.z*17.0-v.y*8.0)
        vertices[i]=v*lobe
    arrays[Mesh.ARRAY_VERTEX]=vertices
    var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    return mesh
