extends SceneTree
## Checks that `AudioFx.deshout()` — and therefore `normalize_speech()` — turns
## every spelled-out keyword back into a spoken word, and that it leaves every
## other line byte-identical.
##
## This exists because the failure it guards is silent: a sentence that stops
## matching its recorded clip does not error, it just gets read by whatever voice
## the machine happens to have, or by nothing at all. The casing rule itself was
## derived from espeak-ng's phonemes (see `AudioFx.normalize_speech()`), so the
## cases below are the ones that measurement identified, not guesses.
##
##     godot --headless --path . --script tools/casing_check.gd

const Shutdown := preload("res://tools/probe_shutdown.gd")

## `[input, expected output]`. The first block is the bug; the second is the
## regression guard — lines whose all-caps words are long enough that espeak
## reads them as words, and which must therefore come back untouched.
const CASES := [
	["Find the RED, BLUE and YELLOW pumpkins!", "Find the Red, BLUE and YELLOW pumpkins!"],
	["Find the BIG BLACK SPIDER.", "Find the Big BLACK SPIDER."],
	["Find the SMALL WHITE CAT.", "Find the SMALL WHITE Cat."],
	["Select the RED TRIANGLE nose.", "Select the Red TRIANGLE nose."],
	["Catch the FAST cat. The slow cat is sleeping!", "Catch the FAST cat. The slow cat is sleeping!"],
	["Trova le zucche ROSSA, BLU e GIALLA!", "Trova le zucche ROSSA, Blu e GIALLA!"],
	["Pesta le foglie in ordine: ROSSA, VERDE, BLU.", "Pesta le foglie in ordine: ROSSA, VERDE, Blu."],
	# Already correct before the fix: four or more letters is a word to espeak.
	["Find the GREEN, PURPLE and ORANGE pumpkins!", "Find the GREEN, PURPLE and ORANGE pumpkins!"],
	["Find the HAPPY pumpkin. Ignore the sad pumpkin!", "Find the HAPPY pumpkin. Ignore the sad pumpkin!"],
	["Tap Jack's body parts in order: HEAD, SHOULDERS, KNEES, TOES!",
		"Tap Jack's body parts in order: HEAD, SHOULDERS, KNEES, TOES!"],
	["Give the skeleton exactly FIVE orange candies.", "Give the skeleton exactly FIVE orange candies."],
	# Things the rule must not damage: an article, a pronoun, a grid coordinate
	# (a letter glued to a digit has no word boundary after it), a possessive.
	["A magic flame!", "A magic flame!"],
	["I am Jack", "I am Jack"],
	["Go to A1.", "Go to A1."],
	["Go to J10.", "Go to J10."],
	["Jack's lantern", "Jack's lantern"],
	# Two-letter words that espeak already read correctly still change case here,
	# because the rule is positional and not a word list. The phonemes are
	# identical for both spellings, which is what makes that acceptable.
	["IN", "In"],
	["ON. Well done!", "On. Well done!"],
]


func _initialize() -> void:
	var audio := root.get_node_or_null("AudioFx")
	if audio == null:
		print("[casing] FAIL: AudioFx autoload not found")
		await Shutdown.and_quit(self, 1)
		return

	var failures := 0
	for row in CASES:
		var source: String = row[0]
		var want: String = row[1]
		var got := String(audio.call("normalize_speech", source))
		if got != want:
			failures += 1
			print("[casing] FAIL  %s" % source)
			print("            want %s" % want)
			print("            got  %s" % got)
		else:
			print("[casing] ok    %s" % got)

	print("[casing] %d check(s), %d failure(s)" % [CASES.size(), failures])
	await Shutdown.and_quit(self, 1 if failures > 0 else 0)
