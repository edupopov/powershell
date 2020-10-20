#################################################
#             Configura a ETH                   #
#################################################

$NIC = "GERENCIA"
$IP_ADDR = "10.210.35.22"
$GW = "10.210.35.1"
$CDIR = "24"
$DNS = ("10.210.35.5","")

netsh interface show interface
Get-NetAdapter | where status -eq Up | Rename-NetAdapter -NewName $NIC
Disable-NetAdapterBinding -InterfaceAlias $NIC -ComponentID ms_tcpip6
New-NetIPAddress –IPAddress $IP_ADDR -DefaultGateway $GW -PrefixLength $CDIR -InterfaceIndex (Get-NetAdapter).InterfaceIndex
Set-DNSClientServerAddress –InterfaceIndex (Get-NetAdapter).InterfaceIndex –ServerAddresses $DNS

REG ADD  "HKLM\Software\policies\Microsoft\Windows NT\DNSClient"
REG ADD  "HKLM\Software\policies\Microsoft\Windows NT\DNSClient" /v " EnableMulticast" /t REG_DWORD /d "0" /f

# OldConfig
# netsh interface ipv4 set address name="GERENCIA" static 172.19.76.7 255.255.255.0 172.19.76.1
# netsh interface ipv4 set dns name="GERENCIA" static 8.8.8.8 

# Habilitar o TOv2 IPsec
# Enable-NetAdapterIPsecOffload $NIC
