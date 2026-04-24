<#
.SYNOPSIS
Desmarca "O computador pode desligar o dispositivo para economizar energia"
(AllowComputerToTurnOffDevice) para NICs físicas e exibe um resumo final:
Suportado / Não suportado / Desativado.

.NOTES
- Requer PowerShell em modo Administrador. [1](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapterpowermanagement?view=windowsserver2025-ps)[2](https://learn.microsoft.com/en-us/powershell/module/netadapter/set-netadapterpowermanagement?view=windowsserver2025-ps)
- Usa Get-NetAdapterPowerManagement / Set-NetAdapterPowerManagement. [1](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapterpowermanagement?view=windowsserver2025-ps)[2](https://learn.microsoft.com/en-us/powershell/module/netadapter/set-netadapterpowermanagement?view=windowsserver2025-ps)
#>

# =========================
# Configurações
# =========================
$IncludeWiFi = $true   # $false = somente Ethernet (InterfaceType 6)
$LogPath     = "$env:ProgramData\DisableNICPowerSave.log"

# =========================
# Checagem de Admin
# =========================
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Error "Execute este script em um PowerShell 'Como Administrador'."
    exit 1
}

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Início" | Out-File -FilePath $LogPath -Append -Encoding utf8

# Lista para armazenar o status final
$results = New-Object System.Collections.Generic.List[object]

try {
    # Obtém adaptadores físicos
    $adapters = Get-NetAdapter -Physical -ErrorAction Stop

    if (-not $IncludeWiFi) {
        # InterfaceType 6 = Ethernet
        $adapters = $adapters | Where-Object { $_.InterfaceType -eq 6 }
    }

    foreach ($nic in $adapters) {

        # Tenta ler PowerManagement
        $pm = $null
        try {
            $pm = $nic | Get-NetAdapterPowerManagement -ErrorAction Stop  # requer admin [1](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapterpowermanagement?view=windowsserver2025-ps)
        }
        catch {
            # Se não conseguiu nem ler, marca como "Suportado" (genérico) e registra no log
            $results.Add([pscustomobject]@{
                Interface = $nic.Name
                Status    = "Suportado"
            })

            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Adapter='$($nic.Name)' ERRO ao consultar PowerManagement: $($_.Exception.Message)" |
                Out-File -FilePath $LogPath -Append -Encoding utf8

            continue
        }

        # Se o driver não suporta a opção (Unsupported), marca como "Não suportado" [4](https://stackoverflow.com/questions/46145449/disable-turn-off-this-device-to-save-power-for-nic)[1](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapterpowermanagement?view=windowsserver2025-ps)
        if ($pm.AllowComputerToTurnOffDevice -eq 'Unsupported') {
            $results.Add([pscustomobject]@{
                Interface = $pm.Name
                Status    = "Não suportado"
            })
            continue
        }

        # Tenta aplicar Disabled [3](https://learn.microsoft.com/en-us/answers/questions/5762553/how-to-disable-allow-the-computer-to-turn-off-this)[2](https://learn.microsoft.com/en-us/powershell/module/netadapter/set-netadapterpowermanagement?view=windowsserver2025-ps)
        try {
            $before = $pm.AllowComputerToTurnOffDevice

            $pm.AllowComputerToTurnOffDevice = 'Disabled'
            $pm | Set-NetAdapterPowerManagement -ErrorAction Stop  # cmdlet oficial [2](https://learn.microsoft.com/en-us/powershell/module/netadapter/set-netadapterpowermanagement?view=windowsserver2025-ps)

            # Reconsulta para confirmar (garante o status real) [1](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapterpowermanagement?view=windowsserver2025-ps)
            $pmAfter = Get-NetAdapterPowerManagement -Name $pm.Name -ErrorAction Stop

            if ($pmAfter.AllowComputerToTurnOffDevice -eq 'Disabled') {
                $results.Add([pscustomobject]@{
                    Interface = $pmAfter.Name
                    Status    = "Desativado"
                })
            }
            else {
                # Suporta (não é Unsupported), mas não ficou Disabled
                $results.Add([pscustomobject]@{
                    Interface = $pmAfter.Name
                    Status    = "Suportado"
                })
            }

            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Adapter='$($pm.Name)' AllowComputerToTurnOffDevice: $before -> $($pmAfter.AllowComputerToTurnOffDevice)" |
                Out-File -FilePath $LogPath -Append -Encoding utf8
        }
        catch {
            # Suporta, mas falhou ao aplicar
            $results.Add([pscustomobject]@{
                Interface = $pm.Name
                Status    = "Suportado"
            })

            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Adapter='$($pm.Name)' ERRO ao aplicar: $($_.Exception.Message)" |
                Out-File -FilePath $LogPath -Append -Encoding utf8
        }
    }

    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Fim (OK)" | Out-File -FilePath $LogPath -Append -Encoding utf8
}
catch {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERRO FATAL: $($_.Exception.Message)" | Out-File -FilePath $LogPath -Append -Encoding utf8
    throw
}

# =========================
# Listagem final solicitada
# =========================
Write-Host ""
Write-Host "===== STATUS FINAL - Power Management (NIC) ====="
$results | Sort-Object Interface | Format-Table -AutoSize Interface, Status
Write-Host "==============================================="
Write-Host ("Log: {0}" -f $LogPath)

# Encerra explicitamente para evitar qualquer “lixo” pós-fim ser interpretado
# exit 0
