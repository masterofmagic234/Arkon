extends RefCounted

# Runtime state only. No scene/node/UI dependencies.
var collected = 0
var ammo = 0
var hp = 0
var message_time = 0.0
var fire_cooldown = 0.0
var damage_cooldown = 0.0
var recoil_time = 0.0
var foot_timer = 0.0
var fake_cone_found = false
var mission_complete = false
var mission_failed = false
var stunned = {}
var squirrel_hp = {}
var acorns = []
var squirrels = []
var squirrel_home = {}
var squirrel_phase = {}

func setup(level_data):
    ammo = level_data.MAX_AMMO
    hp = level_data.MAX_HP
    squirrel_hp = level_data.SQUIRREL_HP.duplicate()
    acorns = level_data.ACORN_NAMES.duplicate()
    squirrels = level_data.SQUIRREL_NAMES.duplicate()
    squirrel_home = level_data.SQUIRREL_HOME.duplicate()
    squirrel_phase = level_data.SQUIRREL_PHASE.duplicate()
