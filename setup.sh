#!/usr/bin/env bash
set -e

# ######################################################
# CONSTANTS
# ######################################################
DEFAULT_ACF_KEY="b3JkZXJfaWQ9MTE4ODkxfHR5cGU9ZGV2ZWxvcGVyfGRhdGU9MjAxNy0xMS0xNiAxNzowMDowNw=="
DEFAULT_GF_KEY="c6b0f8bac9195c2f32efe56c0fb823e6"
DEFAULT_SITE_URL="https://wp-starter.test" 

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# ============================
# Robust MySQL Detection
# ============================
echo "🔍 Searching for MySQL..."
if command -v mysql >/dev/null 2>&1; then
    MYSQL_EXE="mysql"
else
    # find ensures we get the version on your F: drive correctly
    FOUND_MYSQL=$(find /f/laragon/bin/mysql -name "mysql.exe" -type f | head -n 1)
    if [ -n "$FOUND_MYSQL" ]; then
        MYSQL_EXE="$FOUND_MYSQL"
    else
        echo "❌ Error: mysql.exe not found on F: drive."
        exit 1
    fi
fi
echo "✅ Using MySQL at: $MYSQL_EXE"

# ============================
# WordPress Download & Extract
# ============================
if [ -f "wp-load.php" ]; then
    echo "✅ WordPress core already present."
else
    echo "📥 Downloading latest WordPress..."
    curl -L -o wordpress.zip "https://wordpress.org/latest.zip"
    unzip -q wordpress.zip
    mv wordpress/* .
    rm -rf wordpress wordpress.zip
fi

mkdir -p wp-content/uploads wp-content/mu-plugins config

# ==============================
# Create License Sync MU-Plugin
# ==============================
cat > wp-content/mu-plugins/license-sync.php <<EOL
<?php
/**
 * Plugin Name: License Key Sync
 * Description: Syncs Gravity Forms & ACF Pro license keys from constants to the database.
 */
if (!defined('ABSPATH')) exit;
add_action('admin_init', function() {
    if (get_option('mu_license_sync_done')) return;
    if (defined('GF_LICENSE_KEY')) update_option('gravityforms_license_key', GF_LICENSE_KEY);
    if (defined('ACF_PRO_LICENSE')) update_option('acf_pro_license', ACF_PRO_LICENSE);
    update_option('mu_license_sync_done', 1);
});
EOL

# ==============================
# Auth.json & Composer
# ==============================
if [ ! -f "auth.json" ]; then
    read -p "💻 ACF Pro Key [$DEFAULT_ACF_KEY]: " ACF_KEY
    ACF_KEY=${ACF_KEY:-$DEFAULT_ACF_KEY}
    read -p "💻 Gravity Forms Key [$DEFAULT_GF_KEY]: " GF_KEY
    GF_KEY=${GF_KEY:-$DEFAULT_GF_KEY}
    read -p "💻 Site URL [$DEFAULT_SITE_URL]: " SITE_URL
    SITE_URL=${SITE_URL:-$DEFAULT_SITE_URL}

    cat > auth.json <<EOF
{
    "http-basic": {
        "connect.advancedcustomfields.com": { "username": "$ACF_KEY", "password": "$SITE_URL" },
        "composer.gravity.io": { "username": "$GF_KEY", "password": "$SITE_URL" }
    }
}
EOF
fi

composer install

# ==============================
# Config & Database Creation
# ==============================
if [ ! -f "config/local-config.php" ]; then
    read -p "⚙️ DB Name [wp_database]: " DB_NAME
    DB_NAME=${DB_NAME:-wp_database}
    read -p "⚙️ DB User [root]: " DB_USER
    DB_USER=${DB_USER:-root}
    read -s -p "⚙️ DB Password []: " DB_PASS
    echo "" 

    SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

    cat > config/local-config.php <<EOL
<?php
define( 'DB_NAME', '$DB_NAME' );
define( 'DB_USER', '$DB_USER' );
define( 'DB_PASSWORD', '$DB_PASS' );
define( 'DB_HOST', 'localhost' );
\$table_prefix = 'wp_';
define( 'ACF_PRO_LICENSE', '$ACF_KEY' );
define( 'GF_LICENSE_KEY', '$GF_KEY' );
define( 'WP_DEBUG', true );
$SALTS
EOL
else
    DB_NAME=$(grep "DB_NAME" config/local-config.php | cut -d "'" -f 4)
    DB_USER=$(grep "DB_USER" config/local-config.php | cut -d "'" -f 4)
    DB_PASS=$(grep "DB_PASSWORD" config/local-config.php | cut -d "'" -f 4)
fi

# Ensure wp-config.php exists and has the ENV logic for your themes
if [ ! -f "wp-config.php" ]; then
    cat > wp-config.php <<EOL
<?php
if ( isset(\$_SERVER['HTTP_HOST']) && strpos(\$_SERVER['HTTP_HOST'], '.test') !== false ) {
    define( 'ENV', 'local' );
} else {
    define( 'ENV', 'production' );
}

if ( file_exists( __DIR__ . '/config/' . ENV . '-config.php' ) ) {
    include( __DIR__ . '/config/' . ENV . '-config.php' );
}

if ( !defined('ABSPATH') ) define('ABSPATH', __DIR__ . '/');
require_once ABSPATH . 'wp-settings.php';
EOL
fi

# ==============================
# Database Creation (Fixed for Git Bash/Laragon)
# ==============================
read -p "💻 Create/Check database '$DB_NAME' now? (y/n) [y]: " CREATE_DB
CREATE_DB=${CREATE_DB:-y}

if [ "$CREATE_DB" = "y" ]; then
    echo "🔹 Accessing MySQL at $MYSQL_EXE..."
    
    # We use a double-check here: -h 127.0.0.1 often works better in Git Bash
    # And we wrap variables in quotes to handle special characters in passwords
    
    if [ -z "$DB_PASS" ]; then
        # Case: No Password (Laragon default)
        "$MYSQL_EXE" -h 127.0.0.1 -u "$DB_USER" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    else
        # Case: Password exists. 
        # CRITICAL: No space between -p and the password variable
        "$MYSQL_EXE" -h 127.0.0.1 -u "$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    fi

    # Verify if it actually worked
    if [ $? -eq 0 ]; then
        echo "✅ Database '$DB_NAME' is ready."
    else
        echo "❌ MySQL Error: Database could not be created."
        echo "Try running this manually in your Laragon terminal:"
        echo "mysql -u root -e \"CREATE DATABASE $DB_NAME;\""
    fi
fi

echo "🎉 Setup complete!"