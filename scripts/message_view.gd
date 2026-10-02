class_name MessageView
extends RefCounted

# Presentation-only transient message view.
# Gameplay systems publish show_message; this view owns the visual lifetime.

var label: Label
var _message_generation: int = 0
var _signal_bus: Node = null

func setup(message_label: Label) -> void:
    label = message_label
    var tree := Engine.get_main_loop() as SceneTree
    _signal_bus = tree.root.get_node_or_null("SignalBus") if tree != null else null
    if _signal_bus != null and _signal_bus.has_signal("show_message"):
        _signal_bus.connect("show_message", Callable(self, "_on_show_message"))

func teardown() -> void:
    if _signal_bus != null and _signal_bus.has_signal("show_message"):
        _signal_bus.disconnect("show_message", Callable(self, "_on_show_message"))
    _signal_bus = null
    _message_generation += 1

func _on_show_message(text: String, duration: float) -> void:
    set_text(text)
    _message_generation += 1
    var generation := _message_generation
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null or duration <= 0.0:
        return
    var timer := tree.create_timer(duration)
    timer.timeout.connect(
        Callable(self, "_on_message_timer_timeout").bind(generation),
        CONNECT_ONE_SHOT
    )

func _on_message_timer_timeout(generation: int) -> void:
    if generation == _message_generation:
        clear()

func set_text(text: String) -> void:
    if label != null:
        label.text = text

func clear() -> void:
    if label != null:
        label.text = ""
