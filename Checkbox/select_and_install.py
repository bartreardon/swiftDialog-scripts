#!/usr/bin/python3

import time
import os
import subprocess
import json

# [appname, install_trigger]
app_array = [ 
	["Firefox","jamf policy -event FIREFOX"],
	["Microsoft Edge", "installomator.sh microsoftedge"],
	["Google Chrome", "installomator.sh googlechrome"],
	["Adobe Photoshop", "jamf policy -event PHOTOSHOP"],
	["Some Other Stuff", "jamf policy -event OTHERSTUFF"],
	["Some More Stuff", "jamf policy -event MORESTUFF"]
	]

dialogApp = "/usr/local/bin/dialog"	

progress = 0
progress_steps = 100
progress_per_step = 1

# build string array for dialog to display
app_list = []
for app_name in app_array:
	app_list.append(["⬜️",app_name[0],app_name[1]])


def writeDialogCommands(command):
	file = open("/var/tmp/dialog.log", "a")
	file.writelines("{}\n".format(command))
	file.close()
	

def updateDialogCommands(array, steps):
	string = "__Installing Software__\\n\\n"
	
	for item in array:
		string = string + "{} - {}  \\n".format(item[0],item[1])
		
	writeDialogCommands("message: {}".format(string))
	if steps > 0:
		writeDialogCommands("progress: {}".format(steps))
		

# app string
app_string = ""
for app_name in app_array:
	app_string = "{} --checkbox '{}'".format(app_string, app_name[0])


# Run dialogApp and return the results as json
dialog_cmd = "{} --title 'Software Installation' \
--message 'Select Software to install:' \
--icon SF=desktopcomputer.and.arrow.down,colour1=#3596f2,colour2=#11589b \
--button1text Install \
-2 -s --height 420 --json {} ".format(dialogApp, app_string)
			
result = subprocess.Popen(dialog_cmd, shell=True, stdout=subprocess.PIPE)
text = result.communicate()[0]   # contents of stdout
#print(text)

result_json = json.loads(text)

print(result_json)

for key in result_json:
	print(key, ":", result_json[key])
	for i, app_name in enumerate(app_list):
		#print(i)
		if key == app_name[1] and result_json[key] == False:
			print("deleting {} at index {}".format(key, i))
			app_list.pop(i)

print(app_list)

# re-calc steps per item
progress_per_step = progress_steps/len(app_list)

os.system("{} --title 'Software Installation' \
				--message 'Software Install is about to start' \
				--button1text 'Please Wait' \
				--icon SF=desktopcomputer.and.arrow.down,colour1=#3596f2,colour2=#11589b \
				--blurscreen \
				--progress {} \
				-s --height 420 \
				&".format(dialogApp, progress_steps))

# give time for Dialog to launch
time.sleep(0.5)
writeDialogCommands("button1: disable")

time.sleep(2)
writeDialogCommands("title: Software Installation")
writeDialogCommands("button1text: Please Wait")
writeDialogCommands("progress: 0")

#Process the list
for app in app_list:
	progress = progress + progress_per_step
	writeDialogCommands("progressText: Installing {}...".format(app[1]))
	app[0] = "⏳"
	
	updateDialogCommands(app_list, 0)
	
	##### This is where you'd perform the install
	
	# Pretend install happening 
	print("Right now we would be running this command\n : {}".format(app[2]))
	time.sleep(1) 
	writeDialogCommands("progress: increment")
	time.sleep(1)
	writeDialogCommands("progress: increment")
	time.sleep(1)
	writeDialogCommands("progress: increment")
	time.sleep(1)
	writeDialogCommands("progress: increment")
	
	app[0] = "✅"
	
	updateDialogCommands(app_list, progress)
	writeDialogCommands("progressText: Installing {}...".format(app[1]))
	time.sleep(1)

writeDialogCommands("icon: SF=checkmark.shield.fill,colour1=#27db2d,colour2=#1b911f")
writeDialogCommands("progressText: Complete")		
writeDialogCommands("button1text: Done")
writeDialogCommands("button1: enable")