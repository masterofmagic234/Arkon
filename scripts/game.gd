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

const WALL_TEXTURE_PATHS := [
    "res://wall_zone1.png",
    "res://wall_zone2.png",
    "res://wall_zone3.png",
    "res://wall_zone4.png",
]
const FLOOR_TEXTURE_PATH := "res://assets/grass.png"
const LEVEL_2_SCENE_PATH := "res://scenes/level2_pseudo3d.tscn"

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
    _prepare_environment_materials()
    _setup_atmosphere()
    _setup_mobile_visibility()

    player_view = PlayerView.new()
    player_view.setup(camera, carolina)
    player_view.apply()
    mission_panel.visible = false
    muzzle.visible = false
    hit_marker.visible = false
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

func _prepare_environment_materials() -> void:
    # Make the new floor texture visibly read as grass instead of the nearly-black
    # fallback tint from the original scene material.
    var ground := get_node_or_null("Ground") as MeshInstance3D
    if ground and ground.mesh:
        var ground_mesh := ground.mesh.duplicate() as PlaneMesh
        if ground_mesh:
            var ground_material := ground_mesh.material
            if ground_material is StandardMaterial3D:
                ground_material = ground_material.duplicate() as StandardMaterial3D
                ground_material.albedo_color = Color(0.72, 0.82, 0.70, 1.0)
                var floor_texture := load(FLOOR_TEXTURE_PATH) as Texture2D
                if floor_texture:
                    ground_material.albedo_texture = floor_texture
                ground_mesh.material = ground_material
            ground.mesh = ground_mesh

    # Reuse one material per wall-zone texture instead of duplicating a
    # StandardMaterial3D for every wall segment. This keeps material/resource
    # count low and lets Android's renderer batch matching wall surfaces.
    var wall_materials: Dictionary = {}
    var wall_index := 0
    for child in get_children():
        if not (child is StaticBody3D) or not child.name.begins_with("MapWall_"):
            continue
        var mesh_instance := child.get_node_or_null("Mesh") as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue

        var texture_path: String = WALL_TEXTURE_PATHS[wall_index % WALL_TEXTURE_PATHS.size()]
        var wall_material: StandardMaterial3D = wall_materials.get(texture_path) as StandardMaterial3D
        if wall_material == null:
            wall_material = StandardMaterial3D.new()
            var wall_texture := load(texture_path) as Texture2D
            if wall_texture:
                wall_material.albedo_texture = wall_texture
            wall_material.albedo_color = Color.WHITE
            wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
            wall_material.roughness = 1.0
            wall_material.uv1_triplanar = true
            wall_material.uv1_world_triplanar = true
            wall_material.uv1_scale = Vector3(0.4, 0.4, 0.4)
            wall_material.uv1_offset = Vector3.ZERO
            wall_materials[texture_path] = wall_material

        # Keep each wall's geometry resource intact; only override its material.
        mesh_instance.material_override = wall_material
        mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        wall_index += 1

func _setup_mobile_visibility() -> void:
    # Aggressive mobile culling: let the fog hide the cutoff so the renderer
    # does not spend time drawing distant walls, trees and squirrels.
    camera.near = 0.05
    camera.far = 12.0

func _setup_atmosphere() -> void:
    var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
    if we == null or we.environment == null:
        push_warning("[Atmosphere] WorldEnvironment not found")
        return
    var env := we.environment
    var renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))

    # The project intentionally uses GL Compatibility for Android.
    # Volumetric fog is Forward+ only, so use a lightweight depth/height fog
    # fallback here instead of enabling an effect the target renderer cannot draw.
    if renderer != "gl_compatibility":
        env.volumetric_fog_enabled = true
        env.volumetric_fog_density = 0.015
        env.volumetric_fog_emission = Color(0.4, 0.5, 0.7)
        env.volumetric_fog_emission_energy = 0.6
        env.volumetric_fog_albedo = Color(0.9, 0.95, 1.0)
        env.volumetric_fog_length = 60.0
    else:
        env.volumetric_fog_enabled = false
        env.fog_enabled = true
        env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
        env.fog_density = 0.20
        env.fog_height = 0.0
        env.fog_height_density = 0.0
        env.fog_light_color = Color(0.40, 0.48, 0.66)
        env.fog_light_energy = 0.55
        env.fog_sky_affect = 0.08
        env.fog_sun_scatter = 0.30

    # Full-screen glow is expensive on Android Compatibility. Keep the
    # atmosphere fog/tonemapping, but disable bloom on the mobile target.
    env.glow_enabled = false

    # AgX tonemapping — supported by the Android Compatibility renderer.
    env.tonemap_mode = Environment.TONE_MAPPER_AGX
    env.tonemap_exposure = 1.0
    env.tonemap_white = 2.5

    # Slightly deepen ambient for more night contrast.
    env.ambient_light_energy = 0.65

    print("[Atmosphere] Night atmosphere enabled. Renderer: %s" % renderer)

func _spawn_leaves() -> void:
    if get_node_or_null("FallingLeaves") != null:
        return

    var leaves := GPUParticles3D.new()
    leaves.name = "FallingLeaves"
    # Keep the drifting-leaf effect, but make it cheap enough for mobile.
    leaves.amount = 8
    leaves.lifetime = 8.0
    leaves.preprocess = 1.5
    leaves.explosiveness = 0.0
    leaves.randomness = 0.8

    var mat := ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(18, 1, 12)
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 15.0
    mat.initial_velocity_min = 0.6
    mat.initial_velocity_max = 1.4
    mat.gravity = Vector3(0.2, -0.3, 0.1)
    mat.scale_min = 0.4
    mat.scale_max = 0.9
    mat.angular_velocity_min = -30.0
    mat.angular_velocity_max = 30.0

    var draw_pass := QuadMesh.new()
    draw_pass.size = Vector2(0.15, 0.15)
    var leaf_mat := StandardMaterial3D.new()
    leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    leaf_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    leaf_mat.albedo_color = Color(0.55, 0.35, 0.15, 0.85)
    draw_pass.material = leaf_mat

    leaves.draw_pass_1 = draw_pass
    leaves.process_material = mat
    leaves.position = Vector3(0, 10, 0)
    leaves.local_coords = false
    add_child(leaves)
    print("[Atmosphere] Falling leaves spawned.")

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
    get_tree().call_deferred("change_scene_to_file", LEVEL_2_SCENE_PATH)

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
    pass

func _refresh_minimap() -> void:
    presentation_sync.sync_minimap(minimap_view, player, game_state.acorns, game_state.squirrels, game_state.stunned)
