#!/bin/sh

# simple shell script wrapper around AppleScript to add tasks to the Omnifocus
# inbox, the syntax is:
#
# Action! @Context ::Project #Start #Due $Duration //Note
#

OSA=`which osascript`
${OSA} <<EOS
set theName to ("${@}")
set isRunning to false
tell application "System Events"
  if exists process "OmniFocus" then
    set isRunning to true
  end if
end tell

if isRunning is true then
  tell application "OmniFocus"
    parse tasks into default document with transport text theName with as single task
  end tell
else
  tell application "OmniFocus" to activate
  tell application "OmniFocus"
    parse tasks into default document with transport text theName with as single task
  end tell
end if
EOS

