extends RefCounted
## Authored dusk, bounded terrain and cyan/lilac wayfinding. No volumetrics.
static func configure_lighting(world: Node3D) -> void:
    var sky=Sky.new();var material=ShaderMaterial.new();material.shader=preload("res://shaders/woodland/garden_evening_sky.gdshader");material.set_shader_parameter("compatibility_output",RenderingServer.get_current_rendering_method()=="gl_compatibility");sky.sky_material=material;sky.radiance_size=Sky.RADIANCE_SIZE_128
    world.environment.sky=sky
    world.environment.background_energy_multiplier=1.0
    world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    world.environment.ambient_light_color=Color("607fa8");world.environment.ambient_light_energy=.22
    world.environment.fog_enabled=true;world.environment.fog_density=.012
    world.environment.fog_light_color=Color("23354e");world.environment.fog_light_energy=.50;world.environment.fog_sky_affect=.58
    # The old daylight GL grade used .8 contrast, lifting near-black surfaces
    # into a grey veil at night. Keep the evening's dark range while retaining
    # the existing exposure/saturation compensation for Compatibility lighting.
    if RenderingServer.get_current_rendering_method()=="gl_compatibility":
        world.environment.adjustment_contrast=.94
    world.environment.ssao_enabled=true
    var moon=world.get_node("GardenSun") as DirectionalLight3D
    moon.name="GardenSun" # Retained stable diagnostic binding; now authored moonlight.
    moon.light_color=Color("9db9e8");moon.light_energy=.24;moon.rotation_degrees=Vector3(-39,-141,0)
static func apply(world: Node3D) -> void:
    world.environment.ssao_enabled=false
    _land(world)
    _lamps(world)
    preload("res://scripts/botanical_task_lights153.gd").apply(world)
static func _land(world: Node3D) -> void:
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var grid=[-2048.0,-1024.0,-512.0,-256.0]
    # Share every two-metre boundary vertex with the existing terrain. A few
    # coarse corner samples would leave cracks along its undulating edge.
    for coordinate in range(-160,161,2):grid.append(float(coordinate))
    grid.append_array([256.0,512.0,1024.0,2048.0])
    for x in range(grid.size()-1):
        for z in range(grid.size()-1):
            if grid[x]>=-160 and grid[x+1]<=160 and grid[z]>=-160 and grid[z+1]<=160:continue
            var points=[]
            for pair in [[x,z],[x+1,z],[x,z+1],[x+1,z+1]]:
                var px: float=grid[pair[0]];var pz: float=grid[pair[1]]
                var extent=maxf(absf(px),absf(pz));var fade=smoothstep(160,800,extent)
                var base=world.height_at(clampf(px,-160,160),clampf(pz,-160,160))
                points.append(Vector3(px,base+fade*(22+10*sin(px*.004)*cos(pz*.005)),pz))
            for k in [0,1,2,1,3,2]:st.add_vertex(points[k])
    st.generate_normals();var land=MeshInstance3D.new();land.name="ContinuousOuterLandscape";land.mesh=st.commit()
    var earth=world.mats.ground
    land.material_override=earth;land.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(land)
    # Real retaining wall foundations and an iron fence accompany the existing
    # physical boundary. The apron continues for two kilometres beyond it.
    var boundary=Node3D.new();boundary.name="GardenPerimeter";world.add_child(boundary)
    var stone=world.mats.trim
    var iron=StandardMaterial3D.new();iron.albedo_color=Color("1f2b35");iron.metallic=.35;iron.roughness=.8
    var parts={stone:[],iron:[]}
    var physical=StaticBody3D.new();physical.name="SolidPerimeter";physical.collision_layer=1;boundary.add_child(physical)
    # The south fence stops at the entrance pillars: its visual rails and
    # physical boxes share the same real vehicle opening.
    for line in [[Vector2(-88,-97),Vector2(88,-97)],[Vector2(-88,77),Vector2(-6,77)],[Vector2(6,77),Vector2(88,77)],[Vector2(-88,-97),Vector2(-88,77)],[Vector2(88,-97),Vector2(88,77)]]:
        var a: Vector2=line[0];var b: Vector2=line[1];var count=ceili(a.distance_to(b)/4)
        var span: float=a.distance_to(b)/count+.1
        for i in range(count):
            var p=a.lerp(b,(i+.5)/count);var y: float=world.surface_height_at(p.x,p.y);var side=(b-a).normalized();var yaw=atan2(-side.y,side.x)
            parts[stone].append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(span,.65,.55)),Vector3(p.x,y+.25,p.y)))
            var shape=BoxShape3D.new();shape.size=Vector3(span,2.7,.55);var collision=CollisionShape3D.new();collision.shape=shape;collision.position=Vector3(p.x,y+1.0,p.y);collision.rotation.y=yaw;physical.add_child(collision)
            for rail in [.9,1.8]:parts[iron].append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(span,.055,.065)),Vector3(p.x,y+rail,p.y)))
            for j in range(5):
                var q=p+side*(j*.8-1.6);parts[iron].append(Transform3D(Basis.from_scale(Vector3(.055,1.8,.055)),Vector3(q.x,y+1.2,q.y)))
    for mat in parts:
        var mesh=BoxMesh.new();mesh.size=Vector3.ONE;var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=parts[mat].size()
        for i in range(mm.instance_count):mm.set_instance_transform(i,parts[mat][i])
        var node=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;boundary.add_child(node)
static func _lamps(world: Node3D) -> void:
    var root=Node3D.new();root.name="EveningLanterns";world.add_child(root)
    var metal=StandardMaterial3D.new();metal.albedo_color=Color("283139");metal.roughness=.8
    for p in preload("res://scripts/botanical_layout.gd").EVENING_LAMPS:
        var y: float=world.surface_height_at(p.x,p.y)
        _box(root,Vector3(p.x,y+1.75,p.y),Vector3(.10,3.5,.10),metal)
        _box(root,Vector3(p.x,y+3.45,p.y),Vector3(.45,.58,.45),metal)
        var visible_foot:=Vector3(p.x,y+(.30 if p==Vector2(47,-79) else 0.0),p.y)
        world.placement_records.append({"kind":"lamp","id":"lantern_%d"%preload("res://scripts/botanical_layout.gd").EVENING_LAMPS.find(p),"root":Vector3(p.x,y,p.y),"visible_foot":visible_foot,"radius":.275,"category":"pavilion_interior" if p==Vector2(47,-79) else "realtime_lantern","realtime_light":true,"energy":1.15,"range":11.0,"base_embedded_in_pavilion":p==Vector2(47,-79)})
        var light=OmniLight3D.new();light.position=Vector3(p.x,y+3.2,p.y);light.light_color=Color("59d6cc") if preload("res://scripts/botanical_layout.gd").EVENING_LAMPS.find(p)%2==0 else Color("af8bc9");light.light_energy=1.15;light.omni_range=11;light.omni_attenuation=1.4;light.shadow_enabled=false;light.distance_fade_enabled=true;light.distance_fade_begin=27;light.distance_fade_length=8;root.add_child(light)
static func _box(root: Node3D,p: Vector3,size: Vector3,mat: Material) -> void:
    var node=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=p;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(node)
