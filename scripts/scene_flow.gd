extends Node
# Autoload singleton. Owns scene navigation.
#
# complete_level(level_id) — campaign router: marks completed and routes to next.
# next_level() — advances from current campaign scene.
# go_to(level_id) — low-level arbitrary navigator; never marks completion.
#
# Contract:
# SceneFlow decides WHERE we go; GameState remembers WHAT happened.
# Directors emit level_completed facts; they do not call change_scene directly.
# Every transition resumes PauseManager. Direct dev launch remains allowed.

const SCENES := {
    &"level1": "res://game.tscn",
    &"level2": "res://scenes/level2.tscn",
    &"level3": "res://scenes/level3_store.tscn",
    &"menu": "res://menu.tscn",
    &"intro": "res://intro_cutscene.tscn",
    &"park_escape": "res://scenes/park_escape_cutscene.tscn",
    &"ending": "res://scenes/ending_cutscene.tscn",
}
const CAMPAIGN := [&"level1", &"level2", &"level3", &"ending", &"menu"]
const LoadingScreen = preload("res://scripts/context_loading151.gd")

var _transitioning := false
var _signal_bus: Node = null
var _clear_garden_checkpoint_on_arrival := false
var loading_screen: CanvasLayer
var _generation := 0
var _target_id: StringName
var _departing: WeakRef
var _departing_process_mode := Node.PROCESS_MODE_INHERIT
var _muted_inputs: Array[Dictionary] = []
var transition_log: Array[Dictionary] = []
var _loading_world_viewport: Viewport
var _loading_world_was_disabled := false

func is_loading_gameplay() -> bool:
    # Navigation building and viewport warm-up must continue behind the artwork;
    # actor movement, encounter clocks and attacks must wait for the player.
    return _transitioning and _target_id in [&"level1", &"level2", &"level3"]

func _ready() -> void:
    _signal_bus = get_node_or_null("/root/SignalBus")
    if _signal_bus != null and not _signal_bus.is_connected(&"level_completed", Callable(self, "_on_level_completed")):
        _signal_bus.connect(&"level_completed", Callable(self, "_on_level_completed"))
    call_deferred("_sync_current_scene")

func _exit_tree() -> void:
    _restore_loading_world()
    if _signal_bus != null:
        var callback := Callable(self, "_on_level_completed")
        if _signal_bus.is_connected(&"level_completed", callback):
            _signal_bus.disconnect(&"level_completed", callback)

func _sync_current_scene() -> void:
    var current := get_tree().current_scene
    if current == null:
        return
    for level_id in SCENES.keys():
        if SCENES[level_id] == current.scene_file_path:
            GameState.current_level = level_id
            return

func _on_level_completed(level_id: StringName) -> void:
    complete_level(level_id)

func complete_level(level_id: StringName) -> void:
    if _transitioning:
        return
    # A delayed duplicate boarding fact must not restart the interstitial or
    # pull the player back out of the pursuit. Explicit Level1 replay still works.
    if level_id in [&"level1", &"level2", &"level3"] and GameState.is_completed(level_id) and GameState.current_level != level_id:
        return
    if not CAMPAIGN.has(level_id):
        push_error("[SceneFlow] Cannot complete unknown campaign level: %s" % level_id)
        return
    GameState.mark_completed(level_id)
    var next_id := _next_after(level_id)
    if next_id == &"":
        push_warning("[SceneFlow] No next campaign level after %s; staying." % level_id)
        return
    go_to(next_id)

func next_level() -> void:
    if GameState.current_level == &"":
        go_to(CAMPAIGN[0])
        return
    var next_id := _next_after(GameState.current_level)
    if next_id != &"":
        go_to(next_id)

func restart_current() -> void:
    if GameState.current_level != &"":
        go_to(GameState.current_level)

func go_to(level_id: StringName) -> void:
    if _transitioning:
        return
    var path: String = SCENES.get(level_id, "") as String
    if path == "":
        push_error("[SceneFlow] Unknown level id: %s" % level_id)
        return
    _transitioning = true
    _generation += 1
    _target_id = level_id
    _clear_garden_checkpoint_on_arrival = level_id == &"level2" and GameState.current_level == &"park_escape" and GameState.is_completed(&"level1")
    if has_node("/root/PauseManager"):
        PauseManager.resume()
    var current := get_tree().current_scene
    if current != null:
        _departing = weakref(current)
        _departing_process_mode = current.process_mode
        current.process_mode = Node.PROCESS_MODE_DISABLED
    if level_id in [&"level1", &"level2", &"level3"]:
        _ensure_loading_screen()
        loading_screen.present(level_id, loading_context(level_id))
    if level_id == &"level1":
        # The garden's physics route graph can build while only the opaque
        # artwork is drawn. Rendering its hidden forest on every bootstrap
        # frame wastes GPU time and delays navigation on slower devices.
        _loading_world_viewport = get_tree().root
        _loading_world_was_disabled = _loading_world_viewport.disable_3d
        _loading_world_viewport.disable_3d = true
    GameState.current_level = level_id
    var scene_tree := get_tree()
    var rearm_callback := Callable(self, "_rearm")
    if not scene_tree.is_connected(&"scene_changed", rearm_callback):
        scene_tree.scene_changed.connect(rearm_callback, CONNECT_ONE_SHOT)

    # Facts may originate in an Area3D body_entered callback. Leave the physics
    # flush before replacing a scene containing collision objects.
    call_deferred("_change_scene", path)

func _change_scene(path: String) -> void:
    var generation := _generation
    var scene_tree := get_tree()
    # Present artwork before expensive resource loading or synchronous _ready
    # construction. The old scene is still intact behind this first frame.
    await _loading_frame()
    if generation != _generation: return
    var err := ResourceLoader.load_threaded_request(path, "PackedScene", true)
    if err != OK:
        _loading_failed(path, "resource request", err)
        return
    var started := Time.get_ticks_msec()
    while generation == _generation:
        var progress: Array = []
        var status := ResourceLoader.load_threaded_get_status(path, progress)
        if status == ResourceLoader.THREAD_LOAD_LOADED: break
        if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS or Time.get_ticks_msec() - started > 30000:
            _loading_failed(path, "resource loading", status)
            return
        if is_instance_valid(loading_screen) and loading_screen.active and not progress.is_empty():
            loading_screen.set_progress(float(progress[0]) * .90)
        await _loading_frame()
    if generation != _generation: return
    var packed := ResourceLoader.load_threaded_get(path) as PackedScene
    if packed == null:
        _loading_failed(path, "packed scene", ERR_CANT_OPEN)
        return
    err = scene_tree.change_scene_to_packed(packed)
    if err != OK: _loading_failed(path, "scene change", err)

func _rearm() -> void:
    var generation := _generation
    _sync_current_scene()
    var current := get_tree().current_scene
    if current == null: return
    _mute_scene_inputs(current)
    var started := Time.get_ticks_msec()
    while not _scene_ready(current):
        if generation != _generation: return
        if Time.get_ticks_msec() - started > 30000:
            _loading_failed(current.scene_file_path, "scene startup", ERR_TIMEOUT)
            return
        if is_instance_valid(loading_screen) and loading_screen.active: loading_screen.set_progress(.96)
        await _loading_frame()
    if generation != _generation: return
    # Also warm the arriving viewport while the artwork still covers it.
    _restore_loading_world()
    GraphicsSettings.apply_root_viewport()
    await _loading_frame()
    if generation != _generation: return
    transition_log.append({"target":String(_target_id), "scene":current.scene_file_path, "ready":true, "context":loading_screen.context.duplicate(true) if is_instance_valid(loading_screen) and loading_screen.active else {}})
    if is_instance_valid(loading_screen) and loading_screen.active: await loading_screen.dismiss()
    if generation != _generation: return
    _restore_scene_inputs()
    # Keep the completed garden checkpoint through the film, including an app
    # kill/background interruption. Retire it only after Level2 really arrives.
    if _clear_garden_checkpoint_on_arrival and GameState.current_level == &"level2":
        preload("res://scripts/botanical_state.gd").clear()
    _clear_garden_checkpoint_on_arrival = false
    _transitioning = false
    _departing = null

func _ensure_loading_screen() -> void:
    if is_instance_valid(loading_screen): return
    loading_screen = LoadingScreen.new()
    loading_screen.name = "ContextLoading151"
    add_child(loading_screen)
    loading_screen.retry_requested.connect(_retry_loading)
    loading_screen.menu_requested.connect(_loading_menu)

func _loading_frame() -> void:
    await get_tree().process_frame
    if DisplayServer.get_name() != "headless":
        call_deferred("_force_loading_draw")
        await RenderingServer.frame_post_draw

func _force_loading_draw() -> void:
    RenderingServer.force_draw(true)

func _restore_loading_world() -> void:
    if is_instance_valid(_loading_world_viewport):
        _loading_world_viewport.disable_3d = _loading_world_was_disabled
    _loading_world_viewport = null

func _scene_ready(scene: Node) -> bool:
    for property in scene.get_property_list():
        if property.name == "ready_for_play" and not bool(scene.get("ready_for_play")): return false
        if property.name == "ready_for_playback" and not bool(scene.get("ready_for_playback")): return false
    var navigation: Node = scene.get_node_or_null("GuardNavigation")
    if navigation != null and not bool(navigation.get("is_ready")): return false
    return true

func _mute_scene_inputs(scene: Node) -> void:
    var nodes: Array[Node] = [scene]
    nodes.append_array(scene.find_children("*", "Node", true, false))
    for node in nodes:
        var direct := node.is_processing_input()
        var unhandled := node.is_processing_unhandled_input()
        if direct or unhandled:
            _muted_inputs.append({"node":weakref(node), "direct":direct, "unhandled":unhandled})
            node.set_process_input(false)
            node.set_process_unhandled_input(false)

func _restore_scene_inputs() -> void:
    for entry in _muted_inputs:
        var node: Node = entry.node.get_ref()
        if node != null:
            node.set_process_input(entry.direct)
            node.set_process_unhandled_input(entry.unhandled)
    _muted_inputs.clear()

func _loading_failed(path: String, stage: String, code: int) -> void:
    _restore_loading_world()
    GraphicsSettings.apply_root_viewport()
    push_error("[SceneFlow] %s failed for %s (%d)" % [stage, path, code])
    _ensure_loading_screen()
    if not loading_screen.active: loading_screen.present(_target_id, loading_context(_target_id))
    loading_screen.show_failure()
    var current := get_tree().current_scene
    if current != null: current.process_mode = Node.PROCESS_MODE_DISABLED
    var callback := Callable(self, "_rearm")
    if get_tree().scene_changed.is_connected(callback): get_tree().scene_changed.disconnect(callback)
    _clear_garden_checkpoint_on_arrival = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _prepare_retry() -> void:
    _restore_loading_world()
    if _departing != null:
        var old: Node = _departing.get_ref()
        if old != null: old.process_mode = _departing_process_mode
    _restore_scene_inputs()
    _transitioning = false

func _retry_loading() -> void:
    _prepare_retry()
    go_to(_target_id)

func _loading_menu() -> void:
    _prepare_retry()
    go_to(&"menu")

func loading_context(level_id: StringName) -> Dictionary:
    if level_id == &"level2":
        return {"chapter":"02 / ЛЕСНАЯ ПОГОНЯ", "title":"ВЫРВИСЬ ИЗ ПАРКА", "description":"Шесть жёлудей в рюкзаке. Беличьи патрули уже перекрывают дорогу." if GameState.is_completed(&"level1") else "240 на ходу. Не дай патрулям зажать машину между заграждениями."}
    if level_id == &"level3":
        return {"chapter":"03 / НОЧНАЯ СМЕНА", "title":"ПИЦЦА ПОСЛЕ ПОЛУНОЧИ", "description":"Тая добралась до закусочной. Осталось позвать сотрудника и забрать заказ."}
    if level_id == &"level1":
        var saved := preload("res://scripts/botanical_state.gd").new()
        saved.load_save()
        var result := {"chapter":"01 / БОТАНИЧЕСКИЙ САД", "title":"НОЧНОЙ САД", "description":"Дарине нужны жёлуди для поделки. Зимний запас белки хранят в оранжерее."}
        if saved.reward:
            result.title = "ПРОРЫВ К МАШИНЕ"
            result.description = "Шесть жёлудей уже в рюкзаке. Последний дозор отрезает путь к выезду."
        elif saved.guardian:
            result.title = "ЗАПАС В ОРАНЖЕРЕЕ"
            result.description = "Страж повержен. Забери шесть жёлудей для Дарины и возвращайся к 240."
        elif saved.guardian_started:
            result.title = "СТРАЖ ОРАНЖЕРЕИ"
            result.description = "Путь к запасу открыт. Уйди с линии выпада и ответь, пока страж переводит дух."
        elif saved.encounters_completed.has("gallery"):
            result.title = "КЛЮЧ ОТ ОРАНЖЕРЕИ"
            result.description = "Ключ найден в галерее. Открой вход рычагом перед воротами."
        elif saved.installed:
            result.title = "НАСОСНАЯ ОЖИЛА"
            result.description = "Вода вернулась в сад. Через центральную лестницу — к западной галерее."
        elif saved.encounters_completed.has("entry"):
            result.title = "НАСОСНАЯ У ПРУДА"
            result.description = "Входной дозор позади. Найди предохранитель и запусти насос."
        return result
    return {"chapter":"ACORN HUNTER", "title":"ПОСЛЕ ПОЛУНОЧИ", "description":"Ночь ещё не закончилась."}

func _next_after(level_id: StringName) -> StringName:
    if level_id == &"level1":
        return &"park_escape"
    if level_id == &"park_escape":
        return &"level2"
    var idx := CAMPAIGN.find(level_id)
    if idx < 0 or idx >= CAMPAIGN.size() - 1:
        return &""
    return CAMPAIGN[idx + 1]
