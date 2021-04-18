# Array01
Clear-Host
$GoogleDNS = @("8.8.8.8", "8.8.4.4") # Informo a quantidade de itens, neste caso dois endereços IP
$TotalDNS = $GoogleDNS.Count # Faz a contagem de itens dentro do Array
Write-Host Pingando todos os $TotalDNS endereços de DNS do Google # Mostra uma frase inicial de apoio
Test-Connection $GoogleDNS -Count 1 # Faz o Ping nos endereços disponíveis do Array
Sleep 3 # Entrega uma pausa de 03 segundos antes da finalização do script
Write-Host Ping finalizado com sucesso! # Adiciona uma frase de finalização