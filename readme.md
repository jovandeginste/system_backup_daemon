# System backup daemon
Author: Jo Vandeginste

This project enables you to make easy backups of your different systems.
The clients are basically platform independent - as long as they support rsync. I use this script to make backups of the following systems:
* backup server itself (Ubuntu Desktop)
* mediacenter PC (Ubuntu Desktop)
* remote web server (Ubuntu Server)
* OpenELEC.tv installation (OpenELEC.tv)
* laptop (Documents and Users directories only) (Windows 7)
* Asus EEE Pad Transformer TF101 (Android 3.1)
* HTC Wildfire (Android 2.2)

## Features:
* templates for backup cycles and filesets
* multiple ips per host, each with its own cycle
* incremental snapshots (+ auto-cleanup)
* notification mails

## Todo
* improve documentation :-)
* implement configuration tests
* support non-root user
* extra parameters
 * base configuration directory
* support for other types
 * MySQL dumps

# Getting started
## The server

* put all the code in a single directory, eg. ```/usr/local/backup```
* write your configuration (examples in ./config)
* start the daemon:
 * ```./backup -n -D``` will dump the config
 * ```./backup``` will just run it (and try to perform backups!)

## Make this daemon start automatically

### Ubuntu

(as root)

Copy the upstart config file:
```bash
cp backup.init.conf /etc/init/backup.conf
```

Make a symlink for the init.d script:
```bash
ln -s /lib/init/upstart-job /etc/init.d/backup
```

Let the system make the necessary symlinks:
```bash
update-rc.d backup defaults
```

## The clients

Add each client to the configuration files

### Linux
This is fairly straight forward. Make sure the user running the backup script can ssh directly to your
host without password prompt (preferably as root) and run the rsync binary there.

Sample configuration (partial):
```yaml
---
my_linux_host:
  contact: me@mydomain.com
  cycle: Weekly
  connect: my_linux_host
  mode: linux
  fileset: linux
```

### Windows
More complicated than linux. I use a Windows rsync daemon (ICW / cwRsync), running as a service.

Sample configuration (partial):
```yaml
---
my_windows_host:
  contact: me@mydomain.com
  cycle: Daily
  connect:
    my_windows_host: {}

    my_windows_host_on_wifi:
      cycle: TripleDaily
  mode: windows
  fileset: docs_and_user_dirs
```

This implies a fileset with the name ```docs_and_user_dirs```, eg.:

```yaml
---
docs_and_user_dirs:
  excludes:
  - c/Users/my_user/AppData/Local/Temp
  includes:
  - root/c/my_user
  - root/d/Documents
```

Maybe "*" works instead of "my_user"?

### Android
This requires a rooted device, running an ssh server (eg. DropBear SSH Server) and the (manual) copying of an rsync binary to your device.

I put the binary here: ```/system/xbin/rsync```

Make sure your backup server can ssh to the device as root without a password prompt!

Sample configuration (partial):
```yaml
---
transformer:
  rsync_path: /system/xbin/rsync
  contact: me@mydomain.com
  cycle: TripleDaily
  connect: transformer
  mode: linux
  fileset: android
```

Again, a fileset "android" is implied:
```yaml
android:
  excludes:
  - /acct
  - /proc
  - /dev
  - /sys
  - /tmp
  - /mnt
  - /Removable
  includes:
  - /
```

# License
Distributed under Apache License, Version 2.0

Read it here:
* [license.txt](license.txt)
* [apache license (txt)](http://www.apache.org/licenses/LICENSE-2.0.txt)
* [apache license (html)](http://www.apache.org/licenses/LICENSE-2.0.html)

