#!/bin/zsh

autoload is-at-least

function dialogCheck(){
	local dialogApp="/Library/Application Support/Dialog/Dialog.app"
	local installedappversion=$(defaults read "/Library/Application Support/Dialog/Dialog.app/Contents/Info.plist" CFBundleShortVersionString || echo 0)
	local requiredVersion=0
	if [ ! -z $1 ]; then
		requiredVersion=$1
	fi 

	# Check for Dialog and install if not found
	is-at-least $requiredVersion $installedappversion
	local result=$?
	if [ ! -e "${dialogApp}" ] || [ $result -ne 0 ]; then
		dialogInstall
	else
		echo "Dialog found or already up to date. Proceeding..."
	fi
}

function dialogInstall(){
	# Get the URL of the latest PKG From the Dialog GitHub repo
	local dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
	# Expected Team ID of the downloaded PKG
	local expectedDialogTeamID="PWA5E9TQ59"
	
    # Create temporary working directory
    local workDirectory=$( /usr/bin/basename "$0" )
    local tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
    # Download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
    # Verify the download
    local teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
    # Install the package if Team ID validates
    if [ "$expectedDialogTeamID" = "$teamID" ] || [ "$expectedDialogTeamID" = "" ]; then
      /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
    else
      # displayAppleScript # uncomment this if you're using my displayAppleScript function
      # echo "Dialog Team ID verification failed."
      # exit 1 # uncomment this if want script to bail if Dialog install fails
    fi
    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"  
}

# this will just check to see if swiftDialog is installed and if not, install the latest version
echo "checking with no version"
dialogCheck

# this will check to see if swiftDialog is at a mimimum version of 1.9
echo "checking with version 1.9"
dialogCheck 1.9

# this will check for a version that does not (yet) exist. until this version is released it will always run the download and install.
echo "checking with version 2.0"
dialogCheck 2.0
