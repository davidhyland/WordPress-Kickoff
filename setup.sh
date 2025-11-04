#!/usr/bin/env bash
set -e

# ######################################################
# CONSTANTS (set defaults here, prompts are given to confirm)
# ######################################################
DEFAULT_ACF_KEY="b3JkZXJfaWQ9MTE4ODkxfHR5cGU9ZGV2ZWxvcGVyfGRhdGU9MjAxNy0xMS0xNiAxNzowMDowNw=="
DEFAULT_GF_KEY="c6b0f8bac9195c2f32efe56c0fb823e6"
DEFAULT_SITE_URL="https://local.mcdill.xyz" # <-- UPDATE URL HERE

# Set WordPress version to install
# Change this to a specific version (e.g., "6.8.1") or
# leave as "latest" to always get the latest stable release
WP_VERSION="latest" 

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


# ============================
# WordPress Version & Download
# ============================

WP_DIR="wp"

# Check if WordPress core already exists
if [ -d "$WP_DIR" ] && [ -f "$WP_DIR/wp-config-sample.php" ] && [ -f "$WP_DIR/wp-settings.php" ]; then
    echo "✅ Existing WordPress installation detected in '$WP_DIR/'."
    echo "⏭️  Skipping version prompt and download."
else
    # Prompt to confirm or update WordPress version
    while true; do
        echo "🔹Current WordPress version is set to: $WP_VERSION"
        read -p "💻 Enter WordPress version to install (press Enter to keep '$WP_VERSION'): " INPUT_WP_VERSION
        INPUT_WP_VERSION=${INPUT_WP_VERSION:-$WP_VERSION}

        # Validate input: must be 'latest' or x.y or x.y.z
        if [[ "$INPUT_WP_VERSION" == "latest" ]] || [[ "$INPUT_WP_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            WP_VERSION="$INPUT_WP_VERSION"
            echo "✅ WordPress version set to: $WP_VERSION"
            break
        else
            echo "❌ Invalid version format. Use 'latest' or semantic version like '6.8' or '6.8.3'."
        fi
    done

    # Strip patch version (third digit) if present, only keep major.minor
    if [[ "$WP_VERSION" != "latest" ]]; then
        WP_VERSION_MAJOR_MINOR=$(echo "$WP_VERSION" | awk -F. '{print $1 "." $2}')
    else
        WP_VERSION_MAJOR_MINOR="latest"
    fi

    echo "ℹ️ Using WordPress archive version: $WP_VERSION_MAJOR_MINOR"

    # Clean any leftover WP dir
    rm -rf "$WP_DIR"
    mkdir -p "$WP_DIR"

    # Detect OS for archive format
    UNAME_OUT="$(uname -s)"
    case "${UNAME_OUT}" in
        Linux*|Darwin*) EXT="tar.gz" ;;
        MINGW*|MSYS*|CYGWIN*|Windows*) EXT="zip" ;;
        *) echo "❌ Unsupported OS: ${UNAME_OUT}"; exit 1 ;;
    esac

    # Build URL
    if [ "$WP_VERSION" = "latest" ]; then
        WP_URL="https://wordpress.org/latest.$EXT"
    else
        WP_URL="https://wordpress.org/wordpress-$WP_VERSION_MAJOR_MINOR.$EXT"
    fi

    ARCHIVE="wordpress.$EXT"
    echo "📥 Downloading WordPress $WP_VERSION_MAJOR_MINOR from $WP_URL ..."
    curl -L -o "$ARCHIVE" -w "%{http_code}" "$WP_URL" > http_status.txt
    STATUS=$(cat http_status.txt)
    rm http_status.txt

    # If download failed, fallback to major.minor or latest
    if [ "$STATUS" != "200" ]; then
        echo "⚠️ $WP_URL not found (status $STATUS). Trying fallback..."
        BASE_VERSION=$(echo "$WP_VERSION" | cut -d. -f1,2)
        FALLBACK_URL="https://wordpress.org/wordpress-$BASE_VERSION.$EXT"
        echo "🔄 Trying $FALLBACK_URL ..."
        curl -L -o "$ARCHIVE" "$FALLBACK_URL" || {
            echo "⚠️ Fallback failed, using latest..."
            curl -L -o "$ARCHIVE" "https://wordpress.org/latest.$EXT"
        }
    fi

    # Validate archive and extract
    if [ "$EXT" = "tar.gz" ]; then
        if ! file "$ARCHIVE" | grep -q "gzip compressed"; then
            echo "❌ Not a valid tar.gz archive"
            exit 1
        fi
        echo "📦 Extracting WordPress..."
        tar -xzf "$ARCHIVE" || { echo "❌ Extraction failed"; exit 1; }
    else
        if ! unzip -tq "$ARCHIVE" >/dev/null 2>&1; then
            echo "❌ Not a valid zip archive"
            exit 1
        fi
        echo "📦 Extracting WordPress..."
        unzip -q "$ARCHIVE" || { echo "❌ Extraction failed"; exit 1; }
    fi

    rm "$ARCHIVE"
    mv wordpress/* "$WP_DIR"/
    rm -rf wordpress

    echo "✅ WordPress $WP_VERSION_MAJOR_MINOR installed in $WP_DIR/"
fi




# Clean bundled plugins
echo "🧹 Cleaning bundled plugins..."
rm -f "$WP_DIR/wp-content/plugins/hello.php"

# Clean bundled themes
echo "🧹 Organizing default themes..."

# Ensure custom themes dir exists
mkdir -p content/themes

THEME_DIR="$WP_DIR/wp-content/themes"

if [ -d "$THEME_DIR" ]; then
    # Try to find latest "twenty*" theme
    LATEST_THEME=$(ls -d "$THEME_DIR"/twenty* 2>/dev/null | sort -V | tail -n 1)

    # Fallback: any theme folder
    if [ -z "$LATEST_THEME" ]; then
        LATEST_THEME=$(find "$THEME_DIR" -maxdepth 1 -mindepth 1 -type d | head -n 1)
    fi

    if [ -n "$LATEST_THEME" ]; then
        THEME_NAME=$(basename "$LATEST_THEME")
        if [ ! -d "content/themes/$THEME_NAME" ]; then
            echo "📂 Moving latest theme ($THEME_NAME) into /content/themes..."
            mv "$LATEST_THEME" "content/themes/"
            echo "✅ $THEME_NAME moved"
        else
            echo "ℹ️ $THEME_NAME already exists in /content/themes, skipping move"
        fi
    else
        echo "⚠️ No theme found to move from $THEME_DIR"
    fi

    # Remove remaining themes in wp-content/themes
    rm -rf "$THEME_DIR"/*
    echo "✅ Removed remaining themes in $THEME_DIR"
else
    echo "⚠️ Theme directory $THEME_DIR does not exist, skipping cleanup"
fi


# ==============================
# Ensure /content/uploads exists
# ==============================
UPLOADS_DIR="content/uploads"

echo "🗂️ Checking uploads directory..."

if [ ! -d "$UPLOADS_DIR" ]; then
  echo "📁 Creating uploads directory at $UPLOADS_DIR..."
  mkdir -p "$UPLOADS_DIR" || { echo "❌ Failed to create $UPLOADS_DIR"; exit 1; }
else
  echo "✅ Uploads directory already exists."
fi

# Set writable permissions (Linux/macOS/XAMPP-safe)
echo "🔒 Setting correct permissions for uploads..."
chmod -R 755 content 2>/dev/null || true
chmod -R 775 "$UPLOADS_DIR" 2>/dev/null || true

# Create a blank index.php file to prevent directory listing
INDEX_FILE="$UPLOADS_DIR/index.php"
if [ ! -f "$INDEX_FILE" ]; then
  echo "🧩 Creating blank index.php inside uploads..."
  echo "<?php // Silence is golden. ?>" > "$INDEX_FILE"
else
  echo "✅ index.php already exists in uploads."
fi

# On Windows/XAMPP (Git Bash or WSL) this may not apply,
# so we check writeability manually
if [ ! -w "$UPLOADS_DIR" ]; then
  echo "⚠️  $UPLOADS_DIR is not writable. Please adjust folder permissions manually."
else
  echo "✅ $UPLOADS_DIR is writable."
fi




# === Auth.json Setup for ACF Pro + Gravity Forms ===
# Username: license key / Password: Site URL
if [ ! -f "auth.json" ]; then
  echo "🔐 Setting up Composer auth.json for ACF Pro + Gravity Forms"

  # Prompt with defaults
  read -p "💻 Enter your ACF Pro license key [${DEFAULT_ACF_KEY}]: " ACF_KEY
  ACF_KEY=${ACF_KEY:-$DEFAULT_ACF_KEY}

  read -p "💻 Enter your Gravity Forms license key [${DEFAULT_GF_KEY}]: " GF_KEY
  GF_KEY=${GF_KEY:-$DEFAULT_GF_KEY}

  read -p "💻 Enter your site URL [${DEFAULT_SITE_URL}]: " SITE_URL
  SITE_URL=${SITE_URL:-$DEFAULT_SITE_URL}

  if [ -z "$ACF_KEY" ] && [ -z "$GF_KEY" ]; then
    echo "ℹ️ Skipping auth.json (no license keys provided)"
  else
    # Build JSON dynamically
    AUTH_CONTENT="{\n    \"http-basic\": {"
    SEP=""

    if [ -n "$ACF_KEY" ]; then
      AUTH_CONTENT="$AUTH_CONTENT\n        \"connect.advancedcustomfields.com\": {\n            \"username\": \"$ACF_KEY\",\n            \"password\": \"$SITE_URL\"\n        }"
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

# if ! grep -q "\"password\": \"null\"" auth.json; then
#   echo "❌ ACF password must be 'null'" && exit 1
# fi

if ! grep -q "composer.gravity.io" auth.json; then
  echo "❌ Missing Gravity Forms entry in auth.json" && exit 1
fi

if ! grep -q "${GF_SITE}" auth.json; then
  echo "❌ Gravity Forms site URL does not match expected value" && exit 1
fi

echo "✅ auth.json validated successfully."



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




# Install Composer dependencies
echo "🎼 Installing Composer dependencies (plugins) ..."
composer install



# =============================
# Create environment config files
# =============================

echo "🌍 Creating environment config templates..."

# Create environment configs
if [ ! -f "local-config.php" ]; then
    #echo "⚙️ No local-config.php found."
    #echo "🔹Let's create environment config files (local, staging, production)..."

    # Prompt for local DB credentials
    read -p "⚙️ Database name: " DB_NAME
    read -p "⚙️ Database user [root]: " DB_USER
    DB_USER=${DB_USER:-root}

    read -s -p "⚙️ Database password: " DB_PASSWORD
    echo
    read -p "⚙️ Database host [localhost]: " DB_HOST
    DB_HOST=${DB_HOST:-localhost}

    read -p "⚙️ Table prefix [wp_]: " TABLE_PREFIX
    TABLE_PREFIX=${TABLE_PREFIX:-wp_}

    echo "🔑 Fetching WordPress salts..."
    SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

    ENVIRONMENTS=("local" "staging" "production")

    CONFIG_DIR="config"

    # Ensure the config directory exists
    mkdir -p "${CONFIG_DIR}"

    for ENV in "${ENVIRONMENTS[@]}"; do
        echo "📄 Creating ${ENV}-config.php..."

        CONFIG_FILE="${CONFIG_DIR}/${ENV}-config.php"

        # Set DB values depending on environment
        if [ "$ENV" = "local" ]; then
            DBN=$DB_NAME
            DBU=$DB_USER
            DBP=$DB_PASSWORD
            DBH=$DB_HOST
            DEBUG="true"
            LOG="true"
            DISPLAY="true"
            ERRORS=1
        elif [ "$ENV" = "staging" ]; then
            DBN=""
            DBU=""
            DBP=""
            DBH="localhost"
            DEBUG="true"
            LOG="true"
            DISPLAY="false"
            ERRORS=0
        else # production
            DBN=""
            DBU=""
            DBP=""
            DBH="localhost"
            DEBUG="false"
            LOG="false"
            DISPLAY="false"
            ERRORS=0
        fi

        cat > "${CONFIG_FILE}" <<EOL
<?php
// ${ENV^} environment configuration
define( 'DB_NAME', '${DBN}' );
define( 'DB_USER', '${DBU}' );
define( 'DB_PASSWORD', '${DBP}' );
define( 'DB_HOST', '${DBH}' );
\$table_prefix = '${TABLE_PREFIX}';

define( 'WP_DEBUG', ${DEBUG} );
define( 'WP_DEBUG_LOG', ${LOG} );
define( 'WP_DEBUG_DISPLAY', ${DISPLAY} );
ini_set( 'display_errors', ${ERRORS} );

define( 'ACF_PRO_LICENSE', '${ACF_KEY}' );
define( 'GF_LICENSE_KEY', '${GF_KEY}' );

// WordPress salts
${SALTS}
EOL

    echo "✅ ${ENV}-config.php created."

    done

    echo "✅ All environment configs created: local, staging, and production."
fi




    # Create mu-plugins folder if it doesn't exist
    mkdir -p content/mu-plugins

    # Generate license-sync.php
    cat > content/mu-plugins/license-sync.php <<EOL
<?php
/**
 * Plugin Name: License Key Sync
 * Description: Sync Gravity Forms license keys from local-config.php constants into the database. Executes once per site.
 */

// Exit if accessed directly
if (!defined('ABSPATH')) {
    exit;
}

add_action('admin_init', function() {
    // Only run once
    if (get_option('mu_license_sync_done')) {
        return; // Already synced
    }

    // --- Gravity Forms ---
    if (defined('GF_LICENSE_KEY') && GF_LICENSE_KEY) {
        \$stored = get_option('gravityforms_license_key');
        if (\$stored !== GF_LICENSE_KEY) {
            update_option('gravityforms_license_key', GF_LICENSE_KEY);
        }
    }

    // Mark as done so it won't run again
    update_option('mu_license_sync_done', 1);
});
EOL

    echo "✅ license-sync.php MU-plugin created"


# ---------------------------------------------------------------------
# Create or update .htaccess
# ---------------------------------------------------------------------

HTACCESS_FILE=".htaccess"

echo ""
echo "🧱 Setting up .htaccess rewrite rules for WordPress ($WP_DIR)..."

# Define the .htaccess content (hybrid-safe)
cat > "$HTACCESS_FILE" <<EOF
<IfModule mod_rewrite.c>
RewriteEngine On

# --- Direct routes ---
# Redirect /admin → /wp/wp-admin
RewriteRule ^admin$ wp/wp-admin/ [R=301,L]

# --- Serve favicon and similar assets directly ---
RewriteCond %{REQUEST_FILENAME} -f
RewriteRule ^(favicon\.(ico|svg|png))$ $1 [L]
</IfModule>

# BEGIN WordPress
# The directives (lines) between "BEGIN WordPress" and "END WordPress" are
# dynamically generated, and should only be modified via WordPress filters.
# Any changes to the directives between these markers will be overwritten.
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
EOF

# Confirm write
if [ -f "$HTACCESS_FILE" ]; then
  echo "✅ .htaccess has been created/updated successfully."
else
  echo "❌ Failed to write .htaccess. Please check permissions."
fi



    # Prompt to create the database
    read -p "💻 Create this database locally? (y/n) [y]: " CREATE_DB
    CREATE_DB=${CREATE_DB:-y}

    if [ "$CREATE_DB" = "y" ]; then
      echo "🔹Creating database '${DB_NAME}' on host '${DB_HOST}'..."

      # Prompt for root MySQL password (hidden input)
      read -s -p "⚙️ MySQL root password: " MYSQL_ROOT_PASS
      echo

      # Try creating the database
      "${MYSQL_EXE}" -u root -p"${MYSQL_ROOT_PASS}" -h "${DB_HOST}" -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

      if [ $? -eq 0 ]; then
        echo "✅ Database '${DB_NAME}' created (or already exists)"
      else
        echo "❌ Failed to create database. Please check credentials and permissions."
      fi
    fi



echo "🎉 Setup complete!"
echo "⚠️ Don't forget to update hosts, apache/vhosts and SSL cert."
echo "⚠️ You should also delete this setup.sh file after running it."
echo "✅ Ciao. Adios. Goodnight!"
