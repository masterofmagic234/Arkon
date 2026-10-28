extends SceneTree
## Geometry/contact contract plus actual movement/recoil native presentation.
const Weapon = preload("res://scripts/botanical_conegun.gd")
var failures: Array[String] = []
var visual := false
var raw := false
var candidate_path := "res://assets/level1/weapons/cedar/cedar_runtime.glb"
var output := "user://cedar-weapon"
var game: Node3D
var weapon: Node3D
var report: Dictionary = {}
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--visual": visual = true
        elif arg == "--raw-authoring": raw = true
        elif arg.begins_with("--candidate="): raw = true; candidate_path = arg.trim_prefix("--candidate=")
        elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")
func check(ok: bool, why: String) -> void:
    if not ok:
        failures.append(why)
        push_error("MODERN CONEGUN: " + why)
func settle(count: int = 4) -> void:
    for i in range(count): await physics_frame
func draw(count: int = 2) -> void:
    for i in range(count):
        await process_frame
        RenderingServer.force_draw(true)
func replace_with_raw_authoring() -> void:
    # Diagnostic only. CI/native acceptance uses the actual imported PackedScene.
    var state := GLTFState.new()
    var importer := GLTFDocument.new()
    var error := importer.append_from_file(candidate_path, state)
    check(error == OK, "raw authoring GLB could not be loaded")
    weapon.model.free()
    weapon.model = importer.generate_scene(state)
    weapon.model.name = "CedarModel"
    weapon.model.scale = Vector3.ONE * Weapon.MODEL_SCALE
    weapon.add_child(weapon.model)
    for node in weapon.model.find_children("*", "MeshInstance3D", true, false):
        node.layers = Weapon.VIEW_LAYER
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    weapon.muzzle = weapon.model.find_child("MuzzleSocket", true, false)
    weapon.support_palm = weapon.model.find_child("SupportPalmSocket", true, false)
func find_parent(parents: Array[int], value: int) -> int:
    var current := value
    while parents[current] != current:
        parents[current] = parents[parents[current]]
        current = parents[current]
    return current
func rounded_foregrip_distance(point: Vector3) -> float:
    var q := (point - Vector3(0, -.031, -.257)).abs() - (Vector3(.066, .057, .235) * .5 - Vector3.ONE * .012)
    return q.max(Vector3.ZERO).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0) - .012
func check_model() -> void:
    var metrics: Dictionary = weapon.mesh_metrics()
    report.metrics = metrics
    check(metrics.meshes == 3 and metrics.surfaces == 3, "weapon stopped using three bounded opaque batches")
    check(metrics.triangles >= 8000 and metrics.triangles <= 18000, "weapon/hand finite triangle budget changed")
    var hand := weapon.model.find_child("FemaleSupportHand", true, false) as MeshInstance3D
    var sleeve := weapon.model.find_child("HoodieSleeve", true, false) as MeshInstance3D
    var gun := weapon.model.find_child("CedarGunAssembly", true, false) as MeshInstance3D
    check(hand != null and sleeve != null and gun != null, "named gun/continuous hand/sleeve geometry missing")
    if hand == null or sleeve == null or gun == null: return
    check(hand.get_aabb().size.length() > .35 and hand.get_aabb().size.length() < .90, "female hand/forearm proportions are not human scale")
    check(gun.get_aabb().size.z * Weapon.MODEL_SCALE < .85, "carbine is oversized")
    check(weapon.muzzle != null and weapon.support_palm != null, "actual muzzle/support sockets missing")
    var muzzle_local: Vector3 = weapon.model.to_local(weapon.muzzle.global_position)
    check(muzzle_local.distance_to(Vector3(0, .033, -.651)) < .001, "muzzle socket no longer matches the hollow bore")
    var arrays: Array = hand.mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    var relative: Transform3D = weapon.model.global_transform.affine_inverse() * hand.global_transform
    var weld: Dictionary = {}
    var vertex_ids: Array[int] = []
    var parents: Array[int] = []
    var contact_count := 0
    var deepest := 0.0
    var deep_samples: Array[Dictionary] = []
    for vertex in vertices:
        var point := relative * vertex
        check(point.is_finite(), "non-finite hand skin vertex")
        var key := Vector3i((point * 100000).round())
        if not weld.has(key):
            weld[key] = parents.size()
            parents.append(parents.size())
        vertex_ids.append(int(weld[key]))
        if point.z > -.29 and point.z < -.17 and point.x > -.07 and point.x < .07:
            var distance := rounded_foregrip_distance(point)
            if absf(distance) < .0035: contact_count += 1
            deepest = minf(deepest, distance)
            if distance < -.004: deep_samples.append({"position":[point.x,point.y,point.z],"depth_m":distance})
    for offset in range(0, indices.size(), 3):
        var a := find_parent(parents, vertex_ids[indices[offset]])
        for j in [1, 2]:
            var b := find_parent(parents, vertex_ids[indices[offset + j]])
            parents[b] = a
    var components: Dictionary = {}
    for i in range(parents.size()):
        var key := find_parent(parents, i)
        components[key] = int(components.get(key, 0)) + 1
    var sizes: Array = components.values()
    sizes.sort()
    sizes.reverse()
    report.hand_components = sizes
    report.foregrip_contact_vertices = contact_count
    report.deepest_skin_contact_m = deepest
    deep_samples.sort_custom(func(a,b): return a.depth_m < b.depth_m)
    report.deep_contact_samples = deep_samples.slice(0, mini(8, deep_samples.size()))
    check(int(sizes[0]) > 2000 and (sizes.size() == 1 or (sizes.size() == 6 and int(sizes[1]) <= 64)), "wrist, palm or fingers detached; expected continuous anatomical skin (integrated nails or five small nail pieces)")
    check(contact_count >= 12, "supporting hand floats away from the foregrip")
    check(deepest >= -.004, "skin penetrates the foregrip beyond soft contact")
    for node in [hand, sleeve, gun]:
        check(node.layers == Weapon.VIEW_LAYER and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "first-person model leaks into world/shadow passes")
    var material: Material = gun.mesh.surface_get_material(0)
    check(material is StandardMaterial3D and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "opaque PBR atlas material missing")
    if material is StandardMaterial3D:
        check(material.albedo_texture != null and material.metallic_texture != null and material.roughness_texture != null, "three finishes were flattened into an untextured single material")
func save_frame(name_: String, count: int = 3) -> void:
    if not visual: return
    await draw(count)
    root.get_texture().get_image().save_png(output.path_join(name_ + ".png"))
func run() -> void:
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").music_muted = true
    root.get_node("GameState").sfx_muted = true
    if visual:
        check(DisplayServer.get_name() != "headless", "native visual mode needs a real framebuffer")
        root.size = Vector2i(1280, 720)
        root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
        DirAccess.make_dir_recursive_absolute(output)
        RenderingServer.set_render_loop_enabled(false)
    game = load("res://game.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await settle(16)
    weapon = game.weapon
    if raw: replace_with_raw_authoring()
    for guard in game.guards: guard.set_physics_process(false)
    check_model()
    if visual:
        game.hud.set_mobile_preview(true)
        game.world.set_meta("force_mobile_profile", true)
        for size_ in [Vector2i(1280, 720), Vector2i(2582, 1220)]:
            root.size = size_
            game.world._mobile_profile()
            await save_frame("entry-%dx%d" % [size_.x, size_.y])
        root.size = Vector2i(1280, 720)
        game.world._mobile_profile()
    var start: Vector3 = game.player.global_position
    var low := INF
    var high := -INF
    Input.action_press("l1_move_forward")
    for i in range(24):
        await physics_frame
        low = minf(low, weapon.position.y)
        high = maxf(high, weapon.position.y)
    Input.action_release("l1_move_forward")
    check(game.player.global_position.distance_to(start) > .6, "actual forward movement did not exercise the support hand")
    check(high - low > .003, "walk did not produce the authored held-weapon bob")
    await save_frame("walking")
    var before: int = game.player.ammo
    game.player.request_fire()
    await settle(3)
    check(game.player.ammo == before - 1 and game.player.recoil_time > 0, "real player fire did not drive recoil")
    check(weapon.rotation.x > .02, "muzzle recoil must rise with the supporting arm, not dip")
    report.recoil = weapon.rotation.x
    await save_frame("shot-recoil", 1)
    if visual:
        var camera: Camera3D = game.player.camera
        var projected: Vector2 = camera.unproject_position(weapon.muzzle.global_position)
        report.projected_muzzle = [projected.x, projected.y]
        check(projected.y > root.size.y * .5 and projected.y < root.size.y * .94, "weapon blocks the central sight line or drops out of frame")
    report.movement_m = game.player.global_position.distance_to(start)
    report.bob_range_m = high - low
    report.raw_authoring_diagnostic = raw
    report.failures = failures
    DirAccess.make_dir_recursive_absolute(output)
    FileAccess.open(output.path_join("weapon-report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    print("MODERN CONEGUN GEOMETRY: ", report)
    game.queue_free()
    current_scene = null
    await settle(6)
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if visual: RenderingServer.set_render_loop_enabled(true)
    if failures.is_empty(): print("MODERN CONEGUN: PASS — compact opaque CEDAR, connected female support hand, real foregrip contact, walking and recoil")
    quit(0 if failures.is_empty() else 1)
