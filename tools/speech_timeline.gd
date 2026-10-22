extends SceneTree
## Timeline probe: what is the game *saying*, and when?
##
## The complaint this answers: "the first quests are piled up". Speech is the
## channel a teacher actually hears, so this runs the real startup (title -> zone
## card -> prologue -> chapter -> first task) with `AudioFx.print_speech` on.
## Every line arrives prefixed with `[speech/en]`, and `tools/stamp_speech.py`
## adds the timestamp and measures the gaps:
##
##   godot --headless --path . --script tools/speech_timeline.gd 2>&1 \
##     | python3 -u tools/stamp_speech.py
##
## `speak()` interrupts by design, so two lines closer together than the first
## one's spoken length are a collision: the child hears the first one cut off.
##
## The pages have to be dismissed by the probe, because a page never advances by
## itself (the class presses GO ON). `DWELL` is therefore a *reading time*, not a
## timeout: dismissing on the first frame the page is visible would cut every
## page's own title mid-word and make the probe report a collision it caused
## itself. A class spends around eight seconds on a page.
##
## This probe always exits 0; the pass/fail verdict is the stamping script's.

## How long the probe "reads" each page before pressing GO ON.
const DWELL := 8.0

var _main: Node

const Shutdown := preload("res://tools/probe_shutdown.gd")


func _initialize() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	var quest := root.get_node_or_null("QuestManager")
	if quest != null:
		quest.set("persist", false)
	# The export `AudioFx` already ships for teachers checking a lesson without
	# sound, so the probe adds nothing to the game's behaviour.
	var audio := root.get_node_or_null("AudioFx")
	if audio != null:
		audio.set("print_speech", true)
	_run()


func _run() -> void:
	await create_timer(0.5).timeout
	# Story included on purpose: this is the sequence a class sits through.
	_main.set("story_enabled", true)
	_main.call("begin_playing")
	# zone card -> prologue -> chapter. A page that a fix removed simply is not
	# found, and the probe moves on: `_read_page()` gives up after `open_timeout`.
	await _read_page("/root/Main/MenuLayer/ZoneIntro", 4.0)
	await _read_page("/root/Main/MenuLayer/StoryScreen", 4.0)
	await _read_page("/root/Main/MenuLayer/StoryScreen", 4.0)
	# Long enough for the first mission to build (~0.9 s of fades) and speak.
	await create_timer(6.0).timeout
	print("[timeline] end")
	await Shutdown.and_quit(self, 0)


## Waits for `path` to open, "reads" it for `DWELL`, then presses its own close
## button the way a child would.
func _read_page(path: String, open_timeout: float) -> void:
	var waited := 0.0
	while waited < open_timeout:
		var page: Node = root.get_node_or_null(path)
		if page is CanvasItem and (page as CanvasItem).visible:
			await create_timer(DWELL).timeout
			# The page may have been closed by whatever it triggered in the
			# meantime; asking first keeps the log readable in a run where a fix
			# changed the flow.
			if is_instance_valid(page) and (page as CanvasItem).visible:
				page.call("close")
			await create_timer(0.8).timeout
			return
		await create_timer(0.1).timeout
		waited += 0.1
