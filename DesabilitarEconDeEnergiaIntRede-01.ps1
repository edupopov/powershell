<#
.SYNOPSIS
Força adaptadores de rede a permanecerem ativos (sem economia de energia) e tenta desativar EEE/Green/Selective Suspend quando o driver expõe.

.NOTES
- Execute como Administrador.
- Reinicie o computador após a execução para garantir que todas as alterações sejam aplicadas.
#>

Write-Host ">>> Forçando adaptadores de rede a permanecer ativos (sem economia de energia)..." -ForegroundColor Cyan

# 1) Seleciona apenas adaptadores físicos operacionais (evita 'Disconnected' e 'Not Present')
$adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -ne "Disconnected" -and $_.Status -ne "Not Present" }

if (-not $adapters) {
    Write-Host "Nenhum adaptador físico ativo encontrado. Saindo." -ForegroundColor Yellow
    return
}

# Acúmulo de resultados para resumo
$result = @()

foreach ($adapter in $adapters) {
    Write-Host ""  # linha em branco
    Write-Host ("Processando: {0}  |  {1}" -f $adapter.Name, $adapter.InterfaceDescription) -ForegroundColor White

    $row = [ordered]@{
        Adapter        = $adapter.Name
        Description    = $adapter.InterfaceDescription
        PM_Registry    = "N/A"
        IdleDisabled   = $false
        SleepDiscOff   = $false
        AllowWakeOn    = $false
        EEE_Off        = $false
        Green_Off      = $false
        SelSuspendOff  = $false
        Notes          = ""
    }

    # 2) Obter PNPDeviceID via CIM/WMI
    $wmi = Get-CimInstance -ClassName Win32_NetworkAdapter -Filter ("NetConnectionID='{0}'" -f $adapter.Name) -ErrorAction SilentlyContinue
    if (-not $wmi) {
        $row.Notes = "Sem CIM/WMI para esse adaptador."
        $result += [pscustomobject]$row
        Write-Host "  ! Não foi possível obter Win32_NetworkAdapter (CIM/WMI)" -ForegroundColor Yellow
        continue
    }

    # 3) Ajustes de Power Management no Registro
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\{0}\Device Parameters\PowerManagement" -f $wmi.PNPDeviceID
    if (Test-Path $regPath) {
        $row.PM_Registry = $regPath
        $items = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue

        # DeviceIdleEnabled = 0 (impede desligamento por economia)
        if ($items.PSObject.Properties.Name -contains 'DeviceIdleEnabled') {
            if ($items.DeviceIdleEnabled -ne 0) {
                try {
                    Set-ItemProperty -Path $regPath -Name "DeviceIdleEnabled" -Value 0 -Type DWord
                    $row.IdleDisabled = $true
                    Write-Host "  ✔ DeviceIdleEnabled -> 0 (desativado)" -ForegroundColor Green
                } catch {
                    Write-Host ("  ✖ Falha ao ajustar DeviceIdleEnabled: {0}" -f $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                $row.IdleDisabled = $true
                Write-Host "  • DeviceIdleEnabled já estava 0" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  • DeviceIdleEnabled não existe para este driver (ok)" -ForegroundColor DarkGray
        }

        # DeviceSleepOnDisconnect = 0 (não “dormir” ao desconectar)
        if ($items.PSObject.Properties.Name -contains 'DeviceSleepOnDisconnect') {
            if ($items.DeviceSleepOnDisconnect -ne 0) {
                try {
                    Set-ItemProperty -Path $regPath -Name "DeviceSleepOnDisconnect" -Value 0 -Type DWord
                    $row.SleepDiscOff = $true
                    Write-Host "  ✔ DeviceSleepOnDisconnect -> 0" -ForegroundColor Green
                } catch {
                    Write-Host ("  ✖ Falha ao ajustar DeviceSleepOnDisconnect: {0}" -f $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                $row.SleepDiscOff = $true
                Write-Host "  • DeviceSleepOnDisconnect já estava 0" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  • DeviceSleepOnDisconnect não existe para este driver (ok)" -ForegroundColor DarkGray
        }

        # AllowWake = 1 (opcional — habilita WOL se existir)
        if ($items.PSObject.Properties.Name -contains 'AllowWake') {
            if ($items.AllowWake -ne 1) {
                try {
                    Set-ItemProperty -Path $regPath -Name "AllowWake" -Value 1 -Type DWord
                    $row.AllowWakeOn = $true
                    Write-Host "  ✔ AllowWake -> 1 (Wake-on-LAN habilitado)" -ForegroundColor Green
                } catch {
                    Write-Host ("  ✖ Falha ao ajustar AllowWake: {0}" -f $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                $row.AllowWakeOn = $true
                Write-Host "  • AllowWake já estava 1" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  • AllowWake não existe para este driver (ok)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  • Chave de PowerManagement não encontrada (driver não expõe via registro)" -ForegroundColor DarkGray
        $row.PM_Registry = "Chave ausente"
    }

    # 4) Propriedades avançadas (quando o driver expõe)
    $advProps = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue
    if ($advProps) {
        # Energy Efficient Ethernet (EEE)
        $eee = $advProps | Where-Object { $_.DisplayName -match 'Energy.*Efficient|EEE' -or $_.RegistryKeyword -match 'EEE' }
        if ($eee) {
            foreach ($p in $eee) {
                try {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $p.RegistryKeyword -DisplayValue "Disabled" -NoRestart -ErrorAction Stop
                    $row.EEE_Off = $true
                    Write-Host ("  ✔ EEE desativado ({0})" -f $p.DisplayName) -ForegroundColor Green
                } catch {
                    Write-Host ("  • Não foi possível desativar EEE via '{0}': {1}" -f $p.RegistryKeyword, $_.Exception.Message) -ForegroundColor Yellow
                }
            }
        }

        # Green Ethernet
        $green = $advProps | Where-Object { $_.DisplayName -match 'Green.*Ethernet' -or $_.RegistryKeyword -match 'Green' }
        if ($green) {
            foreach ($p in $green) {
                try {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $p.RegistryKeyword -DisplayValue "Disabled" -NoRestart -ErrorAction Stop
                    $row.Green_Off = $true
                    Write-Host ("  ✔ Green Ethernet desativado ({0})" -f $p.DisplayName) -ForegroundColor Green
                } catch {
                    Write-Host ("  • Não foi possível desativar Green Ethernet '{0}': {1}" -f $p.RegistryKeyword, $_.Exception.Message) -ForegroundColor Yellow
                }
            }
        }

        # Selective Suspend (comum em Wi-Fi/USB Ethernet)
        $sel = $advProps | Where-Object { $_.RegistryKeyword -match 'SelectiveSuspend' -or $_.DisplayName -match 'Selective.*Suspend' }
        if ($sel) {
            foreach ($p in $sel) {
                try {
                    # Tenta por DisplayValue e, se falhar, define valor 0
                    $ok = $false
                    try {
                        Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $p.RegistryKeyword -DisplayValue "Disabled" -NoRestart -ErrorAction Stop
                        $ok = $true
                    } catch {
                        # segue para tentar valor 0
                    }
                    if (-not $ok) {
                        Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $p.RegistryKeyword -RegistryValue 0 -NoRestart -ErrorAction Stop
                    }
                    $row.SelSuspendOff = $true
                    Write-Host ("  ✔ Selective Suspend desativado/0 ({0})" -f $p.DisplayName) -ForegroundColor Green
                } catch {
                    Write-Host ("  • Não foi possível ajustar Selective Suspend '{0}': {1}" -f $p.RegistryKeyword, $_.Exception.Message) -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host "  • Driver não expõe propriedades avançadas (ok)" -ForegroundColor DarkGray
    }

    $result += [pscustomobject]$row
}

# 5) Resumo
Write-Host ""
Write-Host "Resumo:" -ForegroundColor Cyan
$result | Format-Table -AutoSize

Write-Host ""
Write-Host "Concluído. Recomenda-se reiniciar o computador para aplicar todas as alterações." -ForegroundColor Green
