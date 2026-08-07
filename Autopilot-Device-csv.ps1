# Executar como Administrador
# Gera o arquivo .csv para ser adicionado ao Windows Autopilot, seja pelo Intune ou pelo admin center

# Garante TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Cria a pasta caso não exista
New-Item -Path "C:\HWID" -ItemType Directory -Force | Out-Null

# Permite execução apenas nesta sessão
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Instala NuGet se necessário
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue))
{
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

# Confia no PowerShell Gallery
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Atualiza PowerShellGet se necessário
if (-not (Get-Module -ListAvailable PowerShellGet))
{
    Install-Module PowerShellGet -Force -AllowClobber
}

# Instala o script mais recente
Install-Script Get-WindowsAutopilotInfo -Force

# Coleta o Hardware Hash
Get-WindowsAutopilotInfo `
    -OutputFile "C:\HWID\AutopilotHWID.csv"

Write-Host "Arquivo gerado em C:\HWID\AutopilotHWID.csv" -ForegroundColor Green
