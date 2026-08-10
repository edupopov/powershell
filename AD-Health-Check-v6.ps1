<# 
AD Health Check – PS 5.1/7 – Layout v4
- Criado por Eduardo Popovici e disponível em seu repositório GitHub
- Script criado e disponibilizado para a comunidade Microsoft
- Ping via ping.exe
- Port checks: Kerberos (88 TCP/UDP), LDAP (389 TCP/UDP), LDAPS (636 TCP), GC (3268/3269 TCP), NTLM (135/139/445 TCP), DNS (53 TCP/UDP)
- DNS functional checks: A (self), SRV _ldap._tcp.dc._msdcs.<ForestRoot>, PTR (reverse)
- Relatório salvo no Desktop por padrão (ou -OutputPath)
- Analista/Cliente no rodapé e nas exportações
- dcdiag com timeout real (sem jobs)
- Relatório HTML com resumo, inventário do Windows Server e seção de falhas identificadas
- Inventário por DC: edição, versão e build do Windows Server
- Manutenção por DC: último HotFix/KB detectado e última inicialização (reboot)
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

# Armazena mensagens relevantes retornadas pelo DCDiag para exibição no relatório HTML.
$script:DcDiagDetails = @{}

function Invoke-DcDiagTest {
  param(
    [Parameter(Mandatory)][string]$ComputerName,
    [Parameter(Mandatory)][ValidateSet('Netlogons','Replications','Services','Advertising','FSMOCheck')] [string]$TestName,
    [int]$Timeout=180
  )

  $detailKey = "$ComputerName|$TestName"
  $script:DcDiagDetails[$detailKey] = @()

  try {
    $exe = (Get-Command -Name 'dcdiag.exe' -ErrorAction Stop).Source
  } catch {
    $script:DcDiagDetails[$detailKey] = @('dcdiag.exe não foi encontrado neste equipamento.')
    return 'Failed'
  }

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

    if (-not $finished) {
      try { $proc.Kill() | Out-Null } catch {}
      $script:DcDiagDetails[$detailKey] = @("DCDiag excedeu o timeout configurado de ${Timeout}s.")
      return 'Timeout'
    }

    $output = $proc.StandardOutput.ReadToEnd() + $proc.StandardError.ReadToEnd()
  } catch {
    $script:DcDiagDetails[$detailKey] = @("Falha ao executar DCDiag: $($_.Exception.Message)")
    return 'Failed'
  }
  finally {
    try { $proc.Close() } catch {}
  }

  $lower = $output.ToLowerInvariant()

  # Separa apenas linhas potencialmente úteis para diagnóstico. O relatório não recebe
  # a saída inteira do DCDiag, evitando páginas excessivamente grandes.
  $detailLines = @(
    $output -split '\r?\n' |
      ForEach-Object { $_.Trim() } |
      Where-Object {
        $_ -and $_ -match '(?i)(failed\s+test|error|warning|fail|unable|cannot|unavailable|denied|not\s+found|replication.*error|last\s+error|rpc\s+server|access\s+is\s+denied)'
      } |
      Select-Object -Unique |
      Select-Object -First 12
  )

  if ($detailLines.Count -gt 0) {
    $script:DcDiagDetails[$detailKey] = $detailLines
  }

  if ($lower -match 'no longer available|cannot be contacted|rpc server is unavailable') {
    if ($script:DcDiagDetails[$detailKey].Count -eq 0) {
      $script:DcDiagDetails[$detailKey] = @('Falha de conectividade detectada pelo DCDiag.')
    }
    return 'ConnError'
  }

  if ($lower -match "passed\s+test\s+$($TestName.ToLowerInvariant())") {
    return 'Passed'
  }

  if ($script:DcDiagDetails[$detailKey].Count -eq 0) {
    $script:DcDiagDetails[$detailKey] = @('DCDiag retornou falha, mas não foi encontrada uma mensagem específica para resumir.')
  }

  return 'Failed'
}

function Convert-ToDateTimeSafe {
  param([Parameter(ValueFromPipeline=$true)]$Value)

  if ($null -eq $Value) { return $null }
  if ($Value -is [datetime]) { return [datetime]$Value }

  $text = [string]$Value
  if ([string]::IsNullOrWhiteSpace($text)) { return $null }

  # Formato WMI/DMTF, por exemplo: 20260810083015.000000-180
  if ($text -match '^\d{14}\.\d{6}[\+\-]\d{3}$') {
    try { return [System.Management.ManagementDateTimeConverter]::ToDateTime($text) } catch {}
  }

  $parsed = [datetime]::MinValue
  if ([datetime]::TryParse($text, [ref]$parsed)) { return $parsed }

  return $null
}

function Get-RemoteCimDataSafe {
  param(
    [Parameter(Mandatory)][string]$ComputerName,
    [Parameter(Mandatory)][string]$ClassName
  )

  # Prioriza CIM via DCOM para não depender de WinRM habilitado nos Domain Controllers.
  if ((Get-Command New-CimSession -ErrorAction SilentlyContinue) -and
      (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
    $session = $null
    try {
      $sessionOption = New-CimSessionOption -Protocol Dcom
      $session = New-CimSession -ComputerName $ComputerName -SessionOption $sessionOption -ErrorAction Stop
      return @(Get-CimInstance -ClassName $ClassName -CimSession $session -ErrorAction Stop)
    } catch {
      # Fallback abaixo.
    } finally {
      if ($session) { try { Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue } catch {} }
    }
  }

  # Fallback para Windows PowerShell 5.1.
  if (Get-Command Get-WmiObject -ErrorAction SilentlyContinue) {
    try { return @(Get-WmiObject -Class $ClassName -ComputerName $ComputerName -ErrorAction Stop) } catch {}
  }

  # Última tentativa via CIM padrão/WSMan.
  if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
    try { return @(Get-CimInstance -ClassName $ClassName -ComputerName $ComputerName -ErrorAction Stop) } catch {}
  }

  return @()
}

function Get-ServerInventorySafe {
  param([Parameter(Mandatory)][string]$ComputerName)

  $osCaption      = 'Unknown'
  $osVersion      = 'Unknown'
  $osBuild        = 'Unknown'
  $lastUpdateDate = 'Unknown'
  $lastUpdateKB   = '-'
  $lastRebootDate = 'Unknown'

  # Sistema operacional e último boot.
  $os = @(Get-RemoteCimDataSafe -ComputerName $ComputerName -ClassName 'Win32_OperatingSystem') | Select-Object -First 1
  if ($os) {
    if ($os.Caption)     { $osCaption = ([string]$os.Caption).Trim() }
    if ($os.Version)     { $osVersion = ([string]$os.Version).Trim() }
    if ($os.BuildNumber) { $osBuild   = ([string]$os.BuildNumber).Trim() }

    $bootDate = Convert-ToDateTimeSafe -Value $os.LastBootUpTime
    if ($bootDate) { $lastRebootDate = $bootDate.ToString('dd/MM/yyyy HH:mm:ss') }
  }

  # Último HotFix/QFE instalado. Esse método é compatível com Windows Server
  # e não exige o módulo PSWindowsUpdate no servidor remoto.
  $hotFixes = @(Get-RemoteCimDataSafe -ComputerName $ComputerName -ClassName 'Win32_QuickFixEngineering')
  if ($hotFixes.Count -gt 0) {
    $datedHotFixes = foreach ($hf in $hotFixes) {
      $installed = Convert-ToDateTimeSafe -Value $hf.InstalledOn
      if ($installed) {
        [pscustomobject]@{
          Date     = $installed
          HotFixID = [string]$hf.HotFixID
        }
      }
    }

    $latestHotFix = $datedHotFixes | Sort-Object Date -Descending | Select-Object -First 1
    if ($latestHotFix) {
      $lastUpdateDate = $latestHotFix.Date.ToString('dd/MM/yyyy')
      if (-not [string]::IsNullOrWhiteSpace($latestHotFix.HotFixID)) {
        $lastUpdateKB = $latestHotFix.HotFixID
      }
    }
  }

  [pscustomobject]@{
    OSCaption      = $osCaption
    OSVersion      = $osVersion
    OSBuild        = $osBuild
    LastUpdateDate = $lastUpdateDate
    LastUpdateKB   = $lastUpdateKB
    LastRebootDate = $lastRebootDate
  }
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

  # Sistema operacional / manutenção
  $serverInfo = Get-ServerInventorySafe -ComputerName $target

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
    OSCaption         = $serverInfo.OSCaption
    OSVersion         = $serverInfo.OSVersion
    OSBuild           = $serverInfo.OSBuild
    LastUpdateDate    = $serverInfo.LastUpdateDate
    LastUpdateKB      = $serverInfo.LastUpdateKB
    LastRebootDate    = $serverInfo.LastRebootDate
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
# HTML (layout moderno + resumo)
# ===========================
$EndDate = Get-Date

# Propriedades exibidas no relatório. A mesma lista é usada para calcular o resumo.
$StatusProperties = @(
  'PingStatus',
  'NetlogonService',
  'NTDSService',
  'DNSServiceStatus',
  'NetlogonsTest',
  'ReplicationTest',
  'ServicesTest',
  'AdvertisingTest',
  'FSMOCheckTest',
  'NETLOGONTest',
  'SYSVOLTest',
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
)


# Nomes amigáveis usados na seção "Falhas identificadas".
$StatusLabels = @{
  PingStatus       = 'Ping / Conectividade'
  NetlogonService  = 'Serviço Netlogon'
  NTDSService      = 'Serviço NTDS'
  DNSServiceStatus = 'Serviço DNS'
  NetlogonsTest    = 'DCDiag - Netlogons'
  ReplicationTest  = 'DCDiag - Replicação'
  ServicesTest     = 'DCDiag - Services'
  AdvertisingTest  = 'DCDiag - Advertising'
  FSMOCheckTest    = 'DCDiag - FSMO Check'
  NETLOGONTest     = 'Compartilhamento NETLOGON'
  SYSVOLTest       = 'Compartilhamento SYSVOL'
  KerberosTCP      = 'Kerberos TCP 88'
  KerberosUDP      = 'Kerberos UDP 88'
  LDAPTCP          = 'LDAP TCP 389'
  LDAPUDP          = 'LDAP UDP 389'
  LDAPS            = 'LDAPS TCP 636'
  GCLDAP           = 'Global Catalog TCP 3268'
  GCLDAPS          = 'Global Catalog SSL TCP 3269'
  DNS_TCP          = 'DNS TCP 53'
  DNS_UDP          = 'DNS UDP 53'
  DNS_A_Self       = 'DNS A (Self)'
  DNS_SRV_Forest   = 'DNS SRV (Forest)'
  DNS_PTR_Self     = 'DNS PTR (Self)'
  NTLM_RPC135      = 'RPC TCP 135'
  NTLM_139         = 'NetBIOS TCP 139'
  NTLM_445         = 'SMB TCP 445'
}

$StatusCategories = @{
  PingStatus='Conectividade'; NetlogonService='Serviços'; NTDSService='Serviços'; DNSServiceStatus='Serviços'
  NetlogonsTest='DCDiag'; ReplicationTest='DCDiag'; ServicesTest='DCDiag'; AdvertisingTest='DCDiag'; FSMOCheckTest='DCDiag'
  NETLOGONTest='Compartilhamentos'; SYSVOLTest='Compartilhamentos'
  KerberosTCP='Kerberos'; KerberosUDP='Kerberos'
  LDAPTCP='LDAP / GC'; LDAPUDP='LDAP / GC'; LDAPS='LDAP / GC'; GCLDAP='LDAP / GC'; GCLDAPS='LDAP / GC'
  DNS_TCP='DNS'; DNS_UDP='DNS'; DNS_A_Self='DNS'; DNS_SRV_Forest='DNS'; DNS_PTR_Self='DNS'
  NTLM_RPC135='NTLM / RPC'; NTLM_139='NTLM / RPC'; NTLM_445='NTLM / RPC'
}

$DcDiagPropertyToTest = @{
  NetlogonsTest='Netlogons'
  ReplicationTest='Replications'
  ServicesTest='Services'
  AdvertisingTest='Advertising'
  FSMOCheckTest='FSMOCheck'
}

# Resumo geral do Health Check
$AllStatuses = foreach ($r in $ResultsArr) {
  foreach ($p in $StatusProperties) {
    [string]$r.$p
  }
}

$OkCount   = @($AllStatuses | Where-Object { (Get-StatusColor -Status $_) -eq 'ok' }).Count
$WarnCount = @($AllStatuses | Where-Object { (Get-StatusColor -Status $_) -eq 'warn' }).Count
$FailCount = @($AllStatuses | Where-Object { (Get-StatusColor -Status $_) -eq 'fail' }).Count
$TotalChecks = $OkCount + $WarnCount + $FailCount
$HealthPercent = if ($TotalChecks -gt 0) { [math]::Round(($OkCount / $TotalChecks) * 100, 1) } else { 0 }


# Consolida somente falhas críticas para uma seção resumida do relatório.
$FailureItems = @(
  foreach ($r in $ResultsArr) {
    foreach ($p in $StatusProperties) {
      $status = [string]$r.$p
      if ((Get-StatusColor -Status $status) -ne 'fail') { continue }

      $detail = ''

      if ($DcDiagPropertyToTest.ContainsKey($p)) {
        $diagTest = $DcDiagPropertyToTest[$p]
        $shortName = ([string]$r.Identity -split '\.')[0]
        $candidateKeys = @(
          "$([string]$r.Identity)|$diagTest",
          "$shortName|$diagTest"
        )

        foreach ($candidateKey in $candidateKeys) {
          if ($script:DcDiagDetails.ContainsKey($candidateKey) -and $script:DcDiagDetails[$candidateKey].Count -gt 0) {
            $detail = ($script:DcDiagDetails[$candidateKey] -join "`n")
            break
          }
        }
      }

      if ([string]::IsNullOrWhiteSpace($detail)) {
        $detail = switch ($p) {
          'PingStatus'       { 'O Domain Controller não respondeu ao teste de conectividade ICMP.' }
          'NETLOGONTest'     { 'O compartilhamento NETLOGON não pôde ser acessado.' }
          'SYSVOLTest'       { 'O compartilhamento SYSVOL não pôde ser acessado.' }
          'KerberosTCP'      { 'Não foi possível estabelecer conexão TCP com a porta 88.' }
          'LDAPTCP'          { 'Não foi possível estabelecer conexão TCP com a porta 389.' }
          'LDAPS'            { 'Não foi possível estabelecer conexão TCP com a porta 636.' }
          'GCLDAP'           { 'Não foi possível estabelecer conexão TCP com a porta 3268.' }
          'GCLDAPS'          { 'Não foi possível estabelecer conexão TCP com a porta 3269.' }
          'DNS_TCP'          { 'Não foi possível estabelecer conexão TCP com a porta 53.' }
          'NTLM_RPC135'      { 'Não foi possível estabelecer conexão TCP com a porta 135.' }
          'NTLM_139'         { 'Não foi possível estabelecer conexão TCP com a porta 139.' }
          'NTLM_445'         { 'Não foi possível estabelecer conexão TCP com a porta 445.' }
          'DNS_A_Self'       { 'Falha ao resolver o registro A do próprio Domain Controller.' }
          'DNS_SRV_Forest'   { 'Falha ao resolver o registro SRV da floresta.' }
          'DNS_PTR_Self'     { 'Falha ao resolver o registro PTR do Domain Controller.' }
          default {
            if ($p -match 'Service') { "O serviço retornou o estado '$status'." }
            else { "O teste retornou o status '$status'." }
          }
        }
      }

      [pscustomobject]@{
        DomainController = [string]$r.Identity
        Category         = [string]$StatusCategories[$p]
        Test             = [string]$StatusLabels[$p]
        Status           = $status
        Detail           = $detail
      }
    }
  }
)

# Codificação para evitar quebra do HTML caso os campos tenham caracteres especiais
$ClientNameHtml  = [System.Net.WebUtility]::HtmlEncode([string]$ClientName)
$AnalystNameHtml = [System.Net.WebUtility]::HtmlEncode([string]$AnalystName)
$ForestRootHtml  = [System.Net.WebUtility]::HtmlEncode([string]$ForestRoot)

$css = @"
<style>
  * { box-sizing: border-box; }

  body {
    margin: 0;
    background: #f4f7fb;
    color: #1f2937;
    font-family: "Segoe UI", Tahoma, Arial, sans-serif;
  }

  .page {
    width: 100%;
    padding: 24px;
  }

  .hero {
    background: linear-gradient(135deg, #0f4c81 0%, #1769aa 55%, #2386c8 100%);
    color: #ffffff;
    border-radius: 14px;
    padding: 24px 28px;
    box-shadow: 0 8px 24px rgba(15, 76, 129, 0.18);
    margin-bottom: 18px;
  }

  .hero-title {
    margin: 0 0 6px 0;
    font-size: 28px;
    font-weight: 650;
    letter-spacing: -0.3px;
  }

  .hero-subtitle {
    margin: 0;
    color: rgba(255,255,255,0.88);
    font-size: 13px;
  }

  .meta-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(160px, 1fr));
    gap: 10px;
    margin-top: 18px;
  }

  .meta-item {
    background: rgba(255,255,255,0.11);
    border: 1px solid rgba(255,255,255,0.18);
    border-radius: 9px;
    padding: 10px 12px;
  }

  .meta-label {
    display: block;
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.7px;
    opacity: 0.78;
    margin-bottom: 3px;
  }

  .meta-value {
    display: block;
    font-size: 13px;
    font-weight: 600;
    overflow-wrap: anywhere;
  }

  .summary-grid {
    display: grid;
    grid-template-columns: repeat(5, minmax(130px, 1fr));
    gap: 12px;
    margin-bottom: 18px;
  }

  .summary-card {
    background: #ffffff;
    border: 1px solid #e3eaf2;
    border-radius: 12px;
    padding: 16px 18px;
    box-shadow: 0 3px 12px rgba(15, 23, 42, 0.05);
  }

  .summary-label {
    font-size: 11px;
    color: #64748b;
    text-transform: uppercase;
    letter-spacing: 0.55px;
    font-weight: 650;
  }

  .summary-value {
    display: block;
    margin-top: 5px;
    font-size: 27px;
    line-height: 1;
    font-weight: 700;
    color: #0f172a;
  }

  .summary-card.card-ok { border-top: 4px solid #159447; }
  .summary-card.card-warn { border-top: 4px solid #d79600; }
  .summary-card.card-fail { border-top: 4px solid #d13438; }
  .summary-card.card-dc { border-top: 4px solid #1769aa; }
  .summary-card.card-health { border-top: 4px solid #6b5bd2; }

  .panel {
    background: #ffffff;
    border: 1px solid #e3eaf2;
    border-radius: 12px;
    box-shadow: 0 3px 12px rgba(15, 23, 42, 0.05);
    overflow: hidden;
    margin-bottom: 18px;
  }

  .panel-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 14px;
    padding: 15px 18px;
    border-bottom: 1px solid #e8edf3;
    background: #fbfcfe;
  }

  .panel-title {
    margin: 0;
    font-size: 16px;
    font-weight: 650;
    color: #24364b;
  }

  .legend {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    font-size: 11px;
  }

  .legend-badge,
  .status-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 4px;
    border-radius: 999px;
    font-weight: 650;
    white-space: nowrap;
  }

  .legend-badge { padding: 5px 9px; }
  .status-badge { padding: 4px 8px; min-width: 66px; }

  .ok {
    background: #e7f6ec;
    color: #0f6c3a;
    border: 1px solid #b9e5c8;
  }

  .warn {
    background: #fff4ce;
    color: #8a5d00;
    border: 1px solid #f0d58a;
  }

  .fail {
    background: #fde7e9;
    color: #b42318;
    border: 1px solid #f4b8bd;
  }

  .inventory-panel {
    border-left: 4px solid #1769aa;
  }

  .inventory-panel .panel-header {
    background: #f5f9fd;
  }

  .inventory-table {
    min-width: 1180px !important;
  }

  .inventory-table th,
  .inventory-table td {
    font-size: 11px;
  }

  .inventory-table thead th {
    position: static !important;
    background: #1769aa;
    color: #ffffff;
    height: auto;
  }

  .inventory-table td {
    text-align: left;
    white-space: normal;
  }

  .inventory-table .inventory-dc {
    min-width: 210px;
    font-weight: 650;
    color: #24364b;
  }

  .inventory-table .inventory-os {
    min-width: 260px;
  }

  .inventory-table .inventory-date {
    min-width: 150px;
    white-space: nowrap;
  }

  .inventory-table .inventory-kb {
    min-width: 110px;
    white-space: nowrap;
  }

  .failure-panel {
    border-left: 4px solid #d13438;
  }

  .failure-panel .panel-header {
    background: #fff8f8;
  }

  .failure-count {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 28px;
    height: 28px;
    padding: 0 9px;
    border-radius: 999px;
    background: #fde7e9;
    color: #b42318;
    border: 1px solid #f4b8bd;
    font-size: 12px;
    font-weight: 700;
  }

  .failure-table {
    min-width: 980px !important;
  }

  .failure-table th,
  .failure-table td {
    font-size: 11px;
  }

  .failure-table thead th {
    position: static !important;
    background: #8f2d2d;
    color: #ffffff;
    height: auto;
  }

  .failure-table .failure-dc {
    min-width: 210px;
    text-align: left;
    font-weight: 650;
    color: #24364b;
  }

  .failure-table .failure-category {
    min-width: 130px;
    font-weight: 650;
  }

  .failure-table .failure-test {
    min-width: 190px;
    text-align: left;
  }

  .failure-table .failure-detail {
    min-width: 420px;
    text-align: left;
    white-space: normal;
    line-height: 1.45;
  }

  .failure-empty {
    padding: 16px 18px;
    color: #0f6c3a;
    background: #f4fbf6;
    font-size: 12px;
    border-top: 1px solid #d8eddf;
  }

  .note {
    margin: 0 0 18px 0;
    padding: 13px 16px;
    background: #eef6fc;
    border-left: 4px solid #1769aa;
    border-radius: 8px;
    color: #334155;
    font-size: 12px;
    line-height: 1.55;
  }

  .table-scroll {
    width: 100%;
    overflow-x: auto;
    overflow-y: visible;
  }

  table {
    border-collapse: separate;
    border-spacing: 0;
    min-width: 3300px;
    width: 100%;
  }

  th, td {
    border-right: 1px solid #e5eaf0;
    border-bottom: 1px solid #e5eaf0;
    padding: 8px 9px;
    font-size: 11px;
    text-align: center;
    vertical-align: middle;
    background: #ffffff;
  }

  thead th {
    font-weight: 650;
    white-space: nowrap;
  }

  thead tr.group-row th {
    position: sticky;
    top: 0;
    z-index: 5;
    height: 36px;
    color: #ffffff;
    border-bottom: 1px solid rgba(255,255,255,0.22);
    letter-spacing: 0.2px;
  }

  thead tr.column-row th {
    position: sticky;
    top: 36px;
    z-index: 4;
    background: #34495e;
    color: #ffffff;
    height: 42px;
  }

  .group-identity { background: #24364b; }
  .group-service  { background: #1769aa; }
  .group-dcdiag   { background: #5c4aa5; }
  .group-share    { background: #277da1; }
  .group-kerberos { background: #c06c00; }
  .group-ldap     { background: #008272; }
  .group-dns      { background: #0078a8; }
  .group-ntlm     { background: #8d4f73; }

  tbody tr:nth-child(even) td { background: #f9fbfd; }
  tbody tr:hover td { background: #eef6fc; }

  .identity-head {
    position: sticky !important;
    left: 0;
    top: 0 !important;
    z-index: 8 !important;
    min-width: 210px;
    max-width: 260px;
  }

  .idcell {
    position: sticky;
    left: 0;
    z-index: 3;
    min-width: 210px;
    max-width: 260px;
    text-align: left;
    font-weight: 650;
    color: #24364b;
    background: #f2f5f8 !important;
    box-shadow: 2px 0 0 #dde4ec;
    overflow-wrap: anywhere;
  }

  .footer {
    color: #64748b;
    font-size: 11px;
    line-height: 1.7;
    padding: 4px 2px 10px 2px;
  }

  @media (max-width: 1000px) {
    .meta-grid { grid-template-columns: repeat(2, minmax(140px, 1fr)); }
    .summary-grid { grid-template-columns: repeat(2, minmax(130px, 1fr)); }
    .page { padding: 14px; }
  }

  @media print {
    body { background: #ffffff; }
    .page { padding: 0; }
    .hero, .panel, .summary-card { box-shadow: none; }
    .table-scroll { overflow: visible; }
    thead tr.group-row th, thead tr.column-row th, .identity-head, .idcell { position: static !important; }
  }
</style>
"@

# Gera a seção visual de sistema operacional e manutenção dos Domain Controllers.
$inventoryRows = foreach ($r in $ResultsArr) {
  $dcHtml       = [System.Net.WebUtility]::HtmlEncode([string]$r.Identity)
  $osHtml       = [System.Net.WebUtility]::HtmlEncode([string]$r.OSCaption)
  $versionHtml  = [System.Net.WebUtility]::HtmlEncode([string]$r.OSVersion)
  $buildHtml    = [System.Net.WebUtility]::HtmlEncode([string]$r.OSBuild)
  $updateHtml   = [System.Net.WebUtility]::HtmlEncode([string]$r.LastUpdateDate)
  $kbHtml       = [System.Net.WebUtility]::HtmlEncode([string]$r.LastUpdateKB)
  $rebootHtml   = [System.Net.WebUtility]::HtmlEncode([string]$r.LastRebootDate)

  "<tr><td class='inventory-dc'>$dcHtml</td><td class='inventory-os'>$osHtml</td><td>$versionHtml</td><td>$buildHtml</td><td class='inventory-date'>$updateHtml</td><td class='inventory-kb'>$kbHtml</td><td class='inventory-date'>$rebootHtml</td></tr>"
}

$inventorySection = @"
  <section class='panel inventory-panel'>
    <div class='panel-header'>
      <h2 class='panel-title'>Sistema Operacional e Manutenção dos Domain Controllers</h2>
      <span class='legend-badge ok'>&#128187; Inventário</span>
    </div>
    <div class='table-scroll'>
      <table class='inventory-table'>
        <thead>
          <tr>
            <th>Domain Controller</th>
            <th>Edição do Windows Server</th>
            <th>Versão</th>
            <th>Build</th>
            <th>Última atualização</th>
            <th>KB mais recente</th>
            <th>Último reboot</th>
          </tr>
        </thead>
        <tbody>
          $($inventoryRows -join "`n")
        </tbody>
      </table>
    </div>
  </section>
"@

# Gera a seção visual de falhas identificadas.
if ($FailureItems.Count -gt 0) {
  $failureRows = foreach ($failure in $FailureItems) {
    $dcHtml       = [System.Net.WebUtility]::HtmlEncode([string]$failure.DomainController)
    $categoryHtml = [System.Net.WebUtility]::HtmlEncode([string]$failure.Category)
    $testHtml     = [System.Net.WebUtility]::HtmlEncode([string]$failure.Test)
    $statusHtml   = [System.Net.WebUtility]::HtmlEncode([string]$failure.Status)
    $detailHtml   = [System.Net.WebUtility]::HtmlEncode([string]$failure.Detail) -replace '\r?\n', '<br/>'

    "<tr><td class='failure-dc'>$dcHtml</td><td class='failure-category'>$categoryHtml</td><td class='failure-test'>$testHtml</td><td><span class='status-badge fail'>&#10005; $statusHtml</span></td><td class='failure-detail'>$detailHtml</td></tr>"
  }

  $failureSection = @"
  <section class='panel failure-panel'>
    <div class='panel-header'>
      <h2 class='panel-title'>Falhas identificadas</h2>
      <span class='failure-count'>$($FailureItems.Count)</span>
    </div>
    <div class='table-scroll'>
      <table class='failure-table'>
        <thead>
          <tr>
            <th>Domain Controller</th>
            <th>Categoria</th>
            <th>Teste</th>
            <th>Status</th>
            <th>Detalhes identificados</th>
          </tr>
        </thead>
        <tbody>
          $($failureRows -join "`n")
        </tbody>
      </table>
    </div>
  </section>
"@
} else {
  $failureSection = @"
  <section class='panel'>
    <div class='panel-header'>
      <h2 class='panel-title'>Falhas identificadas</h2>
      <span class='legend-badge ok'>&#10003; Nenhuma falha</span>
    </div>
    <div class='failure-empty'>Nenhuma falha crítica foi identificada nos testes executados.</div>
  </section>
"@
}

$htmlHeader = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Active Directory Health Check By Popovici</title>
  $css
</head>
<body>
<div class='page'>

  <section class='hero'>
    <h1 class='hero-title'>Active Directory Health Check</h1>
    <p class='hero-subtitle'>Relatório de integridade dos Controladores de Domínio</p>

    <div class='meta-grid'>
      <div class='meta-item'>
        <span class='meta-label'>Cliente</span>
        <span class='meta-value'>$ClientNameHtml</span>
      </div>
      <div class='meta-item'>
        <span class='meta-label'>Analista</span>
        <span class='meta-value'>$AnalystNameHtml</span>
      </div>
      <div class='meta-item'>
        <span class='meta-label'>Floresta</span>
        <span class='meta-value'>$ForestRootHtml</span>
      </div>
      <div class='meta-item'>
        <span class='meta-label'>Execução</span>
        <span class='meta-value'>$($StartDate.ToString('dd/MM/yyyy HH:mm:ss'))</span>
      </div>
    </div>
  </section>

  <section class='summary-grid'>
    <div class='summary-card card-dc'>
      <span class='summary-label'>Domain Controllers</span>
      <span class='summary-value'>$($DCServers.Count)</span>
    </div>
    <div class='summary-card card-ok'>
      <span class='summary-label'>Testes OK</span>
      <span class='summary-value'>$OkCount</span>
    </div>
    <div class='summary-card card-warn'>
      <span class='summary-label'>Avisos</span>
      <span class='summary-value'>$WarnCount</span>
    </div>
    <div class='summary-card card-fail'>
      <span class='summary-label'>Falhas</span>
      <span class='summary-value'>$FailCount</span>
    </div>
    <div class='summary-card card-health'>
      <span class='summary-label'>Saúde Geral</span>
      <span class='summary-value'>$HealthPercent%</span>
    </div>
  </section>

  <div class='note'>
    <b>Nota sobre UDP / NoReply:</b> Em UDP não existe handshake como no TCP. O teste envia um datagrama simples; 
    se o servidor não responde, marcamos <i>NoReply</i>. Isso não significa necessariamente porta fechada: ela pode estar 
    aberta porém silenciosa ou filtrada por firewall. Para conectividade crítica do Active Directory, priorize os resultados TCP.
  </div>

  $inventorySection

  $failureSection

  <section class='panel'>
    <div class='panel-header'>
      <h2 class='panel-title'>Resultado detalhado por Domain Controller</h2>
      <div class='legend'>
        <span class='legend-badge ok'>&#10003; OK</span>
        <span class='legend-badge warn'>&#9888; Aviso</span>
        <span class='legend-badge fail'>&#10005; Falha</span>
      </div>
    </div>

    <div class='table-scroll'>
      <table>
        <thead>
          <tr class='group-row'>
            <th class='group-identity identity-head' rowspan='2'>Domain Controller</th>
            <th class='group-service' colspan='4'>Conectividade e Serviços</th>
            <th class='group-dcdiag' colspan='5'>DCDiag</th>
            <th class='group-share' colspan='2'>Compartilhamentos</th>
            <th class='group-kerberos' colspan='2'>Kerberos</th>
            <th class='group-ldap' colspan='5'>LDAP / Global Catalog</th>
            <th class='group-dns' colspan='5'>DNS</th>
            <th class='group-ntlm' colspan='3'>NTLM / RPC</th>
          </tr>
          <tr class='column-row'>
            <th>Ping</th>
            <th>Netlogon</th>
            <th>NTDS</th>
            <th>DNS Service</th>

            <th>Netlogons</th>
            <th>Replication</th>
            <th>Services</th>
            <th>Advertising</th>
            <th>FSMO Check</th>

            <th>NETLOGON</th>
            <th>SYSVOL</th>

            <th>TCP 88</th>
            <th>UDP 88</th>

            <th>LDAP TCP 389</th>
            <th>LDAP UDP 389</th>
            <th>LDAPS 636</th>
            <th>GC 3268</th>
            <th>GC SSL 3269</th>

            <th>TCP 53</th>
            <th>UDP 53</th>
            <th>A (Self)</th>
            <th>SRV (Forest)</th>
            <th>PTR (Self)</th>

            <th>RPC 135</th>
            <th>NetBIOS 139</th>
            <th>SMB 445</th>
          </tr>
        </thead>
        <tbody>
"@

$rows = foreach ($r in $ResultsArr) {
  $identityHtml = [System.Net.WebUtility]::HtmlEncode([string]$r.Identity)
  $cells = @("<td class='idcell'>$identityHtml</td>")

  foreach ($p in $StatusProperties) {
    $val = [string]$r.$p
    $valHtml = [System.Net.WebUtility]::HtmlEncode($val)
    $cls = Get-StatusColor -Status $val

    $icon = switch ($cls) {
      'ok'   { '&#10003;' }
      'fail' { '&#10005;' }
      default { '&#9888;' }
    }

    $cells += "<td><span class='status-badge $cls'>$icon $valHtml</span></td>"
  }

  "<tr>{0}</tr>" -f ($cells -join '')
}

$htmlFooter = @"
        </tbody>
      </table>
    </div>
  </section>

  <div class='footer'>
    <b>Cliente:</b> $ClientNameHtml &nbsp; | &nbsp;
    <b>Analista:</b> $AnalystNameHtml &nbsp; | &nbsp;
    <b>Floresta:</b> $ForestRootHtml<br/>
    <b>Início:</b> $($StartDate.ToString('dd/MM/yyyy HH:mm:ss')) &nbsp; | &nbsp;
    <b>Fim:</b> $($EndDate.ToString('dd/MM/yyyy HH:mm:ss')) &nbsp; | &nbsp;
    <b>Timeout DCDiag:</b> ${TimeoutSeconds}s &nbsp; | &nbsp;
    <b>DCs analisados:</b> $($DCServers.Count) &nbsp; | &nbsp;
    <b>Total de verificações:</b> $TotalChecks
  </div>

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
