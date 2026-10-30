extends Node3D
## One continuous terraced garden. All paths and destinations share one space.
const ATLAS=preload("res://assets/level1/botanical/foliage_atlas.png")
const Layout=preload("res://scripts/botanical_layout.gd")
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
var collision_geometry: RefCounted
var collision_instances: Array[Dictionary]=[]
var paving_triangles152: Array[Dictionary]=[]
var paving_coverage152: Array[PackedVector2Array]=[]

static func surface_height_at(x: float,z: float) -> float:
    # Match the actual two-meter terrain triangles, including terrace edges.
    var x0=floorf(x*.5)*2;var z0=floorf(z*.5)*2
    var u=(x-x0)*.5;var v=(z-z0)*.5
    if u+v<=1:return height_at(x0,z0)+u*(height_at(x0+2,z0)-height_at(x0,z0))+v*(height_at(x0,z0+2)-height_at(x0,z0))
    return height_at(x0+2,z0+2)+(1-u)*(height_at(x0,z0+2)-height_at(x0+2,z0+2))+(1-v)*(height_at(x0+2,z0)-height_at(x0+2,z0+2))
const LANDMARKS={"entrance":Vector2(0,60),"pond":Vector2(-24,22),"pump":Vector2(34,19),"glasshouse":Vector2(0,-34),"herbarium":Vector2(-34,-38),"orchard":Vector2(-44,-81),"pavilion":Vector2(47,-79),"heart":Vector2(0,-38)}

static func height_at(x: float,z: float) -> float:
    return preload("res://scripts/botanical_world151.gd").terrain_height(x,z,authored_height_at(x,z))

static func authored_height_at(x: float,z: float) -> float:
    # Architectural ribbons keep their baked authored elevation. Lowering the
    # soil under stairs must not lower those walkable stone approach paths.
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
    _lighting();_terrain();_terraces();_paths();_conservatory();_entry_pergola();_side_pergola();_pond();_upper_pavilion();_planting();_rock_garden();_forest();_furnishings();_canal_bridge152();_reconcile_ground_plants152();_flush()
    if not get_meta("reference_rendering",false):
        var optimizer=preload("res://scripts/botanical_rendering.gd")
        optimizer.add_occluders(self);rendering_optimizer=optimizer.new();rendering_optimizer.setup(self)
        get_viewport().use_occlusion_culling=true
    if not get_meta("skip_baked_lighting",false) and not get_meta("reference_rendering",false):
        baked_lighting=preload("res://scripts/botanical_lighting.gd").new();baked_lighting.setup(self)
    preload("res://scripts/botanical_evening.gd").apply(self)
    _physical_approaches150()
    preload("res://scripts/botanical_world151.gd").build(self)
    if not get_meta("reference_rendering",false):
        material_profile=preload("res://scripts/botanical_material_profile.gd").new()
        material_profile.setup(self)
        set_reference_147_enabled(bool(get_meta("reference_147",false)))
    collision_geometry=preload("res://scripts/botanical_collision150.gd").new();collision_geometry.bake(self)
    get_viewport().size_changed.connect(_mobile_profile);_mobile_profile()
    set_meta("layout152",Layout.describe())
    add_to_group("botanical_world")

func _process(_delta: float) -> void:
    if rendering_optimizer!=null:rendering_optimizer.update(get_viewport().get_camera_3d())

func _physical_approaches150() -> void:
    # The original discs rise26/30cm above terrain. Real visible half-steps
    # preserve the20cm actor step ceiling without lifting actors through floors.
    for spec in [[Vector3(0,7.065,-22.3),Vector3(5,.13,2.0)],[Vector3(37.95,12.075,-79),Vector3(1.0,.15,3)]]:
        var node=MeshInstance3D.new();node.name="StoneApproachStep150";var box=BoxMesh.new();box.size=spec[1];node.mesh=box;node.position=spec[0];node.material_override=mats.trim;node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.set_meta("mission150_dynamic",true);add_child(node)

func physical_support_at(point: Vector3,up:=2.0,down:=8.0) -> Dictionary:
    var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*up,point-Vector3.UP*down,1)
    return get_world_3d().direct_space_state.intersect_ray(ray)

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
    mats.soil=_plain("65503c",.99);mats.soil.albedo_texture=preload("res://assets/level1/botanical/soil_color.jpg");mats.soil.uv1_triplanar=true;mats.soil.uv1_world_triplanar=true;mats.soil.uv1_scale=Vector3.ONE*.8
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
            var corrected: bool=preload("res://scripts/botanical_world151.gd").TERRAIN_TILES.has(number)
            var cache_path="res://assets/level1/botanical/meshes/terrain151_%d.res"%number if corrected else "res://assets/level1/botanical/meshes/terrain_%d.res"%number
            var mi=MeshInstance3D.new();mi.mesh=load(cache_path) if not get_meta("reference_rendering",false) and ResourceLoader.exists(cache_path) else mesh
            # Near architectural edges, drawing a simplified terrain LOD can
            # lift grass through the exact paving/treads. These nine physical
            # tiles use their full18k triangles; the outer sixteen retain LODs.
            if abs(tx)<=1 and abs(tz)<=1:mi.mesh=mesh;mi.set_meta("critical_walk_terrain152",true);mi.set_meta("authored_geometry152",true)
            mi.lod_bias=4;mi.set_meta("lightmap_source_id","terrain:%d"%number);mi.set_meta("authored_geometry151",corrected);number+=1;mi.material_override=mats.ground;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(mi)
            if abs(tx)<=1 and abs(tz)<=1:
                var body=StaticBody3D.new();body.collision_layer=1;body.set_meta("audio_surface",&"grass");var shape=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();body.add_child(shape);add_child(body)
    for x in [-90,90]:solid(Vector3(x,12,0),Vector3(2,40,200),"GardenBoundary")
    solid(Vector3(0,12,-99),Vector3(180,40,2),"GardenBoundary")
    for side in [-1,1]:solid(Vector3(side*48,12,79),Vector3(84,40,2),"GardenBoundary")

func _terraces() -> void:
    # Three levels remain connected by the central stairs and broad side ramps.
    for pair in [[-50,-11],[11,50]]:
        _wall(Vector3(pair[0],3,-14),Vector3(pair[1],3,-14),4)
    # The two inner fragments used to cross the water and read as floating seats.
    for pair in [[-50,-31],[31,50]]:_wall(Vector3(pair[0],0,25),Vector3(pair[1],0,25),3)
    for pair in [[-80,-58],[-36,-8],[8,36],[58,80]]:_wall(Vector3(pair[0],7,-72),Vector3(pair[1],7,-72),5)
    for flight in Layout.STAIR_FLIGHTS:_stairs(flight[0],flight[1],flight[2],flight[3])
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
        var soil_y:=_soil_bed(Vector3(x,7,-12),Vector2(12,5),.5,"rock_outlook")
        for j in range(9):_shrub(Vector3(x+rng.randf_range(-5,5),soil_y,-12+rng.randf_range(-1.5,1.5)),1.2,4,"soil_bed")

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
        # Treads remain clear stone. Wall vines are authored on walls, not
        # mistaken for plants rooted in the walking surface.

func _baluster(p: Vector3) -> void:
    _box("trim",p+Vector3.UP*.1,Vector3(.5,.2,.5));_put("cylinder","trim",p+Vector3.UP*.6,Vector3(.25,1,.25));_box("trim",p+Vector3.UP*1.1,Vector3(.5,.2,.5))
    _box("trim",p+Vector3(0,1.23,0),Vector3(4,.13,.45))

func _paths() -> void:
    for spec in Layout.all_paths():_path(spec.points,float(spec.half_width),String(spec.id))

func _path(route: Array,width: float,label: String="") -> void:
    _audio_path(route,width)
    var outlines:=Geometry2D.offset_polyline(PackedVector2Array(route),width,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
    var pieces: Array[PackedVector2Array]=[]
    pieces.append_array(outlines)
    # Cut whole polygons before sampling terrain. Every physical stair/landing
    # is the sole visible walking surface inside its footprint.
    for flight in Layout.STAIR_FLIGHTS:
        var footprint:=Layout.stair_footprint(flight)
        var edge:=PackedVector2Array([footprint.position,footprint.position+Vector2(footprint.size.x,0),footprint.end,footprint.position+Vector2(0,footprint.size.y)])
        var remaining: Array[PackedVector2Array]=[]
        for polygon in pieces:remaining.append_array(Geometry2D.clip_polygons(polygon,edge))
        pieces=remaining
    # The open channel is a trough, never pavement painted through water.
    # Its one crossing is supplied by a separate physically raised footbridge.
    for corridor in Geometry2D.offset_polyline(PackedVector2Array(Layout.CHANNEL_POINTS),Layout.CHANNEL_HALF_WIDTH+.04,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
        var remaining: Array[PackedVector2Array]=[]
        for polygon in pieces:remaining.append_array(Geometry2D.clip_polygons(polygon,corridor))
        pieces=remaining
    # The turning court is a separate raised solid, sharing this exact edge.
    var court: Rect2=Layout.VEHICLE_COURT
    var court_polygon:=PackedVector2Array([court.position,court.position+Vector2(court.size.x,0),court.end,court.position+Vector2(0,court.size.y)])
    var outside_court: Array[PackedVector2Array]=[]
    for polygon in pieces:outside_court.append_array(Geometry2D.clip_polygons(polygon,court_polygon))
    pieces=outside_court
    # Emit each junction once rather than stacking coplanar path ribbons.
    for previous in paving_coverage152:
        var remaining: Array[PackedVector2Array]=[]
        for polygon in pieces:remaining.append_array(Geometry2D.clip_polygons(polygon,previous))
        pieces=remaining
    paving_coverage152.append_array(pieces)
    var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var actual_faces:=PackedVector3Array()
    for polygon in pieces:
        if polygon.size()<3:continue
        var bounds:=Rect2(polygon[0],Vector2.ZERO)
        for point in polygon:bounds=bounds.expand(point)
        for gx in range(floori(bounds.position.x*.5),ceili(bounds.end.x*.5)):
            for gz in range(floori(bounds.position.y*.5),ceili(bounds.end.y*.5)):
                var x:=float(gx)*2;var z:=float(gz)*2
                for cell in [PackedVector2Array([Vector2(x,z),Vector2(x+2,z),Vector2(x,z+2)]),PackedVector2Array([Vector2(x+2,z),Vector2(x+2,z+2),Vector2(x,z+2)])]:
                    for clipped in Geometry2D.intersect_polygons(polygon,cell):
                        var indices:=Geometry2D.triangulate_polygon(clipped)
                        for i in range(0,indices.size(),3):
                            var triangle:=PackedVector3Array()
                            for j in range(3):
                                var point: Vector2=clipped[indices[i+j]]
                                triangle.append(Vector3(point.x,surface_height_at(point.x,point.y)+.035,point.y))
                            if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).y>0:
                                # Godot front faces are clockwise when viewed from above.
                                var swap:=triangle[1];triangle[1]=triangle[2];triangle[2]=swap
                            for point in triangle:
                                st.set_uv(Vector2(point.x,point.z)*.15);st.add_vertex(point);actual_faces.append(point)
    st.generate_normals();st.index()
    var node:=MeshInstance3D.new();node.name="GardenPath152_%02d"%path_source_index;node.mesh=st.commit();node.material_override=mats.paving;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC;node.set_meta("lightmap_source_id","path:%d"%path_source_index);node.set_meta("authored_geometry152",true);node.set_meta("stair_path_cutout151",true)
    paving_triangles152.append({"id":label,"source_id":"path:%d"%path_source_index,"triangles":actual_faces,"route":route.duplicate(),"half_width":width})
    path_source_index+=1;add_child(node)

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
        # The keyed moving portcullis owns the entrance bars and their body.
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
        var soil_y:=_soil_bed(Vector3(side*11,0,60.65),Vector2(10,2),.25,"entry_hedge")
        for i in range(6):_shrub(Vector3(side*(7+i*1.5),soil_y,60.65),1.4,4,"soil_bed")

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
    _box("stone",Vector3(-28,3.5,17.5),Vector3(2,1,1.4))

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
            if not shore.is_finite():continue
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
    # The canal is its own authored trough. It is not a second paved ribbon
    # drawn through the steep rock bank; the outer promenade supplies access.

func _upper_pavilion() -> void:
    var center=Vector3(47,12,-79)
    _audio_disc(center,9.0)
    _put("cylinder","stone",center,Vector3(18,.6,18))
    for i in range(10):
        var angle=i*TAU/10;var p=center+Vector3(cos(angle)*7,0,sin(angle)*7);_column(p,5.3,.9)
        if i%2==0:_ivy_column(p,5.3)
    _dome(center+Vector3.UP*5.3,7.4,4.3,16)
    for i in range(10):
        var angle=(i+.5)*TAU/10;var at: Vector3=center+Vector3(cos(angle)*7.5,.3,sin(angle)*7.5)
        _pot(at,.8);_shrub(at+Vector3.UP*.78,1.6,4,"pot")

func _barrel_roof(x1: float,x2: float) -> void:
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in range(16):
        var a=j*PI/16;var b=(j+1)*PI/16
        var pts=[Vector3(x1,11.4+sin(a)*3.7,-34+cos(a)*5),Vector3(x2,11.4+sin(a)*3.7,-34+cos(a)*5),Vector3(x1,11.4+sin(b)*3.7,-34+cos(b)*5),Vector3(x2,11.4+sin(b)*3.7,-34+cos(b)*5)]
        for k in [0,1,2,1,3,2]:st.add_vertex(pts[k])
    st.generate_normals();var n=MeshInstance3D.new();n.mesh=st.commit();n.material_override=mats.glass;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n)

func _cypress(p: Vector3,height: float) -> void:
    var point:=Layout.plant_point(Vector2(p.x,p.z),1.7)
    if point.is_finite():p=Vector3(point.x,surface_height_at(point.x,point.y),point.y)
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
    var point:=Layout.plant_point(Vector2(p.x,p.z),maxf(1.0,height*.11))
    if point.is_finite():p=Vector3(point.x,surface_height_at(point.x,point.y),point.y)
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
        for key in Layout.BED_KEYS:
            var present: bool=Layout.BEDS.has(key)
            var spec: Dictionary=Layout.BEDS.get(key,{"x":29.0,"z":float(key),"size":Vector2(10,5)})
            var x: float=side*float(spec.x);var z: float=spec.z;var size_: Vector2=spec.size
            var soil_y:=surface_height_at(x,z)
            if present:soil_y=_soil_bed(Vector3(x,soil_y,z),size_,.7,"formal_%d_%d"%[side,key])
            for i in range(16):
                var point:=Vector3(x+rng.randf_range(-size_.x*.40,size_.x*.40),soil_y,z+rng.randf_range(-size_.y*.30,size_.y*.30))
                var scale_:=rng.randf_range(.6,1.3)
                # Consume exactly the original stream even for retired beds.
                _shrub(point,scale_,4 if i%3 else 3,"soil_bed",present)
    for i in range(620):
        var x=rng.randf_range(-86,86);var z=rng.randf_range(-98,70)
        if absf(x)<12 or (absf(x)<36 and z< -19 and z> -46):continue
        if Vector2(x/22,(z-23)/12).length()<1:continue
        var type=3 if i%3==0 else (4 if i%5==0 else 5)
        var size_=rng.randf_range(.6,1.4);var angle_=rng.randf()*TAU
        _ground_plant(type,Vector2(x,z),size_,angle_)
    # Front glasshouse hedges occupy real soil strips behind the promenade.
    for side in [-1,1]:
        for z in [-25.5,-43.5]:
            var soil_y:=_soil_bed(Vector3(side*25,7,z),Vector2(24,2),.25,"gallery_hedge")
            for x in range(14,36,3):_shrub(Vector3(side*x,soil_y,z),rng.randf_range(1.2,2),4,"soil_bed")
    for p in [Vector3(-22,3,15),Vector3(23,3,16),Vector3(-40,7,-25.5),Vector3(40,7,-25.5)]:_pot(p,1.2);_shrub(p+Vector3.UP*1.16,2,4,"pot")

func _soil_bed(base: Vector3,size_: Vector2,height: float,label: String) -> float:
    var low:=base.y
    for dx in [-size_.x*.5,size_.x*.5]:
        for dz in [-size_.y*.5,size_.y*.5]:low=minf(low,surface_height_at(base.x+dx,base.z+dz))
    var body_top:=base.y+height-.15
    _put("furniture_box","stone",Vector3(base.x,(low+body_top)*.5,base.z),Vector3(size_.x,body_top-low+.02,size_.y))
    for side in [-1,1]:
        _put("furniture_box","trim",base+Vector3(side*(size_.x*.5-.15),height-.10,0),Vector3(.3,.2,size_.y))
        _put("furniture_box","trim",base+Vector3(0,height-.10,side*(size_.y*.5-.15)),Vector3(size_.x-.6,.2,.3))
    var soil_y:=base.y+height-.08
    _put("furniture_box","soil",Vector3(base.x,soil_y-.04,base.z),Vector3(size_.x-.6,.08,size_.y-.6))
    placement_records.append({"kind":"soil_bed","id":label,"root":base,"rect":Rect2(Vector2(base.x,base.z)-size_*.5,size_),"soil_rect":Rect2(Vector2(base.x,base.z)-(size_-Vector2.ONE*.6)*.5,size_-Vector2.ONE*.6),"soil_y":soil_y,"lip_y":base.y+height})
    return soil_y

func _shrub(p: Vector3,size_: float,type: int,context: String="pot",visible_: bool=true) -> void:
    var offset:=Vector3.ZERO
    for i in range(4):offset+=Vector3(rng.randf_range(-.25,.25),0,rng.randf_range(-.25,.25))*size_
    if not visible_:return
    var actual_type:=type if type in [3,4,5] else 4
    if context=="pot":
        for soil in placement_records:
            if soil.kind=="pot_soil" and Vector2(soil.root.x,soil.root.z).distance_to(Vector2(p.x,p.z))<.1:p.y=soil.soil_y;break
    var root:=p+offset*(.06 if context=="pot" else .25);var yaw:=p.x*.53+p.z*.31
    var mesh: Mesh=meshes["herb%d"%actual_type]
    root.y-=mesh.get_aabb().position.y*size_
    var binding:=_put("herb%d"%actual_type,"plants",root,Vector3.ONE*size_,Basis(Vector3.UP,yaw))
    placement_records.append({"batch_key":binding.key,"batch_index":binding.index,"kind":"bed_plant","root":root,"support_y":p.y,"support_class":context,"plant_type":actual_type,"scale":size_,"yaw":yaw,"mesh_key":"herb%d"%actual_type})

func _ground_plant(type: int,p: Vector2,size_: float,angle_: float) -> void:
    if not p.is_finite():return
    var radius:=maxf(.6,size_*.7)
    var point:=Layout.plant_point(p,radius)
    if not point.is_finite() or point.y< -95.0 or point.y>73.0 or absf(point.x)>86.0:return
    var y:=surface_height_at(point.x,point.y)
    # A vertical retaining face is not a plausible rooting surface.
    for delta in [Vector2(.4,0),Vector2(-.4,0),Vector2(0,.4),Vector2(0,-.4)]:
        if absf(surface_height_at(point.x+delta.x,point.y+delta.y)-y)>.4:return
    var root:=Vector3(point.x,y,point.y)
    var mesh: Mesh=meshes["herb%d"%type];root.y-=mesh.get_aabb().position.y*size_
    var binding:=_put("herb%d"%type,"plants",root,Vector3.ONE*size_,Basis(Vector3.UP,angle_))
    placement_records.append({"batch_key":binding.key,"batch_index":binding.index,"kind":"ground_plant","root":root,"support_y":y,"support_class":"grass","plant_type":type,"scale":size_,"yaw":angle_,"mesh_key":"herb%d"%type,"clearance_radius":radius})

func _ivy_column(p: Vector3,height: float) -> void:
    for i in range(5):
        var y=(i+.5)*height/5
        _foliage(1,p+Vector3(.1,y,.44),Vector2(1.2,height*.43),Basis(Vector3.UP,rng.randf_range(-.4,.4)))

func _pot(p: Vector3,size_: float) -> void:
    _put("cylinder","terra",p+Vector3.UP*size_*.45,Vector3(size_*.9,size_*.9,size_*.9))
    _put("cylinder","terra",p+Vector3.UP*size_*.87,Vector3(size_*1.12,size_*.13,size_*1.12))
    _put("cylinder","moss",p+Vector3.UP*size_*.95,Vector3(size_,.04,size_))
    placement_records.append({"kind":"pot_soil","root":p,"soil_y":p.y+size_*.95+.02,"radius":size_*.5})

func _canal_bridge152() -> void:
    var route: Array=Layout.PATHS[3]
    var crossing: Variant=null
    for i in range(route.size()-1):
        for j in range(Layout.CHANNEL_POINTS.size()-1):
            var point: Variant=Geometry2D.segment_intersects_segment(route[i],route[i+1],Layout.CHANNEL_POINTS[j],Layout.CHANNEL_POINTS[j+1])
            if point!=null:crossing=point
    if crossing==null:return
    var at:=Vector3(crossing.x,surface_height_at(crossing.x,crossing.y),crossing.y)
    var direction: Vector2=(route[-1]-route[-2]).normalized()
    var basis:=Basis(Vector3.UP,atan2(-direction.y,direction.x))
    var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _bridge_prism152(st,at,basis,-3.0,-.8,.035,.40,-.10,.28,5.3)
    _bridge_prism152(st,at,basis,-.8,.8,.40,.40,.28,.28,5.3)
    _bridge_prism152(st,at,basis,.8,3.0,.40,.035,.28,-.10,5.3)
    st.generate_normals();st.index()
    var bridge:=MeshInstance3D.new();bridge.name="CanalFootbridge152";bridge.mesh=st.commit();bridge.material_override=mats.paving;bridge.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC;bridge.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;bridge.set_meta("bridge152",true);add_child(bridge)
    placement_records.append({"kind":"canal_bridge","root":at,"direction":direction,"width":5.3,"deck_y":at.y+.40,"underpass_y":at.y+.28,"half_span":3.0,"ramp_slope":.365/2.2})

func _bridge_prism152(st: SurfaceTool,at: Vector3,basis: Basis,x0: float,x1: float,top0: float,top1: float,bottom0: float,bottom1: float,width: float) -> void:
    var points=[Vector3(x0,bottom0,-width*.5),Vector3(x1,bottom1,-width*.5),Vector3(x1,bottom1,width*.5),Vector3(x0,bottom0,width*.5),Vector3(x0,top0,-width*.5),Vector3(x1,top1,-width*.5),Vector3(x1,top1,width*.5),Vector3(x0,top0,width*.5)]
    var center:=Vector3.ZERO
    for point in points:center+=point/8.0
    for face in [[0,1,2,3],[4,5,6,7],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]:
        for indices in [[face[0],face[1],face[2]],[face[0],face[2],face[3]]]:
            var triangle:=PackedVector3Array([points[indices[0]],points[indices[1]],points[indices[2]]])
            var normal: Vector3=(triangle[1]-triangle[0]).cross(triangle[2]-triangle[0])
            if normal.dot((triangle[0]+triangle[1]+triangle[2])/3-center)>0:
                var swap:=triangle[1];triangle[1]=triangle[2];triangle[2]=swap
            for point in triangle:
                var world_point: Vector3=at+basis*point;st.set_uv(Vector2(world_point.x,world_point.z)*.15);st.add_vertex(world_point)

func _reconcile_ground_plants152() -> void:
    # After trees/furniture exist, reject roots inside their actual CPU-authored
    # solid bounds. Filter the same batch arrays later uploaded to the GPU.
    var grid: Dictionary={}
    for item in collision_instances:
        var bounds: AABB=item.at*item.mesh.get_aabb()
        for x in range(floori(bounds.position.x/8),floori(bounds.end.x/8)+1):
            for z in range(floori(bounds.position.z/8),floori(bounds.end.z/8)+1):
                var cell:=Vector2i(x,z)
                if not grid.has(cell):grid[cell]=[]
                grid[cell].append(bounds)
    var rejected: Dictionary={};var kept: Array[Dictionary]=[];var count:=0
    for row in placement_records:
        var blocked:=false
        if row.kind=="ground_plant":
            var point:=Vector3(row.root.x,float(row.support_y),row.root.z)
            for bounds: AABB in grid.get(Vector2i(floori(point.x/8),floori(point.z/8)),[]):
                if bounds.end.y>point.y+.035 and bounds.position.y<point.y+.23 and point.x>bounds.position.x-.025 and point.x<bounds.end.x+.025 and point.z>bounds.position.z-.025 and point.z<bounds.end.z+.025:
                    blocked=true;break
        if blocked:
            if not rejected.has(row.batch_key):rejected[row.batch_key]={}
            rejected[row.batch_key][row.batch_index]=true;count+=1
        else:kept.append(row)
    var remaps: Dictionary={}
    for key in rejected:
        var transforms: Array=batches[key];var filtered: Array=[];var remap: Dictionary={}
        for i in range(transforms.size()):
            if rejected[key].has(i):continue
            remap[i]=filtered.size();filtered.append(transforms[i])
        batches[key]=filtered;remaps[key]=remap
    for row in kept:
        if row.has("batch_key") and remaps.has(row.batch_key):row.batch_index=remaps[row.batch_key][row.batch_index]
    placement_records=kept;set_meta("layout152_loose_roots_removed_by_actual_solid_bounds",count)

func _furnishings() -> void:
    for index in range(Layout.BENCHES.size()):
        var spec: Array=Layout.BENCHES[index];var point: Vector2=spec[0];var basis:=Basis(Vector3.UP,float(spec[1]));var polygon:=Layout.bench_pad(spec)
        var y:=surface_height_at(point.x,point.y)+.04
        var center:=Vector3(point.x,y-.02,point.y)+basis*Vector3(0,0,.4)
        _put("furniture_box","paving",center,Vector3(3.8,.04,2.5),basis)
        var p:=Vector3(point.x,y,point.y)
        _put("furniture_box","wood",p+basis*Vector3(0,.55,0),Vector3(3,.14,.9),basis)
        _put("furniture_box","wood",p+basis*Vector3(0,1.05,-.38),Vector3(3,.8,.1),basis)
        var feet:=PackedVector3Array()
        for side in [-1,1]:
            _put("furniture_box","iron",p+basis*Vector3(side*1.1,.27,0),Vector3(.12,.54,.7),basis)
            for front in [-.29,.29]:feet.append(p+basis*Vector3(side*1.1,0,front))
        solid(p+basis*Vector3(0,.7,-.1),Vector3(3,1.4,1),"GardenBench",basis)
        placement_records.append({"kind":"bench","id":index,"root":p,"support_y":p.y,"yaw":spec[1],"pad":polygon,"feet":feet,"front":p+basis*Vector3(0,0,1.2),"seat_half_size":Vector2(1.5,.45)})
    for p in Layout.LAMP_POSTS:
        var pos:=Vector3(p.x,height_at(p.x,p.y),p.y)
        _beam(pos,pos+Vector3.UP*2.8,.09,"iron");_box("iron",pos+Vector3.UP*2.8,Vector3(.45,.55,.45))
        _box("trim",pos+Vector3.UP*3.15,Vector3(.6,.12,.6))
        placement_records.append({"kind":"lamp","id":"post_%d"%Layout.LAMP_POSTS.find(p),"root":pos,"visible_foot":pos,"radius":.30,"category":"decorative_post","realtime_light":false})

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
func _put(shape: String,material: String,p: Vector3,size_: Vector3,basis:=Basis.IDENTITY) -> Dictionary:
    var key="%s|%s|%d|%d"%[shape,material,floori(p.x/48),floori(p.z/48)]
    # New opaque herbs use identical batches/LOD distances in both benchmark
    # paths; only the legacy leaf cards belong to the old 48-meter baseline.
    if material=="plants" or (material=="leaves" and not get_meta("reference_rendering",false)):key="%s|%s|%d|%d"%[shape,material,floori(p.x/24),floori(p.z/24)]
    if shape=="box" and material in ["wood","iron","terra","trim"]:key="%s|%s|0|0"%[shape,material]
    if not batches.has(key):batches[key]=[]
    # The Dummy renderer does not retain MultiMesh instance buffers. Keep the
    # same authored CPU transforms for physical geometry on every renderer.
    if material not in ["plants","leaves","water"] and shape not in ["lily_pad","lilyflower"]:
        collision_instances.append({"mesh":meshes[shape],"at":Transform3D(basis*Basis.from_scale(size_),p),"kind":shape,"material":material,"label":"%s_%s_%d"%[shape,material,collision_instances.size()],"batch_key":key,"batch_index":batches[key].size()})
    var index: int=batches[key].size()
    batches[key].append(Transform3D(basis*Basis.from_scale(size_),p))
    return {"key":key,"index":index}
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
        if parts[0]=="box" and parts[1] in ["stone","trim"] or parts[0]=="cylinder" and parts[1] in ["terra","moss"]:node.set_meta("authored_geometry152",true);node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
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
