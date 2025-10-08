<?php
// SET ENVIRONMENT CONSTANT

if( 'domain.com' == $_SERVER['SERVER_NAME'] ) {
	define( 'ENV', 'production' );
}
elseif ( 'staging.domain.com' == $_SERVER['SERVER_NAME'] ) {
	define( 'ENV', 'staging' );
}
elseif ( 'local.mcdill.kenmore' == $_SERVER['SERVER_NAME'] ) {
	define( 'ENV', 'local' );
}
else {
	define( 'ENV', 'production' );
}


// =========================================================
// Path & URL configuration for WordPress in /wp directory
// =========================================================

// --- Root path (one directory above wp-config.php)
$root_dir = dirname(__FILE__);

// --- WordPress core directory
$wp_dir = $root_dir . '/wp';

// --- Site URLs
define( 'WP_HOME', 'https://' . $_SERVER['HTTP_HOST'] );
define( 'WP_SITEURL', WP_HOME . '/wp' );

// --- Custom content directory
define( 'WP_CONTENT_DIR', $root_dir . '/content' );
define( 'WP_CONTENT_URL', WP_HOME . '/content' );

// --- Uploads directory (relative to root, not /wp)
define( 'UPLOADS', 'content/uploads' );
define( 'UPLOADS_URL', WP_CONTENT_URL . '/uploads' );


// ===================================================
// Load database info and local development parameters
// ===================================================
if ( file_exists( __DIR__ . '/local-config.php' ) && 'local' === ENV ) {
    include __DIR__ . '/local-config.php';
} elseif ( file_exists( __DIR__ . '/staging-config.php' ) && 'staging' === ENV ) {
    include __DIR__ . '/staging-config.php';
} elseif ( file_exists( __DIR__ . '/production-config.php') && 'production' === ENV ) {
    include __DIR__ . '/production-config.php';
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
require_once( ABSPATH . 'wp-settings.php' );
