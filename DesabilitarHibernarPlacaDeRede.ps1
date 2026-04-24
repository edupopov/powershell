<#
.SYNOPSIS
Desativa a opção "O computador pode desligar o dispositivo para economizar energia"
(AllowComputerToTurnOffDevice) e ao final lista: Suportado / Não suportado / Desativado.
#>

# --- Checagem de admin ---
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Error "Execute este script em um PowerShell 'Como Administrador'."
    exit 1
}

$IncludeWiFi = $true
$LogPath     = "$env:ProgramData\DisableNICPowerSave.log"

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Início" | Out-File -FilePath $LogPath -Append -Encoding utf8

$results = New-Object System.Collections.Generic.List[object]

try {
    $adapters = Get-NetAdapter -Physical -ErrorAction Stop

    if (-not $IncludeWiFi) {
        $adapters = $adapters | Where-Object { $_.InterfaceType -eq 6 } # 6 = Ethernet
    }

    foreach ($nic in $adapters) {

        try {
            $pm = $nic | Get-NetAdapterPowerManagement -ErrorAction Stop  # requer admin [1](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapterpowermanagement?view=windowsserver2025-ps)
        }
        catch {
            # Se não conseguir nem ler as configs, marca como "Suportado" (genérico) e loga
            $results.Add([pscustomobject]@{ Interface = $nic.Name; Status = "Suportado" })
            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Adapter='$($nic.Name)' ERRO ao consultar PowerManagement: $($_.Exception.Message)" |
                Out-File -FilePath $LogPath -Append -Encoding utf8
            continue
        }

        if ($pm.AllowComputerToTurnOffDevice -eq 'Unsupported') {  # valor conhecido do cmdlet [3](https://stackoverflow.com/questions/46145449/disable-turn-off-this-device-to-save-power-for-nic)[1](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapterpowermanagement?view=windowsserver2025-ps)
            $results.Add([pscustomobject]@{ Interface = $pm.Name; Status = "Não suportado" })
            continue
        }

        try {
            $before = $pm.AllowComputerToTurnOffDevice
            $pm.AllowComputerToTurnOffDevice = 'Disabled'
            $pm | Set-NetAdapterPowerManagement -ErrorAction Stop        # cmdlet oficial [2](https://learn.microsoft.com/en-us/powershell/module/netadapter/set-netadapterpowermanagement?view=windowsserver2025-ps)

            # Confirma
            $pmAfter = Get-NetAdapterPowerManagement -Name $pm.Name -ErrorAction Stop  [1](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapterpowermanagement?view=windowsserver2025-ps)

            if ($pmAfter.AllowComputerToTurnOffDevice -eq 'Disabled') { # Disabled esperado [4](https://learn.microsoft.com/en-us/answers/questions/5762553/how-to-disable-allow-the-computer-to-turn-off-this)[3](https://stackoverflow.com/questions/46145449/disable-turn-off-this-device-to-save-power-for-nic)
                $results.Add([pscustomobject]@{ Interface = $pmAfter.Name; Status = "Desativado" })
            }
            else {
                $results.Add([pscustomobject]@{ Interface = $pmAfter.Name; Status = "Suportado" })
            }

            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Adapter='$($pm.Name)' AllowComputerToTurnOffDevice: $before -> $($pmAfter.AllowComputerToTurnOffDevice)" |
                Out-File -FilePath $LogPath -Append -Encoding utf8
        }
        catch {
            $results.Add([pscustomobject]@{ Interface = $pm.Name; Status = "Suportado" })
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

# --- Listagem final solicitada ---
Write-Host ""
Write-Host "===== STATUS FINAL - Power Management (NIC) ====="
$results | Sort-Object Interface | Format-Table -AutoSize Interface, Status
Write-Host "==============================================="
Write-Host ("Log: {0}" -f $LogPath)
