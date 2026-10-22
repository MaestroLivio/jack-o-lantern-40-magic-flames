# Jack-o'-Lantern: The 40 Magic Flames

A gentle 3D educational Halloween adventure for **7-year-olds** (Seconda Primaria, English pre-A1/A1), built in **Godot 4**.

Jack is a clumsy pumpkin-boy. A gust of wind scattered the **40 Magic Flames of Halloween** across five biomes. To light his lantern for the Grand Party, Jack must recover them by completing playful language tasks. There is **no game over, no timer, no lives** — only gentle repetition and a lot of small victories.

---

## Building the release (Windows + macOS)

```bash
tools/build_release.sh 1.0.2          # both platforms
tools/build_release.sh 1.0.2 macos    # macOS only
tools/build_release.sh 1.0.2 windows  # Windows only
```

Output lands in `dist/`:

| Artefact | What it is |
|---|---|
| `JackOLantern-Setup-1.0.2.exe` | Windows installer (NSIS, per-user, no admin) |
| `windows/JackOLantern.exe` | Portable Windows build |
| `JackOLantern-1.0.2.dmg` | macOS disk image (drag to Applications) |
| `macos/JackOLantern.zip` | The `.app` on its own |
| `README.txt` | Teacher instructions, embedded in both installers |

**Bumping the version:** the script's `version` argument reaches the installer
name, the NSIS metadata and `README.txt`, but *not* the exported binary
metadata — Godot reads that from `export_presets.cfg`. So a release is two
edits: pass the new number to the script, then update
`application/file_version` + `application/product_version` (Windows) and
`application/short_version` + `application/version` (macOS) in
[`export_presets.cfg`](file:///Users/livioluppino/Downloads/Halloween%20game/export_presets.cfg).
Skipping the second leaves a 1.0.2 installer wrapping an exe whose Properties
still say 1.0.0.0 — check with:

```bash
# macOS: must print the new version twice
ditto -x -k dist/macos/JackOLantern.zip /tmp/v \
  && plutil -p "/tmp/v/Jack o Lantern - The 40 Magic Flames.app/Contents/Info.plist" \
     | grep -E "CFBundleShortVersionString|CFBundleVersion"

# Windows: the version block in the PE resources, read straight from the exe
python3 -c "d=open('dist/windows/JackOLantern.exe','rb').read(); \
print('ok' if '1.0.2.0'.encode('utf-16-le') in d else 'STALE VERSION')"
```

The macOS build is **universal** (`x86_64` + `arm64`) and **ad-hoc signed**,
because there is no Apple Developer certificate to sign with. Gatekeeper
therefore warns on a machine that has never seen the app; `dist/README.txt`
explains the one-time approval. With a real certificate, set
`codesign/identity` and `notarization/*` in the macOS preset and the warning
disappears.

Two settings exist *only* to make the universal export possible and are
documented in `project.godot`: `import_etc2_astc` (Apple Silicon) and
`import_s3tc_bptc` (Intel). Godot refuses a universal build unless both are on.

Helper scripts, run by hand only when their input changes:

```bash
# Regenerate the macOS .icns from icon.svg (needed only if the artwork changes)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/make_app_icon.gd
iconutil -c icns build/icon/jack.iconset -o build/icon/jack.icns

# Regenerate the DMG window background
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/make_dmg_background.gd
```

---

## Running the game

```bash
# from this folder
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Or open the folder with the Godot editor and press **F5**.

The game always launches **windowed and freely resizable** (`1280×720` by default).
Everything scales cleanly because of this configuration:

| Project Setting | Value | Why |
|---|---|---|
| `display/window/size/viewport_width` | `1280` | Base design resolution |
| `display/window/size/viewport_height` | `720` | Base design resolution |
| `display/window/size/resizable` | `true` | The child (or teacher) can resize freely |
| `display/window/size/mode` | `0` (Windowed) | Never full-screens by surprise |
| `display/window/stretch/mode` | `canvas_items` | UI scales with the window instead of clipping |
| `display/window/stretch/aspect` | `expand` | **No distortion**: extra space is revealed, never stretched |

With `canvas_items` + `expand`, the 3D viewport keeps a correct aspect ratio (the camera's `keep_aspect` stays `KEEP_HEIGHT`), and UI anchored to the screen edges stays on the screen edges at any size.

---

## Controls

| Input | Action |
|---|---|
| `W A S D` / arrows | Walk |
| `E` or **left click** on a prop | Interact / pick up / talk to the NPC |
| `H` or the **purple magnifier** button | Magic Italian translation |
| `Esc` | Pause & settings |
| Right-drag | Orbit the camera |
| Mouse wheel | Zoom |
| `Q` / `E` while holding right-drag | Keyboard orbit fallback |

`E` is also the camera-orbit key only while right-drag is held, so on a laptop trackpad use `Q`/`R`/`F` instead — see `CameraRig.gd`.

---

## Project structure

```
project.godot                    Window/stretch config, input map, autoloads
scenes/Main.tscn                 Single entry scene (root Node + Main.gd)
icon.svg                         Game icon

scripts/
  Main.gd                        Screen flow: title → zone intro → playing → ending
  autoload/
    GameData.gd                  ALL content: 6 zones, 40 missions, EN↔IT vocabulary
    QuestManager.gd              Event bus + progression + save/load
    AudioFx.gd                   Voice pack playback + runtime-synthesised sound effects
    Music.gd                     Background music: per-zone tracks, crossfade, ducking
  core/
    PropFactory.gd               Builds every 3D prop from primitive meshes
  resources/
    VocabWord.gd                 Custom Resource: english, italian, icon, audio
  player/
    Jack.gd                      CharacterBody3D player + InteractionArea
  world/
    WorldBuilder.gd              Environment, lighting, decor per zone, grid room
    Level.gd                     Mission lifecycle, flame celebration, fireworks
    CameraRig.gd                 Smoothed third-person camera
    LearningProp.gd              Pickable 3D learning object
    NpcCharacter.gd              Barnaby, Dracula, Wendy, Franky, Echo + models
  missions/
    MissionController.gd         Base class + spawn/scatter/solve helpers
    FindMission.gd               "Find the X"        (11 missions)
    SequenceMission.gd           "Step in order"     (4 missions)
    CountMission.gd              "Give exactly N"    (4 missions)
    QuizMission.gd               "Multiple choice"   (10 missions)
    RepeatMission.gd             "Listen & repeat"   (5 missions)
    TprMission.gd                "Franky says"       (1 mission)
    GridTrapRoom.gd              "10×10 grid"        (3 missions)
    CoordsMission.gd             "Grid, no markers"  (10 bonus challenges)
    FindNumbersMission.gd        "Find 3, 7 and 12"  (10 bonus challenges)
  ui/
    UiKit.gd                     Theme, widget builders, procedural icons
    Hud.gd                       Always-on overlay
    DialogueBox.gd               Bilingual dialogue
    QuizManager.gd               Multiple-choice panel
    RepeatPanel.gd               Magic Mirror (listen & repeat)
    CountingPanel.gd             "Give exactly N" panel
    TitleScreen.gd / ZoneIntroCard.gd / PauseMenu.gd / EndingScreen.gd
    ChallengeHub.gd              The list of the 20 bonus challenges
```

---

## The nine mission mechanics

Every one of the 40 missions is data — a dictionary in `GameData.missions()` — and is run by one of seven controllers. Adding a 41st mission means adding one dictionary, not writing code.

| Mechanic | Missions | What the child does |
|---|---|---|
| `find` | 1, 2, 3, 8, 11, 12, 17–22 | Walk to a prop and tap it. Distractors wobble and teach the contrast. |
| `sequence` | 6, 13, 14, 15 | Step on pads in the right order (colours, then 1–20). |
| `count` | 9, 10, 23, 24 | Collect props, then hand in *exactly* N. Overshooting drops one back. |
| `quiz` | 5, 7, 16, 25–31, 40 | Tap one of three picture cards. |
| `repeat` | 4, 33–36 | Listen, then press the Magic Microphone. |
| `tpr` | 32 | Tap Jack's head / shoulders / knees / toes in order. |
| `grid` | 37, 38, 39 | Walk a 10×10 board to coordinates A1–J10. |
| `coords` | **bonus 1–10** | The same board with the target tiles **not lit**: read the coordinate and walk it. Traps still bounce back, obstacles block the straight line. |
| `find_numbers` | **bonus 11–20** | Find a *set* of numbers ("3, 7 and 12") in any order, on a board that also carries wrong digits. |

---

## The 20 bonus challenges

Reachable from the title screen (**CHALLENGES**) and from the ending screen, because
a class may never go back to the title. They are **optional**: no flame, no chapter,
no effect on the story or its ending. Each one returns to the list when solved,
which is also the only way out — nobody is walked into the twentieth.

They live in `GameData.EXTRA_CHALLENGES` with ids **101–120**, deliberately outside
the 1–40 story id range so no story code can mistake one for a mission. Progress is
saved separately (`extra_completed`) and survives *PLAY AGAIN*, because replaying
the story should not punish a class for the puzzles it has already solved.

---

## Graphics: generated geometry only

There are no imported 3D models or textures. Everything is built from primitives in
`PropFactory` and `WorldBuilder`, which is what keeps the geometry a few hundred
kilobytes and lets every prop be re-coloured for a vocabulary lesson. (The two things
that *are* shipped as files are the nine music tracks, 2 MB, and the voice pack,
13 MB — see the Voice section.)

What the graphics pass added:

- **Ground.** The old 9 m checkerboard read as two floors rather than one. It is now
  4 m tiles, 8 % darker, drawn as a single `MultiMeshInstance3D` — 181 tiles in **one
  draw call** instead of 181 nodes.
- **Air.** A `GPUParticles3D` of slow rising motes per zone, tinted from the zone's
  own sky palette, so the fog has something to be *in*.
- **Depth.** A ring of paper lanterns at 2.4 m inside the tree line, with four real
  lights rather than twelve (twelve would flatten the moon).
- **The party zone.** Balloons rising on their own phases, a warm fill light, and
  120 motes instead of 84: the sky visibly changes on the last mission.
- **Eight props rebuilt** from one-primitive silhouettes into recognisable shapes —
  star, candy, barrel, cauldron, candle, lantern, tombstone, tree.

`tools/gfx_verify.gd` asserts all of the above against the live scene tree, so a
prop that silently collapses back to a cube fails a test rather than a lesson.

---

## Pedagogical design

**Error-free learning.** Nothing can end the game. A wrong tap:
- plays a soft two-note "boop" (never a buzzer),
- wobbles the prop instead of deleting anything,
- says *"Not this one. Try again!"*,
- and quietly highlights the correct answer.

**Scaffolding.** Missions 1–2 teach colours before mission 3 asks for four; stars are counted 1–10 before 11–15 before 16–20; single adjectives (17–20) come before combined ones (21–22).

**Repetition with reward.** Every correct answer is spoken aloud. The word the child just tapped is pronounced again — this is the whole lesson, repeated for free.

**Two languages, English first.** Every prompt is written in short English and spoken by the system voice. The **Magic Italian Magnifying Glass** (top-right, or `H`) reveals the Italian translation on demand, so translation is a tool the child chooses — not a crutch that appears automatically.

**TPR.** Mission 32 ("Franky Says") is Total Physical Response translated to a touchscreen: head, shoulders, knees, toes.

**Accessibility.**
- High-contrast palette, thick borders, 28–40 px type.
- **Easy-read letters** toggle in the pause menu switches the whole UI to OpenDyslexic / Atkinson Hyperlegible (SystemFont fallback stack, so it works without downloading a font).
- Every key word has a **procedurally drawn icon** — text is never the only channel.
- Slow pacing: no timers anywhere, ×0.9 speech rate, 0.85 s reveal on correct answers.

---

## Settings (pause menu → SETTINGS)

Three things a teacher can change mid-lesson, all saved immediately:

| Setting | Values | Notes |
|---|---|---|
| **Difficulty** | LOTS OF HELP · SOME HELP · **ALL BY MYSELF** (default) | Removes visual hints, never the spoken instruction or the way out. Defaults to 3 for a **new** game; an existing save keeps the level it had. |
| **Music / Effects** | OFF · SOFT · MEDIUM · LOUD · MAX, separately | Five named steps rather than a slider: a continuous slider cannot be centred with a seven-year-old's hand. |
| **VIEW** | AUTO (default) · ALWAYS · NEVER | Whether zooming into the character switches to first person. Applies to the mission already running, so the child sees the change at once. |
| **Hide the words after a while** | ON (default) · OFF | The task bar folds into a small **TASK** tab and the dialogue box into a **SPEECH** pill after a few seconds, so the world is visible while the child plays. Nothing is lost: one tap on the tab brings the sentence straight back, and folding a dialogue never answers it — only **OK** advances the story. Turn this off to keep both panels on screen all the time. |

**Panel minimising.** Every instruction panel can also be folded by hand at any
moment, whatever this setting says: the task bar has a **–** button on its right,
the dialogue box has one next to **OK**, and each leaves a small tab in the same
corner it came from. The counting bag (**MY BAG**) folds into a **BAG n/N** tab
the same way. A folded panel is never gone, only out of the way.

**Controls.** Mouse (drag to look around, wheel to zoom), keyboard, or **gamepad** —
including in every menu: the A button presses whatever button is focused, so no
screen is unreachable with a controller. The keyboard bindings can be rebound on the
controls page; the gamepad buttons stay put, and the page shows both (`E · Button A`)
so the second route is always visible.

---

## The 40 missions

### Zone 1 — The Whispering Pumpkin Patch (colours & greetings)
1. Primary Pumpkins (red, blue, yellow) · 2. Secondary Pumpkins (green, purple, orange)
3. Dark & Light (black, white, pink, brown bats) · 4. Hello & Goodbye
5. Please & Thank You · 6. Colour Sequence (red → green → blue)
7. The Painted Apples · 8. Bat Hide & Seek 1 (*the green bat **ON** the tree*)

### Zone 2 — Dracula's Cozy Castle (numbers 1–20 & prepositions)
9. Bridge Toll 1 (5 orange candies) · 10. Bridge Toll 2 (9 black candies)
11. Bat Hide & Seek 2 (***UNDER** the bench*) · 12. Bat Hide & Seek 3 (***IN** the barrel*)
13. Counting Stars 1–10 · 14. Counting Stars 11–15 · 15. Counting Stars 16–20
16. The Number Door ("Twelve" → 12)

### Zone 3 — The Wacky Witch's Bog (adjectives & animals)
17. BIG ghost · 18. SMALL spider · 19. FAST cat · 20. HAPPY pumpkin
21. BIG BLACK SPIDER · 22. SMALL WHITE CAT
23. Cauldron Soup 1 (1 bat + 1 hat + 1 broom) · 24. Cauldron Soup 2 (2 red apples + 3 small spiders)

### Zone 4 — Franky's Laboratory (body parts & shapes)
25. GREEN SQUARE eye · 26. BLUE CIRCLE eye · 27. RED TRIANGLE nose · 28. PURPLE STAR mouth
29. LONG arms · 30. BIG feet · 31. How many fingers? (10) · 32. Franky Says (TPR)

### Zone 5 — The Haunted Dungeon (pronunciation, coordinates, directions)
33. "Hello!" · 34. "I am a ghost." · 35. "I have two eyes." · 36. "The pumpkin is orange."
37. Walk to A1, then B3 · 38. Walk to D5, avoid the trap at C5 · 39. 2 squares FORWARD, 1 RIGHT

### Zone 6 — The Grand Halloween Party
40. Ten-question review quiz → all 40 flames light the lantern → **fireworks**.

---

## Technical notes

### Custom Resource — `VocabWord.gd`
```gdscript
@export_multiline var english_text: String
@export_multiline var italian_translation: String
@export var icon: Texture2D
@export var audio_pronunciation: AudioStream
@export_range(0.5, 1.5) var speech_rate: float
```
`speak()` plays a recorded clip when the `VocabWord` carries one, otherwise it asks `AudioFx` —
which plays from the shipped voice pack and only then falls back to text-to-speech. No
`VocabWord` in the project ships a clip today: the pronunciation comes from the voice pack,
which is keyed by the word itself, so there is no second copy of the audio to keep in sync.

### Background music — `Music.gd`
Nine looping Ogg Vorbis tracks in `assets/music/`: `title`, one per zone (`zone1_patch` …
`zone6_party`), `story`, `ending`. The `Music` autoload owns two `AudioStreamPlayer`s on the
`Music` bus so a track can crossfade into the next one, and it ignores a request for the track
that is already playing — so re-entering a zone, or opening a quiz, never restarts the loop.

Four buses are declared in `default_bus_layout.tres`: `Master`, `Music`, `SFX`, `Voice`. The
Sound page in the pause menu sets the `Music` and `SFX` levels; `Voice` (the recorded voice pack,
and the text-to-speech fallback for a line nobody recorded) deliberately has no user control,
because turning the voice down turns
the lesson off. The pause menu's `Sound` switch still mutes `Master`, so one switch silences
everything at once.

The music steps back (`-7 dB`) while a line is spoken and (`-6 dB`) while a story page is open,
which is what lets a teacher read a chapter aloud over it. `duck_for_speech()` takes the clip's
own length when the voice pack played it — measured, not guessed — and only estimates from the
word count on the text-to-speech fallback, where the game cannot know when the OS engine stops.
The two paces differ (`~2.2` words/s recorded against `~2.6` for the system voice), so a single
estimate would under-duck every recorded line by about 18% and let the last syllable fight the
music.

### Voice — `AudioFx.gd`
The game does not borrow a voice from the computer it is installed on. Every sentence it can
say was recorded once, on a build machine, with a neural voice, and ships in `assets/voice/`
as an Ogg Vorbis clip plus an index. `AudioFx.speak()` looks the sentence up, plays it, and
only falls back to the operating system's text-to-speech for a line nobody recorded.

That ordering is the whole fix. Borrowing the OS voice was a gamble that went wrong on a
school machine: Windows handed back an old 16 kHz SAPI4 voice, and a macOS install with no
British voice read English in Italian — which for a child is worse than silence, because it
teaches the wrong sounds. `en_GB-cori-high` is now the same voice on every install, has
zero start-up latency, and needs no binary on the target machine.

**Why a pack and not a synthesiser.** Shipping Piper itself would have meant 60–113 MB of
model (against 3 MB of audio), 0.78–0.96 s to load it at start-up and ~0.96 s per sentence
through the CLI, a GPL-3.0 binary in the installer, and a broken macOS release to work
around — its tarball is missing `libespeak-ng` and `libpiper_phonemize`, so it dies on
`dyld`. Recording the corpus once has none of those problems. The whole pack regenerates
in about four minutes, so it is a build step like `tools/make_music.py`.

**The index is keyed by the sentence, not by an id.** `speak()` is called from forty-odd
places and most of them assemble the text at runtime (`"Find %s first!" % word`,
`"A magic flame! %d"`, `"Not this one. Look for %s."`). A key per string would mean editing
every call site and getting each of them right, and the first one missed would silently go
back to the machine's voice. A lookup on the normalised sentence covers all of them —
including the call sites a future edit adds. Both sides normalise identically (`AudioFx.
normalize_speech()` and `normalize()` in `tools/make_voice_pack.py`): whitespace collapsed
and curly quotes folded, because a key that differs by one apostrophe is a sentence that
falls back to the system voice.

Measured: **880 sentences** (714 English, 166 Italian), ~32 minutes of audio, **13.0 MB**
at Vorbis `-q 3`. That is the corpus *after* removing the sentences that no code path
speaks: an earlier build recorded 1017 entries because the collector synthesised
`"Go to C4."` for all hundred cells and `"Magic Flame! %d / 40"` for all forty flames —
both guesses about a template nothing builds (the real `Go to …` prompts are literals in
`GameData` and the flame counter is a *toast* label nothing speaks). Those 137 clips cost
4 MB of installer for audio no code could play. Anything the pack cannot say still gets
spoken by the OS voice — a teacher's freshly edited line, a mission added after the last
build — so the game never goes silent; the miss is recorded (`voice_pack_misses`) for
`tools/voice_pack_check.gd` to report.

```bash
# once, in a throwaway venv (the models are 113 MB and are NOT in the repo)
python3 -m venv /tmp/piperprobe/venv && /tmp/piperprobe/venv/bin/pip install piper-tts
# download en_GB-cori-high and it_IT-serena-high -- URLs and licences in tools/VOICE_MODELS.md

/tmp/piperprobe/venv/bin/python tools/make_voice_pack.py \
    --en /tmp/piperprobe/en_GB-cori-high.onnx \
    --it /tmp/piperprobe/it_IT-serena-high.onnx --force

godot --headless --path . --import                          # so ResourceLoader finds the clips
godot --headless --path . --script tools/voice_pack_check.gd # must print "every sentence ... in the pack"
```

`tools/collect_speech.gd` is what makes the corpus complete: it runs inside the engine and
walks `GameData`/`Story`, so it sees the generated families a regex over `.gd` files cannot —
the 100 grid coordinates, the numerals 1–40, `"Green. Well done!"` for every answer label,
every substring of a numbers prompt (`"3, 7 and 12"`, `"7 and 12"`, `"12"`), and the READ ALL
button's whole-chapter sentence. The walk itself lives in `tools/speech_corpus.gd`, because
`voice_pack_check.gd` has to replay *the same list* — a checker built on a second list would
prove only that two tools agree with each other, not that either matches the game.

`voice_pack_check.gd` replays that list through `speak()` and fails on any line the pack
cannot serve, or on a manifest entry whose clip will not load — the two silent ways the
voice can become inconsistent mid-lesson. It reports both counts (`corpus=880,
manifest=880`) because the two faults are different: a *miss* means nobody recorded a
sentence the game says, whereas an oversized manifest just means the pack still carries
clips for sentences a mission used to say. Only misses and broken clips fail the run.


### Regenerating the music
The tracks are synthesised offline by a script, kept in `tools/` so the files are reproducible
and nobody has to trust an opaque binary. It writes the `.ogg` files themselves — the game only
imports them.

```bash
python3 -m venv /tmp/musenv && /tmp/musenv/bin/pip install numpy scipy
brew install vorbis-tools                    # provides oggenc; this ffmpeg has no libvorbis
/tmp/musenv/bin/python tools/make_music.py   # or: ... --only zone3_bog
```

It prints one line per track: length, peak, RMS, crest factor, loop-seam error, file size. A
seam above ~0.02 is a loop that will tick and should be treated as a failure.

### Player — `Jack.gd`
`CharacterBody3D` with camera-relative `Input.get_vector()` movement, acceleration/friction smoothing, and an `InteractionArea` (`Area3D`, mask = layer 3) that tracks nearby `LeariningProp`s and focuses the nearest one.

**Two owners, one gate.** `can_move` belongs to `Main` (is the game playing at all?), `_ui_blocked` to `Level` (is a quiz or a conversation holding the screen?). Movement, turning, camera drag and the interact key all stop when *either* says so, and `Level._process()` re-evaluates the second one every frame instead of relying on each panel to push it — a quarantine that one panel forgot to release is exactly the bug the class reported ("I'm answering the questions and Jack walks off"). `set_ui_blocked(true)` also releases the focus ring, so the prop Jack was about to pick up stops glowing while a question is open.

### Event bus — `QuestManager.gd`
Autoload singleton. Signals: `mission_started`, `mission_completed`, `flames_changed`, `feedback`, `level_transition_requested`, `all_missions_completed`, `step_changed`, `translation_requested`, `save_state_changed`. Progress is saved to `user://jack_progress.json` and resumes at the first unsolved mission.

### Dialogue — `DialogueBox.gd`
Two labels: English always visible and spoken; Italian hidden until the magnifier is pressed. The level instantiates it (`Level.dialogue`) and opens it whenever Jack presses **E** next to the zone character, so a child can always hear the task again — in English first, Italian on demand.

### Quiz — `QuizManager.gd`
Builds three `TextureButton` cards from `mission["questions"]`, each with a procedurally drawn icon plus a word. Correct → green flash + spoken praise; wrong → wobble + kind correction, quiz stays open.

### Listen & repeat — `RepeatPanel.gd`
`AudioStreamPlayer`-based speech playback with **Replay** and a pulsing **Magic Microphone**. The microphone answers only after the child has heard the line once (`MIN_LISTEN_TIME`), which enforces the instruction kindly instead of failing them.

### 10×10 grid — `GridTrapRoom.gd`
```gdscript
column = floor((x + half) / cell)    # 0..9 → 'A'..'J'
row    = floor((half - z) / cell)    # 0..9 → 1..10
```
`position_to_coord()` / `coord_to_position()` convert both ways. The current coordinate is displayed both on the HUD and as a floating `Label3D` above Jack. Stepping on a trap plays a soft "boing" and returns him to the last safe tile — nothing is lost.

---

## Developer / QA tools

```bash
# Parse-check every script
./tools/check_scripts.sh

# Build all 40 missions headlessly and report
godot --headless --path . -- --smoke

# Build AND solve all 40 missions (exercises every interaction handler)
godot --headless --path . -- --smoke --autoplay

# Build AND solve the 20 bonus challenges instead of the story
godot --headless --path . -- --smoke --autoplay --extra

# Check that every overlay panel fits the 1280x720 design viewport
godot --headless --path . --script tools/layout_check.gd

# Assert the scenery of the graphics pass exists in the live scene tree
godot --headless --path . --script tools/gfx_verify.gd

# Check that folding/unfolding every panel works and frees the screen
godot --headless --path . --script tools/fold_check.gd

# Assert that no two panels are ever on screen over each other, and that the
# task bar really disappears under a dialogue or a quiz
godot --headless --path . --script tools/overlap_check.gd

# Assert that Jack cannot move, turn or interact while a quiz or a dialogue
# owns the screen (the "I answer and he walks off" complaint)
godot --headless --path . --script tools/input_guard_check.gd

# Print every spoken line with a timestamp and report collisions between them
godot --headless --path . --script tools/speech_timeline.gd 2>&1 \
  | python3 -u tools/stamp_speech.py

# Assert that the shipped voice pack can say every line the game can say, and
# that every clip it indexes really loads. Exit code 0 = the pack is complete.
godot --headless --path . --script tools/voice_pack_check.gd

# Print the corpus the pack is built from (one JSON object per line)
godot --headless --path . --script tools/collect_speech.gd

# Check that the auto-fold timers fire once, on the right mission
godot --path . --script tools/fold_timing.gd

# Render the overlay panels to res://_shots for visual inspection
godot --path . --script tools/screenshot_ui.gd

# Render the folded states (TASK tab, SPEECH pill, quiz, settings) to res://_shots
godot --path . --script tools/screenshot_fold.gd

# Render the 3D zones (ground, motes, balloons, props) to res://_shots
godot --path . --script tools/gfx_probe.gd
```

`layout_check.gd` exits with code 0 only when every panel passes, so it works
as a regression test. It checks two invariants: no widget may need a minimum
size larger than the screen, and everything drawn inside a dialog must stay
within that dialog's frame. Both are what break when a wrapping `Label` is
allowed to collapse — see the note under "Layout rules" below.

Result of the last run: **40 / 40 missions built, 40 solved, 0 failures** (all
nine mechanics exercised end to end, no script errors), **20 / 20 bonus
challenges built and solved**, **78 / 78 panels inside the viewport** (every
overlay, every story page at all three difficulty levels, the volume page at
all five volume settings and all three view modes, and the challenge list at
all three difficulty levels both before and after a challenge is solved),
**33 / 33 fold checks**, **6 / 6 input-guard checks** (Jack moves 0.000 m, the
camera does not turn and the interact key does nothing while a quiz or a
dialogue owns the screen), **no overlapping panels**,
**23 / 23 graphics assertions**, and **880 / 880 voice clips** (the corpus the
game can say and the manifest agree exactly; 0 misses, 0 clips that fail to
load).

Every probe now ends through `tools/probe_shutdown.gd` instead of calling
`quit()` itself. `stop()` only *asks* the audio server to release a playback and
the server does so on its next mix pass, so a `quit()` in the same frame leaves
the playback, its stream and its `OggPacketSequence` alive at teardown and Godot
reports them as leaks. The helper stops the music and effects, drops the voice
clip cache, waits two mix passes, and *then* quits — the same sequence
`Main._quit_cleanly()` uses, in one place, so a probe cannot forget it and a
genuine leak stays visible instead of drowning in expected noise.

`speech_timeline.gd` reads the real startup — zone card → prologue → chapter →
first task — and stamps every line. The last measured run:

```
  1.10 s  The Whispering Pumpkin Patch. Colours & greetings
  6.35 s  The Lantern With No Light
 18.10 s  The Whispering Pumpkin Patch
 26.91 s  Find the RED, BLUE and YELLOW pumpkins!
4 line(s), no collisions
```

The probe "reads" each page for eight seconds before pressing GO ON, because a
page never advances by itself: dismissing it on the first visible frame would
cut its own title and report a collision the probe had caused itself.

Both harnesses run with `QuestManager.persist = false`, so they never touch the
player's save file — verified by comparing the file byte for byte before and
after a run.

---

## Layout rules (important for new UI)

Every panel is built in code, so a simple container mistake can silently push
content off screen. One rule prevents it:

> A `Label` with word wrapping enabled reports a minimum width of **1 px**.
> Inside an `HBoxContainer` it will be given a one-pixel column, wrap after
> every letter and grow hundreds of pixels tall, inflating the whole panel.

So, when calling `UiKit.label()`:

* short strings inside an `HBoxContainer` (counters, "3 / 5", one-word chips) →
  `wrap = false`;
* sentences → `wrap = true` **and** `min_width` set to the width the label will
  actually be laid out at (the panel's inner width).

Each panel declares its own `WRAP_WIDTH` constant so the numbers stay in one
place next to the geometry they belong to.


---

## Adding content

**A new mission:** append a dictionary to `GameData.missions()` with `id`, `zone`, `title`, `prompt_en`, `prompt_it`, `mechanic`, and the data that mechanic needs (`targets`, `questions`, `requirements`, `lines`, `path`…). Update `TOTAL_MISSIONS` in `QuestManager.gd` if you go past 40.

**A new word:** add it to `GameData.VOCAB`. It becomes available to the magnifying glass and the word chips.

**A new prop:** add a `match` branch to `PropFactory.build()` and a builder function next to the others. Colours come from `PropFactory.PALETTE`.
