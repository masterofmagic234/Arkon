extends Node3D
# An interaction has no remote command path: the director checks reach and LOS
# again on every activation and throughout a timed action.
var kind := ""
var index := 0
var value := 0
var used := false
var cooldown := 0.0
var title: Label3D
var dial: Node3D

func description() -> String:
    match kind:
        "dial": return "Линза %s: %s" % [["I","II","III"][index],preload("res://scripts/level1_heist_data.gd").SYMBOLS[value]]
        "relay": return "Отключить дозорные лучи · 2 с"
        "seal": return "Снять печать дуба · 3 с"
        "bell": return "Позвонить и отвлечь дозор" if cooldown <= 0 else "Колокольчик: ещё %d с" % ceili(cooldown)
        "note": return "Прочитать записку садовника"
    return ""
