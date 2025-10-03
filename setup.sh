#!/usr/bin/env bash
set -e

# Hardcoded defaults (set defaults here, prompts are given to confirm)
DEFAULT_ACF_KEY="b3JkZXJfaWQ9MTE4ODkxfHR5cGU9ZGV2ZWxvcGVyfGRhdGU9MjAxNy0xMS0xNiAxNzowMDowNw=="
DEFAULT_GF_KEY="c6b0f8bac9195c2f32efe56c0fb823e6"
DEFAULT_SITE_URL="https://local.mcdill.XYZ"
WP_VERSION=""   # <-- change this to WP version, Leave blank for latest stable

# Update path to mysql.exe (if auto creation of database is required)
MYSQL_EXE="/F/xampp/mysql/bin/mysql.exe"

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



# ========================
# Download WordPress Core
# ========================
WP_DIR="wp"

# Ensure target directory exists and is empty
rm -rf "$WP_DIR"
mkdir -p "$WP_DIR"

# Detect OS for archive format
UNAME_OUT="$(uname -s)"
case "${UNAME_OUT}" in
    Linux*|Darwin*)
        if [ "$WP_VERSION" = "latest" ]; then
            WP_URL="https://wordpress.org/latest.tar.gz"
        else
            WP_URL="https://wordpress.org/wordpress-$WP_VERSION.tar.gz"
        fi
        ARCHIVE="wordpress.tar.gz"
        echo "📥 Downloading WordPress from $WP_URL ..."
        curl -L -o "$ARCHIVE" "$WP_URL"

        # Sanity check: confirm it's a valid gzip
        if ! file "$ARCHIVE" | grep -q "gzip compressed"; then
            echo "❌ Download failed or not a valid tar.gz (got $(file $ARCHIVE))"
            exit 1
        fi

        echo "📦 Extracting WordPress..."
        tar -xzf "$ARCHIVE" || { echo "❌ Extraction failed"; exit 1; }
        rm "$ARCHIVE"
        ;;
    MINGW*|MSYS*|CYGWIN*|Windows*)
        if [ "$WP_VERSION" = "latest" ]; then
            WP_URL="https://wordpress.org/latest.zip"
        else
            WP_URL="https://wordpress.org/wordpress-$WP_VERSION.zip"
        fi
        ARCHIVE="wordpress.zip"
        echo "📥 Downloading WordPress from $WP_URL ..."
        curl -L -o "$ARCHIVE" "$WP_URL"

        # Sanity check: confirm it's a valid zip
        if ! unzip -tq "$ARCHIVE" >/dev/null 2>&1; then
            echo "❌ Download failed or not a valid zip archive"
            rm "$ARCHIVE"
            exit 1
        fi

        echo "📦 Extracting WordPress..."
        unzip -q "$ARCHIVE" || { echo "❌ Extraction failed"; exit 1; }
        rm "$ARCHIVE"
        ;;
    *)
        echo "❌ Unsupported OS: ${UNAME_OUT}"
        exit 1
        ;;
esac

# Move extracted files into wp/ folder
mv wordpress/* "$WP_DIR"/
rm -rf wordpress

echo "✅ WordPress $WP_VERSION installed in $WP_DIR/"


# Clean bundled plugins & themes
echo "🧹 Cleaning bundled themes and plugins..."
rm -f "$WP_DIR/wp-content/plugins/hello.php"

THEMES_DIR="$WP_DIR/wp-content/themes"
if [ -d "$THEMES_DIR" ]; then
  NEWEST_THEME=$(ls -d $THEMES_DIR/twenty* 2>/dev/null | sort -V | tail -n 1)
  if [ -n "$NEWEST_THEME" ]; then
    echo "Keeping newest theme: $(basename "$NEWEST_THEME")"
    for theme in $THEMES_DIR/twenty*; do
      if [ "$theme" != "$NEWEST_THEME" ]; then
        rm -rf "$theme"
      fi
    done
  fi
fi



# === Auth.json Setup for ACF Pro + Gravity Forms ===
# Username: license key / Password: Site URL
if [ ! -f "auth.json" ]; then
  echo "🔐 Setting up Composer auth.json for ACF Pro + Gravity Forms"

  # Prompt with defaults
  read -p "Enter your ACF Pro license key [${DEFAULT_ACF_KEY}]: " ACF_KEY
  ACF_KEY=${ACF_KEY:-$DEFAULT_ACF_KEY}

  read -p "Enter your Gravity Forms license key [${DEFAULT_GF_KEY}]: " GF_KEY
  GF_KEY=${GF_KEY:-$DEFAULT_GF_KEY}

  read -p "Enter your site URL [${DEFAULT_SITE_URL}]: " SITE_URL
  SITE_URL=${SITE_URL:-$DEFAULT_SITE_URL}

  if [ -z "$ACF_KEY" ] && [ -z "$GF_KEY" ]; then
    echo "ℹ️ Skipping auth.json (no license keys provided)"
  else
    # Build JSON dynamically
    AUTH_CONTENT="{\n    \"http-basic\": {"
    SEP=""

    if [ -n "$ACF_KEY" ]; then
      AUTH_CONTENT="$AUTH_CONTENT\n        \"connect.advancedcustomfields.com\": {\n            \"username\": \"$ACF_KEY\",\n            \"password\": \"null\"\n        }"
      SEP=","
    fi

    if [ -n "$GF_KEY" ]; then
      AUTH_CONTENT="$AUTH_CONTENT$SEP\n        \"composer.gravity.io\": {\n            \"username\": \"$GF_KEY\",\n            \"password\": \"$SITE_URL\"\n        }"
    fi

    AUTH_CONTENT="$AUTH_CONTENT\n    }\n}"

    echo -e "$AUTH_CONTENT" > auth.json
    echo "✅ auth.json created"
  fi
else
  echo "ℹ️ auth.json already exists, skipping"
fi


# --- Validation step ---
echo "🔍 Validating auth.json..."

if ! grep -q "connect.advancedcustomfields.com" auth.json; then
  echo "❌ Missing ACF entry in auth.json" && exit 1
fi

if ! grep -q "\"password\": \"null\"" auth.json; then
  echo "❌ ACF password must be 'null'" && exit 1
fi

if ! grep -q "composer.gravity.io" auth.json; then
  echo "❌ Missing Gravity Forms entry in auth.json" && exit 1
fi

if ! grep -q "${GF_SITE}" auth.json; then
  echo "❌ Gravity Forms site URL does not match expected value" && exit 1
fi

echo "✅ auth.json validated successfully."



# Install Composer dependencies
echo "🎼 Installing Composer dependencies (plugins) ..."
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

define( 'ACF_PRO_LICENSE', '${ACF_KEY}' );
define( 'GF_LICENSE_KEY', '${GF_KEY}' );

// WordPress salts
${SALTS}
EOL

    echo "✅ Created local-config.php with provided values"




    # Create mu-plugins folder if it doesn't exist
    mkdir -p content/mu-plugins

    # Generate license-sync.php
    cat > content/mu-plugins/license-sync.php <<EOL
<?php
/**
 * Plugin Name: License Key Sync
 * Description: Sync Gravity Forms and ACF Pro license keys from local-config.php constants into the database.
 */

add_action( 'init', function() {
    // Gravity Forms license sync
    if ( defined( 'GF_LICENSE_KEY' ) && GF_LICENSE_KEY ) {
        \$stored = get_option( 'gravityforms_license_key' );
        if ( \$stored !== GF_LICENSE_KEY ) {
            update_option( 'gravityforms_license_key', GF_LICENSE_KEY );
        }
    }

    // ACF Pro license sync
    if ( defined( 'ACF_PRO_KEY' ) && ACF_PRO_KEY ) {
        \$stored = get_option( 'acf_pro_license' );
        if ( \$stored !== ACF_PRO_KEY ) {
            update_option( 'acf_pro_license', ACF_PRO_KEY );
        }
    }
});

// Define constants so they are always available
if ( ! defined( 'GF_LICENSE_KEY' ) ) {
    define( 'GF_LICENSE_KEY', '${GF_KEY}' );
}
if ( ! defined( 'ACF_PRO_KEY' ) ) {
    define( 'ACF_PRO_KEY', '${ACF_KEY}' );
}
EOL

    # Prompt to create the database
    read -p "Create this database locally? (y/n) [y]: " CREATE_DB
    CREATE_DB=${CREATE_DB:-y}

    if [ "$CREATE_DB" = "y" ]; then
      echo "⚙️ Creating database '${DB_NAME}' on host '${DB_HOST}'..."

      # Prompt for root MySQL password (hidden input)
      read -s -p "MySQL root password: " MYSQL_ROOT_PASS
      echo

      # Try creating the database
      "${MYSQL_EXE}" -u root -p"${MYSQL_ROOT_PASS}" -h "${DB_HOST}" -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

      if [ $? -eq 0 ]; then
        echo "✅ Database '${DB_NAME}' created (or already exists)"
      else
        echo "❌ Failed to create database. Please check credentials and permissions."
      fi
    fi

else
  echo "ℹ️ local-config.php already exists, not overwriting"
fi

echo "🎉 Setup complete!\n"
echo "Don't forget to update hosts, apache/vhosts and SSL cert."
