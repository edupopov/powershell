#################################################
#       Reset de senha Admin via invoke         #
#################################################

Invoke-Command -ScriptBlock {net user administrator "Password01"} -ComputerName (Get-ADComputer -SearchBase "OU=test,OU=servers,DC=lab,DC=com" -Filter * | Select-Object -Expand Name)
