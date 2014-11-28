#!/bin/sh
#
# Backup script to pull in changes from remote hosts
#
if [ "z$1" = "z--verbose" ]; then
  VERBOSE=1
  ARG="-v"
fi

for backup in $(ls /backup); do
  grep -q ${backup} ~/.backup/excludes
  if [ $? != 0 ]; then
    if [ -f ~/.backup/${backup} ]; then
      for path in $(cat ~/.backup/${backup}); do
        [ ! -z "${VERBOSE}" ] && echo "Backing up ${backup}:${path}..."
        /usr/local/bin/rsync ${ARG} -e 'ssh -o BatchMode=yes -o ConnectTimeout=20' -z --archive --delete --timeout=60 ${backup}:${path}/ /backup/${backup}/${path}/
      done
    else
      [ ! -z "${VERBOSE}" ] && echo "Backing up ${backup}..."
      /usr/local/bin/rsync ${ARG} -e 'ssh -o BatchMode=yes -o ConnectTimeout=20' -z --archive --delete --timeout=60 ${backup}:. /backup/${backup}/
    fi
  fi
done
