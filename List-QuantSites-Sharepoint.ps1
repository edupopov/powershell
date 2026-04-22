# Instalar o módulo de powershell
Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser -Force

# Carregar o módulo depowershell
Get-Module Microsoft.Online.SharePoint.PowerShell -ListAvailable

# Conectar ao tenant
Connect-SPOService -Url https://TENANT-admin.sharepoint.com/

# Listar Sites
(Get-SPOSite -Limit All).Count
