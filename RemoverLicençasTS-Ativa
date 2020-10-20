#################################################
#         Remover licença de TS ativa           #
#################################################

Get-WmiObject Win32_TSLicenseKeyPack
wmic /namespace:\\root\CIMV2 PATH Win32_TSLicenseKeyPack CALL UninstallLicenseKeyPackWithId 5
