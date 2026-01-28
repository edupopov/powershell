<#
    -------------------------------------------------------------------------
    Script:       Set-DOT1X-Wired.ps1
    Propósito:    Aplicar perfil 802.1X (Wired) em todas as interfaces Ethernet ativas
    Autor:        Criado por Eduardo Popovici
    Versão:       1.0
    Observações:  - Mantém tudo simples: sem editar XML, sem telas.
                  - Requer execução como Administrador.
                  - Espera o arquivo "C:\DOT1X\profile-nac.xml" já pronto (exportado).
    -------------------------------------------------------------------------
#>

# =============================
# 1) Liberação da execução de scripts
# -----------------------------
# Define a ExecutionPolicy para "RemoteSigned" no escopo LocalMachine,
# permitindo que scripts locais sejam executados (e scripts assinados, se remotos).
# Em ambientes com políticas de segurança mais rígidas, isso pode ser feito via GPO.
# =============================
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
} catch {
    Write-Host "Aviso: não foi possível ajustar ExecutionPolicy. Prosseguindo..." -ForegroundColor Yellow
}

# =============================
# 2) Caminho do arquivo de perfil
# -----------------------------
# Este XML deve ter sido exportado de uma máquina modelo com as configs de 802.1X adequadas.
# Ex.: netsh lan export profile interface="Ethernet" folder="C:\DOT1X"
# =============================
$importPath = "C:\DOT1X\profile-nac.xml"

if (-not (Test-Path $importPath)) {
    Write-Host "Erro: arquivo de perfil não encontrado em $importPath" -ForegroundColor Red
    exit 1
}

# =============================
# 3) Serviço Wired AutoConfig (dot3svc)
# -----------------------------
# Necessário para autenticação 802.1X em interfaces cabeadas.
# Define o startup como Automático e inicia o serviço.
# =============================
try {
    Set-Service -Name dot3svc -StartupType Automatic -ErrorAction Stop
    if ((Get-Service dot3svc).Status -ne 'Running') {
        Start-Service dot3svc -ErrorAction Stop
    }
    # Pequena espera para garantir que o serviço esteja plenamente operacional
    Start-Sleep -Seconds 3
} catch {
    Write-Host "Erro: não foi possível iniciar o serviço dot3svc (Wired AutoConfig)." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# =============================
# 4) Seleção das interfaces Ethernet ativas
# -----------------------------
# Filtra adaptadores com Status 'Up' e exclui quaisquer Wi-Fi/Wireless.
# Se preferir aplicar indistintamente, substitua o filtro por interface='*' no netsh.
# =============================
$wiredAdapters = Get-NetAdapter | Where-Object {
    $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Wi-Fi|Wireless'
}

if (-not $wiredAdapters) {
    Write-Host "Aviso: nenhuma interface Ethernet ativa encontrada." -ForegroundColor Yellow
}

# =============================
# 5) Importar o perfil para cada interface
# -----------------------------
# Importa o XML pronto para cada interface detectada.
# Em alternativa, pode usar interface='*' para aplicar a todas.
# =============================
foreach ($adapter in $wiredAdapters) {
    Write-Host "Importando perfil para a interface: $($adapter.Name)" -ForegroundColor Cyan
    netsh lan add profile filename="$importPath" interface="$($adapter.Name)"
}

# =============================
# 6) Forçar reautenticação
# -----------------------------
# Após importar, reconecta todas as interfaces para acionar a autenticação 802.1X.
# =============================
Write-Host "Forçando reautenticação 802.1X..." -ForegroundColor Cyan
netsh lan reconnect interface=*

Write-Host "Concluído: perfil 802.1X aplicado." -ForegroundColor Green
exit 0
