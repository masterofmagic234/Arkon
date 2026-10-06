extends Node3D

# ACORN HUNTER — LEVEL 1 director.
# Progression lives here; gameplay state lives in actor scenes.

const LevelData = preload("res://scripts/level_data.gd")
const HudView = preload("res://scripts/hud_view.gd")
const AudioController = preload("res://scripts/audio_controller.gd")
const MissionView = preload("res://scripts/mission_view.gd")
const CombatFeedbackView = preload("res://scripts/combat_feedback_view.gd")
const MessageView = preload("res://scripts/message_view.gd")
const NavigationController = preload("res://scripts/navigation_controller.gd")
const PresentationSync = preload("res://scripts/presentation_sync.gd")
const PlayerView = preload("res://scripts/player_view.gd")
const Level1Player = preload("res://scripts/level1_player.gd")
const Level1Navigation = preload("res://scripts/level1_navigation.gd")

const WALL_TEXTURE_PATHS := [
    "res://wall_zone1.png",
    "res://wall_zone2.png",
    "res://wall_zone3.png",
    "res://wall_zone4.png",
]
const FLOOR_TEXTURE_PATH := "res://assets/grass.png"
const HERO_GRASS_PATH := "res://assets/floor_grass_hero.png"
const HERO_GRASS_SHADER := "res://scripts/hero_grass_fade.gdshader"
# Scene transitions are centralized in SceneFlow autoload; no per-level path const here.

@onready var player: Level1Player = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var joystick: Panel = $HUD/Joystick
@onready var knob: Panel = $HUD/Joystick/Knob
@onready var fire_button: Button = $HUD/Fire
@onready var mute_button: Button = $HUD/Mute
@onready var count_label: Label = $HUD/Count
@onready var hp_ammo_label: Label = $HUD/HPAmmo
@onready var message_label: Label = $HUD/Message
@onready var mission_panel: Panel = $HUD/Mission
@onready var mission_title: Label = $HUD/Mission/Title
@onready var mission_body: Label = $HUD/Mission/Body
@onready var weapon: TextureRect = $HUD/Weapon
@onready var muzzle: ColorRect = $HUD/MuzzleFlash
@onready var hit_marker: Label = $HUD/HitMarker
@onready var carolina: TextureRect = $HUD/Carolina
@onready var music: AudioStreamPlayer = $Music
@onready var fx: AudioStreamPlayer = $FX

var collected := 0
var keys_held := 0
var doors_opened: Array[StringName] = []
var mission_complete := false
var mission_failed := false

var audio_controller: AudioController
var hud_view: HudView
var mission_view: MissionView
var combat_feedback: CombatFeedbackView
var message_view: MessageView
var navigation_controller: NavigationController
var level1_navigation: Level1Navigation
var presentation_sync: PresentationSync
var player_view: PlayerView
var presentation_timer := 0.0
var _signal_bus: Node = null

func _ready() -> void:
    level1_navigation = Level1Navigation.new()
    level1_navigation.name = "Level1Navigation"
    add_child(level1_navigation)
    level1_navigation.setup()

    presentation_sync = PresentationSync.new()
    player_view = PlayerView.new()
    player_view.setup(camera, carolina)
    player_view.apply()


    mission_panel.visible = false
    if not OS.has_feature("mobile"):
        joystick.visible = false
        knob.visible = false
        fire_button.visible = false
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

    muzzle.visible = false
    hit_marker.visible = false

    mute_button.pressed.connect(_toggle_music)

    hud_view = HudView.new()
    hud_view.setup(count_label, hp_ammo_label)

    mission_view = MissionView.new()
    mission_view.setup(mission_panel, mission_title, mission_body, weapon)

    combat_feedback = CombatFeedbackView.new()
    combat_feedback.setup(weapon, muzzle, hit_marker)

    message_view = MessageView.new()
    message_view.setup(message_label)

    _signal_bus = get_node_or_null("/root/SignalBus")
    if _signal_bus != null:
        _signal_bus.connect(&"item_collected", Callable(self, "_on_item_collected"))
        _signal_bus.connect(&"mission_changed", Callable(self, "_on_mission_changed"))
        _signal_bus.connect(&"combat_event", Callable(self, "_on_combat_event"))
        _signal_bus.connect(&"entity_died", Callable(self, "_on_entity_died"))
        _signal_bus.connect(&"object_interacted", Callable(self, "_on_object_interacted"))


    audio_controller = AudioController.new()
    var fx_players: Array[AudioStreamPlayer] = []
    fx_players.append(fx)
    var fx_pool_root := get_node_or_null("FXPool")
    if fx_pool_root != null:
        for child in fx_pool_root.get_children():
            if child is AudioStreamPlayer:
                fx_players.append(child)
    audio_controller.setup(music, fx_players)
    AudioManager.register_music(music)

    navigation_controller = NavigationController.new()
    navigation_controller.setup($HUD/Mission/Menu, get_tree())

    presentation_timer = 0.0
    _update_hud()
    if _signal_bus != null:
        _signal_bus.emit_signal(&"mission_changed", &"level1", &"started")
    _set_message(
        "Операция «ЖЁЛУДЬ»: найди ключи, открой ворота и собери 6 жёлудей.",
        4.0
    )

func _exit_tree() -> void:
    if audio_controller != null:
        audio_controller.teardown()
    if message_view != null:
        message_view.teardown()

    if _signal_bus == null:
        return
    var mission_callback := Callable(self, "_on_mission_changed")
    var item_callback := Callable(self, "_on_item_collected")
    var combat_callback := Callable(self, "_on_combat_event")
    var death_callback := Callable(self, "_on_entity_died")
    var object_callback := Callable(self, "_on_object_interacted")
    if _signal_bus.is_connected(&"mission_changed", mission_callback):
        _signal_bus.disconnect(&"mission_changed", mission_callback)
    if _signal_bus.is_connected(&"item_collected", item_callback):
        _signal_bus.disconnect(&"item_collected", item_callback)
    if _signal_bus.is_connected(&"combat_event", combat_callback):
        _signal_bus.disconnect(&"combat_event", combat_callback)
    if _signal_bus.is_connected(&"entity_died", death_callback):
        _signal_bus.disconnect(&"entity_died", death_callback)
    if _signal_bus.is_connected(&"object_interacted", object_callback):
        _signal_bus.disconnect(&"object_interacted", object_callback)

func _physics_process(delta: float) -> void:
    if combat_feedback != null:
        combat_feedback.update_muzzle(delta)

    presentation_timer -= delta
    if presentation_timer <= 0.0:
        presentation_timer = 0.10
        _update_hud()

func _unhandled_input(event: InputEvent) -> void:
    if OS.has_feature("mobile"):
        return

    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.set_mouse_mode(
            Input.MOUSE_MODE_VISIBLE
            if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
            else Input.MOUSE_MODE_CAPTURED
        )
        return

    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        player.handle_mouse_motion(event.relative)
        return

    if event.is_action_pressed("l1_fire"):
        if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            return
        player.request_fire()

func _on_entity_died(entity: Node) -> void:
    if entity != player or mission_complete or mission_failed:
        return
    mission_failed = true
    player.stop()
    if _signal_bus != null:
        _signal_bus.emit_signal(&"mission_changed", &"level1", &"failed")

func _on_item_collected(
        item_kind: StringName,
        item_id: StringName,
        amount: int,
        collector: Node
) -> void:
    if collector != player or amount <= 0:
        return

    if item_kind == &"key":
        keys_held = mini(keys_held + amount, LevelData.KEY_COUNT)
        var key_number := int(String(item_id).right(2))
        _set_message(
            "КЛЮЧ №%d ПОЛУЧЕН — найдена ещё одна часть маршрута." % key_number,
            1.8
        )
        if _signal_bus != null:
            _signal_bus.call("emit_audio_event",
            &"pickup",
            Vector3(player.global_position.x, player.global_position.y, player.global_position.z)
        )
        return

    if item_kind != &"acorn":
        return

    collected = mini(collected + amount, LevelData.ACORN_COUNT)
    if _signal_bus != null:
        _signal_bus.call("emit_audio_event",
        &"pickup",
        Vector3(player.global_position.x, player.global_position.y, player.global_position.z)
    )
    _set_message(
        LevelData.ACORN_LINES.pick_random()
            + "\nЖёлуди: %d / %d" % [collected, LevelData.ACORN_COUNT],
        1.8
    )

    _check_mission_complete()

func _on_object_interacted(object_id: StringName, state: StringName) -> void:
    if state != &"opened":
        return
    if not LevelData.DOOR_NAMES.has(String(object_id)):
        return
    if not doors_opened.has(object_id):
        doors_opened.append(object_id)
    _check_mission_complete()


func _check_mission_complete() -> void:
    if mission_complete:
        return
    if collected < LevelData.ACORN_COUNT:
        return
    if doors_opened.size() < LevelData.DOOR_NAMES.size():
        _set_message(
            "Жёлуди собраны. Открой все трое ворот.",
            2.0
        )
        return

    mission_complete = true
    player.stop()
    if _signal_bus != null:
        _signal_bus.emit_signal(&"mission_changed", &"level1", &"completed")


func _on_mission_changed(level_id: StringName, status: StringName) -> void:
    if level_id != &"level1":
        return

    if status == &"completed":
        mission_view.show_complete(LevelData.ACORN_COUNT)
        # SceneFlow autoload routes level_completed -> next scene.
        if _signal_bus != null:
            _signal_bus.emit_signal(&"level_completed", &"level1")
    elif status == &"failed":
        mission_view.show_failed()

func _update_hud() -> void:
    presentation_sync.sync_hud(
        hud_view,
        collected,
        LevelData.ACORN_COUNT,
        player.get_hp(),
        player.get_ammo()
    )
    count_label.text = "ЖЁЛУДИ %d / %d    КЛЮЧИ %d" % [
        collected,
        LevelData.ACORN_COUNT,
        keys_held
    ]

func _set_message(text: String, duration: float) -> void:
    if _signal_bus != null:
        _signal_bus.emit_signal(&"show_message", text, duration)

func _on_combat_event(kind: StringName, _position: Vector2) -> void:
    match kind:
        &"weapon_fired":
            combat_feedback.recoil()
            combat_feedback.show_muzzle()
        &"weapon_hit":
            combat_feedback.show_hit()
        &"weapon_missed":
            combat_feedback.show_miss()
        &"weapon_feedback_clear":
            combat_feedback.hide_hit()

func _toggle_music() -> void:
    var is_muted := AudioManager.toggle_music()
    mute_button.text = "×" if is_muted else "♪"
    _set_message(
        "Музыка выключена."
        if is_muted
        else "Музыка возвращена. Белки снова слышат угрозу.",
        1.6
    )

