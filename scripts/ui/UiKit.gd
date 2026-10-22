class_name UiKit
extends RefCounted
## Small UI toolkit: theme + helper builders used by every panel.
##
## Design rules for 7-year-olds (from the GDD): very large type, thick
## rounded buttons, high-contrast colours, one idea per screen, and an icon
## next to every word. Everything is built in code so the look stays
## consistent and the project needs no art imports.

const COL_BG := Color("1b1330")
const COL_PANEL := Color("2a1b45")
const COL_TEXT := Color("fff6e2")
const COL_TEXT_DIM := Color("cbb9e6")
const COL_ACCENT := Color("ffc94d")
const COL_ORANGE := Color("f28c1e")
const COL_GREEN := Color("4fb84f")
const COL_BLUE := Color("4fa3d9")
const COL_PINK := Color("f28cc0")
const COL_SOFT_RED := Color("e2704f")

const FONT_KID := ["Comic Sans MS", "Chalkboard SE", "Trebuchet MS", "Verdana", "Arial"]
const FONT_DYSLEXIC := ["OpenDyslexic", "Open Dyslexic", "Atkinson Hyperlegible", "Verdana", "Arial"]

static var _theme: Theme
static var _font_normal: SystemFont
static var _font_dyslexic: SystemFont
static var _icon_cache: Dictionary = {}


# --- Fonts & theme ---------------------------------------------------------

static func normal_font() -> SystemFont:
	if _font_normal == null:
		_font_normal = SystemFont.new()
		_font_normal.font_names = FONT_KID
		_font_normal.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font_normal


static func dyslexic_font() -> SystemFont:
	if _font_dyslexic == null:
		_font_dyslexic = SystemFont.new()
		_font_dyslexic.font_names = FONT_DYSLEXIC
		_font_dyslexic.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font_dyslexic


## The shared theme. `easy_read` swaps in the OpenDyslexic font stack and
## widens spacing; call `refresh_theme()` after changing the setting.
static func build_theme(easy_read: bool = false) -> Theme:
	var t := Theme.new()
	t.default_font = dyslexic_font() if easy_read else normal_font()
	t.default_font_size = 34 if easy_read else 32

	# --- Button ---
	var btn_normal := _panel_style(COL_PANEL.lightened(0.06), COL_ACCENT, 6, 24)
	var btn_hover := _panel_style(COL_PANEL.lightened(0.16), COL_ACCENT.lightened(0.2), 8, 24)
	var btn_pressed := _panel_style(COL_PANEL.darkened(0.08), COL_ACCENT, 6, 24)
	var btn_disabled := _panel_style(COL_PANEL.darkened(0.25), COL_TEXT_DIM.darkened(0.4), 4, 24)
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBoxFlat
		match style_name:
			"hover", "focus": style = btn_hover
			"pressed": style = btn_pressed
			"disabled": style = btn_disabled
			_: style = btn_normal
		t.set_stylebox(style_name, "Button", style)
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", COL_ACCENT)
	t.set_color("font_disabled_color", "Button", COL_TEXT_DIM.darkened(0.3))
	t.set_font_size("font_size", "Button", 30 if easy_read else 29)
	t.set_constant("outline_size", "Button", 0)
	t.set_constant("separation", "Button", 14)

	# --- Label ---
	t.set_color("font_color", "Label", COL_TEXT)
	t.set_color("font_outline_color", "Label", Color(0.04, 0.02, 0.07, 0.9))
	t.set_constant("outline_size", "Label", 6 if easy_read else 4)
	t.set_font_size("font_size", "Label", 32)

	return t


static func refresh_theme() -> void:
	_theme = build_theme(easy_read_enabled())


static func theme() -> Theme:
	if _theme == null:
		refresh_theme()
	return _theme


## Reads the accessibility setting without hard-referencing the autoload.
##
## `UiKit` is used by `--script` developer tools too, and in that mode the
## autoload names are not registered as identifiers, so a bare `QuestManager`
## would make the whole toolkit fail to compile. Looking the node up through
## the scene tree keeps the toolkit usable everywhere.
static func _quest_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("QuestManager")


static func easy_read_enabled() -> bool:
	var q := _quest_manager()
	return q != null and bool(q.get("easy_read"))


static func sound_enabled() -> bool:
	var q := _quest_manager()
	return q == null or bool(q.get("sound_on"))


static func _panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.anti_aliasing = true
	return s


static func panel_style(fill: Color = COL_PANEL, border: Color = COL_ACCENT, border_width: int = 5, radius: int = 32) -> StyleBoxFlat:
	return _panel_style(fill, border, border_width, radius)


# --- Widgets ---------------------------------------------------------------

## Builds a themed Label.
##
## `wrap` enables word wrapping, which is what every *sentence* wants. Pass
## `false` for short strings that live inside an HBoxContainer (counters such
## as "3 / 5", the flame total, a one-word chip).
##
## `min_width` is the important one for wrapped text. A wrapping Label reports
## a minimum width of just **1 px**, so a container happily squeezes it into a
## one-pixel column, wraps after every single letter and grows a tower hundreds
## of pixels tall — which then inflates the minimum size of the whole panel and
## pushes the real content off screen. Giving wrapped labels the width they will
## actually be laid out at (the panel's inner width) removes the trap: set it to
## slightly less than the container's content width.
static func label(text: String, size: int = 32, color: Color = COL_TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = true, min_width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06, 0.85))
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap and min_width > 0.0:
		l.custom_minimum_size = Vector2(min_width, l.custom_minimum_size.y)
	return l


static func button(text: String, icon: Texture2D = null, min_size: Vector2 = Vector2(240, 104)) -> Button:
	var b := Button.new()
	b.text = text
	b.theme = theme()
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	if icon != null:
		b.icon = icon
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 64)
	b.add_theme_font_size_override("font_size", 32 if easy_read_enabled() else 30)
	return b


static func panel(fill: Color = COL_PANEL, border: Color = COL_ACCENT, border_width: int = 5, radius: int = 32) -> PanelContainer:
	var p := PanelContainer.new()
	var s := panel_style(fill, border, border_width, radius)
	p.add_theme_stylebox_override("panel", s)
	return p


static func margin(m: int) -> MarginContainer:
	var c := MarginContainer.new()
	c.add_theme_constant_override("margin_left", m)
	c.add_theme_constant_override("margin_right", m)
	c.add_theme_constant_override("margin_top", m)
	c.add_theme_constant_override("margin_bottom", m)
	return c


static func vbox(separation: int = 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	return h


## Full-rect control used as the background of a modal layer.
static func scrim(alpha: float = 0.62) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.05, 0.02, 0.09, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


## Gives keyboard/gamepad focus to the first button that a child can actually
## press, walking the tree in order.
##
## Every modal panel needs this. With a controller (or with Tab) there is no
## pointer to aim at, so a page that nobody has focused cannot be used at all:
## the D-pad moves nothing and A does nothing. Calling it right after a panel
## becomes visible is what makes "playable entirely with a gamepad" true rather
## than aspirational.
##
## Buttons that are disabled (the first page of the story has none, the
## difficulty arrows at the end of their range do) are skipped, so focus never
## lands on something the child cannot activate.
static func focus_first_button(root: Node) -> void:
	var target := _first_pressable(root)
	if target != null:
		target.grab_focus()


static func _first_pressable(node: Node) -> Control:
	for child in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is Button:
			var button := child as Button
			if button.disabled or button.focus_mode == Control.FOCUS_NONE:
				continue
			return button
		# Depth first, so the first *visible* row wins over a later one.
		var found := _first_pressable(child)
		if found != null:
			return found
	return null


# --- Procedural icons ------------------------------------------------------

## Vector-ish icon drawn into an ImageTexture. Used on quiz cards so every
## option has a picture, never text alone.
##
## `face` only reaches the pumpkin, and it exists because the game *teaches the
## word* "happy" with it: the final-party quiz asks "Which one is HAPPY?" and
## mission 20 asks the child to pick the happy pumpkin out of sad ones. A single
## hard-coded smile made that question unanswerable — every card showed the same
## face, so the only way through was to guess. The parameter is defaulted to
## "happy" so the dozen call sites that just want a pumpkin (title screen, HUD
## flame row, ending screen) keep working untouched.
static func icon_texture(icon_name: String, color_key: String = "orange", px: int = 160, number: int = 0, face: String = "happy") -> Texture2D:
	# `face` is part of the cache key, or the first pumpkin ever drawn would be
	# handed back for both the smile and the frown — the exact bug this parameter
	# fixes, reintroduced by the cache.
	var cache_key := "%s|%s|%d|%d|%s" % [icon_name, color_key, px, number, face]
	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key]

	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := PropFactory.color_of(color_key)
	var ink := Color(0.09, 0.05, 0.14)
	var s := float(px)
	var center := Vector2(s * 0.5, s * 0.5)

	match icon_name:
		"circle":
			_fill_circle(img, center, s * 0.34, c)
			_ring_outline(img, s * 0.34, ink)
		"square":
			_fill_rect(img, Rect2(s * 0.18, s * 0.18, s * 0.64, s * 0.64), c)
			_rect_outline(img, Rect2(s * 0.18, s * 0.18, s * 0.64, s * 0.64), ink)
		"triangle":
			_fill_triangle(img, Vector2(s * 0.5, s * 0.14), Vector2(s * 0.9, s * 0.84), Vector2(s * 0.1, s * 0.84), c)
		"star":
			_fill_star(img, center, s * 0.38, s * 0.17, c)
		"number":
			_draw_number(img, number, c if color_key != "orange" else COL_ACCENT, ink)
		"pumpkin":
			_fill_circle(img, Vector2(s * 0.5, s * 0.58), s * 0.34, c)
			_fill_rect(img, Rect2(s * 0.46, s * 0.14, s * 0.09, s * 0.16), Color("4f7a28"))
			_fill_rect(img, Rect2(s * 0.34, s * 0.5, s * 0.09, s * 0.11), ink)
			_fill_rect(img, Rect2(s * 0.58, s * 0.5, s * 0.09, s * 0.11), ink)
			# The mouth is an arc, not a bar. A straight bar was what made
			# "Which one is HAPPY?" unanswerable: all three cards carried the
			# identical mark, so the only visible difference was the body colour
			# and the child learned to answer by colour instead of by expression.
			_draw_mood_mouth(img, Vector2(s * 0.5, s * 0.72), s * 0.13, s * 0.075, ink, face == "sad")
			if face == "sad":
				# A second, redundant signal: brows angled *down toward the
				# nose* read as a scowl even at projector distance, where the
				# mouth curve alone can wash out.
				_draw_brow(img, Vector2(s * 0.34, s * 0.45), s * 0.11, ink, 1)
				_draw_brow(img, Vector2(s * 0.58, s * 0.45), s * 0.11, ink, -1)
		"bat":
			_fill_circle(img, center, s * 0.15, c)
			_fill_triangle(img, Vector2(s * 0.5, s * 0.44), Vector2(s * 0.08, s * 0.3), Vector2(s * 0.16, s * 0.62), c)
			_fill_triangle(img, Vector2(s * 0.5, s * 0.44), Vector2(s * 0.92, s * 0.3), Vector2(s * 0.84, s * 0.62), c)
			_fill_rect(img, Rect2(s * 0.43, s * 0.34, s * 0.06, s * 0.08), ink)
			_fill_rect(img, Rect2(s * 0.55, s * 0.34, s * 0.06, s * 0.08), ink)
		"ghost":
			_fill_circle(img, Vector2(s * 0.5, s * 0.46), s * 0.28, c)
			_fill_rect(img, Rect2(s * 0.22, s * 0.46, s * 0.56, s * 0.34), c)
			_fill_rect(img, Rect2(s * 0.4, s * 0.44, s * 0.07, s * 0.1), ink)
			_fill_rect(img, Rect2(s * 0.55, s * 0.44, s * 0.07, s * 0.1), ink)
		"cat":
			_fill_circle(img, Vector2(s * 0.5, s * 0.6), s * 0.26, c)
			_fill_triangle(img, Vector2(s * 0.3, s * 0.46), Vector2(s * 0.22, s * 0.2), Vector2(s * 0.42, s * 0.36), c)
			_fill_triangle(img, Vector2(s * 0.7, s * 0.46), Vector2(s * 0.78, s * 0.2), Vector2(s * 0.58, s * 0.36), c)
			_fill_rect(img, Rect2(s * 0.4, s * 0.56, s * 0.06, s * 0.08), ink)
			_fill_rect(img, Rect2(s * 0.55, s * 0.56, s * 0.06, s * 0.08), ink)
		"frog":
			# Wide body with two eyes on top. Without its own branch this icon
			# fell through to the generic circle and "small" looked identical to
			# "big" on the same quiz card — a picture that teaches the wrong
			# thing is worse than no picture at all.
			_fill_circle(img, Vector2(s * 0.5, s * 0.62), s * 0.31, c)
			_fill_circle(img, Vector2(s * 0.31, s * 0.32), s * 0.14, c)
			_fill_circle(img, Vector2(s * 0.69, s * 0.32), s * 0.14, c)
			_fill_rect(img, Rect2(s * 0.42, s * 0.55, s * 0.07, s * 0.09), ink)
			_fill_rect(img, Rect2(s * 0.55, s * 0.55, s * 0.07, s * 0.09), ink)
			_fill_rect(img, Rect2(s * 0.36, s * 0.75, s * 0.28, s * 0.05), ink)
		"bucket":
			_fill_rect(img, Rect2(s * 0.26, s * 0.34, s * 0.48, s * 0.46), c)
			_fill_rect(img, Rect2(s * 0.3, s * 0.2, s * 0.4, s * 0.08), ink)
			_fill_rect(img, Rect2(s * 0.24, s * 0.78, s * 0.52, s * 0.06), c.darkened(0.3))
		"barrel":
			# Its own branch because the quiz asks "Which one is a SHAPE?" with
			# a barrel as a distractor: drawn as a pumpkin it looked like yet
			# another round shape, which made the *wrong* answer look right.
			# Two metal hoops and a flat top are what makes a barrel read as a
			# barrel at card size, not the wood colour.
			_fill_rect(img, Rect2(s * 0.28, s * 0.2, s * 0.44, s * 0.62), c)
			_fill_rect(img, Rect2(s * 0.26, s * 0.3, s * 0.48, s * 0.06), c.darkened(0.45))
			_fill_rect(img, Rect2(s * 0.26, s * 0.66, s * 0.48, s * 0.06), c.darkened(0.45))
			_fill_rect(img, Rect2(s * 0.3, s * 0.18, s * 0.4, s * 0.04), c.lightened(0.25))
		"hat":
			_fill_rect(img, Rect2(s * 0.16, s * 0.68, s * 0.68, s * 0.1), c)
			_fill_triangle(img, Vector2(s * 0.5, s * 0.16), Vector2(s * 0.74, s * 0.68), Vector2(s * 0.26, s * 0.68), c.darkened(0.12))
		"broom":
			_fill_rect(img, Rect2(s * 0.46, s * 0.12, s * 0.08, s * 0.5), Color("6b4324"))
			_fill_triangle(img, Vector2(s * 0.5, s * 0.56), Vector2(s * 0.8, s * 0.88), Vector2(s * 0.2, s * 0.88), c)
		"arm":
			_fill_rect(img, Rect2(s * 0.42, s * 0.18, s * 0.16, s * 0.6), c)
			_fill_circle(img, Vector2(s * 0.5, s * 0.82), s * 0.12, c.lightened(0.2))
		"foot":
			_fill_rect(img, Rect2(s * 0.28, s * 0.56, s * 0.44, s * 0.22), c)
			_fill_rect(img, Rect2(s * 0.4, s * 0.24, s * 0.2, s * 0.36), c.darkened(0.12))
		"flame":
			_fill_triangle(img, Vector2(s * 0.5, s * 0.1), Vector2(s * 0.78, s * 0.72), Vector2(s * 0.22, s * 0.72), c)
			_fill_circle(img, Vector2(s * 0.5, s * 0.66), s * 0.16, Color("fff3c4"))
		"speaker":
			_fill_rect(img, Rect2(s * 0.16, s * 0.38, s * 0.16, s * 0.24), c)
			_fill_triangle(img, Vector2(s * 0.62, s * 0.16), Vector2(s * 0.62, s * 0.84), Vector2(s * 0.3, s * 0.5), c)
			for i in 3:
				var r := s * (0.2 + i * 0.11)
				_arc(img, Vector2(s * 0.62, s * 0.5), r, -0.6, 0.6, c)
		"mic":
			_fill_circle(img, Vector2(s * 0.5, s * 0.38), s * 0.14, c)
			_fill_rect(img, Rect2(s * 0.36, s * 0.34, s * 0.28, s * 0.3), c)
			_arc(img, Vector2(s * 0.5, s * 0.52), s * 0.26, 0.15, PI - 0.15, c)
			_fill_rect(img, Rect2(s * 0.47, s * 0.74, s * 0.06, s * 0.14), c)
		"magnifier":
			_ring_outline(img, s * 0.26, c)
			_fill_rect(img, Rect2(s * 0.62, s * 0.62, s * 0.22, s * 0.08), c)
		_:
			_fill_circle(img, center, s * 0.3, c)

	var tex := ImageTexture.create_from_image(img)
	_icon_cache[cache_key] = tex
	return tex


# --- Raster drawing helpers (no external deps) -----------------------------

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _fill_rect(img: Image, r: Rect2, c: Color) -> void:
	var x0 := maxi(int(r.position.x), 0)
	var y0 := maxi(int(r.position.y), 0)
	var x1 := mini(int(r.position.x + r.size.x), img.get_width())
	var y1 := mini(int(r.position.y + r.size.y), img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			img.set_pixel(x, y, c)


static func _rect_outline(img: Image, r: Rect2, c: Color) -> void:
	_fill_rect(img, Rect2(r.position.x, r.position.y, r.size.x, 3), c)
	_fill_rect(img, Rect2(r.position.x, r.position.y + r.size.y - 3, r.size.x, 3), c)
	_fill_rect(img, Rect2(r.position.x, r.position.y, 3, r.size.y), c)
	_fill_rect(img, Rect2(r.position.x + r.size.x - 3, r.position.y, 3, r.size.y), c)


static func _fill_circle(img: Image, center: Vector2, radius: float, c: Color) -> void:
	var r2 := radius * radius
	var x0 := maxi(int(center.x - radius), 0)
	var x1 := mini(int(center.x + radius), img.get_width())
	var y0 := maxi(int(center.y - radius), 0)
	var y1 := mini(int(center.y + radius), img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dx := x - center.x + 0.5
			var dy := y - center.y + 0.5
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, c)


static func _ring_outline(img: Image, radius: float, c: Color) -> void:
	var center := Vector2(img.get_width() * 0.5, img.get_height() * 0.5)
	var steps := 160
	for i in steps:
		var a := TAU * float(i) / float(steps)
		var p := center + Vector2(cos(a), sin(a)) * radius
		_px(img, int(p.x), int(p.y), c)


## A pumpkin mouth that is unmistakably a smile or a frown.
##
## Drawn as a row of overlapping beads along a parabola rather than as a filled
## shape, for two reasons: an image drawn bead by bead cannot produce a jagged
## edge at any icon size (the bead overlap rounds the join), and the same loop
## gives both moods by flipping one sign, which is what keeps the two faces from
## drifting apart the way a hand-drawn second shape would.
##
## `Image` has y growing *downward*, so a smile (corners lifted, middle dropped)
## is the positive curvature and a frown is the negative one.
static func _draw_mood_mouth(img: Image, center: Vector2, half_width: float,
		depth: float, c: Color, sad: bool) -> void:
	var beads := 11
	var bead_r := maxf(half_width * 0.18, 1.6)
	for i in beads:
		var t := float(i) / float(beads - 1)            # 0 .. 1 across the mouth
		var x := center.x + lerpf(-half_width, half_width, t)
		# 4*(t-0.5)^2 is 0 in the middle and 1 at both corners: the same curve
		# read as "corners up" (smile) or "corners down" (frown) by its sign.
		var bend := 4.0 * pow(t - 0.5, 2.0)
		var y := center.y + (depth * bend if not sad else -depth * bend)
		_fill_circle(img, Vector2(x, y), bead_r, c)


## One slanted eyebrow. `direction` is +1 for the left brow and -1 for the right,
## so both point their inner end down towards the nose: that shared direction is
## what makes the pair read as a scowl instead of as two random marks.
static func _draw_brow(img: Image, origin: Vector2, length: float, c: Color,
		direction: int) -> void:
	var steps := 12
	var rise := length * 0.55
	for i in steps:
		var t := float(i) / float(steps - 1)
		var x := origin.x + lerpf(0.0, length, t) * float(direction)
		var y := origin.y + lerpf(0.0, rise, t)
		_fill_circle(img, Vector2(x, y), maxf(length * 0.11, 1.4), c)


## Draws an open arc (used by the speaker and microphone icons).
static func _arc(img: Image, center: Vector2, radius: float, from_angle: float, to_angle: float, c: Color, thickness: int = 3) -> void:
	var steps := 60
	for i in steps + 1:
		var a := lerpf(from_angle, to_angle, float(i) / float(steps))
		var p := center + Vector2(cos(a), sin(a)) * radius
		_fill_rect(img, Rect2(p.x - thickness * 0.5, p.y - thickness * 0.5, thickness, thickness), c)


static func _fill_triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var min_x := maxi(int(minf(a.x, minf(b.x, c.x))), 0)
	var max_x := mini(int(maxf(a.x, maxf(b.x, c.x))) + 1, img.get_width())
	var min_y := maxi(int(minf(a.y, minf(b.y, c.y))), 0)
	var max_y := mini(int(maxf(a.y, maxf(b.y, c.y))) + 1, img.get_height())
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			if _point_in_triangle(Vector2(x + 0.5, y + 0.5), a, b, c):
				img.set_pixel(x, y, col)


static func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _sign(p, a, b)
	var d2 := _sign(p, b, c)
	var d3 := _sign(p, c, a)
	var has_neg := (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos := (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)


static func _sign(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)


static func _fill_star(img: Image, center: Vector2, outer: float, inner: float, c: Color) -> void:
	var points: Array[Vector2] = []
	for i in 10:
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI / 2.0 + TAU * float(i) / 10.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	for i in 10:
		var a := points[i]
		var b := points[(i + 1) % 10]
		_fill_triangle(img, center, a, b, c)


static func _draw_number(img: Image, number: int, c: Color, ink: Color) -> void:
	# Digits are drawn with a tiny 5x7 bitmap font so quiz cards can show
	# numbers without loading a font into an Image.
	var glyph := _digit_glyph(str(number))
	var rows := glyph.size()
	var total_w := 0
	for i in rows:
		total_w = maxi(total_w, (glyph[i] as String).length())
	var scale := float(img.get_width()) / 12.0
	var w := total_w * scale
	var h := rows * scale
	var ox := (img.get_width() - w) * 0.5
	var oy := (img.get_height() - h) * 0.5
	# A soft disc behind the number keeps it readable on any background.
	_fill_circle(img, Vector2(img.get_width() * 0.5, img.get_height() * 0.5), minf(w, h) * 0.78, Color(c.r, c.g, c.b, 0.22))
	for r in rows:
		var line: String = glyph[r]
		for col_i in line.length():
			if line[col_i] == "#":
				_fill_rect(img, Rect2(ox + col_i * scale, oy + r * scale, scale + 1, scale + 1), c)


static func _digit_glyph(text: String) -> Array:
	var font := {
		"0": [" ### ", "#   #", "#  ##", "# # #", "##  #", "#   #", " ### "],
		"1": ["  #  ", " ##  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
		"2": [" ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####"],
		"3": ["#### ", "    #", "    #", " ### ", "    #", "    #", "#### "],
		"4": ["   # ", "  ## ", " # # ", "#  # ", "#####", "   # ", "   # "],
		"5": ["#####", "#    ", "#### ", "    #", "    #", "#   #", " ### "],
		"6": [" ### ", "#    ", "#    ", "#### ", "#   #", "#   #", " ### "],
		"7": ["#####", "    #", "   # ", "  #  ", " #   ", " #   ", " #   "],
		"8": [" ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### "],
		"9": [" ### ", "#   #", "#   #", " ####", "    #", "    #", " ### "],
	}
	var out: Array[String] = []
	var widths := 0
	var glyphs: Array = []
	for ch in text:
		var g: Array = font.get(ch, font["0"])
		glyphs.append(g)
		widths += (g[0] as String).length() + 1
	for row in 7:
		var line := ""
		for g in glyphs:
			line += String(g[row]) + " "
		out.append(line)
	return out


## A rounded "card" showing an icon plus a word: the core learning unit of
## the game's UI (word + picture, never text alone).
static func word_card(word: String, color_key: String, icon_name: String, number: int = 0) -> Control:
	var panel := panel(COL_PANEL.lightened(0.04), COL_ACCENT, 4, 24)
	var v := vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon_texture(icon_name, color_key, 160, number)
	icon_rect.custom_minimum_size = Vector2(150, 150)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon_rect)
	var l := label(word, 30, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(170, 0)
	v.add_child(l)
	var m := margin(10)
	m.add_child(v)
	panel.add_child(m)
	return panel
