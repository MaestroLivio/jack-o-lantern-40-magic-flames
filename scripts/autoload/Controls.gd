extends Node
## Runtime key rebinding (autoload `Controls`).
##
## The game ships with friendly defaults (WASD + arrows, E to pick things up),
## but a child may share a keyboard with a sibling, use a left-handed layout or
## simply prefer different keys. This autoload owns the `InputMap` and the small
## save file, so a choice made in the settings panel survives a restart.
##
##     Controls.rebind("interact", KEY_F)
##     Controls.key_label("interact")   # -> "F"
##     Controls.reset_defaults()
##
## Only *keys* are rebound here. Mouse look (drag to orbit) and the wheel zoom
## are always available and are described inside the panel, because a child
## should never be able to switch the mouse off by accident.
##
## The gamepad is the third way in and it is **never** touched by a rebind: the
## defaults in `project.godot` already cover movement, picking up, the Italian
## help and pause, so a child holding a controller can play the whole game by
## themselves. Rebinding a key therefore removes and re-adds only `InputEventKey`
## events — an earlier version erased every event of the action, which silently
## deleted the controller binding the first time a child changed a key.
##
## The panel that edits these lives in `scripts/ui/ControlsPanel.gd`.

const SAVE_PATH := "user://controls.json"
const SAVE_VERSION := 1

## Actions offered in the settings, in the order the panel shows them.
## `label` is English (the game's first language), `label_it` is only used when
## the child asks for the Italian help.
const BINDINGS: Array[Dictionary] = [
	{"action": "move_forward", "label": "Walk forward", "label_it": "Cammina avanti"},
	{"action": "move_back", "label": "Walk back", "label_it": "Cammina indietro"},
	{"action": "move_left", "label": "Walk left", "label_it": "Cammina a sinistra"},
	{"action": "move_right", "label": "Walk right", "label_it": "Cammina a destra"},
	{"action": "interact", "label": "Pick up / talk", "label_it": "Prendi / parla"},
	{"action": "help", "label": "Italian help", "label_it": "Aiuto in italiano"},
	{"action": "pause", "label": "Pause", "label_it": "Pausa"},
]

## Short names for the pad buttons the game binds in `project.godot`. Kept here
## (rather than read from the event) because Godot reports `JOY_BUTTON_A`
## without a console-specific letter, and "A" is what a child sees on the pad.
##
## The four D-pad directions share one name: a child reading a settings row does
## not need "D-Pad Left" spelled out next to "Walk left", and the shorter text
## keeps the row inside the panel's 780 px inner width (a long chip inflates the
## whole page's minimum size — the trap described in `UiKit.label`).
const PAD_BUTTON_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_DPAD_UP: "D-Pad",
	JOY_BUTTON_DPAD_DOWN: "D-Pad",
	JOY_BUTTON_DPAD_LEFT: "D-Pad",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
}

## action -> Array[int] of keycodes, captured from `project.godot` at startup so
## "reset to default" always restores the shipped layout even after a rebind.
var _defaults: Dictionary = {}
## Guards the "cannot write settings" warning so it appears only once.
var _warned := false


func _ready() -> void:
	# The InputMap already holds the project defaults at this point: capture them
	# before applying any saved override, otherwise "reset" would restore the
	# user's own last choice instead of the original keys.
	_capture_defaults()
	load_saved()
	# Controller confirmation for the menus. See `install_pad_ui()`.
	install_pad_ui()


## Gives the gamepad a way to *confirm* menu buttons, which Godot does not
## provide out of the box.
##
## Measured on the shipped build: `ui_accept` was bound to Enter, Keypad-Enter
## and Space -- three keyboard events and **no joypad button at all** -- while
## `ui_cancel` was Escape only. D-pad navigation worked because Godot's built-in
## defaults do bind the pad to `ui_up/down/left/right`, so a child could move the
## focus ring around every menu in the game and then had no button that pressed
## anything. That is the whole of "the gamepad doesn't work": one missing button.
##
## Why not simply add `JOY_BUTTON_A` to `ui_accept`? Because `ui_accept` is also
## what a focused `Button` spends, and the HUD keeps two focusable buttons on
## screen during play (the speaker and the magnifier). With A on `ui_accept`, a
## child who happened to leave the focus on one of them would press A to pick up
## a pumpkin and get "read the task again" instead. So the pad gets its own
## action, and `Main` routes it to `ui_accept` only while a menu owns the screen.
##
## `JOY_BUTTON_Y` is on `ui_cancel` as well as B: on a Nintendo pad the face
## buttons are swapped, and a child pressing the button marked "B" there should
## still close a menu rather than be stuck in it.
func install_pad_ui() -> void:
	_bind_pad("ui_confirm_pad", [JOY_BUTTON_A])
	# B and Y both close: see the note above about swapped face buttons.
	_add_pad_to("ui_cancel", [JOY_BUTTON_B, JOY_BUTTON_Y])


## (Re)creates `action` with exactly `buttons` as its joypad buttons.
func _bind_pad(action: String, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(action, event)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = int(b)
		ev.pressed = true
		InputMap.action_add_event(action, ev)


## Adds `buttons` to `action` without removing anything already there: `ui_cancel`
## is a Godot built-in, and rebuilding it would drop Escape.
func _add_pad_to(action: String, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var already: Array[int] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			already.append((event as InputEventJoypadButton).button_index)
	for b in buttons:
		if already.has(int(b)):
			continue
		var ev := InputEventJoypadButton.new()
		ev.button_index = int(b)
		ev.pressed = true
		InputMap.action_add_event(action, ev)


# --- Queries ---------------------------------------------------------------

## True when `action` is one of the rebindable actions.
func knows(action: String) -> bool:
	for entry in BINDINGS:
		if String(entry["action"]) == action:
			return true
	return false


## The keycodes currently bound to `action`, primary key first.
func keycodes_for(action: String) -> Array[int]:
	var codes: Array[int] = []
	for event in _key_events(action):
		var key: InputEventKey = event
		# `physical_keycode` is layout-independent, which keeps WASD under
		# the same fingers on AZERTY keyboards. Fall back to `keycode` for
		# events created with only the logical key set.
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code != KEY_NONE and not codes.has(code):
			codes.append(code)
	return codes


## Only the keyboard events of `action`, so everything that rewrites a binding
## can leave the gamepad alone.
func _key_events(action: String) -> Array[InputEvent]:
	var keys: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			keys.append(event)
	return keys


## The gamepad events of `action`. Used to preserve them across a key rebind and
## to show the child that the controller works too.
func _pad_events(action: String) -> Array[InputEvent]:
	var pads: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			pads.append(event)
	return pads


## Replaces the *keyboard* bindings of `action` with `codes`, keeping every
## gamepad event exactly as it was.
func _set_keys(action: String, codes: Array) -> void:
	if not InputMap.has_action(action):
		return
	var pads := _pad_events(action)
	InputMap.action_erase_events(action)
	for code in codes:
		var event := InputEventKey.new()
		event.physical_keycode = int(code)
		InputMap.action_add_event(action, event)
	for pad in pads:
		InputMap.action_add_event(action, pad)


## Human-readable primary key, e.g. "W", "Space", "Up".
func key_label(action: String) -> String:
	var codes := keycodes_for(action)
	if codes.is_empty():
		return "—"
	var text := OS.get_keycode_string(codes[0])
	return text if not text.is_empty() else "Key %d" % codes[0]


## Same as `key_label()` but lists every fallback: "W  ·  Up".
func key_label_full(action: String) -> String:
	var codes := keycodes_for(action)
	if codes.is_empty():
		return "—"
	var parts: Array[String] = []
	for code in codes:
		var text := OS.get_keycode_string(code)
		parts.append(text if not text.is_empty() else str(code))
	return "  ·  ".join(parts)


## The first gamepad button bound to `action`, or "". Shown next to the keys in
## the settings so a child can see that the controller needs no setup at all.
##
## Only *buttons* are named. A stick axis has no name a 7-year-old would
## recognise, and the D-pad already covers the same directions, so naming the
## axis would just add a line of noise.
func pad_label(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in _pad_events(action):
		if event is InputEventJoypadButton:
			var button := event as InputEventJoypadButton
			if PAD_BUTTON_NAMES.has(button.button_index):
				return String(PAD_BUTTON_NAMES[button.button_index])
			return "Button %d" % button.button_index
	return ""


## True when at least one gamepad button is bound to `action` (movement is
## covered by the D-pad, so this holds for every rebindable action).
func has_pad_binding(action: String) -> bool:
	return not pad_label(action).is_empty()


## The action that already uses `keycode` as its primary key, or "".
func conflicting_action(action: String, keycode: int) -> String:
	for entry in BINDINGS:
		var other := String(entry["action"])
		if other == action:
			continue
		var codes := keycodes_for(other)
		if not codes.is_empty() and codes[0] == keycode:
			return other
	return ""


# --- Changes ---------------------------------------------------------------

## Binds `keycode` as the primary key of `action`.
##
## The extra fallbacks of that action (for example the arrow keys next to WASD)
## are kept, so rebinding "walk forward" does not take the arrow key away from a
## child who uses it. If the key was already the primary key of another action
## the old action keeps its own fallbacks, so no action is ever left with no key
## at all — a child can never lock themselves out of the game.
func rebind(action: String, keycode: int) -> bool:
	if not InputMap.has_action(action) or keycode == KEY_NONE:
		return false
	var existing := keycodes_for(action)
	var others: Array[int] = []
	for i in range(1, existing.size()):
		if existing[i] != keycode:
			others.append(existing[i])

	# Only the keys are replaced: `_set_keys()` re-adds the gamepad events, so a
	# child who rebinds WASD still has a working controller.
	var wanted: Array[int] = [keycode]
	for code in others:
		wanted.append(code)
	_set_keys(action, wanted)

	# Take the key away from whichever action used it, or two actions would
	# fire at the same time.
	for entry in BINDINGS:
		var other := String(entry["action"])
		if other == action:
			continue
		_drop_key(other, keycode)

	save()
	return true


## Restores the layout shipped in `project.godot`.
##
## The gamepad defaults are re-added too, otherwise "reset" would quietly make
## the controller stop working — the one thing a reset must never do.
func reset_defaults() -> void:
	for entry in BINDINGS:
		var action := String(entry["action"])
		if not InputMap.has_action(action):
			continue
		_set_keys(action, _defaults.get(action, []))
	save()


## Removes `keycode` from `action`, keeping at least one key bound.
func _drop_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	var codes := keycodes_for(action)
	if codes.size() <= 1 and codes.size() > 0 and codes[0] == keycode:
		return  # never leave an action without any key
	var kept: Array[int] = []
	for code in codes:
		if code != keycode:
			kept.append(code)
	_set_keys(action, kept)


# --- Persistence -----------------------------------------------------------

func _capture_defaults() -> void:
	_defaults.clear()
	for entry in BINDINGS:
		var action := String(entry["action"])
		_defaults[action] = keycodes_for(action)


## Writes the current bindings to `user://controls.json`.
func save() -> void:
	var data := {"version": SAVE_VERSION, "bindings": {}}
	var bindings: Dictionary = data["bindings"]
	for entry in BINDINGS:
		var action := String(entry["action"])
		bindings[action] = keycodes_for(action)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		if not _warned:
			_warned = true
			push_warning("Controls: cannot write settings (%s)" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## Applies `user://controls.json` on top of the defaults, if it exists.
func load_saved() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		return
	var bindings: Dictionary = data.get("bindings", {})
	for entry in BINDINGS:
		var action := String(entry["action"])
		if not bindings.has(action):
			continue
		var codes: Array = bindings[action]
		if codes.is_empty() or not InputMap.has_action(action):
			continue
		# Only the keys are restored: the gamepad default stays bound, so a save
		# file written by an older build (which did not know about the pad)
		# cannot take the controller away.
		_set_keys(action, codes)
