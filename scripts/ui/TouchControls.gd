class_name TouchControls
extends Control
## On-screen controls for touch screens: a D-pad, an interact button and the
## magnifying glass. Switched on by default, and foldable into a small tab.
##
## ## Why a D-pad at all
##
## Everything else in this game already works with a finger, because a tap is
## just a click: `Level._input` reads `InputEventMouseButton`, and Godot's
## `input_devices/pointing/emulate_mouse_from_touch` (on by default) turns a
## finger into exactly that event. Picking up a pumpkin, pressing OK, choosing
## an answer — all of it already worked on a tablet.
##
## What a touch screen *cannot* do is walk. There is no key to hold. That is the
## whole reason this file exists, and it is why the D-pad is the main element
## and the action buttons are almost an afterthought.
##
## ## Why the pad is on the left edge and not in a bottom corner
##
## Measured, not chosen. The bottom strip of a 1280x720 design frame is already
## fully spoken for:
##
##   HUD task bar        x   16..1264   y 530..708
##   TASK tab (folded)   x   16.. 184   y 656..708
##
## so a pad in the bottom-left corner would land squarely on the folded TASK tab,
## and one in the bottom-right would sit under the opaque task bar. The left
## edge, vertically centred (y 242..478, x 16..424 — the last figure measured
## with `overlap_check.gd`, not added up from the constants), clears both,
## clears the counting card (x 834..1264), and is where a thumb actually rests
## on a tablet held in landscape. That is where the pad *starts*; it is no longer
## where it has to stay, see "## Moving the pad" below.
##
## It does *not* clear the dialogue box (x 220..1060, y 384..684) or the quiz
## card (x 160..1120, y 80..640). That is not an oversight: both of those take
## the screen and block movement anyway, so `set_screen_covered()` hides the pad
## for as long as either is up. A D-pad drawn over a question is a control that
## does nothing, in front of the answer the child is reading.
##
## ## Why the arrows are pictures and not characters
##
## The font stack is `Comic Sans MS / Chalkboard SE / Trebuchet MS / Verdana /
## Arial`, and *not one of them* contains an arrow glyph. Measured with a
## `has_char()` probe: `↑ ↓ ← → ▲ ▼ ◀ ▶ ⤴` all come back false, so a button
## labelled with an arrow renders as an empty box. This is the same trap already
## recorded in `SoundPanel.gd` for `▮`/`▯`, and in `Hud.gd` for the small tab.
## The arrows here are therefore `UiKit`'s drawn triangle texture, rotated in
## quarters — a real shape, in the game's own palette, on every machine.
##
## ## Input: two different mechanisms, on purpose
##
## Movement uses `Input.action_press()` / `Input.action_release()`, which set the
## action's *state* without producing an event. That is exactly what is needed:
## `Jack._physics_process` reads `Input.get_vector(...)` every frame, so the child
## simply keeps walking while the finger is down, and `_ui_blocked` still stops
## it dead during a quiz — the pad gets no privileges the keyboard does not have.
##
## The action buttons cannot work that way. `Level._unhandled_input()` acts on
## `event.is_action_pressed("interact")`, and `action_press()` raises no such
## event, so pressing it would move the state and do nothing visible. Those two
## buttons therefore synthesise a real `InputEventAction` through
## `Input.parse_input_event()`, which travels the ordinary pipeline and is then
## seen — and gated — by every guard the keyboard goes through.

## ## Moving the pad
##
## The left edge is a good default and a poor law. Which corner is *comfortable*
## depends on the hand, on whether the tablet is in a case, on whether the child
## is right- or left-handed, and on where the teacher put the screen — and a
## thumb that has to reach around a case has a much shorter reach than the one
## the measurement above assumed. So the whole cluster can be dragged anywhere,
## and the position is remembered in the save file next to the other settings.
##
## Three decisions in that sentence, each of which was something else first:
##
##   * **A dedicated grip, not the buttons.** Dragging from an arrow button would
##     fight the `mouse_exited` release rule in `_direction_button()`: the finger
##     slides off, the action is released, and then the same finger keeps moving
##     the pad. A child who grabbed "forward" to drag it would find Jack stopped
##     for no visible reason, and one who dragged *towards* an arrow would start
##     walking. The grip is its own narrow strip that does nothing but move.
##   * **The grip is at the bottom of the cluster, under the fold strip.** The
##     fold strip is already at the outer end of the row, where a thumb reaching
##     for "left" cannot hit it by mistake. A drag surface between the arrows and
##     the fold strip would sit exactly where that thumb lands.
##   * **Clamped, always.** A pad dragged half off the screen is a pad that can
##     never be dragged back, and one dragged fully off is gone with no way to
##     recover it short of deleting the save file. Every assignment to the
##     position goes through `_clamp_origin()`, including the one that reads the
##     value back from disk: a save file edited by hand, or one written on a
##     1280x720 screen and opened in a narrow window, must not strand the pad.
##
## The position is stored as the **top-left corner of the cluster, in canvas
## pixels**, not as the old anchor-relative `offset_left` / `offset_top` pair.
## Two reasons: a corner is what `Rect2` clamping is written in, and the folded
## tab has to land on the *same* corner as the open pad or the pad visibly jumps
## sideways when it is folded. A single origin is the only representation where
## "the tab is where the pad was" is true by construction rather than by two
## offsets that must be kept in step.
##
## A drag emits nothing and presses nothing: `_gui_input` on the grip calls
## `accept_event()`, so the motion never reaches `CameraRig` (which would orbit
## the view) or `Level._try_click()` (which would pick up the prop drawn behind).
## Starting a drag also calls `_release_all()`, so a finger that began on an
## arrow and slid onto the grip cannot leave Jack walking.

## The pad and the tab, in 1280x720 design pixels. See the header for the
## measurement that put them on the left edge, and "## Moving the pad" for why
## that is only where they *start*.
const CELL := 76.0
const CELL_GAP := 4.0
## Distance from the left edge of the design frame, kept even after the pad can
## be moved: it is the default the child gets on a fresh save, and it is where
## `_default_origin()` puts the cluster back on one.
const PAD_LEFT := 16.0
## The action buttons sit in a column immediately right of the D-pad, inside the
## same band, so a child who has found the arrows finds the rest by looking
## sideways. They are sized differently on purpose: TAP is pressed constantly
## and is the bigger target, the magnifying glass is a rare, optional helper.
const INTERACT_SIZE := 104.0
const HELP_SIZE := 88.0
const ACTION_GAP := 12.0
## The strip that folds the pad away. It sits at the *outer* end of the cluster,
## past the action buttons, and not next to the arrows: a thumb reaching for
## "left" lands within a few pixels of its neighbour, and folding the controls
## away mid-step is a far worse misfire than walking the wrong way for a moment.
## It is a tall, narrow bar rather than a fourth square button because the pad
## has no room left at the bottom (the task bar starts at y 530 and the pad ends
## at 504): a square button would have had to be either too small to hit or
## push the whole row down into the bar.
const FOLD_W := 36.0
const FOLD_H := CELL * 2.0
## Full width of the pad block: the 3-cell cross, its two inner gaps, the gap to
## the action column, the action column itself, and the folding strip.
##
## This is a *floor*, not the realised width: `UiKit.button()` gives every
## button 22 px of content margin a side, so the magnifying glass's 64 px icon
## makes its column 112 px wide however small `HELP_SIZE` is asked to be, and the
## fold column's 36 px strip likewise becomes 44. A `Container` refuses to be
## sized below its own minimum. `layout_check.gd` measured the block at 408 px
## (the constants add up to 400), so anything that needs the real number asks
## `_pad.size` after it has been laid out — see `_apply_origin()`.
const PAD_W := CELL * 3.0 + CELL_GAP * 2.0 + ACTION_GAP + INTERACT_SIZE + ACTION_GAP + FOLD_W
## Height of the block: the three D-pad cells and the two gaps between them.
## Written down rather than left implicit in a pair of anchor offsets, because
## the block is now positioned from its top-left corner and the height is what
## the clamp needs.
const PAD_H := CELL * 3.0 + CELL_GAP * 2.0
## The grip: the strip a finger pushes to move the whole cluster.
##
## It lives directly *under* the fold strip, in the same 36 px column, and it
## takes exactly the height the fold strip left over (`PAD_H` minus the strip
## and one gap). That puts it at the far end of the pad from every arrow — the
## same argument that put the fold strip there — while costing no extra width
## and no extra height, so the block's measured rect does not change at all.
##
## 36 x 72 px looks small next to a 76 px arrow, and it is deliberately not held
## to the thumb-target rule the arrows are: it is dragged, not tapped, and a
## drag that starts a few pixels off still grabs it, which is exactly what a
## slop-tolerant gesture buys. A wider grip would have had to make the pad
## wider, and the pad is already 408 px of a 1280 px screen.
const GRIP_H := PAD_H - FOLD_H - ACTION_GAP
## How far a finger has to travel before a press on the grip becomes a drag.
##
## A resting thumb wobbles two or three pixels, and a "drag" of one pixel would
## make every press on the folded tab a two-pixel move. `Level.CLICK_DRAG_TOLERANCE`
## is 8 px for the same reason and `CameraRig.drag_threshold` the same order;
## this one is tighter because nothing else is competing for the gesture — there
## is no tap meaning to lose on the grip, only on the tab it shares the handler
## with.
const DRAG_TOLERANCE := 6.0
## Keeps the cluster off the very edge of the screen, so its rounded border is
## never clipped and a finger has something to aim at. Smaller than `PAD_LEFT`
## on purpose: a child who wants the pad flush left should be able to get it
## there, and 8 px is still visibly inside the frame.
const EDGE_MARGIN := 8.0
## The folded tab. It is a tall, narrow pill, and it is drawn at the *same
## corner* the open pad occupies (vertically centred inside the pad's band),
## *not* in the bottom-left corner like the TASK tab: the bottom-left corner is
## taken, and the task bar covers everything else down there. Sharing the corner
## is what makes folding look like the pad shrinking rather than jumping.
const TAB_W := 56.0
const TAB_H := 128.0
## Radius of the small triangular arrow inside each direction button.
const ARROW_PX := 88

## What each direction button drives, and what it says when hovered. The
## InputMap actions are the ones in `project.godot`, so the pad needs no support
## at all from `Jack` or `Level`.
const DIRECTIONS := {
	"up": {"action": "move_forward", "tip": "Walk forward"},
	"down": {"action": "move_back", "tip": "Walk back"},
	"left": {"action": "move_left", "tip": "Walk left"},
	"right": {"action": "move_right", "tip": "Walk right"},
}

var _pad: VBoxContainer
var _tab: Button
## The strip a finger pushes to move the whole cluster. See "## Moving the pad".
var _grip: Button
## Top-left corner of the open cluster, in canvas pixels. The *only* record of
## where the pad is: both `_pad` and `_tab` are placed from it, so the folded tab
## lands on the corner the open pad occupies and folding cannot make the pad
## jump sideways. `(-1, -1)` means "not placed yet" and is not a valid position;
## `_apply_origin()` replaces it with `_default_origin()` before it is used.
var _origin := Vector2(-1, -1)
## True once the current press has travelled past `DRAG_TOLERANCE` and become a
## drag. Until then a press on the tab is still a tap, and a tap must fold.
var _dragging := false
## Total travel of the current press, in canvas pixels, summed from the motion
## events' `relative`. A finger that returns to where it started sums to zero,
## so the press never becomes a drag.
##
## A delta rather than "corner = finger - grab": the pad moves *with* the hand,
## so the grip's own position changes on every event that follows. Recomputing
## the corner from a control that has already moved by the last delta feeds that
## motion back into the next one, and the pad accelerates away from the finger.
var _drag_total := Vector2.ZERO
## Where the corner was when the current press started.
var _drag_start_origin := Vector2.ZERO
## True while the pointer is down on the grip or the tab, before it is known
## whether the gesture will be a tap or a drag.
var _press_active := false
## Set when a drag ends, and read by the tab's `pressed` handler.
##
## `Button` reports a press-and-release on the tab as `pressed` whatever the
## pointer did in between, and the `gui_input` signal we watch fires *before*
## `BaseButton._gui_input()` in the same dispatch — so there is no ordering in
## which marking the event handled could stop the button from reporting itself.
## The only honest fix is to look at the flag when the report arrives: a release
## that ended a drag is not a tap, and must not unfold the pad.
var _suppress_tap := false
## Directions currently held, so `_release_all()` knows what to let go of even
## if the button that started it has already been freed.
var _held: Dictionary = {}
## Folded by the child (or by us when a panel takes the screen).
var _folded := false
## A quiz / repeat panel / dialogue box owns the screen: the pad is not usable
## and is hidden rather than left sitting on top of the question.
var _covered := false
## False while a menu or a story page is the thing on screen.
##
## Kept here rather than letting `Main` write `visible` directly, because there
## are now *three* independent reasons for the pad to be off — the setting, the
## fold, and whatever screen is up — and a single `visible = ...` assignment
## from outside would quietly overrule the other two. That is the same class of
## bug `Hud._prompt_suppressed` vs `Hud._dialogue_hidden` was split apart to fix.
var _gameplay_active := true


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The root ignores the mouse: the world behind the pad stays clickable and
	# draggable, which is what lets a child still tap a prop next to the D-pad.
	# Only the buttons themselves ask for the pointer. `Level._try_click()`
	# covers the other half of this bargain by asking `blocks_point()`.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_pad()
	_build_tab()
	QuestManager.touch_controls_changed.connect(_on_touch_controls_changed)
	QuestManager.touch_pad_position_changed.connect(_on_touch_pad_position_changed)
	# A position read from disk is *not* trusted: it may have been written on a
	# bigger screen, or by a build whose block was a different size. `_apply_origin()`
	# clamps whatever it is given, and only after the layout has run, because the
	# clamp needs the real width of the block (`_pad.size`), not `PAD_W`.
	_origin = QuestManager.touch_pad_position
	_apply_visibility()
	# The block has no size until the container has been laid out, and
	# `_clamp_origin()` needs the real one: 408 px, not the 392 the constants add
	# up to. The first `_apply_origin()` above therefore clamps with the fallback
	# width, and this makes the true clamp happen as soon as the size is known —
	# also whenever a font-scale change or the easy-read toggle resizes the
	# block. A `resized` signal fires on size only, so re-entering `_apply_origin()`
	# (which sets `position`, never `size`) cannot loop.
	_pad.resized.connect(_apply_origin)
	# Rotating a tablet or resizing a window changes the room available. Without
	# this the pad stays where the old screen allowed and can end up half outside
	# the new one, which is the one state the whole clamping argument exists to
	# avoid.
	get_viewport().size_changed.connect(_on_viewport_resized)


# --- Construction ----------------------------------------------------------

func _build_pad() -> void:
	_pad = UiKit.vbox(ACTION_GAP)
	# Anchored to the top-left and positioned by `_apply_origin()` rather than
	# centred on the left edge: the pad is now dragged, and an anchor is a second
	# opinion about where it goes. With `PRESET_TOP_LEFT` the anchor is the frame
	# corner and `position` *is* the origin, so the clamp compares like with like.
	# Under the old `PRESET_CENTER_LEFT` a stored `(16, 242)` would have meant
	# something different on every window height, and the pad would have drifted
	# downwards whenever the window grew.
	_pad.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)

	var row := UiKit.hbox(ACTION_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Not the centred default `UiKit.hbox()` gives: the D-pad must stay hard
	# against the left edge, with the action column butting up to its right.
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_pad.add_child(row)

	row.add_child(_build_dpad())
	row.add_child(_build_actions())
	row.add_child(_build_fold_column())


## The four directions, laid out as a cross in a 3x3 grid. The five empty cells
## are real `Control`s rather than gaps in the grid, so the cross stays square
## and each arrow keeps its place when the font scale changes.
func _build_dpad() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(CELL_GAP))
	grid.add_theme_constant_override("v_separation", int(CELL_GAP))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var slots := ["", "up", "", "left", "", "right", "", "down", ""]
	for slot in slots:
		if String(slot) == "":
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(CELL, CELL)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(spacer)
			continue
		grid.add_child(_direction_button(slot))
	return grid


func _direction_button(direction: String) -> Button:
	var action := String(DIRECTIONS[direction]["action"])
	var b := UiKit.button("", null, Vector2(CELL, CELL))
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = String(DIRECTIONS[direction]["tip"])
	b.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.04), UiKit.COL_ORANGE.lightened(0.1), 4, 20))
	b.add_theme_stylebox_override("hover",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.14), UiKit.COL_ORANGE, 5, 20))
	b.add_theme_stylebox_override("pressed",
		UiKit.panel_style(UiKit.COL_ORANGE.darkened(0.35), UiKit.COL_ACCENT, 5, 20))

	var arrow := TextureRect.new()
	arrow.texture = UiKit.icon_texture("triangle", "white", ARROW_PX)
	arrow.custom_minimum_size = Vector2(CELL * 0.52, CELL * 0.52)
	arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	arrow.offset_left = -CELL * 0.26
	arrow.offset_right = CELL * 0.26
	arrow.offset_top = -CELL * 0.26
	arrow.offset_bottom = CELL * 0.26
	# Rotate around the middle of the *texture*, which is where a `Control`'s
	# pivot lives by default in local coordinates only if it is told to be.
	arrow.pivot_offset = Vector2(CELL * 0.26, CELL * 0.26)
	arrow.rotation = {
		"up": 0.0,
		"right": PI * 0.5,
		"down": PI,
		"left": -PI * 0.5,
	}[direction]
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(arrow)

	# `button_down` / `button_up` rather than `pressed`: a D-pad has to keep
	# moving while the finger stays on it, and `pressed` only fires on release.
	b.button_down.connect(_hold.bind(action))
	b.button_up.connect(_release.bind(action))
	# A finger that slides off the button is a finger that has stopped pressing
	# it. Without this the child walks into a wall forever after dragging a
	# thumb off the edge, which is the single nastiest failure mode of an
	# on-screen pad.
	b.mouse_exited.connect(_release_if_held.bind(action))
	return b


func _build_actions() -> Control:
	var col := UiKit.vbox(ACTION_GAP)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	col.add_child(_action_button("interact", Vector2(INTERACT_SIZE, INTERACT_SIZE), "hand"))
	col.add_child(_action_button("help", Vector2(HELP_SIZE, HELP_SIZE), "star"))
	return col


## An action that fires a real input event. `hand` has no icon of its own in
## `UiKit`, so the interact button carries the word on it: at 104 px there is
## room, and a 7-year-old reads "TAP" faster than any icon we could draw.
func _action_button(action: String, size: Vector2, icon: String) -> Button:
	var label := "TAP" if action == "interact" else ""
	var texture: Texture2D = UiKit.icon_texture(icon, "pink", 96) if icon != "hand" else null
	var b := UiKit.button(label, texture, size)
	b.focus_mode = Control.FOCUS_NONE
	if action == "interact":
		b.add_theme_font_size_override("font_size", 24)
		b.tooltip_text = "Pick up / talk"
	else:
		b.tooltip_text = "Magic magnifying glass"
	b.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.04),
			UiKit.COL_PINK if action == "help" else UiKit.COL_ACCENT, 4, 26))
	b.add_theme_stylebox_override("hover",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.16),
			UiKit.COL_PINK.lightened(0.2) if action == "help" else UiKit.COL_ACCENT.lightened(0.2), 5, 26))
	b.add_theme_stylebox_override("pressed",
		UiKit.panel_style(UiKit.COL_PANEL.darkened(0.1),
			UiKit.COL_PINK if action == "help" else UiKit.COL_ACCENT, 5, 26))
	b.button_down.connect(_fire_action.bind(action))
	return b


## The strip that folds the pad. It carries a drawn chevron pointing *left*,
## towards the edge the pad slides into, because it is the only element on
## screen whose meaning is not obvious from its shape: TAP says what it does,
## an arrow says which way Jack walks, and this one has to say "put the rest
## away". The triangle is `UiKit`'s own texture rotated a quarter turn, for the
## same reason the D-pad uses one.
func _build_fold_strip() -> Button:
	var b := UiKit.button("", null, Vector2(FOLD_W, FOLD_H))
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Hide the buttons"
	b.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL.darkened(0.15), UiKit.COL_ORANGE.darkened(0.25), 3, 18))
	b.add_theme_stylebox_override("hover",
		UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ORANGE, 4, 18))
	b.add_theme_stylebox_override("pressed",
		UiKit.panel_style(UiKit.COL_ORANGE.darkened(0.4), UiKit.COL_ACCENT, 4, 18))
	var chevron := TextureRect.new()
	chevron.texture = UiKit.icon_texture("triangle", "orange", 72)
	chevron.custom_minimum_size = Vector2(FOLD_W * 0.6, FOLD_W * 0.6)
	chevron.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	chevron.offset_left = -FOLD_W * 0.3
	chevron.offset_right = FOLD_W * 0.3
	chevron.offset_top = -FOLD_W * 0.3
	chevron.offset_bottom = FOLD_W * 0.3
	chevron.pivot_offset = Vector2(FOLD_W * 0.3, FOLD_W * 0.3)
	chevron.rotation = -PI * 0.5
	chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(chevron)
	b.pressed.connect(func():
		set_folded(true)
		AudioFx.play_sfx("pop")
	)
	return b


## The fold strip with the grip stacked underneath it, in one 36 px column.
##
## A `VBoxContainer` and not two siblings of the row, because the two have to
## stay in the same column: the grip is `PAD_H - FOLD_H - ACTION_GAP` tall, and
## that arithmetic is only true if the strip above it is the width of the column
## and they are laid out with exactly `ACTION_GAP` between them. As two children
## of the row they would be side by side, and the pad would be 36 px wider than
## `PAD_W` says for no visible gain.
func _build_fold_column() -> Control:
	var col := UiKit.vbox(ACTION_GAP)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_build_fold_strip())
	_grip = _build_grip()
	col.add_child(_grip)
	return col


## The strip a finger pushes to move the whole cluster. See "## Moving the pad".
##
## Three small dots rather than a glyph: the font stack has no drag handle or
## arrow-up-down character (the same `has_char()` measurement the header records
## for the arrows), and three `UiKit` circles in a column read as "grip" on any
## machine, at any font size, without needing a word in it.
##
## `MOUSE_FILTER_STOP` is the important line. The root ignores the mouse so the
## world stays tappable, and every other button asks for the pointer on its own;
## this one has to as well, or the drag would begin on a control that never sees
## the motion and `_gui_input` would never run.
func _build_grip() -> Button:
	var b := UiKit.button("", null, Vector2(FOLD_W, GRIP_H))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	# Not one of the strings the probes look for: they find the direction
	# buttons by tooltip, and a new tooltip that happened to say "Walk left"
	# would make `_direction_button()` return this strip instead.
	b.tooltip_text = "Move the buttons"
	b.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL.darkened(0.22), UiKit.COL_TEXT_DIM.darkened(0.35), 3, 16))
	b.add_theme_stylebox_override("hover",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_ORANGE, 4, 16))
	b.add_theme_stylebox_override("pressed",
		UiKit.panel_style(UiKit.COL_ORANGE.darkened(0.45), UiKit.COL_ACCENT, 4, 16))

	var dots := UiKit.vbox(5)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var texture: Texture2D = UiKit.icon_texture("circle", "white", 24)
	for _i in 3:
		var dot := TextureRect.new()
		dot.texture = texture
		dot.custom_minimum_size = Vector2(10, 10)
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
	b.add_child(dots)

	# One handler for the whole gesture. `Button` does not report motion, so
	# `_gui_input` on the button itself is the only place a drag can be seen;
	# `button_down` / `button_up` would tell us it was pressed but not where the
	# finger went. `pressed` is deliberately *not* connected: the grip has no
	# tap meaning, and a child who taps it once is not asking to fold anything.
	b.gui_input.connect(_on_drag_input)
	return b


func _build_tab() -> void:
	_tab = UiKit.button("", UiKit.icon_texture("star", "orange", 64), Vector2(TAB_W, TAB_H))
	_tab.tooltip_text = "Show the controls"
	_tab.focus_mode = Control.FOCUS_NONE
	# Positioned from `_origin` like the pad, by `_apply_origin()`, and not from
	# an anchor preset: the tab has to sit on the same corner the open pad
	# occupies, and *that* corner is now a stored value. Two anchors kept in step
	# by hand were the alternative, and they are exactly the pair that drifts.
	_tab.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_tab.size = Vector2(TAB_W, TAB_H)
	_tab.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ORANGE, 4, 24))
	_tab.add_theme_stylebox_override("hover",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.14), UiKit.COL_ORANGE.lightened(0.25), 5, 24))
	_tab.add_theme_stylebox_override("pressed",
		UiKit.panel_style(UiKit.COL_PANEL.darkened(0.08), UiKit.COL_ORANGE, 4, 24))
	_tab.visible = false
	# The tab is the only thing on screen when the pad is folded, so it is also
	# the only thing a child could grab to move the pad out of the way of a
	# puzzle. Dragging it moves the cluster; a tap on it unfolds, exactly as
	# before. `_suppress_tap` is what tells the two apart, because `pressed`
	# arrives either way.
	_tab.gui_input.connect(_on_drag_input)
	_tab.pressed.connect(func():
		if _suppress_tap:
			_suppress_tap = false
			return
		set_folded(false)
		AudioFx.play_sfx("pop")
	)
	add_child(_tab)


# --- Moving the pad --------------------------------------------------------

## Home position: the measured left edge, vertically centred in the frame.
##
## Computed from the live viewport height rather than written down as the 242 px
## the header quotes, because `--headless` reports a 1280x1280 visible rect and a
## window can be any size; the pad must start centred on the screen it is on.
func _default_origin() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(PAD_LEFT, vp.y * 0.5 - PAD_H * 0.5)


## Clamps a wanted origin so the whole cluster stays on screen.
##
## The width used is `_pad.size.x` and not `PAD_W`: `UiKit.button()` gives every
## button 22 px of content margin a side, so the magnifying-glass column is
## 112 px wide however small `HELP_SIZE` asks for, and the block really measures
## 408 px. Clamping with the 400 the constants add up to would let the right-hand
## 8 px of the fold column hang off the screen — and the moment a child drags the
## pad as far right as it goes is exactly the moment they most want it reachable.
##
## A zero or unlaid-out `_pad.size.x` falls back to `PAD_W` rather than clamping
## to the left edge: `_apply_origin()` runs from `_ready()` before the layout
## pass has sized anything, and a fallback that scrambled the stored position
## would undo a drag on every launch.
func _clamp_origin(wanted: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	var w := _pad.size.x if _pad != null and _pad.size.x > 0.0 else PAD_W
	var h := _pad.size.y if _pad != null and _pad.size.y > 0.0 else PAD_H
	var max_x := maxf(EDGE_MARGIN, vp.x - EDGE_MARGIN - w)
	var max_y := maxf(EDGE_MARGIN, vp.y - EDGE_MARGIN - h)
	return Vector2(clampf(wanted.x, EDGE_MARGIN, max_x), clampf(wanted.y, EDGE_MARGIN, max_y))


## Places the pad and the tab from `_origin`. The single writer of both rects.
##
## `_origin` may hold the `(-1, -1)` "never moved" sentinel; this is where that
## becomes the home position, once, so every later reader sees a real point. It
## is also where a stored position meets this session's window: clamping happens
## on assignment, so a save written on a big screen cannot strand the pad half
## off a small one.
func _apply_origin() -> void:
	if _origin.x < 0.0 or _origin.y < 0.0:
		_origin = _default_origin()
	_origin = _clamp_origin(_origin)
	if _pad != null:
		_pad.position = _origin
	if _tab != null:
		# Vertically centred in the band the open pad occupies, so folding looks
		# like the pad shrinking to its left-hand part rather than sliding up.
		_tab.position = _origin + Vector2(0, (PAD_H - TAB_H) * 0.5)


## Moves the cluster and remembers it. Public: the probes call this instead of
## synthesising a drag, because `push_input()` does not reach the GUI in a
## headless run (measured — `gui_get_hovered_control()` stays null).
func set_pad_position(wanted: Vector2) -> void:
	_origin = _clamp_origin(wanted)
	_apply_origin()
	QuestManager.set_touch_pad_position(_origin)


## The origin after clamping, for probes and for the settings preview.
func pad_position() -> Vector2:
	if _origin.x < 0.0 or _origin.y < 0.0:
		_origin = _clamp_origin(_default_origin())
	return _origin


## Turns a pointer event on the grip or the tab into a drag.
##
## `gui_input` reports positions in the receiving control's own coordinates, but
## the motion is applied as a **delta** (`InputEventMouseMotion.relative`), and a
## delta is the same number in the grip's frame as in the canvas frame: the grip
## is not scaled or rotated relative to the canvas, so its 1 px is the canvas's
## 1 px even with `stretch/mode="canvas_items"` rescaling the 1280x720 design
## frame onto the real window. That is why nothing here converts coordinates,
## and it is the only reason the drag works at every window size.
##
## The *press* is deliberately not accepted. Godot calls the `gui_input` signal
## before `BaseButton._gui_input()`, so `accept_event()` here would stop the
## button from ever registering the press — and the tab, whose tap means
## "unfold", would stop responding to a real finger while the probe that emits
## `pressed` by hand went on passing. The gesture is kept away from the rest of
## the game the way every other button here keeps it away: both the grip and the
## tab are `MOUSE_FILTER_STOP`, which is what stops `CameraRig._unhandled_input()`
## ever seeing the press and starting an orbit. `accept_event()` on the motion is
## belt and braces for the drag itself, which must not turn the view.
func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_drag()
		else:
			_end_drag()
		return
	if event is InputEventMouseMotion and _press_active:
		# `relative` is the travel since the previous motion event, so it sums to
		# the total no matter how many events arrive. A finger that wobbles back
		# to where it started sums to zero and the press never becomes a drag.
		_drag_total += (event as InputEventMouseMotion).relative
		_drag_to(_drag_total)
		if _dragging:
			accept_event()


## Starts a press on the grip or the tab. No argument: a drag is a *delta* from
## where the pad already is, not a position, so there is nothing to remember
## about the finger's starting point.
func _begin_drag() -> void:
	_press_active = true
	_dragging = false
	_suppress_tap = false
	_drag_total = Vector2.ZERO
	_drag_start_origin = _origin
	# A finger that started on an arrow and slid onto the grip would otherwise
	# keep Jack walking for the whole drag: the arrow's `mouse_exited` fires, but
	# a child can start the press *on* the grip while a previously held direction
	# is still down from another finger, and two fingers on a pad is normal.
	_release_all()


func _drag_to(total: Vector2) -> void:
	if not _press_active:
		return
	if not _dragging:
		if total.length() < DRAG_TOLERANCE:
			return
		_dragging = true
		_suppress_tap = true
	# Applied to the corner the press *started* from, so the block travels with
	# the hand instead of jumping under it — and so the arithmetic reads a fixed
	# number rather than a control that has already moved.
	_origin = _clamp_origin(_drag_start_origin + total)
	_apply_origin()


func _end_drag() -> void:
	if not _press_active:
		return
	_press_active = false
	if not _dragging:
		return
	_dragging = false
	# Only a real move is worth saving, and only a real move makes a sound: a
	# tap on the grip is not an action, and a save per tap would be one
	# `FileAccess.open` for every child who brushed the pad by accident.
	AudioFx.play_sfx("pop")
	QuestManager.set_touch_pad_position(_origin)
	QuestManager.save_progress()


## A release that happens away from the grip is still the end of the drag.
##
## Without this the flag would stay set for the rest of the session: the pad is
## clamped, so a finger that keeps pushing at the edge slides off the grip, the
## grip never sees the `button_up`, and the *next* tap on the folded tab would be
## swallowed by `_suppress_tap`. The root ignores the mouse for picking, but
## `_input` is a node callback and still runs.
func _input(event: InputEvent) -> void:
	if not _press_active:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_end_drag()


func _on_touch_pad_position_changed(pos: Vector2) -> void:
	# Another `TouchControls` (a rebuild, or a probe driving the manager) moved
	# the pad. Obeying the signal instead of reading the value once is what keeps
	# the two in step after `Main._rebuild_ui()` frees and rebuilds the overlay.
	if pos.is_equal_approx(_origin):
		return
	_origin = pos
	_apply_origin()


func _on_viewport_resized() -> void:
	_apply_origin()


# --- Pressing and releasing -------------------------------------------------

func _hold(action: String) -> void:
	if not InputMap.has_action(action):
		return
	_held[action] = true
	Input.action_press(action)


func _release(action: String) -> void:
	if not _held.has(action):
		return
	_held.erase(action)
	Input.action_release(action)


func _release_if_held(action: String) -> void:
	_release(action)


## Fires a one-shot gameplay action through the normal input pipeline.
##
## `pressed = true` only: `Level` reacts to `is_action_pressed`, and a matching
## "release" event would be a second, meaningless dispatch. `InputEventAction`
## created by hand has no device and no key, which is exactly right — it is not
## pretending to be a keyboard.
func _fire_action(action: String) -> void:
	if not InputMap.has_action(action):
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ev.strength = 1.0
	Input.parse_input_event(ev)


## Lets go of every direction. Called from every path that can hide the pad: a
## finger that is never told to stop would leave Jack walking for the rest of the
## session, and the child would have no idea why.
func _release_all() -> void:
	for action in _held.keys():
		if InputMap.has_action(String(action)):
			Input.action_release(String(action))
	_held.clear()


func _notification(what: int) -> void:
	# Hidden by the pause menu, by a quiz, by the end of the run: all of them
	# must not leave a direction stuck down.
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_release_all()


func _exit_tree() -> void:
	_release_all()


# --- Visibility ------------------------------------------------------------

## Folds the pad away, leaving the tab. Public so the settings preview and the
## probes can drive it the way a child would.
func set_folded(value: bool) -> void:
	_folded = value
	_apply_visibility()


func is_folded() -> bool:
	return _folded


## True while a panel the child is reading owns the screen.
##
## The pad is not merely useless there, it is *in the way*: the quiz panel spans
## x 160..1120, y 80..640 and would be drawn over by an interactive D-pad. Since
## movement is blocked anyway while a panel is up, hiding costs nothing.
func set_screen_covered(covered: bool) -> void:
	if covered == _covered:
		return
	_covered = covered
	_apply_visibility()


func _on_touch_controls_changed(_enabled: bool) -> void:
	_apply_visibility()


## False while a menu, a story page or the ending is the thing on screen.
##
## `Main._set_gameplay_active()` is what calls this, and it is deliberately the
## same signal that hides the HUD: the two overlays answer to the same question
## ("is the world the thing in front of the child?"), so they cannot drift.
func set_gameplay_active(active: bool) -> void:
	if active == _gameplay_active:
		return
	_gameplay_active = active
	_apply_visibility()


func _apply_visibility() -> void:
	# The three reasons are folded into one answer here rather than applied to
	# the children one at a time, because the root's own `visible` is what
	# `blocks_point()` asks first: a root left visible while `_covered` was
	# true still answered "not blocking", so the overlay looked hidden and the
	# invariant "hidden means nothing of ours holds a key down" could not be
	# read off a single flag. `touch_check.gd` caught it: with a quiz open the
	# pad's buttons were gone but the node was still visible.
	var enabled := QuestManager.touch_controls and _gameplay_active and not _covered
	visible = enabled
	if not enabled:
		# `visible = false` already reaches `_notification`, but doing it here
		# too keeps the invariant local: whenever the pad is not shown, nothing
		# of ours is holding a key down.
		_release_all()
	var show_pad := enabled and not _folded
	var show_tab := enabled and _folded
	# Re-applied from `_origin` on every change, not only while visible. The
	# window may have been resized while a quiz owned the screen, and the pad is
	# the one thing in this overlay whose position is a *number* rather than an
	# anchor: without this, unfolding after a rotation would put it back where
	# the old screen size allowed.
	_apply_origin()
	_pad.visible = show_pad
	_tab.visible = show_tab
	if not show_pad:
		_release_all()


## True when a screen point lands on the pad or its tab.
##
## Mirrors `Hud.blocks_point()` and exists for the same reason: `Level._input`
## sees a press *before* the GUI does, so without this a tap on "forward" would
## also raycast the world behind the button and pick up whatever pumpkin is drawn
## under it.
func blocks_point(at: Vector2) -> bool:
	if not visible or _covered:
		return false
	if _pad != null and _pad.is_visible_in_tree() and _pad.get_global_rect().has_point(at):
		return true
	if _tab != null and _tab.is_visible_in_tree() and _tab.get_global_rect().has_point(at):
		return true
	return false
