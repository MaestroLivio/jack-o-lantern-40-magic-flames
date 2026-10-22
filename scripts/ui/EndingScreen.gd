class_name EndingScreen
extends Control
## The Grand Halloween Party ending.
##
## Shows the lit lantern, the fourty flames, a small certificate and a big
## "play again" button — a clear, calm finish for a 40-mission journey.

signal play_again_pressed
## Opens the twenty bonus challenges. The story is over; the bonus set is the
## only thing left to do, and the last page is where a class looks for it.
signal challenges_pressed

var _flame_grid: GridContainer
var _message: Label


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


## Panel geometry. The ending packs an emblem, a title, a message, forty
## flame glyphs, a credit line and a button, so it is sized explicitly and the
## flame wall is kept small enough to fit.
const PANEL_W := 860.0
const PANEL_H := 700.0
const WRAP_WIDTH := 730.0
const FLAME_PX := 36


func _build() -> void:
	add_child(UiKit.scrim(0.72))

	var panel := UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ACCENT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ACCENT, 8, 40))
	add_child(panel)

	var m := UiKit.margin(28)
	panel.add_child(m)
	var v := UiKit.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)

	var emblem := TextureRect.new()
	emblem.texture = UiKit.icon_texture("pumpkin", "orange", 200)
	emblem.custom_minimum_size = Vector2(96, 96)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(emblem)

	var title := UiKit.label("HAPPY HALLOWEEN!", 48, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, false)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color("3b1d00"))
	v.add_child(title)

	_message = UiKit.label("Jack's lantern is shining. All 40 magic flames are home!",
		28, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	v.add_child(_message)

	# A little wall of flames: one glyph per mission recovered.
	_flame_grid = GridContainer.new()
	_flame_grid.columns = 10
	_flame_grid.add_theme_constant_override("h_separation", 6)
	_flame_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_flame_grid)

	var credit := UiKit.label("You learnt colours, numbers, animals, body parts, shapes and directions.",
		21, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	v.add_child(credit)

	# Two buttons side by side, not one under the other. The panel has about
	# 80 px of vertical headroom in a 720 px screen and a second full-width row
	# would eat all of it; a row costs nothing because the flame wall already
	# leaves the width free.
	var actions := UiKit.hbox(16)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(actions)

	var button := UiKit.button("PLAY AGAIN", UiKit.icon_texture("star", "yellow", 96), Vector2(300, 84))
	button.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.COL_GREEN.darkened(0.45), UiKit.COL_GREEN, 6, 30))
	button.add_theme_stylebox_override("hover", UiKit.panel_style(UiKit.COL_GREEN.darkened(0.3), UiKit.COL_GREEN.lightened(0.25), 7, 30))
	button.pressed.connect(func(): play_again_pressed.emit())
	actions.add_child(button)

	# The bonus challenges, offered where the class has just run out of story.
	# Deliberately *not* the green "play" colour: it is a different thing from
	# replaying the adventure, and a child who presses it expects more game,
	# not a restart.
	var extra := UiKit.button("CHALLENGES", null, Vector2(300, 84))
	extra.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_PINK, 6, 30))
	extra.add_theme_stylebox_override("hover", UiKit.panel_style(UiKit.COL_PANEL.lightened(0.16), UiKit.COL_PINK.lightened(0.2), 7, 30))
	extra.tooltip_text = "Twenty bonus puzzles with no glowing squares"
	extra.pressed.connect(func(): challenges_pressed.emit())
	actions.add_child(extra)


func open() -> void:
	visible = true
	modulate.a = 0.0
	for child in _flame_grid.get_children():
		child.queue_free()
	for i in 40:
		var flame := TextureRect.new()
		flame.texture = UiKit.icon_texture("flame", "orange" if i < QuestManager.flames else "grey", 48)
		flame.custom_minimum_size = Vector2(FLAME_PX, FLAME_PX)
		flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flame.modulate.a = 0.0
		flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flame_grid.add_child(flame)
		# Flames pop in one by one: a tiny reward for finishing everything.
		var tween := create_tween()
		tween.tween_property(flame, "modulate:a", 1.0, 0.2).set_delay(0.25 + i * 0.035)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	# Gamepad / Tab: PLAY AGAIN is the only button, so it is the one focused.
	UiKit.focus_first_button(self)


func close() -> void:
	visible = false
