extends SceneTree
## Renders `res://icon.svg` into the PNG set that `iconutil` needs for a macOS
## `.icns`, then quits.
##
## WHY this exists instead of shelling out to `sips`: `sips` cannot read SVG, and
## `icon.svg` is only 128x128. Upscaling that bitmap to the 512 and 1024 pixels
## macOS wants for Finder and the Dock produces a visibly soft icon. Godot's own
## SVG loader rasterises the vector at the requested scale, so this renders once
## at 1024 and downsamples with Lanczos -- every size stays sharp.
##
## Output: build/icon/jack.iconset/  (exactly the names `iconutil` requires)
##
## Usage:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##       --script tools/make_app_icon.gd

const SVG_PATH := "res://icon.svg"
const OUT_DIR := "res://build/icon/jack.iconset"

## (pixel size, file name). The @2x entries are the Retina variants: macOS asks
## for "128 points at 2x" which is a 256 px image, and iconutil infers the point
## size from the name, not the pixels.
const SIZES := [
	[16, "icon_16x16.png"],
	[32, "icon_16x16@2x.png"],
	[32, "icon_32x32.png"],
	[64, "icon_32x32@2x.png"],
	[128, "icon_128x128.png"],
	[256, "icon_128x128@2x.png"],
	[256, "icon_256x256.png"],
	[512, "icon_256x256@2x.png"],
	[512, "icon_512x512.png"],
	[1024, "icon_512x512@2x.png"],
]

## Rendering at 8x turns the 128 px viewBox into 1024 px of real vector detail.
const SUPERSAMPLE := 8.0


func _initialize() -> void:
	var svg := FileAccess.get_file_as_string(SVG_PATH)
	if svg.is_empty():
		printerr("ICON FAIL: cannot read ", SVG_PATH)
		quit(1)
		return

	# The largest size decides the master; rendering once and resizing down is
	# both faster and less flickery than asking the rasteriser eight times.
	# `load_svg_from_string` is an instance method that fills this Image in
	# place (there is no static-returning variant), so it cannot be chained.
	var master := Image.new()
	var err := master.load_svg_from_string(svg, SUPERSAMPLE)
	if err != OK or master.is_empty():
		printerr("ICON FAIL: the SVG could not be rasterised (error %d)" % err)
		quit(1)
		return
	print("ICON master: %dx%d" % [master.get_width(), master.get_height()])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var written := 0
	for entry in SIZES:
		var px: int = entry[0]
		var name: String = entry[1]
		var img := master.duplicate() as Image
		if px != master.get_width():
			img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		var path := "%s/%s" % [OUT_DIR, name]
		if img.save_png(path) != OK:
			printerr("ICON FAIL: cannot write ", path)
			quit(1)
			return
		print("ICON %4d px -> %s" % [px, name])
		written += 1

	print("ICON RESULT: %d / %d written" % [written, SIZES.size()])
	quit(0)
