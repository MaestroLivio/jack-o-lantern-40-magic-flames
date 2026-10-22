class_name StoryScreen
extends Control
## The story page between missions.
##
## This is the one screen in the game written for the *teacher* as much as for
## the child. It opens before a chapter's mission and stays on screen until
## somebody closes it — there is no auto-advance, no timer, no "skip" that
## punishes waiting. A class can sit on one page for ten minutes, read it line by
## line, press the speaker on any single line, and talk about the words.
##
## Reading controls, all of them optional:
##   * **each line is its own button**, so a teacher can re-hear just the tricky
##     sentence instead of restarting the whole page;
##   * **the magnifier** swaps the footer for the Italian teaching note — the
##     only Italian in the game that is meant for the adult, never automatic;
##   * **the keyword row** shows the words worth pausing on, with their picture,
##     and respects the difficulty setting (`Hints`): at the highest level the
##     pictures are withdrawn and only the words remain;
##   * **pause** freezes the page and dims it without closing it, so attention
##     can move to the class and back;
##   * **GO ON** is the only way out, and it is a big friendly button.
##
## Line buttons are real `Button`s, so the page also works end to end with a
## gamepad or with Tab + Enter — the same focus model as every other panel.

signal finished
## Emitted when the teacher asks for a pause / resume on this page, so `Main`
## can keep its own screen state in step (and stop the world from reacting).
signal pause_toggled(paused: bool)

## Panel geometry in 1280x720 design pixels. The page is allowed to be tall:
## story text is the whole point here. `tools/layout_check.gd` verifies that the
## minimum size still fits inside the design viewport.
const PANEL_W := 1040.0
const PANEL_H := 660.0
const WRAP_WIDTH := 900.0
## Height of one clickable line. Fixed so a chapter with five lines and one with
## three still lay out predictably.
##
## 48 px rather than 54: the teacher's Italian note can wrap to three lines in
## the reserved footer slot, and at the old height the longest pages measured
## 714 px against a 720 px viewport. That is technically "inside", but six
## pixels of slack is not a margin — a longer note added later would push the
## GO ON button off the screen, so the page was given real headroom instead.
const LINE_H := 48.0

var _chapter: Dictionary = {}
var _paused := false
var _italian_notes := false

var _panel: PanelContainer
var _title: Label
var _counter: Label
var _line_box: VBoxContainer
var _question: Label
var _word_row: HBoxContainer
var _notes: Label
var _pause_button: Button
var _magnifier: Button
var _go_button: Button
## Live fade, kept so opening a second page in the same second cannot leave a
## half-faded page behind (two tweens writing `modulate:a` would fight).
var _fade: Tween
## Every clickable line, so pause can disable them all at once.
var _line_buttons: Array[Button] = []
var _line_texts: Array[String] = []


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	add_child(UiKit.scrim(0.7))

	_panel = UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ACCENT)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -PANEL_W * 0.5
	_panel.offset_right = PANEL_W * 0.5
	_panel.offset_top = -PANEL_H * 0.5
	_panel.offset_bottom = PANEL_H * 0.5
	# The chapter colour is applied per page in `open()`.
	_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ACCENT, 6, 34))
	add_child(_panel)

	var m := UiKit.margin(22)
	_panel.add_child(m)
	var v := UiKit.vbox(8)
	m.add_child(v)

	# --- Header: chapter label on the left, page counter on the right ---
	var header := UiKit.hbox(12)
	v.add_child(header)
	var badge := UiKit.label("STORY", 22, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, false)
	header.add_child(badge)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_counter = UiKit.label("", 20, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
	header.add_child(_counter)

	_title = UiKit.label("", 40, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	_title.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	v.add_child(_title)

	var divider := ColorRect.new()
	divider.color = UiKit.COL_ACCENT.darkened(0.35)
	divider.custom_minimum_size = Vector2(0, 3)
	v.add_child(divider)

	# --- The lines themselves, each one a button ---
	_line_box = UiKit.vbox(4)
	_line_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_line_box)

	_question = UiKit.label("", 28, UiKit.COL_PINK, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	v.add_child(_question)

	# --- Keywords, with or without their picture depending on difficulty ---
	_word_row = UiKit.hbox(14)
	_word_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_word_row)

	# One reserved note line. It holds the teacher's Italian note *or* the
	# instruction line, never both, so the page never re-flows under the mouse.
	#
	# The label is free to grow past this minimum: the longest `teacher_notes_it`
	# wraps to three lines, and clipping the end of the note would be the worst
	# possible failure on a page whose whole purpose is to be read by an adult.
	# `LINE_H` is what was trimmed to pay for that, not the note.
	_notes = UiKit.label("", 20, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	_notes.custom_minimum_size = Vector2(WRAP_WIDTH, 52)
	_notes.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(_notes)

	# --- Footer ---
	var footer := UiKit.hbox(14)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(footer)

	var listen_all := _compact(UiKit.button("", UiKit.icon_texture("speaker", "white", 80), Vector2(84, 62)))
	listen_all.tooltip_text = "Read the whole page again"
	listen_all.add_theme_stylebox_override("normal", _compact_style(UiKit.COL_BLUE.darkened(0.3), UiKit.COL_BLUE, 4))
	listen_all.add_theme_stylebox_override("hover", _compact_style(UiKit.COL_BLUE.darkened(0.15), UiKit.COL_BLUE.lightened(0.2), 5))
	listen_all.pressed.connect(_read_all)
	footer.add_child(listen_all)

	_pause_button = _compact(UiKit.button("PAUSE", null, Vector2(170, 62)))
	_pause_button.tooltip_text = "Freeze the page to talk about it"
	_pause_button.pressed.connect(_toggle_pause)
	footer.add_child(_pause_button)

	_magnifier = _compact(UiKit.button("", UiKit.icon_texture("magnifier", "pink", 80), Vector2(84, 62)))
	_magnifier.tooltip_text = "Note per l'insegnante"
	_magnifier.pressed.connect(_toggle_notes)
	footer.add_child(_magnifier)

	_go_button = _compact(UiKit.button("GO ON", UiKit.icon_texture("flame", "green", 80), Vector2(230, 62)))
	_go_button.add_theme_stylebox_override("normal", _compact_style(UiKit.COL_GREEN.darkened(0.45), UiKit.COL_GREEN, 5))
	_go_button.add_theme_stylebox_override("hover", _compact_style(UiKit.COL_GREEN.darkened(0.3), UiKit.COL_GREEN.lightened(0.25), 6))
	_go_button.pressed.connect(close)
	footer.add_child(_go_button)


## Buttons on the story page use tighter vertical padding than the game's menus:
## the page stacks five line buttons plus three footer buttons, and the shared
## theme's 14 px margin would push it past the 720 px design height (the same
## trap the controls page hit).
func _compact(button: Button) -> Button:
	button.add_theme_stylebox_override("normal", _compact_style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_ACCENT, 5))
	button.add_theme_stylebox_override("hover", _compact_style(UiKit.COL_PANEL.lightened(0.16), UiKit.COL_ACCENT.lightened(0.2), 6))
	button.add_theme_stylebox_override("focus", _compact_style(UiKit.COL_PANEL.lightened(0.16), UiKit.COL_ACCENT.lightened(0.2), 6))
	button.add_theme_stylebox_override("pressed", _compact_style(UiKit.COL_PANEL.darkened(0.08), UiKit.COL_ACCENT, 5))
	return button


func _compact_style(fill: Color, border: Color, border_width: int, radius: int = 22) -> StyleBoxFlat:
	var style := UiKit.panel_style(fill, border, border_width, radius)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


# --- Public API ------------------------------------------------------------

## Opens a page. `index`/`total` only drive the "story 3 of 12" counter; when
## they are left at 0 the page works them out from `Story` itself, so a caller
## cannot drift out of step with the book.
func open(chapter: Dictionary, index: int = 0, total: int = 0) -> void:
	if chapter.is_empty():
		return
	_chapter = chapter
	_paused = false
	_italian_notes = false
	visible = true
	modulate.a = 0.0

	var zone_id := int(chapter.get("zone", 1))
	var accent := Color(GameData.zone_info(zone_id).get("color", UiKit.COL_ACCENT))
	_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, accent, 6, 34))
	_title.add_theme_color_override("font_color", accent)

	_title.text = String(chapter.get("title", ""))
	if index <= 0:
		index = Story.page_number(int(chapter.get("mission", 0)))
	if total <= 0:
		total = Story.page_count()
	# A beat is a short page, not a chapter: saying so keeps the book honest
	# for a teacher who is following along.
	var is_beat := bool(chapter.get("beat", false))
	_counter.text = "%s %d / %d" % ["STORY" if is_beat else "CHAPTER", maxi(index, 1), maxi(total, 1)]
	_question.text = String(chapter.get("question", ""))
	_build_lines()
	_build_word_row()
	_apply_paused_look()

	_kill_fade()
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.25)
	# A gamepad has no pointer to aim with, so the page hands the focus to its
	# first line: D-pad down walks the page, A replays a line, and GO ON is two
	# taps away at the bottom of the same chain.
	if not _line_buttons.is_empty():
		_line_buttons[0].grab_focus()
	else:
		_go_button.grab_focus()
	# The page is read at the class's pace: only the title is spoken, so a
	# teacher can lead the rest. Everything else is one tap away.
	AudioFx.speak(String(chapter.get("title", "")))


func close() -> void:
	if not visible:
		return
	_paused = false
	_kill_fade()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.2)
	_fade.tween_callback(func():
		visible = false
		finished.emit()
	)


## Cancels the running fade. Two tweens writing `modulate:a` at once would fight:
## opening a page while the previous one is still fading out used to leave the
## new page stuck at half opacity — exactly the state a teacher would describe as
## "the text is greyed out".
func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null


func is_paused() -> bool:
	return _paused


## Redraws only the parts that depend on the difficulty setting.
##
## Called when the level changes while the page is open. Deliberately *not*
## `open()` again: that would un-pause the page, stop the teacher's reading and
## re-speak the title from the beginning. The text itself never changes with the
## level, so the lines are left alone.
func refresh_hints() -> void:
	if not visible or _chapter.is_empty():
		return
	_build_word_row()
	_restore_notes_text()


## Total number of readable pages, so `Main` can say "chapter 3 of 12".
static func chapter_count() -> int:
	return Story.page_count()


# --- Construction of the variable parts ------------------------------------

## Turns each line into a big button that speaks *that* line. A `Button` (not a
## plain Label) is what makes the page usable with a gamepad: D-pad up/down walks
## the lines, A replays one.
func _build_lines() -> void:
	for child in _line_box.get_children():
		_line_box.remove_child(child)
		child.queue_free()
	_line_buttons.clear()
	_line_texts.clear()

	var lines: Array = _chapter.get("lines", [])
	for i in lines.size():
		var text := String(lines[i])
		_line_texts.append(text)
		var button := Button.new()
		button.text = text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(WRAP_WIDTH, LINE_H)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 27)
		button.add_theme_color_override("font_color", UiKit.COL_TEXT)
		# A quiet "reading" style: no border until hover, so five lines read as
		# a paragraph rather than as five competing buttons.
		var quiet := _compact_style(UiKit.COL_PANEL.lightened(0.03), UiKit.COL_PANEL.lightened(0.10), 2, 16)
		quiet.content_margin_left = 16
		quiet.content_margin_right = 16
		button.add_theme_stylebox_override("normal", quiet)
		var loud := _compact_style(UiKit.COL_PANEL.lightened(0.14), UiKit.COL_ACCENT, 3, 16)
		loud.content_margin_left = 16
		loud.content_margin_right = 16
		button.add_theme_stylebox_override("hover", loud)
		button.add_theme_stylebox_override("focus", loud)
		button.add_theme_stylebox_override("pressed", loud)
		button.pressed.connect(_on_line_pressed.bind(i))
		_line_box.add_child(button)
		_line_buttons.append(button)


func _build_word_row() -> void:
	for child in _word_row.get_children():
		_word_row.remove_child(child)
		child.queue_free()

	var words: Array = _chapter.get("focus_words", [])
	_word_row.visible = not words.is_empty()
	if words.is_empty():
		return

	# Difficulty decides whether the picture is a crutch or a vocabulary test.
	var with_icons := Hints.word_chips_have_icons()
	for entry in words:
		var w: Dictionary = entry
		var chip := UiKit.hbox(8)
		if with_icons:
			var icon := TextureRect.new()
			icon.texture = UiKit.icon_texture(
				String(w.get("icon", "circle")),
				String(w.get("color", "gold")),
				72,
				int(w.get("number", 0)))
			icon.custom_minimum_size = Vector2(40, 40)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(icon)
		# Single words inside an HBox must not wrap (see `UiKit.label`).
		var label := UiKit.label(String(w.get("word", "")).to_upper(), 22,
			UiKit.COL_TEXT_DIM if with_icons else UiKit.COL_ACCENT,
			HORIZONTAL_ALIGNMENT_LEFT, false)
		chip.add_child(label)
		_word_row.add_child(chip)


## The one reserved line under the keywords. It carries exactly one message at a
## time — the teacher's Italian note, the "paused" reminder, or a short English
## reading hint — so the page never re-flows under a finger that is about to tap
## a line. Two competing hint labels (one here, one under the footer) used to
## fight over the same job and say different things at the same moment.
func _restore_notes_text() -> void:
	if _italian_notes:
		var note := String(_chapter.get("teacher_notes_it", ""))
		_notes.text = note if not note.is_empty() else "Nessuna nota per questa pagina."
		_notes.add_theme_color_override("font_color", UiKit.COL_PINK)
	elif _paused:
		_notes.text = "Paused. Read and talk about the words — tap RESUME when you are ready."
		_notes.add_theme_color_override("font_color", UiKit.COL_ACCENT)
	else:
		# The difficulty setting changes what is *shown*, so the reading hint has
		# to change with it: at the top level the pictures are gone and looking
		# at the word is the only clue left.
		if Hints.word_chips_have_icons():
			_notes.text = "Tap a line to hear it again. Tap PAUSE to stop and talk about the words."
		else:
			_notes.text = "Read the words: no picture clues at this level."
		_notes.add_theme_color_override("font_color", UiKit.COL_TEXT_DIM)
	_notes.visible = true


# --- Interaction -----------------------------------------------------------

func _on_line_pressed(index: int) -> void:
	if _paused or index < 0 or index >= _line_texts.size():
		return
	AudioFx.speak(_line_texts[index])
	# A quick highlight so the class can see which line is being read.
	var button := _line_buttons[index]
	var tween := create_tween()
	tween.tween_property(button, "modulate", Color(1.35, 1.25, 0.8), 0.12)
	tween.tween_property(button, "modulate", Color.WHITE, 0.3)


func _read_all() -> void:
	if _paused:
		return
	AudioFx.speak(Story.spoken_text(_chapter))


func _toggle_pause() -> void:
	_paused = not _paused
	_apply_paused_look()
	pause_toggled.emit(_paused)
	if _paused:
		AudioFx.stop_speech()
	AudioFx.play_sfx("pop")


## A paused page is dimmed and its line buttons are disabled (not hidden): the
## text stays perfectly readable, which is the whole point of pausing it while a
## teacher talks over it.
func _apply_paused_look() -> void:
	_pause_button.text = "RESUME" if _paused else "PAUSE"
	for button in _line_buttons:
		button.disabled = _paused
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.62) if _paused else Color.WHITE
	_go_button.disabled = _paused
	_restore_notes_text()


func _toggle_notes() -> void:
	_italian_notes = not _italian_notes
	_restore_notes_text()
	if _italian_notes:
		AudioFx.speak(String(_chapter.get("teacher_notes_it", "")), "it")
	else:
		AudioFx.stop_speech()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# `pause` (Esc / Start) is the natural "hold on a moment" on this page: it
	# freezes the page instead of closing it, which is what a teacher wants when
	# a hand goes up in the middle of a sentence.
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
