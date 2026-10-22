class_name RepeatPanel
extends Control
## "Magic Mirror" listen-and-repeat controller (missions 4, 33-36).
##
## Plays the target sentence, offers a Replay button, and a big Magic
## Microphone button to confirm. Because 7-year-olds play in a classroom and
## speech recognition is unreliable for a pre-A1 accent, the microphone is
## *gamified*: pressing it always succeeds once the child has listened to the
## sentence at least once. The reward is real, the pressure is not.
##
##     var panel := RepeatPanel.new()
##     add_child(panel)
##     panel.start(mission, hud)
##     panel.finished.connect(...)

signal finished
signal line_completed(index: int, total: int)

const MIN_LISTEN_TIME := 0.6

## Panel geometry and the inner width its wrapped text is laid out at (see
## `UiKit.label` for why that width must be explicit).
const PANEL_W := 840.0
const PANEL_H := 540.0
const WRAP_WIDTH := 700.0

var _lines: Array = []
var _index: int = 0
var _played_once := false
var _listened_at := 0.0

var _sentence: Label
var _translation: Label
var _counter: Label
var _mic_button: Button
var _replay_button: Button
var _pulse_tween: Tween
var _ring: PanelContainer
## The full-screen backdrop and framed panel, kept so folding can take both away.
var _scrim: ColorRect
var _panel: PanelContainer
## The pill left behind by a folded mirror, carrying the line counter.
var _fold_tab: Button
var _folded := false

## Mirrors the quiz's ratio here: a mirror sentence is read, not answered, so the
## six seconds are counted from the moment the voice stops rather than from the
## moment the panel appears.
const AUTO_FOLD_TIME := 8.0


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	_scrim = UiKit.scrim(0.55)
	add_child(_scrim)

	var panel := UiKit.panel(UiKit.COL_PANEL, UiKit.COL_BLUE)
	_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_BLUE, 6, 36))
	add_child(panel)

	var m := UiKit.margin(24)
	panel.add_child(m)
	var v := UiKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)

	var header := UiKit.hbox(10)
	v.add_child(header)
	var title := UiKit.label("THE MAGIC MIRROR", 24, UiKit.COL_BLUE, HORIZONTAL_ALIGNMENT_CENTER, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_counter = UiKit.label("", 22, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
	header.add_child(_counter)

	# A mirror frame: the ghostly face of Echo lives in here.
	_ring = UiKit.panel(UiKit.COL_PANEL.lightened(0.1), UiKit.COL_BLUE.lightened(0.3))
	_ring.custom_minimum_size = Vector2(0, 122)
	_ring.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_BLUE.darkened(0.55), UiKit.COL_BLUE, 5, 60))
	var echo := TextureRect.new()
	echo.texture = UiKit.icon_texture("ghost", "white", 160)
	echo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	echo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	echo.custom_minimum_size = Vector2(110, 110)
	echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.add_child(echo)
	v.add_child(_ring)

	_sentence = UiKit.label("", 38, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	_sentence.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sentence.custom_minimum_size = Vector2(WRAP_WIDTH, 66)
	v.add_child(_sentence)

	_translation = UiKit.label("", 28, UiKit.COL_PINK, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	_translation.visible = false
	v.add_child(_translation)

	var buttons := UiKit.hbox(20)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons)

	_replay_button = UiKit.button("LISTEN AGAIN", UiKit.icon_texture("speaker", "white", 80), Vector2(300, 92))
	_replay_button.pressed.connect(_on_replay)
	buttons.add_child(_replay_button)

	_mic_button = UiKit.button("SAY IT!", UiKit.icon_texture("mic", "green", 80), Vector2(280, 92))
	_mic_button.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.COL_GREEN.darkened(0.5), UiKit.COL_GREEN, 5, 26))
	_mic_button.add_theme_stylebox_override("hover", UiKit.panel_style(UiKit.COL_GREEN.darkened(0.35), UiKit.COL_GREEN.lightened(0.25), 6, 26))
	_mic_button.add_theme_stylebox_override("pressed", UiKit.panel_style(UiKit.COL_GREEN.darkened(0.6), UiKit.COL_GREEN, 5, 26))
	_mic_button.pressed.connect(_on_mic)
	buttons.add_child(_mic_button)

	var help := UiKit.hbox(8)
	help.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(help)
	var magnifier := UiKit.button("", UiKit.icon_texture("magnifier", "pink", 80), Vector2(72, 56))
	magnifier.tooltip_text = "Italian translation (H)"
	magnifier.pressed.connect(func():
		_translation.visible = not _translation.visible
		if _translation.visible:
			AudioFx.speak(_translation.text, "it")
	)
	help.add_child(magnifier)

	# Folding the mirror. The sentence is spoken, not read, so a child who has
	# listened once can put the frame away and still answer with SAY IT!.
	var fold_btn := UiKit.button("–", null, Vector2(62, 56))
	fold_btn.add_theme_font_size_override("font_size", 28)
	fold_btn.tooltip_text = "Put the mirror away for a moment"
	fold_btn.pressed.connect(fold_away)
	help.add_child(fold_btn)

	_fold_tab = UiKit.button("MIRROR", UiKit.icon_texture("ghost", "white", 64), Vector2(190, 52))
	_fold_tab.add_theme_font_size_override("font_size", 22)
	_fold_tab.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_fold_tab.offset_left = -95
	_fold_tab.offset_right = 95
	_fold_tab.offset_top = 104
	_fold_tab.offset_bottom = 156
	_fold_tab.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_BLUE, 4, 24))
	_fold_tab.add_theme_stylebox_override("hover",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.14), UiKit.COL_BLUE.lightened(0.2), 5, 24))
	_fold_tab.tooltip_text = "Show the mirror again"
	_fold_tab.visible = false
	_fold_tab.pressed.connect(unfold)
	add_child(_fold_tab)


## Starts the exercise with the mission's `lines` array.
func start(mission: Dictionary) -> void:
	_lines = mission.get("lines", [])
	_index = 0
	visible = true
	_folded = false
	if _scrim != null:
		_scrim.visible = true
	if _panel != null:
		_panel.visible = true
	if _fold_tab != null:
		_fold_tab.visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	# Gamepad / Tab: the replay button is the first thing the exercise asks for.
	UiKit.focus_first_button(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	if _lines.is_empty():
		push_warning("RepeatPanel: mission has no lines")
		return
	_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	_sentence.text = String(line.get("en", ""))
	_translation.text = String(line.get("it", ""))
	_translation.visible = false
	_counter.text = "%d / %d" % [_index + 1, _lines.size()]
	_played_once = false
	_listened_at = 0.0
	_start_mic_pulse()
	# Give the child a moment before the voice starts, so it never overlaps
	# the previous screen's audio.
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	AudioFx.speak(_sentence.text)
	_played_once = true
	_listened_at = Time.get_ticks_msec() / 1000.0
	# Auto-fold once the sentence has had time to be listened to twice. Never
	# while the mirror is already folded, and never for a line the child has
	# already answered in the meantime.
	#
	# `visible` is checked as well as the token: closing the panel does not
	# remove it from the tree (it is a child of the mission controller), so a
	# timer left over from a closed mirror would otherwise fire on the next
	# one and fold it before it had been read.
	var token := _index
	await get_tree().create_timer(AUTO_FOLD_TIME).timeout
	if not is_inside_tree() or not visible or token != _index or _folded:
		return
	var q := UiKit._quest_manager()
	if q != null and bool(q.get("auto_hide_ui")):
		fold_away()


func _start_mic_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_mic_button.modulate = Color(1, 1, 1, 0.75)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_mic_button, "modulate:a", 1.0, 0.8)
	_pulse_tween.tween_property(_mic_button, "modulate:a", 0.7, 0.8)


func _on_replay() -> void:
	AudioFx.speak(_sentence.text)
	_played_once = true
	_listened_at = Time.get_ticks_msec() / 1000.0


func _on_mic() -> void:
	# The microphone only answers once the child has heard the sentence: that
	# is the whole "listen and repeat" instruction, enforced kindly.
	var now := Time.get_ticks_msec() / 1000.0
	if not _played_once or (now - _listened_at) < MIN_LISTEN_TIME:
		AudioFx.speak("Listen first, then say it!")
		AudioFx.play_sfx("soft")
		return

	AudioFx.play_sfx("magic")
	_mic_button.text = "GREAT!"
	_ring.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_GREEN.darkened(0.5), UiKit.COL_GREEN, 6, 60))
	line_completed.emit(_index + 1, _lines.size())
	QuestManager.step_changed.emit(_index + 1, _lines.size())
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	_ring.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_BLUE.darkened(0.55), UiKit.COL_BLUE, 5, 60))
	_mic_button.text = "SAY IT!"
	_show_line()


func _finish() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_folded = false
	if _fold_tab != null:
		_fold_tab.visible = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func():
		visible = false
		finished.emit()
	)


func close() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_folded = false
	if _fold_tab != null:
		_fold_tab.visible = false
	if _scrim != null:
		_scrim.visible = true
	if _panel != null:
		_panel.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Puts the mirror away without losing the sentence or the line count.
func fold_away() -> void:
	if _folded:
		return
	_folded = true
	if _scrim != null:
		_scrim.visible = false
	if _panel != null:
		_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _fold_tab != null:
		_fold_tab.text = "MIRROR %d/%d" % [_index + 1, maxi(_lines.size(), 1)]
		_fold_tab.visible = true
		_fold_tab.grab_focus()


func unfold() -> void:
	if not _folded:
		return
	_folded = false
	if _fold_tab != null:
		_fold_tab.visible = false
	if _scrim != null:
		_scrim.visible = true
	if _panel != null:
		_panel.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _replay_button != null:
		_replay_button.grab_focus()


func is_folded() -> bool:
	return _folded


## True when a screen point lands on the MIRROR pill.
func blocks_point(at: Vector2) -> bool:
	if _fold_tab == null or not _fold_tab.visible:
		return false
	return _fold_tab.get_global_rect().has_point(at)
