#!/bin/bash

# This function can be used to parse JSON results from a dialog command

function get_json_value () {
	# usage: get_json_value "$JSON" "key 1" "key 2" "key 3"	 
	for var in "${@:2}"; do jsonkey="${jsonkey}['${var}']"; done
    JSON="$1" osascript -l 'JavaScript' \
        -e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
        -e "JSON.parse(env)$jsonkey"
}

# example usage

UserPromptJSON='{
  "title" : "Device Setup",
  "message" : "Please set a computer name and choose the appropriate State and Department for where you normally work.\n\nFeel free to also leave a comment",
  "textfield" : [
  	 {"title" : "Computer Name", "required" : false, "prompt" : "Computer Name"},
  	 {"title" : "Comment", "required" : false, "prompt" : "Enter a comment"}
  ],
  "selectitems" : [
    {"title" : "Select State", "values" : ["ACT","NSW","VIC","QLD","TAS","SA","WA","NT"]},
    {"title" : "Department",
    "values" : [
			  "Business Development",
			  "Chief of Staff",
		  	"Commercial",
			  "Corporate Affairs",
			  "Executive",
		  	"Finance",
		  	"Governance",
			  "Human Resources",
		  	"Information Technology",
		  	"Services"
			]
	}],
	"icon" : "SF=info.circle",
	"centreicon" : true,
	"alignment" : "centre",
	"button1text" : "Next",
	"height" : "450"
}'

# make a temp file for storing our JSON
tempfile=$(mktemp)
echo $UserPromptJSON > $tempfile

# run dialog and store the JSON results in a variable
results=$(/usr/local/bin/dialog --jsonfile $tempfile --json)

# clean up
rm $tempfile

# extract the various values from the results JSON
state=$(get_json_value "$results" "Select State" "selectedValue")
department=$(get_json_value "$results" "Department" "selectedValue")
compname=$(get_json_value "$results" "Computer Name")
comment=$(get_json_value "$results" "Comment")

echo "Computer name is $compname"
echo "Department is $division"
echo "State is $state"
echo "Comment is $comment"

# continue processing from here ...
