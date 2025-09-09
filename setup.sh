#!/usr/bin/env bash
set -e

# Move into the directory where this script lives
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🚀 Setting up WordPress Starter in $SCRIPT_DIR"

# Make sure this script is executable
if [ ! -x "$0" ]; then
  echo "🔑 Making setup.sh executable..."
  chmod +x "$0"
fi

# Ensure submodules are pulled
echo "📦 Initializing Git submodules..."
git submodule update --init --recursive

# Install Composer dependencies
echo "🎼 Installing Composer dependencies..."
composer install

# Create local-config.php if missing
if [ ! -f "local-config.php" ]; then
  if [ -f "local-config.example.php" ]; then
    cp local-config.example.php local-config.php
    echo "✅ Created local-config.php from example"
  else
    echo "⚙️ No local-config.example.php found."
    echo "Let's create local-config.php interactively..."

    read -p "Database name: " DB_NAME
    read -p "Database user: " DB_USER
    read -s -p "Database password: " DB_PASSWORD
    echo
    read -p "Database host [localhost]: " DB_HOST
    DB_HOST=${DB_HOST:-localhost}

    read -p "Table prefix [wp_]: " TABLE_PREFIX
    TABLE_PREFIX=${TABLE_PREFIX:-wp_}

    read -p "Enable WP_DEBUG? (true/false) [false]: " WP_DEBUG
    WP_DEBUG=${WP_DEBUG:-false}

    echo "🔑 Fetching WordPress salts..."
    SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

    cat > local-config.php <<EOL
<?php
define( 'DB_NAME', '${DB_NAME}' );
define( 'DB_USER', '${DB_USER}' );
define( 'DB_PASSWORD', '${DB_PASSWORD}' );
define( 'DB_HOST', '${DB_HOST}' );
\$table_prefix = '${TABLE_PREFIX}';
define( 'WP_DEBUG', ${WP_DEBUG} );

// WordPress salts
${SALTS}
EOL

    echo "✅ Created local-config.php with provided values"
  fi
else
  echo "ℹ️ local-config.php already exists, not overwriting"
fi

echo "🎉 Setup complete!"
