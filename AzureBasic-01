#################################################
#                  Utilizando                   #
#################################################

# Logar no Azure via powershell 
Login-AzureRmAccount

# Lista as subscrições
Get-AzureRmSubscription

# Tenants (assinaturas) - Informa a Microsoft que você fará uso destes recursos dentro da assinatura. Deve ser feito apra novas assinaturas e novas contas.
Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.Network"
Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.Compute"
Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.Storage"

# Lista os grupos de recursos
Get-AzureRmResourceGroup

# Validação da localização para criação de grupos de recursos
Get-AzureRmLocation | select Location 

# Criação de grupo de recurso com o Powershell
New-AzureRmResourceGroup -ResourceGroupName "AZ-HTB-SPO-01" -Location "centralus"

# Listar as VNets
Get-AzureRmVirtualNetwork -ResourceGroupName AZ-HTB-SPO-01

# Criar Vnet 01
# /21 - 28.19.0.0- 28.19.7.255 (2048 endereços) - Vnet comunica 2048 endereços por vez
# /27 - 28.19.0.0- 28.19.0.31 (32 endereços) - Subnet com 32 endereços válidos
$subnet1 = New-AzureRmVirtualNetworkSubnetConfig -Name "SUBNET-HTB-SPO-01" -AddressPrefix 28.19.0.0/21
New-AzureRmVirtualNetwork -Name "SUBNET-HTB-SPO-AA" -ResourceGroupName "AZ-HTB-SPO-01" -Location "centralus" -AddressPrefix 28.19.0.0/27 -Subnet $subnet1

# Criar Vnet 02
# /21 - 28.19.8.0- 28.19.15.255 (2048 endereços) - Vnet comunica 2048 endereços por vez
# /27 - 28.19.8.0- 28.19.8.31 (32 endereços) - Subnet com 32 endereços válidos
$subnet1 = New-AzureRmVirtualNetworkSubnetConfig -Name "SUBNET-HTB-SPO-02" -AddressPrefix 28.19.8.0/21
New-AzureRmVirtualNetwork -Name "SUBNET-HTB-SPO-AB" -ResourceGroupName "AZ-HTB-SPO-01" -Location "centralus" -AddressPrefix 28.19.0.0/27 -Subnet $subnet1
