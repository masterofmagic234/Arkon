extends RefCounted
# Fixed-fps tests advance simulation much faster than the real-time audio
# thread. Release scene nodes first, then drain stop commands before process exit.
static func drain_audio(tree: SceneTree) -> void:
    tree.root.get_node("AudioManager").shutdown()
    await tree.process_frame
    await tree.process_frame
    var deadline := Time.get_ticks_msec()+350
    while Time.get_ticks_msec()<deadline:
        OS.delay_msec(10)
        await tree.process_frame
