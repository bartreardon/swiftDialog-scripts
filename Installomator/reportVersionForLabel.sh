#!/bin/zsh

#
# Process the list of labels, download directly from the Installomator git repo
# process the labels and report the version number
# Will also record the last run in a file and compare against the last known version
# If there is a new version, a report is generated with the updated labels and what version is the latest
# 


# labels we want to process
labels=(
    "microsoftedge"
    "firefoxpkg" 
    "macadminspython"
    "microsoftvisualstudiocode"
)

RAWInstallomatorURL="https://raw.githubusercontent.com/Installomator/Installomator/main"
appListFile="applist.txt"

# backup existing file
if [[ -e ${appListFile} ]]; then
    cp "${appListFile}" "${appListFile}-$(date '+%Y-%d-%m')"
else
    touch "${appListFile}"
fi

# load functions from Installomator
functionsPath="/var/tmp/functions.sh"
curl -sL ${RAWInstallomatorURL}/fragments/functions.sh -o "${functionsPath}"
source "${functionsPath}"

# additional functions
labelFromInstallomator() {
    echo "${RAWInstallomatorURL}/fragments/labels/$1.sh"
}

# process each label
for label in $labels; do
    echo "Processing label $label ..."

    # get label fragment from Installomator repo
    fragment=$(curl -sL $(labelFromInstallomator $label))
    if [[ "$fragment" == *"404"* ]]; then
        echo "🚨 no fragment for label $label 🚨"
        continue
    fi
    
    # Process the fragment in a case block which should match the label
    caseStatement="
    case $label in
        $fragment
        *)
            echo \"$label didn't match anything in the case block - weird.\"
        ;;
    esac
    "
    eval $caseStatement
    
    if [[ -n $name ]]; then
        previousVersion=$(grep -e "^${name} " ${appListFile} | awk '{print $NF}')
        # read -s -k '?Press any key to continue.'
        if [[ "$previousVersion" != "$appNewVersion" ]]; then
            if [[ -z $previousVersion ]]; then 
                echo "⭐️ New App $name -> $appNewVersion"
                # app not found - add to the  appListFile 
                echo "$name $appNewVersion" >> ${appListFile}
            else
                echo "📡 Updating $name from $previousVersion -> $appNewVersion"
                # update the  appListFile 
                sed -i "" "s/^$name .*/$name $appNewVersion/g"  ${appListFile}
            fi
            formattedOutput+="$name $appNewVersion, "
        else
            echo "✅ No Update for $name -> $appNewVersion"
        fi
    fi
    unset appNewVersion
    unset name
    unset previousVersion
done

echo "**** text for report"
echo ""
echo $formattedOutput
echo ""
echo "****"

# clean up 
rm "$functionsPath"
