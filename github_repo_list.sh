#!/bin/sh

# Usage:
# github_repo_list.sh mrtazz [34345k34j3k4b2jk3]
#
# get a list of all public repos for a user
if [ -z $1 ]; then
  echo "Usage:"
  echo "github_repo_list.sh USERNAME [TOKEN]"
  exit 1
fi

if [ ! -z $2 ]; then
  TOKEN="&access_token=${2}"
fi

CURL=$(which curl)
if [ -z ${CURL} ]; then
  # fall back to /usr/local/bin/curl
  CURL="/usr/local/bin/curl"
fi

BASEURL="https://api.github.com/users/${1}/repos?type=owner${TOKEN}"
count=1

while [ ${count} -gt 0 ]; do

  lines=$(${CURL} "${BASEURL}&page=${count}" -s | grep git_url | cut -d" " -f6 | sed -e "s/[\",]//g")

  # stop if we don't get any more content. A bit hacky but I don't want to
  # parse HTTP header data to figure out the last page
  if [ "${lines}" == "" ]; then
    count=0
  else
    for line in ${lines}; do echo ${line} ; done
    count=`expr $count + 1`
  fi

done
