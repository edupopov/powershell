Import-Module ActiveDirectory

# ============================================
# LISTA DE ESTAÇÕES A SEREM APAGADAS DO DOMÍNIO
# SEM .TXT — TUDO AQUI DENTRO
# Digite o nome da máquina entre aspas duplas
# Exemplo - "WORK-01" - sem o FQDN
# ============================================
$Workstations = @(



)

# ============================================
# PROCESSO DE EXCLUSÃO
# ============================================

foreach ($name in $Workstations) {

    Write-Host "Procurando: $name"

    $obj = Get-ADComputer -Filter "Name -eq '$name' -or SamAccountName -eq '$name' -or SamAccountName -eq '$name$'" -Properties DistinguishedName -ErrorAction SilentlyContinue

    if ($null -eq $obj) {
        Write-Host " Não encontrado no AD" -ForegroundColor Red
        continue
    }

    Write-Host " → Encontrado em: $($obj.DistinguishedName)"

    # EXCLUSÃO (modo simulação por padrão)
    Remove-ADComputer -Identity $obj.DistinguishedName -Confirm:$false

    Write-Host "   (Simulação de exclusão)" -ForegroundColor Yellow
}

Write-Host "`nFIM."
