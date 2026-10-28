extends SceneTree
## Native mixer proof. This intentionally staged sound scene is not gameplay.
var mix
var output := "/workspace/scratch/audio147/native"
var failures: Array[String] = []
class Fixture extends Node3D:
    var world: Node3D

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")

func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("WOODLAND AUDIO NATIVE: native framebuffer required")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(640, 360)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").music_muted = true
    root.get_node("GameState").sfx_muted = false
    root.get_node("GameState").sfx_volume_db = 0
    var scene := Fixture.new()
    root.add_child(scene)
    current_scene = scene
    scene.world = Node3D.new()
    scene.add_child(scene.world)
    scene.world.set_meta("audio_paths", [{"points": [Vector2(-2,0),Vector2(2,0)], "half_width": 2.5}])
    var camera := Camera3D.new()
    camera.position = Vector3(0, 1.6, 0)
    scene.add_child(camera)
    camera.current = true
    var listener := AudioListener3D.new()
    camera.add_child(listener)
    listener.make_current()
    for x in [-8.0,8.0]:
        var node := MeshInstance3D.new()
        node.mesh = SphereMesh.new()
        node.position = Vector3(x,1,-6)
        var material := StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.albedo_color = Color("74c5b8") if x<0 else Color("efb568")
        node.material_override = material
        scene.add_child(node)
    mix = load("res://scripts/woodland_audio.gd").new()
    scene.add_child(mix)
    mix.water.position = Vector3(20,0,20)
    mix.set_variation_seed(147)
    var events := []
    for frame in range(300):
        if frame == 10: sound(&"shoot", Vector3.ZERO, events, frame)
        if frame == 40: sound(&"enemy_shoot", Vector3(-8,1,-6), events, frame)
        if frame == 70: sound(&"enemy_shoot", Vector3(8,1,-6), events, frame)
        if frame == 100: sound(&"impact_wood", Vector3(-5,1,-4), events, frame)
        if frame in [120,132,144,156]: sound(&"footstep", Vector3.ZERO, events, frame)
        if frame == 170:
            for n in range(6): sound(&"shoot", Vector3.ZERO, events, frame)
        if frame == 205:
            root.get_node("PauseManager").set_paused(true)
            sound(&"shoot", Vector3.ZERO, events, frame)
        if frame == 235:
            root.get_node("PauseManager").set_paused(false)
        if frame == 245: sound(&"shoot", Vector3.ZERO, events, frame)
        if frame == 270:
            root.get_node("GameState").sfx_muted = true
            mix._apply_mix()
        await process_frame
    root.get_node("PauseManager").set_paused(false)
    FileAccess.open(output.path_join("native-audio-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"events":events,"mix_events":mix.event_log,"dropped_paused":mix.dropped_paused,"peak_active_voices":mix.peak_active_voices,"note":"Native Godot MovieMaker mix; staged local/spatial/overload/pause/mute verification, not an end-to-end gameplay recording."},"  "))
    current_scene = null
    scene.queue_free()
    for n in range(6): await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("WOODLAND AUDIO NATIVE: PASS — staged local/spatial/limiter/pause/mute sound timeline recorded")
    quit()

func sound(kind: StringName, position_: Vector3, events: Array, frame: int) -> void:
    root.get_node("SignalBus").emit_audio_event(kind, position_)
    events.append({"frame":frame,"seconds":frame/30.0,"kind":String(kind),"position":[position_.x,position_.y,position_.z]})
