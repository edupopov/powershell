#################################################
#           Configurar servidor NTP             #
#################################################

reg.exe add  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" /v ServiceDllUnloadOnStop /t REG_DWORD /d 1 /f
reg.exe add  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" /v ServiceMain /t REG_SZ /d SvchostEntry_W32Time /f
reg.exe add  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" /v NtpServer /t REG_SZ /d 172.16.50.10,172.16.50.11,172.16.50.12,172.16.50.13 /f
reg.exe add  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" /v Type /t REG_SZ /d NTP /f
reg.exe add  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" /v ServiceDll /t REG_EXPAND_SZ /d %systemroot%\system32\w32time.dll /f
