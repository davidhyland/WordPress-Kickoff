# WordPress Skeleton

This is simply a skeleton repo for a WordPress site, forked from https://github.com/markjaquith/WordPress-Skeleton. 
Clone it to jump-start your WordPress site repos, or fork it and customize it to your own liking!
The original version includes all default WordPress themes since twentyten so this includes my reduced WordPress core fork

## Assumptions

* WordPress as a Git submodule in `/wp/`
* Custom content directory in `/content/` (cleaner, and also because it can't be in `/wp/`)
* `wp-config.php` in the root (because it can't be in `/wp/`)
* Composer is installed - https://getcomposer.org/

## Installation

* Clone this repo with submodules included (the WP core):

`git clone https://github.com/davidhyland/WordPress-Starter.git .`

  Note the final `.` which clones the files into the folder root. Replace with `foldername` if desired. Destination folder must be empty.

* Edit setup.sh and change the default license keys and site URL as needed. Prompts are given to confirm these
* Also update the MYSQL_EXE constant with the local mysql.exe path, if auto creation of database is desired
* Open Git Bash (or a Git Bash terminal in VSC) and run setup. 

`./setup.sh`

* This script takes around a minute to complete and will:

  * Download the WordPress submodule core
  * Prompt for and create auth.json for secure premium plugins
  * Install all required plugins via Composer, installing Composer if needed
  * Prompt for and create local-config.php with provided database details
  * Optionally create the local mysql database

## Updating

* To update the config make your changes to composer.json then run `composer update --no-install` to update composer.lock
* Commit and push

## Questions & Answers

**Q:** What version of WordPress does this track?  
**A:** The latest stable release. It should automatically update within 6 hours of a new WordPress stable release. Open an issue if that doesn't happen.

**Q:** What's the deal with `local-config.php`?  
**A:** It is for local development, which might have different MySQL credentials or do things like enable query saving or debug mode. This file is ignored by Git, so it doesn't accidentally get checked in. If the file does not exist (which it shouldn't, in production), then WordPress will use the DB credentials defined in `wp-config.php`.
