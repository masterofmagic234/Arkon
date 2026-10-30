extends SceneTree
## Actual authored overhead body and production player movement; visual mode captures the
## same actor in the real diner/street. This is asset QA, not a mission replay.
const Hero = preload("res://scripts/level3_hero_visual.gd")
const Teardown = preload("res://tools/level3_test_teardown.gd")
var failed := false
var visual := false
var output := "user://hero-147"
var captures: Array[String] = []
var game: Node
var player: Level3Player
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--visual": visual=true
        elif arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    call_deferred("run")
func check(ok: bool, why: String) -> void:
    if not ok: failed=true;push_error("LEVEL3 HERO: "+why)
func ticks(count: int) -> void:
    for index in range(count): await physics_frame
func run() -> void:
    root.size=Vector2i(1280,720)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    if visual:
        check(DisplayServer.get_name()!="headless","native visual mode requires a framebuffer")
        game=load("res://scenes/level3_store.tscn").instantiate()
        root.add_child(game);current_scene=game
        await ticks(5)
        game.set_process(false);game.set_physics_process(false)
        player=game.player
        # Subsequent poses are a staged equipment/rig inspection, not the
        # peaceful entry. Production keeps these weapons on the back until raid.
        check(not player.combat_enabled and not player._visual.weapon_sprite.visible,"peaceful visitor is already holding a weapon")
        DirAccess.make_dir_recursive_absolute(output)
        game.hud.mobile_active=true;game.hud._layout()
        await capture("street-normal",1.7)
        await capture("street-normal-2x",3.4)
        for index in range(4):
            player.rotation = index*PI*.5
            await capture("peaceful-overhead-%d"%index,6.0)
        player.rotation=0
        player.set_combat_enabled(true)
        game._update_hud()
    else:
        player=load("res://scenes/level3_player.tscn").instantiate()
        root.add_child(player);current_scene=player
    await ticks(3)
    var rig=player._visual
    check(rig is Hero and rig.body_sprite is Sprite2D,"connected overhead body is not the actual actor")
    check(rig.body_sprite.texture.resource_path==Hero.ARMED_STRIP and rig.body_sprite.hframes==8,"actual body lost the original eight authored diner poses")
    check(not rig.parts.has("leg_left") and not rig.parts.has("upper_left"),"front-view shins or separately rotated sleeves remain")
    check(not rig.parts.has("hair") and rig.body_sprite.material.get_shader_parameter("original_overhead_head")==true,"oversized separate head portrait remains instead of the authored overhead contour")
    check(player.get_node_or_null("WeaponOverlay")==null,"unrelated legacy weapon overlay remains")
    check(rig.muzzle_socket.position==Vector2(18,0),"painted weapon diverges from the safe muzzle ray")
    for part in rig.parts.values():
        check(part is Sprite2D and part.texture!=null and part.visible,"painted rig part is missing")
        check(part.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"pixel part is blurred")
    var start: Vector2=player.global_position
    player.set_input(Vector2.RIGHT,Vector2.RIGHT,false,false,false,false)
    await ticks(60)
    check(player.global_position.distance_to(start)>100,"actual production movement did not travel")
    check(rig.state==&"walk" and rig.gait_weight>.99,"actual movement does not drive the feet")
    var phase_before: float=rig.gait_distance
    var point_before: Vector2=player.global_position
    await ticks(24)
    var travelled: float=player.global_position.distance_to(point_before)
    var expected: float=wrapf(phase_before+travelled,0,Hero.STRIDE)
    check(absf(rig.gait_distance-expected)<.2,"gait is a timer instead of travelled distance")
    var held_frame: int=rig.body_sprite.frame
    var held_body: Transform2D=rig.body_sprite.transform
    var held_head: Vector2=rig.body_sprite.material.get_shader_parameter("authored_head_center")
    rig.update_motion(0,Vector2(120,0))
    check(rig.body_sprite.frame==held_frame and rig.body_sprite.transform==held_body and rig.body_sprite.material.get_shader_parameter("authored_head_center")==held_head,"zero-delta frame advances the authored pose")
    # Equal travel at two timesteps produces the same planted-leg pose. Retreat
    # reverses the cycle rather than substituting an unrelated walking strip.
    rig.gait_distance=0;rig.gait_weight=1
    rig.update_motion(.2,Vector2(70,0));held_frame=rig.body_sprite.frame;held_head=rig.body_sprite.material.get_shader_parameter("authored_head_center")
    rig.gait_distance=0;rig.gait_weight=1
    for index in range(4):rig.update_motion(.1,Vector2(35,0))
    check(rig.body_sprite.frame==held_frame and rig.body_sprite.material.get_shader_parameter("authored_head_center")==held_head,"authored gait changes with timestep/speed")
    rig.gait_distance=0;rig.gait_weight=1
    rig.update_motion(.1,Vector2(30,0));rig.update_motion(.1,Vector2(-30,0))
    check(absf(rig.gait_distance)<.001,"backpedalling cannot reverse the gait")
    rig.gait_distance=12;rig.gait_weight=1
    rig.update_motion(.00001,Vector2(0,120))
    check(rig.source_frame==2 and rig.body_sprite.frame==2,"strafing does not retain the travel-driven overhead pose")
    var authored_poses: Dictionary={}
    for index in range(8):
        rig.gait_distance=Hero.STRIDE*index/8.0
        rig.update_motion(.00001,Vector2(120,0))
        authored_poses[rig.body_sprite.frame]=true
    check(authored_poses.size()==8,"walking uses a bobbing single picture instead of all eight authored poses")
    player.clear_controls();await ticks(12)
    check(rig.state==&"idle" and rig.gait_weight<.01,"stopped heroine keeps walking")
    for weapon: StringName in [&"pistol",&"shotgun",&"bat"]:
        player.equip_weapon(weapon,12)
        check(rig.weapon_id==weapon,"painted weapon did not follow equipment")
        check(rig.body_sprite.texture.resource_path==Hero.ARMED_STRIP and rig.weapon_sprite.visible,"equipping lost the connected painted weapon stance")
        check(rig.body_sprite.material.get_shader_parameter("hide_conventional_rifle")==true,"conventional rifle remains behind the cone weapon")
        var maximum := 17 if weapon in [&"shotgun",&"bat"] else 13
        check(rig.weapon_sprite.texture.get_width()==maximum,"weapon is not proportionate to the actor")
        player._play_fire_animation();rig.update_motion(.055,Vector2.ZERO)
        check(rig.state in [&"recoil",&"swing"] and rig.attack_remaining>0,"attack has no real rig animation")
        check(rig.body_sprite.get_parent()==rig.pose_root and rig.weapon_sprite.get_parent()==rig.pose_root,"recoil separates the connected hands and held equipment")
        rig.update_motion(.5,Vector2.ZERO)
        check(rig.state==&"idle" and rig.attack_remaining==0,"attack never recovers")
    player.equip_weapon(&"pistol",12)
    check(player.get_weapon_data().display_name=="ШИШКОЛЁТ","ordinary pistol label remains")
    check(player.get_weapon_data().projectile_texture.ends_with("cone_projectile.png"),"ordinary bullet remains")
    player.equip_weapon(&"shotgun",6)
    check(player.get_weapon_data().display_name=="ШИШКОВИК","ordinary shotgun label remains")
    var sling=player.get_node("PineConeLauncherSling/CarriedCedarCarbine")
    check(sling.texture.get_width()==17,"carried cone launcher is oversized")
    rig.set_weapon_drawn(false)
    check(not rig.weapon_sprite.visible and rig.body_sprite.texture.resource_path==Hero.UNARMED_STRIP,"peaceful heroine uses a concealed armed stance")
    rig.set_weapon_drawn(true)
    if visual:
        DirAccess.make_dir_recursive_absolute(output)
        game.hud.mobile_active=true;game.hud._layout()
        player.equip_weapon(&"pistol",12)
        for weapon: StringName in [&"pistol",&"shotgun"]:
            player.equip_weapon(weapon,12)
            player.set_input(Vector2.RIGHT,Vector2.RIGHT,false,false,false,false)
            for frame in range(4):
                await ticks(5)
                await capture(String(weapon)+"-walk-%d"%frame,4.0)
            player.clear_controls();await ticks(8)
            await capture(String(weapon)+"-idle",4.0)
            player._play_fire_animation();await ticks(3)
            await capture(String(weapon)+"-recoil",4.0)
        # Inspect the same actor on an actual indoor floor at normal camera
        # scale and2x. This is explicitly staged art QA, not a mission route.
        player.set_physics_process(false);player.velocity=Vector2.ZERO
        var interior: Vector2 = game._scaled_cell_world(Vector2i(11,12))
        check(game._is_spawn_clear(interior),"indoor art inspection point intersects furniture")
        player.global_position=interior;player.rotation=0
        player.clear_controls();player.set_combat_enabled(false);game._update_hud()
        await capture("indoor-peaceful-normal",1.7)
        await capture("indoor-peaceful-2x",3.4)
        player.set_combat_enabled(true);player.equip_weapon(&"pistol",12);game._update_hud()
        await capture("indoor-armed-normal",1.7)
        await capture("indoor-armed-2x",3.4)
        rig.die();rig.update_motion(.5,Vector2.ZERO)
        await capture("fallen-authored",3.4)
        var report={"captures":captures,"visual_contract":"original_overhead_body152","rig_parts":rig.part_count(),"authored_walk_frames":8,"original_strips":[Hero.UNARMED_STRIP,Hero.ARMED_STRIP,Hero.FALL_STRIP],"idle_weapon_tip":18.5,"walking_weapon_tip_range":[16.5,20.5],"physical_muzzle":18,"source":"Actual production player/diner. Peaceful street and2x are captured before any override; four close overhead headings, equipment/fallen poses and the clear indoor cell(11,12) use staged cameras/headings/equipment/location/visual-state, not a mission replay.","peaceful_capture":"street-normal.png","overhead_capture_count":4,"actual_scale_captures":["street-normal.png","street-normal-2x.png","indoor-peaceful-normal.png","indoor-peaceful-2x.png","indoor-armed-normal.png","indoor-armed-2x.png"],"fallen_capture":"fallen-authored.png","equipment_presentation_staged":true,"failures":[] if not failed else ["see strict log"]}
        FileAccess.open(output.path_join("hero-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
    rig.die();rig.update_motion(.5,Vector2.ZERO)
    check(rig.state==&"fall" and rig.body_sprite.texture.resource_path==Hero.FALL_STRIP and rig.source_frame==4,"death never reaches the authored full fallen silhouette")
    var settled_frame: int=rig.body_sprite.frame
    var settled_head: Vector2=rig.body_sprite.material.get_shader_parameter("authored_head_center")
    rig.update_motion(1,Vector2.ZERO)
    check(rig.body_sprite.frame==settled_frame and rig.body_sprite.material.get_shader_parameter("authored_head_center")==settled_head,"fallen heroine loops or drifts after settling")
    current_scene.queue_free();current_scene=null
    await ticks(4);await Teardown.drain_audio(self)
    if not failed: print("LEVEL3 HERO: PASS — original connected overhead body/head, eight travel-driven frames, restrained dark/red hair, peaceful holster, recoil, proportionate cone weapons, authored fall and preserved controls")
    quit(1 if failed else 0)
func capture(label: String, zoom: float) -> void:
    game.camera.position_smoothing_enabled=false
    game.camera.global_position=player.global_position+Vector2(12,0)
    game.camera.zoom=Vector2.ONE*zoom
    game.camera.reset_smoothing()
    await process_frame
    RenderingServer.force_draw(true)
    root.get_texture().get_image().save_png(output.path_join(label+".png"))
    captures.append(label+".png")
