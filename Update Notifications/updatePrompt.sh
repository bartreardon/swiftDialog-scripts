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
# 5 - Days until required. This many days after the release date the prompt will be shown. Default is 14
# 6 - infolink - defaults to the release notes for the particular release if they can be determined, otherwise https://support.apple.com/en-au/HT201222
# 7 - Max deferrals - set the number of deferrals allowed (default 5 - set to 0 to disable)
# 8 - support text - Extra informational text inserted into the message (e.g. "For help please contact the [Help Desk](https://link.to/helpdesk)" )
# 9 - Icon - defaults to the OS icon for the major release if it can be determined, otherwise Apple logo SF symbol
# 10 - swiftDialog version required - defaults to v2.3.2. If installed version is older, swiftDialog will be updated.

appleProductJSON=$(curl -sL https://gdmf.apple.com/v2/pmv)
today=$(date "+%Y-%m-%d")

getMajorVersion() {
    echo $1 | awk -F "." '{print $1}'
}

iconForMajorVer() {
    # OS icons gethered from the App Store
    majorversion=$1

    declare -A macosIcon=(
    [14]="https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/53/7b/21/537b2109-d127-ba55-95da-552ec54b1d7e/ProductPageIcon.png/460x0w.webp"
    [13]="https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/01/11/29/01112962-0b21-4351-3e51-28dc1d7fe0a7/ProductPageIcon.png/460x0w.webp"
    [12]="https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/fc/5f/46/fc5f4610-1647-e0bb-197d-a5a447ec3965/ProductPageIcon.png/460x0w.webp"
    [11]="https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/48/4b/eb/484beb20-2c97-1f72-cc11-081b82b1f920/ProductPageIcon.png/460x0w.webp"
    )
    iconURL=${macosIcon[$majorversion]}

    if [[ -n $iconURL ]]; then
        echo ${iconURL}
    else 
        echo "sf=applelogo"
    fi
}

appleReleaseNotesURL() {
    releaseVer=$1
    securityReleaseURL="https://support.apple.com/en-au/HT201222"
    HT201222=$(curl -sL ${securityReleaseURL})
    releaseNotesURL=$(echo $HT201222 | grep "${releaseVer}</a>" | grep "macOS" | sed -r 's/.*href="([^"]+).*/\1/g')
    if [[ -n $releaseNotesURL ]]; then
        echo $releaseNotesURL
    else
        echo $securityReleaseURL
    fi
}

json_value() { # Version 2023.7.24-1 - Copyright (c) 2023 Pico Mitchell - MIT License - Full license and help info at https://randomapplications.com/json_value
	{ set -- "$(/usr/bin/osascript -l 'JavaScript' -e 'function run(argv) { let out = argv.pop(); if ($.NSFileManager.defaultManager.fileExistsAtPath(out))' \
		-e 'out = $.NSString.stringWithContentsOfFileEncodingError(out, $.NSUTF8StringEncoding, ObjC.wrap()).js; if (/^\s*[{[]/.test(out)) out = JSON.parse(out)' \
		-e 'argv.forEach(key => { out = (Array.isArray(out) ? (/^-?\d+$/.test(key) ? (key = +key, out[key < 0 ? (out.length + key) : key]) : (key === "=" ?' \
		-e 'out.length : undefined)) : (out instanceof Object ? out[key] : undefined)); if (out === undefined) throw "Failed to retrieve key/index: " + key })' \
		-e 'return (out instanceof Object ? JSON.stringify(out, null, 2) : out) }' -- "$@" 2>&1 >&3)"; } 3>&1
	[ "${1##* }" != '(-2700)' ] || { set -- "json_value ERROR${1#*Error}"; >&2 printf '%s\n' "${1% *}"; false; }
}

getCurrentReleaseFor() {
    checkrelease=$1
    count=$(json_value 'PublicAssetSets' 'macOS' '=' "${appleProductJSON}")

    for index in {0..$(( $count - 1 ))}; do
        assetSetVer=$(json_value 'PublicAssetSets' 'macOS' $index 'ProductVersion' "${appleProductJSON}")
        if [[ $(getMajorVersion $assetSetVer) == $(getMajorVersion $checkrelease) ]]; then
            echo ${assetSetVer}
        fi
    done
}

getReleaseDateFor() {
    checkrelease=$1
    count=$(json_value 'AssetSets' 'macOS' '=' "${appleProductJSON}")

    for index in {0..$(( $count - 1 ))}; do
        assetSetVer=$(json_value 'AssetSets' 'macOS' $index 'ProductVersion' "${appleProductJSON}")
        if [[ "$assetSetVer" == "$checkrelease" ]]; then
            echo $(json_value 'AssetSets' 'macOS' $index 'PostingDate' "${appleProductJSON}")
        fi
    done
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
appdomain="com.orgname.updateprompt"

OSVer=$(sw_vers | grep "ProductVersion" | awk '{print $NF}')
majorVersion=$(getMajorVersion $OSVer)
modelName=$( /usr/libexec/PlistBuddy -c 'Print :0:_items:0:machine_name' /dev/stdin <<< "$(system_profiler -xml SPHardwareDataType)" )

mode=${1:-"/"}
computerName=${2:-$(hostname -s)}
loggedInUser=${3:-$(stat -f%Su /dev/console)}
requiredOSVer=${4:-$(getCurrentReleaseFor $OSVer)}
daysUntilRequired=${5:-14}
maxdeferrals=${6:-5}
infolink=${7:-"$(appleReleaseNotesURL $requiredOSVer)"}
supportText=${8}
macosIcon=${9:-"$(iconForMajorVer $majorVersion)"}
dialogVersion=${10:-"2.3.2"}  # required

defarralskey="deferrals_${requiredOSVer}"
blurscreen="noblur"

requiredOSText="the latest version of macOS"
dialogHeight=480
if [[ -n $supportText ]]; then
    ((dialogHeight+=28))
fi 

if [[ -z ${requiredOSVer} ]] || [[ "$requiredOSVer" == "Unsupported" ]]; then
    requiredOSVer="100"
else
    requiredOSText="macOS ${requiredOSVer}"
fi

if [[ "$mode" == "test" ]]; then
    # set the OS ver to something old
    OSVer="14.1.0"
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

# get latest release info
latestRelease=$(getCurrentReleaseFor $OSVer)
releaseDate=$(getReleaseDateFor $latestRelease)
echo "Latest release is $latestRelease released on $releaseDate"
requiredByDate=$(date -j -f %Y-%m-%d -v+${daysUntilRequired}d "$releaseDate" +%Y-%m-%d)
requiredby="You will not be able to defer the update after **$(date -j -f %Y-%m-%d "${requiredByDate}" "+%A %B %d, %Y")**"

# check if there's a defferalskey already
deferralsExist=$(defaults read ${appdomain} ${defarralskey} 2>/dev/null || echo "false")
echo "Deferrals exist: ${deferralsExist}"

if [[ $today < $requiredByDate ]]; then
    echo "Update prompt not required until $requiredByDate"
    # work out remaining deferrals"
    deferrals=$(defaults read ${appdomain} ${defarralskey} || echo ${maxdeferrals})
else
    # set deferrals to 0 if we're past the required date
    deferrals=0
    echo "Update is now required. Requirement date $requiredByDate"
fi


# check dialog is installed and up to date
dialogCheck "$dialogVersion"


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
message="## **${requiredOSText}** is available for install

Your ${modelName} is running macOS version ${OSVer} 

It is important that you update to **${requiredOSText}** at your earliest convenience. Click the More Information button below for additional details.

${supportText}

**Your swift attention to applying this update is appreciated**

${requiredby}"

infotext="More Information"
# Create `overlayicon` from Self Service's custom icon
xxd -p -s 260 "$(defaults read /Library/Preferences/com.jamfsoftware.jamf self_service_app_path)"/Icon$'\r'/..namedfork/rsrc | xxd -r -p > /var/tmp/overlayicon.icns
overlayicon="/var/tmp/overlayicon.icns"

button1text="Open Software Update"
buttona1ction="open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane"

runDialog () {
    ${dialogcli} -p -o -d \
                --height ${dialogHeight} \
                --width 900 \
                --title "${title}" \
                --titlefont ${titlefont} \
                --bannerimage "${bannerimage}" \
                --bannertitle \
                --icon "${macosIcon}" \
                --iconsize 180 \
                --overlayicon "${overlayicon}" \
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
    icon="/System/Library/CoreServices/HelpViewer.app/Contents/Resources/AppIcon.icns"
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

