extends SceneTree
## Production 1.48 geometry, real immutable buffers and reversible control.
## Staged native acceptance; full mission routes are separate gameplay gates.
var failures: Array[String]=[]
var output:="user://foliage148"
var visual:=false
var game
var report: Dictionary={"failures":[],"proxy_meshes":[],"poses":[]}
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL FOLIAGE148: "+why)
func settle(count: int=3) -> void:
    for i in range(count):await process_frame
func draw() -> void:
    await process_frame;RenderingServer.force_draw(true);await process_frame
func shader_code(material: ShaderMaterial) -> String:
    var lines=PackedStringArray()
    for line in material.shader.code.split("\n"):lines.append(String(line).get_slice("//",0))
    return "\n".join(lines)
func audit_proxy(mesh: ArrayMesh) -> Dictionary:
    check(mesh.get_surface_count()==1,"proxy must use one opaque draw surface")
    var arrays=mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    var weld={};var ids=PackedInt32Array();var edges={};var volume=0.0
    for i in range(vertices.size()):
        check(vertices[i].is_finite() and normals[i].is_finite(),"nonfinite proxy geometry")
        check(absf(normals[i].length()-1.0)<.001,"proxy normal is not unit length")
        var key=Vector3i((vertices[i]*100000).round())
        if not weld.has(key):weld[key]=weld.size()
        ids.append(weld[key])
    for offset in range(0,indices.size(),3):
        var a: int=indices[offset];var b: int=indices[offset+1];var c: int=indices[offset+2]
        var cross_=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
        check(cross_.dot(normals[a]+normals[b]+normals[c])<-.000001,"proxy winding points inside or has a degenerate triangle")
        volume+=vertices[a].dot(vertices[b].cross(vertices[c]))/6.0
        for edge in [[ids[a],ids[b]],[ids[b],ids[c]],[ids[c],ids[a]]]:
            var key=Vector2i(mini(edge[0],edge[1]),maxi(edge[0],edge[1]))
            edges[key]=int(edges.get(key,0))+1
    for count in edges.values():check(count==2,"proxy is open or nonmanifold")
    check(volume<-.20 and volume>-.70,"proxy has no real closed volume")
    return {"vertices":vertices.size(),"welded_vertices":weld.size(),"triangles":indices.size()/3,"signed_volume":volume,"closed_edges":edges.size()}
func run() -> void:
    check(DisplayServer.get_name()!="headless","native MultiMesh buffers and shaders required")
    if not failures.is_empty():quit(1);return
    root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    DirAccess.make_dir_recursive_absolute(output)
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    game.set_physics_process(false);game.player.set_physics_process(false)
    for guard in game.guards:guard.set_physics_process(false)
    game.hud.hide();game.weapon.hide();game.world.set_meta("force_mobile_profile",true);game.world._mobile_profile()
    for label in game.find_children("*","Label3D",true,false):label.hide()
    var optimizer=game.world.rendering_optimizer
    var foliage=optimizer.mobile_foliage
    check(not optimizer.is_reference_147_enabled() and foliage.root.visible,"new profile is not production default")
    check(foliage.near_card_count>10000 and foliage.lobe_count>1000 and foliage.far_crown_count>100,"real authored tree hierarchy was omitted")
    check(foliage.herb_count>1000 and not foliage.herb_chunks.is_empty(),"real 3D undergrowth omitted")
    var source_count=0
    for record in optimizer.foliage_records:
        source_count+=record.multi.instance_count
        check(not record.instance.visible,"old color foliage duplicates new geometry")
        if record.instance.has_meta("foliage_shadow_node"):check(not record.instance.get_meta("foliage_shadow_node").visible,"masked old shadow caster remains active")
    var preserved_count=0;var aquatic_count=0
    for record in optimizer.preserved_foliage_records:
        var shape=String(record.instance.get_meta("lightmap_source_id","")).trim_prefix("batch:").get_slice("|",0)
        preserved_count+=record.multi.instance_count;source_count+=record.multi.instance_count
        if shape=="lily_pad":aquatic_count+=record.multi.instance_count
        check(record.instance.visible and record.multi.mesh==game.world.meshes.get(shape),"unreplaced foliage disappeared or changed its original mesh")
        check(record.instance.material_override==optimizer._preserved_materials[record.instance],"unrebuilt foliage received an incompatible fast material")
    check(aquatic_count>0,"aquatic leaf pads were not preserved under their flowers")
    var proxy_meshes={};var buffer_snapshots={};var node_geometry={}
    for chunk in foliage.chunks:
        var node: GeometryInstance3D=chunk.node
        check(node.gi_mode==GeometryInstance3D.GI_MODE_DYNAMIC,"foliage lost the evening probe volume")
        check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"old expensive masked foliage shadow pass retained")
        check(node.get_meta("botanical_foliage",false),"diagnostics cannot find a foliage chunk")
        var code=shader_code(node.material_override)
        check("vertex_lighting" in code and "specular_disabled" in code,"new foliage still uses per-fragment specular lighting")
        if node is MultiMeshInstance3D:
            check(not "ALPHA =" in code and not "discard" in code,"volume proxy enters alpha/transparent rendering")
            var mesh: ArrayMesh=node.multimesh.mesh
            if not proxy_meshes.has(mesh):proxy_meshes[mesh]=true;report.proxy_meshes.append(audit_proxy(mesh))
        else:
            check(node.mesh.get_surface_count()==1,"near foliage still uses multiple color passes")
            check("discard" in code and not "alpha_mask" in code,"near leaf mask either lost or double-sampled")
            node_geometry[node]=node.mesh.get_rid()
    var herbal_roots=0
    for chunk in foliage.herb_chunks:
        var full: MultiMeshInstance3D=chunk.near
        var mid: MultiMeshInstance3D=chunk.middle
        var far: MultiMeshInstance3D=chunk.far
        check(full.multimesh.instance_count>=mid.multimesh.instance_count and mid.multimesh.instance_count>=far.multimesh.instance_count,"distance undergrowth density increases")
        check(far.multimesh.instance_count<=ceili(full.multimesh.instance_count*.5),"far undergrowth retains excessive density")
        var roots={}
        for t: Transform3D in chunk.transforms:roots[t]=true;herbal_roots+=1
        for node in [full,mid,far]:
            for i in range(node.multimesh.instance_count):check(roots.has(node.multimesh.get_instance_transform(i)),"LOD invented a floating/moved plant root")
    check(herbal_roots==foliage.herb_count,"chunk construction lost or duplicated authored plants")
    for node in foliage.nodes:
        if node is MultiMeshInstance3D:buffer_snapshots[node]=node.multimesh.buffer
    var static_states={}
    for original in game.world.baked_lighting.originals:static_states[original]=[original.visible,original.cast_shadow]
    for i in range(30):
        game.player.camera.global_position=Vector3(-55+i*4,7.6,-50+i*3)
        game.player.camera.look_at(Vector3(0,8,-35));optimizer.update(game.player.camera)
    for node in buffer_snapshots:check(node.multimesh.buffer==buffer_snapshots[node],"moving camera reuploaded/rewrote an immutable foliage buffer")
    for node in node_geometry:check(node.mesh.get_rid()==node_geometry[node],"moving camera rebuilt near meshes")
    check(foliage.summary(game.player.camera).foliage_buffer_upload_bytes==0,"foliage reports live buffer uploads")
    optimizer.set_enabled(false)
    for node in foliage.nodes:check(node.visibility_range_end==0,"distance-culling off retained a native rejection range")
    for chunk in foliage.herb_chunks:check(chunk.level==0 and chunk.near.visible and not chunk.middle.visible and not chunk.far.visible,"distance-culling off retained a sparse distant tier")
    optimizer.set_enabled(true);optimizer.update(game.player.camera)
    for node in foliage.nodes:check(node.visibility_range_end>0,"distance-culling restore lost native range")
    game.world.set_reference_147_enabled(true)
    check(optimizer.is_reference_147_enabled() and not foliage.root.visible,"reference mode leaks new production geometry")
    for node in optimizer._original_visibility:check(node.visible==optimizer._original_visibility[node],"reference did not restore original foliage/shadow visibility")
    game.world.set_reference_147_enabled(false)
    check(not optimizer.is_reference_147_enabled() and foliage.root.visible,"reference mode did not restore production")
    for original in static_states:check(original.visible==static_states[original][0] and original.cast_shadow==static_states[original][1],"reference toggle duplicated or hid baked static colors/shadows")
    for pose in [["entry",Vector3(0,1.6,65),Vector3(0,4,-35)],["concept",Vector3(-22,4.6,22),Vector3(0,6,-47)],["upper",Vector3(-23,13.6,-88),Vector3(26,15,-61)],["near-forest",Vector3(11,2.6,48),Vector3(26,10,52)],["pond",Vector3(25,5.6,31),Vector3(0,3.0,23)]]:
        game.player.camera.global_position=pose[1];game.player.camera.look_at(pose[2]);optimizer.update(game.player.camera)
        await draw();await draw()
        if visual:root.get_texture().get_image().save_png(output.path_join(pose[0]+".png"))
        report.poses.append({"view":pose[0],"workload":optimizer.workload_summary(game.player.camera),"calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
    report.original_foliage_instances=source_count;report.preserved_original_foliage_instances=preserved_count;report.preserved_aquatic_instances=aquatic_count;report.immutable_buffers_checked=buffer_snapshots.size();report.immutable_meshes_checked=node_geometry.size()
    report.failures=failures;report.note="Native production geometry/material/buffer/restore acceptance with staged cameras. Full gameplay and actual hardware FPS are separate checks."
    FileAccess.open(output.path_join("foliage148-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    game.queue_free();current_scene=null;await settle(5)
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    RenderingServer.set_render_loop_enabled(true)
    if failures.is_empty():print("BOTANICAL FOLIAGE148: PASS — closed opaque canopy LODs, real 3D herbs, immutable chunks, native ranges and exact reference restoration")
    quit(0 if failures.is_empty() else 1)
