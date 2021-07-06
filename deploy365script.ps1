param([switch]$Elevated)

function Test-Admin {
  $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
  $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) 
    {
        # tried to elevate, did not work, aborting
    } 
    else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
}

exit
}

'RUNNING WITH FULL PRIVILEGES'

#INSTALANDO MÓDULO AZURE AD CONNECT


Install-Module -Name MSOnline

cls

Connect-MsolService

cls

$dominio = Read-Host "Digite O nome do dominio trial criado? 

(Ex: Com dominio 'domainname.onmicrosoft.com' colocar apenas 'domainname' )"

#ADICIONANDO USUÃRIOS
#Setando display name do Admin
 
cls

Set-MsolUser -UserPrincipalName admin@$dominio.onmicrosoft.com -DisplayName "MOD Administrator" -FirstName "MOD" -LastName "Administrator"

New-MsolUser -UserPrincipalName AlexW@$dominio.onmicrosoft.com -DisplayName "Alex Wilber" -FirstName "Alex" -LastName "Wilber" -Password 'Pa55w.rd' -ForceChangePassword $false -UsageLocation US
New-MsolUser -City Waukesha -Country "US" -Department IT -DisplayName "Allan Deyoung" -FirstName Allan -LastName Deyoung -Password Pa55w.rd -State WI -UserPrincipalName AllanD@$dominio.onmicrosoft.com -UserType Member -UsageLocation US -ForceChangePassword $false
New-MsolUser -City Birmingham -Country "US" -Department HR -DisplayName "Diego Siciliani" -FirstName Diego -LastName Siciliani -Password Pa55w.rd -State AL -UserPrincipalName DiegoS@$dominio.onmicrosoft.com -UserType Member -UsageLocation US -ForceChangePassword $false
New-MsolUser -City Tulsa -Country "US" -Department Sales -DisplayName "Isaiah Langer" -FirstName Isaiah -LastName Langer -Password Pa55w.rd -State OK -UserPrincipalName IsaiahL@$dominio.onmicrosoft.com -UserType Member -UsageLocation US -ForceChangePassword $false
New-MsolUser -City Charlotte -Country "US" -Department Legal -DisplayName "Joni Sherman" -FirstName Joni -LastName Sherman -Password Pa55w.rd -State NC -UserPrincipalName JoniS@$dominio.onmicrosoft.com -UserType Member -UsageLocation US -ForceChangePassword $false
New-MsolUser -City Tulsa -Country "US" -Department Retail -DisplayName "Lynne Robbins" -FirstName Lynne -LastName Robbins -Password Pa55w.rd -State OK -UserPrincipalName LynneR@$dominio.onmicrosoft.com -UserType Member -UsageLocation US -ForceChangePassword $false
New-MsolUser -City Pittsburgh -Country "US" -Department Marketing -DisplayName "Nestor Wilke" -FirstName Nestor -LastName Wilke -Password Pa55w.rd -State WA -UserPrincipalName NestorW@$dominio.onmicrosoft.com -UserType Member -UsageLocation US -ForceChangePassword $false
New-MsolUser -City Seattle -Country "US" -Department Operations -DisplayName "Megan Bowen" -FirstName Megan -LastName Bowen -Password Pa55w.rd -State PA -UserPrincipalName MeganB@$dominio.onmicrosoft.com -UserType Member -UsageLocation US -ForceChangePassword $false
New-MsolUser -City Louisville -Department "Executive Management" -DisplayName "Patti Fernandez" -FirstName Patti -LastName Fernandez -Password Pa55w.rd -State KY -UserPrincipalName PattiF@$dominio.onmicrosoft.com -UserType Member -UsageLocation US -ForceChangePassword $false


Start-Sleep -Seconds 1

cls

'LICENSING PROCESS STARTED . . .'

#LICENCIAMENTO DOS USUÁRIOS - O365 E5 E ENTERPRISE MOBILITY E5
#TODOS USUÁRIOS E ADMIN

Set-MsolUserLicense -UserPrincipalName admin@$dominio.onmicrosoft.com -AddLicenses $dominio":ENTERPRISEPREMIUM"
Set-MsolUserLicense -UserPrincipalName admin@$dominio.onmicrosoft.com -AddLicenses $dominio":EMSPREMIUM"

Get-MsolUser -All -UnlicensedUsersOnly | Set-MsolUserLicense -AddLicenses $dominio":ENTERPRISEPREMIUM", $dominio":EMSPREMIUM"



cls
'FULL LICENSE PROCESS!
    
    PLEASE WAIT FOR THE RESULTS . . .'
Start-Sleep -Seconds 2
cls

Get-MsolAccountSku

Start-Sleep -Seconds 3
pause
cls
exit