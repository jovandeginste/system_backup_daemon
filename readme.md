# System backup daemon
Author: Jo Vandeginste

This project enables you to make easy backups of your different systems.

## Features:
* configurable cycles
* multiple ips per host
* snapshots (+ auto-cleanup)
* notification mails

## Todo
* configuration tests
* extra parameters
 * base configuration directory

# Getting started

* put all the code in a single directory, eg. ```/usr/local/backup```
* write your configuration (examples in ./config)
* start the daemon:
 * ```./backup -n -D``` will dump the config
 * ```./backup``` will just run it (and try to perform backups!)

# Make this daemon start automatically

## Ubuntu

(as root)

Copy the upstart config file:
	cp backup.init.conf /etc/init/backup.conf

Make a symlink for the init.d script:
	ln -s /lib/init/upstart-job /etc/init.d/backup

Let the system make the necessary symlinks:
	update-rc.d backup defaults

# License
Distributed under Apache License, Version 2.0

Read it here:
* [license.txt](license.txt)
* [apache license (txt)](http://www.apache.org/licenses/LICENSE-2.0.txt)
* [apache license (html)](http://www.apache.org/licenses/LICENSE-2.0.html)

