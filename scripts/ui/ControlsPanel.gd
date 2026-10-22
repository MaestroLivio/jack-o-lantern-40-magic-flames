class_name ControlsPanel
extends Control
## The "change the controls" page, opened from the pause menu.
##
## One row per rebindable action: what it does, the keys it currently uses and a
## CHANGE button. Pressing CHANGE turns the row into a "press a key…" prompt:
## the next key the child touches becomes the new binding, Escape cancels, and
## the chip updates immediately so there is no doubt about what happened.
##
## Two rules keep a 7-year-old from locking themselves out of the game:
##   * `Controls.rebind()` never leaves an action with zero keys — if the key is
##     taken away from another action, that action keeps its own fallback;
##   * the mouse is deliberately *not* rebindable. A drag orbits the view, the
##     wheel zooms, and a click picks things up: those three gestures are always
##     available and the page says so, so nobody can switch them off by mistake.
##
## The English text is the page; pressing the magnifier swaps the help line to
## Italian, exactly like the rest of the game (Italian is never automatic).

signal back_pressed

## Panel geometry, in the 1280x720 design pixels the whole UI is laid out in.
## 880 px is wide enough for a long action label plus two key chips and the
## button, and low enough that the page never has to scroll (see the note on
## wrapped labels in `UiKit.label`).
const PANEL_W := 880.0
const PANEL_H := 680.0
## Inner width handed to the one wrapping label on the page.
const WRAP_WIDTH := 780.0
## Height of a single row. Fixed instead of content-driven, so the seven rows
## add up to a number that is known to fit and the page cannot "breathe" its way
## off the bottom of the screen when the easy-read font is on.
const ROW_H := 44.0
## Vertical content margin used by every button on this page.
##
## This page stacks *ten* buttons (seven CHANGE rows plus RESET / magnifier /
## BACK). With the game's default 14 px top-and-bottom button padding those
## alone add up to more than the 720 px design height, which the layout probe
## caught as "controls needs 799 px but the viewport is 720". A tighter margin
## keeps every button the same size as elsewhere in the game *visually* (the
## border and radius are unchanged) while removing the wasted space.
const BUTTON_PAD := 5.0

var _rows: Array[Dictionary] = []
var _help: Label
var _status: Label
## The action waiting for a key, or "" when nothing is being rebound.
var _listening_action := ""
var _help_italian := false

var _help_en := "Tap CHANGE, then press the key you want. Tap the mouse to look around; the wheel zooms."
var _help_it := "Tocca CAMBIA, poi premi il tasto che vuoi. Con il mouse trascini per guardarti intorno; la rotellina ingrandisce."


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	add_child(UiKit.scrim(0.72))

	var panel := UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ACCENT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ACCENT, 6, 34))
	add_child(panel)

	var m := UiKit.margin(18)
	panel.add_child(m)
	var v := UiKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)

	var title := UiKit.label("CHANGE THE CONTROLS", 36, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, false)
	v.add_child(title)

	for entry in Controls.BINDINGS:
		v.add_child(_build_row(entry))

	# One reserved line of help, swapped to Italian on demand. Keeping it always
	# visible (rather than hiding it) means the page never re-flows, so the
	# buttons stay exactly where the child just found them.
	_help = UiKit.label(_help_en, 22, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER,
		true, WRAP_WIDTH)
	_help.custom_minimum_size = Vector2(WRAP_WIDTH, 46)
	_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(_help)

	# A one-line confirmation after a change ("Walk forward = F"). It reserves
	# no extra height because it lives where the row was.
	_status = UiKit.label("", 22, UiKit.COL_GREEN, HORIZONTAL_ALIGNMENT_CENTER, false)
	v.add_child(_status)

	var footer := UiKit.hbox(16)
	v.add_child(footer)

	# RESET is the one destructive button on the page, so it keeps a red border —
	# but it still uses the compact margins, or it would be the tallest thing here.
	var reset := _compact(UiKit.button("RESET", null, Vector2(190, 56)))
	reset.add_theme_stylebox_override("normal",
		_compact_style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_SOFT_RED, 4, 22))
	reset.pressed.connect(_on_reset)
	footer.add_child(reset)

	var magnifier := _compact(UiKit.button("", UiKit.icon_texture("magnifier", "pink", 80), Vector2(76, 56)))
	magnifier.tooltip_text = "Italiano"
	magnifier.pressed.connect(_toggle_italian)
	footer.add_child(magnifier)

	var back := _compact(UiKit.button("BACK", null, Vector2(190, 56)))
	back.pressed.connect(func(): back_pressed.emit())
	footer.add_child(back)


## One line: action name, the keys it uses, and a CHANGE button.
func _build_row(entry: Dictionary) -> Control:
	var action := String(entry["action"])
	var row := UiKit.hbox(12)
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Single-line labels: wrapping inside an HBox would collapse them to a
	# one-pixel column (see `UiKit.label`).
	var name_label := UiKit.label(String(entry["label"]), 27, UiKit.COL_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, false)
	name_label.custom_minimum_size = Vector2(300, 0)
	row.add_child(name_label)

	var chip := UiKit.label(_chip_text(action), 26, UiKit.COL_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER, false)
	chip.custom_minimum_size = Vector2(210, 0)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(chip)

	var change := _compact(UiKit.button("CHANGE", null, Vector2(170, ROW_H)))
	change.add_theme_font_size_override("font_size", 24)
	change.pressed.connect(_on_change.bind(action))
	row.add_child(change)

	_rows.append({"action": action, "label": String(entry["label"]), "chip": chip, "button": change})
	return row


## What the chip shows: the keys on the keyboard, then the pad button.
##
## The pad is listed on every row on purpose. A teacher setting the game up on a
## classroom laptop should be able to see, without plugging a controller in,
## that the game is playable end to end with one — and a child can point at the
## letter they know. `pad_label()` returns "" on the (impossible) row with no
## pad button, which is why it is joined rather than concatenated.
func _chip_text(action: String) -> String:
	var keys := Controls.key_label_full(action)
	var pad := Controls.pad_label(action)
	return keys if pad.is_empty() else "%s  ·  %s" % [keys, pad]


## Shrinks a button's vertical content margin (see `BUTTON_PAD`).
##
## Every style state is overridden, not just `normal`: `hover` and `focus` are
## separate `StyleBox`es in the shared theme, and leaving them alone would make
## the row grow by ~18 px the moment the child hovers over CHANGE — which is
## exactly the kind of re-flow that moves a button out from under a finger.
func _compact(button: Button) -> Button:
	button.add_theme_stylebox_override("normal",
		_compact_style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_ACCENT, 6))
	button.add_theme_stylebox_override("hover",
		_compact_style(UiKit.COL_PANEL.lightened(0.16), UiKit.COL_ACCENT.lightened(0.2), 8))
	button.add_theme_stylebox_override("focus",
		_compact_style(UiKit.COL_PANEL.lightened(0.16), UiKit.COL_ACCENT.lightened(0.2), 8))
	button.add_theme_stylebox_override("pressed",
		_compact_style(UiKit.COL_PANEL.darkened(0.08), UiKit.COL_ACCENT, 6))
	return button


## One button style with `BUTTON_PAD` vertical padding instead of the theme's.
func _compact_style(fill: Color, border: Color, border_width: int, radius: int = 24) -> StyleBoxFlat:
	var style := UiKit.panel_style(fill, border, border_width, radius)
	style.content_margin_top = BUTTON_PAD
	style.content_margin_bottom = BUTTON_PAD
	return style


# --- Rebinding -------------------------------------------------------------

func _on_change(action: String) -> void:
	# A second CHANGE while listening cancels the first one, so a mis-tap is
	# never a dead end.
	if _listening_action == action:
		_stop_listening()
		return
	_stop_listening()
	_listening_action = action
	for row in _rows:
		if String(row["action"]) == action:
			(row["chip"] as Label).text = "PRESS A KEY…"
			(row["chip"] as Label).add_theme_color_override("font_color", UiKit.COL_PINK)
	_set_status("")
	if _help != null:
		_help.text = "Press the key you want for “%s”. Escape cancels." % String(_action_label(action))
	AudioFx.play_sfx("pop")


## Captures the next key press while a row is listening.
##
## `_input` (rather than `_unhandled_input`) is deliberate: the panel must win
## over every other listener, otherwise pressing E to rebind "pick up" would
## also walk-to-the-NPC. `set_input_as_handled()` then stops the event from
## reaching the level or the pause shortcut. The `visible` and empty-action
## guards matter because `_input` keeps running while the page is closed.
func _input(event: InputEvent) -> void:
	if not visible or _listening_action.is_empty():
		return
	# A controller press cannot become a new *key*, so it cancels the prompt
	# instead of being swallowed: otherwise a child holding a pad would press A
	# on CHANGE and sit in "PRESS A KEY…" with no way out but BACK.
	if event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		_stop_listening()
		_set_status("The gamepad keeps its own buttons.")
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: InputEventKey = event
	get_viewport().set_input_as_handled()
	if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
		_stop_listening()
		_set_status("No change.")
		return
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code == KEY_NONE:
		return
	var action := _listening_action
	var displaced := Controls.conflicting_action(action, code)
	Controls.rebind(action, code)
	_stop_listening(false)
	_refresh_chips()
	if displaced.is_empty():
		_set_status("%s = %s" % [_action_label(action), Controls.key_label(action)])
	else:
		# Naming the action that lost the key is the honest explanation, and it
		# reassures the child that nothing disappeared without a reason.
		_set_status("%s = %s · %s switched key" % [
			_action_label(action), Controls.key_label(action), _action_label(displaced)])
	AudioFx.play_sfx("step")


## Leaves the listening state. `restore_chip = false` refreshes the chips anyway,
## which is what a successful rebind wants.
func _stop_listening(restore_chip: bool = true) -> void:
	_listening_action = ""
	if restore_chip:
		_refresh_chips()
	if _help != null:
		_help.text = _help_it if _help_italian else _help_en


func _refresh_chips() -> void:
	for row in _rows:
		var chip: Label = row["chip"]
		chip.text = _chip_text(String(row["action"]))
		chip.add_theme_color_override("font_color", UiKit.COL_ACCENT)


func _action_label(action: String) -> String:
	for row in _rows:
		if String(row["action"]) == action:
			return String(row["label"])
	return action


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _on_reset() -> void:
	_stop_listening()
	Controls.reset_defaults()
	_refresh_chips()
	_set_status("Default keys restored.")
	AudioFx.play_sfx("pop")


func _toggle_italian() -> void:
	_help_italian = not _help_italian
	if _help != null and _listening_action.is_empty():
		_help.text = _help_it if _help_italian else _help_en


# --- Open / close ----------------------------------------------------------

## Shows the page, always starting from the current bindings and never from a
## half-finished "press a key" state left over from last time.
func open() -> void:
	visible = true
	_listening_action = ""
	_refresh_chips()
	_set_status("")
	if _help != null:
		_help.text = _help_it if _help_italian else _help_en
	modulate.a = 0.0
	# Gamepad / Tab entry point: the first CHANGE button.
	UiKit.focus_first_button(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)


func close() -> void:
	_listening_action = ""
	visible = false
