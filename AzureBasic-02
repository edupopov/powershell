#################################################
#    Instalar Módulo Azure - Powershell - 1     #
#################################################

Get-Module PowerShellGet -list | Select-Object Name.Version.Path
Get-Module Azure
Install-Module Azure -AllowClobber
Import-Module Azure
Get-Module Azure

#################################################
#        Instalar módulo do Azure PS - 2        #
#################################################

Install-Module azurerm
Install-Module -Name Az -AllowClobber
Install-Module -Name Az -AllowClobber -Scope CurrentUser

#################################################
#        Validar versão do Powershell           #
#################################################

$psversiontable
Login-AzRmAccount
Login-AzureRmAccount
Get-AzSubscription
Get-AzContext
