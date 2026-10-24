class_name PauseMenu
extends Control
## The pause / settings panel.
##
## Deliberately minimal for a 7-year-old: resume, hear the task again, restart
## this mission, change the controls, one row to choose the *difficulty*, and two
## accessibility switches (easy-read font, sound). No timers, no scores, no death.
##
## Everything the child or the teacher can change lives on this one page — there
## is no nested settings tree to get lost in. "CHANGE CONTROLS" opens
## `ControlsPanel`, which is the only place keys can be rebound.
##
## The difficulty row is a pair of big arrows around the level's name rather
## than a slider: a slider is a continuous control a small hand cannot aim, while
## three named levels with a visible name are something a child can read back.
## The name is spelled out in English on purpose ("LOTS OF HELP" / "SOME HELP" /
## "ALL BY MYSELF"), so the setting doubles as three more English phrases.

signal resume_pressed
signal help_pressed
signal quit_pressed
signal restart_zone_pressed
signal controls_pressed
## The `<` / `>` arrows: -1 asks for less help, +1 for more.
signal difficulty_pressed(step: int)
signal easy_read_changed(enabled: bool)
signal sound_changed(enabled: bool)
## Opens the dedicated volume page (music and sound effects, separately).
signal sound_settings_pressed
## Opens the teacher menu: every mission, jump straight to any of them.
##
## It sits at the very bottom of the page, under its own divider, because it is
## the one control here that is *not* for the child. Nothing protects it — see
## `TeacherMenu` for why a password would be theatre — so its only defence is
## being visually outside the list of things a child came here to do.
signal teacher_pressed

## Panel height in design pixels. It stacks a title, four actions, a divider,
## the difficulty row, two switches and QUIT. The row heights and the compact
## button padding below are sized so the total stays under 720 px — the layout
## probe (`tools/layout_check.gd`) fails the build if that ever stops being true.
const PANEL_H := 700.0
const PANEL_W := 720.0

var _easy_read_toggle: CheckButton
var _sound_toggle: CheckButton
var _difficulty_name: Label
var _difficulty_detail: Label
var _difficulty_left: Button
var _difficulty_right: Button


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	add_child(UiKit.scrim(0.66))

	var panel := UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ACCENT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ACCENT, 6, 36))
	add_child(panel)

	var m := UiKit.margin(18)
	panel.add_child(m)
	var v := UiKit.vbox(7)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)

	var title := UiKit.label("PAUSE", 36, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, false)
	v.add_child(title)

	var resume := _compact(UiKit.button("KEEP PLAYING", null, Vector2(430, 62)))
	resume.add_theme_stylebox_override("normal", _style(UiKit.COL_GREEN.darkened(0.45), UiKit.COL_GREEN, 5, 26))
	resume.add_theme_stylebox_override("hover", _style(UiKit.COL_GREEN.darkened(0.3), UiKit.COL_GREEN.lightened(0.25), 6, 26))
	resume.add_theme_stylebox_override("pressed", _style(UiKit.COL_GREEN.darkened(0.55), UiKit.COL_GREEN, 5, 26))
	resume.pressed.connect(func(): resume_pressed.emit())
	v.add_child(resume)

	var listen := _compact(UiKit.button("HEAR THE TASK AGAIN",
		UiKit.icon_texture("speaker", "white", 80), Vector2(430, 58)))
	listen.pressed.connect(func(): help_pressed.emit())
	v.add_child(listen)

	var restart := _compact(UiKit.button("START THIS MISSION AGAIN", null, Vector2(430, 58)))
	restart.pressed.connect(func(): restart_zone_pressed.emit())
	v.add_child(restart)

	# The keys live on their own page: one row per action is far too much
	# information for the pause screen itself.
	var controls := _compact(UiKit.button("CHANGE CONTROLS", null, Vector2(430, 58)))
	controls.add_theme_stylebox_override("normal", _style(UiKit.COL_BLUE.darkened(0.5), UiKit.COL_BLUE, 5, 26))
	controls.add_theme_stylebox_override("hover", _style(UiKit.COL_BLUE.darkened(0.35), UiKit.COL_BLUE.lightened(0.25), 6, 26))
	controls.pressed.connect(func(): controls_pressed.emit())
	v.add_child(controls)

	var divider := ColorRect.new()
	divider.color = UiKit.COL_TEXT_DIM.darkened(0.3)
	divider.custom_minimum_size = Vector2(0, 3)
	v.add_child(divider)

	# --- Difficulty: big arrows around a name a child can read back ---
	var diff := UiKit.hbox(12)
	diff.alignment = BoxContainer.ALIGNMENT_CENTER
	diff.custom_minimum_size = Vector2(0, 58)
	v.add_child(diff)

	_difficulty_left = _compact(UiKit.button("<", null, Vector2(64, 58)))
	_difficulty_left.add_theme_font_size_override("font_size", 32)
	_difficulty_left.tooltip_text = "Less help"
	_difficulty_left.pressed.connect(func(): difficulty_pressed.emit(-1))
	diff.add_child(_difficulty_left)

	var names := UiKit.vbox(0)
	names.custom_minimum_size = Vector2(300, 0)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	# Single-line labels inside an HBox: no wrapping (see `UiKit.label`).
	_difficulty_name = UiKit.label("", 27, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, false)
	_difficulty_detail = UiKit.label("", 18, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
	names.add_child(_difficulty_name)
	names.add_child(_difficulty_detail)
	diff.add_child(names)

	_difficulty_right = _compact(UiKit.button(">", null, Vector2(64, 58)))
	_difficulty_right.add_theme_font_size_override("font_size", 32)
	_difficulty_right.tooltip_text = "More help"
	_difficulty_right.pressed.connect(func(): difficulty_pressed.emit(1))
	diff.add_child(_difficulty_right)

	# --- Accessibility switches ---
	var easy_row := UiKit.hbox(14)
	easy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	easy_row.custom_minimum_size = Vector2(0, 46)
	var easy_label := UiKit.label("Easy-read letters", 25, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	easy_label.custom_minimum_size = Vector2(300, 0)
	easy_row.add_child(easy_label)
	_easy_read_toggle = CheckButton.new()
	_easy_read_toggle.button_pressed = QuestManager.easy_read
	_easy_read_toggle.toggled.connect(func(v_on: bool): easy_read_changed.emit(v_on))
	easy_row.add_child(_easy_read_toggle)
	v.add_child(easy_row)

	var sound_row := UiKit.hbox(14)
	sound_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sound_row.custom_minimum_size = Vector2(0, 46)
	var sound_label := UiKit.label("Sound", 25, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	sound_label.custom_minimum_size = Vector2(300, 0)
	sound_row.add_child(sound_label)
	_sound_toggle = CheckButton.new()
	_sound_toggle.button_pressed = QuestManager.sound_on
	_sound_toggle.toggled.connect(func(v_on: bool): sound_changed.emit(v_on))
	sound_row.add_child(_sound_toggle)
	# The volumes and the camera view live one page deeper, next to the switch
	# that silences everything: a child who turns the music off and then wants it
	# back looks in the same place they found the switch, not on a separate
	# settings menu. The button says SETTINGS rather than LEVELS now that the page
	# holds the VIEW row too.
	var levels := _compact(UiKit.button("SETTINGS", null, Vector2(150, 44)))
	levels.add_theme_font_size_override("font_size", 22)
	levels.tooltip_text = "Music, sounds and the camera view"
	levels.add_theme_stylebox_override("normal", _style(UiKit.COL_BLUE.darkened(0.5), UiKit.COL_BLUE, 4, 18))
	levels.add_theme_stylebox_override("hover", _style(UiKit.COL_BLUE.darkened(0.35), UiKit.COL_BLUE.lightened(0.25), 5, 18))
	levels.pressed.connect(func(): sound_settings_pressed.emit())
	sound_row.add_child(levels)
	v.add_child(sound_row)

	var quit := _compact(UiKit.button("QUIT", null, Vector2(240, 56)))
	quit.add_theme_stylebox_override("normal", _style(UiKit.COL_PANEL.darkened(0.1), UiKit.COL_SOFT_RED, 4, 22))
	quit.pressed.connect(func(): quit_pressed.emit())
	v.add_child(quit)

	# --- Teacher: last, and behind its own divider ---
	#
	# The one control on this page that is not for the child. A divider is the
	# whole of its protection: the page had 61 px of slack before this row
	# existed (measured 639 of content inside a 700 px frame), and the row costs
	# 2 px of rule + 2 px of gap + the button. `layout_check.gd` measured the
	# first attempt at 699 of 700 — fitting, but with no room for a font change —
	# so the button's own padding was cut to 2 px above and below (see
	# `_compact_flat()`) rather than shrinking the label or the touch target.
	#
	# Its own divider rather than sharing the one above the difficulty row: that
	# divider groups "the things you change", and the teacher button is neither
	# one of those nor one of the actions above it.
	var teacher_divider := ColorRect.new()
	teacher_divider.color = UiKit.COL_TEXT_DIM.darkened(0.3)
	teacher_divider.custom_minimum_size = Vector2(0, 2)
	v.add_child(teacher_divider)

	var teacher := UiKit.button("TEACHER MENU", null, Vector2(430, 40))
	teacher.add_theme_font_size_override("font_size", 21)
	teacher.tooltip_text = "Open any mission, for the teacher"
	teacher.add_theme_stylebox_override("normal", _style(UiKit.COL_PANEL.darkened(0.15), UiKit.COL_TEXT_DIM.darkened(0.35), 3, 20))
	teacher.add_theme_stylebox_override("hover", _style(UiKit.COL_PANEL.darkened(0.05), UiKit.COL_BLUE, 4, 20))
	teacher.pressed.connect(func(): teacher_pressed.emit())
	# Flattened *after* its styles are in place: the helper rewrites the padding
	# of the boxes it finds, so calling it first would only see the theme's own.
	_compact_flat(teacher)
	v.add_child(teacher)

	refresh_difficulty()


## Tighter vertical padding than the shared theme (14 px each side). This page
## stacks six buttons plus two switch rows; at the theme's padding the page
## measured over 720 px tall and the layout probe failed it.
func _compact(button: Button) -> Button:
	button.add_theme_stylebox_override("normal", _style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_ACCENT, 6))
	button.add_theme_stylebox_override("hover", _style(UiKit.COL_PANEL.lightened(0.16), UiKit.COL_ACCENT.lightened(0.2), 8))
	button.add_theme_stylebox_override("focus", _style(UiKit.COL_PANEL.lightened(0.16), UiKit.COL_ACCENT.lightened(0.2), 8))
	button.add_theme_stylebox_override("pressed", _style(UiKit.COL_PANEL.darkened(0.08), UiKit.COL_ACCENT, 6))
	return button


func _style(fill: Color, border: Color, border_width: int, radius: int = 24) -> StyleBoxFlat:
	var style := UiKit.panel_style(fill, border, border_width, radius)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


## Squeezes the vertical padding of the style boxes a button already carries.
##
## Only the teacher button uses it, and it is *not* a variant of `_compact()`:
## that one installs a whole set of styles and would overwrite the two the
## teacher row sets for itself (a dimmer fill, a blue hover). This one only
## rewrites the padding of whatever boxes are already there, which is why it has
## to be called after them.
func _compact_flat(button: Button) -> Button:
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		if style != null:
			style.content_margin_top = 2
			style.content_margin_bottom = 2
	return button


## Shows the current level's name and its one-line explanation, and disables an
## arrow at the end of the range so a child can see there is nothing beyond.
##
## Public because `Main` calls it when the level changes from somewhere else —
## re-opening the whole menu just to redraw one row would replay its fade.
func refresh_difficulty() -> void:
	var info := Hints.current_level_info()
	_difficulty_name.text = String(info.get("name", ""))
	_difficulty_detail.text = String(info.get("detail", ""))
	var level := Hints.level()
	_difficulty_left.disabled = level <= Hints.MIN_LEVEL
	_difficulty_right.disabled = level >= Hints.MAX_LEVEL


## Opens the panel. `_delay` is unused but keeps the call site readable.
func open(_delay: float = 0.0) -> void:
	visible = true
	modulate.a = 0.0
	_easy_read_toggle.set_pressed_no_signal(QuestManager.easy_read)
	_sound_toggle.set_pressed_no_signal(QuestManager.sound_on)
	refresh_difficulty()
	# A controller has no pointer: without a focused button the page cannot be
	# used at all. The first pressable control is KEEP PLAYING, which is also
	# the safest thing to land on if a child leans on the A button.
	UiKit.focus_first_button(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	visible = false


## Puts the Sound switch back in step with the value behind it without firing
## `toggled`, which would send the change straight back as a new command.
func sync_sound_toggle(on: bool) -> void:
	if _sound_toggle != null:
		_sound_toggle.set_pressed_no_signal(on)
