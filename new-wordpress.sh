#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/davidhyland/WordPress-Starter.git"
TARGET_DIR=${1:-myproject}

echo "🚀 WordPress Starter installer"

if [ "$TARGET_DIR" = "." ]; then
  echo "📂 Cloning into current directory..."

  # Check if directory is empty
  if [ "$(ls -A .)" ]; then
    echo "❌ Error: Current directory is not empty. Please run in an empty folder."
    exit 1
  fi

  git clone --recurse-submodules "$REPO_URL" .
else
  echo "📂 Cloning into $TARGET_DIR ..."
  git clone --recurse-submodules "$REPO_URL" "$TARGET_DIR"
  cd "$TARGET_DIR"
fi

echo "⚙️ Running setup.sh ..."
bash setup.sh

echo "🎉 Project ready!"
