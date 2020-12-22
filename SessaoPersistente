#SessãoPerssitente
Clear-Host

#variaveis
$nameserver = Read-Host "Entre com o nome do Servidor"
$s = New-PSSession -Name $nameserver

Invoke-Command -Session $s -ScriptBlock{

$i = 0
while($true)
{
$i++
Write-Host "Contando até $i"
Sleep 1
If ($i -ge 1000) {break}
}
} -AsJob -JobName LongoTrabalho

# Comados rápidos [use a tecla F8 para executar a linha]
Get-Command *PSSession
