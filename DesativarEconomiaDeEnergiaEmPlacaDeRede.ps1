#Requires -RunAsAdministrator

$LogFile = "$env:ProgramData\NICPowerOptimization.log"

function Write-Log {
    param([string]$Message)

    $Line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message

    Write-Host $Line
    Add-Content -Path $LogFile -Value $Line -ErrorAction SilentlyContinue
}

Write-Log "=============================================="
Write-Log "INICIO DA OTIMIZACAO DE REDE"
Write-Log "=============================================="

$DisableValues = @(
    "Disabled",
    "Desativado",
    "Desactivado",
    "Off",
    "Ausente"
)

$PropertiesToDisable = @(
    "Ethernet Verde",
    "Green Ethernet",
    "Energia Eficiente Ethernet",
    "Energy Efficient Ethernet",
    "EEE",
    "Gigabit Lite",
    "Auto Disable Gigabit",
    "Desligar Despertar Aquando de Lan",
    "Wake on Shutdown",
    "System Idle Power Saver",
    "Reduce Speed On Power Down",
    "Ultra Low Power Mode"
)

$Adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue

foreach ($Adapter in $Adapters)
{
    Write-Log ""
    Write-Log "Adaptador: $($Adapter.Name)"
    Write-Log "Descrição: $($Adapter.InterfaceDescription)"

    #
    # Desabilita:
    # "Permitir que o computador desligue o dispositivo para economizar energia"
    #
    try
    {
        $PM = $Adapter | Get-NetAdapterPowerManagement

        if ($PM.AllowComputerToTurnOffDevice -ne "Unsupported")
        {
            $PM.AllowComputerToTurnOffDevice = "Disabled"
            $PM | Set-NetAdapterPowerManagement

            Write-Log "AllowComputerToTurnOffDevice => Disabled"
        }
    }
    catch
    {
        Write-Log "Falha PowerManagement: $($_.Exception.Message)"
    }

    #
    # Lê propriedades avançadas
    #
    try
    {
        $Properties = Get-NetAdapterAdvancedProperty -Name $Adapter.Name -ErrorAction Continue

        foreach ($Property in $Properties)
        {
            if ($PropertiesToDisable -contains $Property.DisplayName)
            {
                Write-Log "Propriedade encontrada: $($Property.DisplayName)"

                $Configured = $false

                foreach ($Value in $DisableValues)
                {
                    try
                    {
                        Set-NetAdapterAdvancedProperty `
                            -Name $Adapter.Name `
                            -DisplayName $Property.DisplayName `
                            -DisplayValue $Value `
                            -NoRestart `
                            -ErrorAction Stop

                        Write-Log "$($Property.DisplayName) => $Value"

                        $Configured = $true
                        break
                    }
                    catch
                    {
                    }
                }

                if (-not $Configured)
                {
                    Write-Log "Não foi possível alterar: $($Property.DisplayName)"
                }
            }
        }
    }
    catch
    {
        Write-Log "Falha propriedades avançadas: $($_.Exception.Message)"
    }
}

Write-Log ""
Write-Log "=============================================="
Write-Log "FIM DA EXECUCAO"
Write-Log "=============================================="

exit 0
``
