class_name MessageView
extends RefCounted

# Presentation-only transient message view.
var label: Label

func setup(message_label: Label) -> void:
    label = message_label

func set_text(text: String) -> void:
    label.text = text

func clear() -> void:
    label.text = ""
