# Script Básico - Variáveis 01
Clear-Host
$nome = Read-Host "Qual é o seu nome" # O Read-Host permite o input de dados 
$Saudacao = "Olá"
$frase = "$Saudacao, $nome"
write-host "$frase"
$senha1 = Read-Host "Entre com uma senha" -AsSecureString # O -AsSecureString permite a digitação oculta e restrita
$senha2 = Read-Host "Entre novamente com sua senha" -MaskInput # O -MaskInput permite entrada em texto plano sem restrições
# Fim