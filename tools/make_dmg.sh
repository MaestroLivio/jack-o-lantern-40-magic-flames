#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  make_dmg.sh -- wrap an exported .app into a drag-to-Applications disk image
#
#  WHY a separate script rather than a few lines inside build_release.sh: making
#  a DMG that *looks right* needs an AppleScript round-trip to the Finder, and
#  that step is the one that fails on machines where Finder is busy or the
#  automation permission has not been granted yet. Keeping it isolated means the
#  export can still succeed (and be shipped as a zip) when only the cosmetic
#  step fails.
#
#  Usage:
#     tools/make_dmg.sh <path to .app> <output .dmg> [volume name]
#
#  What it produces:
#     * a compressed (UDZO) read-only image,
#     * the app on the left, an Applications shortcut on the right,
#     * a window sized to the artwork, background picture, no toolbar.
#
#  Code signing: the app is re-signed ad-hoc AFTER it is copied into the image,
#  because copying invalidates a signature's resource seals. Ad-hoc is not a
#  real identity and Gatekeeper will still warn on another Mac; see the note in
#  README.txt. Signing here at least makes the bundle internally consistent, so
#  `codesign --verify` passes and macOS does not report it as "damaged".
# ---------------------------------------------------------------------------
set -euo pipefail

APP_PATH="${1:?usage: make_dmg.sh <app> <out.dmg> [volume name]}"
OUT_DMG="${2:?usage: make_dmg.sh <app> <out.dmg> [volume name]}"
VOL_NAME="${3:-Jack o Lantern}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BG_SRC="$PROJECT_DIR/build/dmg/background.png"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$APP_PATH" ] || die "App bundle not found: $APP_PATH"
[ -f "$BG_SRC" ] || die "DMG background missing: $BG_SRC (run tools/make_dmg_background.gd)"

# Window geometry, in points. Kept in one place because the AppleScript below
# and the artwork size must agree, or the icons land off the picture.
WIN_W=660
WIN_H=420
APP_ICON_SIZE=148
APP_X=170
APP_Y=205
LINK_X=490
LINK_Y=205

WORK="$(mktemp -d)"
MOUNT_POINT=""
cleanup() {
  # A half-mounted image left behind would make the next build fail with a
  # confusing "resource busy", so detach defensively.
  if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
    hdiutil detach "$MOUNT_POINT" -quiet -force 2>/dev/null || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

say "Staging"
STAGE="$WORK/stage"
mkdir -p "$STAGE"
# ditto, not cp: it preserves the bundle's metadata, resource forks and
# permission bits that `cp -R` mangles on some filesystems.
STAGED_APP="$STAGE/$(basename "$APP_PATH")"
ditto "$APP_PATH" "$STAGED_APP"

# Re-sign on the local disk, BEFORE the bundle goes into the image. ditto/copy
# leaves the existing signature's resource seals pointing at the old inode
# metadata, and `codesign --verify` then reports "invalid resource directory".
# Signing while the image is mounted does not work either -- codesign needs
# operations the mounted HFS volume rejects (observed: "internal error in Code
# Signing subsystem"), leaving a broken signature that is worse than none.
# Signing here, on the staging copy, is the only order that verifies cleanly.
say "Signing"
codesign --force --deep --sign - "$STAGED_APP" 2>&1 | sed 's/^/    /' || \
  echo "    (codesign failed; the app will be unsigned)"
codesign --verify --deep --strict "$STAGED_APP" 2>&1 | sed 's/^/    /' || \
  echo "    (signature does not verify -- see the note above)"

ln -s /Applications "$STAGE/Applications"

mkdir -p "$STAGE/.background"
cp "$BG_SRC" "$STAGE/.background/background.png"

RW_DMG="$WORK/rw.dmg"
say "Creating writable image"
# Generous size: hdiutil will not grow the image later, and a too-small one fails
# only at the very end, after the long copy.
SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 80 ))
hdiutil create -srcfolder "$STAGE" -volname "$VOL_NAME" -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" -format UDRW -size "${SIZE_MB}m" \
  "$RW_DMG" -quiet

say "Mounting"
# Mount under /Volumes (the default), NOT with -mountpoint into a temp folder.
# A volume mounted at a private path is invisible to the Finder, and the
# AppleScript below then fails with "can't get disk" (-1728) -- which is exactly
# what happened on the first attempt. The catch is that a name clash (an image
# still mounted from an earlier run) makes macOS choose "Jack o Lantern 1", so
# the real mount point is read back rather than assumed.
ATTACH_OUT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen)"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUT" | tail -1 | cut -f3)"
[ -d "$MOUNT_POINT" ] || die "Could not mount $RW_DMG"
REAL_VOL_NAME="$(basename "$MOUNT_POINT")"
if [ "$REAL_VOL_NAME" != "$VOL_NAME" ]; then
  # Say it out loud: the Finder script and the window title both use this name.
  echo "    volume mounted as '$REAL_VOL_NAME' (the name '$VOL_NAME' was taken)"
fi


# The recipe Apple ships in `hdiutil` docs stores Finder's window settings in the
# image's .DS_Store, which is what makes the picture, the icon positions and the
# hidden toolbar persist when the teacher opens it. Without this the DMG opens
# as a plain list of two files.
say "Arranging the Finder window"
osascript <<APPLESCRIPT || echo "    (Finder layout skipped: automation permission not granted)"
tell application "Finder"
  tell disk "$REAL_VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 140, 200 + $WIN_W, 140 + $WIN_H}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set background picture of viewOptions to file ".background:background.png"
    set position of item "$(basename "$APP_PATH")" of container window to {$APP_X, $APP_Y}
    set position of item "Applications" of container window to {$LINK_X, $LINK_Y}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
APPLESCRIPT

# Finder writes .DS_Store lazily; syncing and detaching too fast loses the layout.
sync
sleep 1

hdiutil detach "$MOUNT_POINT" -quiet -force
MOUNT_POINT=""

say "Compressing"
rm -f "$OUT_DMG"
# UDZO = zlib-compressed, read-only. ULFO (lzfse) is smaller on macOS 10.11+ but
# a teacher might open this on an older Mac, and UDZO is the safe default.
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 \
  -o "$OUT_DMG" -quiet

say "Signing the disk image"
# Signing the DMG itself is separate from signing the app inside it, and it is
# what lets macOS verify the download was not corrupted in transit.
codesign --force --sign - "$OUT_DMG" 2>&1 | sed 's/^/    /' || \
  echo "    (DMG signing failed; harmless for local distribution)"

say "Verifying"
hdiutil verify "$OUT_DMG" | sed 's/^/    /'
printf '    size: %s\n' "$(du -h "$OUT_DMG" | cut -f1)"
