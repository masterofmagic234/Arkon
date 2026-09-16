extends RefCounted
class_name MissionView

var panel: Panel
var title_label: Label
var body_label: Label
var weapon: TextureRect

func setup(mission_panel: Panel, mission_title: Label, mission_body: Label, weapon_view: TextureRect) -> void:
    panel = mission_panel
    title_label = mission_title
    body_label = mission_body
    weapon = weapon_view

func show_complete(acorn_count: int) -> void:
    panel.visible = true
    title_label.text = "ОПЕРАЦИЯ ЗАВЕРШЕНА"
    body_label.text = "ЖЁЛУДИ: %d / %d\n\nОН СУЩЕСТВУЕТ.\n\nКаролина нашла легендарный жёлудь.\nДарина может делать поделку.\nБелки официально проиграли.\n\nP.S. Данил всё это время верил в тебя." % [acorn_count, acorn_count]
    weapon.visible = false

func show_failed() -> void:
    panel.visible = true
    title_label.text = "ОПЕРАЦИЯ ПРОВАЛЕНА"
    body_label.text = "HP: 0\n\nБелки победили.\nЭто позор.\n\nНо Дарина всё ещё ждёт жёлуди."
    weapon.visible = false
