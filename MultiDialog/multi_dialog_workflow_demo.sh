#!/bin/bash

##########################################################################################################
#
# © Bart Reardon 2023
#
# This script is an example of running multiple instances of swiftDialog on top of each other
#   in order to display multiple "screens" or steps required to gather information
# 
# The purpose of this script is not to be a complete solution but to serve as an example process that
#   could be used in a workflow where you want to present information that is dependant on prior user input
#
# This script can be run to demonstrate how such a process would work but should not be used
#  as-is as a basis for a production workflow without a lot of additional work
#
# All origional content in this demonstration script is free to use with no warranty or support
#
##########################################################################################################

## Dialog defenition 
## standard branding stuff to modify the experience
dialog_title="Welcome to Multi Dialog workflow demo"
dialog_icon="/Library/Application Support/Dialog/Dialog.app"
dialog_banner="" # not used yet
# ... etc

## JSON Processing stuff
# Sourced from  https://github.com/RandomApplications/JSON-Shell-Tools-for-macOS

json_value() { # Version 2023.7.24-1 - Copyright (c) 2023 Pico Mitchell - MIT License - Full license and help info at https://randomapplications.com/json_value
	{ set -- "$(/usr/bin/osascript -l 'JavaScript' -e 'ObjC.import("unistd"); function run(argv) { const stdin = $.NSFileHandle.fileHandleWithStandardInput; let out; for (let i = 0;' \
		-e 'i < 3; i ++) { let json = (i === 0 ? argv[0] : (i === 1 ? argv[argv.length - 1] : ($.isatty(0) ? "" : $.NSString.alloc.initWithDataEncoding((stdin.respondsToSelector("re"' \
		-e '+ "adDataToEndOfFileAndReturnError:") ? stdin.readDataToEndOfFileAndReturnError(ObjC.wrap()) : stdin.readDataToEndOfFile), $.NSUTF8StringEncoding).js.replace(/\n$/, "")))' \
		-e '); if ($.NSFileManager.defaultManager.fileExistsAtPath(json)) json = $.NSString.stringWithContentsOfFileEncodingError(json, $.NSUTF8StringEncoding, ObjC.wrap()).js; if (' \
		-e '/^\s*[{[]/.test(json)) try { out = JSON.parse(json); (i === 0 ? argv.shift() : (i === 1 && argv.pop())); break } catch (e) {} } if (out === undefined) throw "Failed to" +' \
		-e '" parse JSON."; argv.forEach(key => { out = (Array.isArray(out) ? (/^-?\d+$/.test(key) ? (key = +key, out[key < 0 ? (out.length + key) : key]) : (key === "=" ? out.length' \
		-e ': undefined)) : (out instanceof Object ? out[key] : undefined)); if (out === undefined) throw "Failed to retrieve key/index: " + key }); return (out instanceof Object ?' \
		-e 'JSON.stringify(out, null, 2) : out) }' -- "$@" 2>&1 >&3)"; } 3>&1; [ "${1##* }" != '(-2700)' ] || { set -- "json_value ERROR${1#*Error}"; >&2 printf '%s\n' "${1% *}"; false; }
}

json_extract() { # Version 2023.7.24-1 - Copyright (c) 2023 Pico Mitchell - MIT License - Full license and help info at https://randomapplications.com/json_extract
    	{ set -- "$(/usr/bin/osascript -l JavaScript -e 'ObjC.import("unistd");var run=argv=>{const args=[];let p;argv.forEach(a=>{if(!p&&/^-[^-]/.test(a)){a=a.split("").slice(1);for(const i in a){args.push("-"+a[i' \
	-e ']);if(/[ieE]/.test(a[i])){a.length>+i+1?args.push(a.splice(+i+(a[+i+1]==="="?2:1)).join("")):p=1;break}}}else{args.push(a);p=0}});let o,lA;for(const i in args){if(args[i]==="-i"&&!/^-[eE]$/.test(lA)){o=' \
	-e 'args.splice(+i,2)[1];break}lA=args[i]}const fH=$.NSFileHandle,hWS="fileHandleWithStandard",rtS="respondsToSelector";if(!o||o==="-"){const rdEOF="readDataToEndOfFile",aRE="AndReturnError";const h=fH[hWS+' \
	-e '"Input"];o=$.isatty(0)?"":$.NSString.alloc.initWithDataEncoding(h[rtS](rdEOF+aRE+":")?h[rdEOF+aRE](ObjC.wrap()):h[rdEOF],4).js.replace(/\n$/,"")}if($.NSFileManager.defaultManager.fileExistsAtPath(o))o=$' \
	-e '.NSString.stringWithContentsOfFileEncodingError(o,4,ObjC.wrap()).js;if(/^\s*[{[]/.test(o))o=JSON.parse(o);let e,eE,oL,o0,oT,oTS;const strOf=(O,N)=>typeof O==="object"?JSON.stringify(O,null,N):(O=O["to"+' \
	-e '"String"](),oT&&(O=O.trim()),oTS&&(O=O.replace(/\s+/g," ")),O),ext=(O,K)=>Array.isArray(O)?/^-?\d+$/.test(K)?(K=+K,O[K<0?O.length+K:K]):void 0:O instanceof Object?O[K]:void 0,ar="array",dc="dictionary"' \
	-e ',iv="Invalid option",naV="non-"+ar+" value";if(o||args.length){args.forEach(a=>{const isA=Array.isArray(o);if(e){o=ext(o,a);if(o===void 0)throw(isA?"Index":"Key")+" not found in "+(isA?ar:dc)+": "+a;e=' \
	-e '0}else if(eE){o=o.map(E=>(E=ext(E,a),E===void 0?null:E));eE=0}else if(a==="-l")oL=1;else if(a==="-0")o0=1;else if(a==="-t")oT=1;else if(a==="-T")oT=oTS=1;else{const isO=o instanceof Object;if(isO&&a===' \
	-e '"-e")e=1;else if(isA&&a==="-E")eE=1;else if(isA&&a==="-N")o=o.filter(E=>E!==null);else if(isO&&a==="-S")while(o instanceof Object&&Object.keys(o).length===1)o=o[Object.keys(o)[0]];else if(isA&&a==="-f"' \
	-e '&&typeof o.flat==="function")o=o.flat(Infinity);else if(isA&&a==="-s")o.sort((X,Y)=>strOf(X).localeCompare(strOf(Y)));else if(isA&&a==="-u")o=o.filter((E,I,A)=>A.indexOf(E)===I);else if(isO&&/^-[ckv]$/.' \
	-e 'test(a))o=a==="-c"?Object.keys(o).length:a==="-k"?Object.keys(o):Object.values(o);else if(/^-[eSckv]$/.test(a))throw iv+" for non-"+dc+" or "+naV+": "+a;else if(/^-[ENfsu]$/.test(a))throw iv+" for "+naV' \
	-e '+": "+a;else throw iv+": "+a}});const d=o0?"\0":"\n";o=((oL||o0)&&Array.isArray(o)?o.map(E=>strOf(E)).join(d):strOf(o,2))+d}o=ObjC.wrap(o).dataUsingEncoding(4);const h=fH[hWS+"Output"],wD="writeData";h[' \
	-e 'rtS](wD+":error:")?h[wD+"Error"](o,ObjC.wrap()):h[wD](o)}' -- "$@" 2>&1 >&3)"; } 3>&1; [ "${1##* }" != '(-2700)' ] || { set -- "json_extract ERROR${1#*Error}"; >&2 printf '%s\n' "${1% *}"; false; }
}

json_create() { # Version 2023.7.24-1 - Copyright (c) 2023 Pico Mitchell - MIT License - Full license and help info at https://randomapplications.com/json_create
	/usr/bin/osascript -l 'JavaScript' -e 'ObjC.import("unistd"); function run(argv) { let stdin = $.NSFileHandle.fileHandleWithStandardInput, out = [], dictOut = false, stdinJson' \
	-e '= false, isValue = true, keyArg; if (!$.isatty(0)) { stdin = $.NSString.alloc.initWithDataEncoding((stdin.respondsToSelector("readDataToEndOfFileAndReturnError:") ? stdin.' \
	-e 'readDataToEndOfFileAndReturnError(ObjC.wrap()) : stdin.readDataToEndOfFile), $.NSUTF8StringEncoding).js; if (/^\s*[{[]/.test(stdin)) try { out = JSON.parse(stdin); dictOut' \
	-e '= !Array.isArray(out); stdinJson = true } catch (e) {} } if (argv[0] === "-d") { if (!stdinJson) { out = {}; dictOut = true } if (dictOut) argv.shift() } argv.forEach((arg' \
	-e ', index) => { if (dictOut) isValue = ((index % 2) !== 0); if (isValue) if (/^\s*[{[]/.test(arg)) try { arg = JSON.parse(arg) } catch (e) {} else ((/\d/.test(arg) && !isNaN' \
	-e '(arg)) ? arg = +arg : ((arg === "true") ? arg = true : ((arg === "false") ? arg = false : ((arg === "null") && (arg = null))))); (dictOut ? (isValue ? out[keyArg] = arg :' \
	-e 'keyArg = arg) : out.push(arg)) }); if (dictOut && !isValue && (keyArg !== void 0)) out[keyArg] = null; return JSON.stringify(out, null, 2) }' -- "$@"
}

## END Json processing stuff

## Setup stuff
commandFileRoot="/var/tmp"
backgroundCommandFile="${commandFileRoot}/background.log"
stepCommandFileTemplate="step<int>.log"

# make sure the specified command file has the correct permissions
initalise_command_file() {
    touch $1
    chmod 666 $1
}

# launch the background dialog 
background_dialog() {
    dialog --jsonstring "$@"
    result=$?
    echo "Exit code of background was $result"
}

# launch forground dialogs
foreground_dialog() {
    dialog --jsonstring "$@" --ontop --json
    result=$?
    echo "Exit code of foreground was $result"
}

# Cleans up json output from swiftDialog, or at least tries to
clean_json() {
    local input="$1"

    # Remove lines starting with "ERROR"
    cleaned_input=$(echo "$input" | grep -v '^ERROR')

    local open_bracket_index
    local close_bracket_index

    open_bracket_index=$(echo "$cleaned_input" | grep -b -o '{' | head -n 1 | cut -d ':' -f 1)
    close_bracket_index=$(echo "$cleaned_input" | grep -b -o '}' | tail -n 1 | cut -d ':' -f 1)

    if [[ -n $open_bracket_index && -n $close_bracket_index ]]; then
        local json_blob="${cleaned_input:$open_bracket_index:$((close_bracket_index - open_bracket_index + 1))}"
        echo "$json_blob"
    else
        echo "No valid JSON blob found."
    fi
}

# removes newlines so we can pass it in as one long json string (lets see you to that YAML)
flatten_json() {
    echo "${1//$'\n'}"
}

# the main dialog json template
dialog_json_template() {
    inputblob=$1
    buttonvalue=$2
    if [[ -z $buttonvalue ]]; then
        buttonvalue="Next"
    fi
    read -r -d '' jsonblob << EOM
    {
        "title" : "${dialog_title}",
        "icon" : "${dialog_icon}",
        ${inputblob},
        "height" : "450",
        "button1text" : "${buttonvalue}"
    }
EOM
    echo $(flatten_json "${jsonblob}")
}

# take the json output from a dialog and turn options into a 
listitems_from_options() {
    step2resultsjson=$1

    # load the results of an options screen and generate a list of items
    # for options that are set to "true"
    IFS=$'\n'
    keys=$(json_extract -k -i "${step2resultsjson}" -l)
    for key in $keys; do
        option_selected=$(json_extract -e "$key" -i "${step2resultsjson}")
        if [[ "$option_selected" == "true" ]]; then
            listitemjson+="{\"title\" : \"${key}\", \"status\" : \"pending\"},"
        fi
    done
    # remove the last ","
    listitemjson=${listitemjson%?}

    read -r -d '' listitemsjson << EOM
    "listitem" : [
        ${listitemjson}
    ]
EOM
    # return completed json
    echo "${listitemsjson}"
}

textfield_from_array() {
    textfield_array=("$@")

    for textfield in "${textfield_array[@]}"; do
        textfileds+="{\"title\" : \"${textfield}\"},"
    done
    # remove the last ","
    textfileds=${textfileds%?}

    read -r -d '' textfieldjson << EOM
    "textfield" : [
        ${textfileds}
    ]
EOM

    # return completed json
    echo "${textfieldjson}"
}

## END setup stuff


## set this to the number of steps you have plus 1
number_of_steps=4

## Step 1
# One option is to define the textfields json   
read -r -d '' step1extras << EOM
  "textfield" : [
    {"title" : "Text Field 1", "prompt" : "Field 1 Prompt"},
    {"title" : "Text Field 2", "prompt" : "Field 2 Prompt" },
    {"title" : "Text Field 3", "prompt" : "Field 3 Prompt" },
    {"title" : "Text Field 4", "prompt" : "Field 4 Prompt" }
  ]
EOM

# or generate the textfields from an array of items
text_input_fields=("First Name" "Favourite Colour" "Some Random Thing")
step1extras=$(textfield_from_array "${text_input_fields[@]}")

## Step 2
read -r -d '' step2extras << EOM
  "checkbox" : [
	  {"label" : "Option 1", "icon" : "sf=sun.max.circle,colour=yellow", "checked" : true, "disabled" : true },
	  {"label" : "Option 2", "icon" : "sf=cloud.circle,colour=grey", "checked" : true },
	  {"label" : "Option 3", "icon" : "sf=car.rear,colour=red", "checked" : false },
	  {"label" : "Option 4", "icon" : "sf=moon,colour=yellow", "checked" : true, "disabled" : true },
	  {"label" : "Option 5", "icon" : "sf=gamecontroller,colour=teal", "checked" : false },
	  {"label" : "Option 6", "icon" : "sf=person.badge.clock.fill,colour=blue", "checked" : true }
  ],
  "checkboxstyle" : {
    "style" : "switch",
    "size"  : "regular"
  }  
EOM

## Step 3
# auto generated from the output of step 2

## Background dialog (the one people won't interact with) 

read -r -d '' background << EOM
{
  "title" : "none",
  "icon" : "none",
  "message" : "none",
  "button1text" : "none",
  "width" : "800", 
  "height" : "60",
  "progress" : "${number_of_steps}",
  "progresstext" : "Please Wait",
  "position"  : "bottom",
  "blurscreen" : true, 
  "commandfile" : "${backgroundCommandFile}"
}
EOM


# initiate command files
initalise_command_file "$backgroundCommandFile"

# kick off the background dialog
backgroundjson=$(flatten_json "${background}")
background_dialog "${backgroundjson}" &
background_dialog_pid=$!
# echo "background pid is $background_dialog_pid"

## this is the main loop
# As long as the background dialog is running, this loop will process items.
while kill -0 $background_dialog_pid 2> /dev/null; do
    # little sleep to get things started
    sleep 1
    
    # step 1
    message="Please enter a bunch of details<br><br>Click **Next** to continue"
    step1json=$(dialog_json_template "${step1extras}" "Next")
    echo "progresstext: Doing step 1" >> "${backgroundCommandFile}"
    echo "progress: increment" >> "${backgroundCommandFile}"
    step1resultsjson=$(clean_json "$(foreground_dialog "${step1json}" --message "${message}")")
    sleep 0.1

    # you could loop through the array for step 1 to collect values. for this demo we only collect the first
    first_name=$(json_value "First Name" "${step1resultsjson}")
    if [[ -z $first_name ]]; then
        first_name="Bob"
    fi

    # step 2
    message="### Thanks ${first_name}<br><br>The following Items will be installed<br><br>Adjust your selection as needed.<br>_Some items are required and cannot be skipped_"
    step2json=$(dialog_json_template "${step2extras}" "Continue")
    echo "progresstext: Doing step 2" >> "${backgroundCommandFile}"
    echo "progress: increment" >> "${backgroundCommandFile}"
    step2resultsjson=$(clean_json "$(foreground_dialog "${step2json}" --message "${message}")")
    sleep 0.1

    # step 3
    message="The following Items Were selected"
    step3json=$(dialog_json_template "$(listitems_from_options "${step2resultsjson}")" "Finish")
    echo "progresstext: Doing step 3" >> "${backgroundCommandFile}"
    echo "progress: increment" >> "${backgroundCommandFile}"

    # For list processing we want a background process for updating the step3 dialog window
    ## not yet written

#   do_some_background_processing $step2resultsjson &

    # with that kicked off, display the step 3 dialog. The background process will take
    # care of updating and quitting or whatever

    step3resultsjson=$(clean_json "$(foreground_dialog "${step3json}" --message "${message}")")
    sleep 0.1
    
    # ... other steps here

    # Finished
    echo "progress: complete" >> "${backgroundCommandFile}"
    echo "progresstext: All Done" >> "${backgroundCommandFile}"
    sleep 1
    echo "quit:" >> "${backgroundCommandFile}"
    sleep 0.5
done

# Completed the visual component, now to process any other remaining returned values
# check out https://github.com/RandomApplications/JSON-Shell-Tools-for-macOS for 
# how to use the json functions listed above
# just echoing the results for now

echo "${step1resultsjson}"
echo "${step2resultsjson}"

