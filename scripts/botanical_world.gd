extends Node3D
## One continuous terraced garden. All paths and destinations share one space.
const ATLAS=preload("res://assets/level1/botanical/foliage_atlas.png")
var rng=RandomNumberGenerator.new()
var mats: Dictionary={}
var meshes: Dictionary={}
var batches: Dictionary={}
var blockers: Array[AABB]=[]
var built:=false
var original_scale:=-1.0
var original_msaa:=-1
var original_occlusion:=false
var original_max_fps:=-1
var rendering_optimizer: RefCounted
var baked_lighting: RefCounted
var greenhouse_gate: Node3D
var irrigation_water: Node3D
var environment: Environment
var path_source_index:=0
var placement_records: Array[Dictionary]=[]
var rim_relocations: Array=[]
## Deterministic source lobes let the renderer replace distant leaf cards with
## compact crown volumes without guessing tree membership from giant batches.
var canopy_groups: Array[Dictionary]=[]
var material_profile: RefCounted
var performance_herb_meshes: Dictionary={}
var performance_herb_material: ShaderMaterial
var _reference_147_enabled:=false

static func surface_height_at(x: float,z: float) -> float:
    # Match the actual two-meter terrain triangles, including terrace edges.
    var x0=floorf(x*.5)*2;var z0=floorf(z*.5)*2
    var u=(x-x0)*.5;var v=(z-z0)*.5
    if u+v<=1:return height_at(x0,z0)+u*(height_at(x0+2,z0)-height_at(x0,z0))+v*(height_at(x0,z0+2)-height_at(x0,z0))
    return height_at(x0+2,z0+2)+(1-u)*(height_at(x0,z0+2)-height_at(x0+2,z0+2))+(1-v)*(height_at(x0+2,z0)-height_at(x0+2,z0+2))
const LANDMARKS={"entrance":Vector2(0,60),"pond":Vector2(-24,22),"pump":Vector2(34,19),"glasshouse":Vector2(0,-34),"herbarium":Vector2(-34,-38),"orchard":Vector2(-44,-81),"pavilion":Vector2(47,-79),"heart":Vector2(0,-38)}

static func height_at(x: float,z: float) -> float:
    var y=0.0
    if z<=25:y=3.0
    elif z<45:y=(45-z)*.15
    if z<=-14:y=7.0
    elif z<12 and (absf(x)<11 or absf(x)>50):y=3+(12-z)/26.0*4
    if z<=-72:y=12.0
    elif z< -52 and (absf(x)>39 or absf(x)<8):y=7+(-52-z)*.25
    var outer=smoothstep(72,138,absf(x))
    y+=outer*(6+sin(x*.065)*3+cos(z*.071)*2)
    if z< -102:y+=(-102-z)*.11+sin(x*.08)*2
    return y

func build() -> void:
    if built:return
    built=true;rng.seed=25102026
    original_msaa=get_viewport().msaa_3d;get_viewport().msaa_3d=Viewport.MSAA_2X
    original_occlusion=get_viewport().use_occlusion_culling
    _materials()
    if not get_meta("reference_rendering",false):
        preload("res://scripts/botanical_rendering.gd").optimize_materials(self)
        for key in ["box","cylinder","rock","branch"]:meshes[key]=load("res://assets/level1/botanical/meshes/"+key+".res")
    meshes.furniture_box=meshes.box
    _lighting();_terrain();_terraces();_paths();_conservatory();_entry_pergola();_side_pergola();_pond();_upper_pavilion();_planting();_rock_garden();_forest();_furnishings();_flush()
    if not get_meta("reference_rendering",false):
        var optimizer=preload("res://scripts/botanical_rendering.gd")
        optimizer.add_occluders(self);rendering_optimizer=optimizer.new();rendering_optimizer.setup(self)
        get_viewport().use_occlusion_culling=true
    if not get_meta("skip_baked_lighting",false) and not get_meta("reference_rendering",false):
        baked_lighting=preload("res://scripts/botanical_lighting.gd").new();baked_lighting.setup(self)
    preload("res://scripts/botanical_evening.gd").apply(self)
    if not get_meta("reference_rendering",false):
        material_profile=preload("res://scripts/botanical_material_profile.gd").new()
        material_profile.setup(self)
        set_reference_147_enabled(bool(get_meta("reference_147",false)))
    get_viewport().size_changed.connect(_mobile_profile);_mobile_profile()
    add_to_group("botanical_world")

func _process(_delta: float) -> void:
    if rendering_optimizer!=null:rendering_optimizer.update(get_viewport().get_camera_3d())

func set_distance_culling_enabled(enabled: bool) -> void:
    if rendering_optimizer!=null:rendering_optimizer.set_enabled(enabled)

func is_reference_147_enabled() -> bool:return _reference_147_enabled

func set_reference_147_enabled(value: bool) -> void:
    _reference_147_enabled=value
    set_meta("reference_147",value)
    if material_profile!=null:material_profile.set_enabled(not value)
    if rendering_optimizer!=null and rendering_optimizer.has_method("set_reference_147_enabled"):
        rendering_optimizer.set_reference_147_enabled(value)

func _plain(color: String,roughness:=.85) -> StandardMaterial3D:
    var m=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=roughness;return m
func _materials() -> void:
    mats.stone=_plain("eee6ce");mats.stone.albedo_texture=preload("res://assets/level1/botanical/stone_color.jpg")
    mats.stone.normal_enabled=true;mats.stone.normal_texture=preload("res://assets/level1/botanical/stone_normal.jpg");mats.stone.normal_scale=.75
    mats.stone.roughness_texture=preload("res://assets/level1/botanical/stone_rough.jpg");mats.stone.uv1_triplanar=true;mats.stone.uv1_world_triplanar=true;mats.stone.uv1_scale=Vector3.ONE*.28
    mats.trim=_plain("ebe3c9");mats.trim.albedo_texture=preload("res://assets/level1/botanical/limestone_color.jpg");mats.trim.uv1_triplanar=true;mats.trim.uv1_world_triplanar=true;mats.trim.uv1_scale=Vector3.ONE*.5
    mats.trim.normal_enabled=true;mats.trim.normal_texture=preload("res://assets/level1/botanical/limestone_normal.jpg");mats.trim.normal_scale=.45
    mats.paving=mats.stone.duplicate();mats.paving.albedo_color=Color("c8b99b");mats.paving.uv1_scale=Vector3.ONE*.45
    mats.wood=_plain("9e8d69");mats.wood.albedo_texture=preload("res://assets/level1/textures/park_oak_bark.jpg");mats.wood.uv1_triplanar=true;mats.wood.uv1_world_triplanar=true;mats.wood.uv1_scale=Vector3.ONE*.5
    mats.bark=mats.wood.duplicate();mats.bark.albedo_color=Color("a79d82")
    mats.iron=_plain("34473b",.53);mats.iron.metallic=.55
    mats.terra=_plain("ad7f59")
    mats.moss=_plain("747e42")
    mats.cliff=_plain("d8d4bb");mats.cliff.albedo_texture=preload("res://assets/level1/botanical/rock_color.jpg");mats.cliff.normal_enabled=true;mats.cliff.normal_texture=preload("res://assets/level1/botanical/rock_normal.jpg");mats.cliff.normal_scale=.8;mats.cliff.uv1_triplanar=true;mats.cliff.uv1_world_triplanar=true;mats.cliff.uv1_scale=Vector3.ONE*.28
    mats.glass=_plain("a9c9ba",.13);mats.glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mats.glass.albedo_color.a=.32;mats.glass.cull_mode=BaseMaterial3D.CULL_DISABLED
    mats.water=ShaderMaterial.new();mats.water.shader=preload("res://shaders/woodland/garden_evening_water.gdshader")
    mats.water.set_shader_parameter("panorama",preload("res://assets/level1/botanical/garden_sky.hdr"))
    mats.plants=ShaderMaterial.new();mats.plants.shader=preload("res://shaders/woodland/garden_herbs.gdshader")
    mats.plants.set_shader_parameter("atlas",preload("res://assets/level1/botanical/foliage_color_gl.png") if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ATLAS)
    var herbs=preload("res://scripts/botanical_herbs.gd").new()
    for kind in [3,4,5]:meshes["herb%d"%kind]=herbs.build(kind)
    meshes.lilyflower=herbs.build(6)
    performance_herb_material=preload("res://scripts/botanical_material_profile.gd").make_material(mats.plants,preload("res://shaders/woodland/garden_herbs_fast.gdshader"))
    for kind in [3,4,5]:performance_herb_meshes[kind]=herbs.build(kind,2,true)
    performance_herb_meshes[6]=herbs.build(6,2)
    var shader=Shader.new();shader.code="shader_type spatial; render_mode cull_disabled; uniform sampler2D atlas:source_color,filter_linear_mipmap_anisotropic; void fragment(){vec4 c=texture(atlas,UV); ALBEDO=c.rgb*COLOR.rgb*vec3(.62,.76,.62); ALPHA=c.a; ALPHA_SCISSOR_THRESHOLD=0.38; ROUGHNESS=.92; BACKLIGHT=vec3(.17,.20,.08); NORMAL=normalize(FRONT_FACING?NORMAL:-NORMAL);}"
    mats.leaves=ShaderMaterial.new();mats.leaves.shader=shader;mats.leaves.set_shader_parameter("atlas",ATLAS)
    var ground=preload("res://shaders/woodland/garden_ground.gdshader")
    mats.ground=ShaderMaterial.new();mats.ground.shader=ground;mats.ground.set_shader_parameter("grass",preload("res://assets/level1/textures/park_meadow.jpg"));mats.ground.set_shader_parameter("soil",preload("res://assets/level1/botanical/soil_color.jpg"))
    var box=BoxMesh.new();box.size=Vector3.ONE;meshes.box=box
    var cylinder=CylinderMesh.new();cylinder.radial_segments=10;cylinder.rings=0;cylinder.height=1;cylinder.top_radius=.5;cylinder.bottom_radius=.5;meshes.cylinder=cylinder
    var sphere=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=12;sphere.rings=6;meshes.rock=sphere
    var pad=SurfaceTool.new();pad.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(18):
        var a=.17+i*(TAU-.34)/18;var b=.17+(i+1)*(TAU-.34)/18
        for point in [Vector3.ZERO,Vector3(cos(b)*.5,0,sin(b)*.5),Vector3(cos(a)*.5,0,sin(a)*.5)]:
            pad.set_normal(Vector3.UP);pad.set_color(Color(.58,.76,.56));pad.set_uv(Vector2(.493,.86)+Vector2(point.x,point.z)*.025);pad.add_vertex(point)
    meshes.lily_pad=pad.commit()
    for i in range(6):meshes["leaf%d"%i]=_leaf_mesh(i)

func _lighting() -> void:
    # Create only the authored evening sky. Replacing an already-registered
    # panorama leaves pending GL radiance textures on Compatibility teardown.
    environment=Environment.new();environment.background_mode=Environment.BG_SKY
    environment.tonemap_mode=Environment.TONE_MAPPER_ACES;environment.tonemap_exposure=1.0
    environment.ssao_enabled=true;environment.ssao_radius=1.2;environment.ssao_intensity=1.6
    preload("res://scripts/botanical_compatibility.gd").configure_environment(environment)
    var we=WorldEnvironment.new();we.environment=environment;add_child(we)
    var moon=DirectionalLight3D.new();moon.name="GardenSun";moon.shadow_enabled=true
    moon.directional_shadow_max_distance=55;moon.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;moon.shadow_bias=.05;moon.shadow_normal_bias=.7;moon.light_angular_distance=.6;add_child(moon)
    preload("res://scripts/botanical_evening.gd").configure_lighting(self)

func _terrain() -> void:
    var number=0
    for tx in range(-2,3):
        for tz in range(-2,3):
            var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
            for ix in range(32):
                for iz in range(32):
                    var x=tx*64+ix*2-32;var z=tz*64+iz*2-32
                    var pts=[Vector3(x,height_at(x,z),z),Vector3(x+2,height_at(x+2,z),z),Vector3(x,height_at(x,z+2),z+2),Vector3(x+2,height_at(x+2,z+2),z+2)]
                    for k in [0,1,2,1,3,2]:
                        st.set_color(Color(.93,.95,.86));st.set_uv(Vector2(pts[k].x,pts[k].z)*.1);st.add_vertex(pts[k])
            st.generate_normals();st.index();var mesh=st.commit()
            var mi=MeshInstance3D.new();mi.mesh=mesh if get_meta("reference_rendering",false) or not ResourceLoader.exists("res://assets/level1/botanical/meshes/terrain_%d.res"%number) else load("res://assets/level1/botanical/meshes/terrain_%d.res"%number);mi.lod_bias=4;mi.set_meta("lightmap_source_id","terrain:%d"%number);number+=1;mi.material_override=mats.ground;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(mi)
            if abs(tx)<=1 and abs(tz)<=1:
                var body=StaticBody3D.new();body.collision_layer=1;body.set_meta("audio_surface",&"grass");var shape=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();body.add_child(shape);add_child(body)
    for x in [-90,90]:solid(Vector3(x,12,0),Vector3(2,40,200),"GardenBoundary")
    for z in [-99,79]:solid(Vector3(0,12,z),Vector3(180,40,2),"GardenBoundary")

func _terraces() -> void:
    # Three levels remain connected by the central stairs and broad side ramps.
    for pair in [[-50,-11],[11,50]]:
        _wall(Vector3(pair[0],3,-14),Vector3(pair[1],3,-14),4)
    # The two inner fragments used to cross the water and read as floating seats.
    for pair in [[-50,-31],[31,50]]:_wall(Vector3(pair[0],0,25),Vector3(pair[1],0,25),3)
    for pair in [[-80,-58],[-36,-8],[8,36],[58,80]]:_wall(Vector3(pair[0],7,-72),Vector3(pair[1],7,-72),5)
    for side in [-1,1]:_stairs(Vector3(side*24,0,45),Vector3(side*24,3,25),12,24)
    _stairs(Vector3(0,3,12),Vector3(0,7,-14),20,32)
    _stairs(Vector3(0,7,-52),Vector3(0,12,-72),13,30)
    for side in [-1,1]:
        for z in [-14,25,-72]:
            var y=7.0 if z==-14 else (3.0 if z==25 else 12.0)
            for x in range(14,49,4):
                if z==25 and x<31:continue
                if z==-72 and x>36:continue
                _baluster(Vector3(side*x,y,z))
    # Side retaining walls, stepped beds and broad outlooks frame the paths.
    for x in [-57,57]:
        _wall(Vector3(x,0,46),Vector3(x,0,25),2.8)
        _wall(Vector3(x,3,12),Vector3(x,3,-14),3.8)
    for x in [-33,33]:
        _box("trim",Vector3(x,7.25,-12),Vector3(12,.5,5))
        for j in range(9):_shrub(Vector3(x+rng.randf_range(-5,5),7.55,-12+rng.randf_range(-1.5,1.5)),1.2,4)

func _wall(a: Vector3,b: Vector3,height: float) -> void:
    var middle=(a+b)*.5+Vector3.UP*height*.5
    var length=a.distance_to(b);var basis=Basis.looking_at((b-a).normalized())
    _put("box","stone",middle,Vector3(.9,height,length),basis)
    _put("box","trim",middle+Vector3.UP*(height*.5+.12),Vector3(1.15,.24,length+.15),basis)
    solid(middle,Vector3(.9,height,length),"RetainingWall",basis)
    var n=maxi(1,ceili(length/4))
    for i in range(n):
        var p=a.lerp(b,(i+.4)/n)+Vector3.UP*(height*.6)
        _foliage(1,p+Vector3(0,0,.56),Vector2(2.0,height*.9),Basis.IDENTITY)

func _stairs(a: Vector3,b: Vector3,width: float,count: int) -> void:
    _audio_path([Vector2(a.x,a.z),Vector2(b.x,b.z)],width*.5)
    for i in range(count):
        var p=a.lerp(b,float(i+1)/count);var rise=(b.y-a.y)/count
        _box("trim",p-Vector3.UP*.07,Vector3(width,.16,absf(a.z-b.z)/count+.04))
        if i%4==0:
            for side in [-1,1]:_foliage(1,p+Vector3(side*(width*.5-.15),.12,0),Vector2(.7,.5),Basis(Vector3.RIGHT,-PI*.5))

func _baluster(p: Vector3) -> void:
    _box("trim",p+Vector3.UP*.1,Vector3(.5,.2,.5));_put("cylinder","trim",p+Vector3.UP*.6,Vector3(.25,1,.25));_box("trim",p+Vector3.UP*1.1,Vector3(.5,.2,.5))
    _box("trim",p+Vector3(0,1.23,0),Vector3(4,.13,.45))

func _paths() -> void:
    for route in [
        [Vector2(0,70),Vector2(0,52),Vector2(0,40),Vector2(0,35)],
        [Vector2(0,35),Vector2(-24,35),Vector2(-37,20),Vector2(-45,4),Vector2(-56,-6),Vector2(-56,-35),Vector2(-53,-60),Vector2(-43,-82)],
        [Vector2(0,35),Vector2(24,35),Vector2(39,20),Vector2(47,4),Vector2(56,-6),Vector2(56,-35),Vector2(53,-60),Vector2(43,-82)],
        [Vector2(-48,-20),Vector2(-22,-18),Vector2(0,-18),Vector2(22,-18),Vector2(48,-20)],
        [Vector2(-44,-82),Vector2(-20,-87),Vector2(0,-86),Vector2(22,-87),Vector2(47,-79)],
        [Vector2(-24,22),Vector2(-25,7),Vector2(0,9),Vector2(26,8),Vector2(34,19)],
    ]:_path(route,2.5)

func _path(route: Array,width: float) -> void:
    # _path's width is the actual half-span of its two ribbon edges.
    _audio_path(route,width)
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(route.size()-1):
        var a: Vector2=route[i];var b: Vector2=route[i+1];var length=a.distance_to(b);var n=maxi(2,ceili(length/1.5));var side=(b-a).normalized().orthogonal()*width
        for k in range(n):
            var p=a.lerp(b,float(k)/n);var q=a.lerp(b,float(k+1)/n)
            var pts=[p-side,q-side,p+side,q+side]
            for j in [0,2,1,1,2,3]:
                st.set_normal(Vector3.UP);st.set_uv(pts[j]*.15);st.add_vertex(Vector3(pts[j].x,height_at(pts[j].x,pts[j].y)+.035,pts[j].y))
    st.generate_normals();var node=MeshInstance3D.new();node.mesh=st.commit();node.material_override=mats.paving;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.set_meta("lightmap_source_id","path:%d"%path_source_index);path_source_index+=1;add_child(node)

func _audio_path(points: Array,half_width: float) -> void:
    var paths: Array=get_meta("audio_paths",[])
    paths.append({"points":points.duplicate(),"half_width":half_width,"surface":&"stone"})
    set_meta("audio_paths",paths)

func _audio_disc(center: Vector3,radius: float) -> void:
    var zones: Array=get_meta("audio_surface_zones",[])
    zones.append({"center":Vector2(center.x,center.z),"radius":radius,"surface":&"stone"})
    set_meta("audio_surface_zones",zones)

func _conservatory() -> void:
    var center=Vector3(0,7,-35);var radius=12.0
    _audio_disc(center,12.5)
    _put("cylinder","trim",center+Vector3.UP*.13,Vector3(25,.26,25))
    for i in range(16):
        var angle=i*TAU/16;var p=center+Vector3(cos(angle)*radius,0,sin(angle)*radius)
        _column(p,6.2)
        var next=center+Vector3(cos(angle+TAU/16)*radius,0,sin(angle+TAU/16)*radius)
        if i not in [3,4]:
            _arch(p+Vector3.UP*3.4,next+Vector3.UP*3.4,2.3,.18,"iron")
            _arch(p+Vector3.UP*3.4,next+Vector3.UP*3.4,2.3,.32,"trim")
            var mid=(p+next)*.5;var tangent=p.direction_to(next)
            _put("box","stone",mid+Vector3.UP*.55,Vector3(.55,1.1,p.distance_to(next)),Basis.looking_at(tangent))
            _put("box","glass",mid+Vector3.UP*3.1,Vector3(.045,3.7,p.distance_to(next)-.25),Basis.looking_at(tangent))
            solid(mid+Vector3.UP*.55,Vector3(.45,1.1,p.distance_to(next)),"GreenhouseSill",Basis.looking_at(tangent))
            _beam(p+Vector3.UP*.9,next+Vector3.UP*.9,.11,"iron")
            _beam(p+Vector3.UP*3.4,next+Vector3.UP*3.4,.08,"iron")
        if i%2==0:_ivy_column(p,6)
    _dome(center+Vector3.UP*6.2,12.2,7.3,24)
    for side in [-1,1]:
        for i in range(5):
            var x=side*(14+i*4.2);var p=Vector3(x,7,-34)
            for z in [-29.0,-39.0]:
                _column(Vector3(x,7,z),4.4,.65)
                _arch(Vector3(x-2,9,z),Vector3(x+2,9,z),2.1,.14,"iron")
                _box("stone",Vector3(x,7.4,z),Vector3(4,.8,.3))
                _box("glass",Vector3(x,9.1,z),Vector3(3.8,3.6,.04))
                solid(Vector3(x,7.4,z),Vector3(4,.8,.35),"GlasshouseWingSill")
            _arch(Vector3(x,11.4,-39),Vector3(x,11.4,-29),3.7,.1,"iron")
            if i<4:
                for z in [-39.0,-34.0,-29.0]:_beam(Vector3(x,11.5,z),Vector3(x+side*4.2,11.5,z),.08,"iron")
            _pot(p+Vector3(0,0,1),1.0);_shrub(p+Vector3(0,1,1),2.0,3)
            if i%2==0:_foliage(2,Vector3(x,11.5,-28.7),Vector2(3.4,3.2),Basis.IDENTITY)
    _barrel_roof(-34,-12);_barrel_roof(12,34)
    # Entrance wings and tall arched double doors, connected directly to plaza.
    for side in [-1,1]:
        _column(Vector3(side*3,7,-22.5),5.8,.8)
        for offset in range(6):_beam(Vector3(side*(.25+offset*.5),7.4,-22.3),Vector3(side*(.25+offset*.5),11.6,-22.3),.045,"iron")
        _beam(Vector3(0,9,-22.3),Vector3(side*3,9,-22.3),.07,"iron")
    _arch(Vector3(-3,11.2,-22.4),Vector3(3,11.2,-22.4),2.4,.19,"iron")
    for x in [-8,8]:_pot(Vector3(x,7,-19),1.1);_shrub(Vector3(x,8,-19),2.1,4)
    # Reachable botanical exhibits, rather than a backdrop shell.
    for p in [Vector3(-6,7,-33),Vector3(6,7,-33),Vector3(-5,7,-40),Vector3(5,7,-40)]:
        _pot(p,1);_shrub(p+Vector3.UP,2.2,3)
    _box("stone",Vector3(0,7.3,-36),Vector3(3,.6,3));_put("rock","trim",Vector3(0,8,-36),Vector3(2,1.4,2))

func _column(p: Vector3,height: float,radius:=1.0) -> void:
    _box("trim",p+Vector3.UP*.16,Vector3(radius,.32,radius))
    _put("cylinder","trim",p+Vector3.UP*(height*.5),Vector3(radius*.56,height-.35,radius*.56))
    for pair in [[.35,.8],[height-.35,.72],[height-.12,1.0]]:_put("cylinder","trim",p+Vector3.UP*pair[0],Vector3(radius*pair[1],.16,radius*pair[1]))
    _box("trim",p+Vector3.UP*height,Vector3(radius,.22,radius))
    solid(p+Vector3.UP*(height*.5),Vector3(radius*.55,height,radius*.55),"StoneColumn")

func _dome(center: Vector3,radius: float,height: float,ribs: int) -> void:
    for i in range(ribs):
        var angle=i*TAU/ribs
        var last=center+Vector3(cos(angle)*radius,0,sin(angle)*radius)
        for j in range(1,13):
            var phi=j*PI*.5/12;var p=center+Vector3(cos(angle)*radius*cos(phi),sin(phi)*height,sin(angle)*radius*cos(phi))
            _beam(last,p,.075,"iron");last=p
    for j in range(5):
        var phi=j*PI*.5/6;var r=radius*cos(phi);var y=sin(phi)*height
        for i in range(64):_beam(center+Vector3(cos(i*TAU/64)*r,y,sin(i*TAU/64)*r),center+Vector3(cos((i+1)*TAU/64)*r,y,sin((i+1)*TAU/64)*r),.06,"iron")
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(ribs):
        for j in range(10):
            if (i+j)%13==0:continue
            var pts=[]
            for uv in [Vector2(i,j),Vector2(i+1,j),Vector2(i,j+1),Vector2(i+1,j+1)]:
                var angle=uv.x*TAU/ribs;var phi=uv.y*PI*.5/10
                pts.append(center+Vector3(cos(angle)*radius*cos(phi),sin(phi)*height,sin(angle)*radius*cos(phi)))
            for k in [0,2,1,1,2,3]:st.add_vertex(pts[k])
    st.generate_normals();var node=MeshInstance3D.new();node.mesh=st.commit();node.material_override=mats.glass;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
    _put("rock","iron",center+Vector3.UP*(height+.2),Vector3(.5,.8,.5))

func _arch(a: Vector3,b: Vector3,height: float,thickness: float,material: String) -> void:
    var span=b-a;var middle=(a+b)*.5;var horizontal=span.normalized();var radius=span.length()*.5
    var last=a
    for i in range(1,21):
        var angle=PI-float(i)*PI/20
        var p=middle+horizontal*(cos(angle)*radius)+Vector3.UP*(sin(angle)*height)
        _beam(last,p,thickness,material);last=p

func _entry_pergola() -> void:
    for z in [60,54,48,42]:
        for side in [-1,1]:
            var p=Vector3(side*5,height_at(side*5,z),z);_column(p,3.5,.85);_ivy_column(p,3.4)
            _foliage(2,p+Vector3(0,3.7,0),Vector2(1.9,1.9),Basis(Vector3.UP,side*.3))
        _beam(Vector3(-5,height_at(-5,z)+3.6,z),Vector3(5,height_at(5,z)+3.6,z),.2,"wood")
        for x in range(-4,5,2):
            _foliage(1,Vector3(x,height_at(x,z)+3.65,z),Vector2(3,3),Basis(Vector3.RIGHT,PI*.5))
            if x%4==0:_foliage(2,Vector3(x,height_at(x,z)+3.4,z+.2),Vector2(1.8,1.8),Basis.IDENTITY)
    for x in [-5.0,5.0]:
        for i in range(3):_beam(Vector3(x,height_at(x,60-i*6)+3.6,60-i*6),Vector3(x,height_at(x,54-i*6)+3.6,54-i*6),.25,"wood")
    for x in [-8,8]:
        _column(Vector3(x,0,63),3.1,1.25)
        _put("rock","trim",Vector3(x,3.5,63),Vector3(.9,.9,.9))
        for i in range(7):_beam(Vector3(x+signf(x)*i*.38,.1,63),Vector3(x+signf(x)*i*.38,2.4+sin(i*.5)*.3,63),.04,"iron")
    for side in [-1,1]:
        _wall(Vector3(side*6,0,59),Vector3(side*16,0,59),.65)
        for i in range(6):_shrub(Vector3(side*(7+i*1.5),.7,58.5),1.4,4)

func _side_pergola() -> void:
    for z in [23,16,5]:
        for x in [-31,-22]:
            var p=Vector3(x,height_at(x,z),z);_column(p,3.9,.85);_ivy_column(p,3.8)
            _foliage(2,p+Vector3.UP*3.7,Vector2(1.8,2.0),Basis.IDENTITY)
        _beam(Vector3(-31,6.95,z),Vector3(-22,6.95,z),.2,"wood")
        for x in [-29,-26,-23]:_foliage(1,Vector3(x,7,z),Vector2(2.5,2),Basis(Vector3.RIGHT,PI*.5))
    for x in [-31,-22]:_beam(Vector3(x,6.95,23),Vector3(x,6.95,5),.2,"wood")
    # Combat-looking squirrels are real actors owned by the encounter director.
    # The former two visual-only mannequins had neither AI nor a hitbox.
    _box("stone",Vector3(-23,3.5,13),Vector3(2,1,1.4))

func _pond() -> void:
    var center=Vector3(0,3.06,23)
    _put("cylinder","stone",Vector3(0,2.35,23),Vector3(38,1.4,20))
    _put("cylinder","water",center,Vector3(37,.025,19))
    # Visible shore and solid water volume prevent walking across the pool.
    for i in range(56):
        var a=i*TAU/56;var b=(i+1)*TAU/56
        var p=center+Vector3(cos(a)*19,-.07,sin(a)*10)
        var next=center+Vector3(cos(b)*19,-.07,sin(b)*10)
        var tangent=(next-p).normalized();var basis=Basis(Vector3.UP,atan2(-tangent.z,tangent.x))
        var size_=Vector3(p.distance_to(next)+.04,.42,.8);var middle=(p+next)*.5
        _box("trim",middle,size_,basis)
        rim_relocations.append([Transform3D(Basis(Vector3.UP,-a)*Basis.from_scale(Vector3(2.3,.42,.8)),p),Transform3D(basis*Basis.from_scale(size_),middle)])
        if i%4==0:
            var shore=preload("res://scripts/botanical_layout.gd").plant_point(Vector2(cos(a)*20.1,23+sin(a)*11.1))
            var root=Vector3(shore.x,surface_height_at(shore.x,shore.y),shore.y)
            _pot(root,.7);_shrub(root+Vector3.UP*.7,1.2,3)
    var body=StaticBody3D.new();body.name="PondWaterVolume";body.collision_layer=1
    var cs=CollisionShape3D.new();var cylinder=CylinderShape3D.new();cylinder.radius=1;cylinder.height=.6;cs.shape=cylinder;body.position=center+Vector3.UP*.2;body.scale=Vector3(17.5,1,8.5);body.add_child(cs);add_child(body)
    for i in range(50):
        var x=rng.randf_range(-16,16);var z=rng.randf_range(-7,7)
        if x*x/256+z*z/49>1:continue
        _put("lily_pad","plants",center+Vector3(x,.04,z),Vector3(.7,1,.55),Basis(Vector3.UP,float(i)*2.399963))
        if i%6==0:_put("lilyflower","plants",center+Vector3(x,.055,z),Vector3.ONE*.35)
    for side in [-1,1]:
        for i in range(15):
            var x=side*rng.randf_range(19,22);var z=23+rng.randf_range(-8,8);var angle=rng.randf()*TAU
            _ground_plant(5,preload("res://scripts/botanical_layout.gd").plant_point(Vector2(x,z)),1.4,angle)
    # A creek follows the eastern ramp and feeds the reflecting pool.
    _path([Vector2(31,22),Vector2(40,10),Vector2(45,-4),Vector2(44,-17),Vector2(43,-50),Vector2(48,-70)],1.3)

func _upper_pavilion() -> void:
    var center=Vector3(47,12,-79)
    _audio_disc(center,9.0)
    _put("cylinder","stone",center,Vector3(18,.6,18))
    for i in range(10):
        var angle=i*TAU/10;var p=center+Vector3(cos(angle)*7,0,sin(angle)*7);_column(p,5.3,.9)
        if i%2==0:_ivy_column(p,5.3)
    _dome(center+Vector3.UP*5.3,7.4,4.3,16)
    for i in range(10):
        var angle=i*TAU/10;_shrub(center+Vector3(cos(angle)*8,.3,sin(angle)*8),1.6,2)

func _barrel_roof(x1: float,x2: float) -> void:
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in range(16):
        var a=j*PI/16;var b=(j+1)*PI/16
        var pts=[Vector3(x1,11.4+sin(a)*3.7,-34+cos(a)*5),Vector3(x2,11.4+sin(a)*3.7,-34+cos(a)*5),Vector3(x1,11.4+sin(b)*3.7,-34+cos(b)*5),Vector3(x2,11.4+sin(b)*3.7,-34+cos(b)*5)]
        for k in [0,1,2,1,3,2]:st.add_vertex(pts[k])
    st.generate_normals();var n=MeshInstance3D.new();n.mesh=st.commit();n.material_override=mats.glass;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n)

func _cypress(p: Vector3,height: float) -> void:
    _tapered_branch(p,p+Vector3.UP*height,.3,.05)
    for j in range(9):
        var y=height*(.18+j*.09);var radius=(1-float(j)/10)*1.65
        var cards: Array[Transform3D]=[]
        for i in range(9):
            var a=i*TAU/9
            var position_=p+Vector3(cos(a)*radius,y,sin(a)*radius)
            var basis_=Basis(Vector3.UP,a)
            _foliage(0,position_,Vector2(2.7,2.8),basis_)
            cards.append(Transform3D(basis_*Basis.from_scale(Vector3(2.7,2.8,1)),position_))
        _record_canopy_group("cypress",p,height,cards)

func _rock_garden() -> void:
    var sphere=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=16;sphere.rings=8
    var arrays=sphere.get_mesh_arrays();var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    for i in range(vertices.size()):
        var p=vertices[i];vertices[i]*=1+.18*sin(p.x*14+p.y*5)*cos(p.z*13)+.05*cos(p.y*23)
    arrays[Mesh.ARRAY_VERTEX]=vertices;var rock=ArrayMesh.new();rock.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);meshes.cliff=rock
    for side in [-1,1]:
        for i in range(6):
            var p=Vector3(side*(20+i*5.3),3.3,-8+rng.randf_range(-2,2))
            _put("cliff","cliff",p,Vector3(rng.randf_range(7,11),rng.randf_range(3,5),rng.randf_range(6,9)),Basis(Vector3.UP,rng.randf()*TAU))
            for j in range(8):_foliage(1,p+Vector3(rng.randf_range(-3,3),1.8,rng.randf_range(-2,2)),Vector2(1.4,1.5),Basis(Vector3.UP,rng.randf()*TAU))
        for center in [Vector2(side*25,50),Vector2(side*38,1),Vector2(side*47,-56)]:
            var y=height_at(center.x,center.y)
            for i in range(55):
                var angle=rng.randf()*TAU;var r=sqrt(rng.randf())
                var x=center.x+cos(angle)*r*6;var z=center.y+sin(angle)*r*3
                var size_=rng.randf_range(.65,1.2);var angle_=rng.randf()*TAU
                _ground_plant(4 if i%4 else 3,preload("res://scripts/botanical_layout.gd").plant_point(Vector2(x,z)),size_,angle_)

func _forest() -> void:
    for side in [-1,1]:
        for z in range(-98,73,8):
            var x=side*rng.randf_range(73,88);_tree(Vector3(x,height_at(x,z),z),rng.randf_range(12,19))
    for x in range(-72,73,8):
        _tree(Vector3(x,height_at(x,-98),-98),rng.randf_range(12,18))
    for p in [Vector2(-18,-49),Vector2(18,-49),Vector2(-36,-60),Vector2(36,-60),Vector2(-53,-74),Vector2(26,-79)]:_cypress(Vector3(p.x,height_at(p.x,p.y),p.y),rng.randf_range(13,18))
    for i in range(160):
        var x=rng.randf_range(-145,145);var z=rng.randf_range(-140,90)
        if absf(x)<70 and z> -105 and z<72:continue
        _tree(Vector3(x,height_at(x,z),z),rng.randf_range(9,19))
    for p in [Vector2(-22,50),Vector2(26,52),Vector2(-40,40),Vector2(43,38),Vector2(-66,24),Vector2(66,22),Vector2(-65,-21),Vector2(65,-20),Vector2(-53,-51),Vector2(58,-48),Vector2(-16,-84),Vector2(24,-94),Vector2(-68,-81)]:
        _tree(Vector3(p.x,height_at(p.x,p.y),p.y),rng.randf_range(10,16))
    for x in [-58,-44,-28]:
        for z in [-83,-95]:_tree(Vector3(x,12,z),rng.randf_range(5,7))

func _tree(p: Vector3,height: float) -> void:
    var bend=Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1))
    var root=p;var top=p+Vector3.UP*height*.62+bend
    _tapered_branch(root,top,height*.034,height*.012)
    for i in range(7):
        var angle=i*TAU/7+rng.randf_range(-.25,.25);var branch_start=p+Vector3.UP*height*rng.randf_range(.28,.54)+bend*.5
        var tip=p+Vector3(cos(angle)*height*.29,height*rng.randf_range(.62,.91),sin(angle)*height*.29)+bend
        _tapered_branch(branch_start,tip,height*.017,height*.003)
        var cards: Array[Transform3D]=[]
        for j in range(11):
            var q=tip+Vector3(rng.randf_range(-1.6,1.6),rng.randf_range(-.3,1.6),rng.randf_range(-1.6,1.6))*height*.13
            var scale_=height*rng.randf_range(.19,.28)
            var basis_=Basis.from_euler(Vector3(rng.randf_range(-.8,.8),rng.randf()*TAU,rng.randf_range(-.7,.7)))
            _foliage(0,q,Vector2(scale_,scale_),basis_)
            cards.append(Transform3D(basis_*Basis.from_scale(Vector3(scale_,scale_,1)),q))
        _record_canopy_group("tree",p,height,cards)
    for i in range(5):
        var angle=i*TAU/5
        _tapered_branch(p+Vector3(cos(angle)*height*.10,.05,sin(angle)*height*.10),p+Vector3.UP*.8,height*.026,height*.015)
    if absf(p.x)<88 and p.z> -98:solid(p+Vector3.UP*2,Vector3(height*.065,4,height*.065),"TreeTrunk")

func _record_canopy_group(kind: String,root_: Vector3,height: float,cards: Array[Transform3D]) -> void:
    var quad=AABB(Vector3(-.5,-.5,0),Vector3(1,1,0))
    var bounds=cards[0]*quad
    for i in range(1,cards.size()):bounds=bounds.merge(cards[i]*quad)
    canopy_groups.append({"kind":kind,"root":root_,"height":height,"center":bounds.get_center(),"bounds":bounds,"card_transforms":cards})

func _tapered_branch(a: Vector3,b: Vector3,bottom: float,top: float) -> void:
    if not meshes.has("branch"):
        var mesh=CylinderMesh.new();mesh.height=1;mesh.bottom_radius=.5;mesh.top_radius=.12;mesh.radial_segments=8;mesh.rings=0;meshes.branch=mesh
    _put("branch","bark",(a+b)*.5,Vector3(bottom*2,a.distance_to(b),bottom*2),Basis(Quaternion(Vector3.UP,a.direction_to(b))))

func _planting() -> void:
    for side in [-1,1]:
        for z in [52,40,6,-5,-48,-82]:
            var x=side*(17 if z>30 else (29 if z> -14 else 23))
            var y=height_at(x,z)
            _box("stone",Vector3(x,y+.35,z),Vector3(10,.7,5))
            # A level bed on a ramp needs a foundation down to the low corner.
            var low=y
            for dx in [-5.0,5.0]:
                for dz in [-2.5,2.5]:low=minf(low,surface_height_at(x+dx,z+dz))
            if low<y-.02:_put("furniture_box","stone",Vector3(x,(low+y)*.5,z),Vector3(10,y-low,5))
            for i in range(16):_shrub(Vector3(x+rng.randf_range(-4.7,4.7),y+.72,z+rng.randf_range(-2.2,2.2)),rng.randf_range(.6,1.3),4 if i%3 else 3)
    for i in range(620):
        var x=rng.randf_range(-86,86);var z=rng.randf_range(-98,70)
        if absf(x)<12 or (absf(x)<36 and z< -19 and z> -46):continue
        if Vector2(x/22,(z-23)/12).length()<1:continue
        var type=3 if i%3==0 else (4 if i%5==0 else 5)
        var size_=rng.randf_range(.6,1.4);var angle_=rng.randf()*TAU
        _ground_plant(type,preload("res://scripts/botanical_layout.gd").plant_point(Vector2(x,z)),size_,angle_)
    for side in [-1,1]:
        for z in [-18,-42]:
            for x in range(14,36,3):_shrub(Vector3(side*x,7.3,z),rng.randf_range(1.2,2),1)
    for p in [Vector3(-22,3,15),Vector3(23,3,16),Vector3(-38,7,-22),Vector3(38,7,-22)]:_pot(p,1.2);_shrub(p+Vector3.UP*1.1,2,4)

func _shrub(p: Vector3,size_: float,type: int) -> void:
    if type in [3,4,5]:
        # Preserve the deterministic RNG stream for the existing trees/bake.
        var offset=Vector3.ZERO
        for i in range(4):offset+=Vector3(rng.randf_range(-.25,.25),0,rng.randf_range(-.25,.25))*size_
        var root=p+offset*.25
        _put("herb%d"%type,"plants",root,Vector3.ONE*size_,Basis(Vector3.UP,p.x*.53+p.z*.31))
        placement_records.append({"kind":"bed_plant","root":root,"support_y":p.y,"plant_type":type})
        return
    for i in range(4):_foliage(type,p+Vector3(rng.randf_range(-.25,.25),0,rng.randf_range(-.25,.25))*size_,Vector2(size_,size_),Basis(Vector3.UP,i*PI*.37))

func _ground_plant(type: int,p: Vector2,size_: float,angle_: float) -> void:
    var root=Vector3(p.x,surface_height_at(p.x,p.y),p.y)
    _put("herb%d"%type,"plants",root,Vector3.ONE*size_,Basis(Vector3.UP,angle_))
    placement_records.append({"kind":"ground_plant","root":root,"support_y":root.y,"plant_type":type})

func _ivy_column(p: Vector3,height: float) -> void:
    for i in range(5):
        var y=(i+.5)*height/5
        _foliage(1,p+Vector3(.1,y,.44),Vector2(1.2,height*.43),Basis(Vector3.UP,rng.randf_range(-.4,.4)))

func _pot(p: Vector3,size_: float) -> void:
    _put("cylinder","terra",p+Vector3.UP*size_*.45,Vector3(size_*.9,size_*.9,size_*.9))
    _put("cylinder","terra",p+Vector3.UP*size_*.87,Vector3(size_*1.12,size_*.13,size_*1.12))
    _put("cylinder","moss",p+Vector3.UP*size_*.95,Vector3(size_,.04,size_))

func _furnishings() -> void:
    for spec in preload("res://scripts/botanical_layout.gd").BENCHES:
        var point: Vector2=spec[0];var p=Vector3(point.x,surface_height_at(point.x,point.y),point.y);var basis=Basis(Vector3.UP,spec[1])
        _put("furniture_box","wood",p+basis*Vector3(0,.55,0),Vector3(3,.14,.9),basis)
        _put("furniture_box","wood",p+basis*Vector3(0,1.05,-.38),Vector3(3,.8,.1),basis)
        for side in [-1,1]:_put("furniture_box","iron",p+basis*Vector3(side*1.1,.27,0),Vector3(.12,.54,.7),basis)
        solid(p+basis*Vector3(0,.7,-.1),Vector3(3,1.4,1),"GardenBench",basis)
        placement_records.append({"kind":"bench","root":p,"support_y":p.y,"yaw":spec[1]})
    for p in [Vector2(-11,54),Vector2(11,54),Vector2(-23,8),Vector2(23,8),Vector2(-44,-19),Vector2(44,-19),Vector2(-43,-76),Vector2(37,-77)]:
        var pos=Vector3(p.x,height_at(p.x,p.y),p.y)
        _beam(pos,pos+Vector3.UP*2.8,.09,"iron");_box("iron",pos+Vector3.UP*2.8,Vector3(.45,.55,.45))
        _box("trim",pos+Vector3.UP*3.15,Vector3(.6,.12,.6))

func _leaf_mesh(cell: int) -> ArrayMesh:
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var col=cell%3;var row=floori(float(cell)/3)
    var points=[Vector3(-.5,-.5,0),Vector3(.5,-.5,0),Vector3(-.5,.5,0),Vector3(.5,.5,0)]
    var uv=[Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,0)]
    for k in [0,1,2,1,3,2]:
        st.set_color(Color.WHITE);st.set_normal(Vector3.FORWARD);st.set_uv((Vector2(col,row)+uv[k]*.98+Vector2(.01,.01))/Vector2(3,2));st.add_vertex(points[k])
    return st.commit()

func _foliage(cell: int,p: Vector3,size_: Vector2,basis: Basis) -> void:
    _put("leaf%d"%cell,"leaves",p,Vector3(size_.x,size_.y,1),basis)
func _box(material: String,p: Vector3,size_: Vector3,basis:=Basis.IDENTITY) -> void:_put("box",material,p,size_,basis)
func _beam(a: Vector3,b: Vector3,width: float,material: String) -> void:_put("cylinder",material,(a+b)*.5,Vector3(width,a.distance_to(b),width),Basis(Quaternion(Vector3.UP,a.direction_to(b))))
func _put(shape: String,material: String,p: Vector3,size_: Vector3,basis:=Basis.IDENTITY) -> void:
    var key="%s|%s|%d|%d"%[shape,material,floori(p.x/48),floori(p.z/48)]
    # New opaque herbs use identical batches/LOD distances in both benchmark
    # paths; only the legacy leaf cards belong to the old 48-meter baseline.
    if material=="plants" or (material=="leaves" and not get_meta("reference_rendering",false)):key="%s|%s|%d|%d"%[shape,material,floori(p.x/24),floori(p.z/24)]
    if shape=="box" and material in ["wood","iron","terra","trim"]:key="%s|%s|0|0"%[shape,material]
    if not batches.has(key):batches[key]=[]
    batches[key].append(Transform3D(basis*Basis.from_scale(size_),p))
func _flush() -> void:
    for key in batches:
        var parts=key.split("|");var transforms=batches[key];var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=meshes[parts[0]];multi.instance_count=transforms.size()
        for i in range(transforms.size()):multi.set_instance_transform(i,transforms[i])
        var node=MultiMeshInstance3D.new();node.name="Garden_"+parts[0]+"_"+parts[1];node.multimesh=multi;node.material_override=mats[parts[1]]
        node.set_meta("botanical_shape",parts[0]);node.set_meta("botanical_material",parts[1])
        node.set_meta("lightmap_source_id","batch:"+key)
        if parts[1]=="plants":
            node.set_meta("botanical_foliage",true);node.set_meta("botanical_cutout",false);node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
        if parts[0]=="furniture_box":node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
        if parts[1]=="leaves":
            node.set_meta("botanical_foliage",true)
            node.set_meta("botanical_cutout",true)
            node.set_meta("tree_canopy",parts[0]=="leaf0")
            if not get_meta("reference_rendering",false):node.set_meta("foliage_legacy_mesh",meshes["shadow_"+parts[0]])
        if parts[1]=="leaves" and not get_meta("reference_rendering",false):node.material_override=null
        node.lod_bias=1 if parts[1]=="plants" else 4
        if parts[1]=="leaves" and not get_meta("reference_rendering",false):
            var largest_scale=1.0
            for t in transforms:largest_scale=maxf(largest_scale,maxf(t.basis.x.length(),maxf(t.basis.y.length(),t.basis.z.length())))
            node.lod_bias=2*largest_scale
        node.visibility_range_end=180 if parts[0]=="leaf0" else (85 if parts[1] in ["leaves","plants"] else 150)
        node.visibility_range_end_margin=8
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if parts[1] in ["ground","water","plants"] or parts[0] in ["leaf3","leaf4","leaf5"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        add_child(node)
        if parts[1]=="leaves" and not get_meta("reference_rendering",false) and node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
            node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            if parts[0]=="leaf0":node.set_meta("foliage_casts_shadow",true)
            var shadow=MultiMeshInstance3D.new();shadow.name="FoliageShadow";shadow.multimesh=MultiMesh.new();shadow.multimesh.transform_format=MultiMesh.TRANSFORM_3D;shadow.multimesh.mesh=meshes["shadow_"+parts[0]];shadow.multimesh.instance_count=transforms.size();shadow.material_override=mats.leaves
            for i in range(transforms.size()):shadow.multimesh.set_instance_transform(i,transforms[i])
            shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;shadow.lod_bias=4
            shadow.visibility_range_end=node.visibility_range_end;shadow.visibility_range_end_margin=node.visibility_range_end_margin
            shadow.set_meta("foliage_shadow_proxy",true);shadow.set_meta("tree_canopy",parts[0]=="leaf0");add_child(shadow)
            node.set_meta("foliage_shadow_node",shadow)
    batches.clear()
func solid(p: Vector3,size_: Vector3,name_: String,basis:=Basis.IDENTITY) -> StaticBody3D:
    var body=StaticBody3D.new();body.name=name_;body.position=p;body.basis=basis;body.collision_layer=1
    body.set_meta("audio_surface",&"wood" if name_ in ["TreeTrunk","GardenBench"] else &"stone")
    var cs=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size_;cs.shape=shape;body.add_child(cs);add_child(body)
    blockers.append(AABB(p-size_*.5,size_));return body
func _mobile_profile() -> void:
    if not OS.has_feature("mobile") and not get_meta("force_mobile_profile",false):return
    if original_scale<0:original_scale=get_viewport().scaling_3d_scale
    if original_max_fps<0:
        original_max_fps=Engine.max_fps
        # Avoid unnecessary 90/120-Hz rendering and thermal load on high-refresh
        # phones. Preserve any lower user/host cap and restore it on scene exit.
        Engine.max_fps=60 if original_max_fps==0 else mini(60,original_max_fps)
    var size_=Vector2(get_viewport().size)
    get_viewport().scaling_3d_scale=minf(original_scale,sqrt(1280.0*720.0/maxf(1,size_.x*size_.y)))
func _exit_tree() -> void:
    if is_instance_valid(get_viewport()):
        if original_scale>=0:get_viewport().scaling_3d_scale=original_scale
        if original_msaa>=0:get_viewport().msaa_3d=original_msaa
        get_viewport().use_occlusion_culling=original_occlusion
    if original_max_fps>=0:Engine.max_fps=original_max_fps
