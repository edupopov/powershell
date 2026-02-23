# Usa somente o ping - nao precisa do nmap

<# =======================
   Ping-Windows.ps1
   Autor: Eduardo Popovici
   Data: 23/02/2026
   ======================= #>

# ===== Configurações =====
$HostsFile             = ".\hosts.txt"                            # lista de hostnames
$LogTxt                = ".\resultado_ping_windows.log"           # log textual
$LogCsv                = ".\resultado_ping_windows.csv"           # log CSV estruturado
$TimeoutMs             = 1500                                     # timeout do ping em ms
$AppendDomainIfMissing = $true                                    # acrescentar ".dominio.com.br" se faltar
$DefaultDomainSuffix   = "dominio.com.br"                      # sufixo a acrescentar
$DnsInterno            = ""                                       # ex.: "192.168.0.1" (opcional)

# ===== Funções =====
function Log([string]$msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg"
    Write-Host $line
    Add-Content -Encoding UTF8 -Path $LogTxt -Value $line
}

function Try-ResolveTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )
    # 1) tenta com DNS padrão do adaptador
    try {
        $r1 = Resolve-DnsName -Name $Target -ErrorAction Stop
        return $r1
    } catch {}

    # 2) se falhou e temos DNS interno, tenta nele
    if ($DnsInterno) {
        try {
            $r2 = Resolve-DnsName -Name $Target -Server $DnsInterno -Timeout 5 -ErrorAction Stop
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
$targets = Get-Content -Encoding UTF8 $HostsFile |
           Where-Object { $_ -and $_.Trim() -ne "" } |
           Select-Object -Unique
Log "Total de hosts lidos: $($targets.Count)"

foreach ($t0 in $targets) {
    $t = $t0.Trim()

    # Acrescenta sufixo se não houver ponto (ex.: 'REC-MC386103' -> 'REC-MC386103.rederecord.com.br')
    if ($AppendDomainIfMissing -and ($t -notmatch "\.")) {
        $t = "$t.$DefaultDomainSuffix"
    }

    Log "----- Host: $t -----"

    # Resolve IP
    $res = Try-ResolveTarget -Target $t
    if ($null -eq $res) {
        $msg = "Falha de DNS: não foi possível resolver '$t'."
        Log $msg
        "$t,,NaoResolveuDNS,,`"$msg`",$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogCsv -Encoding UTF8
        continue
    }

    $ips = $res | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique
    if (-not $ips) {
        $msg = "Resolvido sem registro A/AAAA (CNAME sem destino A/AAAA?)."
        Log $msg
        "$t,,SemRegistroA,,`"$msg`",$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogCsv -Encoding UTF8
        continue
    }

    $ip = $ips[0]
    Log ("IP: $ip")

    # Executa ping (1 eco, timeout configurável)
    $pingOutput = ping -n 1 -w $TimeoutMs $t 2>&1
    $joined = ($pingOutput | Out-String)

    # Determina sucesso/latência (cobre PT-BR e EN)
    $ok = ($joined -match 'TTL=' -or $joined -match 'bytes=') -and ($joined -notmatch 'Esgotado o tempo' -and $joined -notmatch 'Request timed out')
    $lat = $null
    if ($joined -match 'tempo[=<]\s*(\d+)\s*ms') { $lat = [int]$Matches[1] }
    elseif ($joined -match 'time[=<]\s*(\d+)\s*ms') { $lat = [int]$Matches[1] }

    if ($ok) {
        Log "PING OK em $t ($ip) latência ${lat}ms"
        "$t,$ip,OK,$lat,`"Ping bem-sucedido`",$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogCsv -Encoding UTF8
    } else {
        $errLine = ($pingOutput | Where-Object { $_ -match 'Esgotado|excedido|timed out|inacessível|unreachable|could not find host|host não pôde ser encontrado' } | Select-Object -First 1)
        if (-not $errLine) { $errLine = "Ping falhou (veja LOG textual para detalhes)" }
        Log "PING FALHOU em $t ($ip) - $errLine"
        "$t,$ip,Falha,,`"$errLine`",$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogCsv -Encoding UTF8
    }

    Log ""  # linha em branco no LOG
}

Log "===== Fim $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====="
