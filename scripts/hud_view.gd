class_name HudView
extends RefCounted

# Presentation-only HUD view. It does not own game state or input.
var count_label: Label
var hp_ammo_label: Label

func setup(count: Label, hp_ammo: Label) -> void:
    count_label = count
    hp_ammo_label = hp_ammo

func update_status(collected: int, total_acorns: int, hp: int, ammo: int) -> void:
    count_label.text = "ЖЁЛУДИ  %d / %d" % [collected, total_acorns]
    hp_ammo_label.text = "HP %d     AMMO %d" % [hp, ammo]
