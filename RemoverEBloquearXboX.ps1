# ============================================================
# BASELINE CORPORATIVO - HARDENING WINDOWS 11
# Foco: Remoção de Xbox + Desativação de funcionalidades
# ============================================================

Write-Host "🚀 Iniciando hardening do Windows 11..." -ForegroundColor Cyan

# ============================================================
# FUNÇÃO PADRÃO (boas práticas enterprise)
# ============================================================
function Set-RegValue {
    param (
        [string]$Path,
        [string]$Name,
        [int]$Value
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
}

# ============================================================
# 1. REMOVER XBOX / GAMING SERVICES
# ============================================================
Write-Host "Removendo componentes Xbox..."

$packages = @(
    "Microsoft.GamingServices",
    "Microsoft.XboxApp",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.Xbox.TCUI"
)

foreach ($pkg in $packages) {

    # Remove instalado
    Get-AppxPackage -Name $pkg -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue

    # Remove provisionado
    Get-AppxProvisionedPackage -Online |
    Where-Object {$_.DisplayName -eq $pkg} |
    Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}

# ============================================================
# 2. DESATIVAR GAME DVR
# ============================================================
Write-Host "Desativando GameDVR..."

Set-RegValue `
    -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" `
    -Name "AllowGameDVR" `
    -Value 0

# ============================================================
# 3. BLOQUEAR CONSUMER FEATURES (evita reinstalação)
# ============================================================
Write-Host "Aplicando políticas de bloqueio consumer..."

Set-RegValue `
    -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" `
    -Name "DisableWindowsConsumerFeatures" `
    -Value 1

# ============================================================
# 4. DESATIVAR WIDGETS
# ============================================================
Write-Host "Desativando Widgets..."

Set-RegValue `
    -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" `
    -Name "AllowNewsAndInterests" `
    -Value 0

# Compatibilidade adicional
Set-RegValue `
    -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" `
    -Name "EnableFeeds" `
    -Value 0

# ============================================================
# 5. LIMPEZA DE EXPERIÊNCIAS (UX)
# ============================================================
Write-Host "Ajustando experiência do usuário..."

# Desabilita sugestões e conteúdo dinâmico
Set-RegValue `
    -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" `
    -Name "DisableSoftLanding" `
    -Value 1

Set-RegValue `
    -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" `
    -Name "DisableTailoredExperiencesWithDiagnosticData" `
    -Value 1

# ============================================================
# 6. REMOVER WIDGETS DO PERFIL DO USUÁRIO
# ============================================================
Write-Host "Aplicando configuração por usuário..."

try {
    Set-ItemProperty `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "TaskbarDa" `
        -Value 0 `
        -ErrorAction SilentlyContinue
} catch {}

# ============================================================
# FINALIZAÇÃO
# ============================================================
Write-Host "✅ Hardening concluído com sucesso!" -ForegroundColor Green

# Reinicia Explorer para aplicar imediatamente
Stop-Process -Name explorer -Force
