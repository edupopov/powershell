# Script aprimorado para importação de drivers em formato powershell
# Criado por Eduardo Popovici
# Requires -RunAsAdministrator
# Importa drivers de C:\DriversBKP (e subpastas), gera resumo e log

$DriverPath = 'C:\DriversBKP'
$LogDir     = $DriverPath
$LogFile    = Join-Path $LogDir ("import_drivers_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

# Garante pasta de log
if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Função de log
function Write-Log {
    param([string]$Message)
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$timestamp] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

Write-Log "[*] Iniciando importacao de drivers a partir de: $DriverPath"
if (-not (Test-Path -LiteralPath $DriverPath)) {
    Write-Log "[ERRO] Pasta nao encontrada: $DriverPath"
    Write-Host "`nPressione qualquer tecla para sair..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

# Coleta todos os .inf
$infFiles = Get-ChildItem -Path $DriverPath -Recurse -Filter *.inf -ErrorAction SilentlyContinue

if (-not $infFiles -or $infFiles.Count -eq 0) {
    Write-Log "[AVISO] Nenhum arquivo .inf encontrado em $DriverPath"
    Write-Host "`nPressione qualquer tecla para sair..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 0
}

$ok = 0
$err = 0
$total = $infFiles.Count

Write-Log "[*] Total de pacotes .inf encontrados: $total"
Write-Log "[*] Iniciando instalacao com pnputil..."

foreach ($inf in $infFiles) {
    Write-Log ("[>] Instalando: {0}" -f $inf.FullName)

    # Executa pnputil para cada INF individualmente
    $proc = Start-Process -FilePath pnputil.exe `
        -ArgumentList '/add-driver', "`"$($inf.FullName)`"", '/install' `
        -NoNewWindow -PassThru -Wait

    # pnputil retorna 0 para sucesso; diferente de 0 indica erro
    if ($proc.ExitCode -eq 0) {
        $ok++
        Write-Log "    [OK] Sucesso (ExitCode=$($proc.ExitCode))"
    } else {
        $err++
        Write-Log "    [ERRO] Falha (ExitCode=$($proc.ExitCode))"
    }
}

Write-Log "-------------------------------------------"
Write-Log ("[RESUMO] Total: {0} | Sucessos: {1} | Erros: {2}" -f $total, $ok, $err)
Write-Log ("[INFO] Log salvo em: {0}" -f $LogFile)
Write-Log "-------------------------------------------"

# Mensagem final destacada
Write-Host ""
if ($err -gt 0) {
    Write-Host ("[ATENCAO] Foram detectados {0} erro(s). Veja o log: {1}" -f $err, $LogFile) -ForegroundColor Yellow
} else {
    Write-Host "[OK] Nenhum erro detectado." -ForegroundColor Green
}

Write-Host "`nPressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
