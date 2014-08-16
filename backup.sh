#!/bin/sh
#
# Backup script to pull in changes from remote hosts
#
if [ "z$1" = "z--verbose" ]; then
  ARG="-v"
fi

for backup in $(ls /backup); do
  grep -q ${backup} ~/.backupexcludes
  if [ $? != 0 ]; then
    /usr/local/bin/rsync ${ARG} -e 'ssh -o BatchMode=yes -o ConnectTimeout=20' --archive --delete --timeout=20 ${backup}:. /backup/${backup}/
  fi
done
