#!/bin/zsh
# Short script that will take a list of defined app bundle ID's and if detected will cause the script to exit
# Useful if you want to perform some action that will have user impact (e.g. display a message or force some interaction)
# but not take that action if a user is using a particular application, e.g. on an active video conference. 

# array of bundleID's that will cause this script to exit if they are detected as being the frontmost app.
DNDApps=(
    "com.webex.meetingmanager"
    "com.microsoft.teams"
    "com.microsoft.VSCode"
    "us.zoom.xos"
)

# when testing, enter in a number of seconds to sleep. this allows you to trigger the script, bring an app
# to be in focus and verify it's being detected correctly.
if [[ $1 =~ '^[0-9]+$' ]] ; then
   sleep $1 
fi

# get the frontmost app and isolate the bundle id
appInFront=$(lsappinfo info $(lsappinfo front) | grep "bundleID" | awk -F "=" '{print $NF}' | tr -d "\"")

echo "$appInFront is in front"
echo "Checking against $DNDApps"

if (($DNDApps[(I)$appInFront])); then
  echo "$appInFront is in front and was detected - exiting"
  exit 0
fi
