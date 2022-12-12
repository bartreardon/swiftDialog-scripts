# Update Notifications

## updatePrompt.sh

This script presents a [Nudge](https://github.com/macadmins/nudge) style update prompt that looks for the requires OS version and presents an update notification if the requirements are not met.

This script doesn't perform any type of processing or checking and will re-direct the user to System Preferences -> Software Update panel.

![image](https://user-images.githubusercontent.com/3598965/161907377-d9187317-eb88-459a-84cc-589ec10387e5.png)

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
