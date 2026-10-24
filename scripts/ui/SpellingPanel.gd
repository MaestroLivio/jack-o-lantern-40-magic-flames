class_name SpellingPanel
extends Control
## "Spell the word" controller (the ten spelling challenges of the bonus set).
##
## The game's own words, spelled out loud. Echo says the word and then its
## letters ("Cat. C, A, T.") and the child rebuilds it by tapping the letters in
## order from a bank that contains a few wrong ones.
##
## Why a bank of buttons and not a keyboard: a seven-year-old cannot be asked to
## find a letter on a keyboard while also remembering a word they just heard, and
## a keyboard would also let them type any letter at all — the exercise has to
## have a *set* of answers to choose from, or it stops being a reading task and
## becomes a typing task. The bank is the same design as the quiz cards: a small
## number of visible options, one of which is right.
##
## Why the letters are spoken one at a time as they are tapped: the point of the
## exercise is the *letter names*, which are English too. Tapping is what makes
## the child hear them again, and hearing them again is the lesson.
##
##     var panel := SpellingPanel.new()
##     add_child(panel)
##     panel.start(mission)
##     panel.finished.connect(...)

signal finished
## Emitted after every accepted letter, with the letters still to come.
signal letter_accepted(index: int, total: int)

## Panel geometry, in viewport pixels at the 1280x720 design size. Tall enough
## for the largest word in the data ("green", seven slots at most) plus two rows
## of letter keys: header 34 + slots 92 + word model 34 + keys 166 + footer 62 +
## four 12 px gaps + 44 px of margins = 480, with 60 px of slack so the panel
## never has to grow past the screen. `tools/layout_check.gd` measures it.
const PANEL_W := 940.0
const PANEL_H := 540.0
## Inner width the wrapped labels are laid out at (see `UiKit.label`).
const WRAP_WIDTH := 780.0
## One empty box per letter of the word.
const SLOT_SIZE := Vector2(84, 92)
## One letter key. Five columns of two rows is what the longest bank needs
## (nine letters for "purple" or "orange"), and it keeps every key the same size
## so a child can aim at the middle of one.
const KEY_SIZE := Vector2(112, 78)
const COLUMNS := 5

var _word := ""
var _index := 0
var _solved := false
var _locked := false
var _mission: Dictionary = {}

var _slots: HBoxContainer
var _slot_labels: Array[Label] = []
var _model: Label
var _translation: Label
var _bank: GridContainer
## `_keys` and `_key_letters` are parallel: changing the bank must change both
## or a press would fill the slot of a letter that is not on that key.
var _keys: Array[Button] = []
var _key_letters: Array[String] = []
var _hint: Label

## The dark backdrop and the framed panel, kept so folding can take both away.
var _scrim: ColorRect
var _panel: PanelContainer
## The pill left behind while the panel is folded, carrying the progress
## ("SPELL 3/5") because that is the one thing folding must not hide.
var _fold_tab: Button
var _folded := false


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	_scrim = UiKit.scrim(0.6)
	add_child(_scrim)

	var panel := UiKit.panel(UiKit.COL_PANEL, UiKit.COL_GREEN)
	_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_GREEN, 6, 36))
	add_child(panel)

	var m := UiKit.margin(22)
	panel.add_child(m)
	var v := UiKit.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)

	var header := UiKit.hbox(12)
	v.add_child(header)
	var title := UiKit.label("SPELL THE WORD", 26, UiKit.COL_GREEN, HORIZONTAL_ALIGNMENT_LEFT, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	# The one control a child needs first: hearing the word again. It sits in
	# the header rather than next to the keys so it is never one of the letters
	# they are aiming at.
	var listen := UiKit.button("LISTEN AGAIN", UiKit.icon_texture("speaker", "white", 80), Vector2(250, 52))
	listen.add_theme_font_size_override("font_size", 20)
	listen.pressed.connect(_on_listen)
	header.add_child(listen)

	_slots = UiKit.hbox(10)
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots.custom_minimum_size = Vector2(0, SLOT_SIZE.y)
	v.add_child(_slots)

	# The written word, shown at the lowest difficulty level only. It is the
	# "see it" step of the see-hear-say-read ladder: a child who cannot yet hold
	# five letters in memory copies them from the model. Hidden, it must not
	# reserve space either.
	_model = UiKit.label("", 30, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
	_model.visible = false
	v.add_child(_model)

	_bank = GridContainer.new()
	_bank.columns = COLUMNS
	_bank.add_theme_constant_override("h_separation", 10)
	_bank.add_theme_constant_override("v_separation", 10)
	v.add_child(_bank)

	var footer := UiKit.hbox(12)
	v.add_child(footer)
	_hint = UiKit.label("Tap the letters in order!", 22, UiKit.COL_TEXT_DIM,
		HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH - 200.0)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_hint)

	var magnifier := UiKit.button("", UiKit.icon_texture("magnifier", "pink", 80), Vector2(72, 56))
	magnifier.tooltip_text = "Italian translation (H)"
	magnifier.pressed.connect(_toggle_translation)
	footer.add_child(magnifier)

	# Folding the panel: a spelling exercise is read from the bank, but a child
	# who wants to look at the world (where the prop of the same word stands)
	# must be able to put it away. The pill keeps the progress visible.
	var fold := UiKit.button("–", null, Vector2(62, 56))
	fold.add_theme_font_size_override("font_size", 28)
	fold.tooltip_text = "Put the letters away for a moment"
	fold.pressed.connect(fold_away)
	footer.add_child(fold)

	# The Italian hint line lives under the footer and stays hidden until asked
	# for, so it cannot push the keys around when it appears.
	_translation = UiKit.label("", 26, UiKit.COL_PINK, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	_translation.visible = false
	v.add_child(_translation)

	_fold_tab = UiKit.button("SPELL", null, Vector2(170, 52))
	_fold_tab.add_theme_font_size_override("font_size", 22)
	_fold_tab.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_fold_tab.offset_left = -85
	_fold_tab.offset_right = 85
	_fold_tab.offset_top = 104
	_fold_tab.offset_bottom = 156
	_fold_tab.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_GREEN, 4, 24))
	_fold_tab.add_theme_stylebox_override("hover",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.14), UiKit.COL_GREEN.lightened(0.2), 5, 24))
	_fold_tab.tooltip_text = "Show the letters again"
	_fold_tab.visible = false
	_fold_tab.pressed.connect(unfold)
	add_child(_fold_tab)


# --- Public API ------------------------------------------------------------

## Starts the exercise with the mission's `word` and `bank`.
##
## `bank` is written out by hand in `GameData` (the wanted letters plus a few
## wrong ones) instead of being generated here: which wrong letters sit next to
## a word is a design decision — a `b` next to `d` is a reading lesson, an `x`
## is filler — and a generator would make that decision invisible to the teacher
## reading the data file.
func start(mission: Dictionary) -> void:
	_mission = mission
	_word = String(mission.get("word", "")).to_upper()
	_index = 0
	_solved = false
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
	if _word.is_empty():
		push_warning("SpellingPanel: mission has no word")
		return
	_build_slots()
	_build_bank(mission)
	_model.text = _word
	_model.visible = Hints.spelling_shows_word()
	_translation.text = GameData.translate(_word)
	_translation.visible = false
	_hint.text = "Tap the letters in order!"
	_speak_spelling()
	# Gamepad / Tab: the first letter key is what the exercise asks for.
	UiKit.focus_first_button(self)


## The sentence the panel says, and the only place it is assembled: the voice
## pack is recorded from `GameData.spelling_sentence()`, so a sentence built
## here by any other rule would silently fall back to the system voice.
func _speak_spelling() -> void:
	AudioFx.speak(GameData.spelling_sentence(_word))


## One slot per letter, all empty. Rebuilt on every start because the word —
## and therefore the number of boxes — changes from mission to mission.
func _build_slots() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	_slot_labels.clear()
	for i in _word.length():
		var slot := UiKit.panel(UiKit.COL_PANEL.lightened(0.04), UiKit.COL_TEXT_DIM.darkened(0.35))
		slot.custom_minimum_size = SLOT_SIZE
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.add_theme_stylebox_override("panel",
			UiKit.panel_style(UiKit.COL_PANEL.lightened(0.04), UiKit.COL_TEXT_DIM.darkened(0.35), 4, 18))
		var letter := UiKit.label("", 44, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(letter)
		_slots.add_child(slot)
		_slot_labels.append(letter)


## The letter keys, in a deterministic shuffled order.
##
## Deterministic because the QA harness has to be able to predict nothing but
## the *letter* of each key, and a random order would still be reproducible only
## by chance; seeded by the mission id so "how the bank looks" is a property of
## the mission and not of the run. Shuffled because a bank written in the order
## of the word would let a child spell `cat` by pressing the first three keys.
func _build_bank(mission: Dictionary) -> void:
	for child in _bank.get_children():
		_bank.remove_child(child)
		child.queue_free()
	_keys.clear()
	_key_letters.clear()
	var letters: Array[String] = []
	for letter in mission.get("bank", []):
		letters.append(String(letter).to_upper())
	if letters.is_empty():
		# A mission that forgot its bank still has to be playable: its own
		# letters, in order, and three filler ones.
		for i in _word.length():
			letters.append(_word.substr(i, 1))
		letters.append_array(["A", "E", "S"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(mission.get("id", 1)) * 7919
	for i in range(letters.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := letters[i]
		letters[i] = letters[j]
		letters[j] = tmp
	for letter in letters:
		var key := UiKit.button(letter, null, KEY_SIZE)
		key.add_theme_font_size_override("font_size", 34)
		key.add_theme_stylebox_override("normal",
			UiKit.panel_style(UiKit.COL_PANEL.lightened(0.08), UiKit.COL_TEXT_DIM.darkened(0.2), 4, 20))
		key.add_theme_stylebox_override("hover",
			UiKit.panel_style(UiKit.COL_PANEL.lightened(0.2), UiKit.COL_GREEN, 5, 20))
		key.add_theme_stylebox_override("focus",
			UiKit.panel_style(UiKit.COL_PANEL.lightened(0.2), UiKit.COL_GREEN, 5, 20))
		key.pressed.connect(_on_key_pressed.bind(key, letter))
		_bank.add_child(key)
		_keys.append(key)
		_key_letters.append(letter)


# --- Playing ---------------------------------------------------------------

## The letter the child has to find next.
func expected_letter() -> String:
	if _index >= _word.length():
		return ""
	return _word.substr(_index, 1)


## Presses the first unused key showing `letter`, exactly as a tap would.
##
## Public because the QA harness drives the exercise through it: a test that
## called the private handler directly with an index could disagree with the
## panel about which key shows which letter, and that disagreement is precisely
## the bug this method is written to avoid.
func press_letter(letter: String) -> bool:
	if _locked or _solved:
		return false
	var wanted := letter.to_upper()
	for i in _keys.size():
		if _keys[i].disabled or _key_letters[i] != wanted:
			continue
		_on_key_pressed(_keys[i], wanted)
		return true
	return false


func _on_key_pressed(key: Button, letter: String) -> void:
	if _locked or _solved:
		return
	if letter != expected_letter():
		_wrong_letter(key)
		return

	# Correct: the key retires, the slot fills, the letter name is heard.
	key.disabled = true
	key.add_theme_stylebox_override("disabled",
		UiKit.panel_style(UiKit.COL_PANEL.darkened(0.15), UiKit.COL_TEXT_DIM.darkened(0.45), 3, 20))
	var label := _slot_labels[_index]
	label.text = letter
	var slot := label.get_parent() as Control
	if slot != null:
		slot.add_theme_stylebox_override("panel",
			UiKit.panel_style(UiKit.COL_GREEN.darkened(0.45), UiKit.COL_GREEN, 5, 18))
		var tween := create_tween()
		tween.tween_property(slot, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK)
		tween.tween_property(slot, "scale", Vector2.ONE, 0.14)
	AudioFx.play_sfx("pop")
	AudioFx.speak(letter)
	_index += 1
	_hint.text = "Good! Now %d of %d." % [mini(_index + 1, _word.length()), _word.length()]
	letter_accepted.emit(_index, _word.length())
	if _folded and _fold_tab != null:
		_fold_tab.text = "SPELL %d/%d" % [_index, _word.length()]
	if _index >= _word.length():
		_finish()


## A letter that is not the next one. The key wobbles, the child hears a kind
## correction, and — below the top difficulty — the key they need glows so the
## next tap cannot fail. Nothing is consumed: the exercise is never a dead end.
func _wrong_letter(key: Button) -> void:
	_locked = true
	AudioFx.play_sfx("wrong")
	AudioFx.speak("Not this one. Try again!")
	_hint.text = "Almost! Look for %s." % expected_letter()
	var tween := create_tween()
	var start := key.position
	tween.tween_property(key, "position:x", start.x + 10.0, 0.07)
	tween.tween_property(key, "position:x", start.x - 10.0, 0.09)
	tween.tween_property(key, "position:x", start.x, 0.07)
	if Hints.spelling_reveals_letter():
		_glow_expected()
	# The correction sentence ("Not this one. Try again!") is a clip like any
	# other, so at the new recording speed it takes about a second: the panel
	# unlocks *after* it rather than over the top of it.
	await get_tree().create_timer(1.1).timeout
	if is_inside_tree():
		_locked = false
		_hint.text = "Tap the letters in order!"


## Lights the key the child needs next (see `Hints.spelling_reveals_letter`).
func _glow_expected() -> void:
	var wanted := expected_letter()
	for i in _keys.size():
		if _keys[i].disabled or _key_letters[i] != wanted:
			continue
		_keys[i].add_theme_stylebox_override("normal",
			UiKit.panel_style(UiKit.COL_PANEL.lightened(0.12), UiKit.COL_ACCENT, 6, 20))
		return


func _finish() -> void:
	if _solved:
		return
	_solved = true
	_locked = true
	_hint.text = "%s — well done!" % _word
	AudioFx.play_sfx("correct")
	AudioFx.speak("%s. Well done!" % _word)
	for key in _keys:
		key.disabled = true
	# 2.2 s, not the 1.1 the first draft used: the line just spoken is twice as
	# long at the new recording speed, and closing the panel underneath it was
	# cutting the congratulation in half.
	await get_tree().create_timer(2.2).timeout
	if not is_inside_tree():
		return
	_close_and_emit()


func _close_and_emit() -> void:
	_folded = false
	if _fold_tab != null:
		_fold_tab.visible = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func():
		visible = false
		finished.emit()
	)


func _on_listen() -> void:
	if _solved:
		return
	_speak_spelling()


func _toggle_translation() -> void:
	_translation.visible = not _translation.visible
	if _translation.visible:
		AudioFx.speak(_translation.text, "it")


# --- Folding ---------------------------------------------------------------

func fold_away() -> void:
	if _folded:
		return
	_folded = true
	_release_focus()
	if _scrim != null:
		_scrim.visible = false
	if _panel != null:
		_panel.visible = false
	# The root is a full-rect `Control` with `MOUSE_FILTER_STOP`: leaving it
	# armed would make the whole screen unclickable.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _fold_tab != null:
		_fold_tab.text = "SPELL %d/%d" % [_index, _word.length()]
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
	if _locked or _solved:
		return
	for i in _keys.size():
		if not _keys[i].disabled:
			_keys[i].grab_focus()
			return


func is_folded() -> bool:
	return _folded


## True when a screen point lands on the SPELL pill left by a folded panel.
func blocks_point(at: Vector2) -> bool:
	if _fold_tab == null or not _fold_tab.visible:
		return false
	return _fold_tab.get_global_rect().has_point(at)


## Italian text of the word on screen, the way `QuizManager.current_italian()`
## answers for a question: the magnifying glass has to translate *this* word,
## not the mission's generic task line.
func current_italian() -> String:
	if _word.is_empty():
		return ""
	return GameData.translate(_word)


## Closes the panel from outside (a mission restart, a panel swap).
func close() -> void:
	_release_focus()
	visible = false
	_folded = false
	if _fold_tab != null:
		_fold_tab.visible = false
	if _scrim != null:
		_scrim.visible = true
	if _panel != null:
		_panel.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


## Drops the focus from whichever key holds it: a hidden `Button` that still
## owns the focus keeps swallowing `ui_accept`.
func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return
	if _bank != null and _bank.is_ancestor_of(focused):
		focused.release_focus()
	elif _fold_tab != null and focused == _fold_tab:
		focused.release_focus()
