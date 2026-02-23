# Salve um arquivo com os hosts em uma mesma coluna
# Use a extencao CSV
# Instale o nmap em seu equipamento e rode o script
# Feito por Eduardo Popovici
# Em 23/02/2026

$hosts = Get-Content .\hosts1.csv
$log = "resultado_nmap.log"
foreach ($h in $hosts) {
    Add-Content $log "##### Testando $h #####"
    nmap -sn $h | Out-String | Add-Content $log
    Add-Content $log ""
}
