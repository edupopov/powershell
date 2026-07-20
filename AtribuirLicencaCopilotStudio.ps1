# ======================================== #
# Atribuição de licenças Copilot Studio    #
# Criado por Eduardo Popovici              #
# ======================================== #

# 1. Lista de usuários (UPN)

$Users = @(
    "contas@domínio",
    "contas2@domínios",
)

# 2. Garantir módulo Graph
if (-not (Get-Module -ListAvailable Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}
Import-Module Microsoft.Graph

# 3. Conectar ao Microsoft Graph
Connect-MgGraph -Scopes User.ReadWrite.All,Organization.Read.All

# 4. Localizar SKU do Copilot Studio
$Sku = Get-MgSubscribedSku | Where-Object {
    $_.SkuPartNumber -match "COPILOT" -and $_.SkuPartNumber -match "STUDIO"
}

if (-not $Sku) {
    Write-Host "SKU do Copilot Studio não encontrado no tenant." -ForegroundColor Red
    Write-Host "Execute: Get-MgSubscribedSku | Select SkuPartNumber, SkuId"
    return
}

$SkuId = $Sku.SkuId
Write-Host "SKU encontrado: $($Sku.SkuPartNumber)" -ForegroundColor Green

# 5. Processar usuários
foreach ($UPN in $Users) {
    try {
        $User = Get-MgUser -UserId $UPN -Property Id,UsageLocation
        # Garantir UsageLocation
        if (-not $User.UsageLocation) {
            Update-MgUser -UserId $User.Id -UsageLocation "BR"
            Write-Host "UsageLocation definido para BR: $UPN"
        }
        # Verificar se já tem a licença
        $Licenses = Get-MgUserLicenseDetail -UserId $User.Id
        if ($Licenses.SkuId -contains $SkuId) {
            Write-Host "Já possui Copilot Studio: $UPN"
            continue
        }
        # Atribuir licença
        Set-MgUserLicense `
            -UserId $User.Id `
            -AddLicenses @{ SkuId = $SkuId } `
            -RemoveLicenses @()
        Write-Host "Licença atribuída: $UPN" -ForegroundColor Cyan
    }
    catch {
        Write-Host "Erro ao processar $UPN — $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Processo finalizado." -ForegroundColor Green
