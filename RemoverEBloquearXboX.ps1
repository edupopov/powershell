# ===========================================
# Remoção de Xbox e Gaming Services
# Escopo: Máquina + Usuários
# ===========================================

Write-Host "Iniciando remoção de componentes Xbox..." -ForegroundColor Cyan

# Lista de pacotes Xbox / Gaming
$packages = @(
    "Microsoft.GamingServices",
    "Microsoft.XboxApp",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.Xbox.TCUI"
)

# ===========================================
# 1. Remove apps instalados (todos usuários)
# ===========================================
foreach ($pkg in $packages) {

    Write-Host "Removendo pacote instalado: $pkg"

    Get-AppxPackage -Name $pkg -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
}

# ===========================================
# 2. Remove provisionados (imagem base)
# ===========================================
foreach ($pkg in $packages) {

    Write-Host "Removendo provisionado: $pkg"

    Get-AppxProvisionedPackage -Online |
    Where-Object {$_.DisplayName -eq $pkg} |
    Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}

# ===========================================
# 3. Bloqueio via Registry (Consumer Experience)
# ===========================================
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"

if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

New-ItemProperty -Path $regPath `
    -Name "DisableWindowsConsumerFeatures" `
    -PropertyType DWord `
    -Value 1 `
    -Force | Out-Null

Write-Host "Xbox e Gaming Services removidos com sucesso."

# Caminho da chave
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"

# Cria a chave se não existir
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Cria o valor para desativar Game DVR
New-ItemProperty `
    -Path $regPath `
    -Name "AllowGameDVR" `
    -PropertyType DWord `
    -Value 0 `
    -Force | Out-Null

Write-Host "Game DVR desativado com sucesso"
