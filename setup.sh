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
    echo "✅ WordPress core detected. Skipping download."
else
    # Detect OS
    UNAME_OUT="$(uname -s)"
    case "${UNAME_OUT}" in
        Linux*|Darwin*) EXT="tar.gz" ;;
        *) EXT="zip" ;;
    esac

    WP_URL="https://wordpress.org/latest.$EXT"
    ARCHIVE="wordpress.$EXT"
    
    echo "📥 Downloading WordPress..."
    curl -L -o "$ARCHIVE" "$WP_URL"

    echo "📦 Extracting to Root..."
    if [ "$EXT" = "tar.gz" ]; then
        tar -xzf "$ARCHIVE" --strip-components=1
    else
        unzip -q "$ARCHIVE"
        mv wordpress/* .
        rm -rf wordpress
    fi
    rm "$ARCHIVE"
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
# Composer & Auth Setup
# ==============================

if [ ! -f "auth.json" ]; then
    echo "🔐 Setting up Composer auth.json..."
    
    read -p "💻 ACF Pro Key [$DEFAULT_ACF_KEY]: " ACF_KEY
    ACF_KEY=${ACF_KEY:-$DEFAULT_ACF_KEY}
    read -p "💻 Site URL [$DEFAULT_SITE_URL]: " SITE_URL
    SITE_URL=${SITE_URL:-$DEFAULT_SITE_URL}

    cat > auth.json <<EOF
{
    "http-basic": {
        "connect.advancedcustomfields.com": {
            "username": "$ACF_KEY",
            "password": "$SITE_URL"
        }
    }
}
EOF
fi

echo "🎼 Installing Composer dependencies..."
# Laragon usually has composer in the path
composer install || php composer.phar install

# ==============================
# Environment Configs
# ==============================

if [ ! -f "wp-config.php" ]; then
    echo "📄 Creating standard wp-config.php with environment loader..."
    
    # Prompt for DB (Laragon default is often 'root' with no password)
    read -p "⚙️ DB Name: " DB_NAME
    read -p "⚙️ DB User [root]: " DB_USER
    DB_USER=${DB_USER:-root}
    read -s -p "⚙️ DB Password []: " DB_PASS
    echo ""

    SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

    # Create the local-config.php
    cat > config/local-config.php <<EOL
<?php
define( 'DB_NAME', '$DB_NAME' );
define( 'DB_USER', '$DB_USER' );
define( 'DB_PASSWORD', '$DB_PASS' );
define( 'DB_HOST', 'localhost' );
\$table_prefix = 'wp_';
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
$SALTS
EOL

    # Create the main wp-config.php loader
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
# Database Creation
# ==============================
read -p "💻 Create database '$DB_NAME' now? (y/n) [y]: " CREATE_DB
CREATE_DB=${CREATE_DB:-y}

if [ "$CREATE_DB" = "y" ]; then
    echo "🔹 Accessing MySQL..."
    "$MYSQL_EXE" -u "$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" && echo "✅ DB Created."
fi

echo "🎉 Setup complete! Move this folder into F:/laragon/www/ and restart Laragon."