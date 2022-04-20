#!/bin/sh

# Name: checkUpTime.sh
# Source: https://github.com/stevewood-tx/CasperScripts-Public/blob/master/checkUpTime/checkUpTime.sh
# Date:  19 Aug 2014
# Author:  Steve Wood (swood@integer.com)
# Updated by: Bart Reardon (https://github.com/bartreardon)
# Purpose:  look for machines that have not been restarted in X number of days.
# Requirements:  swiftDialog on the local machine
#
# How To Use:  create a policy in your JSS with this script set to run once every day.

## Global Variables and Stuff
logPath='/path/to/store/log/files'  ### <--- enter a path to where you store log files locally
if [[ ! -d "$logPath" ]]; then
	mkdir $logPath
fi
set -xv; exec 1> $logPath/checkUpTime.txt 2>&1
version=2.0
dialog="/usr/local/bin/dialog" ### <--- path to where you store swiftDialog on local machine
NC='/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action'
jssURL='https://YOUR.JSSSERVER.COM:8443' ### <--- enter your JSS URL
apiUser=$4   ### <--- enter as $4 variable in your script settings
apiPass=$5  ### <--- enter as $5 variable in your script settings
serNum=$(ioreg -l | grep IOPlatformSerialNumber | awk '{print $4}'| sed 's/"//g')
dialogTitle="Machine Needs A Restart"
loggedInUser=`/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }'`

## set minDays - we start bugging users at this level with just a dialog box
minDays=7

## set maxDays - after we reach maxDays we bug with dialog box AND email
maxDays=15

## Grab user info ##
### Thanks to Bryson Tyrrell (@bryson3Gps) for the code to parse
info=$(curl -s -k -u $apiUser:$apiPass $jssURL/JSSResource/computers/match/$serNum)
email=$(echo $info | /usr/bin/awk -F'<email>|</email>' '{print $2}')
realName=$(echo $info | /usr/bin/awk -F'<realname>|</realname>' '{print $2}')

#### MAIN CODE ####
days=`uptime | awk '{ print $4 }' | sed 's/,//g'`  # grabs the word "days" if it is there
num=`uptime | awk '{ print $3 }'`  # grabs the number of hours or days in the uptime command

## set the body of the email message
message1="Dear $realName"
message1b="Your computer has now been up for $num days.  It is important for you to restart your machine on a regular"
message2="basis to help it run more efficiently and to apply updates and patches that are deployed during the login or logout"
message3="process."
message3a="Please restart your machine ASAP.  If you do not restart, you will continue to get this email and the pop-up"
message4="dialog box daily until you do."
message5="FROM THE IT STAFF"  ### <---  change this to whomever you want

## now the logic

if [ $loggedInUser != "root" ]; then
	if [ $days = "days" ]; then
	
		if [ $num -gt $minDays ]; then
		
			if [ $num -gt $maxDays ]; then
			
				message="Your computer has not been restarted in more than **$maxDays** days.  Please restart ASAP.  Thank you."
			
				$dialog --small --height 200 --position topright --title "$dialogTitle" --titlefont size=20 --message "$message" --icon SF=exclamationmark.octagon.fill,colour=auto --iconsize 70
				
				if [ $email ]; then
				
					echo "$message1\n\n$message1b\n$message2\n$message3\n\n$message3a\n$message4\n\n\n$message5" | mail -s "URGENT: Restart Your Machine" $email
				
				fi
			else
				message="Your computer has not been restarted in $num days.  Please restart ASAP.  Thank you."
				$dialog --small --height 200 --position topright --title "$dialogTitle"--titlefont size=20 --message "$message" --icon caution --iconsize 70
			
			fi
		fi
	fi
fi


exit 0