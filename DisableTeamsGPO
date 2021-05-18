How to disable or enable auto start of Teams application using GPO
Posted on November 9, 2018 by Eswar Koneti | 9 Comments | 97,579 Views

 
When we started of with office 365 project ,one of the key application to be delivered to users is Teams application. Teams is the primary client for intelligent communications in Office 365, replacing Skype for Business Online over time. When we started deploying the teams clients to windows computers using SCCM Configmgr ,teams will auto startup upon computer restart/user logoff & log in and is by design .

When the Teams application is installed on windows PC (it doesn't require admin rights to install and installation location is C:\Users\%username%\AppData\Local\Microsoft\Teams ) ,it has auto-start application setting enabled by default. With this setting ,it create an entry in the registry in HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run

with value com.squirrel.Teams.Teams and data C:\Users\eswar.koneti\AppData\Local\Microsoft\Teams\Update.exe --processStart "Teams.exe" --process-start-args "--system-initiated" as shown below.

image

With the initial deployment ,we decided to remove this auto startup using group policy  for all users and let user start the application manually as they already using lync and teams is additional collaboration platform to use.

image

There are 2 reasons for us to remove the teams auto-start application using GPO.

1) we don't want every one to start using the application from the time we deploy silently to the end user PC’s

2)For those it got installed ,users complain that ,loading of teams when user login takes a while which slow down the PC.

How to delete the Auto-start application of teams  using GPO:

So ,to delete the auto-startup ,we use GPO (best way to remove this) by simply creating a registry key with delete and apply at OU level.

Following is the registry key used in GPO:

Location: User configuration\Preferences\windows settings\registry

Hive: HKEY_CURRENT_USER

Key path: Software\Microsoft\Windows\CurrentVersion\Run

Value Name: com.squirrel.Teams.Teams

image

So far looks good but when we are actually reaching completion of office 365 project that delivers every one to use Teams application ,we started sunset lync application.

When we disabled lync for users users started asking for auto-start application for teams and we already deleted it using GPO for everyone initially.

How to Enable the Auto-start application of teams using GPO (back to beginning) :

The registry key that was created by the application in the registry key was removed earlier and now if we want that to be back ,either user must go the application and enable the setting or we push the registry key using GPO.

Since i already noted the registry key that was created by the application so i created a GPO with following syntax and applied at  OU level.

image

As you can see above, the value data (C:\Users\%username%\AppData\Local\Microsoft\Teams\Update.exe --processStart "Teams.exe" --process-start-args "--system-initiated" ) that we used is same as the one that we deleted initially, but this doesn't work on end-user PC during logon.

The GPO applied correctly and teams never load automatically so i copied the syntax and tried opening in cmd window and it works but auto-start do not work.

so after spending sometime reviewing  ,finally fixed it by changing the command line from system-initiated to user-initiated

clip_image002

image

Value Data: C:\Users\%username%\AppData\Local\Microsoft\Teams\Update.exe --processStart "Teams.exe" --process-start-args "--user-initiated"

If the user have teams installed (if you did not change the default install location)  ,this GPO will launch teams automatically during login .

What happens if the computer doesn't have teams installed but still the GPO applied ? does it pop-up any error ? No ,there wont be any error or pop-up on the computers that doesn't have teams installed and you are safe to apply to everyone who want to have the auto-start application enabled.
