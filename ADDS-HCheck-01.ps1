<# 
AD Health Check – Compatível com PS 5.1/7, próximo do script original, com analista/cliente
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

  # Sem default aqui; definimos logo abaixo com um fallback seguro para a pasta do script
  [string]$OutputPath,

  [string]$ExportCsv,
  [string]$ExportJson
)

# -------- Caminho seguro do script (funciona mesmo se $PSScriptRoot vier vazio) --------
$ScriptRootSafe = if ($PSScriptRoot) {
  $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
  Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
  $PWD.Path
}
if (-not $OutputPath -or [string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $ScriptRootSafe 'ADReport.html'
}
# ---------------------------------------------------------------------------------------

# ===========================
# Utilitários
# ===========================
function Get-ServiceStatusSafe {
  param(
    [Parameter(Mandatory)][string]$ComputerName,
    [Parameter(Mandatory)][string]$ServiceName
  )
  try {
    $svc = Get-Service -ComputerName $ComputerName -Name $ServiceName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $svc) { return 'Unknown' }
    if ($svc.Status -eq 'Running') { 'Running' } else { [string]$svc.Status }
  } catch { 'Unknown' }
}

function Test-UncShare {
  param(
    [Parameter(Mandatory)][string]$ComputerName,
    [Parameter(Mandatory)][ValidateSet('NETLOGON','SYSVOL')] [string]$ShareName
  )
  try {
    if (Test-Path -LiteralPath ("filesystem::\\{0}\{1}" -f $ComputerName,$ShareName) -ErrorAction SilentlyContinue) { 'Passed' }
    else { 'Failed' }
  } catch { 'Failed' }
}

function Invoke-DcDiagTest {
  <#
    Roda dcdiag SEM jobs, com timeout real via .NET
  #>
  param(
    [Parameter(Mandatory)][string]$ComputerName,
    [Parameter(Mandatory)][ValidateSet('Netlogons','Replications','Services','Advertising','FSMOCheck')] [string]$TestName,
    [int]$Timeout = 180
  )

  # Caminho absoluto do dcdiag
  try { $exe = (Get-Command -Name 'dcdiag.exe' -ErrorAction Stop).Source }
  catch { return 'Failed' }

  # ProcessStartInfo para capturar saída
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
    $finished = $proc.WaitForExit($Timeout * 1000)
    if (-not $finished) {
      try { $proc.Kill() | Out-Null } catch {}
      return 'Timeout'
    }
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
    'Failed'    { 'fail' }
    'PingFail'  { 'fail' }
    'Unknown'   { 'warn' }
    'Timeout'   { 'warn' }
    'ConnError' { 'warn' }
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

# Usar o mesmo método do script original (DirectoryServices) para garantir compat
try {
  $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
  $DCServers = $forest.Domains | ForEach-Object { $_.DomainControllers } | ForEach-Object { $_.Name }
} catch {
  throw "Falha ao enumerar DCs: $($_.Exception.Message)"
}
$DCServers = $DCServers | Sort-Object -Unique
if (-not $DCServers) { throw "Nenhum DC encontrado." }

Write-Host "DCs encontrados: $($DCServers -join ', ')" -ForegroundColor DarkCyan

# ===========================
# Testes por DC (sem bloquear pelos pings)
# ===========================
$ResultsArr = foreach ($dcFqdn in $DCServers) {
  $short = ($dcFqdn -split '\.')[0]

  # Ping tenta FQDN depois short; mas não bloqueia os outros testes
  $pingOk = $false
  try { $pingOk = Test-Connection -ComputerName $dcFqdn -Count 1 -Quiet -ErrorAction SilentlyContinue -TimeoutSeconds 2 } catch {}
  if (-not $pingOk) {
    try { $pingOk = Test-Connection -ComputerName $short  -Count 1 -Quiet -ErrorAction SilentlyContinue -TimeoutSeconds 2 } catch {}
  }
  $pingStatus = if ($pingOk) { 'Success' } else { 'PingFail' }

  # Nome preferido p/ operações: se ping falhar no FQDN mas short respondeu, use short
  $target = if ($pingOk) {
    # se FQDN respondeu, usa FQDN; se só short respondeu, usa short (simples)
    if (Test-Connection -ComputerName $dcFqdn -Count 1 -Quiet -ErrorAction SilentlyContinue -TimeoutSeconds 2) { $dcFqdn } else { $short }
  } else {
    # mesmo sem ping, tenta FQDN primeiro, depois short
    $dcFqdn
  }

  # Serviços
  $netlogon = Get-ServiceStatusSafe -ComputerName $target -ServiceName 'Netlogon'
  $ntds     = Get-ServiceStatusSafe -ComputerName $target -ServiceName 'NTDS'
  $dns      = Get-ServiceStatusSafe -ComputerName $target -ServiceName 'DNS'

  # DCDIAG com timeout real
  $tNetlogons   = Invoke-DcDiagTest -ComputerName $target -TestName 'Netlogons'    -Timeout $TimeoutSeconds
  $tRepl        = Invoke-DcDiagTest -ComputerName $target -TestName 'Replications' -Timeout $TimeoutSeconds
  $tServices    = Invoke-DcDiagTest -ComputerName $target -TestName 'Services'     -Timeout $TimeoutSeconds
  $tAdvertising = Invoke-DcDiagTest -ComputerName $target -TestName 'Advertising'  -Timeout $TimeoutSeconds
  $tFSMO        = Invoke-DcDiagTest -ComputerName $target -TestName 'FSMOCheck'    -Timeout $TimeoutSeconds

  # Shares
  $tNetlogonShare = Test-UncShare -ComputerName $target -ShareName 'NETLOGON'
  $tSysvolShare   = Test-UncShare -ComputerName $target -ShareName 'SYSVOL'

  [pscustomobject]@{
    Identity          = $dcFqdn
    PingStatus        = $pingStatus
    NetlogonService   = $netlogon
    NTDSService       = $ntds
    DNSServiceStatus  = $dns
    NetlogonsTest     = $tNetlogons
    ReplicationTest   = $tRepl
    ServicesTest      = $tServices
    AdvertisingTest   = $tAdvertising
    NETLOGONTest      = $tNetlogonShare
    SYSVOLTest        = $tSysvolShare
    FSMOCheckTest     = $tFSMO
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
  h1 { color: #3A4FA0; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #999; padding: 6px 8px; font-size: 12px; text-align: center; }
  th { background: #B04B4B; color: #fff; }
  tr:nth-child(even) { background: #f7f7f7; }
  .ok    { background: #7FFFD4; }
  .fail  { background: #FF6B6B; }
  .warn  { background: #FFD166; }
  .idcell{ background: #DCDCDC; text-align: left; font-weight: bold; }
  .meta  { font-size: 11px; color: #3A4FA0; }
</style>
"@

$htmlHeader = @"
<html>
<head><meta charset="utf-8" /><title>Active Directory Health Check</title>$css</head>
<body>
<h1>Active Directory Health Check</h1>
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
      'FSMOCheckTest'
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
  Timeout: ${TimeoutSeconds}s &nbsp; | &nbsp; DCs: $($DCServers.Count)
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

# ===========================
# E-mail opcional
# ===========================
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
