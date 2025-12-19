#!/usr/bin/env bash

# Default plugins path
DEFAULT_PATH="wp-content"

# Prompt for plugins path
read -p "Plugins path [${DEFAULT_PATH}]: " PLUGINS_PATH
PLUGINS_PATH="${PLUGINS_PATH:-$DEFAULT_PATH}/plugins"

# Validate path
if [ ! -d "$PLUGINS_PATH" ]; then
  echo "❌ Path does not exist: $PLUGINS_PATH"
  exit 1
fi

# Output file in same directory as plugins folder
OUTPUT_DIR="$(dirname "$PLUGINS_PATH")"
OUTPUT_FILE="${OUTPUT_DIR}/plugins-list.txt"

# Generate list
find "$PLUGINS_PATH" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort > "$OUTPUT_FILE"

echo "✅ Plugin list written to: $OUTPUT_FILE"
