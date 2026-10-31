extends RefCounted
## Prepared PCM foley. Source recording/editing provenance lives beside assets.
const ROOT := "res://assets/level1/audio/polished147/"
const VOICE_ROOT := "res://assets/level1/audio/voices149/"
const GUARDIAN_ROOT := "res://assets/level1/audio/guardian153/"
const ALIASES := {
    &"body_hit": &"damage", &"cone_impact_stone": &"impact_stone",
    &"step_gravel": &"step_soil", &"cone_throw": &"enemy_shoot",
    &"gate_open": &"impact_metal", &"woodland_bell": &"pickup",
    &"woodland_activate": &"pickup", &"heist_solved": &"pickup",
    &"encounter_entry": &"squirrel_rally", &"encounter_pump": &"squirrel_warn",
    &"encounter_gallery": &"guardian_rally", &"encounter_escape": &"guardian_warn",
}
const SETS := {
    &"shoot": ["launcher_01", "launcher_02"],
    &"compact_shoot": ["compact_01", "compact_02"],
    &"scatter_shoot": ["scatter_01", "scatter_02"],
    # Scouts throw held cones at the authored paw release, without a firearm.
    &"enemy_shoot": ["attack_01", "attack_02"],
    &"step_stone": ["step_stone_01", "step_stone_02", "step_stone_03", "step_stone_04"],
    &"step_grass": ["step_grass_01", "step_grass_02", "step_grass_03"],
    &"step_soil": ["step_soil_01", "step_soil_02", "step_soil_03", "step_soil_04"],
    &"enemy_step_stone": ["step_stone_01", "step_stone_02", "step_stone_03", "step_stone_04"],
    &"enemy_step_grass": ["step_grass_01", "step_grass_02", "step_grass_03"],
    &"enemy_step_soil": ["step_soil_01", "step_soil_02", "step_soil_03", "step_soil_04"],
    &"impact_stone": ["impact_stone_01", "impact_stone_02"],
    &"impact_wood": ["impact_wood_01", "impact_wood_02"],
    &"impact_metal": ["impact_metal_01", "impact_metal_02"],
    &"impact_soft": ["impact_soft_01", "impact_soft_02"],
    &"impact_soil": ["impact_soil_01", "impact_soil_02"],
    &"squirrel_hit": ["voice_squirrel_hit_01", "voice_squirrel_hit_02", "voice_squirrel_hit_03"],
    &"damage": ["impact_soft_01", "impact_soft_02"],
    &"squirrel_warn": ["voice_squirrel_warn_01", "voice_squirrel_warn_02", "voice_squirrel_warn_03"],
    &"squirrel_attack": ["voice_squirrel_attack_01", "voice_squirrel_attack_02", "voice_squirrel_attack_03"],
    &"squirrel_defeat": ["voice_squirrel_defeat_01", "voice_squirrel_defeat_02", "voice_squirrel_defeat_03"],
    &"squirrel_rally": ["voice_squirrel_rally_01", "voice_squirrel_rally_02", "voice_squirrel_rally_03"],
    &"squirrel_chatter": ["voice_squirrel_rally_01", "voice_squirrel_rally_02", "voice_squirrel_rally_03"],
    &"guardian_warn": ["voice_guardian_warn_153_01", "voice_guardian_warn_153_02", "voice_guardian_warn_153_03"],
    &"guardian_attack": ["voice_guardian_attack_153_01", "voice_guardian_attack_153_02", "voice_guardian_attack_153_03"],
    &"guardian_hit": ["voice_guardian_hit_01", "voice_guardian_hit_02", "voice_guardian_hit_03"],
    &"guardian_defeat": ["voice_guardian_defeat_01", "voice_guardian_defeat_02", "voice_guardian_defeat_03"],
    &"guardian_rally": ["voice_guardian_rally_153_01", "voice_guardian_rally_153_02", "voice_guardian_rally_153_03"],
    &"pickup": ["ready_01", "ready_02"],
}

static func canonical(kind: StringName) -> StringName:
    return ALIASES.get(kind, kind)

static func settings(kind: StringName) -> Dictionary:
    var vocal := is_vocal(kind)
    var local := kind in [&"shoot", &"compact_shoot", &"scatter_shoot", &"damage", &"step_stone", &"step_grass", &"step_soil"]
    var footsteps := String(kind).contains("step_")
    var enemy_step := String(kind).begins_with("enemy_step_")
    var priority := 1 if footsteps or String(kind).begins_with("impact_") else 2
    if kind in [&"shoot", &"compact_shoot", &"scatter_shoot", &"enemy_shoot", &"damage"]: priority = 3
    var gain := 0.0 if kind in [&"shoot", &"compact_shoot", &"scatter_shoot"] else -3.0
    if vocal: gain = -3.0
    if String(kind).ends_with("_defeat"): gain = -5.0
    if kind == &"squirrel_chatter":
        gain = -9.0
        priority = 1
    if enemy_step: gain = -10.0
    var cooldown := .075 if kind == &"damage" else .0
    if vocal:
        cooldown = .32
        if String(kind).ends_with("_warn"): cooldown = 1.5
        if String(kind).ends_with("_rally"): cooldown = 3.0
        if String(kind).ends_with("_hit"): cooldown = .22
        if String(kind).ends_with("_defeat"): cooldown = .3
        if kind == &"squirrel_chatter": cooldown = 8.0
    return {"local": local, "vocal": vocal, "voice_class": "guardian" if String(kind).begins_with("guardian_") else ("squirrel" if vocal else "foley"), "priority": priority, "gain_db": gain, "max_distance": (22.0 if kind == &"squirrel_chatter" else 38.0) if vocal else (18.0 if enemy_step else (48.0 if kind == &"enemy_shoot" else 34.0)), "unit_size": 3.8 if vocal else (2.3 if enemy_step else (5.0 if kind == &"enemy_shoot" else 3.6)), "cooldown": cooldown, "pitch_span": .008 if vocal else (.025 if footsteps else .012), "pitch_base": 1.10 if enemy_step else 1.0}

static func is_vocal(kind: StringName) -> bool:
    return String(kind).begins_with("squirrel_") or String(kind).begins_with("guardian_")

static func path_for(id: String) -> String:
    if id.begins_with("voice_guardian_") and id.contains("_153_"):
        return GUARDIAN_ROOT + id + ".wav"
    return (VOICE_ROOT if id.begins_with("voice_") else ROOT) + id + ".wav"
