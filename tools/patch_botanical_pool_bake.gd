@tool
extends SceneTree
## Offline one-time migration of the 1.42 receiver scene. Requires native GL.
## Pass --source=/absolute/path/to/original-garden-142.scn (never the output).
var source_scene:=""
func _init():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--source="):source_scene=arg.trim_prefix("--source=")
    call_deferred("run")
func inside(p: Vector3) -> bool:
    return absf(absf(p.x)-14.0)<3.5 and p.y>=2.8 and p.y<=4.65 and absf(p.z-25.0)<.95
func key(p: Vector3) -> Vector3i:return Vector3i(roundi(p.x*10000),roundi(p.y*10000),roundi(p.z*10000))
func run():
    assert(DisplayServer.get_name()!="headless","Preserve probe data with a native renderer")
    assert(not source_scene.is_empty(),"Supply the original 1.42 scene with --source=")
    assert(FileAccess.get_sha256(source_scene)=="3fcf03ab0add3c34a9cebaebf4d7aedece54bba126dfc9d668c0253c818b5d1d","Input is not the original 1.42 receiver scene")
    var world=load("res://scripts/botanical_world.gd").new();world.set_meta("skip_baked_lighting",true);root.add_child(world);world.build()
    var sources={}
    for source in world.get_children():
        if source is GeometryInstance3D and source.has_meta("lightmap_source_id"):sources[String(source.get_meta("lightmap_source_id"))]=source
    var mapping=JSON.parse_string(FileAccess.get_file_as_string("res://assets/level1/botanical/lighting/source_bindings.json")).sources
    var scene=load(source_scene).instantiate()
    var probes=scene.get_node("BakedGI").light_data.get("probe_data");assert(probes.points.size()==901)
    var relocated={}
    var box=world.meshes.box.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    for pair in world.rim_relocations:
        var delta=pair[1]*pair[0].affine_inverse()
        for point in box:relocated[key(pair[0]*point)]=[pair[1]*point,delta.basis.inverse().transposed()]
    var removed=0;var changed=0;var moved_vertices=0
    for receiver in scene.get_children():
        if not receiver is MeshInstance3D:continue
        var id=String(mapping[str(receiver.get_meta("source_child"))]);receiver.set_meta("lightmap_source_id",id)
        if sources.has(id):receiver.set_meta("source_bounds",sources[id].transform*sources[id].get_aabb())
        var mesh=receiver.mesh;var arrays=mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var old=arrays[Mesh.ARRAY_INDEX]
        var kept=PackedInt32Array()
        for i in range(0,old.size(),3):
            if inside(receiver.transform*vertices[old[i]]) and inside(receiver.transform*vertices[old[i+1]]) and inside(receiver.transform*vertices[old[i+2]]):removed+=1
            else:kept.append_array(PackedInt32Array([old[i],old[i+1],old[i+2]]))
        var moved=false
        if id=="batch:box|trim|0|0":
            var normals=arrays[Mesh.ARRAY_NORMAL]
            for i in range(vertices.size()):
                var lookup=key(receiver.transform*vertices[i])
                if relocated.has(lookup):
                    var edit=relocated[lookup];vertices[i]=receiver.transform.affine_inverse()*edit[0];normals[i]=(edit[1]*normals[i]).normalized();moved=true;moved_vertices+=1
            arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
        if kept.size()==old.size() and not moved:continue
        assert(not kept.is_empty());arrays[Mesh.ARRAY_INDEX]=kept
        var importer=ImporterMesh.new();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},mesh.surface_get_material(0));importer.generate_lods(60,25,[])
        var replacement=importer.get_mesh();replacement.lightmap_size_hint=mesh.lightmap_size_hint;receiver.mesh=replacement;changed+=1
    assert(removed>0 and changed>0 and moved_vertices>500)
    var packed=PackedScene.new();assert(packed.pack(scene)==OK)
    assert(ResourceSaver.save(packed,"res://assets/level1/botanical/lighting/garden.scn",ResourceSaver.FLAG_COMPRESS)==OK)
    print("POOL BAKE PATCH: ",removed," old intrusive triangles removed; ",moved_vertices," coping vertices relocated in ",changed," receivers; 901 probes preserved")
    scene.free()
    var camera=Camera3D.new();camera.position=Vector3(0,1.6,65);root.add_child(camera)
    for i in range(4):await process_frame;RenderingServer.force_draw(true)
    world.queue_free();camera.queue_free()
    for i in range(6):await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self);quit()
