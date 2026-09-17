extends Control

# ACORN HUNTER — visual-novel intro.
# The intro is now built from four pre-rendered cinematic video clips.
# Godot handles sequencing, dialogue, skip, and the final transition only.
const VIDEO_CLIPS: Array[String] = [
	"res://assets/intro_video/1789649201942.ogv",
	"res://assets/intro_video/1789650878847.ogv",
	"res://assets/intro_video/1789650644963.ogv",
	"res://assets/intro_video/1789649329293.ogv",
]

const INTRO_DURATION_FALLBACK: float = 18.3
const CLIP_FADE_DURATION: float = 0.16
const TITLE_END: float = 2.2
const PROMPT_START: float = 1.0

const DIALOGUE_DATA: Array[Dictionary] = [
	{
		"speaker": "ДАРИНА",
		"text": "Оййй...\nА нам, кстати, поделку на завтра задали..........",
		"start_time": 4.4,
		"end_time": 7.0,
		"fade_in_duration": 0.35,
	},
	{
		"speaker": "ДАРИНА",
		"text": "А я уже хотела с игрушкой играть...",
		"start_time": 8.8,
		"end_time": 11.4,
	},
	{
		"speaker": "КАРОЛИНА",
		"text": "...Ладно. Сделаем эту поделку.",
		"start_time": 11.4,
		"end_time": 14.6,
	},
	{
		"speaker": "ДАРИНА",
		"text": "УРААА! А жёлуди потом найдём?",
		"start_time": 14.6,
		"end_time": 18.3,
	},
]

var elapsed: float = 0.0
var finished: bool = false
var clip_index: int = 0
var clip_lengths: Array[float] = []
var intro_duration: float = INTRO_DURATION_FALLBACK
var current_dialogue_index: int = -1
var clip_transitioning: bool = false

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

	_load_clip_lengths()
	_play_clip(0)

	var intro: Tween = create_tween()
	intro.tween_property(
		fade,
		"modulate:a",
		0.0,
		0.85
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _load_clip_lengths() -> void:
	clip_lengths.clear()

	for path in VIDEO_CLIPS:
		var stream := VideoStreamTheora.new()
		stream.file = path
		var length: float = stream.get_length()
		if length <= 0.0:
			length = INTRO_DURATION_FALLBACK / VIDEO_CLIPS.size()
		clip_lengths.append(length)

	var total: float = 0.0
	for length in clip_lengths:
		total += length

	if total > 0.0:
		intro_duration = total

func _play_clip(index: int) -> void:
	if index < 0 or index >= VIDEO_CLIPS.size():
		_start_game()
		return

	clip_index = index
	var stream := VideoStreamTheora.new()
	stream.file = VIDEO_CLIPS[clip_index]
	video_player.stream = stream
	video_player.play()

func _on_video_finished() -> void:
	if finished or clip_transitioning:
		return

	if clip_index + 1 < VIDEO_CLIPS.size():
		clip_transitioning = true
		var transition: Tween = create_tween()
		transition.tween_property(
			fade,
			"modulate:a",
			0.72,
			CLIP_FADE_DURATION
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		transition.tween_callback(func():
			_play_clip(clip_index + 1)
		)
		transition.tween_property(
			fade,
			"modulate:a",
			0.0,
			CLIP_FADE_DURATION
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		transition.tween_callback(func():
			clip_transitioning = false
		)
	else:
		_start_game()

func _process(delta: float) -> void:
	if finished:
		return

	elapsed += delta

	_update_title()
	_update_dialogue()
	prompt.visible = elapsed > PROMPT_START

	if elapsed >= intro_duration + 0.15 and not clip_transitioning:
		_start_game()

func _update_title() -> void:
	if elapsed <= TITLE_END:
		title.visible = true
		subtitle.visible = true

		var alpha: float = _smoothstep(clampf(elapsed / TITLE_END, 0.0, 1.0))
		if elapsed > 1.45:
			alpha = 1.0 - _smoothstep(
				clampf((elapsed - 1.45) / 0.75, 0.0, 1.0)
			)

		title.modulate.a = alpha
		subtitle.modulate.a = alpha
	else:
		title.visible = false
		subtitle.visible = false

func _update_dialogue() -> void:
	var target_index: int = -1

	for index in DIALOGUE_DATA.size():
		var data: Dictionary = DIALOGUE_DATA[index]
		var start_time: float = float(data["start_time"])
		var end_time: float = float(data["end_time"])

		if elapsed >= start_time and elapsed < end_time:
			target_index = index
			break

	if target_index == current_dialogue_index:
		return

	if target_index < 0:
		dialogue.visible = false
		current_dialogue_index = -1
		return

	_show_dialogue(target_index)

func _show_dialogue(dialogue_index: int) -> void:
	var data: Dictionary = DIALOGUE_DATA[dialogue_index]

	dialogue.visible = true
	dialogue.modulate.a = 0.0
	speaker.text = String(data["speaker"])
	text_label.text = String(data["text"])
	current_dialogue_index = dialogue_index

	var fade_in_duration: float = float(data.get("fade_in_duration", 0.0))
	if fade_in_duration > 0.0:
		var dialogue_fade: Tween = create_tween()
		dialogue_fade.tween_property(
			dialogue,
			"modulate:a",
			1.0,
			fade_in_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		dialogue.modulate.a = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if elapsed <= 1.0:
		return

	if event is InputEventScreenTouch and event.pressed:
		_start_game()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()
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
	outro.tween_property(
		fade,
		"modulate:a",
		1.0,
		0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	outro.tween_callback(
		func():
			get_tree().change_scene_to_file("res://game.tscn")
	)

func _smoothstep(value: float) -> float:
	var p: float = clampf(value, 0.0, 1.0)
	return p * p * (3.0 - 2.0 * p)
