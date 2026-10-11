class_name CombatFeedbackView
extends RefCounted

# Presentation-only combat feedback. It owns no gameplay state.
var weapon: TextureRect
var muzzle: ColorRect
var hit_marker: Label
var idle_position := Vector2.ZERO
var recoil_amount := 0.0

func setup(weapon_view: TextureRect, muzzle_view: ColorRect, hit_view: Label) -> void:
    weapon = weapon_view
    muzzle = muzzle_view
    hit_marker = hit_view
    idle_position = weapon.position
    muzzle.color = Color(1.0, 0.82, 0.42, 0.8)

func set_idle_weapon() -> void:
    weapon.position = idle_position

func recoil() -> void:
    if recoil_amount < 0.01:
        idle_position = weapon.position
    recoil_amount = 20.0

func show_muzzle() -> void:
    muzzle.visible = true
    muzzle.modulate.a = 1.0

func update_muzzle(delta: float) -> void:
    if recoil_amount > 0.01:
        recoil_amount = move_toward(recoil_amount, 0.0, delta * 130.0)
        weapon.position = idle_position + Vector2(0.0, recoil_amount)
    else:
        idle_position = weapon.position
    if muzzle.visible:
        muzzle.modulate.a = clampf(muzzle.modulate.a - delta * 7.0, 0.0, 1.0)
        if muzzle.modulate.a <= 0.0:
            muzzle.visible = false

func show_hit() -> void:
    hit_marker.visible = true
    hit_marker.text = "×"

func show_miss() -> void:
    hit_marker.visible = true
    hit_marker.text = "•"

func hide_hit() -> void:
    hit_marker.visible = false
