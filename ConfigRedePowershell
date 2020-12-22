# Alterando configurações de rede cabeada 

# Declaração de variáveis
$nic = Get-NetIPConfiguration # adiciona as informações de configuração a uma variável
$DigiteIP = Read-Host "Digite o endereço IP que deseja atribuir"
$DigiteDNS = Read-Host "Digite o endereço de DNS primario que deseja atribuir"
$GW1 = Read-Host "Digite o endereço de gateway que desenha atribuir"

# Execução de configuração para IP fixo
New-NetIPAddress $DigiteIP -InterfaceAlias Ethernet -DefaultGateway $GW1 -AddressFamily IPV4 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses $DigiteDNS

# Configuração por DHCP
Set-NetIPInterface -InterfaceAlias Ethernet -Dhcp -Enable
Set-DnsClientServerAddress -InterfaceAlias Ethernet -ResetServerAddresses

#Adicionar maquina no domínio
Add-Computer -ComputerName Client02 -DomainName "dominio.local"
