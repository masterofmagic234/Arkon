extends Node
class_name WeaponComponent

signal weapon_changed(weapon: StringName, ammo: int)

const WeaponData = preload("res://scripts/weapon_data.gd")

@export var initial_weapon: StringName = &"pistol"
@export var initial_ammo: int = 12

var weapons: Dictionary = {}
var current_weapon: StringName = &""
var current_data: WeaponData
# Reserve ammo is owned per weapon, not by the currently equipped weapon.
# This prevents pistol rounds from silently becoming shotgun rounds.
var ammo_by_weapon: Dictionary = {}
var ammo: int = 0
var cooldown: float = 0.0

func _ready() -> void:
    _load_defaults()
    ammo_by_weapon.clear()
    for weapon_id in weapons.keys():
        var data := weapons[weapon_id] as WeaponData
        if data != null and data.consumes_ammo:
            ammo_by_weapon[weapon_id] = 0
    equip(initial_weapon, initial_ammo)

func _load_defaults() -> void:
    var paths := {
        &"pistol": "res://resources/weapons/level3_pistol.tres",
        &"shotgun": "res://resources/weapons/level3_shotgun.tres",
        &"bat": "res://resources/weapons/level3_bat.tres",
    }
    weapons.clear()
    for id in paths.keys():
        var data := load(paths[id]) as WeaponData
        if data != null:
            weapons[id] = data

func tick(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)

func equip(weapon: StringName, additional_ammo: int = 0) -> void:
    if not weapons.has(weapon):
        push_warning("WeaponComponent: unknown weapon %s" % String(weapon))
        return
    current_weapon = weapon
    current_data = weapons[weapon] as WeaponData
    if current_data == null:
        return
    if current_data.consumes_ammo:
        ammo = maxi(int(ammo_by_weapon.get(weapon, 0)) + maxi(additional_ammo, 0), 0)
        ammo_by_weapon[weapon] = ammo
    else:
        ammo = 0
    cooldown = 0.0
    weapon_changed.emit(current_weapon, ammo)
    _emit_global_weapon()

func can_fire() -> bool:
    if current_data == null or cooldown > 0.0:
        return false
    return not current_data.consumes_ammo or ammo > 0

func consume_shot() -> bool:
    if not can_fire():
        return false
    if current_data.consumes_ammo:
        ammo = maxi(ammo - 1, 0)
        ammo_by_weapon[current_weapon] = ammo
    cooldown = maxf(current_data.fire_interval, 0.01)
    weapon_changed.emit(current_weapon, ammo)
    _emit_global_weapon()
    return true

func get_data(weapon: StringName = current_weapon) -> WeaponData:
    if weapon == current_weapon:
        return current_data
    return weapons.get(weapon) as WeaponData

func _emit_global_weapon() -> void:
    var bus := get_node_or_null("/root/SignalBus")
    if bus != null and bus.has_signal("weapon_changed"):
        bus.weapon_changed.emit(get_parent(), current_weapon, ammo)
