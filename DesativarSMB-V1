#################################################
#             Desabilitar SMB 1.0               #
#################################################
# Você pode desabilitar o SMB 1.x nos sistemas Windows 7, Windows Server 2008 R2, Windows Vista e Windows Server 2008 editando o 
# registro ou executando o seguinte comando no Windows PowerShell 2.0:

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" SMB1 -Type DWORD -Value 0 -Force

# Você pode desabilitar o SMB 1.x em sistemas Windows 8 e mais recentes, ou Windows Server 2012 e mais recentes, com o seguinte 
# comando:
Set-SmbServerConfiguration –EnableSMB1Protocol $false

# Você pode desinstalar o SMB 1 do Windows 8.1 e versões mais recentes com o seguinte cmdlet:
Remove-WindowsFeature FS-SMB1

# No Windows 10 ou no Windows Server 2016, você pode habilitar a auditoria do tráfego do SMB 1.x com o seguinte cmdlet:
Set-SmbServerConfiguration –AuditSmb1Access $true

# Para visualizar e gerar eventos de auditoria, você pode usar o seguinte cmdlet:
Get-WinEvent -LogName Microsoft-Windows-SMBServer/Audit
