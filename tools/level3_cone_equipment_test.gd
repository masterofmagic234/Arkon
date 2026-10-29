extends SceneTree
## Actual input -> weapon data -> visible projectile/puff/foley and floor art.
## This is an equipment fixture, not a complete mission replay.
const Teardown=preload("res://tools/level3_test_teardown.gd")
const AssaultFixture=preload("res://tools/level3_assault_fixture.gd")
const PARTS="res://assets/level3/carolina147/"
var game: Level3Store
var failures: Array[String]=[]
var visual:=false
var output:=""
var report: Array=[]

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")

func check(value: bool,message: String) -> void:
    if not value:
        failures.append(message)
        push_error("LEVEL3 CONE EQUIPMENT: "+message)

func tick(count:=1) -> void:
    for frame in range(count):await physics_frame

func active_projectiles() -> Array:
    return game._projectile_pool._active.duplicate()

func fire_once(weapon: StringName) -> void:
    game._projectile_pool.release_all()
    await tick(45)
    game.player.equip_weapon(weapon,12)
    var ammo_before: int=game.player.ammo
    game._on_aim_joystick_changed(Vector2.RIGHT)
    game._on_fire_button_down()
    await tick(4)
    game._on_fire_button_up()
    var bullets:=active_projectiles()
    var wanted:=5 if weapon==&"shotgun" else 1
    check(game.player.ammo==ammo_before-1,"actual fire did not consume one "+String(weapon)+" round")
    check(bullets.size()==wanted,"wrong actual cone volley count for "+String(weapon))
    for bullet in bullets:
        check(bullet._visual_path==PARTS+"cone_projectile.png","weapon data did not reach the live projectile visual")
        var sprite: AnimatedSprite2D=bullet._visual
        var texture_: Texture2D=sprite.sprite_frames.get_frame_texture(&"default",0)
        check(texture_.get_size()==Vector2(6,4),"live projectile still has the old bullet artwork")
    var puffs:=0
    for slot in game.effects._slots:
        if float(slot.life)<=0:continue
        if slot.kind==&"cone_muzzle":puffs+=1
        check(slot.kind!=&"muzzle","player cone weapon produced an ordinary gun flash")
    check(puffs==1,"one shot must produce one compact pneumatic puff")
    check(game.effects._cone_muzzle.get_frame_count(&"default")==3,"air puff lost its three painted frames")
    var stream_paths: Array[String]=[]
    var family: String="scatter_" if weapon==&"shotgun" else "compact_"
    for voice in game.audio._pool:
        if voice.stream!=null and family in voice.stream.resource_path:stream_paths.append(voice.stream.resource_path)
    check(not stream_paths.is_empty(),"actual themed weapon did not use its new Foley family")
    report.append({"weapon":weapon,"projectiles":bullets.size(),"puffs":puffs,"foley":stream_paths})
    if visual:
        for bullet in bullets:bullet.set_physics_process(false)
        game.hud.hide()
        game.camera.position_smoothing_enabled=false
        game.camera.global_position=game.player.global_position+Vector2(24,0)
        game.camera.zoom=Vector2.ONE*4
        await process_frame
        RenderingServer.force_draw(true)
        root.get_texture().get_image().save_png(output.path_join(String(weapon)+"-cone-volley.png"))
        game.hud.show()
        for bullet in bullets:bullet.set_physics_process(true)

func run() -> void:
    check(not visual or DisplayServer.get_name()!="headless","native framebuffer required for visual mode")
    if visual:
        check(not output.is_empty(),"visual output directory missing")
        DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(1280,720)
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=false
    RenderingServer.set_render_loop_enabled(false)
    game=load("res://scenes/level3_store.tscn").instantiate()
    root.add_child(game);current_scene=game
    await tick(8)
    for pickup in game.pickups_root.get_children():
        if pickup.kind not in [&"pistol",&"shotgun"]:continue
        var path: String=PARTS+("cone_pistol.png" if pickup.kind==&"pistol" else "cone_shotgun.png")
        check(pickup._visual.texture==load(path),"floor pickup retained an ordinary weapon sprite")
    # Equipment is unavailable during the peaceful visit. Prepare the actual
    # arrival/breach first, as every production combat input must do.
    if not await AssaultFixture.prepare(self,game): quit(1);return
    await fire_once(&"pistol")
    await fire_once(&"pistol")
    check(game.audio._shot_variants.get(&"pistol",0)==2,"compact Foley variants did not advance")
    await fire_once(&"shotgun")
    check(game.player.get_weapon_data().display_name=="ШИШКОВИК","themed weapon name is missing")
    if visual:
        FileAccess.open(output.path_join("equipment-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"shots":report,"failures":failures,"scope":"Staged real-input equipment/renderer integration; not a complete playthrough."},"  "))
    game.queue_free();current_scene=null
    await Teardown.drain_audio(self)
    RenderingServer.set_render_loop_enabled(true)
    if failures.is_empty():print("LEVEL3 CONE EQUIPMENT: PASS — actual input, proportional cone volleys, pneumatic puffs, Foley variants and themed floor pickups")
    quit(0 if failures.is_empty() else 1)
