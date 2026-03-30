#!/usr/bin/env bash
set -e

# ######################################################
# CONSTANTS
# ######################################################
DEFAULT_ACF_KEY="b3JkZXJfaWQ9MTE4ODkxfHR5cGU9ZGV2ZWxvcGVyfGRhdGU9MjAxNy0xMS0xNiAxNzowMDowNw=="
DEFAULT_GF_KEY="c6b0f8bac9195c2f32efe56c0fb823e6"
# Laragon defaults to .test domains
DEFAULT_SITE_URL="https://wp-starter.test" 

WP_VERSION="latest" 

# Dynamic MySQL path for Laragon (falls back to PATH if not found at specific location)
LARAGON_MYSQL="F/laragon/bin/mysql/mysql-8.4.3-winx64/bin/mysql.exe"
if [ -f "$LARAGON_MYSQL" ]; then
    MYSQL_EXE="$LARAGON_MYSQL"
elif command -v mysql >/dev/null 2>&1; then
    MYSQL_EXE="mysql"
else
    MYSQL_EXE="/F/laragon/bin/mysql/mysql-default/bin/mysql.exe"
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🚀 Setting up Standard WordPress in Laragon environment..."

# ============================
# WordPress Download & Extract
# ============================

# Checking for standard WP files in the current root
if [ -f "wp-load.php" ]; then
    echo "✅ WordPress core already present in root. Skipping download."
else
    echo "📥 Downloading latest WordPress..."
    curl -L -o wordpress.zip "https://wordpress.org/latest.zip"
    echo "📦 Extracting to root..."
    unzip -q wordpress.zip
    mv wordpress/* .
    rm -rf wordpress wordpress.zip
    echo "✅ WordPress installed in root."
fi

# ===============================
# Cleanup & Standard Structure
# ===============================

echo "🧹 Cleaning up bundled content..."
rm -f wp-content/plugins/hello.php

# Standard WP folders
mkdir -p wp-content/uploads
mkdir -p wp-content/mu-plugins
mkdir -p config

# Permissions (Safe for Laragon/Windows)
chmod -R 755 wp-content 2>/dev/null || true


# ==============================
# Create MU-Plugins
# ==============================
echo "🧩 Generating License Sync MU-plugin..."

cat > wp-content/mu-plugins/license-sync.php <<EOL
<?php
/**
 * Plugin Name: License Key Sync
 * Description: Syncs Gravity Forms & ACF Pro license keys from constants to the database.
 */
if (!defined('ABSPATH')) exit;

add_action('admin_init', function() {
    if (get_option('mu_license_sync_done')) return;

    if (defined('GF_LICENSE_KEY') && GF_LICENSE_KEY) {
        update_option('gravityforms_license_key', GF_LICENSE_KEY);
    }

    if (defined('ACF_PRO_LICENSE') && ACF_PRO_LICENSE) {
        update_option('acf_pro_license', ACF_PRO_LICENSE);
    }

    update_option('mu_license_sync_done', 1);
});
EOL

echo "✅ license-sync.php created in wp-content/mu-plugins/"



# ==============================
# Auth.json (ACF + Gravity Forms)
# ==============================

if [ ! -f "auth.json" ]; then
  echo "🔐 Setting up Composer auth.json..."

  read -p "💻 ACF Pro Key [$DEFAULT_ACF_KEY]: " ACF_KEY
  ACF_KEY=${ACF_KEY:-$DEFAULT_ACF_KEY}

  read -p "💻 Gravity Forms Key [$DEFAULT_GF_KEY]: " GF_KEY
  GF_KEY=${GF_KEY:-$DEFAULT_GF_KEY}

  read -p "💻 Site URL (Must match GF dash) [$DEFAULT_SITE_URL]: " SITE_URL
  SITE_URL=${SITE_URL:-$DEFAULT_SITE_URL}

  if [ -z "$ACF_KEY" ] && [ -z "$GF_KEY" ]; then
    echo "ℹ️ No keys provided. Skipping auth.json."
  else
    # We use a Heredoc to create a clean, valid JSON file.
    # Note: If you don't use one of the keys, the entry remains 
    # but uses the default or empty string.
    cat > auth.json <<EOF
{
    "http-basic": {
        "connect.advancedcustomfields.com": {
            "username": "$ACF_KEY",
            "password": "$SITE_URL"
        },
        "composer.gravity.io": {
            "username": "$GF_KEY",
            "password": "$SITE_URL"
        }
    }
}
EOF
    echo "✅ auth.json created and validated."
  fi
else
  echo "ℹ️ auth.json already exists, skipping."
fi

# ==============================
# Composer & Config
# ==============================

echo "🎼 Installing Composer dependencies..."
composer clear-cache # Forces a fresh check of the new auth.json
composer install

if [ ! -f "wp-config.php" ]; then
    echo "📄 Creating wp-config.php loader..."
    
    # Simple Salts Fetch
    SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

    # Create Local Config
    cat > config/local-config.php <<EOL
<?php
define( 'DB_NAME', 'wp_database' );
define( 'DB_USER', 'root' );
define( 'DB_PASSWORD', '' );
define( 'DB_HOST', 'localhost' );
\$table_prefix = 'wp_';
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
$SALTS
EOL

    # Create main wp-config.php (Standard Structure)
    cat > wp-config.php <<EOL
<?php
if ( file_exists( __DIR__ . '/config/local-config.php' ) ) {
    include( __DIR__ . '/config/local-config.php' );
}

if ( !defined('ABSPATH') ) define('ABSPATH', __DIR__ . '/');
require_once ABSPATH . 'wp-settings.php';
EOL
fi

# ==============================
# 1. Config File Creation (Conditional on Local Config)
# ==============================

# We check for the local-config since the main wp-config is tracked in the repo
if [ ! -f "config/local-config.php" ]; then
    echo "📄 local-config.php not found. Starting environment setup..."
    
    read -p "⚙️ DB Name [wp_database]: " DB_NAME
    DB_NAME=${DB_NAME:-wp_database}
    read -p "⚙️ DB User [root]: " DB_USER
    DB_USER=${DB_USER:-root}
    read -s -p "⚙️ DB Password []: " DB_PASS
    echo "" 

    echo "🔐 Fetching WordPress salts..."
    SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

    # Create config/local-config.php
    # This is the file your tracked wp-config.php will include
    cat > config/local-config.php <<EOL
<?php
define( 'DB_NAME', '$DB_NAME' );
define( 'DB_USER', '$DB_USER' );
define( 'DB_PASSWORD', '$DB_PASS' );
define( 'DB_HOST', 'localhost' );
\$table_prefix = 'wp_';

// License Keys for MU-Plugin sync
define( 'ACF_PRO_LICENSE', '$ACF_KEY' );
define( 'GF_LICENSE_KEY', '$GF_KEY' );

define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
$SALTS
EOL
    echo "✅ local-config.php created in /config/"

else
    echo "ℹ️ local-config.php already exists. Reading credentials for DB check..."
    # Extract values so the Database Creation step below has the right info
    DB_NAME=$(grep "DB_NAME" config/local-config.php | cut -d "'" -f 4)
    DB_USER=$(grep "DB_USER" config/local-config.php | cut -d "'" -f 4)
    DB_PASS=$(grep "DB_PASSWORD" config/local-config.php | cut -d "'" -f 4)
fi

# ==============================
# 2. Database Creation (Always Runs Check)
# ==============================
# This now has access to $DB_NAME whether it was just created or read from file
read -p "💻 Create/Check database '$DB_NAME' now? (y/n) [y]: " CREATE_DB
CREATE_DB=${CREATE_DB:-y}

if [ "$CREATE_DB" = "y" ]; then
    echo "🔹 Accessing MySQL..."
    if [ -z "$DB_PASS" ]; then
        "$MYSQL_EXE" -u "$DB_USER" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    else
        "$MYSQL_EXE" -u "$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    fi
    echo "✅ DB check complete."
fi

echo "🎉 Setup complete! Move this folder into F:/laragon/www/ and restart Laragon."