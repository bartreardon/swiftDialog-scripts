#!/usr/bin/python3

import json
import os

dialog_app = "/Library/Application Support/Dialog/Dialog.app/Contents/MacOS/Dialog"

contentDict = {"title" : "An Important Message", 
            "titlefont" : "name=Chalkboard,colour=#3FD0a2,size=40",
            "message" : "This is a **very important** messsage and you _should_ read it carefully\n\nThis is on a new line",
            "icon" : "/Applications/Safari.app",
            "hideicon" : 0,
            "infobutton" : 1,
            "quitoninfo" : 1
            }

jsonString = json.dumps(contentDict)

# passing json in directly as a string

print("Using string Input")
os.system("'{}' --jsonstring '{}'".format(dialog_app, jsonString))


# creating a temporary file

print("Using file Input")

# create a temporary file
jsonTMPFile = "/tmp/dialog.json"
f = open(jsonTMPFile, "w")
f.write(jsonString)
f.close()

os.system("'{}' --jsonfile {}".format(dialog_app, jsonTMPFile))

# clean up
os.remove(jsonTMPFile)
