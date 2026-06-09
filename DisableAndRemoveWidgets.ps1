# ===========================================
# Desativa Widgets no Windows 11
# Autor: Eduardo-Popovici
# Pode ser usado no SCCM, Intune ou manual
# ===========================================

# Definindo caminho da chave
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"

# Cria a chave se não existir
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Desativa Widgets
New-ItemProperty -Path $regPath `
    -Name "AllowNewsAndInterests" `
    -PropertyType DWord `
    -Value 0 `
    -Force | Out-Null

# Opcional: reforço para Windows Feeds (compatibilidade)
$regPathFeeds = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"

if (-not (Test-Path $regPathFeeds)) {
    New-Item -Path $regPathFeeds -Force | Out-Null
}

New-ItemProperty -Path $regPathFeeds `
    -Name "EnableFeeds" `
    -PropertyType DWord `
    -Value 0 `
    -Force | Out-Null

# Reinicia Explorer para aplicar imediatamente (sem reboot)
Stop-Process -Name explorer -Force

Write-Host "Widgets desativados com sucesso."
