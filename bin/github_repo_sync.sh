#!/bin/sh

# take a list of git clone urls on STDIN and clone them if they don't exist.

if [ -z $1 ]; then
  echo "github_repo_sync.sh directory"
  exit 1
fi

GIT=$(which git)

if [ -z ${GIT} ]; then
  # if git is not in path fall back to /usr/local
  if [ -f /usr/local/bin/git ]; then
    GIT="/usr/local/bin/git"
  else
    echo "You need to have git installed."
    exit 1
  fi
fi

# switch to archive directory
cd $1

while read line; do
  directory=$(echo "${line}" | cut -d "/" -f 5)

  if [ ! -d ${directory} ]; then
    ${GIT} clone --mirror ${line}
  else
    cd ${directory}
    ${GIT} fetch -p origin
    cd ..
  fi

done
