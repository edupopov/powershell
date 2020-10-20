##########################################################
#                                                        #
# Script de criação de ambiente de laboratório - HTBRAZ  #
# Criador: Eduardo Popovici                              #
#                                                        #
##########################################################

# Obs. Os scripts de Powershell são bloqueados por padrão no Windows use o comando Set-ExecutionPolicy Unrestricted para desbloquear antes de executar este script
# Set-ExecutionPolicy Unrestricted

#Importar módulo Hyper-V
Import-Module Hyper-V

# Variaveis
# $vm = "NEWVMNAME"
# $SMBShare = "CSV share name"
$CPU1 = 1
$CPU2 = 2
$MEM1 = 1GB
$MEM2 = 2GB
$VlanID1 = 20
$VlanID2 = 30
$VMHD1 = 120GB
$VMHD2 = 80GB
$VMHD3 = 200GB
$Wifi = Get-NetAdapter -Name Wi-Fi
$eth0 = Get-NetAdapter -Name Ethernet

# Listar os comandos do Hyper-V pelo Powershell - Se sentir dúvidas com os comandos, verifique-os com o Get-Command
# Get-Command –Module Hyper-V

# Criar Virtual Switch
# New-VMSwitch -Name INTERNET -NetAdapterName $ethernet.Name -AllowManagementOS $true -Notes 'Acesso real, internet e rede LAN usando o cabo'
# New-VMSwitch -Name INTERNET -NetAdapterName $wifi.Name -AllowManagementOS $true -Notes 'Acesso real, internet e rede LAN usando o wifi'
New-VMSwitch -Name HTB01 -SwitchType Private -Notes 'Interno, uso das máquinas do ambiente 01'
New-VMSwitch -Name CLUSTER -SwitchType Private -Notes 'Interno, uso das máquinas do cluster'
New-VMSwitch -Name RELCONF -SwitchType Private -Notes 'Por este Switch montaremos a relação de confiança entre domínios'
New-VMSwitch -Name VPN -SwitchType Private -Notes 'Por este switch vamos montar as conexões de VPN do ambiente'
New-VMSwitch -Name SBRUBLES01 -SwitchType Private -Notes 'Interno, uso das máquinas do ambiente 02'

# Cria diretório VM-LAB
mkdir c:\VM-LAB
# Cria diretório de imagens
mkdir c:\VM-LAB\ISO
# Criar diretório de discos de Dados
mkdir c:\VM-LAB\Dados

################################################
#                                              #
#         Ambiente 01 - MCSA S/A               #
#                                              #
################################################

# AD primário mcsa.local

New-VM –Name SRV01-MCSA -Generation 2 –MemoryStartupBytes $MEM2 -NewVHDPath c:\VM-LAB\SRV01-MCSA.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMDvdDrive -VMName SRV01-MCSA
Add-VMNetworkAdapter -VMName SRV01-MCSA
New-VHD -Path c:\VM-LAB\Dados\DADOS01.vhdx -SizeBytes $VMHD2
Add-VMHardDiskDrive -VMName SRV01-MCSA -path c:\VM-LAB\Dados\DADOS01.vhdx
New-VHD -Path c:\VM-LAB\Dados\DADOS02.vhdx -SizeBytes $VMHD2 
Add-VMHardDiskDrive -VMName SRV01-MCSA -path c:\VM-LAB\Dados\DADOS02.vhdx
New-VHD -Path c:\VM-LAB\Dados\DADOS03.vhdx -SizeBytes $VMHD2 
Add-VMHardDiskDrive -VMName SRV01-MCSA -path c:\VM-LAB\Dados\DADOS03.vhdx
New-VHD -Path c:\VM-LAB\Dados\DADOS04.vhdx -SizeBytes $VMHD2 
Add-VMHardDiskDrive -VMName SRV01-MCSA -path c:\VM-LAB\Dados\DADOS04.vhdx

# AD réplica mcsa.local

New-VM –Name SRV02-MCSA -Generation 2 –MemoryStartupBytes $MEM2 -NewVHDPath c:\VM-LAB\SRV02-MCSA.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMDvdDrive -VMName SRV02-MCSA
Add-VMNetworkAdapter -VMName SRV02-MCSA
New-VHD -Path c:\VM-LAB\Dados\DADOS05.vhdx -SizeBytes $VMHD2 
Add-VMHardDiskDrive -VMName SRV02-MCSA -path c:\VM-LAB\Dados\DADOS05.vhdx
New-VHD -Path c:\VM-LAB\Dados\DADOS06.vhdx -SizeBytes $VMHD2 
Add-VMHardDiskDrive -VMName SRV02-MCSA -path c:\VM-LAB\Dados\DADOS06.vhdx

# Criação das estações clientes de MCSA

New-VM –Name CLI01-MCSA -Generation 2 –MemoryStartupBytes $MEM1 -NewVHDPath c:\VM-LAB\CLIB01.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMDvdDrive -VMName CLI01-MCSA

New-VM –Name CLI02-MCSA -Generation 2 –MemoryStartupBytes $MEM1 -NewVHDPath c:\VM-LAB\CLIB02.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMDvdDrive -VMName CLI02-MCSA

New-VM –Name CLI03-MCSA -Generation 2 –MemoryStartupBytes $MEM1 -NewVHDPath c:\VM-LAB\CLIB03.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMDvdDrive -VMName CLI03-MCSA

# AD filho - sucursal colatina | colatina.mcsa.local

New-VM –Name SRV03-COLATINA -Generation 2 –MemoryStartupBytes $MEM2 -NewVHDPath c:\VM-LAB\SRV03-COLATINA.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMNetworkAdapter -VMName SRV03-COLATINA
Add-VMDvdDrive -VMName SRV03-COLATINA

# RODC filial | colatina.mcsa.local

New-VM –Name SRV04-COLATINA -Generation 2 –MemoryStartupBytes $MEM2 -NewVHDPath c:\VM-LAB\SRV04-COLATINA.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMNetworkAdapter -VMName SRV04-COLATINA
Add-VMDvdDrive -VMName SRV04-COLATINA

################################################
#                                              #
#         Ambiente 02 - Sbrubles S/A           #
#                                              #
################################################

# AD primário | sbrubles.local

New-VM –Name SRV05-SBRUBLES -Generation 2 –MemoryStartupBytes $MEM2 -NewVHDPath c:\VM-LAB\SRV05-SBRUBLES.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMDvdDrive -VMName SRV05-SBRUBLES
Add-VMNetworkAdapter -VMName SRV05-SBRUBLES

# Ambiente geral

New-VM –Name SRV06-SBRUBLES -Generation 2 –MemoryStartupBytes $MEM2 -NewVHDPath c:\VM-LAB\SRV06-SBRUBLES.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMDvdDrive -VMName SRV06-SBRUBLES
Add-VMNetworkAdapter -VMName SRV06-SBRUBLES

New-VM –Name SRV07-SBRUBLES -Generation 2 –MemoryStartupBytes $MEM2 -NewVHDPath c:\VM-LAB\SRV07-SBRUBLES.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMDvdDrive -VMName SRV07-SBRUBLES
Add-VMNetworkAdapter -VMName SRV07-SBRUBLES

# Ambiente em Cluster

New-VM –Name SRV08-SBRUBLES-CLUSTE -Generation 2 –MemoryStartupBytes $MEM2 -NewVHDPath c:\VM-LAB\SRV08-SBRUBLES-CLUSTER.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU2 -exposevirtualizationextensions $true
Add-VMDvdDrive -VMName SRV08-SBRUBLES-CLUSTER
Add-VMNetworkAdapter -VMName SRV08-SBRUBLES-CLUSTER | set-vmnetworkadapter -vmname SRV08-SBRUBLES-CLUSTER -name "network adapter" -macaddressspoofing on

New-VM –Name SRV09-SBRUBLES-CLUSTER -Generation 2 –MemoryStartupBytes $MEM2 -NewVHDPath c:\VM-LAB\SRV09-SBRUBLES-CLUSTER.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU2 -exposevirtualizationextensions $true
Add-VMDvdDrive -VMName SRV09-SBRUBLES-CLUSTER
Add-VMNetworkAdapter -VMName SRV09-SBRUBLES-CLUSTER | set-vmnetworkadapter -vmname SRV09-SBRUBLES-CLUSTER -name "network adapter" -macaddressspoofing on

# Criação das estações clientes de SBRUBLES

New-VM –Name CLI01-SBRUBLES -Generation 2 –MemoryStartupBytes $MEM1 -NewVHDPath c:\VM-LAB\CLI01-SBRUBLES.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMDvdDrive -VMName CLIB01-SBRUBLES

New-VM –Name CLI02-SBRUBLES -Generation 2 –MemoryStartupBytes $MEM1 -NewVHDPath c:\VM-LAB\CLI02-SBRUBLES.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMDvdDrive -VMName CLI02-SBRUBLES

New-VM –Name CLI03-SBRUBLES -Generation 2 –MemoryStartupBytes $MEM1 -NewVHDPath c:\VM-LAB\CLI03-SBRUBLES.vhdx -NewVHDSizeBytes $VMHD1 | Set-VMMemory -DynamicMemoryEnabled $false | Set-VMProcessor -count $CPU1
Add-VMDvdDrive -VMName CLI03-SBRUBLES
