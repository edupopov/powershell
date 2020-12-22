Get-Command #Lista de comandos
Get-Command -CommandType Cmdlet #traga na tela os commandlets
$PSVersionTable.PSVersion #mostra a versão do powershell
(Get-host).Version #Permite ver a versão do powershell também em um host remoto
Write-host "Hello World" #Escreve algo na tela
Get-ChildItem # corresponde ao dir e ao ls - lista pastas
Get-ChildItem c:\ # apontando aqui a unidade que deve ser listada
update-help # atualiza o help dp Windows pela internet
get-help Write-Host -Examples # Mostra exemplos do write-host pelo help
get-help Write-Host -Online #mostra o help detalhado do Write-host - online 
get-help Write-Host -ShowWindow #Abre o help do comando em uma janela apartada
Get-Date -Format g # Imprime a data na tela em um formato específico
Get-Command -CommandType Cmdlet | more # Lista os comandlets em formato pausado - more
Get-Command -CommandType Cmdlet *eventlog* | more # Lista os comandlets que possuem o termo "eventlog"
Get-Command -CommandType Function | more # Lista as funções
Get-Childitem Function:\Clear-Host # Mostra se o clear-host é um comandlet ou uma função
Get-ChildItem Function:\Clear-Host | type # Mostra o que tem dentro do arquivo Clear-Host
Get-Alias # mostra os apelidos de cada comando 
set-alias limpar clear-host # cria o Alias para limpar a tela com base no clear-host
gps # mostra os processos em execução
PS C:\WINDOWS\system32> Get-Process | ConvertTo-Html | Out-File "processos.html" # - Gera uma lista de processos em um artquivo html
Get-Date # mostra a data
Notepad processos.html # Abre o arquivo no notepad
update help >> erro.log # Gera a saída do erro de comando em um log de texto
Get-Process | ConvertTo-Html | Out-File "processos.html" # Mostra a lista de processos em um grid visual
get-service | where-object {$_.status -eq "Running"} #Mostra quais serviços estão rodando 
get-service | where-object {$_.status -like "*security*"} #Faz a busca com o serviço buscando uma palavra específica com variações antes e depois
get-module -ListAvailable | more # Lista os módulos
Get-Command -Module SmbShare # Lista os parametros do SmbShare
Get-Command -Module Defender # Lista os parametros para o Windows Defender # A extensão dos módulos do powershell é .psm1
Get-PSRepository # Mostra os repositórios
Install-Module -Name Az.Accounts -Force # Força a isntação do módulo pelo repositório PSGallery
Install-Module -Name AWSPowerShell -Force #Instala o módulo de manutenção da AWS
Select-String
Get-Content # Permite ler o conteúdo de um arquivo de texto
Get-Content .\bancos.txt | Select-String ITAU # Procura dentro de um arquivo de texto a string ITAU
Get-Content .\bancos.txt | Select-String ITAU, BRADESCO, SANTANDER # Ao adicionar virgula após a string ITAU, posso buscar outras strings específicas 
Select-String -Pattern Santo .\Municipios.txt # Procura uma string específica sob um padrão único dentro do arquivo municipios.txt
Get-ChildItem .\*.txt # Encontra tudo o que for arquivo .txt
Select-String -Path "senha.txt" -Pathern guest # Procura dentro de um arquivo de senhas a string guest
Select-String -Path "senha.txt" -Pathern Administrator -NotMatch # Esta linha trará tudo o que não estiver relacioando a sring Administrador
Enable-PSRemoting # Libera acesso remoto para o servidor ou estação de trabalho
Get-HotFix # Mostra os hotfix instalados
Get-HotFix -id KB4343898 # Mostra se esse KB esta instalado 
Invoke-Command -ComputerName SRV-02 -ScriptBlock {Get-HotFix -id KB434389} # Esta linha de comando identifica se a máquina remotamente, possui o KB instalado
Enter-PSSession SRV-02 # Estabelece uma sessão remota persistente
Get-Host # Trás insformações do host conectado
