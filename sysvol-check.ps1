<# ===========================
   FIXEN.local – Verificação & Correção de SYSVOL/GPO
   Autor: Eduardo Popovici
   Requisitos: PowerShell como Administrador no DC

1. Valida e (se preciso) corrige o SYSVOL/NETLOGON
2. Garante SysvolReady = 1 e reinicia os serviços
3. Verifica as pastas {GUID}\gpt.ini das Default GPOs
4. Executa dcgpofix se faltar algo
5. Força a replicação (DFSR e AD)
6. Faz checagens finais e imprime um resumo claro
7. Rode como Administrador no DC autoritativo (ex.: FIX-DC00).
8. Quando o dcgpofix aparecer, confirme com S quando solicitado.
   =========================== #>

$ErrorActionPreference = 'Stop'

# ====== Parâmetros principais ======
$DomainFqdn  = (Get-ADDomain).DNSRoot            # ex.: sbrubles.local
$SysvolRoot  = 'C:\Windows\SYSVOL'
$SysvolShare = Join-Path $SysvolRoot 'sysvol'
$DomainPath  = Join-Path $SysvolShare $DomainFqdn
$PoliciesDir = Join-Path $DomainPath 'Policies'
$ScriptsDir  = Join-Path $DomainPath 'Scripts'

function Write-Step($msg){ Write-Host "`n[+] $msg" -ForegroundColor Cyan }
function Write-Ok($msg){ Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn($msg){ Write-Host "    !  $msg" -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host "    X  $msg" -ForegroundColor Red }

# ====== 1) Estrutura SYSVOL ======
Write-Step "Validando estrutura do SYSVOL para $DomainFqdn"

# Corrigir legados: SYSVOL\domain em uso
$legacyDomain = Join-Path $SysvolRoot 'domain'
if (Test-Path $legacyDomain) {
  Write-Warn "Encontrado legado $legacyDomain. Tentando renomear para domain.old"
  try {
    # parar serviços que podem segurar handle
    Write-Host "    Parando Netlogon (se ativo)..." -NoNewline
    Stop-Service -Name Netlogon -Force -ErrorAction SilentlyContinue
    Write-Host " ok"
    Write-Host "    Parando DFSR (se ativo)..." -NoNewline
    Stop-Service -Name DFSR -Force -ErrorAction SilentlyContinue
    Write-Host " ok"

    Rename-Item -Path $legacyDomain -NewName 'domain.old' -ErrorAction Stop
    Write-Ok "Renomeado para $($legacyDomain).old"
  }
  catch {
    Write-Warn "Não foi possível renomear agora (pasta em uso ou permissão). Prosseguindo."
  }
}

# Garante as pastas corretas
foreach($p in @($SysvolShare, $DomainPath, $PoliciesDir, $ScriptsDir)){
  if(-not (Test-Path $p)){
    New-Item -ItemType Directory -Path $p | Out-Null
    Write-Ok "Criada pasta: $p"
  } else {
    Write-Ok "Pasta existe: $p"
  }
}

# ====== 2) SysvolReady e compartilhamentos ======
Write-Step "Ajustando SysvolReady e (re)iniciando serviços"

# SysvolReady = 1
$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters'
New-Item -Path $regPath -Force | Out-Null
$newVal = New-ItemProperty -Path $regPath -Name 'SysVolReady' -PropertyType DWord -Value 1 -Force
Write-Ok "SysVolReady = $($newVal.Value)"

# Sobe os serviços
Start-Service DFSR -ErrorAction SilentlyContinue
Start-Service Netlogon -ErrorAction SilentlyContinue

Start-Sleep 2

# Checar compartilhamentos
Write-Step "Checando compartilhamentos"
$shares = (net share) -join "`n"
if($shares -match 'SYSVOL'){
  Write-Ok "Compartilhamento SYSVOL ativo"
} else {
  Write-Err "SYSVOL não está compartilhado. Verifique Netlogon/DFSR."
}

if($shares -match 'NETLOGON'){
  Write-Ok "Compartilhamento NETLOGON ativo"
} else {
  # O NETLOGON aparece quando a pasta Scripts existe — garantimos acima
  Write-Warn "NETLOGON não apareceu. Reiniciando Netlogon..."
  Restart-Service Netlogon -Force -ErrorAction SilentlyContinue
  Start-Sleep 2
  $shares = (net share) -join "`n"
  if($shares -match 'NETLOGON'){ Write-Ok "NETLOGON ativo após reinício" } else { Write-Warn "NETLOGON ainda ausente (ok por enquanto)" }
}

# ====== 3) Verificar Default GPOs e gpt.ini ======
Write-Step "Verificando pastas e gpt.ini das GPOs padrão"

Import-Module GroupPolicy -ErrorAction SilentlyContinue

function Test-GpoFolder($gpoName){
  try{
    $gpo = Get-GPO -Name $gpoName -ErrorAction Stop
    $guid = $gpo.Id.Guid
    $gpoPath = Join-Path $PoliciesDir "{${guid}}"
    $gpt = Join-Path $gpoPath 'gpt.ini'
    [pscustomobject]@{
      Name   = $gpoName
      Guid   = $guid
      Folder = (Test-Path $gpoPath)
      GptIni = (Test-Path $gpt)
      Path   = $gpoPath
    }
  } catch {
    [pscustomobject]@{
      Name   = $gpoName
      Guid   = $null
      Folder = $false
      GptIni = $false
      Path   = "<sem GPO no AD>"
    }
  }
}

$checks = @(
  Test-GpoFolder -gpoName 'Default Domain Policy'
  Test-GpoFolder -gpoName 'Default Domain Controllers Policy'
)

$needFix = $false
foreach($c in $checks){
  if($c.Guid){
    Write-Host "   - $($c.Name) (GUID: $($c.Guid))" -ForegroundColor White
    Write-Host "     Pasta: $($c.Path)  -> " -NoNewline
    if($c.Folder){ Write-Host "OK" -ForegroundColor Green } else { Write-Host "AUSENTE" -ForegroundColor Yellow; $needFix = $true }
    Write-Host "     gpt.ini -> " -NoNewline
    if($c.GptIni){ Write-Host "OK" -ForegroundColor Green } else { Write-Host "AUSENTE" -ForegroundColor Yellow; $needFix = $true }
  } else {
    Write-Warn "GPO '$($c.Name)' não existe no AD (será recriada com dcgpofix)."
    $needFix = $true
  }
}

# ====== 4) Rodar dcgpofix se faltar algo ======
if($needFix){
  Write-Step "Executando dcgpofix /target:both (confirme com 'S' quando solicitado)"
  # Observação: dcgpofix pede confirmação interativa; confirme duas vezes com 'S'
  Start-Process -FilePath "dcgpofix.exe" -ArgumentList "/target:both" -Wait
} else {
  Write-Ok "Pastas/gpt.ini das Default GPOs estão OK – pulando dcgpofix."
}

# ====== 5) Forçar replicação DFSR e AD ======
Write-Step "Forçando replicação (DFSR e AD)"

# DFSR – puxar da AD config
& dfsrdiag pollad | Out-Null
Start-Sleep 2
try{
  & dfsrdiag replicationstate | Out-Null
  Write-Ok "DFSR respondeu a replicationstate"
} catch {
  Write-Warn "DFSR replicationstate não respondeu (verifique serviço/visão de eventos)."
}

# AD
& repadmin /syncall /AdeP | Out-Null
Write-Ok "repadmin /syncall executado"

# ====== 6) Testes finais ======
Write-Step "Testes finais"

# UNC
$uncPolicies = "\\$DomainFqdn\SYSVOL\$DomainFqdn\Policies"
try {
  $items = Get-ChildItem $uncPolicies -ErrorAction Stop
  Write-Ok "Acesso UNC OK: $uncPolicies (itens: $($items.Count))"
} catch {
  Write-Err "Falha no acesso UNC a $uncPolicies"
}

# gpupdate
Write-Host "Executando gpupdate /force..." -ForegroundColor Gray
try{
  gpupdate /force
} catch {
  Write-Warn "gpupdate retornou erro – verifique eventos 1058/1030 (UserEnv) e 2213/4012 (DFSR)."
}

Write-Step "Resumo"
Write-Host @"
- SYSVOL físico:     $DomainPath
- Policies dir:      $PoliciesDir
- Scripts dir:       $ScriptsDir
- Compart. SYSVOL:   $(if($shares -match 'SYSVOL'){'OK'}else{'NOK'})
- Compart. NETLOGON: $(if(((net share) -join "`n") -match 'NETLOGON'){'OK'}else{'NOK'})
- Default GPOs:      $(if($needFix){'dcgpofix executado/solicitado'}else{'OK'})
"@
