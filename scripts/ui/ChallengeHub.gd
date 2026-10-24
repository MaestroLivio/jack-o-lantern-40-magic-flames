class_name ChallengeHub
extends Control
## The list of the forty bonus challenges.
##
## This page is the *door* to the extra missions and the only way back out of
## them. It exists because those missions are deliberately not part of the
## forty-flame story: a class has to be told, once, in one screen, that these are
## optional puzzles with the hints taken away, and then be able to jump straight
## to any of them instead of walking through all forty in order.
##
## Jumping to any entry is also what makes the list usable in a classroom: a
## teacher who wants "the board, no highlights" for today's lesson opens
## challenge 6 and stops there, and a teacher whose class finished early can let
## them pick.
##
## Every entry is a button. No grid, no map, no unlocking: nothing here can be
## *blocked*, because a challenge a child cannot open is a challenge they will
## ask about instead of playing.
##
## Forty entries do not fit on one page. Eight rows of five was the first thing
## tried, and it cannot work: the page was already at its minimum height with
## four rows and zero pixels of slack (measured 676 inside a 676 frame), so any
## fifth row is past the bottom of a 720 px screen before the text is even read.
## The list is therefore paged, twenty at a time, and the page controls sit in
## the *same row* as BACK so paging costs no vertical space at all. The split is
## not arbitrary: entries 1-20 are the board and number challenges, 21-40 are the
## spelling and meaning ones, so a page is also a topic.

signal challenge_pressed(index: int)
signal back_pressed

## Panel geometry. Five columns of four entries per page plus a title, a progress
## line and the footer row; `tools/layout_check.gd` measures the real minimum
## size and fails the build if this stops fitting inside 1280 x 720.
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
## Twenty per page, because that is what the proven 5 x 4 geometry holds. Tied
## to `COLUMNS` by `PER_PAGE = COLUMNS * ROWS` rather than written as a literal:
## changing the column count without changing the page size would silently put a
## fifth row back on the page.
const ROWS := 4
const PER_PAGE := COLUMNS * ROWS
const ENTRY_SIZE := Vector2(176, 62)

var _grid: GridContainer
var _progress: Label
var _prev: Button
var _next: Button
var _buttons: Array[Button] = []
## Which page is on screen, 0-based. It is *kept* across openings: a class that
## was reading the spelling page and pressed BACK for one mission comes back to
## the spelling page, not to the top of a forty-item list.
var _page := 0



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
	# the forty entries read as forty more missions they owe someone.
	var blurb := UiKit.label(
		"Forty bonus puzzles. Same words, no glowing squares: read the task and find it yourself! Nothing here is required.",
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

	# BACK and the pager share one row. Paging was added when the list doubled
	# to forty entries, and a second row would have cost 56 + 10 px that the
	# panel does not have (it measured 676 in a 676 frame before). The arrows are
	# wide enough for a child on a touch screen and are disabled at the ends
	# rather than hidden, so the row never changes width and the entries above
	# it never shift.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(footer)

	_prev = UiKit.button("< PREVIOUS", null, Vector2(250, 56))
	_prev.add_theme_font_size_override("font_size", 22)
	_prev.pressed.connect(func(): _turn_page(-1))
	footer.add_child(_prev)

	var back := UiKit.button("BACK", null, Vector2(260, 56))
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(func(): back_pressed.emit())
	footer.add_child(back)

	_next = UiKit.button("NEXT >", null, Vector2(250, 56))
	_next.add_theme_font_size_override("font_size", 22)
	_next.pressed.connect(func(): _turn_page(1))
	footer.add_child(_next)


## Fills the grid with the entries of the current page.
##
## The buttons are built once for the whole list and then only re-parented, so
## their `pressed` signal does not have to be re-wired every time the page turns
## and a solved entry keeps its green border while off-screen.
func _build_entries() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
	_buttons.clear()
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
		_buttons.append(button)
	_show_page(_page)


## Puts the entries of page `page` in the grid, clamped to the real page count.
func _show_page(page: int) -> void:
	var pages := _page_count()
	_page = clampi(page, 0, pages - 1)
	for child in _grid.get_children():
		_grid.remove_child(child)
	var first := _page * PER_PAGE
	var last := mini(first + PER_PAGE, _buttons.size())
	for i in range(first, last):
		_grid.add_child(_buttons[i])
	# Disabled rather than hidden: a row that grows and shrinks would shift the
	# entries above it between page turns, and the probe measures exactly that
	# kind of jump. A disabled button also cannot take the focus, so the pager
	# can never become the tab stop the child lands on.
	if _prev != null:
		_prev.disabled = _page <= 0
	if _next != null:
		_next.disabled = _page >= pages - 1
	_update_progress()


func _page_count() -> int:
	return maxi(1, ceili(float(_buttons.size()) / float(PER_PAGE)))


## One page forward or back. Wrapped here rather than inline in the lambdas so
## the focus can be restored: with a gamepad, `focus_first_button` lands on the
## first entry of the new page, which is the only control that page answers to.
func _turn_page(step: int) -> void:
	_show_page(_page + step)
	UiKit.focus_first_button(self)


## Redraws the solved / unsolved look of every entry and the progress line.
##
## It paints all forty buttons, not just the twenty on screen: an entry solved
## on page 2 must already be green when the child turns back to page 1, and the
## tally counts the whole list.
func refresh() -> void:
	var challenges := GameData.extra_missions()
	for i in _buttons.size():
		var index := int(challenges[i].get("extra_index", i + 1))
		var solved: bool = QuestManager.extra_completed.has(index)
		# Solved entries are green and say so in words. A colour alone would be
		# lost on a projector, and a tick glyph is not guaranteed to exist in
		# the font stack (see `UiKit`), so the state is spelled out.
		_buttons[i].text = "%s%d · %s" % ["OK · " if solved else "", index, String(challenges[i].get("title", ""))]
		_buttons[i].add_theme_stylebox_override("normal", UiKit.panel_style(
			UiKit.COL_GREEN.darkened(0.55) if solved else UiKit.COL_PANEL.lightened(0.06),
			UiKit.COL_GREEN if solved else UiKit.COL_ACCENT, 5, 20))
	_update_progress()


## The one line above the grid: which page is on screen and how much is solved.
##
## Both live in the same label because a second line would cost 36 px of height
## the panel does not have. The completion sentence only replaces the tally once
## every entry is solved, so "0 of 40 solved" is still what a teacher sees while
## counting; the congratulation is the *extra* sentence, not a replacement.
func _update_progress() -> void:
	if _progress == null:
		return
	var challenges := GameData.extra_missions()
	var total := _buttons.size()
	var done := 0
	for i in total:
		var index := int(challenges[i].get("extra_index", i + 1))
		if QuestManager.extra_completed.has(index):
			done += 1
	var pages := _page_count()
	var head := "Page %d of %d" % [_page + 1, pages] if pages > 1 else ""
	var tally := "%d of %d solved" % [done, total]
	if done >= total and total > 0:
		tally = "%d of %d solved — all done! Well played!" % [done, total]
	_progress.text = "%s · %s" % [head, tally] if not head.is_empty() else tally


## Called when the fortieth challenge lands. Nothing to build: `refresh()` has
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
