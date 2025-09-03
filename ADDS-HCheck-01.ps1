<# 
AD Health Check – PS 5.1/7
- Ping via ping.exe
- Port checks: Kerberos (88 TCP/UDP), LDAP (389 TCP/UDP), LDAPS (636 TCP), GC (3268/3269 TCP), NTLM (135/139/445 TCP), DNS (53 TCP/UDP)
- DNS functional checks: A (self), SRV _ldap._tcp.dc._msdcs.<ForestRoot>, PTR (reverse)
- Relatório salvo no Desktop por padrão (ou -OutputPath)
- Analista/Cliente no rodapé e nas exportações
- dcdiag com timeout real (sem jobs)
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$AnalystName,

  [Parameter(Mandatory=$true)]
  [string]$ClientName,

  [string]$SmtpHost,
  [string]$EmailTo,
  [int]$TimeoutSeconds = 180,

  # Caminho do relatório (se não informar, vai para o Desktop)
  [string]$OutputPath,

  [string]$ExportCsv,
  [string]$ExportJson
)

# -------- Caminho padrão: Desktop do usuário --------
try {
  $desktop = [Environment]::GetFolderPath('Desktop')
  if (-not $desktop -or [string]::IsNullOrWhiteSpace($desktop)) {
    $desktop = Join-Path $env:USERPROFILE 'Desktop'
  }
} catch {
  $desktop = Join-Path $env:USERPROFILE 'Desktop'
}
if (-not $OutputPath -or [string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $desktop 'ADReport.html'
}
# ----------------------------------------------------

# ===========================
# Funções utilitárias
# ===========================
function Test-PingHost {
  param([Parameter(Mandatory)][string]$ComputerName,[int]$TimeoutSeconds=3)
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "$env:SystemRoot\System32\PING.EXE"
    $psi.Arguments = "-n 1 -w $([int]($TimeoutSeconds*1000)) $ComputerName"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $null = $p.WaitForExit(($TimeoutSeconds+1)*1000)
    if ($p.HasExited -and $p.ExitCode -eq 0) { return $true }
  } catch {}
  return $false
}

function Test-TcpPort {
  param([Parameter(Mandatory)][string]$ComputerName,[Parameter(Mandatory)][int]$Port,[int]$TimeoutSeconds=3)
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $iar = $client.BeginConnect($ComputerName,$Port,$null,$null)
    if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutSeconds*1000)) { $client.Close(); return 'Closed' }
    $client.EndConnect($iar) | Out-Null
    $client.Close()
    return 'Open'
  } catch { return 'Closed' }
}

function Test-UdpPort {
  param([Parameter(Mandatory)][string]$ComputerName,[Parameter(Mandatory)][int]$Port,[int]$TimeoutSeconds=3)
  try {
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.Client.ReceiveTimeout = $TimeoutSeconds*1000
    $udp.Connect($ComputerName,$Port)
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("hi")
    [void]$udp.Send($bytes,$bytes.Length)
    Start-Sleep -Milliseconds 300
    if ($udp.Available -gt 0) { 
      $null = $udp.Receive([ref]([System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any,0)))
      $udp.Close()
      return 'Open'
    } else {
      $udp.Close()
      return 'NoReply'   # pode estar aberto sem responder ou filtrado
    }
  } catch {
    try { $udp.Close() } catch {}
    return 'NoReply'
  }
}

function Get-ServiceStatusSafe {
  param([Parameter(Mandatory)][string]$ComputerName,[Parameter(Mandatory)][string]$ServiceName)
  try {
    $svc = Get-Service -ComputerName $ComputerName -Name $ServiceName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $svc) { return 'Unknown' }
    if ($svc.Status -eq 'Running') { 'Running' } else { [string]$svc.Status }
  } catch { 'Unknown' }
}

function Test-UncShare {
  param([Parameter(Mandatory)][string]$ComputerName,[Parameter(Mandatory)][ValidateSet('NETLOGON','SYSVOL')] [string]$ShareName)
  try {
    if (Test-Path -LiteralPath ("filesystem::\\{0}\{1}" -f $ComputerName,$ShareName) -ErrorAction SilentlyContinue) { 'Passed' }
    else { 'Failed' }
  } catch { 'Failed' }
}

function Invoke-DcDiagTest {
  param([Parameter(Mandatory)][string]$ComputerName,[Parameter(Mandatory)][ValidateSet('Netlogons','Replications','Services','Advertising','FSMOCheck')] [string]$TestName,[int]$Timeout=180)
  try { $exe = (Get-Command -Name 'dcdiag.exe' -ErrorAction Stop).Source } catch { return 'Failed' }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $exe
  $psi.Arguments = "/test:$TestName /s:$ComputerName"
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  try {
    $null = $proc.Start()
    $finished = $proc.WaitForExit($Timeout*1000)
    if (-not $finished) { try { $proc.Kill() | Out-Null } catch {}; return 'Timeout' }
    $output = $proc.StandardOutput.ReadToEnd() + $proc.StandardError.ReadToEnd()
  } catch { return 'Failed' }
  finally { try { $proc.Close() } catch {} }
  $lower = $output.ToLowerInvariant()
  if ($lower -match 'no longer available|cannot be contacted|rpc server is unavailable') { return 'ConnError' }
  if ($lower -match "passed\s+test\s+$($TestName.ToLowerInvariant())") { return 'Passed' }
  return 'Failed'
}

function Get-StatusColor {
  param([Parameter(Mandatory)][string]$Status)
  switch ($Status) {
    'Success'   { 'ok' }
    'Running'   { 'ok' }
    'Passed'    { 'ok' }
    'Open'      { 'ok' }
    'Failed'    { 'fail' }
    'Closed'    { 'fail' }
    'PingFail'  { 'fail' }
    'Unknown'   { 'warn' }
    'Timeout'   { 'warn' }
    'ConnError' { 'warn' }
    'NoReply'   { 'warn' }
    default {
      if ($Status -match 'stopp|stop') { 'fail' }
      elseif ($Status -match 'run')    { 'ok' }
      else                             { 'warn' }
    }
  }
}

# ===========================
# Ambiente / Enumeração de DCs
# ===========================
$StartDate = Get-Date
Write-Host "Iniciando AD Health Check em $StartDate" -ForegroundColor Cyan

try {
  $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
  $DCServers = $forest.Domains | ForEach-Object { $_.DomainControllers } | ForEach-Object { $_.Name }
  $ForestRoot = $forest.RootDomain.Name
} catch {
  throw "Falha ao enumerar DCs: $($_.Exception.Message)"
}
$DCServers = $DCServers | Sort-Object -Unique
if (-not $DCServers) { throw "Nenhum DC encontrado." }
Write-Host "DCs encontrados: $($DCServers -join ', ')" -ForegroundColor DarkCyan

# ===========================
# Tabela de portas por protocolo
# ===========================
$TcpPortsToCheck = [ordered]@{
  KerberosTCP = 88
  LDAPTCP     = 389
  LDAPS       = 636
  GCLDAP      = 3268
  GCLDAPS     = 3269
  NTLM_RPC135 = 135
  NTLM_139    = 139
  NTLM_445    = 445
  DNS_TCP     = 53
}
$UdpPortsToCheck = [ordered]@{
  KerberosUDP = 88
  LDAPUDP     = 389
  DNS_UDP     = 53
}

# ===========================
# Testes por DC
# ===========================
$ResultsArr = foreach ($dcFqdn in $DCServers) {
  $short = ($dcFqdn -split '\.')[0]

  # Conectividade (ping)
  $pingOkFqdn  = Test-PingHost -ComputerName $dcFqdn -TimeoutSeconds 3
  $pingOkShort = $false
  if (-not $pingOkFqdn) { $pingOkShort = Test-PingHost -ComputerName $short -TimeoutSeconds 3 }
  $pingOk = $pingOkFqdn -or $pingOkShort
  $pingStatus = if ($pingOk) { 'Success' } else { 'PingFail' }
  $target = if ($pingOkShort) { $short } else { $dcFqdn }

  # Serviços
  $netlogon = Get-ServiceStatusSafe -ComputerName $target -ServiceName 'Netlogon'
  $ntds     = Get-ServiceStatusSafe -ComputerName $target -ServiceName 'NTDS'
  $dnsSvc   = Get-ServiceStatusSafe -ComputerName $target -ServiceName 'DNS'

  # dcdiag
  $tNetlogons   = Invoke-DcDiagTest -ComputerName $target -TestName 'Netlogons'    -Timeout $TimeoutSeconds
  $tRepl        = Invoke-DcDiagTest -ComputerName $target -TestName 'Replications' -Timeout $TimeoutSeconds
  $tServices    = Invoke-DcDiagTest -ComputerName $target -TestName 'Services'     -Timeout $TimeoutSeconds
  $tAdvertising = Invoke-DcDiagTest -ComputerName $target -TestName 'Advertising'  -Timeout $TimeoutSeconds
  $tFSMO        = Invoke-DcDiagTest -ComputerName $target -TestName 'FSMOCheck'    -Timeout $TimeoutSeconds

  # Shares
  $tNetlogonShare = Test-UncShare -ComputerName $target -ShareName 'NETLOGON'
  $tSysvolShare   = Test-UncShare -ComputerName $target -ShareName 'SYSVOL'

  # Portas TCP
  $tcpStatus = @{}
  foreach ($k in $TcpPortsToCheck.Keys) {
    $tcpStatus[$k] = Test-TcpPort -ComputerName $target -Port $TcpPortsToCheck[$k] -TimeoutSeconds 3
  }

  # Portas UDP
  $udpStatus = @{}
  foreach ($k in $UdpPortsToCheck.Keys) {
    $udpStatus[$k] = Test-UdpPort -ComputerName $target -Port $UdpPortsToCheck[$k] -TimeoutSeconds 3
  }

  # DNS – testes funcionais via Resolve-DnsName usando o próprio DC como servidor
  $dnsA   = 'Unknown'
  $dnsSRV = 'Unknown'
  $dnsPTR = 'Unknown'
  try {
    $aRec = Resolve-DnsName -Name $target -Type A -Server $target -ErrorAction Stop
    if ($aRec -and ($aRec | Where-Object {$_.IPAddress})) { $dnsA = 'Passed' } else { $dnsA = 'Failed' }
  } catch { $dnsA = 'Failed' }

  try {
    $srvRec = Resolve-DnsName -Name ("_ldap._tcp.dc._msdcs.{0}" -f $ForestRoot) -Type SRV -Server $target -ErrorAction Stop
    if ($srvRec) { $dnsSRV = 'Passed' } else { $dnsSRV = 'Failed' }
  } catch { $dnsSRV = 'Failed' }

  try {
    if ($dnsA -eq 'Passed') {
      $ip = (Resolve-DnsName -Name $target -Type A -Server $target -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty IPAddress)
      if ($ip) {
        $ptr = Resolve-DnsName -Name $ip -Type PTR -Server $target -ErrorAction Stop
        $dnsPTR = if ($ptr) { 'Passed' } else { 'Failed' }
      } else { $dnsPTR = 'Failed' }
    } else {
      $dnsPTR = 'Unknown'
    }
  } catch { $dnsPTR = 'Failed' }

  [pscustomobject]@{
    Identity          = $dcFqdn
    PingStatus        = $pingStatus
    NetlogonService   = $netlogon
    NTDSService       = $ntds
    DNSServiceStatus  = $dnsSvc
    NetlogonsTest     = $tNetlogons
    ReplicationTest   = $tRepl
    ServicesTest      = $tServices
    AdvertisingTest   = $tAdvertising
    NETLOGONTest      = $tNetlogonShare
    SYSVOLTest        = $tSysvolShare
    FSMOCheckTest     = $tFSMO

    # Portas TCP
    KerberosTCP       = $tcpStatus.KerberosTCP
    LDAPTCP           = $tcpStatus.LDAPTCP
    LDAPS             = $tcpStatus.LDAPS
    GCLDAP            = $tcpStatus.GCLDAP
    GCLDAPS           = $tcpStatus.GCLDAPS
    NTLM_RPC135       = $tcpStatus.NTLM_RPC135
    NTLM_139          = $tcpStatus.NTLM_139
    NTLM_445          = $tcpStatus.NTLM_445
    DNS_TCP           = $tcpStatus.DNS_TCP

    # Portas UDP
    KerberosUDP       = $udpStatus.KerberosUDP
    LDAPUDP           = $udpStatus.LDAPUDP
    DNS_UDP           = $udpStatus.DNS_UDP

    # DNS funcional
    DNS_A_Self        = $dnsA
    DNS_SRV_Forest    = $dnsSRV
    DNS_PTR_Self      = $dnsPTR

    AnalystName       = $AnalystName
    ClientName        = $ClientName
  }
}

$ResultsArr = $ResultsArr | Sort-Object Identity

# ===========================
# Exportações (CSV/JSON)
# ===========================
if ($ExportCsv) {
  try {
    $ResultsArr | Export-Csv -NoTypeInformation -Path $ExportCsv -Encoding UTF8
    Write-Host "Export CSV: $((Resolve-Path -LiteralPath $ExportCsv).Path)" -ForegroundColor Green
  } catch { Write-Warning "CSV: $($_.Exception.Message)" }
}
if ($ExportJson) {
  try {
    $ResultsArr | ConvertTo-Json -Depth 4 | Out-File -FilePath $ExportJson -Encoding UTF8
    Write-Host "Export JSON: $((Resolve-Path -LiteralPath $ExportJson).Path)" -ForegroundColor Green
  } catch { Write-Warning "JSON: $($_.Exception.Message)" }
}

# ===========================
# HTML (template + cores)
# ===========================
$EndDate = Get-Date
$css = @"
<style>
  body { font-family: Segoe UI, Tahoma, Arial; margin: 12px; }
  h1 { color: #3A4FA0; margin-bottom: 6px; }
  .legend { font-size: 12px; margin: 4px 0 8px 0; }
  .legend span { display:inline-block; padding:2px 6px; border:1px solid #999; margin-right:6px; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #999; padding: 6px 8px; font-size: 12px; text-align: center; }
  th { background: #B04B4B; color: #fff; }
  tr:nth-child(even) { background: #f7f7f7; }
  .ok    { background: #7FFFD4; }
  .fail  { background: #FF6B6B; }
  .warn  { background: #FFD166; }
  .idcell{ background: #DCDCDC; text-align: left; font-weight: bold; }
  .meta  { font-size: 11px; color: #3A4FA0; }
  .note  { font-size: 12px; color: #333; margin: 6px 0 12px 0; }
</style>
"@

$htmlHeader = @"
<html>
<head><meta charset="utf-8" /><title>Active Directory Health Check</title>$css</head>
<body>
<h1>Active Directory Health Check</h1>

<div class='legend'>
  <span class='ok'>OK</span>
  <span class='warn'>Aviso</span>
  <span class='fail'>Falha</span>
</div>

<div class='note'>
  <b>Nota sobre UDP / NoReply:</b> Em UDP não existe handshake como no TCP. O teste envia um datagrama simples; 
  se o servidor não responde (comum para Kerberos/LDAP/DNS em UDP), marcamos <i>NoReply</i>. 
  Isso não significa necessariamente porta fechada — pode estar <i>aberta porém silenciosa</i> ou filtrada por firewall. 
  Somente quando há retorno de erro ICMP ou negação explícita registramos <i>Closed</i>. 
  Para conectividade crítica do AD, priorize resultados das portas TCP.
</div>

<table>
  <tr>
    <th>Identity</th>
    <th>PingStatus</th>
    <th>NetlogonService</th>
    <th>NTDSService</th>
    <th>DNSServiceStatus</th>
    <th>NetlogonsTest</th>
    <th>ReplicationTest</th>
    <th>ServicesTest</th>
    <th>AdvertisingTest</th>
    <th>NETLOGONTest</th>
    <th>SYSVOLTest</th>
    <th>FSMOCheckTest</th>

    <th>KerberosTCP:88</th>
    <th>KerberosUDP:88</th>
    <th>LDAPTCP:389</th>
    <th>LDAPUDP:389</th>
    <th>LDAPS:636</th>
    <th>GC:3268</th>
    <th>GC SSL:3269</th>

    <th>DNS TCP:53</th>
    <th>DNS UDP:53</th>
    <th>DNS A(Self)</th>
    <th>DNS SRV(Forest)</th>
    <th>DNS PTR(Self)</th>

    <th>NTLM RPC:135</th>
    <th>NTLM 139</th>
    <th>NTLM 445</th>
  </tr>
"@

$rows = foreach ($r in $ResultsArr) {
  $cells = @("<td class='idcell'>$($r.Identity)</td>")
  foreach ($p in @(
      'PingStatus',
      'NetlogonService',
      'NTDSService',
      'DNSServiceStatus',
      'NetlogonsTest',
      'ReplicationTest',
      'ServicesTest',
      'AdvertisingTest',
      'NETLOGONTest',
      'SYSVOLTest',
      'FSMOCheckTest',
      'KerberosTCP',
      'KerberosUDP',
      'LDAPTCP',
      'LDAPUDP',
      'LDAPS',
      'GCLDAP',
      'GCLDAPS',
      'DNS_TCP',
      'DNS_UDP',
      'DNS_A_Self',
      'DNS_SRV_Forest',
      'DNS_PTR_Self',
      'NTLM_RPC135',
      'NTLM_139',
      'NTLM_445'
    )) {
      $val = [string]$r.$p
      $cls = Get-StatusColor -Status $val
      $cells += "<td class='$cls'><b>$val</b></td>"
  }
  "<tr>{0}</tr>" -f ($cells -join '')
}

$htmlFooter = @"
</table>
<br/>
<div class='meta'>
  Cliente: $ClientName &nbsp; | &nbsp; Analista: $AnalystName <br/>
  Start Date: $StartDate &nbsp; | &nbsp; End Date: $EndDate &nbsp; | &nbsp;
  Timeout: ${TimeoutSeconds}s &nbsp; | &nbsp; DCs: $($DCServers.Count) &nbsp; | &nbsp; Floresta: $ForestRoot
</div>
</body>
</html>
"@

# Salvar HTML
try {
  $dir = Split-Path -Path $OutputPath -Parent
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  ($htmlHeader + ($rows -join "`n") + $htmlFooter) | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
  $resolvedHtml = Resolve-Path -LiteralPath $OutputPath -ErrorAction Stop
  Write-Host ("Relatório HTML salvo em: {0}" -f $resolvedHtml.Path) -ForegroundColor Green
} catch {
  Write-Warning "Falha ao salvar HTML: $($_.Exception.Message)"
}

# E-mail opcional
if ($SmtpHost -and $EmailTo) {
  try {
    $to = $EmailTo -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($to.Count -gt 0) {
      $body = Get-Content -LiteralPath $OutputPath -Raw -Encoding UTF8
      $from = 'ADHealthCheck@domain.com'
      $subject = "AD Health Monitor - $ClientName - $($StartDate.ToString('yyyy-MM-dd HH:mm'))"
      if (Get-Command Send-MailMessage -ErrorAction SilentlyContinue) {
        Send-MailMessage -SmtpServer $SmtpHost -From $from -To $to -Subject $subject -Body $body -BodyAsHtml -ErrorAction Stop
        Write-Host "E-mail enviado para: $($to -join ', ')" -ForegroundColor Green
      } else {
        Write-Warning "Send-MailMessage não disponível neste host. Pular envio."
      }
    }
  } catch {
    Write-Warning "Falha ao enviar e-mail: $($_.Exception.Message)"
  }
} else {
  Write-Host "Envio de e-mail não configurado (SmtpHost ou EmailTo ausentes)." -ForegroundColor Yellow
}

Write-Host "Concluído em $(Get-Date)." -ForegroundColor Cyan
