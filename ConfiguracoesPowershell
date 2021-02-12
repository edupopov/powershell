# Verifica se admin$ está liberado
$admin = Test-Path "\\$env:COMPUTERNAME\admin$"
$c = Test-Path "\\$env:COMPUTERNAME\C$"
If($admin -like "False" -or $c -like "False"){​​



# Verifica LocalAccountTokenFilterPolicy no Registro do Windows
$registro = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\system"
$nome = "LocalAccountTokenFilterPolicy"
$valor = "1"



$LocalAccountTokenFilterPolicy = Get-ItemProperty -Path $registro -Name $nome -ErrorAction SilentlyContinue



# Cria o registro LocalAccountTokenFilterPolicy se não existir e o habilita
If ($LocalAccountTokenFilterPolicy -like $null){​​
New-ItemProperty -Path $registro -Name $nome -Value $valor -PropertyType DWORD -Force}​​
If ($LocalAccountTokenFilterPolicy.LocalAccountTokenFilterPolicy -eq 0){​​
Set-ItemProperty -Path $registro -Name $nome -Value $valor -Force}​​



# Verifica AutoShareWks no Registro do Windows
$registro = "HKLM:\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters"
$nome = "AutoShareWks"
$valor = "1"
$AutoShareWks = Get-ItemProperty -Path $registro -Name $nome -ErrorAction SilentlyContinue



# Cria o registro AutoShareWks se não existir e o habilita
If ($AutoShareWks -like $null){​​
New-ItemProperty -Path $registro -Name $nome -Value $valor -PropertyType DWORD -Force}​​
If ($AutoShareWks.AutoSharewks -eq 0){​​
Set-ItemProperty -Path $registro -Name $nome -Value $valor -Force}​​



# Reinicia o serviço para liberar os shares administrativos
Restart-Service Server -Force -Confirm:$True
}​​
