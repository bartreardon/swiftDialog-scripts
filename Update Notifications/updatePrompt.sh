#!/bin/zsh

#  nudge like script using dialog to prompt for an OS upgrade
# 
#  Created by Bart Reardon on 15/9/21.
#  Updated 12/9/23
#
# Updated for use with Jamf Pro:
# Parameters:
#  All parameters are optional
# 4 - Required version. Defaults to the latest versions available for the major release of the OS running the script
# 5 - Required By Date in YYYYMMDD format
# 6 - infolink - defaults to https://support.apple.com/en-au/HT201222
# 7 - support text - Extra informational text inserted into the message (e.g. "For help please contact the [Help Desk](https://link.to/helpdesk)" )
# 8 - Icon - defaults to the Apple logo SF symbol
# 9 - swiftDialog version required - defaults to v2.3.2. If installed version is older, swiftDialog will be updated.


macOSLatest() {
    # Determines what the latest available version is of macOS from the passed in major version
    majorversion=$(echo ${1:-$(sw_vers | grep "ProductVersion" | awk '{print $NF}')} | awk -F "." '{print $1}')

    declare -A macosVer=(
    [14]="Sonoma"
    [13]="Ventura"
    [12]="Monterey"
    [11]="Big Sur"
    [10]="Unsupported"
    )
    osName=${macosVer[$majorversion]}

    if [[ $majorversion -gt 10 ]]; then
        macOSLatest=$(curl -sL "https://support.apple.com/en-au/HT201260" | grep -i "<td>macOS ${osName}" -A2 | tail -n1 | sed -e 's/<[^>]*>//g')
        echo ${macOSLatest}
    else 
        echo ""
    fi
}

dialogCheck() {
	local dialogApp="/Library/Application Support/Dialog/Dialog.app"
	local installedappversion=$(defaults read "${dialogApp}/Contents/Info.plist" CFBundleShortVersionString || echo 0)
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
		echo "Dialog found. Proceeding..."
	fi
}

dialogInstall() {
	# Get the URL of the latest PKG From the Dialog GitHub repo
	local dialogURL=$(curl --silent --fail -L "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
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

dialogcli="/usr/local/bin/dialog"
jamfhelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

OSVer=$(sw_vers | grep "ProductVersion" | awk '{print $NF}')
mode=${1}
computerName=${2}
loggedInUser=${3}
requiredOSVer=${4:-$(macOSLatest)}
requiredByDate=${5} # YYYYMMDD format
infolink=${6:-"https://support.apple.com/en-au/HT201222"}
supportText=${7}
macosIcon=${8:-"sf=applelogo"}
dialogVersion=${9:-"2.3.2"}  # required

requiredOSText="the latest version of macOS"
current_date=$(date +'%Y%m%d')

if [[ -z ${requiredOSVer} ]] || [[ "$requiredOSVer" == "Unsupported" ]]; then
    requiredOSVer="100"
else
    requiredOSText="macOS ${requiredOSVer}"
fi

if [[ "$mode" == "test" ]]; then
    OSVer="13.4.0"
fi

autoload is-at-least
if is-at-least ${requiredOSVer} ${OSVer}; then
    # catch if we're already on the build we want
    # is explicit but should catch deployments that haven't checked in to the MDM with the updated OS version
    echo "Device is running ${OSVer}"
    exit 0
else
    echo "Device is running ${OSVer} and needs to be on ${requiredOSVer}"
fi


# check dialog is installed and up to date
dialogCheck "$dialogVersion"

defarralskey="deferrals_${requiredOSVer}"
maxdeferrals="5"
blurscreen="noblur"

requiredby=""
if [[ -n $requiredByDate ]]; then
    if [ "$current_date" -lt  "$requiredByDate" ]; then
        requiredby="This update is required by **$(date -j -f "%Y%m%d" "$requiredByDate" "+%A %B %d, %Y")**"
    else
        requiredby="This update is required **immediately**"
        maxdeferrals="0"
    fi
else
fi

# work out remaining deferrals"
appdomain="au.csiro.macosupdates"
deferrals=$(defaults read ${appdomain} ${defarralskey} || echo ${maxdeferrals})
if [[ $1 == "test" ]]; then
	echo "App domain is ${appdomain}"
	echo "Defferal Key is ${defarralskey}"
	echo "Deferrals is ${deferrals}"
    echo "MAX eferrals is ${maxdeferrals}"
    echo "requiredby is ${requiredby}"
fi

if [[ $deferrals -gt 0 ]]; then
	button2text="Defer ($deferrals remaining)"
else
	button2text="Update Required"
    #blurscreen="blurscreen"
fi

updateselected=0
persistant=0

bannerimage="/Users/${loggedInUser}/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingheader.png"

title="macOS Update Available"
titlefont="shadow=1"
icon="/System/Library/PreferencePanes/SoftwareUpdate.prefPane"
message="## macOS **${requiredOSText}** is available for install

This deviceis running macOS version ${OSVer} 

It is important that you update to **${requiredOSText}** at your earliest convenience. Click the More Information button below for additional details.

${supportText}

**Your swift attention to applying this update is appreciated**

${requiredby}"

infotext="More Information"
icon="/Applications/Software Centre.app"
overlay="caution"
button1text="Open Software Update"
buttona1ction="open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane"
#button2text="Contact the Service Centre"
#button2action="https://go.csiro.au/FwLink/LogAFault"

runDialog () {
    ${dialogcli} -p -o -d --height 550 --width 900 \
                --title "${title}" \
                --titlefont ${titlefont} \
                --bannerimage "${bannerimage}" \
                --bannertitle \
                --icon "${macosIcon}" \
                --iconsize 180 \
                -y "${icon}" \
                --message "${message}" \
                --infobuttontext "${infotext}" \
                --infobuttonaction "${infolink}" \
                --button1text "${button1text}" \
                --button2text "${button2text}" \
                --${blurscreen}
    exitcode=$?
    if [[ $exitcode == 0 ]]; then
        updateselected=1
        open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane
    elif [[ $exitcode == 2 ]] && [[ $deferrals -gt 0 ]]; then
        updateselected=1
  	elif [[ $exitcode == 3 ]]; then
  		updateselected=1
    fi
    if [[ $exitcode -lt 10 ]]; then
        deferrals=$(( $deferrals - 1 ))
        defaults write ${appdomain} ${defarralskey} -int ${deferrals}
    fi
}

runJamfHelper () {
    if [[ -e "/Library/Security/PolicyBanner.rtfd/logo_colour_100x100.png" ]]; then
        icon="/Library/Security/PolicyBanner.rtfd/logo_colour_100x100.png"
    else
        icon="/System/Library/CoreServices/HelpViewer.app/Contents/Resources/AppIcon.icns"
    fi
    "${jamfhelper}" -windowType utility -title "${title}" -description "${message}" -icon "${icon}" -button1 "Update" -button2 "More Info" -defaultButton 1
    exitcode=$?
    if [[ $exitcode == 0 ]]; then
        updateselected=1
        open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane
    elif [[ $exitcode == 2 ]]; then
        currentUser=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
        uid=$(id -u "$currentUser")
        launchctl asuser $uid open "${infolink}"
    fi

}

while [[ ${persistant} -eq 1 ]] || [[ ${updateselected} -eq 0 ]]
do
    if [[ -e "${dialogcli}" ]]; then
        runDialog
    elif [[ -e "${jamfhelper}" ]]; then
        runJamfHelper
    else
        updateselected=1
    fi
done

