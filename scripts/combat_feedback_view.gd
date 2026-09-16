class_name CombatFeedbackView
extends RefCounted

# Presentation-only combat feedback. It owns no gameplay state.
var weapon: TextureRect
var muzzle: ColorRect
var hit_marker: Label

func setup(weapon_view: TextureRect, muzzle_view: ColorRect, hit_view: Label) -> void:
    weapon = weapon_view
    muzzle = muzzle_view
    hit_marker = hit_view

func set_idle_weapon() -> void:
    weapon.position.y = 455.0

func recoil() -> void:
    weapon.position.y = 470.0

func show_muzzle() -> void:
    muzzle.visible = true
    muzzle.modulate.a = 1.0

func update_muzzle(delta: float) -> void:
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
