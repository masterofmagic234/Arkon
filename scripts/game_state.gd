extends Node
class_name GameState
# Autoload singleton. Persistent run data that survives scene transitions.
# RULE: only data + simple mutators here. No gameplay logic, no node references.

var completed_levels: Array[StringName] = []
var current_level: StringName = &""

var player_hp: int = 100
var player_max_hp: int = 100
var player_ammo: int = 38
var acorns_collected: int = 0

var music_volume_db: float = -9.0
var sfx_volume_db: float = 0.0
var music_muted: bool = false
var sfx_muted: bool = false

const SAVE_PATH := "user://settings.cfg"

func _ready() -> void:
    load_settings()

func mark_completed(level_id: StringName) -> void:
    if not completed_levels.has(level_id):
        completed_levels.append(level_id)

func is_completed(level_id: StringName) -> bool:
    return completed_levels.has(level_id)

# Progression contract:
# Direct level launch is allowed in dev/debug. UI may gate using a predecessor.
# retry_level() keeps completed_levels; start_new_run() clears the run.
func is_unlocked(level_id: StringName, required_predecessor: StringName = &"") -> bool:
    if required_predecessor == &"":
        return true
    return is_completed(required_predecessor)

func can_replay(level_id: StringName) -> bool:
    return is_completed(level_id)

func retry_level() -> void:
    player_hp = player_max_hp
    player_ammo = 38

func start_new_run() -> void:
    reset_run()

func reset_run() -> void:
    completed_levels.clear()
    current_level = &""
    player_hp = player_max_hp
    player_ammo = 38
    acorns_collected = 0

func set_music_muted(muted: bool) -> void:
    music_muted = muted
    save_settings()

func set_sfx_muted(muted: bool) -> void:
    sfx_muted = muted
    save_settings()

func save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("audio", "music_volume_db", music_volume_db)
    cfg.set_value("audio", "sfx_volume_db", sfx_volume_db)
    cfg.set_value("audio", "music_muted", music_muted)
    cfg.set_value("audio", "sfx_muted", sfx_muted)
    cfg.save(SAVE_PATH)

func load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    music_volume_db = cfg.get_value("audio", "music_volume_db", music_volume_db)
    sfx_volume_db = cfg.get_value("audio", "sfx_volume_db", sfx_volume_db)
    music_muted = cfg.get_value("audio", "music_muted", music_muted)
    sfx_muted = cfg.get_value("audio", "sfx_muted", sfx_muted)
