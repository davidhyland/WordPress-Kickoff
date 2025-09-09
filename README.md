# WordPress Skeleton

This is simply a skeleton repo for a WordPress site, forked from https://github.com/markjaquith/WordPress-Skeleton. 
Clone it to jump-start your WordPress site repos, or fork it and customize it to your own liking!

## Assumptions

* WordPress as a Git submodule in `/wp/`
* Custom content directory in `/content/` (cleaner, and also because it can't be in `/wp/`)
* `wp-config.php` in the root (because it can't be in `/wp/`)
* Composer is installed - https://getcomposer.org/

## Installation

* Clone this repo with submodules included (the WP core): 
  `git clone --recurse-submodules https://github.com/davidhyland/WordPress-Starter.git .`
  Note the final `.` which clones the files into the folder root. Replace with `foldername` if desired. Destination folder must be empty.
* Open Git Bash (or a Git Bash terminal in VSC) and run setup: `./setup.sh`
* Script will take a minute. Be patient. Have a cup of tea.



## Questions & Answers

**Q:** Will you accept pull requests?  
**A:** Maybe — if I think the change is useful. I primarily made this for my own use, and thought people might find it useful. If you want to take it in a different direction and make your own customized skeleton, then just maintain your own fork.

**Q:** Why the `/shared/` symlink stuff for uploads?  
**A:** For local development, create `/shared/` (it is ignored by Git), and have the files live there. For production, have your deploy script symlink `/shared/` to some outside-the-repo location (like an NFS shared directory or something). This gives you separation between Git-managed code and uploaded files.

**Q:** What version of WordPress does this track?  
**A:** The latest stable release. It should automatically update within 6 hours of a new WordPress stable release. Open an issue if that doesn't happen.

**Q:** What's the deal with `local-config.php`?  
**A:** It is for local development, which might have different MySQL credentials or do things like enable query saving or debug mode. This file is ignored by Git, so it doesn't accidentally get checked in. If the file does not exist (which it shouldn't, in production), then WordPress will use the DB credentials defined in `wp-config.php`.

**Q:** What is `memcached.php`?  
**A:** This is for people using memcached as an object cache backend. It should be something like: `<?php return array( "server01:11211", "server02:11211" ); ?>`. Programattic generation of this file is recommended.

**Q:** Does this support WordPress in multisite mode?  
**A:** Yes, as of WordPress v3.5 which was released in December, 2012.
