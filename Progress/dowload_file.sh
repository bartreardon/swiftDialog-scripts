#!/bin/bash

# Downloads a file and shows progress as a mini dialog

downloadFile() {
    # curl outputs progress - we look for % sign and capture the progress
    APPName="${1}"
    APPURL="${2}"
    PKGURL=$(curl -sIL "${APPURL}" | grep -i location)
    PKGURL=$(echo "${PKGURL##*$'\n'}" | awk '{print $NF}' | tr -d '\r')
    PKGName=$(echo ${PKGURL} | awk -F "/" '{print $NF}' | tr -d '\r')
    TMPDir="/var/tmp/"

    # swiftDialog Options
    dialogcmd="/Library/Application Support/Dialog/Dialog.app"
    commandFile="/var/tmp/dialog.log"
    ICON="SF=arrow.down.app.fill,colour1=teal,colour2=blue"

    # launch swiftDialog in mini mode
    open -a "${dialogcmd}" --args --title "Downloading ${APPName}" --icon "${ICON}" --mini --progress 100 --message "Please wait..."

    echo "progress: 1" >> ${commandFile}
    sleep 2 

    echo "message: Downloading ${PKGName}" >> ${commandFile}

    /usr/bin/curl -L -# -O --output-dir "${TMPDir}" "${PKGURL}" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "progresstext: ${progress}%" >> ${commandFile} && echo "progress: ${progress}" >> ${commandFile} && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
    done

    echo "progress: complete" >> ${commandFile}
    echo "message: Download Complete" >> ${commandFile}
    sleep 2
    echo "quit:" >> ${commandFile}

    echo "${TMPDir}${PKGName}"
}

# example usage
downloadedfile=$(downloadFile "Microsoft OneDrive" "https://go.microsoft.com/fwlink/?linkid=823060")

# do something with the file we just downloaded
echo "Downloaded ${downloadedfile}"
