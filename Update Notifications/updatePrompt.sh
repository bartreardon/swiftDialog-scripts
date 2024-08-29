#!/bin/zsh

# This is a script to nudge users to update their macOS to the latest version
# it uses the SOFA feed to get the latest macOS version and compares it to the local version
# if the local version is less than the latest version then a dialog is displayed to the user
# if the local version has been out for more than the required_after_days then the dialog is displayed

## update these as required with org specific text
# app domain to store deferral history

autoload is-at-least

# needs to run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

computerName=${2:-$(hostname)}
loggedInUser=${3:-$(stat -f%Su /dev/console)}
maxdeferrals=${4:-5}
nag_after_days=${5:-7}
required_after_days=${6:-14}
helpDeskText=${7:-"If you require assistance with this update, please contact the IT Help Desk"}
appdomain=${8:-"com.orgname.macosupdate"}

# get mac hardware info
spData=$(system_profiler SPHardwareDataType)
serialNumber=$(echo $spData | grep "Serial Number" | awk -F': ' '{print $NF}')
modelName=$(echo $spData | grep "Model Name" | awk -F': ' '{print $NF}')

# array of macos major version to friendly name
declare -A macos_major_version
macos_major_version[12]="Monterey 12"
macos_major_version[13]="Ventura 13"
macos_major_version[14]="Sonoma 14"
macos_major_version[15]="Sequioa 15"

# defaults
width="950"
height="570"
days_since_security_release=0
days_since_release=0
local_store="/Library/Application Support/${appdomain}"
update_required=false


if [[ ! -d "${local_store}" ]]; then
    mkdir -p "${local_store}"
fi

### Functions and whatnot

# json function for parsing the SOFA feed
json_value() {
    local jsonpath="${1}"
    local jsonstring="${2}"
    local count=0
    if [[ $jsonpath == *.count ]]; then
        count=1
        jsonpath=${jsonpath%.count}
    fi

    local type=$(echo "${jsonstring}" | /usr/bin/plutil -type "$jsonpath" -)
    local results=$(echo "${jsonstring}" | /usr/bin/plutil -extract "$jsonpath" raw -)

    if [[ $type == "array" ]]; then
        if [[ $count == 0 ]]; then
            for ((i=0; i<$results; i++)); do
                echo "${jsonstring}" | /usr/bin/plutil -extract "$jsonpath.$i" raw -
            done
            return
        fi
    else
        if [[ $count == 1 ]]; then
            echo $results | /usr/bin/wc -l | /usr/bin/tr -d " "
            return
        fi
    fi
    echo "${results}"
}

function echoToErr() {
    echo "$@" 1>&2
}

function getSOFAJson() {
    # get the latest data from SOFA feed - if this fails there's no point continuing
    # SOFA feed URL
    local SOFAURL="https://sofafeed.macadmins.io/v1/macos_data_feed.json"

    # check the last update date on the url and convert to epoch time
    local SOFAFeedLastUpdate=$(curl -s --compressed -I "${SOFAURL}" | grep "last-modified" | awk -F': ' '{print $NF}') 
    local SOFAFeedLastUpdateEpoch=$(date -j -f "%a, %d %b %Y %T %Z" "${SOFAFeedLastUpdate}" "+%s" 2>/dev/null)
    local SOFAJSON=""
    local lastupdate="${local_store}/lastupdate"
    local datafeed="${local_store}/macos_data_feed.json"
    local lastupdatetime=0

    # check /Library/Application Support/$appdomain/lastupdate
    # if the last update is greater than the last update on the SOFA feed then use the local feed
    # else get the feed from the URL
    if [[ -e "${lastupdate}" ]]; then
        lastupdatetime=$(cat "${lastupdate}")
        if [[ $lastupdatetime -ge $SOFAFeedLastUpdateEpoch ]]; then
            echoToErr "Using local SOFA feed"
            SOFAJSON=$(cat "${datafeed}")
        else
            echoToErr "Getting SOFA feed from URL"
            SOFAJSON=$(curl -s --compressed "${SOFAURL}")
            echo $SOFAJSON > "${datafeed}"
            echo $SOFAFeedLastUpdateEpoch > "${lastupdate}"
        fi
    else
        echoToErr "Getting SOFA feed from URL"
        SOFAJSON=$(curl -s --compressed "${SOFAURL}")
        echo $SOFAJSON > "${datafeed}"
        echo $SOFAFeedLastUpdateEpoch > "${lastupdate}"
    fi

    if [[ -z $SOFAJSON ]]; then
        echoToErr "Failed to get SOFA feed"
        exit 1
    fi

    echo $SOFAJSON
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
        echo "swiftDialog not found or out of date. Installing ..."
		dialogInstall
	fi
}

dialogInstall() {
	# Get the URL of the latest PKG From the Dialog GitHub repo
    local dialogURL=""
    if [[ $majorVersion -ge 13 ]]; then
        # latest version of Dialog for macOS 13 and above
        dialogURL=$(curl --silent --fail -L "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
    elif [[ $majorVersion -eq 12 ]]; then
        # last version of Dialog for macOS 12
        dialogURL="https://github.com/swiftDialog/swiftDialog/releases/download/v2.4.2/dialog-2.4.2-4755.pkg"
    else
        # last version of Dialog for macOS 11
        dialogURL="https://github.com/swiftDialog/swiftDialog/releases/download/v2.2.1/dialog-2.2.1-4591.pkg"
    fi
	
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

# function to get the icon for the major version
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

# function to get the release notes URL
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

latestMacOSVersion() {
    # get the latest version of macOS
    json_value "OSVersions.0.Latest.ProductVersion" "$SOFAFeed"
}

supportsLatestMacOS() {
    # check if the current hardware supports the latest macOS
    if [[ -z $model_id ]]; then
        model_id="$(system_profiler SPHardwareDataType | grep "Model Identifier" | awk -F': ' '{print $NF}')"
    fi
    # if we are runniing on a model of type that starts with "VirtualMac"  then return true
    if [[ $model_id == "VirtualMac"* ]]; then
        return 0
    fi
    # get latest fersion supported for this model from the feed
    local latest_supported_os="$(json_value "Models.${model_id}.OSVersions.0" "$SOFAFeed")"
    if [[ $latest_supported_os -ge $(latestMacOSVersion | cut -d. -f1) ]]; then
        return 0
    fi
    return 1
}

getDeferralCount() {
    # get the deferrals count
    local key=$1
    if [[ ! -e "${local_store}/deferrals.plist" ]]; then
        defaults write "${local_store}/deferrals.plist" ${key} -int 0
    fi
    defaults read "${local_store}/deferrals.plist" ${key} || echo 0
}

updateDefferalCount() {
    # update the deferrals count
    local key=$1
    defaults write "${local_store}/deferrals.plist" ${key} -int $(( $(getDeferralCount $key) + 1 ))
}

openSoftwareUpdate() {
    # open software update
    if [[ $majorVersion -ge 14 ]]; then
        /usr/bin/open "x-apple.systempreferences:com.apple.preferences.softwareupdate"
    else
        /usr/bin/open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane
    fi 
}

dialogNotification() {
    local macOSVersion="$1"
    local macOSLocalVersion="${2:-$local_version}"
    local majorVersion=$(echo $macOSVersion | cut -d. -f1)
    local openSU="/usr/bin/open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane"
    if [[ $majorVersion -ge 14 ]]; then
        openSU="/usr/bin/open 'x-apple.systempreferences:com.apple.preferences.softwareupdate'"
    fi 
    local title="OS Update Available"
    local subtitle="macOS ${macOSVersion} is available for install"
    local message="Your ${modelName} ${computerName} is running macOS version ${macOSLocalVersion}"
    local button1text="Update"
    local button1action="${openSU}"
    local button2text="Not Now"
    local button2action="$(defaults write "${local_store}/deferrals.plist" ${defarralskey} -int $(( $(getDeferralCount ${defarralskey}) + 1 )))"
    /usr/local/bin/dialog --notification \
                --title "${title}" \
                --subtitle "${subtitle}" \
                --message "${message}" \
                --button1text "${button1text}" \
                --button1action "${button1action}" \
                --button2text "${button2text}" \
                --button2action "${button2action}"
}

# function to display the dialog
runDialog () {
    updateRequired=0
    local deferrals=$(getDeferralCount ${defarralskey})
    if [[ $deferrals -gt $maxdeferrals ]] || [[ $days_since_security_release -gt $required_after_days ]]; then
        updateRequired=1
    fi
    macOSVersion="$1"
    majorVersion=$(echo $macOSVersion | cut -d. -f1)
    message="$2"
    helpText="$3"
    jamfbanner="/Users/${loggedInUser}/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingheader.png"
    if [[ -e "$jamfbanner" ]]; then
        bannerimage=$jamfbanner
    else    
        bannerimage="colour=red"
    fi
    title="macOS Update Available"
    titlefont="shadow=1"
    macosIcon=$(iconForMajorVer $majorVersion)
    infotext="Apple Security Release Info"
    infolink=$(appleReleaseNotesURL $macOSVersion)
    icon=${$(defaults read /Library/Preferences/com.jamfsoftware.jamf self_service_app_path 2>/dev/null):-"sf=applelogo"}
    button1text="Open Software Update"
    button2text="Remind Me Later"
    blurscreen=""

    if [[ $updateRequired -eq 1 ]]; then
        button2text="Update Now"
        if [[ $deferrals -gt $(( $maxdeferrals )) ]]; then
            blurscreen="--blurscreen"
        fi
    fi

    /usr/local/bin/dialog -p -o -d \
                --height ${height} \
                --width ${width} \
                --title "${title}" \
                --titlefont ${titlefont} \
                --bannerimage "${bannerimage}" \
                --bannertitle \
                --bannerheight 100 \
                --overlayicon "${macosIcon}" \
                --iconsize 160 \
                --icon "${icon}" \
                --message "${message}" \
                --infobuttontext "${infotext}" \
                --infobuttonaction "${infolink}" \
                --button1text "${button1text}" \
                --button2text "${button2text}" \
                --helpmessage "${helpText}" \
                ${blurscreen}
    exitcode=$?

    if [[ $exitcode == 0 ]]; then
        updateselected=1
    elif [[ $exitcode == 2 ]] && [[ $updateRequired == 1 ]]; then
        updateselected=1
  	elif [[ $exitcode == 3 ]]; then
  		updateselected=1
    fi

    # update the deferrals count
    if [[ $exitcode -lt 11 ]]; then
        updateDefferalCount ${defarralskey}
    fi

    # open software update
    if [[ $updateselected -eq 1 ]]; then
        openSoftwareUpdate
    fi
}

function incrementHeightByLines() {
    local lineHeight=28
    local lines=${1:-1}
    local newHeight=$(( $height + $lines * $lineHeight ))
    echo $newHeight
}

# check dialog is installed and up to date
dialogCheck

# get the SOFA feed
SOFAFeed=$(getSOFAJson)

# get the locally installed version of macOS
local_version=$(sw_vers -productVersion)

### if $1 is set to TEST then we want to initiate a test dialog with dummy data
if [[ $1 == "TEST" ]]; then
    echo "Running in test mode"
    echo "forcing an older local version"
    local_version=${2:-"12.6.1"}
    computerName="Test Mac"
    serialNumber="C02C12345678"
    model_id="MacBookPro14,1"
fi

local_version_major=$(echo $local_version | cut -d. -f1)
local_version_name=${macos_major_version[$local_version_major]}
update_required=false

# loop through feed count and match on local version
feed_count=$(json_value "OSVersions.count" "$SOFAFeed")
feed_index=0
for ((i=0; i<${feed_count}; i++)); do
    feed_version_name=$(json_value "OSVersions.${i}.OSVersion" "$SOFAFeed")
    if [[ $feed_version_name == $local_version_name ]]; then
        feed_index=$i
        break
    fi
done

# get the count of security releases for the locally installed release of macOS
security_release_count=$(json_value "OSVersions.${feed_index}.SecurityReleases.count" "$SOFAFeed")

# get the latest version of macOS for the installed release which will be the first item in the security releases array
latest_version=$(json_value "OSVersions.${feed_index}.SecurityReleases.0.ProductVersion" "$SOFAFeed")
latest_version_release_date=$(json_value "OSVersions.${feed_index}.SecurityReleases.0.ReleaseDate" "$SOFAFeed")

# get the number of days since the release date
release_date=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$latest_version_release_date " "+%s" 2>/dev/null)
current_date=$(date "+%s")

# get the required by date and the number of days since release
requiredby=$(date -j -v+${required_after_days}d -f "%s" "$release_date" "+%B %d, %Y" 2>/dev/null)
days_since_release=$(( (current_date - release_date) / 86400 ))

# get the deferrals count
defarralskey="deferrals_${latest_version}"
#deferrals=$(defaults read ${appdomain} ${defarralskey} || echo 0)
deferrals=$(getDeferralCount ${defarralskey})

# loop through security releases to find the one that matches the locally installed version of macOS
security_index=0
for ((i=0; i<${security_release_count}; i++)); do
    security_version=$(json_value "OSVersions.${feed_index}.SecurityReleases.${i}.ProductVersion" "$SOFAFeed")
    if [[ $security_version == $local_version ]]; then
        security_index=$i
        break
    fi
done
# get the security release date
security_release_date=$(json_value "OSVersions.${feed_index}.SecurityReleases.${security_index}.ReleaseDate" "$SOFAFeed")
days_since_security_release=$(( (current_date - $(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$security_release_date" "+%s" 2>/dev/null)) / 86400 ))

# get the number of CVEs and actively exploited CVEs
security_CVEs=$(json_value "OSVersions.${feed_index}.SecurityReleases.${security_index}.CVEs.count" "$SOFAFeed")
security_ActivelyExploitedCVEs=$(json_value "OSVersions.${feed_index}.SecurityReleases.$security_index.ActivelyExploitedCVEs" "$SOFAFeed")
security_ActivelyExploitedCVEs_count=$(json_value "OSVersions.${feed_index}.SecurityReleases.$security_index.ActivelyExploitedCVEs.count" "$SOFAFeed")

#testing


# Perform checks to see if an update is required
if ! is-at-least $latest_version $local_version; then
    echo "Update is required: $latest_version is available for $local_version_name"
    # if the number of days since release is greater than the nag_after_days then we need to nag
    # else just send a notification
    if [[ $days_since_release -ge $nag_after_days ]]; then
        echo "Nag after period has passed. Obtrusive dialog will be displayed"
        update_required=true
    else
        echo "Still in the update notification period. Sending notification only"
        dialogNotification $latest_version
        exit 0
    fi

    # if the cve count is greater than 0 then we need to update regardless of the days since release
    if [[ $security_ActivelyExploitedCVEs_count -gt 0 ]]; then
        echo "Actively exploited CVEs found. Update required"
        update_required=true
    fi

    # if the number of days since the instaled version was released is greater than the required after days then we need to update
    if [[ $days_since_security_release -ge $required_after_days ]]; then
        echo "Days since security release is greater than required after days. Update required" 
        update_required=true
    fi
fi

echo "After checks: update_required = $update_required"

### END OF CHECKS


### Build dialog message

# Make any additions to the support text
if [[ $security_ActivelyExploitedCVEs_count -gt 0 ]]; then
    supportText="**_There are currently $security_ActivelyExploitedCVEs_count actively exploited CVEs for macOS ${local_version}_**<br>**You must update to the latest version**"
    height=$(incrementHeightByLines 2)
else
    if [[ $days_since_security_release -ge $required_after_days ]]; then
        supportText="This update is required to be applied immediately"
    else
        supportText="This update is required to be applied before ${requiredby}"
    fi
    height=$(incrementHeightByLines 1)
fi

# check if the latest version from latestMacOSVersion is supported on the current hardware 
current_macos_version_major=$(latestMacOSVersion | cut -d. -f1)
if [[ $local_version_major -lt $current_macos_version_major ]] && supportsLatestMacOS; then
    additionalText="macOS ${current_macos_version_major} is available for install and supported on this device.  Please update to the latest OS release at your earliest convenience"
    height=$(incrementHeightByLines 2)
elif ! supportsLatestMacOS; then
    additionalText="**Your device does not support macOS ${current_macos_version_major}**  <br>Support for this device has ended"
    height=$(incrementHeightByLines 2)
fi


# build the full message text
message="## **macOS ${latest_version}** is available for install

Your ${modelName} ${computerName} is running macOS version ${local_version}.<br>It has been **${days_since_security_release}** days since this update was released.

It is important that you update to **${latest_version}** at your earliest convenience.  <br>
 - Click the Security Release button for more details or the help button for device info.

**Your swift attention to applying this update is appreciated**

### **Security Information**

${supportText}

${additionalText}

You have deferred this update request **${deferrals}** times."

# build help message with device info and service desk contact details
helpText="### Device Information<br><br> \
  - Computer Name: ${computerName}  <br> \
  - Model: ${modelName}  <br> \
  - Serial Number: ${serialNumber}  <br> \
  - Installed macOS Version: ${local_version}  <br> \
  - Latest macOS Version: ${latest_version}  <br> \
  - Release Date: $(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$latest_version_release_date " "+%B %d, %Y" 2>/dev/null)  <br> \
  - Days Since Release: ${days_since_release}  <br> \
  - Required By: ${requiredby}  <br> \
  - Deferrals: ${deferrals} of ${maxdeferrals}  <br> \
  - Security CVEs: ${security_CVEs}  <br> \
  - Actively Exploited CVEs: ${security_ActivelyExploitedCVEs_count}  <br> \
    - ${security_ActivelyExploitedCVEs}  <br> \
  - Update Required: ${update_required}  <br> \
<br><br> \
### Service Desk Contact<br><br> \
${helpDeskText}"

# if the update is required then display the dialog
# also echo to stdout so info is captured by jamf
if [[ $update_required == true ]]; then
    echo "** Update is required **:"
    echo "Latest version: $latest_version"
    echo "Local version: $local_version"
    echo "Release date: $latest_version_release_date "
    echo "Days since release of $latest_version: $days_since_release"
    echo "Days since release of $local_version : $days_since_security_release"
    echo "There are $security_ActivelyExploitedCVEs_count actively exploited CVEs for $local_version"

    runDialog $latest_version "$message" "$helpText"
else
    echo "No update required:"
    echo "Latest version: $latest_version"
    echo "Local version: $local_version"
    echo "Release date: $latest_version_release_date "
    if [[ $days_since_release -lt $nag_after_days ]]; then
        echo "Days since release: $days_since_release"
        echo "Nag starts after: $nag_after_days days"
    fi
fi
