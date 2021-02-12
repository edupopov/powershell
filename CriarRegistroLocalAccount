# Cria o registro LocalAccountTokenFilterPolicy se não existir e o habilita
If ($LocalAccountTokenFilterPolicy -like $null){​​
New-ItemProperty -Path $registro -Name $nome -Value $valor -PropertyType DWORD -Force}​​
If ($LocalAccountTokenFilterPolicy.LocalAccountTokenFilterPolicy -eq 0){​​
Set-ItemProperty -Path $registro -Name $nome -Value $valor -Force}​​
