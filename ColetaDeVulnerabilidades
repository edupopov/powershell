#################################################
#           Coleta de vulnerabilidades          #
# Hosts with Anonymous Enumeration Vulnerability#
# Hosts with Anonymous Access Vulnerability     #
# FTP Anonymous Access                          #
#################################################

Invoke-Command -ComputerName Server01 {
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" | Select-Object restrictanonymous, restrictanonymoussam
Write-Host "Evidence Anonymous Enumeration and Anonymous Access"}
