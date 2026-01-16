# Script Básico - Variáveis 01
Clear-Host
$nome = Read-Host "Qual é o seu nome" # O Read-Host permite o input de dados 
$Saudacao = "Olá"
$frase = "$Saudacao, $nome"
write-host "$frase"

# Não é necessári o write-host. Se você adicionar apenas o $frase no final, será apresentado a frase.

$frase.Length # O lenght mostra a quantidade de caracteres coletados
$frase.ToUpper() # Deixa o texto em letras maiusculas

# Fim