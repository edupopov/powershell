#################################################
#          Habilitar RDP remotamente1           #
#################################################

Invoke-Command -ComputerName client01 `
{Set-ItemProperty `
-Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'`
-Name "fDenyTSConnections" -Value 0; `
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"}
Test-NetConnection 10.10.1.105 -CommonTCPPort rdp

#################################################
#          Habilitar RDP remotamente2           #
#################################################

Invoke-Command  -ComputerName 172.30.0.28 -ScriptBlock {Enable-NetFirewallRule -DisplayGroup "Remote Desktop” -Verbose}
Test-NetConnection 172.30.0.28 -CommonTCPPort rdp

#################################################
#              Habilitar RDP local              #
#################################################

Enable Remote Desktop
(Get-WmiObject Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices).SetAllowTsConnections(1,1) | Out-Null
(Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null
Get-NetFirewallRule -DisplayName "Remote Desktop*" | Set-NetFirewallRule -enabled true
Test-NetConnection 172.30.0.28 -CommonTCPPort rdp

#################################################
#       Habilitar RDP local ou remoto           #
#################################################

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fdenyTSXonnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Test-NetConnection 172.30.0.28 -CommonTCPPort rdp
