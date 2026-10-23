#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  build_release.sh -- produce the distributable builds and installers
#
#  WHY this script exists rather than a note in the README: a release has
#  several steps that must happen in order and that depend on paths relative to
#  the project root. Doing them by hand is where "the installer shipped last
#  week's exe" comes from. Every step fails loudly instead of continuing.
#
#  Windows:
#    1. Export with the Windows Desktop preset          -> dist/windows/
#    2. Sanity-check the export
#    3. Write the readme, then build the NSIS installer -> dist/
#
#  macOS:
#    4. Export a universal .app                         -> dist/macos/
#    5. Sign it ad-hoc and wrap it in a drag-and-drop DMG -> dist/
#
#  Usage:   tools/build_release.sh [version] [windows|macos|all]
#  Example: tools/build_release.sh 1.0.0          # both platforms
#           tools/build_release.sh 1.0.0 macos    # macOS only
#
#  Requirements on macOS:
#    * Godot 4.7.2 at /Applications/Godot.app (override with GODOT=...)
#    * Export templates for the same version in
#        ~/Library/Application Support/Godot/export_templates/<version>/
#      Download "Export Templates (Standard)" from godotengine.org/download and
#      extract so that version.txt sits inside that folder. Templates built for
#      the .mono (C#) editor are a different variant and do NOT work here.
#    * NSIS (Windows only): `brew install makensis`
#    * macOS DMG needs only what ships with macOS (hdiutil, codesign, iconutil)
#
#  Nothing here writes to the project's scripts or scenes; the only files it
#  creates are under dist/ and .godot/ (Godot's own import cache).
# ---------------------------------------------------------------------------
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
VERSION="${1:-1.0.0}"
TARGET="${2:-all}"
case "$TARGET" in
  all|windows|macos) ;;
  *) echo "usage: $0 [version] [windows|macos|all]" >&2; exit 2 ;;
esac

# VIProductVersion in the .nsi wants four numbers; a human-facing version may
# be "1.0.0". Padding here keeps the two consistent without asking the caller.
VERSION4="$VERSION"
case "$(echo "$VERSION" | awk -F. '{print NF}')" in
  1) VERSION4="$VERSION.0.0.0" ;;
  2) VERSION4="$VERSION.0.0" ;;
  3) VERSION4="$VERSION.0" ;;
esac

DIST="$PROJECT_DIR/dist"
WIN_DIR="$DIST/windows"
EXE="$WIN_DIR/JackOLantern.exe"
SETUP="$DIST/JackOLantern-Setup-$VERSION.exe"
MAC_DIR="$DIST/macos"
DMG="$DIST/JackOLantern-$VERSION.dmg"
# The .app name is fixed by the project name (application/config/name), not by
# anything in export_presets.cfg -- verified against the exported Info.plist.
MAC_APP_NAME="Jack o Lantern - The 40 Magic Flames"
DMG_VOL_NAME="Jack o Lantern"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

file_size() {
  # BSD stat (macOS) takes -f%z, GNU stat takes -c%s. Trying both keeps the
  # script working if it is ever run on a Linux build machine.
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1"
}

# --- Preconditions ---------------------------------------------------------
[ -x "$GODOT" ] || die "Godot not found at '$GODOT'. Set GODOT=/path/to/Godot."
if [ "$TARGET" = "windows" ] || [ "$TARGET" = "all" ]; then
  command -v makensis >/dev/null 2>&1 || die "NSIS not found. Install it with: brew install makensis"
fi

say "Godot: $("$GODOT" --version 2>/dev/null | tail -1)"
say "Building version $VERSION  (file version $VERSION4), target: $TARGET"

# Export templates must match the editor exactly, including the build variant.
# The editor reports e.g. "4.7.2.stable.official.ed1daf0bf" while the templates
# folder is named "4.7.2.stable". Taking the first four dot-separated parts --
# 4, 7, 2, stable -- derives the folder name without depending on the commit
# hash. The .mono (C#) templates carry "4.7.2.stable.mono" in version.txt and
# would be rejected by Godot at export time with a confusing message, so the
# mismatch is caught here instead.
GODOT_VERSION="$("$GODOT" --version 2>/dev/null | tail -1 | cut -d. -f1-4)"
TPL_ROOT="$HOME/Library/Application Support/Godot/export_templates/$GODOT_VERSION"
[ -f "$TPL_ROOT/version.txt" ] \
  || die "Export templates for $GODOT_VERSION not found in '$TPL_ROOT'.
       Download 'Export Templates (Standard)' for $GODOT_VERSION from
       godotengine.org/download and extract so version.txt sits in that folder."
grep -qx "$GODOT_VERSION" "$TPL_ROOT/version.txt" \
  || die "Templates in '$TPL_ROOT' report '$(cat "$TPL_ROOT/version.txt")' but the editor is $GODOT_VERSION.
       These are probably the .mono (C#) templates; this project is GDScript and needs the standard ones."

# --- The voice pack --------------------------------------------------------
# The game's whole teaching value is the recorded voice, and its absence is
# invisible: `AudioFx.speak()` falls back to whatever voice the machine has, so
# a build that shipped without the pack still runs, still speaks, and sounds
# different on every computer -- which is the exact complaint this release
# exists to fix. The manifest and the clips are therefore checked before export,
# not after. `export_filter="all_resources"` already picks up both, so this is a
# presence check, not an include-list.
VOICE_INDEX="$PROJECT_DIR/assets/voice/voice_pack.json"
[ -f "$VOICE_INDEX" ] \
  || die "assets/voice/voice_pack.json is missing.
       Build the pack first: see tools/VOICE_MODELS.md (Regenerating)."
VOICE_CLIPS=$(find "$PROJECT_DIR/assets/voice" -name '*.ogg' | wc -l | tr -d ' ')
VOICE_MB=$(( $(du -sk "$PROJECT_DIR/assets/voice" | cut -f1) / 1024 ))
[ "$VOICE_CLIPS" -ge 500 ] \
  || die "assets/voice/ holds only $VOICE_CLIPS clips; the corpus is ~1000.
       A partial pack means part of the lesson is read in a different voice.
       Re-run tools/make_voice_pack.py --force."
# The .ogg files must be *imported* for ResourceLoader.exists() to see them, and
# Godot writes one .import per source file on scan. Without them every clip is
# on disk, the manifest points at it, and the game still falls back -- the
# failure `tools/voice_pack_check.gd` reports as "will not load". A fresh clone
# has no .import files at all (they are build artefacts), so this repairs itself
# instead of asking the person building to remember.
IMPORTED=$(find "$PROJECT_DIR/assets/voice" -name '*.ogg.import' | wc -l | tr -d ' ')
if [ "$IMPORTED" -lt "$VOICE_CLIPS" ]; then
  say "Importing $VOICE_CLIPS voice clips ($IMPORTED imported so far)"
  "$GODOT" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true
  IMPORTED=$(find "$PROJECT_DIR/assets/voice" -name '*.ogg.import' | wc -l | tr -d ' ')
  [ "$IMPORTED" -ge "$VOICE_CLIPS" ] \
    || die "Godot imported only $IMPORTED of $VOICE_CLIPS voice clips.
       Run it by hand to see the error: \"$GODOT\" --headless --path \"$PROJECT_DIR\" --import"
fi
say "Voice pack: $VOICE_CLIPS clips, ${VOICE_MB} MB"

# ===========================================================================
#  WINDOWS
# ===========================================================================
if [ "$TARGET" = "windows" ] || [ "$TARGET" = "all" ]; then

say "Cleaning $WIN_DIR"
# The export directory is not committed, so a build always starts from a clean
# folder. That guarantees the installer cannot pick up a leftover file from an
# earlier run -- the failure mode that is impossible to see by looking at the
# result.
rm -rf "$WIN_DIR"
mkdir -p "$WIN_DIR"

say "Exporting Windows build"
# --headless keeps the editor from opening a window on a build machine.
# No --quit: --export-release already exits, and adding --quit would let the
# command return before the file is fully written on slower disks.
"$GODOT" --headless --path "$PROJECT_DIR" \
  --export-release "Windows Desktop" "$EXE"

[ -f "$EXE" ] || die "Export reported success but $EXE does not exist."

say "Checking the export"
# The .pck is embedded in the exe, so its contents cannot be listed here.
# What is checked instead are the two mistakes that actually reach a teacher:
# a missing exe (caught above) and dev-only folders that export_presets.cfg is
# supposed to drop. If that filter is ever relaxed, this stops the build rather
# than shipping tools/ and 10 MB of screenshots inside the game.
grep -q 'exclude_filter="tools/\*, build/\*, _shots/\*, \*.md"' export_presets.cfg \
  || die "export_presets.cfg no longer excludes tools/ build/ _shots/ *.md -- check it before shipping."

# The voice index is a plain JSON, which `export_filter="all_resources"` does not
# pick up: it only walks *imported* resources. Without this line in
# include_filter the .pck gets every .ogg and no manifest, and `AudioFx` falls
# back to the system voice on the teacher's machine while the audio sits in the
# package unused. Checked here because the symptom appears on the other computer.
grep -q 'include_filter="assets/voice/\*.json"' export_presets.cfg \
  || die "export_presets.cfg must include 'assets/voice/*.json' in include_filter,
       or the shipped build has the clips but no index and speaks in the OS voice."

EXE_MB=$(( $(file_size "$EXE") / 1048576 ))
# A Godot Windows export with embedded data is ~90-130 MB. Far below that means
# the templates were wrong or the pck was not embedded, and the game would fail
# at launch on the teacher's machine, not here.
[ "$EXE_MB" -ge 40 ] || die "Exported exe is only ${EXE_MB} MB; the embedded pck is probably missing."
say "Exported: ${EXE_MB} MB"

fi  # windows

# ===========================================================================
#  THE README (shared by both platforms)
# ===========================================================================
# Written before the installers so the same text can be embedded inside them: a
# teacher who is handed only the setup file still needs to know where the save
# games live and what to do when there is no sound.
say "Writing dist/README.txt"
# Quoted heredoc plus an explicit placeholder substitution. A quoted heredoc
# passes the text through byte for byte, which matters here because the file is
# full of Windows paths like %APPDATA%\Godot\... -- an *unquoted* heredoc would
# eat those backslashes as escapes and ship a mangled path to the teacher.
# @VERSION@ is replaced afterwards instead of interpolating $VERSION inline.
cat > "$DIST/README.txt" <<'EOF'
Jack o' Lantern - The 40 Magic Flames
=====================================

A gentle 3D English adventure for 7-year-olds (pre-A1).
Forty missions, a spoken story, and no way to lose.

This pack contains BOTH versions:

    Windows   JackOLantern-Setup-@VERSION@.exe   (installer, recommended)
              windows/JackOLantern.exe       (portable, runs without installing)

    macOS     JackOLantern-@VERSION@.dmg         (drag to Applications)
              macos/JackOLantern.zip         (the .app on its own)


WINDOWS
-------
1. Double-click JackOLantern-Setup-*.exe
2. Click Next, Next, Install.
3. Start the game from the desktop shortcut or the Start Menu.

Installs for the current user only, so no administrator password is needed.
Progress is kept in %APPDATA%\Godot\app_userdata\ and uninstalling does not
delete it.

If Windows shows "Windows protected your PC": click "More info", then
"Run anyway". This appears for any program that has not been bought from the
Microsoft Store.


MACOS
-----
1. Double-click JackOLantern-*.dmg
2. Drag "Jack o Lantern" into the Applications folder next to it.
3. Open it from Applications.

FIRST LAUNCH -- PLEASE READ
   The game is not signed with a paid Apple Developer certificate, so macOS
   will refuse to open it the first time with a message like:
       "Jack o Lantern cannot be opened because the developer cannot be
        verified."
   This is expected and it does not mean anything is wrong with the file.
   To allow it once:
       * macOS 15 and newer:  open System Settings > Privacy & Security,
         scroll down, and click "Open Anyway". Then try again.
       * older macOS:  right-click (or Control-click) the app, choose "Open",
         and confirm "Open" in the dialog.
   After that first approval the game starts normally every time.

Progress is kept in ~/Library/Application Support/Godot/app_userdata/ and
deleting the app does not remove it.

REQUIREMENTS ON MAC   macOS 11 or newer on Apple Silicon, macOS 10.13 or newer
                      on Intel. The app runs natively on both.
REQUIREMENTS ON WIN   Windows 10 or 11, 64-bit.


REQUIREMENTS (BOTH)
-------------------
* Sound output -- the game speaks its instructions aloud, and that is the main
  way the English is presented. Headphones or speakers are required.
  The voice is recorded into the game itself (a British English voice, plus an
  Italian one for the translate button), so it sounds the same on every
  computer and does not depend on what is installed on this one.
* A mouse, or a touch screen, or a gamepad (Xbox layout).
  On a touch screen the buttons for walking appear on the left edge by
  themselves; they can be put away with the small strip at the end of the row,
  or switched off altogether in the pause menu (Esc > SETTINGS).


HOW TO PLAY
-----------
Move          W A S D or the arrow keys
Look around   hold the right mouse button and drag, or hold the left button
              on empty ground and drag
Zoom          mouse wheel (out to look from further away; scroll all the way
              in and the view slips into Jack's own eyes -- first person.
              One notch back out returns to the normal view)
Interact      left-click the object, or press E
Translate     H, or the pink magnifier button in the corner
Pause         Esc  (difficulty, controls, sound and easy-read letters live
              in this menu)

A gamepad works too: left stick to walk, A to interact, Start to pause,
Y for the Italian help.

On a tablet there is a D-pad drawn on the left edge of the screen, a TAP button
next to it and the magnifying glass above it. The narrow strip at the far end of
that row puts the buttons away and leaves a small star in the same place; tap
the star to bring them back. Pause menu > SETTINGS > "Buttons on screen" turns
them off for good on a computer that has a keyboard.


FOR TEACHERS
------------
* The game never punishes a mistake: no timer, no game over, no dead end.
  A wrong answer only wobbles and invites another try.
* The magnifier button and the H key show the Italian translation of what is
  on screen. Use them only when a child is stuck; the point is the English.
* Difficulty is in the pause menu (the arrows beside the level name). Lower
  levels show more hints -- for example the colour next to the word "green".
  Higher levels remove those hints, so the child has to know the word.
* A save file is written automatically after every mission, so a lesson can
  be stopped and resumed later.
* Music and sound effects have their own volume (pause menu > Sound > LEVELS).
  The music steps back on its own while a line is spoken or a story page is
  open, so a teacher can read a chapter aloud over it. The spoken voice has no
  volume control on purpose: turning it down turns the lesson off.


WHERE IS MY PROGRESS SAVED?
---------------------------
Windows:  %APPDATA%\Godot\app_userdata\Jack o Lantern - The 40 Magic Flames\
macOS:    ~/Library/Application Support/Godot/app_userdata/
              Jack o Lantern - The 40 Magic Flames/

    jack_progress.json     which missions are done and how many flames
    controls.json          only if the controls were changed

Uninstalling the game does NOT delete this folder. Progress survives a
reinstall, deliberately. Delete it by hand if you want a fresh start.


TROUBLESHOOTING
---------------
Nothing happens when I click:
    Wait a few seconds on first launch; the system may ask for confirmation.

No sound:
    The instructions are spoken aloud, so with sound off the game is much
    harder to follow. Check the volume mixer and the output device, make
    sure "Sound" is ticked in the pause menu, and check that MUSIC and
    SOUND EFFECTS are not set to OFF on the LEVELS page behind it.

The music stopped after a few seconds:
    It has not; every track loops. If a whole zone is silent, the music level
    is probably at OFF -- pause menu > Sound > LEVELS > MUSIC.

The voice has an accent / sounds different from last time:
    The instructions are recorded audio shipped with the game, so this should
    not happen. If it does, the game is reading a line that was added after the
    voice was recorded, and it is using the computer's own voice for that one
    sentence. Nothing is broken and the sentence is still correct.

The window is too small or too large:
    Drag the window edge -- the game scales cleanly at any size and remembers
    nothing about it, so simply resize it each time.

macOS says the app is "damaged" or "cannot be opened":
    See FIRST LAUNCH above. Removing the download quarantine attribute also
    works, in Terminal:
        xattr -dr com.apple.quarantine "/Applications/Jack o Lantern - The 40 Magic Flames.app"
EOF

# Fill in the release version. `|` as the sed delimiter because the version is
# harmless but the placeholder should never be confused with a path separator.
sed -i '' "s|@VERSION@|$VERSION|g" "$DIST/README.txt"
grep -q '@VERSION@' "$DIST/README.txt" && die "README.txt still contains an unreplaced @VERSION@." || true

# ===========================================================================
#  WINDOWS INSTALLER
# ===========================================================================
if [ "$TARGET" = "windows" ] || [ "$TARGET" = "all" ]; then

# Last for this platform, so anything shipped inside it already exists on disk.
say "Building Windows installer"
makensis \
  -DAPP_VERSION="$VERSION" \
  -DAPP_VERSION4="$VERSION4" \
  -DSOURCE_DIR="$WIN_DIR" \
  -DOUT_FILE="$SETUP" \
  -DICON_FILE="$PROJECT_DIR/build/icon/jack.ico" \
  -DREADME_FILE="$DIST/README.txt" \
  "$PROJECT_DIR/build/installer/windows.nsi"

[ -f "$SETUP" ] || die "NSIS did not produce $SETUP."

fi  # windows installer

# ===========================================================================
#  MACOS
# ===========================================================================
if [ "$TARGET" = "macos" ] || [ "$TARGET" = "all" ]; then

say "Checking the macOS icon"
# The .icns is generated from icon.svg by tools/make_app_icon.gd. It is checked
# rather than regenerated on every build: rebuilding it needs a Godot run and
# the vector does not change between releases, so regenerating would only add a
# step that can fail. If the file is missing the build stops with the command.
[ -f build/icon/jack.icns ] \
  || die "build/icon/jack.icns missing. Create it with:
       \"$GODOT\" --headless --path . --script tools/make_app_icon.gd
       iconutil -c icns build/icon/jack.iconset -o build/icon/jack.icns"

say "Cleaning $MAC_DIR"
rm -rf "$MAC_DIR"
mkdir -p "$MAC_DIR"

say "Exporting macOS build"
# Exporting to a .zip lets Godot do its own packaging and keeps the .app bundle
# inside an archive whose metadata survives a copy to a USB stick or a download.
# Godot writes '<guid or name>.app' next to the requested output, so the
# requested path is only a hint -- the real name is discovered afterwards.
ZIP_OUT="$MAC_DIR/JackOLantern.zip"
"$GODOT" --headless --path "$PROJECT_DIR" --export-release "macOS" "$ZIP_OUT"

[ -f "$ZIP_OUT" ] || die "macOS export did not produce $ZIP_OUT."

# Unpack into a scratch folder so the .app can be signed and then looked at as
# a plain directory tree. Signing a bundle that lives inside a zip is impossible,
# and the DMG script needs a real folder anyway.
WORK="$MAC_DIR/work"
rm -rf "$WORK"
mkdir -p "$WORK"
ditto -x -k "$ZIP_OUT" "$WORK"
APP_PATH="$WORK/$MAC_APP_NAME.app"
[ -d "$APP_PATH" ] || {
  # Fall back to whatever single .app was produced, so a rename upstream
  # surfaces as a clear message instead of a bare "file not found".
  FOUND="$(find "$WORK" -maxdepth 1 -name '*.app' | head -1)"
  [ -n "$FOUND" ] || die "The exported zip contains no .app bundle."
  APP_PATH="$FOUND"
  MAC_APP_NAME="$(basename "$APP_PATH" .app)"
  echo "    note: the bundle is named '$MAC_APP_NAME.app'"
}

say "Checking the macOS bundle"
ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/$MAC_APP_NAME" 2>/dev/null || echo unknown)"
case "$ARCHS" in
  *arm64*) ;;
  *) die "The exported binary is only '$ARCHS'; a universal build needs arm64. Check binary_format/architecture in the macOS preset." ;;
esac
# A universal app must carry both slices: schools still have Intel Macs, and a
# silent arm64-only build would fail to launch there with no clue why.
case "$ARCHS" in
  *x86_64*) ;;
  *) echo "    WARNING: no x86_64 slice ('$ARCHS'); Intel Macs will not run this." ;;
esac
say "Architectures: $ARCHS"

# The embedded pck is what makes the .app self-contained. Without it the bundle
# would launch to an empty scene on a teacher's machine.
[ -f "$APP_PATH/Contents/Resources/$MAC_APP_NAME.pck" ] \
  || die "No embedded .pck in the bundle; the game would start with no content."

say "Building the DMG"
bash "$PROJECT_DIR/tools/make_dmg.sh" "$APP_PATH" "$DMG" "$DMG_VOL_NAME"

# The unpacked .app is scaffolding; the zip and the DMG are the deliverables.
rm -rf "$WORK"

fi  # macos

say "Done"
if [ -f "$SETUP" ]; then printf '  windows installer : %s\n' "$SETUP"; fi
if [ -f "$EXE" ];   then printf '  windows portable  : %s\n' "$EXE"; fi
if [ -f "$DMG" ];   then printf '  macos disk image  : %s\n' "$DMG"; fi
if [ -f "$MAC_DIR/JackOLantern.zip" ]; then printf '  macos zip         : %s\n' "$MAC_DIR/JackOLantern.zip"; fi
printf '  readme            : %s\n' "$DIST/README.txt"
