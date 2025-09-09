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

# Determine composer command
if command -v composer >/dev/null 2>&1; then
  COMPOSER_CMD="composer"
else
  if [ -f "composer.phar" ]; then
    COMPOSER_CMD="php $(pwd)/composer.phar"
  else
    echo "⚠️ Composer not found. Installing local composer.phar..."
    EXPECTED_SIGNATURE="$(curl -s https://composer.github.io/installer.sig)"
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

    if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
      >&2 echo '❌ ERROR: Invalid Composer installer signature'
      rm composer-setup.php
      exit 1
    fi

    php composer-setup.php --quiet
    rm composer-setup.php
    COMPOSER_CMD="php $(pwd)/composer.phar"
    echo "✅ Installed local composer.phar"
  fi
fi

# Ensure submodules are pulled
echo "📦 Initializing Git submodules..."
git submodule update --init --recursive

# Install Composer dependencies
echo "🎼 Installing Composer dependencies..."
composer install

# Create local-config.php if missing
if [ ! -f "local-config.php" ]; then
    echo "⚙️ No local-config.example.php found."
    echo "Let's create local-config.php interactively..."

    read -p "Database name: " DB_NAME
    read -p "Database user [root]: " DB_USER
    DB_USER=${DB_USER:-root}

    read -s -p "Database password: " DB_PASSWORD
    echo
    read -p "Database host [localhost]: " DB_HOST
    DB_HOST=${DB_HOST:-localhost}

    read -p "Table prefix [wp_]: " TABLE_PREFIX
    TABLE_PREFIX=${TABLE_PREFIX:-wp_}

    read -p "Enable WP_DEBUG? (true/false) [true]: " WP_DEBUG
    WP_DEBUG=${WP_DEBUG:-true}

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

    # Prompt to create the database
    read -p "Create this database locally? (y/n) [y]: " CREATE_DB
    CREATE_DB=${CREATE_DB:-y}

    if [ "$CREATE_DB" = "y" ]; then
      echo "⚙️ Creating database '${DB_NAME}' on host '${DB_HOST}'..."

      # Prompt for root MySQL password (hidden input)
      read -s -p "MySQL root password: " MYSQL_ROOT_PASS
      echo

      # Try creating the database
      "/F/xampp/mysql/bin/mysql.exe" -u root -p"${MYSQL_ROOT_PASS}" -h "${DB_HOST}" -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

      if [ $? -eq 0 ]; then
        echo "✅ Database '${DB_NAME}' created (or already exists)"
      else
        echo "❌ Failed to create database. Please check credentials and permissions."
      fi
    fi

else
  echo "ℹ️ local-config.php already exists, not overwriting"
fi

echo "🎉 Setup complete!"
