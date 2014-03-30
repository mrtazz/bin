#!/bin/sh
#
# Backup script to pull in changes from remote hosts
#
for backup in $(ls /backup); do
  grep -q ${backup} ~/.backupexcludes
  if [ $? != 0 ]; then
    /usr/local/bin/rsync -e 'ssh -o BatchMode=yes -o ConnectTimeout=10' --archive --delete --timeout=5 ${backup}:. /backup/${backup}/
  fi
done
