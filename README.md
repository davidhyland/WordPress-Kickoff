# WordPress KickOff

This is simply a skeleton repo for a WordPress site inspired by https://github.com/markjaquith/WordPress-Skeleton.
Clone it to jump-start your WordPress site repos, or fork it and customize it to your own liking!
The original version included a submodule of WordPress but this loads the latest official release

## Notes

* WordPress core in `/wp/` 
* All content in `/content/` (plugins, themes, uploads, etc)
* `wp-config.php` in the root (because it can't be in `/wp/`)
* Composer should be ideally installed but the script will attempt to install it if needed
* https://getcomposer.org/

## Installation

* Clone this repo with submodules included (the WP core):

`git clone https://github.com/davidhyland/WordPress-Kickoff.git .`

  Note the final `.` which clones the files into the folder root. Replace with `foldername` if desired. Destination folder must be empty.

* Edit setup.sh and change the default license keys and site URL as needed. Prompts are given to confirm these
* Specify the Wordpress version if necessary. Defaults to latest stable release.
* Also update the MYSQL_EXE constant with the local mysql.exe path, if auto creation of database is desired
* Open Git Bash (or a Git Bash terminal in VSC) and run setup. 

`./setup.sh`

* This script takes around a minute to complete and will:

  * Download the latest WordPress core (unless version is specified) removing default plugins and themes
  * Prompt for and create auth.json for secure premium plugins
  * Install all required plugins via Composer, installing Composer if needed
  * Prompt for and create local-config.php with provided database details
  * Create staging and production config files, just needs database details to be added later
  * Create .htaccess with specific rules for this WP structure
  * Optionally create the local mysql database

## Updating

* To update the config make your changes to composer.json then run `composer update --no-install` to update composer.lock
* Commit and push

## Questions & Answers

**Q:** What version of WordPress does this load?  
**A:** The latest stable release by default. Version can be overridden in the WP_VERSION constant in setup.sh

**Q:** What's the deal with `local-config.php`?  
**A:** It is for local development, which might have different MySQL credentials or do things like enable query saving or debug mode. This file is ignored by Git, so it doesn't accidentally get checked in. If the file does not exist (which it shouldn't, in production), then WordPress will use the DB credentials defined in `wp-config.php`.
