#############################################################################################
# Script para gerar arquivo RDP apontando para o servidor SRV-TS-01                         #
# Criado por Eduardo Popovici - Julho/2025                                                  #
#############################################################################################

# Caminho de destino do arquivo RDP (na área de trabalho pública, por exemplo)
$caminhoRDP = "C:\Users\Public\Desktop\Linkedin-Remoto.rdp"

# Conteúdo do arquivo RDP
$conteudoRDP = @"
screen mode id:i:2
use multimon:i:0
desktopwidth:i:1920
desktopheight:i:1080
session bpp:i:32
winposstr:s:0,3,0,0,800,600
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
username:s:
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:1
allow desktop composition:i:1
disable full window drag:i:0
disable menu anims:i:0
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:SRV-TS-01
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:1
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
use redirection server name:i:0
drivestoredirect:s:
domain:s:
"@

# Criar o arquivo RDP
$conteudoRDP | Out-File -Encoding ASCII -FilePath $caminhoRDP

Write-Host "Arquivo RDP criado com sucesso em: $caminhoRDP"
