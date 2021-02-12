# Cria o registro AutoShareWks se não existir e o habilita
If ($AutoShareWks -like $null){​​
New-ItemProperty -Path $registro -Name $nome -Value $valor -PropertyType DWORD -Force}​​
If ($AutoShareWks.AutoSharewks -eq 0){​​
Set-ItemProperty -Path $registro -Name $nome -Value $valor -Force}​​
