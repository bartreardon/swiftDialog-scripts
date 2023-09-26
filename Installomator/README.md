## reportVersionForLabel.sh

This script was written to take an array of labels, and generate a (really) basic report on the app name and version available. It's intended use is a weekly report that details a list of which Installomator labels have received an application update. It can certainly be run more frequently than that if required.

It will download and import the Installomator [functions.sh](https://github.com/Installomator/Installomator/blob/main/fragments/functions.sh) as well as the label fragments from the Installomator repo.

Labels are assumed to have the same file name as the label name. When downloaded they are stripped of case pattern and `;;` and `eval`-ed. The package name and `appNewVersion` is then used.

Results are also saved to a simple text file and re-used on the next run. The final report only includes labels that are new or updated since the last run.

There is no swiftDialog integration at this point but an interactive option may be something that gets planned.

Raw output will look something like:

```bash
$ ./reportVersionForLabel.sh
Processing label microsoftedge ...
📡 Updating Microsoft Edge from 117.0.2045.35 -> 117.0.2045.40
Processing label alfred ...
📡 Updating Alfred from 5.1.2 -> 5.1.3
Processing label caffeine ...
✅ No Update for Caffeine -> 1.1.3
Processing label citrixworkspace ...
✅ No Update for Citrix Workspace -> 23.08.0.57
Processing label coconutbattery ...
📡 Updating coconutBattery from 3.9.13 -> 3.9.14
Processing label adobecreativeclouddesktop ...
✅ No Update for Adobe Creative Cloud -> 6.0.0.571
Processing label cyberduck ...
✅ No Update for Cyberduck -> 8.6.3
Processing label firefoxpkg ...
📡 Updating Firefox from 117.0.1 -> 118.0
Processing label gimp ...
✅ No Update for GIMP -> 2.10.34
Processing label googlechromepkg ...
📡 Updating Google Chrome from 117.0.5938.88 -> 117.0.5938.92
**** text for report

Microsoft Edge 117.0.2045.40, Alfred 5.1.3, coconutBattery 3.9.14, Firefox 118.0, Google Chrome 117.0.5938.92 

****
``` 
