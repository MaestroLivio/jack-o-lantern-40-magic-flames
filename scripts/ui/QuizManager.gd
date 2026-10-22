class_name QuizManager
extends Control
## Multiple-choice quiz UI (missions 5, 7, 16, 25-31 and the final party).
##
## The GDD asks for three TextureButtons populated dynamically with pictures
## and words. Wrong answers are never fatal: the card wobbles, the child hears
## "Not this one. Try again!" and the quiz stays open. The correct card
## flashes green and the quiz advances.
##
##     var quiz := QuizManager.new()
##     add_child(quiz)
##     quiz.start(mission, hud)      # mission["questions"] drives everything
##     quiz.finished.connect(_on_quiz_solved)

signal finished
signal progress_changed(index: int, total: int)

## Seconds the correct answer glows before moving on. Long enough for a
## 7-year-old to feel the reward, short enough to keep momentum.
const REVEAL_TIME := 0.85

## Panel geometry, in viewport pixels at the 1280x720 design size. The panel is
## anchored to the centre and grows with the window thanks to `canvas_items`
## stretch, so these numbers always describe the same layout.
const PANEL_W := 960.0
## Tall enough for every state the panel can be in, including the Italian line
## when the child reveals it: header 34 + question 92 + translation 36 + cards
## 220 + footer 62 + four 12 px gaps + 44 px of margins = 536. The extra 24 px
## is breathing room, so the panel never has to grow past the screen.
const PANEL_H := 560.0
## Inner width the wrapped labels are laid out at: the panel width minus the
## stylebox content margins (22) and the MarginContainer (22) on both sides,
## with a little slack. Handing this number to a wrapping Label is what keeps
## the panel from collapsing (see `UiKit.label`).
const WRAP_WIDTH := 840.0
const CARD_SIZE := Vector2(220, 220)

var _questions: Array = []
var _index: int = 0
var _locked: bool = false
var _missions_done := false

var _root: Control
var _card_row: HBoxContainer
var _question_label: Label
var _italian_label: Label
var _counter_label: Label
var _hint_label: Label
var _progress_dots: HBoxContainer
## The dark backdrop and the framed panel, kept so folding can take both away
## and leave the 3D world visible underneath.
var _scrim: ColorRect
var _panel: PanelContainer
## The pill left behind while the quiz is folded. It carries the progress
## ("QUIZ 3/10") because that is the one thing folding must not hide.
var _fold_tab: Button
var _folded := false
## Saved `mouse_filter` of the root: a folded quiz must stop eating clicks so
## the child can play while it is out of the way.
var _root_filter: Control.MouseFilter


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	_scrim = UiKit.scrim(0.66)
	add_child(_scrim)

	var panel := UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ACCENT)
	_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ACCENT, 6, 36))
	add_child(panel)

	var m := UiKit.margin(22)
	panel.add_child(m)
	var v := UiKit.vbox(12)
	m.add_child(v)

	var header := UiKit.hbox(12)
	v.add_child(header)

	# Header labels are single-line: `wrap = false` keeps them from being
	# squeezed into a one-pixel column by the flexible spacer next to them.
	_counter_label = UiKit.label("", 24, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false)
	header.add_child(_counter_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_progress_dots = UiKit.hbox(6)
	header.add_child(_progress_dots)

	_question_label = UiKit.label("", 36, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER,
		true, WRAP_WIDTH)
	_question_label.custom_minimum_size = Vector2(WRAP_WIDTH, 92)
	_question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(_question_label)

	# The Italian line stays hidden until the child asks for it, so it must not
	# reserve vertical space either (`custom_minimum_size.y` stays 0 here).
	_italian_label = UiKit.label("", 26, UiKit.COL_PINK, HORIZONTAL_ALIGNMENT_CENTER,
		true, WRAP_WIDTH)
	_italian_label.visible = false
	v.add_child(_italian_label)

	_card_row = UiKit.hbox(20)
	_card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_card_row)

	var footer := UiKit.hbox(12)
	v.add_child(footer)
	_hint_label = UiKit.label("", 22, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER,
		true, WRAP_WIDTH - 96.0)
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_hint_label)

	var magnifier := UiKit.button("", UiKit.icon_texture("magnifier", "pink", 80), Vector2(72, 62))
	magnifier.tooltip_text = "Italian translation (H)"
	magnifier.pressed.connect(_toggle_italian)
	footer.add_child(magnifier)

	# Folding the quiz away. A quiz is the one panel that *has* to be read to be
	# played, so it is not folded automatically; this is for the child who wants
	# to look around mid-question, and for the counting missions where the world
	# is the answer. The pill keeps the progress visible so nothing is lost.
	var fold := UiKit.button("–", null, Vector2(62, 62))
	fold.add_theme_font_size_override("font_size", 28)
	fold.tooltip_text = "Put the question away for a moment"
	fold.pressed.connect(fold_away)
	footer.add_child(fold)

	_fold_tab = UiKit.button("QUIZ", null, Vector2(160, 52))
	_fold_tab.add_theme_font_size_override("font_size", 22)
	_fold_tab.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_fold_tab.offset_left = -80
	_fold_tab.offset_right = 80
	_fold_tab.offset_top = 104
	_fold_tab.offset_bottom = 156
	_fold_tab.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ACCENT, 4, 24))
	_fold_tab.add_theme_stylebox_override("hover",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.14), UiKit.COL_ACCENT.lightened(0.2), 5, 24))
	_fold_tab.tooltip_text = "Show the question again"
	_fold_tab.visible = false
	_fold_tab.pressed.connect(unfold)
	add_child(_fold_tab)


# --- Public API ------------------------------------------------------------

## Starts a quiz from a mission dictionary. `resume_index` lets the final
## party quiz continue from where it was.
func start(mission: Dictionary, resume_index: int = 0) -> void:
	_questions = mission.get("questions", [])
	_index = clampi(resume_index, 0, maxi(_questions.size() - 1, 0))
	_locked = false
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
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	if _questions.is_empty():
		push_warning("QuizManager: mission has no questions")
		return
	_show_question()


func close() -> void:
	# Same reason as `_finish()`: the cards may still hold the focus when the
	# quiz is closed from outside (a mission restart, a panel swap).
	_release_card_focus()
	visible = false
	_folded = false
	if _fold_tab != null:
		_fold_tab.visible = false
	if _scrim != null:
		_scrim.visible = true
	if _panel != null:
		_panel.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


## Puts the whole quiz away without answering it.
##
## The quiz is the most enclosing panel in the game: a full-screen scrim plus a
## 960x560 frame, so on a classroom projector there is almost no world left
## around it. Folding it leaves the world fully playable — the root stops taking
## mouse presses, the cards give up the focus — while the pill on top keeps
## saying which question the child is on, so they cannot lose their place.
func fold_away() -> void:
	if _folded:
		return
	_folded = true
	_release_card_focus()
	if _scrim != null:
		_scrim.visible = false
	if _panel != null:
		_panel.visible = false
	# The root is a full-rect `Control` with `MOUSE_FILTER_STOP`: leaving it
	# armed would make the whole screen unclickable, which is the opposite of
	# what folding is for.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _fold_tab != null:
		_fold_tab.text = "QUIZ %d/%d" % [_index + 1, maxi(_questions.size(), 1)]
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
	# Back to the cards: the child was looking at a card when they folded it.
	if _locked:
		return
	if _card_row.get_child_count() > 0:
		var pick := clampi(_index, 0, _card_row.get_child_count() - 1)
		(_card_row.get_child(pick) as Control).grab_focus()


func is_folded() -> bool:
	return _folded


## True when a screen point lands on the QUIZ pill left by a folded quiz.
func blocks_point(at: Vector2) -> bool:
	if _fold_tab == null or not _fold_tab.visible:
		return false
	return _fold_tab.get_global_rect().has_point(at)


func _show_question() -> void:
	if _index >= _questions.size():
		_finish()
		return
	var q: Dictionary = _questions[_index]
	_locked = false
	_question_label.text = String(q.get("en", ""))
	_question_label.add_theme_color_override("font_color", UiKit.COL_TEXT)
	_italian_label.text = String(q.get("it", ""))
	_italian_label.visible = false
	_counter_label.text = "Question %d / %d" % [_index + 1, _questions.size()]
	# A folded quiz stays folded across questions — the child chose to look at
	# the world and re-folding on every answer would undo that choice silently.
	# Only the progress on the pill is refreshed.
	if _folded and _fold_tab != null:
		_fold_tab.text = "QUIZ %d/%d" % [_index + 1, _questions.size()]
	_build_progress_dots()
	_hint_label.text = "Tap the right picture!"
	_clear_cards()

	var options: Array = q.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		var card := _make_card(opt)
		card.pressed.connect(_on_option_pressed.bind(i, card))
		_card_row.add_child(card)

	progress_changed.emit(_index + 1, _questions.size())
	# A gamepad cannot aim at a card: with nothing focused, A does nothing and a
	# one-tool child is stuck. The first card gets the focus, and the D-pad walks
	# the row from there. The options keep the GDD's order (no shuffle), so the
	# gamepad's idea of "the cards" matches what is written on screen.
	if _card_row.get_child_count() > 0:
		(_card_row.get_child(0) as Control).grab_focus()
	# Read the question aloud, but only once per question.
	AudioFx.speak(String(q.get("en", "")))


## Builds one big picture card: icon on top, word underneath.
func _make_card(opt: Dictionary) -> TextureButton:
	var word := String(opt.get("label", ""))
	var icon_name := String(opt.get("icon", "circle"))
	var color_key := String(opt.get("color", "orange"))
	var number := int(opt.get("number", 0))
	# The face is a *learning target*, not a decoration: "Which one is HAPPY?"
	# can only be answered if the cards actually differ in expression. The data
	# has always carried `face` (see the final-party questions in GameData.gd),
	# and this line is what stops it being dropped on the floor between the
	# dictionary and the picture.
	var face := String(opt.get("face", "happy"))

	var card := TextureButton.new()
	card.custom_minimum_size = CARD_SIZE
	# Keep the card square even when the row is taller than one card.
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.ignore_texture_size = true
	card.stretch_mode = TextureButton.STRETCH_SCALE
	card.focus_mode = Control.FOCUS_ALL

	var normal := _card_style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_TEXT_DIM.darkened(0.2), 4)
	var hover := _card_style(UiKit.COL_PANEL.lightened(0.18), UiKit.COL_ACCENT, 6)
	var pressed := _card_style(UiKit.COL_PANEL.lightened(0.02), UiKit.COL_ORANGE, 6)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", pressed)
	card.add_theme_stylebox_override("focus", hover)

	# A small icon size hint keeps the word and picture balanced.
	var content := UiKit.vbox(8)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 12
	content.offset_right = -12
	content.offset_top = 12
	content.offset_bottom = -12
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.texture = UiKit.icon_texture(icon_name, color_key, 180, number, face)
	icon.custom_minimum_size = Vector2(140, 140)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Size questions ("which one is BIG?") grow the picture itself.
	var scale_hint := float(opt.get("size", 1.0))
	if not is_equal_approx(scale_hint, 1.0) and opt.has("size"):
		icon.custom_minimum_size = Vector2(140, 140) * scale_hint * 0.85
	content.add_child(icon)

	# Single words never need wrapping, and wrapping here would let the card
	# shrink its text to a sliver (see `UiKit.label`).
	#
	# The word under the picture is a reading crutch: it lets a child match the
	# spoken word to the *letters* instead of the picture. At level 3 it is
	# withdrawn, which is the whole point of that level — the card is then just
	# the picture, and the question above it is still spoken and still written.
	if Hints.quiz_cards_show_word() and not word.is_empty():
		var text := UiKit.label(word, 26, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(text)

	card.add_child(content)
	return card


func _card_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(26)
	s.anti_aliasing = true
	return s


func _clear_cards() -> void:
	# `queue_free()` alone would leave the old cards as children until the end
	# of the frame, so the new cards' indices would be shifted while a quick
	# tap is processed. Detach them immediately instead.
	for child in _card_row.get_children():
		_card_row.remove_child(child)
		child.queue_free()


func _build_progress_dots() -> void:
	for child in _progress_dots.get_children():
		_progress_dots.remove_child(child)
		child.queue_free()
	if _questions.size() <= 1:
		return
	for i in _questions.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = UiKit.COL_ACCENT if i <= _index else UiKit.COL_TEXT_DIM.darkened(0.4)
		_progress_dots.add_child(dot)


func _on_option_pressed(index: int, card: Control) -> void:
	if _locked:
		return
	_locked = true
	var q: Dictionary = _questions[_index]
	var options: Array = q.get("options", [])
	var opt: Dictionary = options[index]

	if bool(opt.get("correct", false)):
		_reward(card, opt)
	else:
		_gentle_retry(card, opt, options)


## Correct answer: green flash, sparkle, spoken praise, then next question.
func _reward(card: Control, opt: Dictionary) -> void:
	AudioFx.play_sfx("correct")
	var success_style := _card_style(UiKit.COL_GREEN.darkened(0.25), UiKit.COL_GREEN, 8)
	card.add_theme_stylebox_override("normal", success_style)
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2(1.1, 1.1), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.2)
	_hint_label.text = "Yes! %s" % String(opt.get("label", "")).to_upper()
	AudioFx.speak("%s. Well done!" % String(opt.get("label", "")))

	_index += 1
	QuestManager.step_changed.emit(mini(_index, _questions.size()), _questions.size())
	await get_tree().create_timer(REVEAL_TIME + 0.35).timeout
	if not is_inside_tree():
		return
	_show_question()


## Wrong answer: the card wobbles, the child hears a kind correction and can
## simply try another card. Nothing is lost, no counter goes down.
func _gentle_retry(card: Control, opt: Dictionary, options: Array) -> void:
	AudioFx.play_sfx("wrong")
	_hint_label.text = "Almost! Try another one."
	AudioFx.speak("Not this one. Try again!")
	var tween := create_tween()
	var start := card.position
	tween.tween_property(card, "position:x", start.x + 12.0, 0.08)
	tween.tween_property(card, "position:x", start.x - 12.0, 0.1)
	tween.tween_property(card, "position:x", start.x, 0.08)
	# The correct card keeps a soft glow so the next tap cannot fail — until
	# level 3, which is exactly the level that asks the child to find it alone.
	# This is never a dead end: the question is still spoken, the cards are still
	# all there, and a wrong tap only wobbles.
	if Hints.quiz_reveals_correct():
		for i in options.size():
			var o: Dictionary = options[i]
			if bool(o.get("correct", false)) and i < _card_row.get_child_count():
				var correct_card: Control = _card_row.get_child(i)
				var glow := _card_style(UiKit.COL_PANEL.lightened(0.1), UiKit.COL_ACCENT, 6)
				correct_card.add_theme_stylebox_override("normal", glow)
	await get_tree().create_timer(0.55).timeout
	if is_inside_tree():
		_locked = false


func _finish() -> void:
	if _missions_done:
		return
	_missions_done = true
	# The cards own the focus while the quiz runs; a hidden `TextureButton` that
	# still holds it would swallow the gamepad's next press.
	_release_card_focus()
	_folded = false
	if _fold_tab != null:
		_fold_tab.visible = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func():
		visible = false
		_missions_done = false
		finished.emit()
	)


func _toggle_italian() -> void:
	_italian_label.visible = not _italian_label.visible
	if _italian_label.visible:
		AudioFx.speak(_italian_label.text, "it")


## Italian text of the question on screen, or "" when the quiz is not running.
##
## The magnifying glass is pressed *inside* a question, so the sentence it has to
## translate is that question — not the mission's generic task line. A quiz of
## ten review questions has ten different sentences: reading
## `mission["prompt_it"]` made the glass pronounce "Rispondi alle domande!"
## while the child was looking at "Quale parola significa casa?". The quiz owns
## the questions, so it is also the only place that can answer this correctly.
func current_italian() -> String:
	if not visible or _index < 0 or _index >= _questions.size():
		return ""
	return String((_questions[_index] as Dictionary).get("it", ""))


## Drops the focus from whichever card holds it. Called on the way out: a hidden
## `TextureButton` that still owns the focus keeps swallowing `ui_accept`, so a
## gamepad child would press A and see nothing happen at all.
func _release_card_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and _card_row != null and _card_row.is_ancestor_of(focused):
		focused.release_focus()


## Number of questions already answered (used when re-opening the party quiz).
func answered_count() -> int:
	return _index
