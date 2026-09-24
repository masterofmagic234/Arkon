extends Resource
class_name WeaponData

@export var weapon_id: StringName = &"pistol"
@export var display_name: String = "ПИСТОЛЕТ"
@export var damage: int = 100
@export var pellets: int = 1
@export var spread_angles: PackedFloat32Array = PackedFloat32Array([0.0])
@export var fire_interval: float = 0.18
@export var max_distance: float = 650.0
@export var projectile_speed: float = 650.0
@export var projectile_fps: float = 14.0
@export var projectile_scale: Vector2 = Vector2(2.3, 2.3)
@export var projectile_texture: String = "res://assets/level3/source/Combat/sprBullet_strip4.png"
@export var muzzle_texture: String = "res://assets/level3/source/Combat/sprBulletHit_strip11.png"
@export var movement_sprite: String = "res://assets/level3/source/Player/sprPWalkBossgun_strip8.png"
@export var attack_sprite: String = "res://assets/level3/source/Player/sprPAttackBossgun_strip20.png"
@export var overlay_texture: String = "res://assets/level3/source/Weapons/sprBossgun.png"
@export var projectile_spawn_muzzle: bool = true
@export var consumes_ammo: bool = true
@export var melee: bool = false
@export var action_range: float = 32.0
