# Usa somente o ping - nao precisa do nmap

<# =======================
   Ping-Windows.ps1
   Autor: Eduardo Popovici
   Data: 23/02/2026
   ======================= #>

# ===== Configurações =====
$HostsFile             = ".\hosts.csv"                            # lista de hostnames
$LogTxt                = ".\resultado_ping_windows.log"           # log textual
$LogCsv                = ".\resultado_ping_windows.csv"           # log CSV estruturado
$TimeoutMs             = 1500                                     # timeout do ping em ms
$AppendDomainIfMissing = $true                                    # acrescentar ".dominio.com.br" se faltar
$DefaultDomainSuffix   = "dominio.com.br"                      # sufixo a acrescentar
$DnsInterno            = ""                                       # ex.: "10.150.0.200" (opcional)

# ===== Funções =====
function Log([string]$msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg"
    Write-Host $line
    Add-Content -Encoding UTF8 -Path $LogTxt -Value $line
}

function Try-ResolveHost([string]$host) {
    # Tenta DNS do adaptador
    try {
        $r1 = Resolve-DnsName -Name $host -ErrorAction Stop
        return $r1
    } catch {}

    # Tenta DNS interno, se informado
    if ($DnsInterno) {
        try {
            $r2 = Resolve-DnsName -Name $host -Server $DnsInterno -Timeout 5 -ErrorAction Stop
            return $r2
        } catch {}
    }
    return $null
}

# ===== Início =====
"===== Início $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') =====" | Out-File -Encoding UTF8 -FilePath $LogTxt
"Hostname,IP,Status,LatenciaMs,Mensagem,DataHora" | Out-File -Encoding UTF8 -FilePath $LogCsv

if (!(Test-Path $HostsFile)) {
    Log "ERRO: Arquivo $HostsFile não encontrado. Abortando."
    throw
}

# Carrega hosts, remove vazios e duplicados
$hosts = Get-Content -Encoding UTF8 $HostsFile | Where-Object { $_ -and $_.Trim() -ne "" } | Select-Object -Unique
Log "Total de hosts lidos: $($hosts.Count)"

foreach ($h0 in $hosts) {
    $h = $h0.Trim()

    # Acrescenta sufixo se necessário (ex.: linhas do tipo 'REC-MC386103')
    if ($AppendDomainIfMissing -and ($h -notmatch "\.")) {
        $h = "$h.$DefaultDomainSuffix"
    }

    Log "----- Host: $h -----"

    # Resolve IP
    $res = Try-ResolveHost -host $h
    if ($null -eq $res) {
        $msg = "Falha de DNS: não foi possível resolver '$h'."
        Log $msg
        "$h,,NaoResolveuDNS,,`"$msg`",$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogCsv -Encoding UTF8
        continue
    }

    $ips = $res | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique
    if (-not $ips) {
        $msg = "Resolvido sem registro A/AAAA (CNAME sem destino A/AAAA?)."
        Log $msg
        "$h,,SemRegistroA,,`"$msg`",$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogCsv -Encoding UTF8
        continue
    }

    $ip = $ips[0]
    Log ("IP: $ip")

    # Executa ping (1 eco, timeout configurável)
    # Saída do ping em PT-BR/EN varia; vamos analisar status de forma robusta
    $pingOutput = ping -n 1 -w $TimeoutMs $h 2>&1
    $joined = ($pingOutput | Out-String)

    # Determina sucesso/latência
    $ok = ($joined -match 'TTL=' -or $joined -match 'TTL=' -or $joined -match 'bytes=') -and ($joined -notmatch 'Esgotado o tempo' -and $joined -notmatch 'Request timed out')
    $lat = $null

    # Extrai latência (ms) — cobre PT-BR e EN
    if ($joined -match 'tempo[=<]\s*(\d+)\s*ms') { $lat = [int]$Matches[1] }
    elseif ($joined -match 'time[=<]\s*(\d+)\s*ms') { $lat = [int]$Matches[1] }

    if ($ok) {
        Log "PING OK em $h ($ip) latência ${lat}ms"
        "$h,$ip,OK,$lat,`"Ping bem-sucedido`",$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogCsv -Encoding UTF8
    } else {
        # Captura uma linha significativa de erro
        $errLine = ($pingOutput | Where-Object { $_ -match 'Esgotado|excedido|timed out|inacessível|unreachable|could not find host|host não pôde ser encontrado' } | Select-Object -First 1)
        if (-not $errLine) { $errLine = "Ping falhou (veja LOG textual para detalhes)" }
        Log "PING FALHOU em $h ($ip) - $errLine"
        "$h,$ip,Falha,,`"$errLine`",$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogCsv -Encoding UTF8
    }

    Log ""  # linha em branco no LOG
}

Log "===== Fim $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====="
