## reportVersionForLabel.sh

This script was written to take an array of labels, and generate a (really) basic report on the app name and version available. It's intended use is a weekly report that details a list of which Installomator labels have received an application update. It can certainly be run more frequently than that if required.

It will download and import the Installomator [functions.sh](https://github.com/Installomator/Installomator/blob/main/fragments/functions.sh) as well as the label fragments from the Installomator repo.

Labels are assumed to have the same file name as the label name. When downloaded they are stripped of case pattern and `;;` and `eval`-ed. The package name and `appNewVersion` is then used.

Results are also saved to a simple text file and re-used on the next run. The final report only includes labels that are new or updated since the last run.

There is no swiftDialog integration at this point but an interactive option may be something that gets planned.
