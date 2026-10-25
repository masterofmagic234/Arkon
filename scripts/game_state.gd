extends Node
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
var level1_best_score := 0
var level1_best_rank := ""

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
    preload("res://scripts/woodland_journey_state.gd").clear_checkpoint()
    preload("res://scripts/botanical_state.gd").clear()
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

func record_level1(score: int, rank: String) -> void:
    if score<=level1_best_score: return
    level1_best_score=score
    level1_best_rank=rank
    save_settings()

func save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("audio", "music_volume_db", music_volume_db)
    cfg.set_value("audio", "sfx_volume_db", sfx_volume_db)
    cfg.set_value("audio", "music_muted", music_muted)
    cfg.set_value("audio", "sfx_muted", sfx_muted)
    cfg.set_value("level1", "best_score", level1_best_score)
    cfg.set_value("level1", "best_rank", level1_best_rank)
    cfg.save(SAVE_PATH)

func load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    music_volume_db = cfg.get_value("audio", "music_volume_db", music_volume_db)
    sfx_volume_db = cfg.get_value("audio", "sfx_volume_db", sfx_volume_db)
    music_muted = cfg.get_value("audio", "music_muted", music_muted)
    sfx_muted = cfg.get_value("audio", "sfx_muted", sfx_muted)
    level1_best_score = int(cfg.get_value("level1", "best_score", 0))
    level1_best_rank = str(cfg.get_value("level1", "best_rank", ""))
