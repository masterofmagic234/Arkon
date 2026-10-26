extends SceneTree
var failed:=false
func _init() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failed=true;push_error("BOTANICAL RENDERING: "+why)
func check_cutout_order(optimizer,eye: Vector3) -> void:
    for record in optimizer.records:
        if not record.cutout:continue
        var expected={}
        for cluster in record.clusters:
            if not cluster.visible:continue
            for index in cluster.indices:
                var key=record.original.slice(index*record.stride,(index+1)*record.stride).to_byte_array().hex_encode()
                expected[key]=expected.get(key,0)+1
        var visible=record.multi.visible_instance_count;var buffer=record.multi.buffer
        var previous=-1
        for i in range(visible):
            var offset=i*record.stride
            var key=buffer.slice(offset,offset+record.stride).to_byte_array().hex_encode()
            check(expected.get(key,0)>0,"foliage sort invented or duplicated a transform")
            expected[key]=expected.get(key,0)-1
            var position_=Vector3(buffer[offset+3],buffer[offset+7],buffer[offset+11])
            var bin_=int(eye.distance_squared_to(position_)*16.0)
            check(bin_>=previous,"foliage did not render near to far")
            previous=bin_
        for count in expected.values():check(count==0,"foliage sort dropped visible foliage")
func check_foliage(world,optimizer) -> void:
    var atlas_image=world.ATLAS.get_image()
    if atlas_image.is_compressed():check(atlas_image.decompress()==OK,"could not decode imported alpha")
    atlas_image.convert(Image.FORMAT_RGBA8)
    var mask=world.mats.leaves.get_shader_parameter("alpha_mask")
    check(mask==optimizer.alpha_mask(world.ATLAS),"alpha mask was not cached")
    check(mask==world.mats.canopy.get_shader_parameter("alpha_mask"),"canopy duplicated its coverage texture")
    var decoded=mask.get_image()
    check(decoded.get_format()==Image.FORMAT_R8 and decoded.get_size()==atlas_image.get_size() and decoded.get_mipmap_count()==atlas_image.get_mipmap_count(),"mask changed format, dimensions or existing mip chain")
    var colors=atlas_image.get_data();var alpha=decoded.get_data();var exact=colors.size()==alpha.size()*4
    for i in range(alpha.size()):
        if alpha[i]!=colors[i*4+3]:exact=false;break
    check(exact,"mask changed decoded alpha at some mip level")
    var sources={};var shadows={};var recorded={}
    check(world.mats.canopy.render_priority<world.mats.glass.render_priority,"binary canopy must draw before translucent glass")
    for node in world.get_children():
        if not node is MultiMeshInstance3D:continue
        if node.get_meta("foliage_shadow_proxy",false):
            check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"canopy proxy became visible geometry")
            check(not shadows.has(node.multimesh),"canopy casts duplicate masked shadows")
            shadows[node.multimesh]=node
        elif node.get_meta("foliage_casts_shadow",false):sources[node.multimesh]=node
    check(sources.size()>0 and sources.size()==shadows.size(),"canopy lost its independent sun shadows")
    for multi in sources:
        check(shadows.has(multi),"canopy shadow does not share the exact instance data")
        var source=sources[multi];var shadow=shadows[multi]
        check(source.visibility_range_end==shadow.visibility_range_end and source.visibility_range_end_margin==shadow.visibility_range_end_margin,"canopy shadow distance/hysteresis differs")
    for record in optimizer.records:
        check(not recorded.has(record.multi),"shared canopy instance data is culled/uploaded twice")
        recorded[record.multi]=true
        if sources.has(record.multi):check(record.cutout and record.shadow,"canopy culling lost offscreen shadow casters")
    for cell in range(6):
        var original=world._leaf_mesh(cell).surface_get_arrays(0)
        var current=world.meshes["leaf%d"%cell].surface_get_arrays(0)
        var order=[0,1,2,3,4,5,0,2,1,3,5,4]
        for attribute in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]:
            check(current[attribute].size()==12,"foliage lost one side of the original card")
            for i in range(12):check(current[attribute][i]==original[attribute][order[i]],"foliage changed authored positions, normals or atlas coordinates")
func check_canopy_range(optimizer,eye: Vector3) -> void:
    for record in optimizer.records:
        if record.canopy==null:continue
        var distance=eye.distance_to(eye.clamp(record.canopy_bounds.position,record.canopy_bounds.end))
        if distance<optimizer.CANOPY_AO_ENTER:check(record.canopy_ao and record.canopy.material_override==optimizer.foliage_opaque,"near canopy lost original contact shading")
        elif distance>optimizer.CANOPY_AO_EXIT:check(not record.canopy_ao and record.canopy.material_override==optimizer.foliage_far,"far-only canopy still enters the normal prepass")
func run() -> void:
    check(DisplayServer.get_name()!="headless","native renderer required for real MultiMesh buffers")
    root.get_node("GameState").start_new_run();root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    game.set_physics_process(false);game.player.set_physics_process(false)
    for guard in game.guards:guard.set_physics_process(false)
    var optimizer=game.world.rendering_optimizer
    check_foliage(game.world,optimizer)
    var original_count=0;var visible_min=2147483647;var times=[]
    for record in optimizer.records:
        original_count+=record.multi.instance_count
        check(record.multi.custom_aabb.size.length()>0,"batch lost original distance/culling bounds")
    # Exercise changing views at walking/turning cadence, then restore every
    # authored transform exactly. Frozen cameras must not upload again.
    for i in range(90):
        game.player.position=Vector3(-22+i*.2,3.65,22-i*.25)
        game.player.camera.look_at(Vector3(sin(i*.05)*25,7,-35))
        optimizer.update(game.player.camera);times.append(optimizer.last_update_usec)
        check_canopy_range(optimizer,game.player.camera.global_position)
        if i==0:check_cutout_order(optimizer,game.player.camera.global_position)
        var count=0
        for record in optimizer.records:count+=record.multi.instance_count if record.multi.visible_instance_count<0 else record.multi.visible_instance_count
        visible_min=mini(visible_min,count)
    check(visible_min<original_count*.8,"moving views never rejected offscreen instances")
    var uploads=optimizer.upload_count
    optimizer.update(game.player.camera);optimizer.update(game.player.camera)
    check(optimizer.upload_count==uploads,"static camera reuploaded instance buffers")
    game.player.position=Vector3(300,100,300);optimizer.update(game.player.camera);check_canopy_range(optimizer,game.player.camera.global_position)
    optimizer.set_enabled(false)
    for record in optimizer.records:
        check(record.multi.buffer==record.original and record.multi.visible_instance_count==-1,"visibility culling discarded authored transforms")
    # The full-detail resource retains the original sphere's geometry. LODs
    # remove subpixel work at distance, not any near-camera model detail.
    for kind in ["petal","specimen"]:
        var source=SphereMesh.new();source.radius=.18;source.height=.65 if kind=="petal" else .4
        var baked=load("res://assets/level1/botanical/meshes/"+kind+".res")
        check(source.get_mesh_arrays()[Mesh.ARRAY_VERTEX]==baked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"baked "+kind+" changed full-detail positions")
        check(baked.shadow_mesh!=null,"baked "+kind+" lacks optimized depth geometry")
    # FPS uses wall time, so Godot's capped simulation delta cannot report a
    # slideshow as ten FPS. Pause/resume gaps are excluded from active frames.
    game.hud.sampled_playing=true;game.hud.last_tick=Time.get_ticks_usec()-500000;game.hud.frame_times.clear();game.hud.sample_seconds=0
    game.hud._process(1.0/60);check(game.hud.sample_seconds>=.5,"FPS used simulation time instead of wall time")
    root.get_node("PauseManager").set_paused(true);game.hud._process(0)
    var sample_before=game.hud.sample_seconds;game.hud.last_tick=Time.get_ticks_usec()-3000000;root.get_node("PauseManager").resume();game.hud._process(0)
    check(is_equal_approx(game.hud.sample_seconds,sample_before),"paused time contaminated active FPS")
    times.sort();print("BOTANICAL CULL: ",optimizer.records.size()," batches / ",original_count," instances; moving-view median ",times[times.size()/2]," us; minimum visible ",visible_min)
    game.queue_free();current_scene=null
    for i in range(5):await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if not failed:print("BOTANICAL RENDERING: PASS — moving views, full buffer restoration, original near detail and real-time FPS")
    quit(1 if failed else 0)
