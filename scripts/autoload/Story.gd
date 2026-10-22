extends Node
## The story that holds the 40 missions together.
##
## A 7-year-old playing an English game needs two different things from the
## text: a *task* ("find the red pumpkin") and a *reason*. The tasks already
## live in `GameData.missions()`. This file holds the reason — a short piece of
## narration, in English, that sits between one mission and the next.
##
## Each chapter is deliberately small and readable aloud:
##
##     var page := Story.chapter_for(1)
##     story_screen.open(page)
##
## `teacher_notes_it` is the only Italian on the page and it is never shown
## automatically: it exists for the adult in the room, behind the magnifier.
## `focus_words` are the two or three words worth pausing on, each with the
## picture that belongs to it, so the class can point at the thing while the
## word is said.
##
## Writing rules kept throughout (they matter for pre-A1 readers):
##   * one idea per sentence, present tense, at most ~12 words;
##   * the vocabulary of the mission being introduced appears in the chapter;
##   * no idiom, no metaphor that needs explaining, no past perfect;
##   * every chapter ends on a small question or a small action, never on a
##     cliffhanger that would worry a child.

## One entry per *zone-opening* chapter, plus one intro and one finale.
## Keyed by zone id; `mission` is the mission the chapter introduces.
const CHAPTERS: Array[Dictionary] = [
	{
		"key": "prologue",
		"zone": 1,
		"mission": 0,
		"title": "The Lantern With No Light",
		"lines": [
			"Jack is a little pumpkin with a big empty lantern.",
			"Tonight is Halloween, and every pumpkin must shine.",
			"But Jack's lantern has no fire inside it at all.",
			"An old owl lands on the fence. \"Forty flames are lost,\" she says.",
			"\"Find them before the party starts, and your lantern will shine.\"",
		],
		"question": "Can you help Jack find the first flame?",
		"focus_words": [
			{"word": "lantern", "icon": "flame", "color": "gold"},
			{"word": "pumpkin", "icon": "pumpkin", "color": "orange"},
			{"word": "forty", "icon": "number", "color": "gold", "number": 40},
		],
		"teacher_notes_it": "Prologo. Presenta Jack, la lanterna vuota e il compito: trovare 40 fiamme. Lessico: pumpkin, lantern, flame, forty. Chiedete: «What does a lantern need?» → «Fire!»",
	},
	{
		"key": "zone1",
		"zone": 1,
		"mission": 1,
		"title": "The Whispering Pumpkin Patch",
		"lines": [
			"The pumpkin patch is full of whispering leaves.",
			"Mr. Barnaby the scarecrow is very, very old.",
			"He has lost the colours of his pumpkins.",
			"\"Everything looks the same to me,\" he says sadly.",
			"\"Tell me which one is red. Which one is blue.\"",
		],
		"question": "Which pumpkin is red?",
		"focus_words": [
			{"word": "red", "icon": "pumpkin", "color": "red"},
			{"word": "blue", "icon": "pumpkin", "color": "blue"},
			{"word": "yellow", "icon": "pumpkin", "color": "yellow"},
		],
		"teacher_notes_it": "Zona 1. Colori primari. Il personaggio è non vedente: è un buon motivo narrativo per *nominare* i colori invece di indicarli. Chiedete: «Is this pumpkin red or blue?»",
	},
	{
		"key": "zone2",
		"zone": 2,
		"mission": 9,
		"title": "Dracula's Cozy Castle",
		"lines": [
			"Baby Dracula is not scary. He is small, and he is sleepy.",
			"His castle has ten stairs, twenty candles and one big bath.",
			"The clumsy skeletons are counting everything, very loudly.",
			"\"One, two, three... no! Start again!\"",
			"Dracula needs a helper who can count without losing the way.",
		],
		"question": "Can you count the candles with Dracula?",
		"focus_words": [
			{"word": "one", "icon": "number", "color": "gold", "number": 1},
			{"word": "ten", "icon": "number", "color": "gold", "number": 10},
			{"word": "twenty", "icon": "number", "color": "gold", "number": 20},
		],
		"teacher_notes_it": "Zona 2. Numeri 1-20. Il conteggio nasce da un problema concreto (gli scheletri sbagliano). Chiedete: «How many stairs? How many candles?»",
	},
	{
		"key": "zone3",
		"zone": 3,
		"mission": 17,
		"title": "The Wacky Witch's Bog",
		"lines": [
			"Wendy the witch has a very messy bog.",
			"Her frog is green and slow. Her cat is black and fast.",
			"Her broom is too long, and her hat is too small.",
			"\"My spells mix up big and small,\" Wendy says.",
			"\"Tell me what you see, and I will fix everything.\"",
		],
		"question": "Is the frog big or small?",
		"focus_words": [
			{"word": "big", "icon": "cat", "color": "orange"},
			{"word": "small", "icon": "frog", "color": "green"},
			{"word": "fast", "icon": "cat", "color": "black"},
		],
		"teacher_notes_it": "Zona 3. Aggettivi e animali. Gli opposti sono il cuore della zona: big/small, fast/slow, long/short. Chiedete di indicare gli oggetti mentre dite la parola.",
	},
	{
		"key": "zone4",
		"zone": 4,
		"mission": 25,
		"title": "Franky's Laboratory",
		"lines": [
			"Franky the monster is building a friend out of boxes.",
			"He has two arms, two legs and one happy head.",
			"But the shapes will not stay still.",
			"\"A circle rolled away! A square is hiding!\"",
			"Franky needs eyes that are quick and names that are clear.",
		],
		"question": "Where are Franky's arms?",
		"focus_words": [
			{"word": "arm", "icon": "arm", "color": "skin"},
			{"word": "head", "icon": "circle", "color": "skin"},
			{"word": "square", "icon": "square", "color": "blue"},
		],
		"teacher_notes_it": "Zona 4. Parti del corpo e forme. Franky costruisce un amico: ogni pezzo ha un nome. Chiedete: «Touch your arm. Touch your head.»",
	},
	{
		"key": "zone5",
		"zone": 5,
		"mission": 33,
		"title": "The Haunted Dungeon",
		"lines": [
			"Under the castle there is a long, dark dungeon.",
			"Echo the ghost lives here, and Echo repeats everything you say.",
			"\"Hello!\" says Echo. \"Hello, hello, hello!\"",
			"The Bat Guide knows the way: ten rows, ten columns, A to J.",
			"Say the word, and Echo will show you the door.",
		],
		"question": "Can you say \"hello\" to Echo?",
		"focus_words": [
			{"word": "ghost", "icon": "ghost", "color": "white"},
			{"word": "bat", "icon": "bat", "color": "purple"},
			{"word": "hello", "icon": "speaker", "color": "pink"},
		],
		"teacher_notes_it": "Zona 5. Pronuncia, coordinate, direzioni. Echo ripete: perfetto per far sentire agli alunni la differenza fra la propria voce e il modello. Chiedete di ripetere a coppie.",
	},
	{
		"key": "finale",
		"zone": 6,
		"mission": 40,
		"title": "The Grand Halloween Party",
		"lines": [
			"All the friends come to the party: a scarecrow, a vampire, a witch.",
			"A monster, a ghost, and one very sleepy owl.",
			"Jack's lantern is full of forty little flames.",
			"Everyone stands in the light and says the same word: \"Thank you!\"",
			"Happy Halloween, Jack. You did it all by yourself.",
		],
		"question": "Shall we light the last flame together?",
		"focus_words": [
			{"word": "thank you", "icon": "speaker", "color": "gold"},
			{"word": "flame", "icon": "flame", "color": "orange"},
			{"word": "party", "icon": "hat", "color": "purple"},
		],
		"teacher_notes_it": "Finale. Ritornano tutti i personaggi e le parole delle cinque zone. È il momento del ripasso: «Who can you see? What colour is the witch's hat?»",
	},
]

## Short pages *between* two missions of the same zone, so the story does not
## disappear for seven missions in a row. They are full pages (not floating
## captions) on purpose: a caption would be spoken at the same moment as the
## mission prompt, the two voices would interrupt each other, and a class could
## not stop to read it. A page is something a teacher can hold on screen.
##
## They are shorter than a chapter (two lines, one question) and marked
## `"beat": true` so the page calls itself a story beat rather than a chapter.
const BEATS: Dictionary = {
	4: {
		"key": "beat4",
		"beat": true,
		"zone": 1,
		"mission": 4,
		"title": "Something In The Dark",
		"lines": [
			"The pumpkins are glowing again. One, two, three!",
			"Something small is moving between the trees.",
		],
		"question": "Can you say \"hello\" to it?",
		"focus_words": [
			{"word": "hello", "icon": "speaker", "color": "pink"},
			{"word": "goodbye", "icon": "speaker", "color": "purple"},
		],
		"teacher_notes_it": "Intermezzo. Prepara i saluti: hello / goodbye. Fate ripetere le due parole guardando il bosco illuminato.",
	},
	8: {
		"key": "beat8",
		"beat": true,
		"zone": 1,
		"mission": 8,
		"title": "The Last Leaf",
		"lines": [
			"Mr. Barnaby waves goodbye with his long straw arm.",
			"\"The castle is that way,\" he says. \"Mind the bats!\"",
		],
		"question": "Can you find one more green bat?",
		"focus_words": [
			{"word": "bat", "icon": "bat", "color": "green"},
			{"word": "tree", "icon": "hat", "color": "brown"},
		],
		"teacher_notes_it": "Intermezzo. Ripasso di on / under / in con i pipistrelli. Chiedete: «Where is the bat?» e fate rispondere «On the tree!».",
	},
	16: {
		"key": "beat16",
		"beat": true,
		"zone": 2,
		"mission": 16,
		"title": "The Door With Numbers",
		"lines": [
			"The skeletons are tired. They counted all night.",
			"One last door is waiting, and it only opens with a number.",
		],
		"question": "Which number do you think it wants?",
		"focus_words": [
			{"word": "door", "icon": "square", "color": "brown"},
			{"word": "number", "icon": "number", "color": "gold", "number": 16},
		],
		"teacher_notes_it": "Intermezzo. Ultimo enigma numerico della zona 2. Contate insieme fino a venti, lentamente, prima di aprire la porta.",
	},
	24: {
		"key": "beat24",
		"beat": true,
		"zone": 3,
		"mission": 24,
		"title": "The Quiet Bog",
		"lines": [
			"The bog goes quiet. The frogs stop singing.",
			"Far away, a small light switches on in a laboratory.",
		],
		"question": "Is the light near or far?",
		"focus_words": [
			{"word": "near", "icon": "flame", "color": "gold"},
			{"word": "far", "icon": "star", "color": "blue"},
		],
		"teacher_notes_it": "Intermezzo. Opposti near / far. Indicate un oggetto vicino e uno lontano nella stanza e chiedete «Near or far?».",
	},
	32: {
		"key": "beat32",
		"beat": true,
		"zone": 4,
		"mission": 32,
		"title": "Down The Stairs",
		"lines": [
			"Franky's friend is finished. He waves one big green arm.",
			"\"Thank you!\" says Franky, and he points down the stairs.",
		],
		"question": "Can you wave with your arm too?",
		"focus_words": [
			{"word": "arm", "icon": "arm", "color": "skin"},
			{"word": "hand", "icon": "foot", "color": "skin"},
			{"word": "thank you", "icon": "speaker", "color": "gold"},
		],
		"teacher_notes_it": "Intermezzo. Il corpo è completo: braccia, mani, gambe. «Touch your arm. Wave your hand.» Poi si scende nel sotterraneo.",
	},
}


## Every page in reading order: the prologue (mission 0), then chapters and
## beats sorted by the mission they introduce. Chapter and beat pages share one
## list so the page counter (\"story 3 of 12\") never needs a special case.
static func _ordered_pages() -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	for chapter in CHAPTERS:
		pages.append(chapter)
	for mission_id in BEATS:
		pages.append(BEATS[mission_id] as Dictionary)
	pages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("mission", 0)) < int(b.get("mission", 0)))
	return pages


## Every page, for tools and for the counter's total.
static func all_pages() -> Array[Dictionary]:
	return _ordered_pages()


## The page that opens the mission `mission_id`, or an empty dictionary when
## that mission is not a boundary (the common case). An empty result means
## \"just show the mission prompt\".
static func chapter_for(mission_id: int) -> Dictionary:
	var wanted := maxi(mission_id, 0)
	for page in _ordered_pages():
		if int(page.get("mission", 0)) == wanted:
			return page
	return {}


## The one-line beat before `mission_id`, or empty. Kept separate from
## `chapter_for()` for callers that want to know *which kind* of page a mission
## opens (the page itself prints CHAPTER or STORY).
static func beat_for(mission_id: int) -> Dictionary:
	var beat: Variant = BEATS.get(mission_id, {})
	return beat if beat is Dictionary else {}


## True when starting `mission_id` should open the story page rather than
## jumping straight to the task. Used by `Main` so the choice lives with the
## content instead of being duplicated in the screen flow.
static func opens_chapter(mission_id: int) -> bool:
	return not chapter_for(mission_id).is_empty()


## 1-based position of `mission_id`'s page in the book, or 0 when it has none.
static func page_number(mission_id: int) -> int:
	var wanted := maxi(mission_id, 0)
	var pages := _ordered_pages()
	for i in pages.size():
		if int(pages[i].get("mission", 0)) == wanted:
			return i + 1
	return 0


## Total number of readable pages (chapters + beats).
static func page_count() -> int:
	return _ordered_pages().size()


## Every line of a page as one spoken paragraph, for the \"listen to the whole
## page\" button. Joining with a space (not a newline) keeps the text-to-speech
## engine from clipping at the line breaks.
static func spoken_text(chapter: Dictionary) -> String:
	var parts: Array[String] = []
	for line in chapter.get("lines", []):
		parts.append(String(line))
	var question := String(chapter.get("question", ""))
	if not question.is_empty():
		parts.append(question)
	return " ".join(parts)
