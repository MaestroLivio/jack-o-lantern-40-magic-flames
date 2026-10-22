extends RefCounted
## The one correct way for a `--script` probe to end the process.
##
## Every probe used to call `tree.quit()` from wherever it finished, and that is
## why their logs end with "N ObjectDB instances were leaked" and "resources still
## in use at exit" even when every check passed. The cause is not a bug in the
## game: it is that `stop()` only *asks* the audio server to release a playback,
## and the server does so on its next mix pass. `quit()` in the same frame skips
## that pass, so the playback, its stream and its `OggPacketSequence` are still
## alive when Godot tears the tree down and it reports them.
##
## `Main._quit_cleanly()` documents the same thing for the real game and waits
## 0.2 s for the same reason. This is that wait, in one place, so a probe cannot
## forget it and so a genuine leak -- a node never freed, a stream kept alive by a
## cache -- is still visible instead of being lost among the expected noise.
##
## Usage, at the end of a probe:
##
##     const Shutdown := preload("res://tools/probe_shutdown.gd")
##     await Shutdown.and_quit(self, 0)

## Stops every audio producer, releases the voice cache, waits two mix passes,
## then quits with `code`.
##
## `tree` is the `SceneTree` the probe extends. `await`ed rather than fire-and-
## forget: the probe's `_initialize()`/body must not return before `quit()` is
## called, or the engine would keep running with nothing left to do.
static func and_quit(tree: SceneTree, code: int = 0) -> void:
	var audio: Node = tree.root.get_node_or_null("AudioFx")
	var music: Node = tree.root.get_node_or_null("Music")
	if music != null:
		music.call("stop_now")
	if audio != null:
		audio.call("stop_sfx")
		# Drops the 880-entry clip cache and the speech player's stream. Without
		# this a probe that spoke anything leaves the whole corpus reachable.
		audio.call("release_cache")
	await tree.create_timer(0.2).timeout
	tree.quit(code)
