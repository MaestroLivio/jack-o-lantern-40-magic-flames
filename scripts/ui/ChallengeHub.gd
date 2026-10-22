class_name ChallengeHub
extends Control
## The list of the twenty bonus challenges.
##
## This page is the *door* to the extra missions and the only way back out of
## them. It exists because those missions are deliberately not part of the
## forty-flame story: a class has to be told, once, in one screen, that these are
## optional puzzles with the hints taken away, and then be able to jump straight
## to any of them instead of walking through all twenty in order.
##
## Jumping to any entry is also what makes the list usable in a classroom: a
## teacher who wants "the board, no highlights" for today's lesson opens
## challenge 6 and stops there, and a teacher whose class finished early can let
## them pick.
##
## Every entry is a button. No grid, no map, no unlocking: nothing here can be
## *blocked*, because a challenge a child cannot open is a challenge they will
## ask about instead of playing.

signal challenge_pressed(index: int)
signal back_pressed

## Panel geometry. Five rows of four entries plus a title, a progress line and
## the back button; `tools/layout_check.gd` measures the real minimum size and
## fails the build if this stops fitting inside 1280 x 720.
##
## The entry height was 86 in the first draft and the probe measured the page at
## 812 px tall — 92 px past the bottom of a 720 px screen. Shrinking
## `ENTRY_SIZE` alone barely helped (812 → 726), because a button's minimum is
## set by its *wrapped text*, not by the size asked for: four columns of five
## rows meant five rows of two-line labels no size could squeeze. Five columns of
## four rows is the fix that actually removes a row, and it keeps the font at
## 17 px, so nothing a child reads had to shrink.
const PANEL_W := 980.0
const PANEL_H := 600.0
const COLUMNS := 5
const ENTRY_SIZE := Vector2(176, 62)

var _grid: GridContainer
var _progress: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	# The tally can change while the page is closed (a challenge solved, then the
	# class pressed BACK): refreshing on the signal keeps the green borders
	# honest without the hub having to be rebuilt.
	QuestManager.extra_completed_changed.connect(_on_extra_changed)
	# Solving the twentieth is worth a sentence of its own: the list otherwise
	# goes on reading "20 of 20 solved" exactly as it read "19 of 20", and a class
	# that has just finished everything deserves to be told so.
	QuestManager.extra_challenges_completed.connect(_on_all_solved)


func _build() -> void:
	add_child(UiKit.scrim(0.72))

	var panel := UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ACCENT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ACCENT, 8, 38))
	add_child(panel)

	var m := UiKit.margin(22)
	panel.add_child(m)
	var v := UiKit.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)

	var title := UiKit.label("EXTRA CHALLENGES", 40, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, false)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color("3b1d00"))
	v.add_child(title)

	# The explanation is the whole point of this page: a child who stumbles in
	# here must be told that these are harder *and* that they are optional, or
	# the twenty entries read as twenty more missions they owe someone.
	var blurb := UiKit.label(
		"Twenty bonus puzzles. Same words, no glowing squares: read the task and find it yourself! Nothing here is required.",
		24, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true, 880.0)
	v.add_child(blurb)

	_progress = UiKit.label("", 26, UiKit.COL_PINK, HORIZONTAL_ALIGNMENT_CENTER, false)
	v.add_child(_progress)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	v.add_child(_grid)

	_build_entries()

	var back := UiKit.button("BACK", null, Vector2(260, 56))
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(func(): back_pressed.emit())
	v.add_child(back)


## One button per challenge, in the order of `GameData.extra_missions()`.
##
## The label is the challenge number and its title, e.g. "11 · The Teens". The
## *number* is what a teacher says out loud ("open number eleven"), so it leads.
func _build_entries() -> void:
	_buttons.clear()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var challenges := GameData.extra_missions()
	for entry in challenges:
		var index := int(entry.get("extra_index", 0))
		var button := UiKit.button("", null, ENTRY_SIZE)
		button.add_theme_font_size_override("font_size", 17)
		# Long titles ("Only One Way In") must wrap inside the entry instead of
		# widening it: a grid entry that grows to fit its longest label is how a
		# 980 px panel quietly becomes 1200 px wide.
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%d · %s" % [index, String(entry.get("title", ""))]
		button.pressed.connect(func(): challenge_pressed.emit(index))
		_grid.add_child(button)
		_buttons.append(button)


## Redraws the progress line and the solved / unsolved look of every entry.
func refresh() -> void:
	var total := _buttons.size()
	var done := 0
	var challenges := GameData.extra_missions()
	for i in _buttons.size():
		var index := int(challenges[i].get("extra_index", i + 1))
		var solved: bool = QuestManager.extra_completed.has(index)
		if solved:
			done += 1
		# Solved entries are green and say so in words. A colour alone would be
		# lost on a projector, and a tick glyph is not guaranteed to exist in
		# the font stack (see `UiKit`), so the state is spelled out.
		_buttons[i].text = "%s%d · %s" % ["OK · " if solved else "", index, String(challenges[i].get("title", ""))]
		_buttons[i].add_theme_stylebox_override("normal", UiKit.panel_style(
			UiKit.COL_GREEN.darkened(0.55) if solved else UiKit.COL_PANEL.lightened(0.06),
			UiKit.COL_GREEN if solved else UiKit.COL_ACCENT, 5, 20))
	if _progress != null:
		# The completion line only replaces the tally once every entry is solved,
		# so "20 of 20 solved" is still what a teacher sees while counting; the
		# congratulation is the *extra* sentence, not a replacement for the number.
		_progress.text = "%d of %d solved" % [done, total]
		if done >= total and total > 0:
			_progress.text = "%d of %d solved — all done! Well played!" % [done, total]


## Called when the twentieth challenge lands. Nothing to build: `refresh()` has
## already painted the entry green and `_progress` already says so. The method
## exists because the signal is the one place a future sound or confetti can be
## attached without the mission controller needing to know about the hub.
func _on_all_solved() -> void:
	refresh()


func _on_extra_changed(_done: int, _total: int) -> void:
	refresh()


func open() -> void:
	visible = true
	modulate.a = 0.0
	refresh()
	# Without a focused control this page is unreachable with a gamepad, and it
	# is the *only* way into the challenges.
	UiKit.focus_first_button(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)


func close() -> void:
	visible = false
