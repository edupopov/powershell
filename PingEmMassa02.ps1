# Instale o nmap no caminho padrao
# Crie um arquivo .csv com as estacoes que quer pingar - use formato de linha, uma em baixo da outra
# Criado por Eduardo Popovici
# Criado em 23/02/2026

# ===== Configurações =====
$HostsFile  = ".\hosts1.csv"                 # arquivo que eu gerei pra você
$Log        = ".\resultado_nmap.log"
$NmapPath   = "nmap"                         # ou: "C:\Program Files (x86)\Nmap\nmap.exe"
$DnsInterno = "192.168.0.1"                 # deixe em branco "" se não quiser forçar um DNS

# ===== Funções auxiliares =====
function Log([string]$msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg"
    Write-Host $line
    Add-Content -Encoding UTF8 -Path $Log -Value $line
}

function Try-Resolve([string]$host) {
    # 1) tenta com DNS padrão do adaptador
    try {
        $r1 = Resolve-DnsName -Name $host -ErrorAction Stop
        return $r1
    } catch {}

    # 2) se falhou e temos DNS interno, tenta nele
    if ($DnsInterno) {
        try {
            $r2 = Resolve-DnsName -Name $host -Server $DnsInterno -Timeout 4 -ErrorAction Stop
            return $r2
        } catch {}
    }
    return $null
}

# ===== Execução =====
# Início do log
"===== Início $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') =====" | Out-File -Encoding UTF8 -FilePath $Log

# Checagens iniciais
try {
    & $NmapPath --version | Out-Null
    Log "OK: Nmap acessível em '$NmapPath'."
} catch {
    Log "ERRO: Nmap não encontrado em '$NmapPath'. Ajuste a variável \$NmapPath."
    throw
}

if (!(Test-Path $HostsFile)) { Log "ERRO: Não achei $HostsFile"; throw }

$hosts = Get-Content -Encoding UTF8 $HostsFile | Where-Object { $_ -and $_.Trim() -ne "" } | Select-Object -Unique
Log "Total de hosts lidos: $($hosts.Count)"

foreach ($h in $hosts) {
    Log "----- Host: $h -----"

    $res = Try-Resolve -host $h
    if ($null -eq $res) {
        Log "Falha de DNS: não foi possível resolver '$h'. Pulando nmap."
        continue
    }

    # Obter IPs distintos
    $ips = $res | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique
    if (-not $ips) {
        Log "Resolvido sem IP (registros não-A/AAAA). Pulando nmap."
        continue
    }

    Log ("IPs: " + ($ips -join ", "))

    # Rodar nmap -sn (ping scan)
    try {
        $nmapOutput = & $NmapPath -sn $h 2>&1 | Out-String
        # também mostra na tela
        $nmapOutput.Trim().Split([Environment]::NewLine) | ForEach-Object { Log $_ }
    } catch {
        Log "ERRO ao executar nmap em '$h': $($_.Exception.Message)"
    }
}

Log "===== Fim $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====="
