# Update Notifications

## updatePrompt.sh

This script presents a [Nudge](https://github.com/macadmins/nudge) style update prompt with deferral that looks for the requires OS version and presents an update notification if the requirements are not met.

Can determine the latest version of the installed OS so easy to keep running as an ongoing policy and users will receive the update automatically (sane policy triggers/conditions are encouraged)

This script doesn't perform any actual installing and will simply re-direct the user to System Preferences/Settings -> Software Update panel.

### Arguments (all are optional and will use defaults if not set)

```
1 - Path (if running locally you can use "test" as the first argument to force check against a different version of macOS instead of the current one - useful for validation testing)
2 - computer Name
3 - logged in user
4 - required OS Version - defaults to the latest release for the major version of the current OS
5 - days Until Required - default 14. Days to wait after the release date to force the prompt. 0 = immediate
6 - infolink - default "https://support.apple.com/en-au/HT201222". Long for the Info button
7 - support Text - additional text you want inserted into the message (e.g. "For any questions please contact the [Help Desk](https://help.desk/link)"
8 - Icon - defaults to the OS version icon for the current release (supports macOS 11, 12 and 13)
9 - swiftDialog Version - default "2.3.2" - specifies the minimum version of swiftDialog for this script.
```

<img width="550" alt="image" src="https://github.com/bartreardon/swiftDialog-scripts/assets/3598965/a03b2a29-7609-49f9-b36c-c000d90cb34e">



## appupdate_with_deferral.sh

Pop up a dialog to allow the user to defer the install of some application. Will require two policies, one to present the dialog, and another to perform the actual application install.

This script is written to be used as a jamf pro policy. The parameters accepted are:
 
 - Title - sets the title of the dialog
 - App to update - path of the application (e.g. /Applications/Firefox.app)
 - App version required - version you want to be installed (e.g. 10.2.3)
 - Max deferrals - number of deferrals to allow
 - Additional info (optional) - any additional text you want to appear in the dialog
 - Policy trigger - the jamf policy trigger to run 
 
 When "Max deferrals" is met, the defer button will also trigger the install
 
 ![image](https://user-images.githubusercontent.com/3598965/161907703-cd309288-f8d7-4fd1-9ac5-95f8cf333e36.png)
