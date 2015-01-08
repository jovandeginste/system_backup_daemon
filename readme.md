# System backup daemon
Author: Jo Vandeginste

This project enables you to make easy selected, scheduled, incremental backups of your different systems.
The clients are basically platform independent - as long as they support rsync. I use this script to make backups of the following systems:
* backup server itself (Ubuntu Desktop)
* mediacenter PC (Ubuntu Desktop)
* remote web server (Ubuntu Server)
* OpenELEC.tv installation (OpenELEC.tv)
* Asus EEE Pad Transformer TF101 (Android 4.4)

Windows is also supported, but I no longer use that.

## Features:
* templates for backup cycles and filesets
* multiple ips per host, each with its own cycle, eg.:
 * frequent backups over LAN
 * less frequent when over WiFi
 * finally try over VPN if it has really been a long time
* incremental snapshots (+ auto-cleanup of old snapshots)
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

### Prepare the directories
* put all the code in a single directory, eg. ```/usr/local/backup```
* write your configuration (examples in ./config), either
 * in ```/etc/backup```
 * in ```/usr/local/backup/config```
* start the daemon:
 * ```./backup -n -D``` will dump the config - check for errors!
 * ```./backup``` will just run it (and try to perform backups!)

### Make this daemon start automatically

#### Ubuntu

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
host without password prompt (preferably as root) and run the rsync binary there - learn about SSH public/private keys.

Sample configuration (partial):
```yaml
---
my_linux_host:
  contact: me@mydomain.com
  cycle: Weekly
  connect: my_linux_host
  mode: linux
  fileset: fs_linux
```
This implies a fileset with the name ```fs_linux```. A fairly extensive example:

```fs_linux.yaml```

```yaml
---
:excludes: 
- /proc
- /dev
- /sys
- /tmp
- /media
- /mnt
- /home/*/.gvfs
- /home/*/.ccache*
- /home/*/.cache*
- /home/*/tmp
- /var/lib/mysql
- /usr/local/mysql
- /run
- /var/run
- /var/cache
- /var/lib/docker
:includes: 
- /
```

### Windows
More complicated than linux. I used a Windows rsync daemon (ICW / cwRsync), running as a service.

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
  fileset: fs_docs_and_user_dirs
```

This implies a fileset with the name ```fs_docs_and_user_dirs```, eg.:

```fs_docs_and_user_dirs.yaml```

```yaml
---
excludes:
- root/c/Users/my_user/AppData/Local/Temp
includes:
- root/c/Users/my_user
- root/d/Documents
```

Maybe "*" works instead of "my_user"?

### Android
This requires a rooted device, running an sftp server (eg. https://play.google.com/store/apps/details?id=web.oss.sshsftpDaemon). If the app does not provide one, you can copy the rsync binary manually to your device.

Again, make sure your backup server can ssh to the device as root without a password prompt!

Sample configuration (partial):
```yaml
---
transformer:
  rsync_path: /system/xbin/rsync
  contact: me@mydomain.com
  cycle: TripleDaily
  connect: transformer
  mode: linux
  fileset: fs_android
```

Again, a fileset "fs_android" is implied:
```fs_android.yaml```

```yaml
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
