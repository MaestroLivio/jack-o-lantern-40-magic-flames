extends SceneTree
## Real-time probe for the *timers* that fold panels automatically.
##
## `tools/fold_check.gd` proves that folding works when asked. This one proves
## the other half of the feature: that the game really folds a panel on its own
## after the advertised wait, and that turning the setting off really stops it.
## The two are separate because a timer is the one part that a click test cannot
## cover — a probe that only ever calls `collapse_prompt()` would pass even if
## `_schedule_auto_fold()` had been deleted.
##
##   godot --path . --headless --script tools/fold_timing.gd
##
## It takes about 25 seconds because it waits out the real delays on purpose. A
## shortened copy of the timer would test the copy, not the game.

var _failures: Array[String] = []
var _checks := 0
var _main: Node
var _quest: Node
var _hud: Node


func _initialize() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_quest = root.get_node_or_null("QuestManager")
	_run()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("TIME OK   %s" % label)
	else:
		var msg := label if detail.is_empty() else "%s (%s)" % [label, detail]
		print("TIME FAIL %s" % msg)
		_failures.append(msg)


func _run() -> void:
	_main.set("story_enabled", false)
	_quest.set("persist", false)
	_quest.call("set_auto_hide_ui", true)

	_main.call("begin_playing")
	await _wait(1.0)
	_main.call("_on_intro_dismissed")
	await _wait(0.8)

	_hud = _main.get("hud")
	if _hud == null:
		print("TIME FAIL hud missing")
		quit(1)
		return

	# --- The bar folds itself after five seconds ---------------------------
	_quest.call("start_mission", 1)
	await _wait(1.0)
	_check("bar is still open one second in (it must be readable)",
		not bool(_hud.call("is_prompt_collapsed")))
	await _wait(2.0)
	_check("bar is still open three seconds in", not bool(_hud.call("is_prompt_collapsed")))
	await _wait(3.0)
	_check("bar folded itself after about five seconds",
		bool(_hud.call("is_prompt_collapsed")),
		"waited 6 s in total")

	# --- Turning the setting off stops the timer --------------------------
	_quest.call("set_auto_hide_ui", false)
	await _wait(0.4)
	_check("turning it off unfolds the bar", not bool(_hud.call("is_prompt_collapsed")))
	await _wait(6.0)
	_check("with the setting off the bar stays open past the delay",
		not bool(_hud.call("is_prompt_collapsed")))

	# --- Turning it back on re-arms the timer on the running mission ------
	_quest.call("set_auto_hide_ui", true)
	await _wait(0.5)
	_check("turning it on leaves the bar open at first",
		not bool(_hud.call("is_prompt_collapsed")))
	await _wait(5.5)
	_check("turning it on folds the bar of the running mission",
		bool(_hud.call("is_prompt_collapsed")))

	# --- A mission that ends inside the delay cannot fold the next bar ----
	# This is the `_prompt_token` guard. `start_mission` is deliberately called
	# faster than the five-second delay, in the same way the smoke test walks
	# forty missions back to back.
	#
	# Only `find` missions are used: a `repeat` or `quiz` mission takes the task
	# bar away on purpose (`set_prompt_visible(false)`), so folding it is not
	# something the probe could observe — and expecting the bar to fold over a
	# quiz is expecting the bug this feature must never introduce.
	for id in [1, 2, 3, 8]:
		_quest.call("start_mission", id)
		await _wait(1.0)
		if id != 8:
			_check("mission %d bar still open 1 s in" % id,
				not bool(_hud.call("is_prompt_collapsed")))
	await _wait(4.5)
	_check("after a burst of missions the last bar folds once, on time",
		bool(_hud.call("is_prompt_collapsed")))

	_finish()


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("TIMING RESULT: %d checks, 0 failures" % _checks)
	else:
		print("TIMING RESULT: %d checks, %d failures" % [_checks, _failures.size()])
		for f in _failures:
			print("  - ", f)
	quit(0 if _failures.is_empty() else 1)
