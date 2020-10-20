#################################################
#        Localizar usuário e estação            #
#################################################

Invoke-Command -ComputerName NomeDoServerAD {

#cls

Write-Host Coletando informações ...

#usuário de rede que sera localizado

$user = "eduardo.popovici"

#quantos logins irá retornar

$QntddLogs = 3
$Data = (get-date).date
#$Data = (get-date).AddHours(-3)
#$Data = "24/05/2019"

Get-winevent -FilterHashtable @{logname='security'; id=4624; starttime=$Data; Level=0 } –MaxEvents 50000000 | Where-Object {$_.Message -match "Account Name:\s+$user"} | Select TimeCreated, @{n='User';e={$_.Properties[5].Value }},@{n="Maquina";e={$_.properties[11].value}},@{n="IP";e={$_.properties[18].value}} -First $QntddLogs | ft -AutoSize}
