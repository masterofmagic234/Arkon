extends AudioStreamPlayer
## One scene-owned spoken line. Manual page changes replace it; text reveal
## leaves it playing. Explicit PAUSABLE also works beneath cinematic ALWAYS UI.
const Lines = preload("res://scripts/level3_dialogue_lines.gd")
const ROOT := "res://assets/audio158/voice/"
var current_voice_id := ""

func _init() -> void:
    name = "DialogueVoice158"
    process_mode = Node.PROCESS_MODE_PAUSABLE
    bus = &"Master"

func _ready() -> void:
    finished.connect(_on_finished)
    _apply_preferences()

static func id_for_dialogue(entry: Dictionary) -> String:
    if String(entry.get("speaker", "")) != "ТАЯ": return ""
    for section in [["reception", Lines.RECEPTION], ["kitchen", Lines.KITCHEN], ["aftermath", Lines.AFTERMATH]]:
        var entries: Array = section[1]
        for index in entries.size():
            if entries[index].speaker == entry.speaker and entries[index].text == String(entry.get("text", "")):
                return "l3_%s_%02d" % [section[0], index]
    return ""

func play_dialogue(entry: Dictionary) -> bool:
    return play_line(id_for_dialogue(entry))

func play_line(id: String) -> bool:
    stop_voice()
    if id.is_empty(): return false
    var path := ROOT + id + ".ogg"
    if not ResourceLoader.exists(path, "AudioStream"): return false
    stream = load(path) as AudioStream
    if stream == null: return false
    current_voice_id = id
    _apply_preferences()
    play()
    return true

func remaining_time() -> float:
    return maxf(0.0, stream.get_length() - get_playback_position()) if playing and stream != null else 0.0

func stop_voice() -> void:
    stop()
    stream = null
    current_voice_id = ""

func _on_finished() -> void:
    stream = null
    current_voice_id = ""

func _process(_delta: float) -> void:
    _apply_preferences()

func _apply_preferences() -> void:
    var settings := get_node_or_null("/root/GameState")
    if settings != null:
        volume_db = -80.0 if settings.sfx_muted else float(settings.sfx_volume_db)

func _exit_tree() -> void:
    stop_voice()
