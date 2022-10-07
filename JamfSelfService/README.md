## A Jamf Pro script to provide install feedback from Self Service

This script will run a jamf policy while providing some user feedback as to the progress which it gets from reading `/var/log/jamf.log`

It requires two policies. One is the self service policy and contains this script. The other is the policy that will be performing the install or other task

The script takes three parameters:

 - (4) policy name - A human readable description
 - (5) policy Trigger - The custom trigger to call 
 - (6) icon - an icon resource to display (recommended, the http source of the self service policy icon)

![image](https://user-images.githubusercontent.com/3598965/194520608-eeeee4c8-e3a2-472b-bb8f-23817e492255.png)
