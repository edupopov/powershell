# Coleta o tempo de atividade que um servidor e/ou estacao de trabalho esta no ar sem reboot com powershell
(get-date) - (gcim Win32_OperatingSystem).LastBootUpTime

# Coleta informações completas do servidor com powershell
Get-CimInstance Win32_OperatingSystem | Select-Object *

# Coleta os dados pelo LastBootTime usando o wmic, porem é necessario converter para ficar legível
wmic os get lastbootuptime

# Coleta dados do servidor usando wmic
wmic os get Caption,Version,OSArchitecture,LastBootUpTime
