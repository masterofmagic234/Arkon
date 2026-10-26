@tool
extends SceneTree
## Export the deterministic garden to UV2 static receivers. Run in the native
## editor binary, then bake garden_source.scn with botanical_baker enabled.
const OUT="res://assets/level1/botanical/lighting"
var receiver_count:=0
var occluder_count:=0
func _init() -> void:call_deferred("run")
func save_resource(resource: Resource,path: String) -> void:
    assert(ResourceSaver.save(resource,path,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)==OK)
func merged(source: Mesh,transforms: Array,material: Material) -> ArrayMesh:
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for transform_: Transform3D in transforms:st.append_from(source,0,transform_)
    # SurfaceTool.append_from applies basis directly to normals, which is
    # incorrect for the garden's nonuniformly scaled rocks/tapered branches.
    # Correct them before UV unwrapping, baking and rendering merged geometry.
    var intermediate=st.commit();var arrays=intermediate.surface_get_arrays(0)
    var source_normals: PackedVector3Array=source.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
    var normals=PackedVector3Array()
    for transform_: Transform3D in transforms:
        var changed=Transform3D(transform_.basis.inverse().transposed(),Vector3.ZERO)*source_normals
        for i in range(changed.size()):changed[i]=changed[i].normalized()
        normals.append_array(changed)
    arrays[Mesh.ARRAY_NORMAL]=normals
    var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    result.surface_set_material(0,material)
    return result
func foliage_proxy(source: Mesh) -> ArrayMesh:
    var arrays=source.surface_get_arrays(0)
    var surfaces=source.get("_surfaces")
    var lods: Array=surfaces[0].lods
    var bytes: PackedByteArray=lods[7] # 16 px core, fourth stored LOD.
    var indices=PackedInt32Array();indices.resize(bytes.size()/2)
    for i in range(indices.size()):indices[i]=bytes.decode_u16(i*2)
    # This mesh is only an occluder. Its small overlapping receiver chart is
    # discarded after baking; ray-traced bounces never sample receiver charts.
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index in indices:
        st.set_normal(arrays[Mesh.ARRAY_NORMAL][index]);st.set_color(Color.WHITE)
        st.set_uv(arrays[Mesh.ARRAY_TEX_UV][index]);st.set_uv2(arrays[Mesh.ARRAY_TEX_UV][index])
        st.add_vertex(arrays[Mesh.ARRAY_VERTEX][index])
    st.index();return st.commit()
func run() -> void:
    RenderingServer.set_render_loop_enabled(false)
    DirAccess.make_dir_recursive_absolute(OUT+"/meshes")
    var world=load("res://scripts/botanical_world.gd").new()
    world.set_meta("skip_baked_lighting",true)
    root.add_child(world);world.build();world.set_process(false)
    world.set_distance_culling_enabled(false)
    var scene=Node3D.new();scene.name="BakedGarden";root.add_child(scene)
    var proxies={}
    for source in world.get_children():
        if not source is GeometryInstance3D:continue
        if source.get_meta("foliage_shadow_proxy",false):continue
        if source.material_override in [world.mats.glass,world.mats.water]:continue
        var transforms: Array=[]
        var source_mesh: Mesh
        if source is MultiMeshInstance3D:
            source_mesh=source.multimesh.mesh
            for i in range(source.multimesh.instance_count):transforms.append(source.transform*source.multimesh.get_instance_transform(i))
        elif source is MeshInstance3D:
            source_mesh=source.mesh;transforms.append(source.transform)
        else:continue
        var foliage=source.get_meta("botanical_foliage",false)
        var material=source.material_override
        if foliage:
            if not proxies.has(source_mesh):proxies[source_mesh]=foliage_proxy(source_mesh)
            source_mesh=proxies[source_mesh]
            material=StandardMaterial3D.new();material.albedo_color=Color(.17,.29,.12);material.roughness=1
            material.cull_mode=BaseMaterial3D.CULL_DISABLED
        var mesh=merged(source_mesh,transforms,material)
        if foliage:
            mesh.lightmap_size_hint=Vector2i(16,16)
        else:
            var error=mesh.lightmap_unwrap(Transform3D.IDENTITY,.65)
            assert(error==OK,"UV2 failed for "+source.name)
            # Regenerate useful distance LODs after UV2 seam splits.
            var importer=ImporterMesh.new()
            importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0),[],{},material)
            importer.generate_lods(60,25,[])
            var hint=mesh.lightmap_size_hint
            mesh=importer.get_mesh();mesh.lightmap_size_hint=hint
        var node=MeshInstance3D.new()
        node.name=("BakeOccluder%03d"%occluder_count) if foliage else ("Static%03d"%receiver_count)
        node.mesh=mesh;node.gi_mode=GeometryInstance3D.GI_MODE_STATIC
        node.cast_shadow=source.cast_shadow;node.lod_bias=source.lod_bias
        node.visibility_range_end=0 # Every authored plant contributes to bake.
        if not foliage:
            node.set_meta("source_child",source.get_index())
            node.visibility_range_end=source.visibility_range_end
            node.visibility_range_end_margin=source.visibility_range_end_margin
            save_resource(mesh,OUT+"/meshes/"+node.name+".res")
            receiver_count+=1
        else:occluder_count+=1
        scene.add_child(node);node.owner=scene
        if not foliage:print("UV2 ",node.name," ",mesh.lightmap_size_hint)
    for node in world.get_children():
        if node is WorldEnvironment or node is Light3D:
            var copy=node.duplicate();scene.add_child(copy);copy.owner=scene
            if copy is WorldEnvironment:copy.environment.ssao_enabled=false
            if copy is Light3D:copy.light_bake_mode=Light3D.BAKE_DYNAMIC
    for x in range(-64,65,8):
        for z in range(-96,73,8):
            for height in [1.1,3.0]:
                var probe=LightmapProbe.new();probe.position=Vector3(x,world.height_at(x,z)+height,z)
                scene.add_child(probe);probe.owner=scene
    var gi=LightmapGI.new();gi.name="BakedGI";gi.quality=LightmapGI.BAKE_QUALITY_LOW
    gi.bounces=1;gi.directional=false;gi.use_texture_for_bounces=false
    gi.max_texture_size=2048;gi.generate_probes_subdiv=LightmapGI.GENERATE_PROBES_SUBDIV_8
    gi.use_denoiser=true;gi.bias=.04
    save_resource(LightmapGIData.new(),OUT+"/garden.lmbake")
    gi.light_data=load(OUT+"/garden.lmbake");scene.add_child(gi);gi.owner=scene
    var packed=PackedScene.new();assert(packed.pack(scene)==OK)
    assert(ResourceSaver.save(packed,OUT+"/garden_source.scn",ResourceSaver.FLAG_COMPRESS)==OK)
    print("BOTANICAL BAKE SCENE READY receivers=",receiver_count," occluders=",occluder_count)
    world.free();scene.free();quit()
