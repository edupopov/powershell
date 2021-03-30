#Alterando licenciamento Microsoft 365

Connect-MsolService

#### Verificar o nome da licença do Office 365
Get-MsolAccountSku

#### SKU de algumas licenças
OFFICE 365 ENTERPRISE E1 - STANDARDPACK
OFFICE 365 ENTERPRISE E3 - ENTERPRISEPACK
OFFICE 365 ENTERPRISE E5 - ENTERPRISEPREMIUM
OFFICE 365 ENTERPRISE E5 WITHOUT AUDIO CONFERENCING - ENTERPRISEPREMIUM_NOPSTNCONF

OFFICE 365 BUSINESS - O365_BUSINESS   ou    SMB_BUSINESS
OFFICE 365 BUSINESS ESSENTIALS - O365_BUSINESS_ESSENTIALS   ou   SMB_BUSINESS_ESSENTIALS
OFFICE 365 BUSINESS PREMIUM - O365_BUSINESS_PREMIUM    ou   SMB_BUSINESS_PREMIUM

EXCHANGE ONLINE (PLAN 1) - EXCHANGESTANDARD

MICROSOFT 365 BUSINESS - SPB
MICROSOFT 365 E3 - SPE_E3

AZURE ACTIVE DIRECTORY PREMIUM P1 - AAD_PREMIUM
AZURE ACTIVE DIRECTORY PREMIUM P2 - AAD_PREMIUM_P2


#### Exibir todos os usuários que possui a licença E3
Get-MsolUser -all | select Displayname, Licenses | Where-Object {$_.Licenses.AccountSkuID -eq "akitreinamentos:ENTERPRISEPACK" }

#### Exibir licença de único usuário
 Get-MsolUser -UserPrincipalName alex@akitreinamentos.online | fl DisplayName,Licenses

#### Trocar licença de um único usuário
Set-MsolUserLicense -UserPrincipalName “alex@akitreinamentos.online” –AddLicenses “akitreinamentos:ENTERPRISEPACK“ –RemoveLicenses “akitreinamentos:SMB_BUSINESS_ESSENTIALS“

#### Trocar licença para várias contas
Get-MsolUser -All | select Displayname, Licenses | Where-Object {$_.Licenses.AccountSkuID -eq "akitreinamentos:ENTERPRISEPACK"} | Set-MsolUserLicense –AddLicenses “akitreinamentos:ENTERPRISEPACK“ –RemoveLicenses “akitreinamentos:SMB_BUSINESS_ESSENTIALS“
