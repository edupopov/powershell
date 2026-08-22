# Test com a Hashtable
Clear-Host
$servidores = [ordered] @{Gateway="192.168.17.1";ChromecastSala="192.168.17.10";MiLite="192.168.17.13";AsusTeck="192.168.17.15"} # Ordena pela ordem dos endereços IP
# $servidores["iPhonedPopovici"]="192.168.17.92" # Esta linha adiciona um item a hashtable - Cuidado com o espaço entre a variável e o nome do servidor
$servidores
# Caso queira remover um item da hashtable use o parámetro .remove("nome do servidor")
$TotalServidores = $servidores.Count
Write-Host Total de $TotalServidores endereços de Servidor # Mostra uma frase inicial de apoio
# $servidores.Values
Test-Connection $servidores.Values # Faz o Ping nos endereços disponíveis do Array
# Sleep 3 # Entrega uma pausa de 03 segundos antes da finalização do script
# Write-Host Ping finalizado! # Adiciona uma frase de finalização
# Importante! Este script utiliza a relação de DNS disponível. Pode ocorrer o erro de Este host ão é conhecido