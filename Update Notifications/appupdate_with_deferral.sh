#!/bin/zsh

autoload is-at-least
dialogapp="/usr/local/bin/dialog"
dialoglog="/var/tmp/dialog.log"

org="Org Name Here"
softwareportal="Self Service"
dialogheight="430"
iconsize="120"
waittime=60

if [[ $1 == "test" ]]; then
	title="GlobalProtect VPN"
	apptoupdate="/Applications/GlobalProtect.app"
	appversionrequired="5.2.11"
	maxdeferrals="5"
	additionalinfo="Your VPN will disconnect during the update. Estimated installation time: 1 minute\n\n"
	policytrigger="INSTALLPANGP"
else
	title=$4
	apptoupdate=$5
	appversionrequired=$6
	maxdeferrals=$7
    additionalinfo=$8 # optional
    policytrigger=$9

	if [[ -z $4 ]] || [[ -z $5 ]] || [[ -z $6 ]] || [[ -z $7 ]] || [[ -z $9 ]]; then
		echo "Incorrect parameters entered"
		exit 1
	fi
fi

if [[ ! -e "$apptoupdate" ]]; then
	echo "App $apptoupdate does not exist on this device"
	exit 0
fi

# work out the current installed version and exit if we are already up to date
installedappversion=$(defaults read ${apptoupdate}/Contents/Info.plist CFBundleShortVersionString)
is-at-least $appversionrequired $installedappversion
result=$?

if [[ $result -eq 0 ]]; then
	echo "Already up to date"
	exit 0
fi


# work out remaining deferrals"
appdomain="${org// /_}.$(echo $apptoupdate | awk -F '/' '{print $NF}')"
deferrals=$(defaults read ${appdomain} deferrals || echo ${maxdeferrals})

if [[ $deferrals -gt 0 ]]; then
	infobuttontext="Defer"
else
	infobuttontext="Max Deferrals Reached"
fi

# construct the dialog
message="${org} requires **${title}** to be updated to version **${appversionrequired}**:\n\n \
${additionalinfo} \
_Remaining Deferrals: **${deferrals}**_\n\n \
You can also update at any time from ${softwareportal}. Search for **${title}**."

$dialogapp --title "$title Update" \
				--titlefont colour=#00a4c7 \
				--icon "${apptoupdate}" \
				--message "${message}" \
				--infobuttontext "${infobuttontext}" \
				--button1text "Continue" \
				--height ${dialogheight} \
				--iconsize ${iconsize} \
				--quitoninfo \
				--alignment centre \
				--centreicon
				
if [[ $? == 3 ]] && [[ $deferrals -gt 0 ]]; then
	deferrals=$(( $deferrals - 1 ))
	defaults write ${appdomain} deferrals -int ${deferrals}
else
	echo "Continuing with install"
	# cleanup deferral count
	defaults delete ${appdomain} deferrals
	
	# popup wait dialog for 60 seconds to give the user something to look at
	$dialogapp --title "${title} Install" \
			  --icon "${apptoupdate}" \
			  --height 230 \
			  --progress ${waittime} \
			  --progresstext "" \
			  --message "Please wait while ${title} is installed" \
			  --commandfile "$dialoglog" &
	
	# background for loop to display the dialog		  
	for ((i=1; i<=${waittime}; i++)); do 
		echo "progress: increment" >> $dialoglog
		sleep 1
		if [[ $i -eq ${waittime} ]]; then
			echo "progress: complete" >> $dialoglog
			sleep 1
			echo "quit:" >> $dialoglog
		fi
	done &
	
	# run the install policy in the background
	echo "Launching policy ${policytrigger}"
	/usr/local/bin/jamf policy -event ${policytrigger} 
	
fi
