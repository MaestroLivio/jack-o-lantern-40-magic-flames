class_name DialogueBox
extends Control
## Bilingual dialogue box.
##
## Speaks the English line, shows the text, and keeps the Italian translation
## hidden behind the Magic Magnifying Glass so English is always the first
## language the child hears and reads.
##
##     var box := DialogueBox.new()
##     add_child(box)
##     box.show_line("Mr. Barnaby", "Find the red pumpkin!", "Trova la zucca rossa!")

signal advanced
signal help_pressed

## Panel geometry and the inner width its wrapped text is laid out at (see
## `UiKit.label` for why that width must be explicit).
const PANEL_W := 840.0
const PANEL_H := 300.0
const WRAP_WIDTH := 760.0
## How long a line stays fully open before folding itself away, in seconds.
##
## Long enough to read a two-line sentence twice at this reading level and to
## finish hearing it, short enough that a child who has understood is not left
## staring at a panel. Folding never answers the dialogue: `advanced` is only
## emitted by OK, so nothing can be skipped by waiting.
const AUTO_FOLD_TIME := 7.0

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _italian_label: Label
var _continue_button: Button
var _advance_pending := false
## The "–" button that folds the box without answering it, so a child can look
## at the world for a moment without losing the sentence.
var _fold_button: Button
## The pill left behind while the box is folded. Tapping it brings the sentence
## back in the same state it was in, Italian line included.
var _fold_tab: Button
var _folded := false
## Bumped on every `show_line()`. The auto-fold timer belongs to the line that
## scheduled it: without this, reading the task again three seconds after the
## first line would let the *first* timer fold the *second* sentence halfway
## through being read.
var _line_token: int = 0


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	_panel = UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ACCENT)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -PANEL_W * 0.5
	_panel.offset_right = PANEL_W * 0.5
	_panel.offset_top = -PANEL_H - 36.0
	_panel.offset_bottom = -36
	_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ACCENT, 6, 32))
	add_child(_panel)

	var m := UiKit.margin(18)
	_panel.add_child(m)
	var v := UiKit.vbox(8)
	m.add_child(v)

	_name_label = UiKit.label("", 26, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, false)
	v.add_child(_name_label)

	_text_label = UiKit.label("", 34, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true, WRAP_WIDTH)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text_label)

	_italian_label = UiKit.label("", 27, UiKit.COL_PINK, HORIZONTAL_ALIGNMENT_LEFT, true, WRAP_WIDTH)
	_italian_label.visible = false
	v.add_child(_italian_label)

	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)

	var listen := UiKit.button("", UiKit.icon_texture("speaker", "white", 80), Vector2(76, 68))
	listen.tooltip_text = "Listen again"
	listen.pressed.connect(func(): AudioFx.speak(_text_label.text))
	row.add_child(listen)

	var magnifier := UiKit.button("", UiKit.icon_texture("magnifier", "pink", 80), Vector2(76, 68))
	magnifier.tooltip_text = "Italian translation (H)"
	magnifier.pressed.connect(_toggle_italian)
	row.add_child(magnifier)

	_continue_button = UiKit.button("OK", null, Vector2(160, 68))
	_continue_button.pressed.connect(_on_continue)
	row.add_child(_continue_button)

	# Folding without answering. The OK button ends the conversation; this one
	# only puts the panel away, because "I want to see where I am walking" and
	# "I have understood, go on" are two different intentions and a
	# seven-year-old should not have to advance the story to look around.
	_fold_button = UiKit.button("–", null, Vector2(68, 68))
	_fold_button.add_theme_font_size_override("font_size", 30)
	_fold_button.tooltip_text = "Put the words away for a moment"
	_fold_button.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL.darkened(0.1), UiKit.COL_ACCENT.darkened(0.35), 4, 20))
	_fold_button.add_theme_stylebox_override("hover",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.1), UiKit.COL_ACCENT, 5, 20))
	_fold_button.pressed.connect(fold)
	row.add_child(_fold_button)

	# The pill that stays behind, in the same lower-centre place the box
	# occupies, so "the words went away" never looks like "the words are lost".
	_fold_tab = UiKit.button("SPEECH", UiKit.icon_texture("speaker", "white", 64), Vector2(190, 54))
	_fold_tab.add_theme_font_size_override("font_size", 22)
	_fold_tab.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_fold_tab.offset_left = -95
	_fold_tab.offset_right = 95
	_fold_tab.offset_top = -78
	_fold_tab.offset_bottom = -24
	_fold_tab.tooltip_text = "Show the words again"
	_fold_tab.visible = false
	_fold_tab.pressed.connect(unfold)
	add_child(_fold_tab)


## Shows and speaks a line. `auto_continue` closes the box after the speech.
func show_line(speaker: String, english: String, italian: String = "", auto_continue: float = 0.0) -> void:
	_name_label.text = speaker.to_upper()
	_text_label.text = english
	_italian_label.text = italian
	_italian_label.visible = false
	# A new line always starts unfolded: the panel has to be readable the
	# moment it changes, whatever the child did with the previous one.
	_folded = false
	if _fold_tab != null:
		_fold_tab.visible = false
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	_panel.pivot_offset = _panel.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioFx.speak(english)
	# A gamepad has no pointer: without a focused button, the only way out of
	# this box is a mouse click, and a one-tool child would be stuck on it. OK
	# is the safest thing to land on — A dismisses the box instead of walking.
	# `hide_box()` gives the focus back, or the release would leave it on a
	# hidden button and swallow every later press for the rest of the mission.
	if _continue_button.is_visible_in_tree():
		_continue_button.grab_focus()
	if auto_continue > 0.0:
		await get_tree().create_timer(auto_continue).timeout
		if is_inside_tree():
			_on_continue()
		return
	# Waited for the OK press, the box folds itself out of the way after a while
	# so the child is left looking at the world instead of at a wall of words.
	# The pill below stays, and OK is still one tap away.
	_line_token += 1
	var token := _line_token
	await get_tree().create_timer(AUTO_FOLD_TIME).timeout
	# `visible` matters as well as the token: the box is a permanent child of
	# the level and is hidden — not freed — when the conversation ends, so a
	# timer from a dismissed line would otherwise fold the next mission's
	# dialogue before a child had finished reading it.
	if not is_inside_tree() or not visible or token != _line_token \
			or not _panel.visible or _folded or not auto_hide_enabled():
		return
	fold()


## Reads the setting through the autoload without hard-referencing it: this
## script is also loaded by `--script` tools, where autoload names are not
## registered as identifiers.
func auto_hide_enabled() -> bool:
	var q := UiKit._quest_manager()
	return q != null and bool(q.get("auto_hide_ui"))


## Puts the panel away without answering it. `advanced` is deliberately *not*
## emitted: folding a dialogue must never move the story forward.
func fold() -> void:
	if _folded:
		return
	_folded = true
	if _fold_button != null and _fold_button.has_focus():
		_fold_button.release_focus()
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.16)
	tween.tween_callback(func():
		_panel.visible = false
		if _fold_tab != null:
			_fold_tab.visible = true
	)


## Brings a folded panel back, exactly as it was.
func unfold() -> void:
	if not _folded:
		return
	_folded = false
	if _fold_tab != null:
		_fold_tab.visible = false
	_panel.visible = true
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.16)
	if _continue_button.is_visible_in_tree():
		_continue_button.grab_focus()


func is_folded() -> bool:
	return _folded


## True when a screen point lands on the SPEECH pill left by a folded box.
##
## Same reason as the counting bag's `blocks_point`: `Level._input` sees the
## press before the GUI consumes it, so without this the tap that unfolds the
## sentence would also pick up whatever prop was standing behind the pill.
func blocks_point(at: Vector2) -> bool:
	if _fold_tab == null or not _fold_tab.visible:
		return false
	return _fold_tab.get_global_rect().has_point(at)


func _toggle_italian() -> void:
	_italian_label.visible = not _italian_label.visible
	if _italian_label.visible and not _italian_label.text.is_empty():
		AudioFx.speak(_italian_label.text, "it")
	help_pressed.emit()


func _on_continue() -> void:
	advanced.emit()
	hide_box()


func hide_box() -> void:
	# The box takes the focus when it opens, so it has to give it back: a hidden
	# `Button` that still owns the focus keeps `ui_accept`, and the child's next
	# `A` press would land nowhere at all.
	if _continue_button.has_focus():
		_continue_button.release_focus()
	# A closed box leaves nothing behind: the pill belongs to a *folded* box,
	# and a pill on screen after the conversation ended would be a dead button.
	_folded = false
	if _fold_tab != null and _fold_tab.has_focus():
		_fold_tab.release_focus()
	if _fold_tab != null:
		_fold_tab.visible = false
	_panel.visible = true
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func(): visible = false)
