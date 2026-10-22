extends SceneTree
## Draws the DMG window background and writes it to build/dmg/background.png.
##
## WHY procedural: this project ships no imported artwork -- every mesh, icon and
## sound is generated in code. Painting the background the same way keeps that
## true, and it means the picture can never drift out of sync with the palette
## the game actually uses.
##
## The layout mirrors tools/make_dmg.sh: the app icon sits in the left half, the
## Applications shortcut in the right, so the arrow points between them.
## Window is 660x420 points; the artwork is drawn at 2x for Retina displays and
## Finder scales it down to 660x420 automatically.
##
## Usage:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##       --script tools/make_dmg_background.gd

const W := 660
const H := 420
const SS := 2                       # supersample factor for Retina
const OUT := "res://build/dmg/background.png"

# Matches UiKit's palette so the disk image looks like the game it contains.
const BG_TOP := Color("2b1b3d")
const BG_BOTTOM := Color("1a1024")
const ACCENT := Color("f28c1e")


func _initialize() -> void:
	var img := Image.create(W * SS, H * SS, false, Image.FORMAT_RGBA8)

	# Vertical gradient, drawn row by row. A plain linear blend would band on a
	# dark background; adding a tiny amount of ordered noise breaks the bands up
	# in the same way the game's debanding pass does.
	for y in img.get_height():
		var t := float(y) / float(img.get_height() - 1)
		var row := BG_TOP.lerp(BG_BOTTOM, t)
		for x in img.get_width():
			var n := float((x * 7 + y * 13) % 5) / 255.0
			img.set_pixel(x, y, Color(row.r + n, row.g + n, row.b + n, 1.0))

	# Two soft glows behind where the icons will sit, so the drop targets read as
	# destinations rather than as empty space.
	_glow(img, Vector2(170, 205) * SS, 150.0 * SS, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.13))
	_glow(img, Vector2(490, 205) * SS, 150.0 * SS, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.10))

	# The arrow between them: a thick shaft plus a triangular head, drawn by hand
	# because Image has no line primitive and pulling in a Control tree for two
	# shapes would be more machinery than the task deserves.
	var mid_y := 205 * SS
	var x0 := 280 * SS
	var x1 := 380 * SS
	var shaft := 7 * SS
	for x in range(x0, x1):
		for dy in range(-shaft, shaft + 1):
			_blend(img, x, mid_y + dy, Color(1, 1, 1, 0.55))
	var head_base := x1
	var head_len := 26 * SS
	var head_half := 22 * SS
	for i in head_len:
		var half := int(round(head_half * (1.0 - float(i) / float(head_len))))
		for dy in range(-half, half + 1):
			_blend(img, head_base + i, mid_y + dy, Color(1, 1, 1, 0.55))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/dmg"))
	if img.save_png(OUT) != OK:
		printerr("DMG BG FAIL: cannot write ", OUT)
		quit(1)
		return
	print("DMG BG: %dx%d -> %s" % [img.get_width(), img.get_height(), OUT])
	quit(0)


## Additive radial falloff. Using squared distance instead of sqrt keeps this
## cheap enough for a few hundred thousand pixels in GDScript.
func _glow(img: Image, centre: Vector2, radius: float, colour: Color) -> void:
	var r2 := radius * radius
	var x0 := maxi(0, int(centre.x - radius))
	var x1 := mini(img.get_width() - 1, int(centre.x + radius))
	var y0 := maxi(0, int(centre.y - radius))
	var y1 := mini(img.get_height() - 1, int(centre.y + radius))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) - centre.x
			var dy := float(y) - centre.y
			var d2 := dx * dx + dy * dy
			if d2 >= r2:
				continue
			var f := 1.0 - d2 / r2
			_blend(img, x, y, Color(colour.r, colour.g, colour.b, colour.a * f))


## Alpha-composites `colour` over the existing pixel. Written out rather than
## using Image.blend_rect because that needs a temporary 1x1 image per call.
func _blend(img: Image, x: int, y: int, colour: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var dst := img.get_pixel(x, y)
	var a := colour.a
	img.set_pixel(x, y, Color(
		dst.r * (1.0 - a) + colour.r * a,
		dst.g * (1.0 - a) + colour.g * a,
		dst.b * (1.0 - a) + colour.b * a,
		1.0))
