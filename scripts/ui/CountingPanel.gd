class_name CountingPanel
extends Control
## The "give exactly N candies" bag (missions 9, 10, 23, 24).
##
## Children collect props in the world, then this card shows how many of each
## they are carrying and a big GIVE button. Overshooting is allowed and is
## answered with a friendly "Too many! Put some back." — counting is a skill
## that needs practice, not a punishment.
##
## ## Why this is a *card* and not a modal
##
## It used to be a centred modal with a full-screen scrim. That is the right
## shape for a quiz, where the answer lives on the panel, but it is the wrong
## shape here: this is the one panel a child has to *play the 3D world* while
## wearing. Picking up candies means walking and looking, and the modal hid
## exactly the thing they needed to see.
##
## So the bag is now a small card in the top-right corner with no scrim. The
## world stays visible and clickable around it.
##
## ## Why it cannot be lost
##
## The card has a "–" button that folds it away, and folding it leaves a small
## `BAG n/N` tab in the very same corner. The tab brings the card back, so
## folding is always reversible. That matters more than it sounds: the previous
## version had a BACK button that hid the whole panel with nothing at all to
## bring it back, so the only way to see the counts again was to fail the
## mission on purpose.
##
## Delivering the items is done by walking to the character and tapping them
## (`CountMission._on_npc_talked_to()`, reached through `NpcCharacter.talked_to`),
## because that is what the mission says and what a child expects. The GIVE
## button stays as a second route, for a child who would rather not walk back —
## and for the QA harness.

signal submitted(counts: Dictionary)

## Card geometry in 1280x720 design pixels.
##
## The height is computed from the number of rows instead of being fixed: a
## one-row mission ("5 orange candies") should not leave a tall empty card
## behind, and a three-row mission ("1 bat, 1 hat, 1 broom") must not clip its
## last row. `_height_for()` is the single place that arithmetic lives.
const PANEL_W := 430.0
## Distance from the top of the screen. It clears the HUD's top bar (~96 px)
## and stops short of the instruction bar at the bottom, so the card never
## covers either of the two things that tell the child what to do.
const PANEL_TOP := 104.0
const PANEL_RIGHT := 16.0
const ROW_H := 50.0
const ROW_GAP := 8.0
const HEADER_H := 76.0
const HINT_H := 44.0
const FOOTER_H := 58.0
const PAD := 16.0
## Width the one wrapping label on the card is laid out at (see `UiKit.label`).
const WRAP_WIDTH := 360.0
const TAB_SIZE := Vector2(190, 54)

var _requirements: Array = []
var _counts: Dictionary = {}   # requirement key -> int
var _hud: Hud
var _count_labels: Dictionary = {}
var _rows: VBoxContainer
var _give_button: Button
var _hide_button: Button
var _hint: Label
var _title: Label
var _subtitle: Label
## The card itself, and the tab that is left behind when it is folded away.
var _frame: PanelContainer
var _tab: Button


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The root ignores the mouse so that a click anywhere else on the screen
	# still reaches the 3D world; only the card and the tab want the pointer.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


## Height of the card for `rows` requirement rows.
func _height_for(rows: int) -> float:
	var gaps := ROW_GAP * float(maxi(rows - 1, 0))
	return PAD * 2.0 + HEADER_H + float(rows) * ROW_H + gaps + HINT_H + FOOTER_H + ROW_GAP * 2.0


func _build() -> void:
	# --- The card -----------------------------------------------------------
	_frame = UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ORANGE)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_frame.offset_left = -(PANEL_W + PANEL_RIGHT)
	_frame.offset_right = -PANEL_RIGHT
	_frame.offset_top = PANEL_TOP
	_frame.offset_bottom = PANEL_TOP + _height_for(1)
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	# 0.94 alpha: the world behind stays readable, so the card reads as an
	# overlay laid *on* the scene rather than a room the child has walked into.
	var fill := UiKit.COL_PANEL
	fill.a = 0.94
	_frame.add_theme_stylebox_override("panel", UiKit.panel_style(fill, UiKit.COL_ORANGE, 5, 26))
	add_child(_frame)

	var m := UiKit.margin(PAD)
	_frame.add_child(m)
	var v := UiKit.vbox(ROW_GAP)
	m.add_child(v)

	_title = UiKit.label("MY BAG", 26, UiKit.COL_ORANGE, HORIZONTAL_ALIGNMENT_LEFT, false)
	v.add_child(_title)

	_subtitle = UiKit.label("", 19, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true, WRAP_WIDTH)
	v.add_child(_subtitle)

	_rows = UiKit.vbox(ROW_GAP)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_rows)

	_hint = UiKit.label("", 19, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true, WRAP_WIDTH)
	_hint.custom_minimum_size = Vector2(WRAP_WIDTH, HINT_H - 6.0)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(_hint)

	var footer := UiKit.hbox(10)
	footer.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(footer)

	_give_button = _compact(UiKit.button("GIVE", UiKit.icon_texture("candy", "orange", 80), Vector2(210, FOOTER_H)))
	_give_button.add_theme_stylebox_override("normal",
		_compact_style(UiKit.COL_GREEN.darkened(0.5), UiKit.COL_GREEN, 5))
	_give_button.add_theme_stylebox_override("hover",
		_compact_style(UiKit.COL_GREEN.darkened(0.35), UiKit.COL_GREEN.lightened(0.25), 6))
	_give_button.add_theme_stylebox_override("pressed",
		_compact_style(UiKit.COL_GREEN.darkened(0.6), UiKit.COL_GREEN, 5))
	_give_button.tooltip_text = "Give the bag to the character"
	_give_button.pressed.connect(_on_give)
	footer.add_child(_give_button)

	# Folding the card away, never closing the mission. See the header: the tab
	# below is what makes this reversible.
	_hide_button = _compact(UiKit.button("-", null, Vector2(56, FOOTER_H)))
	_hide_button.add_theme_font_size_override("font_size", 30)
	_hide_button.tooltip_text = "Hide the bag (you can bring it back)"
	_hide_button.pressed.connect(collapse)
	footer.add_child(_hide_button)

	# --- The tab left behind when the card is folded -------------------------
	_tab = _compact(UiKit.button("BAG 0/0", null, TAB_SIZE))
	_tab.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_tab.offset_left = -(TAB_SIZE.x + PANEL_RIGHT)
	_tab.offset_right = -PANEL_RIGHT
	_tab.offset_top = PANEL_TOP
	_tab.offset_bottom = PANEL_TOP + TAB_SIZE.y
	_tab.add_theme_stylebox_override("normal",
		_compact_style(UiKit.COL_PANEL.lightened(0.08), UiKit.COL_ORANGE, 4))
	_tab.add_theme_stylebox_override("hover",
		_compact_style(UiKit.COL_PANEL.lightened(0.18), UiKit.COL_ORANGE.lightened(0.25), 5))
	_tab.tooltip_text = "Show the bag again"
	_tab.pressed.connect(expand)
	_tab.visible = false
	add_child(_tab)


## Buttons on the bag use a tighter vertical padding than the game's menus: the
## card has to sit inside a fixed height next to a live 3D view, and the shared
## 14 px margin would eat the row it is meant to accompany.
func _compact(button: Button) -> Button:
	button.add_theme_stylebox_override("normal", _compact_style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_ORANGE, 4))
	button.add_theme_stylebox_override("hover", _compact_style(UiKit.COL_PANEL.lightened(0.16), UiKit.COL_ORANGE.lightened(0.2), 5))
	button.add_theme_stylebox_override("focus", _compact_style(UiKit.COL_PANEL.lightened(0.16), UiKit.COL_ORANGE.lightened(0.2), 5))
	button.add_theme_stylebox_override("pressed", _compact_style(UiKit.COL_PANEL.darkened(0.08), UiKit.COL_ORANGE, 4))
	return button


func _compact_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := UiKit.panel_style(fill, border, border_width, 20)
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


# --- Public API ------------------------------------------------------------

## Opens the bag for a mission's requirements. The card starts expanded: a child
## who has never seen it needs to know it exists before they can be glad about
## folding it away.
func start(mission: Dictionary, hud: Hud = null) -> void:
	_hud = hud
	_requirements = mission.get("requirements", [])
	_counts.clear()
	visible = true
	var npc_name := String(mission.get("npc", ""))
	_subtitle.text = ("Give them to %s." % npc_name) if not npc_name.is_empty() else "Keep them safe."
	_rebuild_rows()
	clear_hint()
	_frame.visible = true
	_tab.visible = false
	modulate.a = 0.0
	# Gamepad / Tab: GIVE is the button a child will need, and the card is
	# useless to a controller without a focused control.
	UiKit.focus_first_button(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


## Folds the card down to its tab. Always reversible through `expand()`.
func collapse() -> void:
	_frame.visible = false
	_tab.visible = true
	_refresh_tab()
	# The hide button has just left the screen; leaving the focus on it would
	# make the gamepad's next press do nothing at all.
	_tab.grab_focus()


func expand() -> void:
	_frame.visible = true
	_tab.visible = false
	_give_button.grab_focus()


func is_expanded() -> bool:
	return _frame != null and _frame.visible


## True when `at` (a screen point) lands on the card or on the tab.
##
## `Level._try_click()` asks this before raycasting the 3D world. Input reaches
## `_input` before the GUI consumes it, so without this check a tap on GIVE
## would *also* pick up whatever candy happened to sit behind the button.
func blocks_point(at: Vector2) -> bool:
	if not visible:
		return false
	if _frame.visible and _frame.get_global_rect().has_point(at):
		return true
	return _tab.visible and _tab.get_global_rect().has_point(at)


func _rebuild_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_count_labels.clear()
	for req in _requirements:
		var kind := String(req.get("kind", "candy"))
		var color_key := String(req.get("color", "orange"))
		var needed := int(req.get("count", 1))
		var word := String(req.get("word", kind))
		var have := int(_counts.get(_key_of(req), 0))

		var row := UiKit.hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.custom_minimum_size = Vector2(0, ROW_H)

		var icon := TextureRect.new()
		icon.texture = UiKit.icon_texture(kind, color_key, 96)
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

		# Rows live in an HBoxContainer next to an expanding counter, so the
		# name must not wrap: a wrapping Label would ask for a 1 px column and
		# stack one letter per line.
		var name_label := UiKit.label(word.to_upper(), 21, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		# Live count with the target, e.g. "3 / 5".
		var label := UiKit.label("%d / %d" % [have, needed], 26, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_RIGHT, false)
		row.add_child(label)
		_count_labels[_key_of(req)] = label

		# A row of dots visualises the target so counting doesn't need reading.
		var dots := UiKit.hbox(3)
		for i in needed:
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(9, 9)
			dot.color = UiKit.COL_GREEN if i < have else UiKit.COL_TEXT_DIM.darkened(0.5)
			dots.add_child(dot)
		row.add_child(dots)

		_rows.add_child(row)
	_refresh_tab()
	_frame.offset_bottom = PANEL_TOP + _height_for(_requirements.size())


## The folded card still has to answer "how many do I have?", or folding it
## away would cost the child the one piece of information they were tracking.
func _refresh_tab() -> void:
	var have := 0
	var need := 0
	for req in _requirements:
		have += int(_counts.get(_key_of(req), 0))
		need += int(req.get("count", 1))
	_tab.text = "BAG %d/%d" % [have, need]


func _key_of(req: Dictionary) -> String:
	return "%s|%s" % [String(req.get("kind", "")), str(int(float(req.get("scale", 1.0)) * 10.0))]


## Called by the level each time the child picks up a prop.
func add_item(kind: String, color_key: String, scale_value: float = 1.0) -> void:
	# Find the requirement this item belongs to, matching kind, colour and size.
	var matched_key := ""
	for req in _requirements:
		if String(req.get("kind", "")) != kind:
			continue
		var req_color := String(req.get("color", ""))
		if not req_color.is_empty() and req_color != color_key:
			continue
		var req_scale := float(req.get("scale", 1.0))
		if not is_equal_approx(req_scale, scale_value):
			continue
		matched_key = _key_of(req)
		break
	if matched_key.is_empty():
		return
	_counts[matched_key] = int(_counts.get(matched_key, 0)) + 1
	_refresh_counts()


func _refresh_counts() -> void:
	# Rebuild the whole list: the dots are the main feedback for a
	# non-reading child, so they must always match the bag.
	_rebuild_rows()


## Removes one item (used when the child puts one back into the world).
func remove_item(kind: String, color_key: String, scale_value: float = 1.0) -> void:
	for req in _requirements:
		if String(req.get("kind", "")) != kind:
			continue
		var req_color := String(req.get("color", ""))
		if not req_color.is_empty() and req_color != color_key:
			continue
		var req_scale := float(req.get("scale", 1.0))
		if not is_equal_approx(req_scale, scale_value):
			continue
		var key := _key_of(req)
		_counts[key] = maxi(int(_counts.get(key, 0)) - 1, 0)
		break
	_refresh_counts()


## Clears the collected counts (used when the child takes items back).
func reset_counts() -> void:
	_counts.clear()
	_refresh_counts()


func _on_give() -> void:
	submitted.emit(_counts.duplicate())


## Shows the "too many / not enough" hint without closing the card. A folded bag
## is unfolded first: a correction the child cannot read is not a correction.
func show_hint(text_en: String) -> void:
	if not _frame.visible:
		expand()
	_hint.text = text_en
	_hint.add_theme_color_override("font_color", UiKit.COL_SOFT_RED)


func clear_hint() -> void:
	_hint.text = "Pick them up, then tap the character."
	_hint.add_theme_color_override("font_color", UiKit.COL_TEXT_DIM)


## Hides the bag without touching the mission (the level frees the panel when the
## mission ends). Deliberately *not* connected to the "-" button: that one folds
## the card into a tab so it can be brought back, while this one is a teardown
## path with no way back.
func close() -> void:
	visible = false
