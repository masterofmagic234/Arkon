extends RefCounted
## Prepared PCM foley. Source recording/editing provenance lives beside assets.
const ROOT := "res://assets/level1/audio/polished147/"
const ALIASES := {
    &"body_hit": &"damage", &"cone_impact_stone": &"impact_stone",
    &"step_gravel": &"step_soil", &"cone_throw": &"squirrel_attack",
    &"gate_open": &"impact_metal", &"woodland_bell": &"pickup",
    &"woodland_activate": &"pickup", &"heist_solved": &"pickup",
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
    &"squirrel_hit": ["impact_soft_01", "impact_soft_02"],
    &"damage": ["impact_soft_01", "impact_soft_02"],
    &"squirrel_warn": ["ready_01", "ready_02"],
    &"squirrel_attack": ["attack_01", "attack_02"],
    &"squirrel_defeat": ["defeat_01", "defeat_02"],
    &"pickup": ["ready_01", "ready_02"],
}

static func canonical(kind: StringName) -> StringName:
    return ALIASES.get(kind, kind)

static func settings(kind: StringName) -> Dictionary:
    var local := kind in [&"shoot", &"compact_shoot", &"scatter_shoot", &"damage", &"step_stone", &"step_grass", &"step_soil"]
    var footsteps := String(kind).contains("step_")
    var enemy_step := String(kind).begins_with("enemy_step_")
    var priority := 1 if footsteps or String(kind).begins_with("impact_") else 2
    if kind in [&"shoot", &"compact_shoot", &"scatter_shoot", &"enemy_shoot", &"damage"]: priority = 3
    var gain := 0.0 if kind in [&"shoot", &"compact_shoot", &"scatter_shoot"] else -3.0
    if kind == &"squirrel_warn": gain = 2.0
    if kind == &"squirrel_defeat": gain = -5.0
    if enemy_step: gain = -10.0
    var cooldown := .075 if kind == &"damage" else (.52 if kind == &"squirrel_warn" else .0)
    return {"local": local, "priority": priority, "gain_db": gain, "max_distance": 18.0 if enemy_step else (48.0 if kind == &"enemy_shoot" else 34.0), "unit_size": 2.3 if enemy_step else (5.0 if kind == &"enemy_shoot" else 3.6), "cooldown": cooldown, "pitch_span": .025 if footsteps else .012, "pitch_base": 1.10 if enemy_step else 1.0}

static func path_for(id: String) -> String:
    return ROOT + id + ".wav"
