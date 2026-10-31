extends SceneTree
## Remove bake-only foliage receivers and the duplicate environment/sun.
## Keep the exact UV2 receiver node names referenced by LightmapGIData.
func _init() -> void:call_deferred("run")
func partition(mesh: ArrayMesh) -> Array[ArrayMesh]:
    var arrays=mesh.surface_get_arrays(0);var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var groups={}
    for i in range(0,indices.size(),3):
        var center=(positions[indices[i]]+positions[indices[i+1]]+positions[indices[i+2]])/3.0
        var cell=Vector2i(floori(center.x/48),floori(center.z/48))
        if not groups.has(cell):groups[cell]=PackedInt32Array()
        for j in range(3):groups[cell].append(indices[i+j])
    if groups.size()==1:return [mesh]
    var result: Array[ArrayMesh]=[]
    for group: PackedInt32Array in groups.values():
        var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for index in group:
            st.set_normal(arrays[Mesh.ARRAY_NORMAL][index])
            st.set_uv(arrays[Mesh.ARRAY_TEX_UV][index]);st.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][index])
            if arrays[Mesh.ARRAY_COLOR]!=null and arrays[Mesh.ARRAY_COLOR].size()>0:st.set_color(arrays[Mesh.ARRAY_COLOR][index])
            if arrays[Mesh.ARRAY_TANGENT]!=null and arrays[Mesh.ARRAY_TANGENT].size()>0:
                var t=arrays[Mesh.ARRAY_TANGENT];st.set_tangent(Plane(t[index*4],t[index*4+1],t[index*4+2],t[index*4+3]))
            st.add_vertex(positions[index])
        st.index();var chunk=st.commit();var importer=ImporterMesh.new()
        importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,chunk.surface_get_arrays(0),[],{},mesh.surface_get_material(0))
        importer.generate_lods(60,25,[]);chunk=importer.get_mesh();chunk.lightmap_size_hint=mesh.lightmap_size_hint
        result.append(chunk)
    var count=0
    for chunk in result:count+=chunk.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()
    assert(count==indices.size(),"Partitioning dropped or duplicated baked receiver triangles")
    return result
func run() -> void:
    assert(DisplayServer.get_name()!="headless","Dummy renderer discards probe storage; finalize with the native renderer")
    RenderingServer.set_render_loop_enabled(false)
    var world=load("res://scripts/botanical_world.gd").new()
    world.set_meta("skip_baked_lighting",true);root.add_child(world);world.build();world.set_process(false)
    var path="res://assets/level1/botanical/lighting/"
    var scene=load(path+"garden_source.scn").instantiate()
    var gi=scene.get_node("BakedGI")
    var data: LightmapGIData=gi.light_data
    assert(data.get_user_count()>=121,"Expected the complete baked source scene")
    var probes: Dictionary=data.get("probe_data")
    assert(probes.points.size()>=748 and probes.sh.size()==probes.points.size()*9,"Missing baked probe capture")
    var users=data._get_user_data();var kept=[];var seen={}
    for i in range(0,users.size(),4):
        if "BakeOccluder" in str(users[i]):continue
        var base_path=NodePath(str(users[i]).get_slice("Part",0))
        if seen.has(base_path):continue
        seen[base_path]=true
        kept.append_array([base_path,users[i+1],users[i+2],users[i+3]])
    data._set_user_data(kept)
    assert(data.get_user_count()==int(scene.get_meta("receiver_count",121)),"Every static receiver must have a lightmap")
    var runtime_users=[]
    for i in range(0,kept.size(),4):
        var receiver: MeshInstance3D=gi.get_node(kept[i])
        var source=world.get_child(int(receiver.get_meta("source_child")))
        if receiver.has_meta("lightmap_source_id"):
            source=null
            for candidate in world.get_children():
                if candidate.get_meta("lightmap_source_id",null)==receiver.get_meta("lightmap_source_id"):source=candidate;break
            assert(source!=null,"Baked source ID is missing from the garden")
        var source_bounds=source.transform*source.get_aabb()
        var chunks: Array[ArrayMesh]=[]
        if source is MultiMeshInstance3D:chunks=partition(receiver.mesh)
        else:chunks.append(receiver.mesh)
        if chunks.size()==1:
            receiver.set_meta("source_bounds",source_bounds);runtime_users.append_array(kept.slice(i,i+4))
            continue
        for j in range(chunks.size()):
            var part=MeshInstance3D.new();part.name=str(receiver.name)+"Part%03d"%j;part.mesh=chunks[j]
            part.lod_bias=receiver.lod_bias;part.visibility_range_end=receiver.visibility_range_end;part.visibility_range_end_margin=receiver.visibility_range_end_margin
            part.gi_mode=GeometryInstance3D.GI_MODE_STATIC;part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            part.set_meta("source_child",receiver.get_meta("source_child"));part.set_meta("source_bounds",source_bounds)
            part.set_meta("lightmap_source_id",source.get_meta("lightmap_source_id",""))
            scene.add_child(part);part.owner=scene
            runtime_users.append_array([NodePath("../"+str(part.name)),kept[i+1],kept[i+2],kept[i+3]])
        scene.remove_child(receiver);receiver.free()
    data._set_user_data(runtime_users)
    assert(ResourceSaver.save(data,path+"garden.lmbake",ResourceSaver.FLAG_COMPRESS)==OK)
    for node in scene.get_children():
        if node.name.begins_with("BakeOccluder") or node is Light3D or node is WorldEnvironment or node is LightmapProbe:
            scene.remove_child(node);node.free()
    var packed=PackedScene.new();assert(packed.pack(scene)==OK)
    assert(ResourceSaver.save(packed,path+"garden.scn",ResourceSaver.FLAG_COMPRESS)==OK)
    # Lossless half-float lightmaps preserve gradients and avoid expensive
    # compressed HDR decoder shader generation on software validation GPUs.
    var import_settings=ConfigFile.new()
    assert(import_settings.load(path+"garden.exr.import")==OK)
    import_settings.set_value("params","compress/mode",0)
    assert(import_settings.save(path+"garden.exr.import")==OK)
    print("BOTANICAL LIGHTING FINALIZED: ",data.get_user_count()," real lightmapped receivers, ",data.get_lightmap_textures().size()," atlas textures, ",probes.points.size()," probes")
    scene.free();world.free();quit()
