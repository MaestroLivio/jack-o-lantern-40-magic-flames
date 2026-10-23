class_name SoundPanel
extends Control
## The settings page, opened from the pause menu.
##
## Why its own page rather than more rows on the pause screen: the pause page
## measured 639 px of content inside a 700 px frame, so even two 46 px rows do
## not fit without shrinking every other control on it, and shrinking KEEP
## PLAYING is the wrong trade for a child who is already disoriented. A separate
## page also gives each setting room to be *read* ("MUSIC: LOUD"), which is the
## whole point.
##
## It holds three choices, all built the same way:
##   * MUSIC       -- background music level,
##   * SOUND EFFECTS -- jingles and clicks,
##   * VIEW        -- auto / always first person / never.
##
## The two volumes share one control type on purpose: a pair of big arrows around
## a name. A continuous slider would be the natural widget for a volume, but this
## is aimed at seven-year-olds on a classroom projector with a trackpad: a
## 4-pixel handle is not an honest target, and a child cannot describe a slider
## position to a teacher. Five named steps can be counted out loud ("press it
## twice"). The same argument decided the view row: "ALWAYS / AUTO / NEVER" are
## three words a teacher can read out, where a checkbox labelled "first person"
## says nothing about what happens if you leave it alone.
##
## The sound effects row plays a short "ding" on every change, so the level is
## chosen by ear and not only by the number: a child who cannot read "MEDIUM"
## can still hear which setting is loud.

## A level was changed: "music" or "sfx", already applied by QuestManager.
signal volume_changed(channel: String, step: int)
## The camera view changed (0 = auto, 1 = always first person, 2 = never).
signal camera_mode_changed(mode: int)
signal back_pressed

const PANEL_W := 720.0
## Tall enough for the three steppers, the hint line, the three switches and
## BACK.
##
## The history of this number is the reason it is what it is. The auto-hide
## switch pushed the content to 577 px inside a 560 px frame (measured by
## `tools/layout_check.gd`, which reports the minimum size of the whole page);
## the frame was raised to 610 to hold it. Adding the camera and touch-pad
## switches put two more rows on the page — 2 x (48 + 14) = 124 px — which does
## not fit in 720 even at 610. Rather than grow past the design height, the page
## was tightened: separation 14 -> 10 and margins 24 -> 20 give back 32 + 8 px,
## which pays for most of the two rows, and the frame sits at 680 with a little
## slack. Measured, not guessed: `layout_check.gd` is what said 577 in the first
## place, and it is what validates this number too.
const PANEL_H := 680.0
## Height of one stepper row, matching the difficulty row on the pause page.
const ROW_H := 58.0
## Width of the name column, so every row lines up and the arrows form a
## vertical pair the eye can follow down the page.
const LABEL_W := 210.0

var _music_name: Label
var _sfx_name: Label
var _view_name: Label
var _music_left: Button
var _music_right: Button
var _sfx_left: Button
var _sfx_right: Button
var _view_left: Button
var _view_right: Button
## The four bars of each level display, so `refresh()` can fill them.
var _music_segments: Array[ColorRect] = []
var _sfx_segments: Array[ColorRect] = []
var _view_segments: Array[ColorRect] = []
## The auto-hide switch. A `CheckButton` rather than a fourth stepper: it is one
## yes/no question ("may the game put the words away?"), and a checkbox is the
## only control a child already knows.
var _auto_hide_toggle: CheckButton
## The two switches added for the camera and the touch pad. Kept as members for
## the same reason as `_auto_hide_toggle`: `refresh()` is what re-syncs the page
## with `QuestManager` after a `continue`, and a switch rebuilt from a stale
## value would show the opposite of the truth the moment the child saved.
var _auto_camera_toggle: CheckButton
var _touch_controls_toggle: CheckButton


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
	panel.add_theme_stylebox_override("panel",
		UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ACCENT, 6, 36))
	add_child(panel)

	var m := UiKit.margin(20)
	panel.add_child(m)
	# 10 rather than 14: see `PANEL_H`. The page gained two rows and the only
	# alternatives were to shrink the gaps or to grow past the 720 px design
	# height, which would clip on a short window.
	var v := UiKit.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)

	var title := UiKit.label("SETTINGS", 36, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, false)
	v.add_child(title)

	# The three rows are built by the same helper, so a change to the stepper
	# also reaches the others: duplicating the block is how these drift apart
	# later and one ends up with an off-by-one range.
	var music_row := _build_row(v, "MUSIC", "music")
	_music_left = music_row["left"]
	_music_right = music_row["right"]
	_music_name = music_row["value"]
	_music_segments = music_row["segments"]

	var sfx_row := _build_row(v, "SOUND EFFECTS", "sfx")
	_sfx_left = sfx_row["left"]
	_sfx_right = sfx_row["right"]
	_sfx_name = sfx_row["value"]
	_sfx_segments = sfx_row["segments"]

	var view_row := _build_row(v, "VIEW", "view")
	_view_left = view_row["left"]
	_view_right = view_row["right"]
	_view_name = view_row["value"]
	_view_segments = view_row["segments"]

	var hint := UiKit.label(
		"Press < or > to change a setting. THE VIEW row picks if you play as Jack.",
		19, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true, PANEL_W - 90.0)
	v.add_child(hint)

	# --- Auto-hide the words ------------------------------------------------
	# A switch, not a stepper: "may the game put the task bar away after a few
	# seconds?" has only two honest answers, and the small tab it leaves behind
	# is what makes yes safe for a child who reads slowly.
	var hide_row := UiKit.hbox(14)
	hide_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hide_row.custom_minimum_size = Vector2(0, 46)
	var hide_label := UiKit.label("Hide the words after a while", 22,
		UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	hide_label.custom_minimum_size = Vector2(LABEL_W + 110.0, 0)
	hide_row.add_child(hide_label)
	_auto_hide_toggle = CheckButton.new()
	_auto_hide_toggle.button_pressed = QuestManager.auto_hide_ui
	_auto_hide_toggle.tooltip_text = "The task bar folds into a small TASK tab you can tap"
	_auto_hide_toggle.toggled.connect(func(on: bool) -> void:
		QuestManager.set_auto_hide_ui(on)
		QuestManager.save_progress()
		AudioFx.play_sfx("pop")
	)
	hide_row.add_child(_auto_hide_toggle)
	v.add_child(hide_row)

	# --- Camera follows Jack ------------------------------------------------
	# The second switch, and the same reasoning as the one above: "should the
	# view turn by itself?" is one yes/no question. It is ON by default because
	# a child who never touches the mouse would otherwise walk into a corner and
	# stay looking at the same wall — the request that added this feature was
	# literally "per semplificare la giocabilità".
	#
	# Turning it off is not a downgrade: every manual way of aiming the camera
	# stays exactly as it was (drag, Q/E, right stick), so the switch only ever
	# adds or removes the automatic part.
	var camera_row := UiKit.hbox(14)
	camera_row.alignment = BoxContainer.ALIGNMENT_CENTER
	camera_row.custom_minimum_size = Vector2(0, 46)
	var camera_label := UiKit.label("Camera follows Jack", 22,
		UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	camera_label.custom_minimum_size = Vector2(LABEL_W + 110.0, 0)
	camera_row.add_child(camera_label)
	_auto_camera_toggle = CheckButton.new()
	_auto_camera_toggle.button_pressed = QuestManager.auto_camera
	_auto_camera_toggle.tooltip_text = "The view turns by itself to stay behind Jack"
	_auto_camera_toggle.toggled.connect(func(on: bool) -> void:
		QuestManager.set_auto_camera(on)
		QuestManager.save_progress()
		AudioFx.play_sfx("pop")
	)
	camera_row.add_child(_auto_camera_toggle)
	v.add_child(camera_row)

	# --- Buttons on screen --------------------------------------------------
	# ON by default: on a tablet there is no keyboard, so without the pad the
	# child can look around and tap things but cannot walk — the game is not
	# playable at all. On a laptop the pad is merely redundant, and a child who
	# finds it in the way can fold it with the tab or switch it off here.
	var pad_row := UiKit.hbox(14)
	pad_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pad_row.custom_minimum_size = Vector2(0, 46)
	var pad_label := UiKit.label("Buttons on screen", 22,
		UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	pad_label.custom_minimum_size = Vector2(LABEL_W + 110.0, 0)
	pad_row.add_child(pad_label)
	_touch_controls_toggle = CheckButton.new()
	_touch_controls_toggle.button_pressed = QuestManager.touch_controls
	_touch_controls_toggle.tooltip_text = "A D-pad and TAP button, for a touch screen"
	_touch_controls_toggle.toggled.connect(func(on: bool) -> void:
		QuestManager.set_touch_controls(on)
		QuestManager.save_progress()
		AudioFx.play_sfx("pop")
	)
	pad_row.add_child(_touch_controls_toggle)
	v.add_child(pad_row)

	var back := UiKit.button("BACK", null, Vector2(240, 56))
	back.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_ACCENT, 4, 22))
	back.pressed.connect(func(): back_pressed.emit())
	v.add_child(back)

	refresh()


## Builds one `<  MUSIC  ▮▮▯▯  MEDIUM  >` row and hands back its moving parts.
## A Dictionary rather than a tuple because GDScript has none, and the
## alternative -- storing them as node metadata -- reads worse at the call site.
##
## The VIEW row is built by the same function with `channel == "view"`. It has no
## bars (`segments` comes back empty) because its three values are names, not
## quantities: a filled bar chart next to "NEVER" would read as "a quarter of
## something", and there is no amount of first person to show.
func _build_row(parent: VBoxContainer, title_text: String, channel: String) -> Dictionary:
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(0, ROW_H)

	var name_label := UiKit.label(title_text, 24, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, false)
	name_label.custom_minimum_size = Vector2(LABEL_W, 0)
	row.add_child(name_label)

	var left := _arrow("<", -1, channel)
	row.add_child(left)

	var segments: Array[ColorRect] = []
	if channel == "view":
		# An empty box of the bars' width, so the two kinds of row still line up
		# column for column. Zero-height would collapse the row.
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(120, 0)
		row.add_child(spacer)
	else:
		# The level is drawn, not written. The obvious choice was a run of block
		# characters ("▮▮▮▯▯"), and it measured as a *failure*: the game's font
		# stack (Comic Sans / Chalkboard / Trebuchet) has no glyph for U+25AE or
		# U+2588 -- SystemFont.has_char() returned false for every filled-block
		# codepoint -- so the page would have shown five tofu boxes. Rectangles
		# cannot fail that way.
		var value_box := UiKit.hbox(4)
		value_box.alignment = BoxContainer.ALIGNMENT_CENTER
		value_box.custom_minimum_size = Vector2(120, 0)
		for i in QuestManager.VOLUME_STEPS.size() - 1:
			var seg := ColorRect.new()
			seg.custom_minimum_size = Vector2(18, 26)
			seg.color = UiKit.COL_ACCENT
			value_box.add_child(seg)
			segments.append(seg)
		row.add_child(value_box)

	var value := UiKit.label("", 24, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, false)
	# "SOUND EFFECTS" needs less room for its value than "ALWAYS" does, but the
	# column is shared so the arrows of all three rows sit on the same vertical
	# lines. 170 px fits the longest name in `CAMERA_MODES` at 24 pt.
	value.custom_minimum_size = Vector2(170, 0)
	row.add_child(value)

	var right := _arrow(">", 1, channel)
	row.add_child(right)

	parent.add_child(row)
	return {"left": left, "right": right, "value": value, "segments": segments}


func _arrow(text: String, step: int, channel: String) -> Button:
	var b := UiKit.button(text, null, Vector2(64, ROW_H))
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_ACCENT, 4, 22))
	# The tooltip names *this* row's axis. "+1 on the view row" is not "louder".
	if channel == "view":
		b.tooltip_text = "More first person" if step > 0 else "Less first person"
	else:
		b.tooltip_text = "Louder" if step > 0 else "Softer"
	b.pressed.connect(func(): _step(channel, step))
	return b


## One press of an arrow: clamp, apply, redraw. The clamp is silent on purpose —
## pressing `>` at MAX must do nothing at all rather than wrap to OFF, because a
## child leaning on the button would otherwise silence the game.
func _step(channel: String, delta: int) -> void:
	if channel == "view":
		_step_view(delta)
		return
	# Typed by hand: `QuestManager.VOLUME_STEPS` is a const reached through the
	# autoload singleton, so the compiler sees it as Variant and refuses to infer
	# the type of `clampi(...)`.
	var step: int = clampi(QuestManager.volume_step(channel) + delta, 0,
		QuestManager.VOLUME_STEPS.size() - 1)
	if step == QuestManager.volume_step(channel):
		return
	QuestManager.set_volume(channel, step)
	QuestManager.save_progress()
	# A click on every press, plus the "ding" on the effects row only: hearing
	# the effect level while changing it is the point of that row, but hearing a
	# ding under *music* changes would be confusing about which row it belongs to.
	AudioFx.play_sfx("pop")
	if channel == "sfx":
		AudioFx.play_sfx("correct")
	refresh()
	volume_changed.emit(channel, step)


## The VIEW row. Saved immediately and applied through `QuestManager`, which
## emits `camera_mode_changed`: the level is listening and switches the camera
## on the mission that is already running, so the child sees the result before
## they close the menu.
func _step_view(delta: int) -> void:
	var mode: int = clampi(QuestManager.camera_mode + delta, 0, QuestManager.CAMERA_MODES.size() - 1)
	if mode == QuestManager.camera_mode:
		return
	QuestManager.set_camera_mode(mode)
	QuestManager.save_progress()
	AudioFx.play_sfx("pop")
	refresh()
	camera_mode_changed.emit(mode)


## Redraws every row from the saved values, and disables an arrow at each end of
## the range so the limit is visible rather than discovered by pressing.
func refresh() -> void:
	_set_row(_music_left, _music_right, _music_name, _music_segments, "music")
	_set_row(_sfx_left, _sfx_right, _sfx_name, _sfx_segments, "sfx")
	_set_view_row()
	# Without this the switch would keep the state it was built with, so a
	# setting changed from anywhere else (or a save loaded mid-session) would
	# show the wrong answer and the next press would "change" it to itself.
	if _auto_hide_toggle != null:
		_auto_hide_toggle.set_pressed_no_signal(QuestManager.auto_hide_ui)
	if _auto_camera_toggle != null:
		_auto_camera_toggle.set_pressed_no_signal(QuestManager.auto_camera)
	if _touch_controls_toggle != null:
		_touch_controls_toggle.set_pressed_no_signal(QuestManager.touch_controls)


func _set_row(left: Button, right: Button, value_label: Label,
		segments: Array[ColorRect], channel: String) -> void:
	var step := QuestManager.volume_step(channel)
	# Bars plus a word: the bars are readable at a glance from across a
	# classroom, the word is readable to a child who is learning to read.
	value_label.text = String(QuestManager.VOLUME_NAMES[step])
	for i in segments.size():
		# A filled bar is orange, an empty one is the panel colour behind a dim
		# outline -- reading as a bar chart rather than as four grey blocks.
		segments[i].color = UiKit.COL_ACCENT if i < step else UiKit.COL_TEXT_DIM.darkened(0.55)
	left.disabled = step <= 0
	right.disabled = step >= QuestManager.VOLUME_STEPS.size() - 1


func _set_view_row() -> void:
	var mode := QuestManager.camera_mode_id()
	var info: Dictionary = QuestManager.CAMERA_MODES[mode]
	_view_name.text = String(info.get("name", "AUTO"))
	_view_left.disabled = mode <= 0
	_view_right.disabled = mode >= QuestManager.CAMERA_MODES.size() - 1


func open() -> void:
	visible = true
	modulate.a = 0.0
	refresh()
	UiKit.focus_first_button(self)
	AudioFx.play_sfx("pop")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	visible = false
