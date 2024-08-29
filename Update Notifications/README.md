# Update Notifications

## updatePrompt.sh

This script uses swiftDialog to present a minimal update prompt with deferral that looks for the required OS version and presents an update notification if the requirements are not met.

It uses the [SOFA](https://sofa.macadmins.io) feed for OS and patch information 

It has very few options and is designed to be set and forget in order to automatically notify users of software updates for their OS. It determines the latest availavle version of the installed OS so it's easy to keep running as an ongoing task and users will receive the update automatically when required. Sane update policies are encouraged.

Supports macOS 12+

### Behaviour

By default when it detects an update is available it will wait the specified time period before activating. If the user dismisses the dialog, a record of the deferral is kept. If the maximum number of deferrals is reached the dialog becomes increasingly obtrusive. If the installed OS is too old then the ability to defer is limited. If the hardware is too old to run the latest version of macOS, the user will be notified.

This script doesn't perform any actual installing and will simply re-direct the user to System Preferences/Settings -> Software Update panel. For a more full featured and customisable experience, I'd encourage the use of [Nudge](https://github.com/macadmins/nudge).

If the device is enrolled to Jamf Pro, the Self Service banner and icon are used for the banner and icon.

### Arguments 

_(all are optional and will use defaults if not set. Matches the Jamf Pro schema for script arguments but Jamf is not required to use this script)_

```
1 - unused
2 - computer name
3 - logged in user
4 - max deferrals - default 5
     number of deferrals a user has. Set to 0 to disable
5 - nag after days - default 7
      number of days to wait until the notification is shows
6 - Required after days - default 14
      Days to notify the user that the update is manditory  
7 - support Text
     additional text you want inserted into the message (e.g. "For any questions please contact the [Help Desk](https://help.desk/link)"
     This will be displayed below system and patch info in the help area when displayed
8 - Preference domain - default com.orgname.macosupdates
     Preferences and feed cache will be stored in /Library/Applciation Support/$domain/
```

<img width="550" alt="Screenshot 2024-08-15 at 10 36 23 PM" src="https://github.com/user-attachments/assets/4543c200-804f-4732-a930-6857599dc7af">

<img width="500" alt="image" src="https://github.com/user-attachments/assets/bf2e6ab1-07c4-4c76-9960-54933cf67de6">


## appupdate_with_deferral.sh

A general pop up dialog to allow the user to defer the install of some application. Will require two policies, one to present the dialog, and another to perform the actual application install.

This script is written to be used as a jamf pro policy. The parameters accepted are:
 
 - Title - sets the title of the dialog
 - App to update - path of the application (e.g. /Applications/Firefox.app)
 - App version required - version you want to be installed (e.g. 10.2.3)
 - Max deferrals - number of deferrals to allow
 - Additional info (optional) - any additional text you want to appear in the dialog
 - Policy trigger - the jamf policy trigger to run 
 
 When "Max deferrals" is met, the defer button will also trigger the install
 
