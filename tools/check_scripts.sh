#!/bin/zsh
# Parse-checks every GDScript file in the project with the Godot binary.
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
cd "$(dirname "$0")/.." || exit 1
for f in $(find scripts -name "*.gd" | sort); do
  out=$("$GODOT" --headless --check-only --script "$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR: Failed")
  if [ -n "$out" ]; then
    echo "=== $f"
    echo "$out"
  fi
done
echo "--- done"
