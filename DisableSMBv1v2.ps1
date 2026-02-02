<#
.SYNOPSIS
  Hardening SMB para Windows 11 (uso local/manual):
  - Remove e desativa SMBv1
  - Garante SMB2/3 habilitado
  - Exige criptografia e assinatura
  - Tenta fixar dialeto em SMB 3.1.1 (24H2+); se não suportado, aplica fallback no cliente via Registro
  - Ativa auditoria de tentativas SMBv1

.NOTES
  Reinício recomendado ao final.
#>

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-IsAdmin)) { throw "Execute este script como Administrador." }

Write-Host "Iniciando hardening de SMB..." -ForegroundColor Cyan

# 1) Remover/Desabilitar SMBv1 (recurso opcional) + reforço no servidor
try {
    $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue
    if ($smb1 -and $smb1.State -in 'Enabled','EnablePending') {
        Write-Host "Desinstalando recurso SMB 1.0/CIFS..." -ForegroundColor Yellow
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -Remove -NoRestart | Out-Null
    } else {
        Write-Host "SMB1 (recurso) já está desabilitado/ausente." -ForegroundColor DarkGray
    }
} catch { Write-Warning "Falha ao consultar/remover SMB1: $($_.Exception.Message)" }

Set-SmbServerConfiguration -EnableSMB1Protocol $false -EnableSMB2Protocol $true -AuditSmb1Access $true -Confirm:$false | Out-Null

# 2) Exigir criptografia (obriga SMB 3.x) e bloquear acesso não criptografado
try {
    Set-SmbServerConfiguration -EncryptData $true -RejectUnencryptedAccess $true -Confirm:$false | Out-Null
} catch { Write-Warning "Falha ao ativar criptografia no servidor SMB: $($_.Exception.Message)" }

try {
    $clientParams = (Get-Command Set-SmbClientConfiguration).Parameters.Keys
    if ($clientParams -contains 'RequireEncryption') {
        Set-SmbClientConfiguration -RequireEncryption $true -Confirm:$false | Out-Null
        Write-Host "Cliente: criptografia exigida para todas as conexões." -ForegroundColor Green
    } else {
        Write-Host "Cliente: parâmetro -RequireEncryption indisponível nesta build; pulando exigência global." -ForegroundColor DarkGray
    }
} catch { Write-Warning "Falha ao configurar criptografia no cliente: $($_.Exception.Message)" }

# 3) Exigir assinatura (signing)
try {
    Set-SmbServerConfiguration -RequireSecuritySignature $true -Confirm:$false | Out-Null
    Set-SmbClientConfiguration -RequireSecuritySignature $true -EnableSecuritySignature $true -Confirm:$false | Out-Null
} catch { Write-Warning "Falha ao configurar assinatura SMB: $($_.Exception.Message)" }

# 4) Fixar dialeto em SMB 3.1.1 (24H2+) se suportado; senão, fallback via Registro no cliente
function Set-SmbDialect311 {
    param([ValidateSet('Server','Client')][string] $Side)

    $cmd = if ($Side -eq 'Server') { Get-Command Set-SmbServerConfiguration } else { Get-Command Set-SmbClientConfiguration }
    $hasMin = $cmd.Parameters.ContainsKey('Smb2DialectMin')
    $hasMax = $cmd.Parameters.ContainsKey('Smb2DialectMax')

    if ($hasMin -and $hasMax) {
        if ($Side -eq 'Server') {
            Set-SmbServerConfiguration -Smb2DialectMin SMB311 -Smb2DialectMax SMB311 -Confirm:$false | Out-Null
        } else {
            Set-SmbClientConfiguration -Smb2DialectMin SMB311 -Smb2DialectMax SMB311 -Confirm:$false | Out-Null
        }
        Write-Host "${Side}: Dialetos fixados em SMB 3.1.1 (Min=Max=SMB311)." -ForegroundColor Green
        return $true
    }
    return $false
}

$serverDialOk = Set-SmbDialect311 -Side Server
$clientDialOk = Set-SmbDialect311 -Side Client

if (-not $clientDialOk) {
    # Fallback (cliente): Registro Min/Max SMB2 Dialect = 0x311
    try {
        $wkParams = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
        New-Item -Path $wkParams -Force | Out-Null
        New-ItemProperty -Path $wkParams -Name 'MinSMB2Dialect' -PropertyType DWord -Value 0x00000311 -Force | Out-Null
        New-ItemProperty -Path $wkParams -Name 'MaxSMB2Dialect' -PropertyType DWord -Value 0x00000311 -Force | Out-Null
        Write-Host "Cliente: definido fallback de dialeto via Registro (Min/Max=0x311)." -ForegroundColor Yellow
    } catch { Write-Warning "Falha ao definir dialeto via Registro: $($_.Exception.Message)" }
}

if (-not $serverDialOk) {
    Write-Host "Servidor: cmdlet sem Min/Max de dialeto; manteremos SMB2/3 + criptografia/assinatura para forçar 3.x." -ForegroundColor DarkGray
}

# 5) Resumo e auditoria (versão corrigida)

Write-Host "`n=== Resumo de Configuração SMB ===" -ForegroundColor Cyan

# -- SERVER --
$serverProps = @(
  'EnableSMB1Protocol',
  'EnableSMB2Protocol',
  'EncryptData',
  'RejectUnencryptedAccess',
  'RequireSecuritySignature',
  'AuditSmb1Access'
)

if ((Get-Command Set-SmbServerConfiguration).Parameters.ContainsKey('Smb2DialectMin')) {
  $serverProps += 'Smb2DialectMin','Smb2DialectMax'
}

Get-SmbServerConfiguration | Select-Object -Property $serverProps | Format-List

# -- CLIENT --
$clientProps = @(
  'EnableSecuritySignature',
  'RequireSecuritySignature'
)

if ((Get-Command Set-SmbClientConfiguration).Parameters.ContainsKey('RequireEncryption')) {
  $clientProps += 'RequireEncryption'
}
if ((Get-Command Set-SmbClientConfiguration).Parameters.ContainsKey('Smb2DialectMin')) {
  $clientProps += 'Smb2DialectMin','Smb2DialectMax'
}

Get-SmbClientConfiguration | Select-Object -Property $clientProps | Format-List

Write-Host "`nÚltimos eventos de auditoria SMB1 (se houver):" -ForegroundColor Cyan
try {
  Get-WinEvent -LogName 'Microsoft-Windows-SMBServer/Audit' -MaxEvents 5 |
    Format-Table TimeCreated, Id, LevelDisplayName, Message -AutoSize
} catch {
  Write-Host "Sem eventos ou log indisponível." -ForegroundColor DarkGray
}

Write-Host "`n*** Reinicie o computador para aplicar completamente todas as alterações. ***" -ForegroundColor Magenta
