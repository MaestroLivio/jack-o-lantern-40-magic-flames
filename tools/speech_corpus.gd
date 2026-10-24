extends RefCounted
## The complete list of sentences the game can say — one source of truth.
##
## Three tools need the same answer:
##
##   `tools/collect_speech.gd`    → writes it out, so `make_voice_pack.py` can
##                                  record the clips
##   `tools/voice_pack_check.gd`  → replays it through `AudioFx.speak()` and
##                                  reports every sentence the pack cannot say
##   `tools/speech_timeline.gd`   → (see there) times the lines a mission speaks
##
## Having the walk in two places is how the first estimate of this corpus came
## out wrong by a factor of four: a regex in one tool and a hand-written list in
## another disagreed, and neither was the game. Everything that needs "what can
## the game say" now calls `build()`.
##
## Written as `preload`-able functions rather than a `class_name`, because a
## `--script` tool is not a scene and resolves neither class names nor autoload
## identifiers as bare names; the caller passes the `GameData`/`Story` nodes in.

## Upper bound for the numeral family. The data currently stops at 28, but the
## flame counter goes to 40 and a bonus tally to 20; a pack that stopped at the
## largest number in today's data would go silent the moment a mission is added.
const NUMERAL_MAX := 40

## The grid is 10x10 with columns A..J. Coordinates are said as a letter and a
## number (`A1`, `J10`), so they are generated rather than listed.
const GRID_COLUMNS := "ABCDEFGHIJ"
const GRID_ROWS := 10

## One entry per sentence: `{"lang": "en"|"it", "text": "..."}`.
##
## Sorted by language then text, so the pack builder's output — and therefore the
## diff of two regenerations — is stable. An unsorted walk would reorder clips
## whenever a dictionary happened to be built differently, which makes a 1000-file
## diff out of a one-line data change.
static func build(data: Node, story: Node) -> Array:
	var en: Dictionary = {}
	var it: Dictionary = {}

	for m in data.call("missions"):
		_mission(m as Dictionary, data, en, it)
	for m in data.call("extra_missions"):
		_mission(m as Dictionary, data, en, it)
	for chapter in story.call("all_pages"):
		_page(chapter as Dictionary, en, it)
	for zone in data.get("ZONES"):
		_zone(zone as Dictionary, en, it)

	_numerals(en)
	_coordinates(en)
	# The last line of the game, said once in `Level.play_finale()`. It is the one
	# sentence with no dictionary behind it, so it has to be listed here or the
	# pack would fall back to the system voice for the most important sentence.
	_store(en, "Happy Halloween! You lit all forty flames. Well done, Jack!")

	var out: Array = []
	var en_keys: Array = en.keys()
	var it_keys: Array = it.keys()
	en_keys.sort()
	it_keys.sort()
	for t in en_keys:
		out.append({"lang": "en", "text": t})
	for t in it_keys:
		out.append({"lang": "it", "text": t})
	return out


## Everything one mission can pronounce: the task, its title, the words on its
## props, the quiz questions and their answer labels, the lines to repeat, the
## body parts of the hands-on mission, and the praise/correction sentences each
## mission script can produce.
##
## `data` is the `GameData` node, and it is passed in rather than reached for: two
## of the sentences below are *assembled* by `GameData` helpers
## (`spelling_sentence`, `spelling_answer`) and re-typing them here would make the
## corpus a second, silently diverging definition of what the game says.
static func _mission(m: Dictionary, data: Node, en: Dictionary, it: Dictionary) -> void:
	_store(en, m.get("prompt_en", ""))
	_store(it, m.get("prompt_it", ""))
	_store(en, m.get("title", ""))
	_store(it, m.get("title_it", ""))
	# The NPC's name is spoken by the dialogue box as the speaker line.
	_store(en, m.get("npc", ""))

	for key in ["targets", "distractors", "requirements", "obstacles", "traps", "pool", "path"]:
		for item in m.get(key, []):
			if item is Dictionary:
				_item(item as Dictionary, en, it)
	for item in m.get("items", []):
		if item is Dictionary:
			_item(item as Dictionary, en, it)
	for q in m.get("questions", []):
		if not q is Dictionary:
			continue
		_store(en, (q as Dictionary).get("en", ""))
		_store(it, (q as Dictionary).get("it", ""))
		for opt in (q as Dictionary).get("options", []):
			if opt is Dictionary:
				var label := String((opt as Dictionary).get("label", ""))
				_store(en, label)
				# `QuizManager` answers a correct tap with the label *inside* a
				# sentence, so the bare label is not enough: "Green. Well done!"
				# is a different clip from "Green".
				_store(en, "%s. Well done!" % label)
	for line in m.get("lines", []):
		if line is Dictionary:
			_store(en, (line as Dictionary).get("en", ""))
			_store(it, (line as Dictionary).get("it", ""))

	# Numbers: `FindNumbersMission` and `SequenceMission` say the digit, and
	# `CountMission` says the whole sentence with the total inside it.
	for n in m.get("numbers", []):
		_store(en, str(n))
	if not m.get("numbers", []).is_empty():
		_numbers_phrase(m.get("numbers", []), en)
	for req in m.get("requirements", []):
		if req is Dictionary:
			var c := int((req as Dictionary).get("count", 0))
			if c > 0:
				_store(en, "Exactly right! %d!" % c)

	# The scripted praise and correction sentences. They are literals in the
	# mission scripts, so the only way to be sure of them is to list them.
	var mechanic := String(m.get("mechanic", ""))
	match mechanic:
		"count":
			for line in ["Too many! I put one back.", "Too many! I put them back.",
					"We need more!", "Exactly right!"]:
				_store(en, line)
		"find":
			_store(en, "Not this one. Look for %s." % _strip_find(String(m.get("prompt_en", ""))))
			for t in m.get("targets", []):
				if t is Dictionary:
					_store(en, "Not this one. Look for %s." % String((t as Dictionary).get("word", "")))
		"repeat":
			for line in ["Listen first, then say it!", "Beautiful speaking!"]:
				_store(en, line)
		"tpr":
			for t in m.get("targets", []):
				if t is Dictionary:
					var w := String((t as Dictionary).get("word", "")).to_lower()
					_store(en, "%s. Yes!" % w)
					_store(en, "%s! Tap %s." % [w, w])
			_store(en, "Head, shoulders, knees and toes. Well done!")
		"grid":
			for p in m.get("path", []):
				_store(en, str(p))
			_store(en, "Careful! That is a trap.")
		"sequence":
			for t in m.get("targets", []):
				if t is Dictionary:
					var d := t as Dictionary
					if int(d.get("number", 0)) > 0:
						_store(en, str(d.get("number")))
						_store(en, "Find %s first!" % str(d.get("number")))
					else:
						_store(en, String(d.get("word", "")))
						_store(en, "Find %s first!" % String(d.get("word", "")))
		"spell":
			# The two sentences `SpellingPanel` assembles itself instead of reading
			# from the data: the word plus its letters ("Cat. C, A, T.") and the
			# congratulation. They go through the same `GameData` helpers the panel
			# calls, so the recorded clip cannot drift from the spoken one — a
			# hand-written copy here would be a second definition of a sentence
			# that is already defined once, which is how the corpus went wrong the
			# first time.
			var word := String(m.get("word", "")).to_lower()
			if not word.is_empty():
				# The letters are said one at a time as each is accepted
				# (`AudioFx.speak(letter)`), so every single letter needs a clip.
				# `_store` upper-cases nothing: the capital letters that make the
				# pack say "see" rather than "cuh" are produced by
				# `GameData.spelling_sentence()`, and the ones spoken on their own
				# are already capitals in `SpellingPanel`.
				for i in word.length():
					_store(en, word.substr(i, 1).to_upper())
				_store(en, String(data.call("spelling_sentence", word)))
				_store(en, String(data.call("spelling_answer", word)))
	# The panel scripts also praise and correct generically.
	for line in ["Not this one. Try again!", "Well done!", "Not this one."]:
		_store(en, line)


static func _item(d: Dictionary, en: Dictionary, it: Dictionary) -> void:
	_store(en, d.get("word", ""))
	_store(it, d.get("it", ""))


static func _page(page: Dictionary, en: Dictionary, it: Dictionary) -> void:
	_store(en, page.get("title", ""))
	_store(it, page.get("title_it", ""))
	_store(en, page.get("question", ""))
	_store(it, page.get("question_it", ""))
	_store(it, page.get("teacher_notes_it", ""))
	var spoken: Array[String] = []
	for line in page.get("lines", []):
		_store(en, line)
		spoken.append(str(line))
	for word in page.get("focus_words", []):
		_store(en, word)
	# `StoryScreen`'s READ ALL button says the whole page in one breath
	# (`Story.spoken_text`: every line, then the question, joined by spaces). That
	# is a single clip no line-by-line pack can serve, so it is generated too.
	var q := String(page.get("question", ""))
	if not q.is_empty():
		spoken.append(q)
	_store(en, " ".join(spoken))


static func _zone(z: Dictionary, en: Dictionary, it: Dictionary) -> void:
	# `ZoneIntroCard` says the name and the topic in one breath, joined by a
	# full stop, so both the halves and the joined sentence are needed.
	var name := String(z.get("name_en", ""))
	var topic := String(z.get("topic_en", ""))
	_store(en, name)
	_store(en, topic)
	_store(en, "%s. %s" % [name, topic])
	_store(it, z.get("name_it", ""))
	_store(it, z.get("topic_it", ""))


## `FindNumbersMission` builds "3, 7 and 12" and speaks the whole thing, so every
## substring of every asked set has to exist: a wrong answer mid-mission speaks
## the *remaining* numbers, which is one of these strings.
static func _numbers_phrase(numbers: Array, en: Dictionary) -> void:
	var strs: Array[String] = []
	for n in numbers:
		strs.append(str(n))
	# Every suffix ("3, 7 and 12", "7 and 12", "12") is reachable as answers are
	# found, and every prefix as they are not.
	for start in strs.size():
		for end in range(start + 1, strs.size() + 1):
			_join_phrase(strs.slice(start, end), en)


static func _join_phrase(parts: Array, en: Dictionary) -> void:
	var text := ""
	for i in parts.size():
		if i > 0:
			text += " and " if i == parts.size() - 1 else ", "
		text += str(parts[i])
	_store(en, text)


static func _numerals(en: Dictionary) -> void:
	# Only the two sentences `Level` actually says. `"Magic Flame! %d / 40"` is
	# deliberately absent: it is the text of the *toast*
	# (`QuestManager.feedback.emit`), and `Hud.show_feedback()` only writes it into
	# a Label — nothing speaks it. Recording forty clips for it cost 40 x ~2 s of
	# audio that no code path can ever play. Counting sentences the game does not
	# say is not "safe": it inflates the installer and hides a real miss among the
	# dead entries when `voice_pack_check.gd` reports a count.
	for n in range(1, NUMERAL_MAX + 1):
		_store(en, str(n))
		_store(en, "A magic flame! %d" % n)
		_store(en, "Challenge done! %d" % n)


## The bare coordinates the grid says as Jack steps on a tile.
##
## `"Go to C4."` is *not* generated: every one of those sentences is a literal in
## `GameData` (`prompt_en: "Go to C4."`), and the missions speak their prompt
## verbatim, so the data walk above already has all ten of them. Synthesising the
## other ninety was a guess about a sentence template that no code builds — a
## hundred clips for a string the game never assembles.
static func _coordinates(en: Dictionary) -> void:
	for c in GRID_COLUMNS:
		for r in range(1, GRID_ROWS + 1):
			_store(en, "%s%d" % [c, r])


## `"Find the RED, BLUE and YELLOW pumpkins!"` → `"RED, BLUE and YELLOW pumpkins!"`
##
## `FindMission` splices the task into its correction by dropping the first two
## words, so the correction only exists if the task has that shape. Anything else
## keeps the whole sentence, which is still a helpful thing to say.
static func _strip_find(prompt: String) -> String:
	var marker := "Find the "
	if prompt.begins_with(marker):
		return prompt.substr(marker.length())
	return prompt


## Stores one line, dropping empties and collapsing whitespace. Numbers arrive as
## ints from the data, so everything is stringified the same way.
static func _store(bag: Dictionary, raw: Variant) -> void:
	var text := str(raw).strip_edges()
	if text.is_empty():
		return
	# Collapse runs of spaces: the data has a few double spaces after a full
	# stop, and the same sentence spelled two ways would be two clips.
	text = text.replace("\n", " ").replace("\r", " ")
	while text.contains("  "):
		text = text.replace("  ", " ")
	bag[text] = true
