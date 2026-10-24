class_name TeacherMenu
extends Control
## The teacher's page: all forty story missions on one screen, and a way into the
## bonus challenges.
##
## Why it exists. The game is strictly sequential on purpose (see
## `QuestManager`), and the QA harness proves that order every build. A class
## working through the book still needs the two things a fixed sequence cannot
## give: a teacher who is told "we did numbers last week, can we do the castle?"
## must be able to *get* to the castle, and a teacher who wants to revise
## mission 21 before a test must not have to play 1-20 first. This page is that
## answer, and it changes nothing about the sequence itself — leaving a mission
## still advances to the mission after it, because that is what the child behind
## the teacher expects to happen.
##
## No password, no long press, no key combination. The agreed design is that the
## page is reached from the bottom of the PAUSE screen, under its own divider, so
## it is out of the way of a child's thumb but never a puzzle for an adult. A
## padlock here would be theatre: anyone can quit and reopen the game, and the
## whole clientele is a teacher holding the machine.
##
## Nothing on this page is *saved*. `QuestManager.current_mission_id` is moved
## while the page is in use, and the next flame moves it again through the normal
## `advance()`; relaunching the game resumes at the first unsolved mission, which
## is the same rule the game has always used. Writing a second "unlocked up to"
## number would add a save key that has to agree with `completed_missions`
## forever, and there is no request for one.
##
## Every entry is a jump button. A mission is never *blocked* — the only thing
## the list adds to a mission is the ability to start it from here.

signal mission_pressed(mission_id: int)
signal challenges_pressed
signal back_pressed

## Panel geometry, in the 1280x720 design pixels the whole UI is laid out in.
##
## The grid is five entries wide, which is what forty entries need to become
## eight rows instead of ten: at four columns the same grid was 8 * 52 px taller
## than the frame and `tools/layout_check.gd` measured it off the bottom of the
## screen. 200 px per entry still fits the longest title ("Bat Hide & Seek 1")
## on two wrapped lines at 15 px, and the entry height leaves room for exactly
## that.
##
## The vertical budget is the whole story of these numbers, and it was measured
## rather than guessed: the first draft (18 px margins, 8 px separation, 52 px
## entries) put the page at 763 px in a 720 px viewport. The entries were the
## reason, and not because 52 was too small: a button's minimum height is its
## *wrapped text* plus the 14 px content margin the shared theme puts above and
## below every label, which made each of the eight rows 61 px tall no matter what
## `ENTRY_SIZE` said. `_entry_style()` is what actually fixes it, by cutting that
## margin to 2 px; the 46 px below is then the size that is really used.
const PANEL_W := 1100.0
const PANEL_H := 690.0
const COLUMNS := 5
const ENTRY_SIZE := Vector2(200, 46)
## Inner width handed to the one wrapping label on the page.
const WRAP_WIDTH := 1040.0

var _grid: GridContainer
var _buttons: Array[Button] = []
var _ids: Array[int] = []


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	add_child(UiKit.scrim(0.74))

	var panel := UiKit.panel(UiKit.COL_PANEL, UiKit.COL_BLUE)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	panel.add_theme_stylebox_override("panel",
		UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_BLUE, 6, 34))
	add_child(panel)

	var m := UiKit.margin(18)
	panel.add_child(m)
	var v := UiKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)

	var title := UiKit.label("TEACHER MENU", 34, UiKit.COL_BLUE, HORIZONTAL_ALIGNMENT_CENTER, false)
	v.add_child(title)

	# The sentence a teacher needs and a child does not: what this page is, and
	# that using it does not break the class's progress. Green-bordered entries
	# are explained here rather than marked with an "OK · " prefix, because that
	# prefix adds three characters to every solved entry and the entries are
	# fixed-width: the width change is exactly what the layout probe measures.
	var blurb := UiKit.label(
		"Every mission is open. Tap one and the class starts it straight away. "
		+ "A green border means it is already solved. Nothing here is saved: "
		+ "closing and reopening the game carries on from the first unsolved mission.",
		21, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	v.add_child(blurb)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_grid)

	_build_entries()

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(footer)

	var challenges := UiKit.button("EXTRA CHALLENGES", null, Vector2(300, 54))
	challenges.add_theme_font_size_override("font_size", 23)
	challenges.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_PINK, 4, 20))
	challenges.pressed.connect(func(): challenges_pressed.emit())
	footer.add_child(challenges)

	var back := UiKit.button("BACK", null, Vector2(240, 54))
	back.add_theme_font_size_override("font_size", 25)
	back.pressed.connect(func(): back_pressed.emit())
	footer.add_child(back)


## One button per story mission, in the order of `GameData.missions()`.
##
## The label leads with the mission *number* because that is what a teacher says
## out loud ("open number twenty-one"), exactly like the challenge list.
func _build_entries() -> void:
	_buttons.clear()
	_ids.clear()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for mission in GameData.missions():
		var id := int(mission.get("id", 0))
		var button := UiKit.button("", null, ENTRY_SIZE)
		button.add_theme_font_size_override("font_size", 15)
		# Wrapping, not widening: a grid entry that grows to fit its longest
		# title is how a 1100 px panel quietly becomes 1400 px wide, which is
		# the failure the challenge list already ran into.
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%d · %s" % [id, String(mission.get("title", ""))]
		button.pressed.connect(func(): mission_pressed.emit(id))
		_grid.add_child(button)
		_buttons.append(button)
		_ids.append(id)


## The style every entry wears, at every state, so `refresh()` only has to swap
## the colours.
##
## Its 2 px content margin (against the shared theme's 14) is the reason the page
## fits: a button cannot be shorter than its text plus its own margins, so eight
## rows of theme-padded buttons were 61 px each whatever `ENTRY_SIZE` asked for.
## Kept as one helper rather than five inline style boxes so the margin cannot
## drift back to 14 on one of the states and re-break the layout.
func _entry_style(fill: Color, border: Color, border_width: int = 5) -> StyleBoxFlat:
	var style := UiKit.panel_style(fill, border, border_width, 16)
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


## Paints the solved / unsolved state and the zone colour of every entry.
##
## The border colour carries the zone so a teacher can see the six chapters as
## blocks at a glance; the fill carries "already solved". Two different things,
## two different channels — a single colour cannot say both.
func refresh() -> void:
	for i in _buttons.size():
		var id := _ids[i]
		var zone: Dictionary = GameData.zone_info(int(GameData.mission(id).get("zone", 1)))
		var zone_color: Color = zone.get("color", UiKit.COL_ACCENT)
		var solved := QuestManager.is_completed(id)
		_buttons[i].add_theme_stylebox_override("normal", _entry_style(
			UiKit.COL_GREEN.darkened(0.55) if solved else UiKit.COL_PANEL.lightened(0.06),
			UiKit.COL_GREEN if solved else zone_color))
		_buttons[i].add_theme_stylebox_override("hover", _entry_style(
			UiKit.COL_PANEL.lightened(0.22), UiKit.COL_ACCENT.lightened(0.2), 6))
		_buttons[i].add_theme_stylebox_override("focus", _entry_style(
			UiKit.COL_PANEL.lightened(0.22), UiKit.COL_ACCENT.lightened(0.2), 6))


func open() -> void:
	visible = true
	modulate.a = 0.0
	refresh()
	# Forty buttons and no pointer: without a focused control the page cannot be
	# used with a gamepad at all, and this is the only page that can move the
	# class forward without playing.
	UiKit.focus_first_button(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	visible = false
