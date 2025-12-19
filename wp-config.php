<?php
// SET ENVIRONMENT CONSTANT
if( 'domain.com' == $_SERVER['SERVER_NAME'] ) {
	define( 'ENV', 'production' );
}
elseif ( 'staging.domain.com' == $_SERVER['SERVER_NAME'] ) {
	define( 'ENV', 'staging' );
}
elseif ( 'local.mcdill.xyz' == $_SERVER['SERVER_NAME'] ) {
	define( 'ENV', 'local' );
}
else {
	define( 'ENV', 'production' );
}


// Safety check: ensure WordPress is loading this config, not one from /wp/
if ( defined( 'ABSPATH' ) && strpos( __FILE__, '/wp/' ) !== false ) {
    error_log( '⚠️ WordPress is loading config from /wp/ instead of root: ' . __FILE__ );
    die( 'Configuration error: wrong wp-config.php loaded.' );
}


// =========================================================
// Path & URL configuration for WordPress in /wp directory
// =========================================================

// --- Root path (one directory above wp-config.php)
$root_dir = str_replace('\\', '/', dirname(__FILE__));

// --- WordPress core directory
$wp_dir = $root_dir . '/wp';

// --- Site URLs
define( 'WP_HOME', 'https://' . $_SERVER['HTTP_HOST'] ); // Root URL
define( 'WP_SITEURL', WP_HOME . '/wp' ); // WP Core URL

// --- Custom content directory
define( 'WP_CONTENT_DIR', $root_dir . '/content' );
define( 'WP_CONTENT_URL', WP_HOME . '/content' );


// ===================================================
// Load database info and local development parameters
// ===================================================
if ( file_exists( __DIR__ . '/config/local-config.php' ) && 'local' === ENV ) {
    include __DIR__ . '/config/local-config.php';
} elseif ( file_exists( __DIR__ . '/config/staging-config.php' ) && 'staging' === ENV ) {
    include __DIR__ . '/config/staging-config.php';
} elseif ( file_exists( __DIR__ . '/config/production-config.php') && 'production' === ENV ) {
    include __DIR__ . '/config/production-config.php';
}


// ================================================
// You almost certainly do not want to change these
// ================================================
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );


// ================================
// Language
// Leave blank for American English
// ================================
define( 'WPLANG', '' );




// ======================================
// Load a Memcached config if we have one
// ======================================
if ( file_exists( dirname( __FILE__ ) . '/memcached.php' ) )
	$memcached_servers = include( dirname( __FILE__ ) . '/memcached.php' );

// ===========================================================================================
// This can be used to programatically set the stage when deploying (e.g. production, staging)
// ===========================================================================================
define( 'WP_STAGE', '%%WP_STAGE%%' );
define( 'STAGING_DOMAIN', '%%WP_STAGING_DOMAIN%%' ); // Does magic in WP Stack to handle staging domain rewriting

// ===================
// Bootstrap WordPress
// ===================
if ( !defined('ABSPATH') ) {
    define( 'ABSPATH', $wp_dir . '/' );
}
if ( !defined('ABSPATH') ) {
    define( 'ABSPATH', $wp_dir . '/' );
}
require_once( ABSPATH . 'wp-settings.php' );