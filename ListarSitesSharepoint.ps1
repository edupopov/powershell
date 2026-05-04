# Inicializa a variável que irá armazenar o total de arquivos
# Começa com zero e será incrementada a cada site processado
$TotalFiles = 0

# Recupera todos os sites do SharePoint Online do tenant
# -Limit All garante que todos os sites sejam retornados, sem paginação
Get-SPOSite -Limit All | ForEach-Object {

    # Exibe no console o site que está sendo processado no momento
    # Útil para acompanhamento e troubleshooting
    Write-Host "Processando site:" $_.Url

    # Soma ao total geral a quantidade de arquivos do site atual
    # StorageMetrics.TotalFileCount retorna o número total de arquivos do site
    # Esse valor vem das métricas internas do SharePoint (não percorre bibliotecas)
    $TotalFiles += $_.StorageMetrics.TotalFileCount
}

# Exibe no final o total consolidado de arquivos em todos os sites do tenant
$TotalFiles
