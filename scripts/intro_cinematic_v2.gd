extends Control

# ACORN HUNTER — visual-novel intro.
# Required chronological video sequence:
# 1) 1789650644963 — opening room shot
# 2) 1789649201942 — Darina at the doorway / first dialogue block
# 3) 1789650878847 — silent visual transition
# 4) 1789649329293 — Darina with the toy beside Carolina / final dialogue block
#
# IMPORTANT: dialogue is intentionally shown on ONLY two videos:
# - 1789649201942.ogv: dialogue 0..4
# - 1789649329293.ogv: dialogue 5..16
const VIDEO_CLIPS: Array[String] = [
	"res://assets/intro_video/1789650644963.ogv",
	"res://assets/intro_video/1789649201942.ogv",
	"res://assets/intro_video/1789650878847.ogv",
	"res://assets/intro_video/1789649329293.ogv",
]

const CLIP_FADE_DURATION: float = 0.16
const TITLE_END: float = 2.2
const FIRST_DIALOGUE_INDEX: int = 0
const FIRST_DIALOGUE_VIDEO_INDEX: int = 1
const FIRST_DIALOGUE_LAST_INDEX: int = 4
const FINAL_DIALOGUE_VIDEO_INDEX: int = 3
const FINAL_DIALOGUE_START_INDEX: int = 5
const FINAL_DIALOGUE_INDEX: int = 16

const DIALOGUE_DATA: Array[Dictionary] = [
	{"speaker": "ДАРИНА", "text": "Каролин, спишь?"},
	{"speaker": "КАРОЛИНА", "text": "Уже нет...... Ночь на дворе, ты почему ещё не в кровати?"},
	{"speaker": "ДАРИНА", "text": "Нам поделку на завтра задали......"},
	{"speaker": "КАРОЛИНА", "text": "Сейчас?!"},
	{"speaker": "ДАРИНА", "text": "Ага...... Я только вспомнила."},
	{"speaker": "КАРОЛИНА", "text": "Дарина......"},
	{"speaker": "ДАРИНА", "text": "Ну не ругайся......"},
	{"speaker": "КАРОЛИНА", "text": "Я не ругаюсь. Просто уже почти ночь."},
	{"speaker": "ДАРИНА", "text": "Я хотела сама сделать... честно."},
	{"speaker": "КАРОЛИНА", "text": "И что же тебе задали?"},
	{"speaker": "ДАРИНА", "text": "Поделку из желудей."},
	{"speaker": "КАРОЛИНА", "text": "Из желудей?"},
	{"speaker": "КАРОЛИНА", "text": "Ладно. Сделаем эту поделку."},
	{"speaker": "ДАРИНА", "text": "УРААА! А жёлуди когда найдём?"},
	{"speaker": "КАРОЛИНА", "text": "Пойду сейчас на пробежку и найду тебе..."},
	{"speaker": "ДАРИНА", "text": "Обещаешь?"},
	{"speaker": "КАРОЛИНА", "text": "Обещаю."},
]

var elapsed: float = 0.0
var finished: bool = false
var clip_index: int = 0
var clip_transitioning: bool = false
var current_dialogue_index: int = -1
var dialogue_started: bool = false

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var title: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var dialogue: Panel = $Dialogue
@onready var speaker: Label = $Dialogue/Speaker
@onready var text_label: Label = $Dialogue/Text
@onready var prompt: Label = $Prompt
@onready var fade: ColorRect = $Fade

func _ready() -> void:
	dialogue.visible = false
	prompt.visible = false
	title.visible = true
	subtitle.visible = true
	video_player.expand = true
	video_player.volume_db = -80.0
	video_player.finished.connect(_on_video_finished)
	fade.visible = true
	fade.modulate.a = 1.0
	_play_clip(0)
	var intro: Tween = create_tween()
	intro.tween_property(fade, "modulate:a", 0.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_clip(index: int) -> void:
	if index < 0 or index >= VIDEO_CLIPS.size():
		return
	clip_index = index
	var stream := VideoStreamTheora.new()
	stream.file = VIDEO_CLIPS[clip_index]
	video_player.stream = stream
	video_player.play()

func _on_video_finished() -> void:
	if finished or clip_transitioning:
		return
	match clip_index:
		0:
			# Opening visual only. The dialogue begins on the second video.
			_transition_to_clip(FIRST_DIALOGUE_VIDEO_INDEX)
			_show_dialogue(FIRST_DIALOGUE_INDEX)
		1:
			# The entire first dialogue block stays on this video.
			if current_dialogue_index <= FIRST_DIALOGUE_LAST_INDEX:
				video_player.play()
			else:
				_transition_to_clip(2)
		2:
			# Silent visual transition. No dialogue is shown on this video.
			_transition_to_clip(FINAL_DIALOGUE_VIDEO_INDEX)
			_show_dialogue(FINAL_DIALOGUE_START_INDEX)
		3:
			# The entire remaining dialogue block stays on this video.
			if current_dialogue_index < FINAL_DIALOGUE_INDEX:
				video_player.play()
			else:
				_start_game()

func _transition_to_clip(index: int) -> void:
	if finished or clip_transitioning:
		return
	clip_transitioning = true
	var transition: Tween = create_tween()
	transition.tween_property(fade, "modulate:a", 0.72, CLIP_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	transition.tween_callback(func(): _play_clip(index))
	transition.tween_property(fade, "modulate:a", 0.0, CLIP_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	transition.tween_callback(func(): clip_transitioning = false)

func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	_update_title()

func _update_title() -> void:
	if elapsed <= TITLE_END:
		title.visible = true
		subtitle.visible = true
		var alpha: float = _smoothstep(clampf(elapsed / TITLE_END, 0.0, 1.0))
		if elapsed > 1.45:
			alpha = 1.0 - _smoothstep(clampf((elapsed - 1.45) / 0.75, 0.0, 1.0))
		title.modulate.a = alpha
		subtitle.modulate.a = alpha
	else:
		title.visible = false
		subtitle.visible = false

func _show_dialogue(dialogue_index: int) -> void:
	if dialogue_index < 0 or dialogue_index >= DIALOGUE_DATA.size():
		return
	var data: Dictionary = DIALOGUE_DATA[dialogue_index]
	dialogue.visible = true
	dialogue.modulate.a = 0.0
	speaker.text = String(data["speaker"])
	text_label.text = String(data["text"])
	current_dialogue_index = dialogue_index
	dialogue_started = true
	prompt.visible = true
	prompt.text = "Нажмите, чтобы продолжить"
	var dialogue_fade: Tween = create_tween()
	dialogue_fade.tween_property(dialogue, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _hide_dialogue_for_transition() -> void:
	dialogue.visible = false
	prompt.visible = false
	dialogue_started = false

func _advance_dialogue() -> void:
	if finished or clip_transitioning or not dialogue_started:
		return
	if current_dialogue_index < FINAL_DIALOGUE_INDEX:
		var next_index: int = current_dialogue_index + 1
		# The first dialogue block ends here. Hide the UI so the third video is completely silent.
		if current_dialogue_index == FIRST_DIALOGUE_LAST_INDEX and clip_index == FIRST_DIALOGUE_VIDEO_INDEX:
			_hide_dialogue_for_transition()
			_transition_to_clip(2)
			return
		_show_dialogue(next_index)
		return
	_start_game()

func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventScreenTouch and event.pressed:
		_advance_dialogue()
	elif event is InputEventMouseButton and event.pressed:
		_advance_dialogue()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_start_game()

func _start_game() -> void:
	if finished:
		return
	finished = true
	prompt.visible = false
	dialogue.visible = false
	video_player.stop()
	fade.visible = true
	fade.modulate.a = 0.0
	var outro: Tween = create_tween()
	outro.tween_property(fade, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	outro.tween_callback(func(): get_tree().change_scene_to_file("res://game.tscn"))

func _smoothstep(value: float) -> float:
	var p: float = clampf(value, 0.0, 1.0)
	return p * p * (3.0 - 2.0 * p)
