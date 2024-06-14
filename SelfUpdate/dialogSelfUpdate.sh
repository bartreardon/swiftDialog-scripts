#!/bin/zsh

# This script will check for the presence of swiftDialog and install it if it is not found or if
# the version is below a specified minimum version.
#   If swiftDialog is not found, it will download the latest version from the swiftDialog GitHub repo
#    and install it.
#   If swiftDialog is found, it will check the version and if it is below the specified minimum
#    version, it will download the latest version from the swiftDialog GitHub repo and install it.
#   If swiftDialog is found and the version is at or above the specified minimum version, it will
#    do nothing and exit.

# No warranty expressed or implied. Use at your own risk.
# Feel free to modify for your own environment.

autoload is-at-least
debugmode=false

# Check for debug mode
if [[ $1 == "debug" ]]; then
	debugmode=true
fi

function versionFromGit() {
	local dialogVersion=$(curl --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/tag_name/ { print \$4; exit }")
	# tag is usually v1.2.3 so we need to extract the version number
	local numeric_version=$(echo "$dialogVersion" | sed 's/[^0-9.]*//g')
	if [[ ! "$numeric_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  		echo "Unexpected version format: $dialogVersion"
  		exit 1
	fi
	echo $numeric_version
}

function localVersion() {
	local dialogApp="/Library/Application Support/Dialog/Dialog.app"
	local installedappversion=$(defaults read "${dialogApp}/Contents/Info.plist" CFBundleShortVersionString || echo 0)
	echo $installedappversion
}

function dialogCheck() {
	local installedappversion=$(localVersion)
	local requiredVersion=0
	if [[ -n $1 ]]; then
		requiredVersion=$1
	fi 
	if [[ $requiredVersion == "latest" ]]; then
		requiredVersion=$(versionFromGit)
		echo "Latest available version of swiftDialog is $requiredVersion"
	fi

	# Check for swiftDialog and install if not found
	echo "Checking required version $requiredVersion against installed version $installedappversion"
	if is-at-least $requiredVersion $installedappversion; then
		echo "swiftDialog found or already up to date. Installed version: $installedappversion Required version: $requiredVersion"
	else
		if $debugmode; then
			echo "Debug mode enabled. Not downloading or installing swiftDialog."
			echo "Installed version: $installedappversion"
			echo "Required version: $requiredVersion"		
		else
			echo "swiftDialog not found or below required version. Installed version: $installedappversion Required version: $requiredVersion"
			dialogInstall
		fi
	fi
}

function dialogInstall() {
	# Get the URL of the latest PKG From the Dialog GitHub repo
	local dialogURL=$(curl --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
	# Expected Team ID of the downloaded PKG
	local expectedDialogTeamID="PWA5E9TQ59"
	
	# Create temporary working directory
	local workDirectory=$( /usr/bin/basename "$0" )
	local tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
	# Download the installer package
	echo "Downloading swiftDialog from $dialogURL ..."
	/usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
	echo "Download complete."
	# Verify the download
	echo "Verifying..."
	local teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
	# Install the package if Team ID validates
	if [[ "$expectedDialogTeamID" == "$teamID" ]] || [[ "$expectedDialogTeamID" == "" ]]; then
		echo "Validated package Team ID: $teamID"
		echo "Installing swiftDialog..."
		/usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
		echo "Installation complete."
		echo "Local version: $(localVersion)"
	else
		echo "Downloaded package does not have expected Team ID. Exiting."
		exit 1
	fi
	# Remove the temporary working directory when done
	/bin/rm -Rf "$tempDirectory"
}

## Usage:
# dialogCheck [version|latest]
# version: Optional. The minimum version of swiftDialog that should be installed. If not provided, the latest version will be installed.

## Examples (uncomment to run):

## this will just check to see if swiftDialog is installed and if not, install the latest version
# echo "checking with no version"
# dialogCheck

## this will check to see if swiftDialog is at a mimimum version of 1.9
#echo "checking with version 1.9"
#dialogCheck 1.9

## this will check for a version that does not (yet) exist. until this version is released it will always run the download and install.
#echo "checking with version 10.0"
#dialogCheck 10.0

## this will check for the latest version of swiftDialog and print the version number
#echo "checking for latest version"
#latest=$(versionFromGit)

## Default in case anyone runs the script without any arguments
dialogCheck latest