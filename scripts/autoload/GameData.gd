extends Node
## Static content of the game (autoload `GameData`).: vocabulary, the 40 missions and the 5 zones.
##
## Everything a child sees or hears lives here so teachers can edit the
## text without touching the gameplay code. Each mission is a small
## dictionary read by the matching mission script.

## Zone overview. `decor` selects the environment palette in ZoneDecor.
const ZONES: Array[Dictionary] = [
	{
		"id": 1,
		"name_en": "The Whispering Pumpkin Patch",
		"name_it": "Il frutteto delle zucche sussurranti",
		"short_en": "Pumpkin Patch",
		"short_it": "Frutteto",
		"npc": "Mr. Barnaby the Scarecrow",
		"topic_en": "Colours & greetings",
		"topic_it": "Colori e saluti",
		"color": Color("f28c1e"),
		"decor": "patch",
		"first_mission": 1,
		"last_mission": 8,
	},
	{
		"id": 2,
		"name_en": "Dracula's Cozy Castle",
		"name_it": "Il castello accogliente di Dracula",
		"short_en": "Cozy Castle",
		"short_it": "Castello",
		"npc": "Baby Dracula & the Clumsy Skeletons",
		"topic_en": "Numbers 1-20 & prepositions",
		"topic_it": "Numeri 1-20 e preposizioni",
		"color": Color("8b4fd6"),
		"decor": "castle",
		"first_mission": 9,
		"last_mission": 16,
	},
	{
		"id": 3,
		"name_en": "The Wacky Witch's Bog",
		"name_it": "La palude della strega strampalata",
		"short_en": "Witch's Bog",
		"short_it": "Palude",
		"npc": "Wendy the Wacky Witch",
		"topic_en": "Adjectives & animals",
		"topic_it": "Aggettivi e animali",
		"color": Color("4fb84f"),
		"decor": "bog",
		"first_mission": 17,
		"last_mission": 24,
	},
	{
		"id": 4,
		"name_en": "Franky's Laboratory",
		"name_it": "Il laboratorio di Franky",
		"short_en": "Laboratory",
		"short_it": "Laboratorio",
		"npc": "Franky the Friendly Monster",
		"topic_en": "Body parts & shapes",
		"topic_it": "Parti del corpo e forme",
		"color": Color("3b6fd9"),
		"decor": "lab",
		"first_mission": 25,
		"last_mission": 32,
	},
	{
		"id": 5,
		"name_en": "The Haunted Dungeon",
		"name_it": "Il sotterraneo infestato",
		"short_en": "Dungeon",
		"short_it": "Sotterraneo",
		"npc": "Echo the Ghost & the Bat Guide",
		"topic_en": "Pronunciation, coordinates & directions",
		"topic_it": "Pronuncia, coordinate e direzioni",
		"color": Color("3bb7d9"),
		"decor": "dungeon",
		"first_mission": 33,
		"last_mission": 39,
	},
	{
		"id": 6,
		"name_en": "The Grand Halloween Party",
		"name_it": "La grande festa di Halloween",
		"short_en": "Grand Party",
		"short_it": "Festa",
		"npc": "All your friends",
		"topic_en": "Big review",
		"topic_it": "Ripasso finale",
		"color": Color("ffc94d"),
		"decor": "party",
		"first_mission": 40,
		"last_mission": 40,
	},
]

## English word -> Italian. Used by the Italian magnifying glass and by
## the word cards. Lower case keys.
const VOCAB: Dictionary = {
	# colours
	"red": "rosso", "blue": "blu", "yellow": "giallo", "green": "verde",
	"purple": "viola", "orange": "arancione", "black": "nero", "white": "bianco",
	"pink": "rosa", "brown": "marrone", "gold": "oro", "grey": "grigio",
	# numbers
	"one": "uno", "two": "due", "three": "tre", "four": "quattro", "five": "cinque",
	"six": "sei", "seven": "sette", "eight": "otto", "nine": "nove", "ten": "dieci",
	"eleven": "undici", "twelve": "dodici", "thirteen": "tredici",
	"fourteen": "quattordici", "fifteen": "quindici", "sixteen": "sedici",
	"seventeen": "diciassette", "eighteen": "diciotto", "nineteen": "diciannove",
	"twenty": "venti",
	# greetings & polite words
	"hello": "ciao", "goodbye": "arrivederci", "good morning": "buongiorno",
	"good night": "buonanotte", "please": "per favore", "thank you": "grazie",
	"here you are": "ecco a te", "my name is jack": "mi chiamo jack",
	# animals
	"bat": "pipistrello", "cat": "gatto", "spider": "ragno", "ghost": "fantasma",
	"pumpkin": "zucca", "skeleton": "scheletro", "witch": "strega",
	"monster": "mostro", "owl": "gufo", "frog": "rana", "snake": "serpente",
	# adjectives
	"big": "grande", "small": "piccolo", "fast": "veloce", "slow": "lento",
	"happy": "felice", "sad": "triste", "long": "lungo", "short": "corto",
	"scary": "spaventoso", "funny": "divertente", "sweet": "dolce",
	# body parts
	"head": "testa", "shoulders": "spalle", "knees": "ginocchia", "toes": "dita dei piedi",
	"eye": "occhio", "eyes": "occhi", "nose": "naso", "mouth": "bocca",
	"hand": "mano", "hands": "mani", "arm": "braccio", "arms": "braccia",
	"leg": "gamba", "legs": "gambe", "foot": "piede", "feet": "piedi",
	"finger": "dito", "fingers": "dita", "ear": "orecchio", "hair": "capelli",
	# shapes
	"square": "quadrato", "circle": "cerchio", "triangle": "triangolo", "star": "stella",
	# prepositions
	"on": "sopra", "under": "sotto", "in": "dentro", "next to": "accanto",
	"behind": "dietro", "in front of": "davanti",
	# objects
	"candy": "caramella", "apple": "mela", "hat": "cappello", "broom": "scopa",
	"cauldron": "calderone", "lantern": "lanterna", "flame": "fiamma",
	"door": "porta", "bench": "panchina", "barrel": "barile", "tree": "albero",
	"leaf": "foglia", "leaves": "foglie", "bucket": "secchio", "paint": "colore",
	# sentences
	"i am a ghost": "sono un fantasma",
	"i have two eyes": "ho due occhi",
	"i have ten fingers": "ho dieci dita",
	"the pumpkin is orange": "la zucca è arancione",
	"how are you?": "come stai?",
	"i am fine": "sto bene",
	"what is your name?": "come ti chiami?",
	"let's go!": "andiamo!",
	"well done!": "ben fatto!",
}

## All 40 missions, in order. `mechanic` picks the mission script.
static func missions() -> Array[Dictionary]:
	return [
		# ---------------- ZONE 1: colours & greetings ----------------
		{
			"id": 1, "zone": 1, "title": "Primary Pumpkins",
			"title_it": "Le zucche primarie",
			"npc": "Mr. Barnaby",
			"prompt_en": "Find the RED, BLUE and YELLOW pumpkins!",
			"prompt_it": "Trova le zucche ROSSA, BLU e GIALLA!",
			"mechanic": "find",
			"targets": [
				{"kind": "pumpkin", "color": "red", "word": "red"},
				{"kind": "pumpkin", "color": "blue", "word": "blue"},
				{"kind": "pumpkin", "color": "yellow", "word": "yellow"},
			],
			"distractors": [
				{"kind": "pumpkin", "color": "purple"},
				{"kind": "pumpkin", "color": "green"},
				{"kind": "pumpkin", "color": "orange"},
			],
		},
		{
			"id": 2, "zone": 1, "title": "Secondary Pumpkins",
			"title_it": "Le zucche secondarie",
			"npc": "Mr. Barnaby",
			"prompt_en": "Find the GREEN, PURPLE and ORANGE pumpkins!",
			"prompt_it": "Trova le zucche VERDE, VIOLA e ARANCIONE!",
			"mechanic": "find",
			"targets": [
				{"kind": "pumpkin", "color": "green", "word": "green"},
				{"kind": "pumpkin", "color": "purple", "word": "purple"},
				{"kind": "pumpkin", "color": "orange", "word": "orange"},
			],
			"distractors": [
				{"kind": "pumpkin", "color": "red"},
				{"kind": "pumpkin", "color": "blue"},
				{"kind": "pumpkin", "color": "yellow"},
			],
		},
		{
			"id": 3, "zone": 1, "title": "Dark & Light",
			"title_it": "Scuro e chiaro",
			"npc": "Mr. Barnaby",
			"prompt_en": "Find the BLACK, WHITE, PINK and BROWN bats!",
			"prompt_it": "Trova i pipistrelli NERO, BIANCO, ROSA e MARRONE!",
			"mechanic": "find",
			"targets": [
				{"kind": "bat", "color": "black", "word": "black"},
				{"kind": "bat", "color": "white", "word": "white"},
				{"kind": "bat", "color": "pink", "word": "pink"},
				{"kind": "bat", "color": "brown", "word": "brown"},
			],
			"distractors": [
				{"kind": "bat", "color": "green"},
				{"kind": "bat", "color": "blue"},
			],
		},
		{
			"id": 4, "zone": 1, "title": "Hello & Goodbye",
			"title_it": "Ciao e arrivederci",
			"npc": "Mr. Barnaby",
			"prompt_en": "Wake up the sleeping trees. Say HELLO and GOODBYE!",
			"prompt_it": "Sveglia gli alberi addormentati. Dì HELLO e GOODBYE!",
			"mechanic": "repeat",
			"lines": [
				{"en": "Hello!", "it": "Ciao!"},
				{"en": "Goodbye!", "it": "Arrivederci!"},
			],
		},
		{
			"id": 5, "zone": 1, "title": "Please & Thank You",
			"title_it": "Per favore e grazie",
			"npc": "Mr. Barnaby",
			"prompt_en": "Give Barnaby his hat. What do you say?",
			"prompt_it": "Dai il cappello a Barnaby. Cosa dici?",
			"mechanic": "quiz",
			"questions": [
				{
					"en": "You give the hat to Barnaby. What do you say?",
					"it": "Dai il cappello a Barnaby. Cosa dici?",
					"options": [
						{"label": "Here you are!", "icon": "hat", "color": "brown", "correct": true},
						{"label": "Goodbye!", "icon": "bat", "color": "purple"},
						{"label": "Red!", "icon": "pumpkin", "color": "red"},
					],
				},
			],
		},
		{
			"id": 6, "zone": 1, "title": "Colour Sequence",
			"title_it": "La sequenza dei colori",
			"npc": "Mr. Barnaby",
			"prompt_en": "Step on the leaves in order: RED, GREEN, BLUE.",
			"prompt_it": "Pesta le foglie in ordine: ROSSA, VERDE, BLU.",
			"mechanic": "sequence",
			"targets": [
				{"kind": "leaf", "color": "red", "word": "red"},
				{"kind": "leaf", "color": "green", "word": "green"},
				{"kind": "leaf", "color": "blue", "word": "blue"},
			],
		},
		{
			"id": 7, "zone": 1, "title": "The Painted Apples",
			"title_it": "Le mele dipinte",
			"npc": "Mr. Barnaby",
			"prompt_en": "The apple says GREEN. Tap the green paint bucket!",
			"prompt_it": "La mela dice GREEN. Tocca il secchio di colore verde!",
			"mechanic": "quiz",
			"questions": [
				{
					"en": "The apple says GREEN. Tap the green bucket!",
					"it": "La mela dice GREEN. Tocca il secchio verde!",
					"options": [
						{"label": "Green", "icon": "bucket", "color": "green", "correct": true},
						{"label": "Red", "icon": "bucket", "color": "red"},
						{"label": "Blue", "icon": "bucket", "color": "blue"},
					],
				},
			],
		},
		{
			"id": 8, "zone": 1, "title": "Bat Hide & Seek 1",
			"title_it": "Nascondino con i pipistrelli 1",
			"npc": "Mr. Barnaby",
			"prompt_en": "Find the GREEN bat ON the tree.",
			"prompt_it": "Trova il pipistrello VERDE SOPRA l'albero.",
			"mechanic": "find",
			"targets": [
				{"kind": "bat", "color": "green", "word": "on", "anchor": "on_tree", "label": "ON"},
			],
			"distractors": [
				{"kind": "bat", "color": "green", "anchor": "in_barrel", "label": "IN"},
				{"kind": "bat", "color": "green", "anchor": "under_bench", "label": "UNDER"},
			],
		},

		# ---------------- ZONE 2: numbers & prepositions ----------------
		{
			"id": 9, "zone": 2, "title": "Bridge Toll 1",
			"title_it": "Il pedaggio del ponte 1",
			"npc": "Clumsy Skeleton",
			"prompt_en": "Give the skeleton exactly FIVE orange candies.",
			"prompt_it": "Dai allo scheletro esattamente CINQUE caramelle arancioni.",
			"mechanic": "count",
			"requirements": [{"kind": "candy", "color": "orange", "count": 5, "word": "orange"}],
			"extras": [
				{"kind": "candy", "color": "orange", "count": 6},
				{"kind": "candy", "color": "purple", "count": 4},
			],
		},
		{
			"id": 10, "zone": 2, "title": "Bridge Toll 2",
			"title_it": "Il pedaggio del ponte 2",
			"npc": "Clumsy Skeleton",
			"prompt_en": "Give the skeleton exactly NINE black candies.",
			"prompt_it": "Dai allo scheletro esattamente NOVE caramelle nere.",
			"mechanic": "count",
			"requirements": [{"kind": "candy", "color": "black", "count": 9, "word": "black"}],
			"extras": [
				{"kind": "candy", "color": "black", "count": 8},
				{"kind": "candy", "color": "green", "count": 7},
			],
		},
		{
			"id": 11, "zone": 2, "title": "Bat Hide & Seek 2",
			"title_it": "Nascondino con i pipistrelli 2",
			"npc": "Baby Dracula",
			"prompt_en": "Find the PURPLE bat UNDER the bench.",
			"prompt_it": "Trova il pipistrello VIOLA SOTTO la panchina.",
			"mechanic": "find",
			"targets": [
				{"kind": "bat", "color": "purple", "anchor": "under_bench", "label": "UNDER"},
			],
			"distractors": [
				{"kind": "bat", "color": "purple", "anchor": "on_bench", "label": "ON"},
				{"kind": "bat", "color": "pink", "anchor": "in_barrel", "label": "IN"},
			],
		},
		{
			"id": 12, "zone": 2, "title": "Bat Hide & Seek 3",
			"title_it": "Nascondino con i pipistrelli 3",
			"npc": "Baby Dracula",
			"prompt_en": "Find the PINK bat IN the barrel.",
			"prompt_it": "Trova il pipistrello ROSA DENTRO il barile.",
			"mechanic": "find",
			"targets": [
				{"kind": "bat", "color": "pink", "anchor": "in_barrel", "label": "IN"},
			],
			"distractors": [
				{"kind": "bat", "color": "pink", "anchor": "under_bench", "label": "UNDER"},
				{"kind": "bat", "color": "purple", "anchor": "on_bench", "label": "ON"},
			],
		},
		{
			"id": 13, "zone": 2, "title": "Counting Stars 1",
			"title_it": "Contiamo le stelle 1",
			"npc": "Baby Dracula",
			"prompt_en": "Step on the stars from 1 to 10, in order.",
			"prompt_it": "Pesta le stelle da 1 a 10, in ordine.",
			"mechanic": "sequence",
			"numbered": true,
			"targets": [
				{"kind": "star", "color": "gold", "number": 1, "word": "one"},
				{"kind": "star", "color": "gold", "number": 2, "word": "two"},
				{"kind": "star", "color": "gold", "number": 3, "word": "three"},
				{"kind": "star", "color": "gold", "number": 4, "word": "four"},
				{"kind": "star", "color": "gold", "number": 5, "word": "five"},
				{"kind": "star", "color": "gold", "number": 6, "word": "six"},
				{"kind": "star", "color": "gold", "number": 7, "word": "seven"},
				{"kind": "star", "color": "gold", "number": 8, "word": "eight"},
				{"kind": "star", "color": "gold", "number": 9, "word": "nine"},
				{"kind": "star", "color": "gold", "number": 10, "word": "ten"},
			],
		},
		{
			"id": 14, "zone": 2, "title": "Counting Stars 2",
			"title_it": "Contiamo le stelle 2",
			"npc": "Baby Dracula",
			"prompt_en": "Step on the stars from 11 to 15, in order.",
			"prompt_it": "Pesta le stelle da 11 a 15, in ordine.",
			"mechanic": "sequence",
			"numbered": true,
			"targets": [
				{"kind": "star", "color": "gold", "number": 11, "word": "eleven"},
				{"kind": "star", "color": "gold", "number": 12, "word": "twelve"},
				{"kind": "star", "color": "gold", "number": 13, "word": "thirteen"},
				{"kind": "star", "color": "gold", "number": 14, "word": "fourteen"},
				{"kind": "star", "color": "gold", "number": 15, "word": "fifteen"},
			],
		},
		{
			"id": 15, "zone": 2, "title": "Counting Stars 3",
			"title_it": "Contiamo le stelle 3",
			"npc": "Baby Dracula",
			"prompt_en": "Step on the stars from 16 to 20, in order.",
			"prompt_it": "Pesta le stelle da 16 a 20, in ordine.",
			"mechanic": "sequence",
			"numbered": true,
			"targets": [
				{"kind": "star", "color": "gold", "number": 16, "word": "sixteen"},
				{"kind": "star", "color": "gold", "number": 17, "word": "seventeen"},
				{"kind": "star", "color": "gold", "number": 18, "word": "eighteen"},
				{"kind": "star", "color": "gold", "number": 19, "word": "nineteen"},
				{"kind": "star", "color": "gold", "number": 20, "word": "twenty"},
			],
		},
		{
			"id": 16, "zone": 2, "title": "The Number Door",
			"title_it": "La porta dei numeri",
			"npc": "Baby Dracula",
			"prompt_en": "The door says TWELVE. Tap the number 12!",
			"prompt_it": "La porta dice TWELVE. Tocca il numero 12!",
			"mechanic": "quiz",
			"questions": [
				{
					"en": "The door says TWELVE. Tap the number 12!",
					"it": "La porta dice TWELVE. Tocca il numero 12!",
					"options": [
						{"label": "12", "icon": "number", "number": 12, "correct": true},
						{"label": "20", "icon": "number", "number": 20},
						{"label": "2", "icon": "number", "number": 2},
					],
				},
			],
		},

		# ---------------- ZONE 3: adjectives & animals ----------------
		{
			"id": 17, "zone": 3, "title": "Size Matters",
			"title_it": "Questioni di dimensione",
			"npc": "Wendy the Witch",
			"prompt_en": "Bring Wendy the BIG ghost. Ignore the small one.",
			"prompt_it": "Porta a Wendy il fantasma GRANDE. Ignora quello piccolo.",
			"mechanic": "find",
			"targets": [
				{"kind": "ghost", "color": "white", "scale": 1.45, "word": "big", "label": "BIG"},
			],
			"distractors": [
				{"kind": "ghost", "color": "white", "scale": 0.8, "label": "small"},
			],
		},
		{
			"id": 18, "zone": 3, "title": "Size Matters 2",
			"title_it": "Questioni di dimensione 2",
			"npc": "Wendy the Witch",
			"prompt_en": "Bring Wendy the SMALL spider.",
			"prompt_it": "Porta a Wendy il ragno PICCOLO.",
			"mechanic": "find",
			"targets": [
				{"kind": "spider", "color": "black", "scale": 0.75, "word": "small", "label": "SMALL"},
			],
			"distractors": [
				{"kind": "spider", "color": "black", "scale": 1.45, "label": "big"},
			],
		},
		{
			"id": 19, "zone": 3, "title": "Speed Check",
			"title_it": "Chi è veloce?",
			"npc": "Wendy the Witch",
			"prompt_en": "Catch the FAST cat. The slow cat is sleeping!",
			"prompt_it": "Prendi il gatto VELOCE. Il gatto lento dorme!",
			"mechanic": "find",
			"targets": [
				{"kind": "cat", "color": "orange", "motion": "fast", "word": "fast", "label": "FAST"},
			],
			"distractors": [
				{"kind": "cat", "color": "grey", "motion": "slow", "label": "slow"},
			],
		},
		{
			"id": 20, "zone": 3, "title": "Emotions",
			"title_it": "Le emozioni",
			"npc": "Wendy the Witch",
			"prompt_en": "Find the HAPPY pumpkin. Ignore the sad pumpkin.",
			"prompt_it": "Trova la zucca FELICE. Ignora quella triste.",
			"mechanic": "find",
			"targets": [
				{"kind": "pumpkin", "color": "orange", "face": "happy", "word": "happy", "label": "HAPPY"},
			],
			"distractors": [
				{"kind": "pumpkin", "color": "purple", "face": "sad", "label": "sad"},
				{"kind": "pumpkin", "color": "orange", "face": "sad", "label": "sad"},
			],
		},
		{
			"id": 21, "zone": 3, "title": "Combo 1",
			"title_it": "Combinazione 1",
			"npc": "Wendy the Witch",
			"prompt_en": "Find the BIG BLACK SPIDER.",
			"prompt_it": "Trova il RAGNO NERO GRANDE.",
			"mechanic": "find",
			"targets": [
				{"kind": "spider", "color": "black", "scale": 1.5, "word": "big black spider"},
			],
			"distractors": [
				{"kind": "spider", "color": "black", "scale": 0.8},
				{"kind": "spider", "color": "purple", "scale": 1.5},
				{"kind": "cat", "color": "black", "scale": 1.4},
			],
		},
		{
			"id": 22, "zone": 3, "title": "Combo 2",
			"title_it": "Combinazione 2",
			"npc": "Wendy the Witch",
			"prompt_en": "Find the SMALL WHITE CAT.",
			"prompt_it": "Trova il GATTO BIANCO PICCOLO.",
			"mechanic": "find",
			"targets": [
				{"kind": "cat", "color": "white", "scale": 0.8, "word": "small white cat"},
			],
			"distractors": [
				{"kind": "cat", "color": "white", "scale": 1.4},
				{"kind": "cat", "color": "black", "scale": 0.8},
				{"kind": "bat", "color": "white", "scale": 0.8},
			],
		},
		{
			"id": 23, "zone": 3, "title": "Cauldron Soup 1",
			"title_it": "La zuppa del calderone 1",
			"npc": "Wendy the Witch",
			"prompt_en": "Put 1 bat, 1 hat and 1 broom in the cauldron.",
			"prompt_it": "Metti 1 pipistrello, 1 cappello e 1 scopa nel calderone.",
			"mechanic": "count",
			"requirements": [
				{"kind": "bat", "count": 1, "word": "bat"},
				{"kind": "hat", "count": 1, "word": "hat"},
				{"kind": "broom", "count": 1, "word": "broom"},
			],
			"extras": [
				{"kind": "bat", "color": "purple", "count": 2},
				{"kind": "apple", "color": "red", "count": 2},
			],
		},
		{
			"id": 24, "zone": 3, "title": "Cauldron Soup 2",
			"title_it": "La zuppa del calderone 2",
			"npc": "Wendy the Witch",
			"prompt_en": "Put 2 red apples and 3 small spiders in the cauldron.",
			"prompt_it": "Metti 2 mele rosse e 3 ragni piccoli nel calderone.",
			"mechanic": "count",
			"requirements": [
				{"kind": "apple", "color": "red", "count": 2, "word": "red apple"},
				{"kind": "spider", "scale": 0.8, "count": 3, "word": "small spider"},
			],
			"extras": [
				{"kind": "apple", "color": "green", "count": 2},
				{"kind": "spider", "scale": 1.5, "count": 2},
			],
		},

		# ---------------- ZONE 4: body parts & shapes ----------------
		{
			"id": 25, "zone": 4, "title": "The Right Eye",
			"title_it": "L'occhio destro",
			"npc": "Franky",
			"prompt_en": "Select the GREEN SQUARE eye.",
			"prompt_it": "Scegli l'occhio QUADRATO VERDE.",
			"mechanic": "quiz",
			"questions": [
				{
					"en": "Select the GREEN SQUARE eye.",
					"it": "Scegli l'occhio quadrato verde.",
					"options": [
						{"label": "Square", "icon": "square", "color": "green", "correct": true},
						{"label": "Circle", "icon": "circle", "color": "blue"},
						{"label": "Triangle", "icon": "triangle", "color": "red"},
					],
				},
			],
		},
		{
			"id": 26, "zone": 4, "title": "The Left Eye",
			"title_it": "L'occhio sinistro",
			"npc": "Franky",
			"prompt_en": "Select the BLUE CIRCLE eye.",
			"prompt_it": "Scegli l'occhio CERCHIO BLU.",
			"mechanic": "quiz",
			"questions": [
				{
					"en": "Select the BLUE CIRCLE eye.",
					"it": "Scegli l'occhio cerchio blu.",
					"options": [
						{"label": "Circle", "icon": "circle", "color": "blue", "correct": true},
						{"label": "Square", "icon": "square", "color": "green"},
						{"label": "Star", "icon": "star", "color": "purple"},
					],
				},
			],
		},
		{
			"id": 27, "zone": 4, "title": "The Nose",
			"title_it": "Il naso",
			"npc": "Franky",
			"prompt_en": "Select the RED TRIANGLE nose.",
			"prompt_it": "Scegli il naso TRIANGOLO ROSSO.",
			"mechanic": "quiz",
			"questions": [
				{
					"en": "Select the RED TRIANGLE nose.",
					"it": "Scegli il naso triangolo rosso.",
					"options": [
						{"label": "Triangle", "icon": "triangle", "color": "red", "correct": true},
						{"label": "Circle", "icon": "circle", "color": "red"},
						{"label": "Square", "icon": "square", "color": "red"},
					],
				},
			],
		},
		{
			"id": 28, "zone": 4, "title": "The Mouth",
			"title_it": "La bocca",
			"npc": "Franky",
			"prompt_en": "Select the PURPLE STAR mouth.",
			"prompt_it": "Scegli la bocca STELLA VIOLA.",
			"mechanic": "quiz",
			"questions": [
				{
					"en": "Select the PURPLE STAR mouth.",
					"it": "Scegli la bocca stella viola.",
					"options": [
						{"label": "Star", "icon": "star", "color": "purple", "correct": true},
						{"label": "Star", "icon": "star", "color": "yellow"},
						{"label": "Circle", "icon": "circle", "color": "purple"},
					],
				},
			],
		},
		{
			"id": 29, "zone": 4, "title": "Arms",
			"title_it": "Le braccia",
			"npc": "Franky",
			"prompt_en": "Which arm is LONG?",
			"prompt_it": "Quale braccio è LUNGO?",
			"mechanic": "quiz",
			"questions": [
				{
					"en": "Which arm is LONG?",
					"it": "Quale braccio è lungo?",
					"options": [
						{"label": "Long", "icon": "arm", "color": "skin", "size": 1.35, "correct": true},
						{"label": "Short", "icon": "arm", "color": "skin", "size": 0.6},
						{"label": "Short", "icon": "arm", "color": "green", "size": 0.6},
					],
				},
			],
		},
		{
			"id": 30, "zone": 4, "title": "Legs",
			"title_it": "Le gambe",
			"npc": "Franky",
			"prompt_en": "Which foot is BIG?",
			"prompt_it": "Quale piede è GRANDE?",
			"mechanic": "quiz",
			"questions": [
				{
					"en": "Which foot is BIG?",
					"it": "Quale piede è grande?",
					"options": [
						{"label": "Big foot", "icon": "foot", "color": "purple", "size": 1.4, "correct": true},
						{"label": "Small foot", "icon": "foot", "color": "purple", "size": 0.7},
						{"label": "Small foot", "icon": "foot", "color": "green", "size": 0.7},
					],
				},
			],
		},
		{
			"id": 31, "zone": 4, "title": "Franky's Hands",
			"title_it": "Le mani di Franky",
			"npc": "Franky",
			"prompt_en": "How many fingers does Franky have?",
			"prompt_it": "Quante dita ha Franky?",
			"mechanic": "quiz",
			"questions": [
				{
					"en": "How many fingers does Franky have?",
					"it": "Quante dita ha Franky?",
					"options": [
						{"label": "10", "icon": "number", "number": 10, "correct": true},
						{"label": "5", "icon": "number", "number": 5},
						{"label": "12", "icon": "number", "number": 12},
					],
				},
			],
		},
		{
			"id": 32, "zone": 4, "title": "Franky Says",
			"title_it": "Franky dice",
			"npc": "Franky",
			"prompt_en": "Tap Jack's body parts in order: HEAD, SHOULDERS, KNEES, TOES!",
			"prompt_it": "Tocca le parti del corpo di Jack in ordine: HEAD, SHOULDERS, KNEES, TOES!",
			"mechanic": "tpr",
			"targets": [
				{"kind": "body", "word": "head", "part": "head"},
				{"kind": "body", "word": "shoulders", "part": "shoulders"},
				{"kind": "body", "word": "knees", "part": "knees"},
				{"kind": "body", "word": "toes", "part": "toes"},
			],
		},

		# ---------------- ZONE 5: pronunciation & grid ----------------
		{
			"id": 33, "zone": 5, "title": "Magic Mirror 1",
			"title_it": "Lo specchio magico 1",
			"npc": "Echo the Ghost",
			"prompt_en": "Listen and repeat: Hello!",
			"prompt_it": "Ascolta e ripeti: Hello!",
			"mechanic": "repeat",
			"lines": [{"en": "Hello!", "it": "Ciao!"}],
		},
		{
			"id": 34, "zone": 5, "title": "Magic Mirror 2",
			"title_it": "Lo specchio magico 2",
			"npc": "Echo the Ghost",
			"prompt_en": "Listen and repeat: I am a ghost.",
			"prompt_it": "Ascolta e ripeti: I am a ghost.",
			"mechanic": "repeat",
			"lines": [{"en": "I am a ghost.", "it": "Sono un fantasma."}],
		},
		{
			"id": 35, "zone": 5, "title": "Magic Mirror 3",
			"title_it": "Lo specchio magico 3",
			"npc": "Echo the Ghost",
			"prompt_en": "Listen and repeat: I have two eyes.",
			"prompt_it": "Ascolta e ripeti: I have two eyes.",
			"mechanic": "repeat",
			"lines": [{"en": "I have two eyes.", "it": "Ho due occhi."}],
		},
		{
			"id": 36, "zone": 5, "title": "Magic Mirror 4",
			"title_it": "Lo specchio magico 4",
			"npc": "Echo the Ghost",
			"prompt_en": "Listen and repeat: The pumpkin is orange.",
			"prompt_it": "Ascolta e ripeti: The pumpkin is orange.",
			"mechanic": "repeat",
			"lines": [{"en": "The pumpkin is orange.", "it": "La zucca è arancione."}],
		},
		{
			"id": 37, "zone": 5, "title": "Grid Intro",
			"title_it": "La griglia - introduzione",
			"npc": "The Bat Guide",
			"prompt_en": "Walk to A1, then to B3. Watch the glowing squares!",
			"prompt_it": "Cammina fino a A1, poi a B3. Guarda i quadrati luminosi!",
			"mechanic": "grid",
			"path": ["A1", "B3"],
			"traps": [],
		},
		{
			"id": 38, "zone": 5, "title": "Deep Grid",
			"title_it": "La griglia profonda",
			"npc": "The Bat Guide",
			"prompt_en": "Walk to D5. Don't step on the trap at C5!",
			"prompt_it": "Cammina fino a D5. Non pestare la trappola in C5!",
			"mechanic": "grid",
			"path": ["D5"],
			"traps": ["C5"],
		},
		{
			"id": 39, "zone": 5, "title": "Grid Directions",
			"title_it": "La griglia - direzioni",
			"npc": "The Bat Guide",
			"prompt_en": "Move 2 squares FORWARD, then 1 square RIGHT.",
			"prompt_it": "Muoviti di 2 quadrati AVANTI, poi 1 quadrato a DESTRA.",
			"mechanic": "grid",
			"path": ["C2", "D2"],
			"traps": ["C3"],
			"start": "C1",
		},

		# ---------------- ZONE 6: the party ----------------
		{
			"id": 40, "zone": 6, "title": "The Party Quiz",
			"title_it": "Il quiz della festa",
			"npc": "All your friends",
			"prompt_en": "Ten quick questions. You can do it!",
			"prompt_it": "Dieci domande veloci. Ce la puoi fare!",
			"mechanic": "quiz",
			"final_party": true,
			"questions": [
				{
					"en": "What colour is a pumpkin?",
					"it": "Di che colore è una zucca?",
					"options": [
						{"label": "Orange", "icon": "pumpkin", "color": "orange", "correct": true},
						{"label": "Blue", "icon": "pumpkin", "color": "blue"},
						{"label": "Pink", "icon": "pumpkin", "color": "pink"},
					],
				},
				{
					"en": "How many eyes do you have?",
					"it": "Quanti occhi hai?",
					"options": [
						{"label": "2", "icon": "number", "number": 2, "correct": true},
						{"label": "3", "icon": "number", "number": 3},
						{"label": "5", "icon": "number", "number": 5},
					],
				},
				{
					"en": "Which one is a number: FIVE?",
					"it": "Quale è il numero CINQUE?",
					"options": [
						{"label": "5", "icon": "number", "number": 5, "correct": true},
						{"label": "9", "icon": "number", "number": 9},
						{"label": "15", "icon": "number", "number": 15},
					],
				},
				{
					"en": "Which one is BIG?",
					"it": "Quale è GRANDE?",
					"size_question": true,
					"options": [
						{"label": "Big", "icon": "circle", "color": "purple", "size": 1.5, "correct": true},
						{"label": "Small", "icon": "circle", "color": "purple", "size": 0.5},
						{"label": "Small", "icon": "circle", "color": "green", "size": 0.5},
					],
				},
				{
					# No blank in the sentence. It used to read "The bat is ___
					# the tree.", and the three underscores reached both the
					# label and the speech engine verbatim — the child saw a row
					# of line characters and heard "underscore underscore
					# underscore" instead of a question. The prompt now *asks*
					# what the picture above shows, which still needs the
					# preposition and still has exactly one right answer.
					"en": "The bat is high up in the tree. Which word tells us where?",
					"it": "Il pipistrello è in alto sull'albero. Quale parola ci dice dove?",
					"options": [
						{"label": "ON", "icon": "bat", "color": "purple", "correct": true},
						{"label": "UNDER", "icon": "bat", "color": "black"},
						{"label": "IN", "icon": "bat", "color": "green"},
					],
				},
				{
					"en": "What do you say when you meet a friend?",
					"it": "Cosa dici quando incontri un amico?",
					"options": [
						{"label": "Hello!", "icon": "ghost", "color": "white", "correct": true},
						{"label": "Goodbye!", "icon": "bat", "color": "black"},
						{"label": "Twelve!", "icon": "number", "number": 12},
					],
				},
				{
					"en": "How many fingers on two hands?",
					"it": "Quante dita su due mani?",
					"options": [
						{"label": "10", "icon": "number", "number": 10, "correct": true},
						{"label": "2", "icon": "number", "number": 2},
						{"label": "7", "icon": "number", "number": 7},
					],
				},
				{
					"en": "Which one is a SHAPE?",
					"it": "Quale è una FORMA?",
					"options": [
						{"label": "Triangle", "icon": "triangle", "color": "red", "correct": true},
						{"label": "Barrel", "icon": "barrel", "color": "brown"},
						{"label": "Broom", "icon": "broom", "color": "brown"},
					],
				},
				{
					"en": "Which animal flies at night?",
					"it": "Quale animale vola di notte?",
					"options": [
						{"label": "Bat", "icon": "bat", "color": "black", "correct": true},
						{"label": "Cat", "icon": "cat", "color": "orange"},
						{"label": "Frog", "icon": "ghost", "color": "green"},
					],
				},
				{
					"en": "Which one is HAPPY?",
					"it": "Quale è FELICE?",
					"options": [
						{"label": "Happy", "icon": "pumpkin", "color": "orange", "face": "happy", "correct": true},
						{"label": "Sad", "icon": "pumpkin", "color": "orange", "face": "sad"},
						{"label": "Sad", "icon": "pumpkin", "color": "purple", "face": "sad"},
					],
				},
			],
		},
	]


# --- Extra challenges -------------------------------------------------------
#
# Twenty bonus missions that live *outside* the forty-flame story. They are kept
# in their own list, and not appended to `missions()`, for three reasons that all
# come from the same promise to the class:
#
#   * `missions()` is the story. Its length is the number on the title screen, in
#     the HUD counter, in the ending certificate and in `QuestManager.flames`.
#     Adding twenty entries there would turn "The 40 Magic Flames" into a lie.
#   * zone ids are pinned to mission ids 1..40 in `ZONES`, so an appended entry
#     would have to be given a zone it does not belong to.
#   * the story is finished. A child who has already seen the party must be able
#     to open these without the game pretending chapter 41 exists.
#
# Their ids start at 101 rather than 41 so that no code which still reasons about
# story ids can mistake one for a story mission. `extra_index` (1..40) is filled
# in by `extra_missions()`, because it is the number the HUD shows and it must
# never drift from the position in this list.
#
# Pedagogically these are the *same skills* as the story, with the answer taken
# off the floor. Nothing new is asked: a child who can read "G7" still walks to
# G7, they simply have no glowing square to follow. That is what "aumentare il
# livello di difficoltà" means here, and it is why the prompts are terse --
# naming the coordinates *is* the whole instruction.
const EXTRA_CHALLENGES: Array[Dictionary] = [
	# ---------------- Coordinates, no highlight (1-10) ----------------
	{
		"id": 101, "zone": 5, "title": "Read the Board",
		"title_it": "Leggi la griglia",
		"npc": "The Bat Guide",
		"prompt_en": "Go to C4.",
		"prompt_it": "Vai a C4.",
		"mechanic": "coords",
		"start": "A1",
		"path": ["C4"],
		"traps": [],
		# A crate on the diagonal the child would walk by instinct: the short
		# way is closed, so the first thing this mission teaches is that the
		# board is walked tile by tile, not pointed at.
		"obstacles": ["B2"],
	},
	{
		"id": 102, "zone": 5, "title": "Two Stops",
		"title_it": "Due tappe",
		"npc": "The Bat Guide",
		"prompt_en": "Go to F2, then F6.",
		"prompt_it": "Vai a F2, poi a F6.",
		"mechanic": "coords",
		"start": "A1",
		"path": ["F2", "F6"],
		"traps": ["E2"],
		"obstacles": ["D4"],
	},
	{
		"id": 103, "zone": 5, "title": "The Long Climb",
		"title_it": "La salita lunga",
		"npc": "The Bat Guide",
		"prompt_en": "Go to B8.",
		"prompt_it": "Vai a B8.",
		"mechanic": "coords",
		"start": "A1",
		"path": ["B8"],
		# The trap on B5 closes the obvious straight line up column B; the walk
		# is still short, but it has to be *planned*.
		"traps": ["B5", "A6"],
		"obstacles": ["C7"],
	},
	{
		"id": 104, "zone": 5, "title": "Around the Corner",
		"title_it": "Dietro l'angolo",
		"npc": "The Bat Guide",
		"prompt_en": "Go to H3, then H8.",
		"prompt_it": "Vai a H3, poi a H8.",
		"mechanic": "coords",
		"start": "A1",
		"path": ["H3", "H8"],
		# Two traps that turn the column into a dead end, so H8 has to be reached
		# from the inside of the board. Nothing is lost by trying: a trap only
		# puts Jack back where he was standing.
		"traps": ["G4", "H5"],
		"obstacles": ["F8"],
	},
	{
		"id": 105, "zone": 5, "title": "The Far Corner",
		"title_it": "L'angolo lontano",
		"npc": "The Bat Guide",
		"prompt_en": "Go to J10, then D10.",
		"prompt_it": "Vai a J10, poi a D10.",
		"mechanic": "coords",
		"start": "A1",
		"path": ["J10", "D10"],
		"traps": ["E10", "G10"],
		"obstacles": ["H2", "C5"],
	},
	{
		"id": 106, "zone": 5, "title": "The Square",
		"title_it": "Il quadrato",
		"npc": "The Bat Guide",
		"prompt_en": "Go to C3, then G3, then C8, then G8.",
		"prompt_it": "Vai a C3, poi a G3, poi a C8, poi a G8.",
		"mechanic": "coords",
		"start": "A1",
		"path": ["C3", "G3", "C8", "G8"],
		# Four traps on the corners of the inner square and one crate in its
		# middle: the diagonal shortcut across the board is simply not there.
		"traps": ["D4", "F4", "D7", "F7"],
		"obstacles": ["E5"],
	},
	{
		"id": 107, "zone": 5, "title": "Corner to Corner",
		"title_it": "Da un angolo all'altro",
		"npc": "The Bat Guide",
		"prompt_en": "Go to A10, then J1.",
		"prompt_it": "Vai a A10, poi a J1.",
		"mechanic": "coords",
		"start": "D5",
		"path": ["A10", "J1"],
		"traps": ["C4", "B5"],
		"obstacles": ["E5"],
	},
	{
		"id": 108, "zone": 5, "title": "The Rectangle",
		"title_it": "Il rettangolo",
		"npc": "The Bat Guide",
		"prompt_en": "Go to D4, D7, G7 and G4, in that order.",
		"prompt_it": "Vai a D4, D7, G7 e G4, in questo ordine.",
		"mechanic": "coords",
		"start": "B2",
		"path": ["D4", "D7", "G7", "G4"],
		"traps": ["E5", "F6"],
		"obstacles": ["C6", "H5"],
	},
	{
		"id": 109, "zone": 5, "title": "Only One Way In",
		"title_it": "Una sola entrata",
		"npc": "The Bat Guide",
		"prompt_en": "Go to E5.",
		"prompt_it": "Vai a E5.",
		"mechanic": "coords",
		"start": "A1",
		"path": ["E5"],
		# E5 is walled in by traps on six of its eight sides. The two open tiles
		# are on the same side, so the child has to walk *round* the ring to find
		# them -- the clearest possible demonstration that a coordinate names one
		# tile and that reaching it is a route, not a straight line.
		"traps": ["D4", "E4", "F4", "D5", "D6", "E6"],
		"obstacles": [],
	},
	{
		"id": 110, "zone": 5, "title": "The Final Board",
		"title_it": "La griglia finale",
		"npc": "The Bat Guide",
		"prompt_en": "Go to C5, then F5, then F9, then B9.",
		"prompt_it": "Vai a C5, poi a F5, poi a F9, poi a B9.",
		"mechanic": "coords",
		"start": "A1",
		"path": ["C5", "F5", "F9", "B9"],
		"traps": ["D5", "E6", "G6", "E9"],
		"obstacles": ["B3", "C7"],
	},

	# ---------------- Number combinations, any order (11-20) ----------------
	#
	# `numbers` is the set to complete; `pool` is what is actually on the board,
	# and always contains every wanted number at least once plus at least one
	# wrong digit. Some pools repeat a wanted digit on purpose: the second copy
	# stops being correct the moment the first one is claimed, which is a real
	# trap and costs the child nothing to discover.
	#
	# The pools are written out by hand rather than generated from `numbers`
	# because "which wrong numbers are on this board" is a design decision (a
	# 6 next to a 9 is a different lesson from a 6 next to a 13) and a generator
	# would make that decision invisible to the teacher reading this file.
	{
		"id": 111, "zone": 2, "title": "Three Numbers",
		"title_it": "Tre numeri",
		"npc": "Baby Dracula",
		"prompt_en": "Find 3, 7 and 12. Any order!",
		"prompt_it": "Trova 3, 7 e 12. In qualsiasi ordine!",
		"mechanic": "find_numbers",
		"numbers": [3, 7, 12],
		"pool": [3, 7, 12, 5, 9],
	},
	{
		"id": 112, "zone": 2, "title": "The Teens",
		"title_it": "I numeri da 13 a 19",
		"npc": "Baby Dracula",
		"prompt_en": "Find 13, 16 and 19. Any order!",
		"prompt_it": "Trova 13, 16 e 19. In qualsiasi ordine!",
		"mechanic": "find_numbers",
		# 13 and 19 are the pair a class confuses first when it reads the -teen
		# ending, so they sit on the same board as two distractors that share
		# their first digit.
		"numbers": [13, 16, 19],
		"pool": [13, 16, 19, 14, 18],
	},
	{
		"id": 113, "zone": 2, "title": "The Twenties",
		"title_it": "I numeri da 20 a 29",
		"npc": "Baby Dracula",
		"prompt_en": "Find 20, 23 and 28. Any order!",
		"prompt_it": "Trova 20, 23 e 28. In qualsiasi ordine!",
		"mechanic": "find_numbers",
		"numbers": [20, 23, 28],
		"pool": [20, 23, 28, 22, 25],
	},
	{
		"id": 114, "zone": 2, "title": "One and Two",
		"title_it": "Uno e due cifre",
		"npc": "Baby Dracula",
		"prompt_en": "Find 1, 10 and 15. Any order!",
		"prompt_it": "Trova 1, 10 e 15. In qualsiasi ordine!",
		"mechanic": "find_numbers",
		# 1 / 10 / 15 forces the child to look at the *whole* number: 1 is a
		# prefix of 10 and 15 both, so glancing at the first digit is not enough.
		"numbers": [1, 10, 15],
		"pool": [1, 10, 15, 11, 5],
	},
	{
		"id": 115, "zone": 2, "title": "Two Pairs",
		"title_it": "Due coppie",
		"npc": "Baby Dracula",
		"prompt_en": "Find 2, 4, 6 and 8. Any order!",
		"prompt_it": "Trova 2, 4, 6 e 8. In qualsiasi ordine!",
		"mechanic": "find_numbers",
		"numbers": [2, 4, 6, 8],
		"pool": [2, 4, 6, 8, 3, 7],
	},
	{
		"id": 116, "zone": 2, "title": "The Odd Ones",
		"title_it": "I dispari",
		"npc": "Baby Dracula",
		"prompt_en": "Find 5, 9 and 11. Any order!",
		"prompt_it": "Trova 5, 9 e 11. In qualsiasi ordine!",
		"mechanic": "find_numbers",
		"numbers": [5, 9, 11],
		"pool": [5, 9, 11, 6, 10],
	},
	{
		"id": 117, "zone": 2, "title": "Up to Twenty",
		"title_it": "Fino a venti",
		"npc": "Baby Dracula",
		"prompt_en": "Find 14, 17 and 20. Any order!",
		"prompt_it": "Trova 14, 17 e 20. In qualsiasi ordine!",
		"mechanic": "find_numbers",
		"numbers": [14, 17, 20],
		"pool": [14, 17, 20, 4, 7],
	},
	{
		"id": 118, "zone": 2, "title": "Three in a Row",
		"title_it": "Tre di fila",
		"npc": "Baby Dracula",
		"prompt_en": "Find 21, 22 and 24. Any order!",
		"prompt_it": "Trova 21, 22 e 24. In qualsiasi ordine!",
		"mechanic": "find_numbers",
		# 21 / 22 / 24 are near-identical shapes, and 12 (the mirror of 21) is on
		# the board: this is the mission where a child who guesses from the first
		# digit has to look twice.
		"numbers": [21, 22, 24],
		"pool": [21, 22, 24, 12, 26],
	},
	{
		"id": 119, "zone": 2, "title": "Across the Teens",
		"title_it": "Tra i numeri da 13 a 19",
		"npc": "Baby Dracula",
		"prompt_en": "Find 15, 18 and 19. Any order!",
		"prompt_it": "Trova 15, 18 e 19. In qualsiasi ordine!",
		"mechanic": "find_numbers",
		"numbers": [15, 18, 19],
		"pool": [15, 18, 19, 8, 9],
	},
	{
		"id": 120, "zone": 2, "title": "The Big Review",
		"title_it": "Il grande ripasso",
		"npc": "Baby Dracula",
		"prompt_en": "Find 6, 12, 18 and 24. Any order!",
		"prompt_it": "Trova 6, 12, 18 e 24. In qualsiasi ordine!",
		"mechanic": "find_numbers",
		# The board keeps the doubles theme from mission 118 while the wanted set
		# is a sequence of steps of six: a child who notices the pattern has
		# genuinely understood the numbers rather than matched the digits.
		"numbers": [6, 12, 18, 24],
		"pool": [6, 12, 18, 24, 9, 21],
	},

	# ---------------- Spelling: hear it, write it (21-30) ----------------
	#
	# The child hears the word and then its letters, and rebuilds the word by
	# tapping the letters in order. These are the bonus set's answer to "the
	# mirror is not enough": the mirror asks the child to *say* a word they have
	# just heard, which can be done by echo without reading anything. Spelling
	# the same word is the first task in the game that cannot be done without
	# knowing which letter is which.
	#
	# `word` is written lower case because it is a spoken word; the panel raises
	# it. `bank` is the set of letters offered, and it is written out by hand for
	# every mission rather than generated from the word plus random filler:
	# which wrong letters sit next to a word *is* the exercise. A `D` next to
	# `bat` tests the mirror-image confusion seven-year-olds actually have; an
	# `X` next to it tests nothing. For the same reason the bank repeats a letter
	# where the word does (`apple` needs two `P`s, `broom` two `O`s): a child who
	# has used the single `P` of a thinner bank would be stuck on a word they
	# spelled correctly in their head.
	#
	# The bank is shuffled per mission by `SpellingPanel` (seeded by the id), so
	# the order below is the *design* order and never the order on screen.
	#
	# All ten live in the dungeon with Echo: this is the "pronunciation" zone of
	# the story (missions 33-36 are the Magic Mirror), and the exercise is the
	# next rung of exactly that ladder.
	{
		"id": 121, "zone": 5, "title": "Spell: Cat",
		"title_it": "Scrivi: cat",
		"npc": "Echo the Ghost",
		"prompt_en": "Listen, then spell the word!",
		"prompt_it": "Ascolta, poi scrivi la parola!",
		"mechanic": "spell",
		"word": "cat",
		# The shortest word in the set, offered with the two vowels a child most
		# often reaches for first. Three letters is one look at the word and one
		# at the bank: the entry point of the whole group.
		"bank": ["C", "A", "T", "E", "S", "O"],
	},
	{
		"id": 122, "zone": 5, "title": "Spell: Bat",
		"title_it": "Scrivi: bat",
		"npc": "Echo the Ghost",
		"prompt_en": "Listen, then spell the word!",
		"prompt_it": "Ascolta, poi scrivi la parola!",
		"mechanic": "spell",
		"word": "bat",
		# `B` and `D` side by side is the classic reversal, and both are in the
		# bank on purpose: a child who taps `D` for `bat` has made a real reading
		# error and should be corrected, not merely stopped.
		"bank": ["B", "A", "T", "D", "E", "S"],
	},
	{
		"id": 123, "zone": 5, "title": "Spell: Hat",
		"title_it": "Scrivi: hat",
		"npc": "Echo the Ghost",
		"prompt_en": "Listen, then spell the word!",
		"prompt_it": "Ascolta, poi scrivi la parola!",
		"mechanic": "spell",
		"word": "hat",
		# The `H` is the lesson here: it is silent in Italian, so it is the letter
		# an Italian class drops when writing. `R` sits next to it because `hrat`
		# is the shape a hurried hand produces.
		"bank": ["H", "A", "T", "R", "E", "S"],
	},
	{
		"id": 124, "zone": 5, "title": "Spell: Star",
		"title_it": "Scrivi: star",
		"npc": "Echo the Ghost",
		"prompt_en": "Listen, then spell the word!",
		"prompt_it": "Ascolta, poi scrivi la parola!",
		"mechanic": "spell",
		"word": "star",
		"bank": ["S", "T", "A", "R", "E", "O", "L"],
	},
	{
		"id": 125, "zone": 5, "title": "Spell: Ghost",
		"title_it": "Scrivi: ghost",
		"npc": "Echo the Ghost",
		"prompt_en": "Listen, then spell the word!",
		"prompt_it": "Ascolta, poi scrivi la parola!",
		"mechanic": "spell",
		"word": "ghost",
		# Five letters, with the `H` again after the `G` and an `O` that an
		# Italian reader expects to sound like "o" and an English one like "ou".
		"bank": ["G", "H", "O", "S", "T", "A", "E", "R"],
	},
	{
		"id": 126, "zone": 5, "title": "Spell: Apple",
		"title_it": "Scrivi: apple",
		"npc": "Echo the Ghost",
		"prompt_en": "Listen, then spell the word!",
		"prompt_it": "Ascolta, poi scrivi la parola!",
		"mechanic": "spell",
		"word": "apple",
		# The first word in the set with a double letter. Two `P`s in the bank,
		# and the second one only becomes correct after the first has been used:
		# a child who taps the same key twice is told "not this one" by a key
		# that has already retired, which is a lesson about spelling, not a trap.
		"bank": ["A", "P", "P", "L", "E", "O", "S"],
	},
	{
		"id": 127, "zone": 5, "title": "Spell: Broom",
		"title_it": "Scrivi: broom",
		"npc": "Echo the Ghost",
		"prompt_en": "Listen, then spell the word!",
		"prompt_it": "Ascolta, poi scrivi la parola!",
		"mechanic": "spell",
		"word": "broom",
		"bank": ["B", "R", "O", "O", "M", "A", "E", "S"],
	},
	{
		"id": 128, "zone": 5, "title": "Spell: Witch",
		"title_it": "Scrivi: witch",
		"npc": "Echo the Ghost",
		"prompt_en": "Listen, then spell the word!",
		"prompt_it": "Ascolta, poi scrivi la parola!",
		"mechanic": "spell",
		"word": "witch",
		# `W` is the longest letter name in English ("double-u") and the one the
		# class finds funniest; having it lead a word means the child hears it in
		# full at the very start.
		"bank": ["W", "I", "T", "C", "H", "A", "E", "S"],
	},
	{
		"id": 129, "zone": 5, "title": "Spell: Spider",
		"title_it": "Scrivi: spider",
		"npc": "Echo the Ghost",
		"prompt_en": "Listen, then spell the word!",
		"prompt_it": "Ascolta, poi scrivi la parola!",
		"mechanic": "spell",
		"word": "spider",
		# Six letters over two rows of keys. `N` and `O` are the filler pair that
		# makes `spider` and `spinder`/`spoider` both reachable by a wrong tap.
		"bank": ["S", "P", "I", "D", "E", "R", "N", "O", "A"],
	},
	{
		"id": 130, "zone": 5, "title": "Spell: Pumpkin",
		"title_it": "Scrivi: pumpkin",
		"npc": "Echo the Ghost",
		"prompt_en": "Listen, then spell the word!",
		"prompt_it": "Ascolta, poi scrivi la parola!",
		"mechanic": "spell",
		"word": "pumpkin",
		# The longest word the game asks anyone to write, and the only one with
		# two different doubled consonants to keep apart (`P` ... `K`). Ten keys
		# is exactly two rows of five: the bank is as wide as the panel allows.
		"bank": ["P", "U", "M", "P", "K", "I", "N", "A", "E", "S"],
	},

	# ---------------- Meanings: what does that word mean? (31-40) ----------------
	#
	# The mirror image of every quiz in the story. There, the question names an
	# English word and the child finds the picture. Here the question names the
	# *meaning* — in Italian, the language the class thinks in — and the child
	# finds the English word. That is the direction a bilingual teacher actually
	# uses when checking comprehension, and it is the one direction the story
	# never tests: a child can answer "Which one is GREEN?" for a whole year by
	# looking at the colours and never once retrieve the word themselves.
	#
	# Every option is marked `show_label: true`, which `QuizManager._make_card()`
	# honours ahead of the hint policy: at level 3 the word under a picture is
	# normally withdrawn, but here the word *is* the answer, so three bare
	# pictures would leave nothing to choose between. All three cards in a
	# question also share the same icon and colour, for the same reason: a green
	# square among red ones would answer the question before it was read.
	#
	# The Italian word is inside the English sentence ("Which word means
	# “rosso”?") because that is how the question is asked in class. Being a
	# word the English voice has never seen, it is pronounced by English rules
	# -- `rosso` comes out roughly "ross-oh" -- which is close enough to be
	# recognised, always *written* on screen above the cards, and read properly
	# by the magnifying glass, which speaks the Italian line.
	{
		"id": 131, "zone": 1, "title": "Meanings: Please",
		"title_it": "Significati: per favore",
		"npc": "Mr. Barnaby",
		"prompt_en": "Which word means “per favore”?",
		"prompt_it": "Quale parola significa «per favore»?",
		"mechanic": "quiz",
		"questions": [
			{
				"en": "Which word means “per favore”?",
				"it": "Quale parola significa «per favore»?",
				"options": [
					{"label": "Please", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Thank you", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Good night", "icon": "star", "color": "gold", "show_label": true},
				],
			},
			{
				"en": "Which word means “grazie”?",
				"it": "Quale parola significa «grazie»?",
				"options": [
					{"label": "Thank you", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Hello", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Please", "icon": "star", "color": "gold", "show_label": true},
				],
			},
		],
	},
	{
		"id": 132, "zone": 1, "title": "Meanings: Red",
		"title_it": "Significati: rosso",
		"npc": "Mr. Barnaby",
		"prompt_en": "Which word means “rosso”?",
		"prompt_it": "Quale parola significa «rosso»?",
		"mechanic": "quiz",
		"questions": [
			{
				"en": "Which word means “rosso”?",
				"it": "Quale parola significa «rosso»?",
				"options": [
					{"label": "Red", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Blue", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Green", "icon": "star", "color": "gold", "show_label": true},
				],
			},
			{
				"en": "Which word means “giallo”?",
				"it": "Quale parola significa «giallo»?",
				"options": [
					{"label": "Yellow", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Purple", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Black", "icon": "star", "color": "gold", "show_label": true},
				],
			},
		],
	},
	{
		"id": 133, "zone": 1, "title": "Meanings: Bat & Cat",
		"title_it": "Significati: pipistrello e gatto",
		"npc": "Mr. Barnaby",
		"prompt_en": "Which word means “pipistrello”?",
		"prompt_it": "Quale parola significa «pipistrello»?",
		"mechanic": "quiz",
		"questions": [
			{
				"en": "Which word means “pipistrello”?",
				"it": "Quale parola significa «pipistrello»?",
				"options": [
					{"label": "Bat", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Cat", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Hat", "icon": "star", "color": "gold", "show_label": true},
				],
			},
			{
				"en": "Which word means “gatto”?",
				"it": "Quale parola significa «gatto»?",
				"options": [
					{"label": "Cat", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Bat", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Frog", "icon": "star", "color": "gold", "show_label": true},
				],
			},
		],
	},
	{
		"id": 134, "zone": 1, "title": "Meanings: Animals",
		"title_it": "Significati: animali",
		"npc": "Mr. Barnaby",
		"prompt_en": "Which word means “ragno”?",
		"prompt_it": "Quale parola significa «ragno»?",
		"mechanic": "quiz",
		"questions": [
			{
				"en": "Which word means “ragno”?",
				"it": "Quale parola significa «ragno»?",
				"options": [
					{"label": "Spider", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Snake", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Owl", "icon": "star", "color": "gold", "show_label": true},
				],
			},
			{
				"en": "Which word means “gufo”?",
				"it": "Quale parola significa «gufo»?",
				"options": [
					{"label": "Owl", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Frog", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Spider", "icon": "star", "color": "gold", "show_label": true},
				],
			},
		],
	},
	{
		"id": 135, "zone": 1, "title": "Meanings: Big & Small",
		"title_it": "Significati: grande e piccolo",
		"npc": "Mr. Barnaby",
		"prompt_en": "Which word means “grande”?",
		"prompt_it": "Quale parola significa «grande»?",
		"mechanic": "quiz",
		"questions": [
			{
				"en": "Which word means “grande”?",
				"it": "Quale parola significa «grande»?",
				"options": [
					{"label": "Big", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Small", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Long", "icon": "star", "color": "gold", "show_label": true},
				],
			},
			{
				"en": "Which word means “triste”?",
				"it": "Quale parola significa «triste»?",
				"options": [
					{"label": "Sad", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Happy", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Funny", "icon": "star", "color": "gold", "show_label": true},
				],
			},
		],
	},
	{
		"id": 136, "zone": 1, "title": "Meanings: Body",
		"title_it": "Significati: il corpo",
		"npc": "Mr. Barnaby",
		"prompt_en": "Which word means “testa”?",
		"prompt_it": "Quale parola significa «testa»?",
		"mechanic": "quiz",
		"questions": [
			{
				"en": "Which word means “testa”?",
				"it": "Quale parola significa «testa»?",
				"options": [
					{"label": "Head", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Hand", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Foot", "icon": "star", "color": "gold", "show_label": true},
				],
			},
			{
				"en": "Which word means “mano”?",
				"it": "Quale parola significa «mano»?",
				"options": [
					{"label": "Hand", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Nose", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Ear", "icon": "star", "color": "gold", "show_label": true},
				],
			},
		],
	},
	{
		"id": 137, "zone": 1, "title": "Meanings: Shapes",
		"title_it": "Significati: le forme",
		"npc": "Mr. Barnaby",
		"prompt_en": "Which word means “quadrato”?",
		"prompt_it": "Quale parola significa «quadrato»?",
		"mechanic": "quiz",
		"questions": [
			{
				"en": "Which word means “quadrato”?",
				"it": "Quale parola significa «quadrato»?",
				"options": [
					{"label": "Square", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Circle", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Triangle", "icon": "star", "color": "gold", "show_label": true},
				],
			},
			{
				"en": "Which word means “stella”?",
				"it": "Quale parola significa «stella»?",
				"options": [
					{"label": "Star", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Circle", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Square", "icon": "star", "color": "gold", "show_label": true},
				],
			},
		],
	},
	{
		"id": 138, "zone": 1, "title": "Meanings: Things",
		"title_it": "Significati: le cose",
		"npc": "Mr. Barnaby",
		"prompt_en": "Which word means “cappello”?",
		"prompt_it": "Quale parola significa «cappello»?",
		"mechanic": "quiz",
		"questions": [
			{
				"en": "Which word means “cappello”?",
				"it": "Quale parola significa «cappello»?",
				"options": [
					{"label": "Hat", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Broom", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Bucket", "icon": "star", "color": "gold", "show_label": true},
				],
			},
			{
				"en": "Which word means “zucca”?",
				"it": "Quale parola significa «zucca»?",
				"options": [
					{"label": "Pumpkin", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Apple", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Lantern", "icon": "star", "color": "gold", "show_label": true},
				],
			},
		],
	},
	{
		"id": 139, "zone": 1, "title": "Meanings: Where",
		"title_it": "Significati: dove",
		"npc": "Mr. Barnaby",
		"prompt_en": "Which word means “sopra”?",
		"prompt_it": "Quale parola significa «sopra»?",
		"mechanic": "quiz",
		"questions": [
			{
				"en": "Which word means “sopra”?",
				"it": "Quale parola significa «sopra»?",
				"options": [
					{"label": "On", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Under", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Behind", "icon": "star", "color": "gold", "show_label": true},
				],
			},
			{
				"en": "Which word means “sotto”?",
				"it": "Quale parola significa «sotto»?",
				"options": [
					{"label": "Under", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "On", "icon": "star", "color": "gold", "show_label": true},
					{"label": "In", "icon": "star", "color": "gold", "show_label": true},
				],
			},
		],
	},
	{
		"id": 140, "zone": 1, "title": "Meanings: The Big Review",
		"title_it": "Significati: il grande ripasso",
		"npc": "Mr. Barnaby",
		"prompt_en": "Which word means “ecco a te”?",
		"prompt_it": "Quale parola significa «ecco a te»?",
		"mechanic": "quiz",
		"questions": [
			{
				# The same sentence mission 5 teaches, asked the other way round.
				# The class has known this phrase since the first zone, and it is
				# a whole sentence rather than a word: the only way to answer is
				# to have understood it, not to have memorised a label.
				"en": "Which word means “ecco a te”?",
				"it": "Quale parola significa «ecco a te»?",
				"options": [
					{"label": "Here you are", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "How are you", "icon": "star", "color": "gold", "show_label": true},
					{"label": "Good night", "icon": "star", "color": "gold", "show_label": true},
				],
			},
			{
				"en": "Which word means “come stai”?",
				"it": "Quale parola significa «come stai»?",
				"options": [
					{"label": "How are you", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "I am fine", "icon": "star", "color": "gold", "show_label": true},
					{"label": "What is your name", "icon": "star", "color": "gold", "show_label": true},
				],
			},
			{
				"en": "Which word means “andiamo”?",
				"it": "Quale parola significa «andiamo»?",
				"options": [
					{"label": "Let's go", "icon": "star", "color": "gold", "show_label": true, "correct": true},
					{"label": "Well done", "icon": "star", "color": "gold", "show_label": true},
					{"label": "I am fine", "icon": "star", "color": "gold", "show_label": true},
				],
			},
		],
	},
]


## The forty bonus missions, in play order.
##
## Built fresh on every call rather than returned as the const list, because each
## entry needs its `extra_index` stamped on it and a `const` container is
## read-only in Godot 4. The cost is twenty dictionary copies, once per mission.
static func extra_missions() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for i in EXTRA_CHALLENGES.size():
		var entry: Dictionary = (EXTRA_CHALLENGES[i] as Dictionary).duplicate(true)
		entry["extra_index"] = i + 1
		list.append(entry)
	return list


## The bonus mission at `index` (1-based). Empty when the index is out of range,
## so a corrupt save cannot produce a mission with no data.
static func extra_mission(index: int) -> Dictionary:
	var list := extra_missions()
	if list.is_empty() or index < 1 or index > list.size():
		return {}
	return list[index - 1]


## Looks up the Italian translation of a word; falls back to the word itself.
static func translate(word: String) -> String:
	var key := word.to_lower().strip_edges()
	# Try the whole sentence first, then word by word.
	if VOCAB.has(key):
		return String(VOCAB[key])
	return ""


## A word as it is written inside a spoken line: `"pumpkin"` -> `"Pumpkin"`.
##
## Only the first letter is raised. `String.capitalize()` would lower-case the
## rest of the word, which is right for `"PUMPKIN"` but wrong for the two-word
## entries the vocabulary also holds ("next to", "here you are"), where it would
## produce "Next to" anyway -- and wrong in a way that is invisible until one of
## those is used in an exercise.
static func spelling_word(word: String) -> String:
	var lower := word.to_lower().strip_edges()
	if lower.is_empty():
		return ""
	return lower.substr(0, 1).to_upper() + lower.substr(1)


## The sentence a spelling challenge says: the word, then its letters.
##
## `"cat"` -> `"Cat. C, A, T."` Measured with the shipped `cori` voice:
##
##     "Cat. C, A, T."  ->  kˈat. sˈiː, ˈeɪ, tˈiː.
##
## i.e. the letters come out as letter *names*, which is the lesson, and the
## word comes out as a word. The obvious alternative -- spelling the letters
## into the raw text, `"C-A-T"` -- is read as one mangled token (`"c-a-t"` as a
## single word), and a hyphenated form is also what the child would then see.
##
## Assembled here rather than in `SpellingPanel` because
## `tools/speech_corpus.gd` has to record *exactly* this sentence: a line built
## by two different rules is a line the pack does not have, and it would fall
## back to the system voice for the central sentence of ten missions.
static func spelling_sentence(word: String) -> String:
	var upper := word.to_upper().strip_edges()
	if upper.is_empty():
		return ""
	var letters := ""
	for i in upper.length():
		if i > 0:
			letters += ", "
		letters += upper.substr(i, 1)
	# Built with a loop instead of `String.join()`: join() wants a
	# `PackedStringArray` and this is a plain string walk (see the same note in
	# `FindNumbersMission._spoken_list()`).
	return "%s. %s." % [spelling_word(word), letters]


## The line the panel says when the word has been spelled out in full:
## `"cat"` -> `"Cat. Well done!"`.
static func spelling_answer(word: String) -> String:
	var shown := spelling_word(word)
	if shown.is_empty():
		return "Well done!"
	return "%s. Well done!" % shown


## Zone dictionary for a zone id (1-6).
static func zone_info(zone_id: int) -> Dictionary:
	for z in ZONES:
		if int(z["id"]) == zone_id:
			return z
	return ZONES[0]


## Mission dictionary by id (1-40).
static func mission(mission_id: int) -> Dictionary:
	for m in missions():
		if int(m["id"]) == mission_id:
			return m
	return {}
