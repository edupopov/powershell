echo off
reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\SrpV2\Appx /f
reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\SrpV2\Exe /f
reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\SrpV2\Msi /f
reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\SrpV2\Script /f
reg delete HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Srp\Gp /v LastGpNotifyTime /f
reg delete HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Srp\Gp /v LastWriteTime /f
reg delete HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Srp\Gp /v RuleCount /f
net stop AppIDSvc
del C:\Windows\System32\AppLocker\Appx.AppLocker
del C:\Windows\System32\AppLocker\Dll.AppLocker
del C:\Windows\System32\AppLocker\Exe.AppLocker
del C:\Windows\System32\AppLocker\Msi.AppLocker
del C:\Windows\System32\AppLocker\Script.AppLocker
del C:\Windows\System32\AppLocker\AppCache.dat
net start AppIDSvc
exit
