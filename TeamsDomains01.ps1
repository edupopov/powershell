############################################################################
# Script que insere novos domínios a lista de permissão de comunicação     #
# Criado por Eduardo Popovici                                              #
# Data: 06-07-2026                                                         #
############################################################################

# Conecta no Teams
Connect-MicrosoftTeams

# Caminho do arquivo
$Arquivo = "C:\Users\edupopov\OneDrive\Dominios.txt"

# Backup da configuração atual
$Backup = "C:\Users\edupopov\OneDrive\TeamsDomains_Backup.txt"

(Get-CsTenantFederationConfiguration).AllowedDomains.AllowedDomain.Domain |
Out-File $Backup

Write-Host "Backup salvo em: $Backup" -ForegroundColor Green

# Carrega os domínios da lista
$Domains = Get-Content $Arquivo |
            ForEach-Object {$_.Trim()} |
            Where-Object {$_ -ne ""} |
            Sort-Object -Unique

Write-Host "$($Domains.Count) domínios encontrados." -ForegroundColor Yellow

# Obtém os domínios já configurados
$CurrentDomains = (Get-CsTenantFederationConfiguration).AllowedDomains.AllowedDomain.Domain

# Filtra somente os novos
$DomainsToAdd = $Domains | Where-Object {$_ -notin $CurrentDomains}

Write-Host "$($DomainsToAdd.Count) domínios serão adicionados." -ForegroundColor Cyan

# Adiciona os domínios
foreach ($Domain in $DomainsToAdd)
{
    try
    {
        Set-CsTenantFederationConfiguration `
            -AllowedDomainsAsAList @{Add=$Domain}

        Write-Host "[OK] $Domain" -ForegroundColor Green
    }
    catch
    {
        Write-Warning "[ERRO] $Domain"
    }
}

Write-Host "Processo concluído." -ForegroundColor Green
