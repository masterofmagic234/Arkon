extends Node3D

# ACORN HUNTER — LEVEL 1
# Rebuilt from the last proven CLEAN/V6 control foundation.
# World sprites are deliberately MeshInstance3D + QuadMesh, not Sprite3D.
# UI owns touch input: joystick.gui_input + Fire.pressed.

const LevelData = preload("res://scripts/level_data.gd")
const HudView = preload("res://scripts/hud_view.gd")
const AudioController = preload("res://scripts/audio_controller.gd")
const MissionView = preload("res://scripts/mission_view.gd")
const CombatFeedbackView = preload("res://scripts/combat_feedback_view.gd")
const MessageView = preload("res://scripts/message_view.gd")
const MinimapView = preload("res://scripts/minimap_view.gd")
const NavigationController = preload("res://scripts/navigation_controller.gd")
const WorldSpriteView = preload("res://scripts/world_sprite_view.gd")
const RuntimeTimers = preload("res://scripts/runtime_timers.gd")
const PresentationSync = preload("res://scripts/presentation_sync.gd")
const PlayerView = preload("res://scripts/player_view.gd")
const MissionStateQuery = preload("res://scripts/mission_state_query.gd")
const GameState = preload("res://scripts/game_state.gd")
const GameplayController = preload("res://scripts/gameplay_controller.gd")
const PlayerController = preload("res://scripts/player_controller.gd")
const EnemyController = preload("res://scripts/enemy_controller.gd")
const PickupController = preload("res://scripts/pickup_controller.gd")
const WallShader = preload("res://shaders/wall_night_masonry.gdshader")

const WallTextures = [
    preload("res://assets/wall_mural_mossy_stone.png"),
    preload("res://assets/wall_mural_overgrown.png"),
    preload("res://assets/wall_mural_brick_stone.png"),
    preload("res://assets/wall_mural_wooden_fence.png"),
    preload("res://assets/wall_mural_ruined_temple.png"),
    preload("res://assets/wall_mural_autumn.png")
]

var game_state = null
var gameplay_controller
var player_controller
var enemy_controller
var pickup_controller
var audio_controller: AudioController
var hud_view: HudView
var mission_view: MissionView
var combat_feedback: CombatFeedbackView
var message_view: MessageView
var minimap_view: MinimapView
var navigation_controller: NavigationController
var world_sprite_view: WorldSpriteView
var runtime_timers: RuntimeTimers
var presentation_sync: PresentationSync
var player_view: PlayerView

@onready var player: CharacterBody3D = $Player
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

func _ready() -> void:
    game_state = GameState.new()
    game_state.setup(LevelData)
    _apply_illustrated_wall_materials()
    player_view = PlayerView.new()
    player_view.setup(camera, carolina)
    player_view.apply()
    mission_panel.visible = false
    muzzle.visible = false
    hit_marker.visible = false
    weapon.visible = false
    knob.position = joystick.size * 0.5 - knob.size * 0.5

    fire_button.pressed.connect(_on_fire_pressed)
    mute_button.pressed.connect(_toggle_music)

    hud_view = HudView.new()
    hud_view.setup(count_label, hp_ammo_label)

    mission_view = MissionView.new()
    mission_view.setup(mission_panel, mission_title, mission_body, weapon)

    combat_feedback = CombatFeedbackView.new()
    combat_feedback.setup(weapon, muzzle, hit_marker)

    message_view = MessageView.new()
    message_view.setup(message_label)

    minimap_view = $HUD/Minimap as MinimapView

    world_sprite_view = WorldSpriteView.new()
    runtime_timers = RuntimeTimers.new()
    presentation_sync = PresentationSync.new()

    navigation_controller = NavigationController.new()
    navigation_controller.setup($HUD/Mission/Menu, get_tree())

    audio_controller = AudioController.new()
    audio_controller.setup(music, fx)
    audio_controller.start_music()

    player_controller = PlayerController.new()
    player_controller.setup(player, joystick, knob, audio_controller)

    enemy_controller = EnemyController.new()
    enemy_controller.setup(self, player, game_state, world_sprite_view, audio_controller, message_view, Callable(self, "_on_enemy_fail"))

    pickup_controller = PickupController.new()
    pickup_controller.setup(self, player, game_state, world_sprite_view, audio_controller, message_view, mission_view, Callable(self, "_on_pickup_complete"), Callable(self, "_on_pickup_fail"))

    gameplay_controller = GameplayController.new()
    gameplay_controller.setup(self, player, camera, game_state, world_sprite_view, combat_feedback, audio_controller, message_view, mission_view, enemy_controller, pickup_controller, Callable(self, "_on_mission_end"))

    _update_hud()
    _set_message("Парк открыт. Дубы не прячутся — жёлуди тоже.", 4.0)
    _refresh_minimap()

func _apply_illustrated_wall_materials() -> void:
    # Rebuild only the visible wall skins as continuous mural canvases.
    # Collision bodies and their positions remain untouched.
    var mural_count := 0
    for node in find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := node as MeshInstance3D
        if mesh_instance != null and mesh_instance.name.begins_with("IllustratedWall"):
            mesh_instance.visible = false
            mural_count += 1

    var wall_cells: Dictionary = {}
    var wall_nodes: Array[Node3D] = []
    for node in find_children("*", "StaticBody3D", true, false):
        if not node.name.begins_with("MapWall"):
            continue
        var wall := node as Node3D
        if wall == null:
            continue
        var gx := int(round((wall.position.x + 17.1) / 1.8))
        var gz := int(round((wall.position.z + 11.7) / 1.8))
        if gx < 0 or gx >= 20 or gz < 0 or gz >= 14:
            continue
        wall_cells[Vector2i(gx, gz)] = wall
        wall_nodes.append(wall)

    var old_skin := get_node_or_null("WallMuralSkins")
    if old_skin != null:
        old_skin.queue_free()

    var skins := Node3D.new()
    skins.name = "WallMuralSkins"
    add_child(skins)

    var horizontal_runs := 0
    var vertical_runs := 0

    # Every maximal straight run gets the complete 4096x512 artwork. The
    # shader maps the strip over the whole run rather than repeating one 512px
    # panel on every physical wall block.
    for gz in range(14):
        var gx := 0
        while gx < 20:
            if not wall_cells.has(Vector2i(gx, gz)):
                gx += 1
                continue
            var run_start := gx
            var style := _wall_location_style(Vector3(-17.1 + 1.8 * gx, 1.3, -11.7 + 1.8 * gz))
            while gx + 1 < 20 and wall_cells.has(Vector2i(gx + 1, gz)):
                var next_style := _wall_location_style(Vector3(-17.1 + 1.8 * (gx + 1), 1.3, -11.7 + 1.8 * gz))
                if next_style != style:
                    break
                gx += 1
            _create_wall_mural_run(skins, run_start, gx, gz, true, style)
            horizontal_runs += 1
            gx += 1

    for gx in range(20):
        var gz := 0
        while gz < 14:
            if not wall_cells.has(Vector2i(gx, gz)):
                gz += 1
                continue
            var run_start := gz
            var style := _wall_location_style(Vector3(-17.1 + 1.8 * gx, 1.3, -11.7 + 1.8 * gz))
            while gz + 1 < 14 and wall_cells.has(Vector2i(gx, gz + 1)):
                var next_style := _wall_location_style(Vector3(-17.1 + 1.8 * gx, 1.3, -11.7 + 1.8 * (gz + 1)))
                if next_style != style:
                    break
                gz += 1
            _create_wall_mural_run(skins, gx, gz, run_start, false, style)
            vertical_runs += 1
            gz += 1

    # Keep all collision shapes exactly as authored. Only legacy visible boxes
    # are hidden; the new mural skins provide the rendered surfaces.
    for wall in wall_nodes:
        var mesh := wall.get_node_or_null("Mesh") as MeshInstance3D
        if mesh != null:
            mesh.visible = false

    print("ACORN HUNTER: continuous mural canvases; horizontal=", horizontal_runs, ", vertical=", vertical_runs, ", collision walls preserved=", wall_nodes.size(), ", hidden legacy planes=", mural_count)

func _create_wall_mural_run(skins: Node3D, a: int, b: int, fixed: int, horizontal: bool, style_index: int) -> void:
    var count := b - a + 1
    var size := Vector2(float(count) * 1.8, 2.6)
    var center: Vector3

    if horizontal:
        center = Vector3(-17.1 + 1.8 * float(a + b) * 0.5, 1.3, -11.7 + 1.8 * fixed)
        _spawn_wall_skin(skins, center + Vector3(0, 0, 0.906), size, Vector3.ZERO, style_index, float(count) / 8.0)
        _spawn_wall_skin(skins, center + Vector3(0, 0, -0.906), size, Vector3(0, PI, 0), style_index, float(count) / 8.0)
    else:
        center = Vector3(-17.1 + 1.8 * fixed, 1.3, -11.7 + 1.8 * float(a + b) * 0.5)
        _spawn_wall_skin(skins, center + Vector3(0.906, 0, 0), size, Vector3(0, PI * 0.5, 0), style_index, float(count) / 8.0)
        _spawn_wall_skin(skins, center + Vector3(-0.906, 0, 0), size, Vector3(0, -PI * 0.5, 0), style_index, float(count) / 8.0)

func _spawn_wall_skin(parent: Node3D, position: Vector3, size: Vector2, rotation: Vector3, style_index: int, strip_repeat: float) -> void:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "MuralCanvas"
    var quad := QuadMesh.new()
    quad.size = size
    mesh_instance.mesh = quad
    mesh_instance.position = position
    mesh_instance.rotation = rotation

    var material := ShaderMaterial.new()
    material.shader = WallShader
    material.set_shader_parameter("wall_texture", WallTextures[style_index])
    material.set_shader_parameter("strip_repeat", strip_repeat)
    mesh_instance.material_override = material
    parent.add_child(mesh_instance)

func _wall_location_style(wall_position: Vector3) -> int:
    var column := clampi(int(round((wall_position.x + 17.1) / 1.8)), 0, 19)
    var row := clampi(int(round((wall_position.z + 11.7) / 1.8)), 0, 13)
    var zone_column := 0 if column <= 6 else (1 if column <= 12 else 2)
    var zone_row := 0 if row <= 6 else 1
    return zone_row * 3 + zone_column

func _physics_process(delta: float) -> void:
    if MissionStateQuery.is_finished(game_state.mission_complete, game_state.mission_failed):
        player_controller.stop()
        return

    game_state.foot_timer = player_controller.update(delta, game_state.foot_timer)

    var timers := runtime_timers.tick(delta, {
        "fire_cooldown": game_state.fire_cooldown,
        "damage_cooldown": game_state.damage_cooldown,
        "recoil_time": game_state.recoil_time,
        "message_time": game_state.message_time
    })
    game_state.fire_cooldown = timers["fire_cooldown"]
    game_state.damage_cooldown = timers["damage_cooldown"]
    game_state.recoil_time = timers["recoil_time"]
    game_state.message_time = timers["message_time"]

    if game_state.message_time <= 0.0:
        message_view.clear()
    if game_state.recoil_time <= 0.0:
        combat_feedback.set_idle_weapon()
    combat_feedback.update_muzzle(delta)

    gameplay_controller.update(delta)
    _update_hud()
    _refresh_minimap()

func _on_fire_pressed() -> void:
    gameplay_controller.handle_fire()

func _on_mission_end() -> void:
    player_controller.stop()

func _on_enemy_fail() -> void:
    gameplay_controller.fail()

func _on_pickup_complete() -> void:
    player_controller.stop()

func _on_pickup_fail() -> void:
    gameplay_controller.fail()

func _update_hud() -> void:
    presentation_sync.sync_hud(hud_view, game_state.collected, LevelData.ACORN_COUNT, game_state.hp, game_state.ammo)

func _set_message(text: String, duration: float) -> void:
    message_view.set_text(text)
    game_state.message_time = duration

func _toggle_music() -> void:
    var is_muted := audio_controller.toggle_music()
    mute_button.text = "×" if is_muted else "♪"
    _set_message("Музыка выключена." if is_muted else "Музыка возвращена. Белки снова слышат угрозу.", 1.6)

func _face_world_sprites() -> void:
    # Billboard materials handle camera-facing orientation.
    pass

func _refresh_minimap() -> void:
    presentation_sync.sync_minimap(minimap_view, player, game_state.acorns, game_state.squirrels, game_state.stunned)
