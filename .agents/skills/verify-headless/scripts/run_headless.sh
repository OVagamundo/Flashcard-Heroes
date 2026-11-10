#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h:h:h:h}"
SCENE_OR_ARGS=("$@")

TMP_HOME="$(mktemp -d /tmp/fch_headless.XXXXXX)"
trap 'rm -rf "$TMP_HOME"' EXIT
mkdir -p "$TMP_HOME/Library/Application Support/Godot/app_userdata/Flashcard Heroes"

cd "$REPO_ROOT"
if [ ${#SCENE_OR_ARGS[@]} -eq 0 ]; then
  HOME="$TMP_HOME" /Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 2
elif [[ "${SCENE_OR_ARGS[1]}" == *.tscn ]]; then
  HOME="$TMP_HOME" /Applications/Godot.app/Contents/MacOS/Godot --headless --scene "${SCENE_OR_ARGS[@]}"
else
  HOME="$TMP_HOME" /Applications/Godot.app/Contents/MacOS/Godot --headless "${SCENE_OR_ARGS[@]}"
fi
