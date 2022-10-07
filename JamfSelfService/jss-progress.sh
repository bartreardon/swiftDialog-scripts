#!/bin/zsh

# This script will pop up a mini dialog with progress of a jamf pro policy

jamfPID=""
jamf_log="/var/log/jamf.log"
dialog_log=$(mktemp /var/tmp/dialog.XXX)
chmod 644 ${dialog_log}
scriptlog="/var/tmp/jamfprogress.log"
count=0

if [[ -z $4 ]] || [[ -z $5 ]]; then
    echo "Usage: $0 <policy name> <policy id> [<policy icon>]"
    quitScript
fi

policyname="${4}" # jamf parameter $4
policyTrigger="${5}"   # jamf parameter $5
icon="${6}"       # jamf parameter $6

if [[ -z $6 ]]; then
    icon="/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action"
fi

# In case we want the start of the log format including the hour, e.g. "Mon Aug 08 11"
# datepart=$(date +"%a %b %d %H")

function updatelog() {
    echo "$(date) ${1}" >> $scriptlog
}

function dialogcmd() {
    echo "${1}" >> "${dialog_log}"
    sleep 0.1
}

function launchDialog() {
	updatelog "launching main dialog"
    open -a "/Library/Application Support/Dialog/Dialog.app" --args --mini --title "${policyname}" --icon "${icon}" --message "Please wait while ${policyname} is installed" --progress 8 --commandfile "${dialog_log}"
    updatelog "main dialog running in the background with PID $PID"
}

function runPolicy() {
    updatelog "Running policy ${policyTrigger}"
    jamf policy -event ${policyTrigger} &
}

function dialogError() {
	updatelog "launching error dialog"
    errormsg="### Error\n\nSomething went wrong. Please contact IT support and report the following error message:\n\n${1}"
    open -a "/Library/Application Support/Dialog/Dialog.app" --args --ontop --title "Jamf Policy Error" --icon "${icon}" --overlayicon caution --message "${errormsg}"
    updatelog "error dialog running in the background with PID $PID"
}

function quitScript() {
	updatelog "quitscript was called"
    dialogcmd "quit: "
    sleep 1
    updatelog "Exiting"
    # brutal hack - need to find a better way
    killall tail
    if [[ -e ${dialog_log} ]]; then
        updatelog "removing ${dialog_log}"
		# rm "${dialog_log}"
    fi
    exit 0
}

function getPolicyPID() {
    datestamp=$(date "+%a %b %d %H:%M")
    while [[ ${jamfPID} == "" ]]; do
        jamfPID=$(grep "${datestamp}" "${jamf_log}" | grep "Checking for policies triggered by \"${policyTrigger}\"" | tail -n1 | awk -F"[][]" '{print $2}')
        sleep 0.1
    done
    updatelog "JAMF PID for this policy run is ${jamfPID}"
}

function readJAMFLog() {
    updatelog "Starting jamf log read"    
    if [[ ! -z "${jamfPID}" ]]; then
        updatelog "Processing jamf pro log for PID ${jamfPID}"
        while read -r line; do    
            statusline=$(echo "${line}" | grep "${jamfPID}")
            case "${statusline}" in
                *Success*)
                    updatelog "Success"
                    dialogcmd "progresstext: Complete"
                    dialogcmd "progress: complete"
                    sleep 1
                    dialogcmd "quit:"
                    updatelog "Success Break"
                    #break
                    quitScript
                ;;
                *failed*)
                    updatelog "Failed"
                    dialogcmd "progresstext: Policy Failed"
                    dialogcmd "progress: complete"
                    sleep 1
                    dialogcmd "quit:"
                    dialogError "${statusline}"
                    updatelog "Error Break"
                    #break
                    quitScript
                ;;
                *)
                    progresstext=$(echo "${statusline}" | awk -F "]: " '{print $NF}')
                    updatelog "Reading policy entry : ${progresstext}"
                    dialogcmd "progresstext: ${progresstext}"
                    dialogcmd "progress: increment"
                ;;
            esac
            ((count++))
            if [[ ${count} -gt 10 ]]; then
                updatelog "Hit maxcount"
                dialogcmd "progress: complete"
                sleep 0.5
                #break
                quitscript
            fi
        done < <(tail -f -n1 $jamf_log) 
    else
        updatelog "Something went wrong"
        echo "ok, something weird happened. We should have a PID but we don't."
    fi
    updatelog "End while loop"
}

function main() {
    updatelog "***** Start *****"
    updatelog "Running launchDialog function"
    launchDialog
    updatelog "Launching Policy in the background" 
    runPolicy
    sleep 1
    updatelog "Getting Policy ID"
    getPolicyPID
    updatelog "Policy ID is ${jamfPID}"
    updatelog "Processing Jamf Log"
    readJAMFLog
    updatelog "All Done we think"
    updatelog "***** End *****"
    quitScript
}

main 
exit 0
