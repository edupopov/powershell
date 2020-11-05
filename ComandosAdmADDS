# Exibir todos os comandos do Active Directory:
get-command -Module ActiveDirectory
 
# Exibir informações básicas de domínio: 
Get-ADDomain 

# Obter todos os controladores de domínio por nome de host e operação
Get-ADDomainController -filter * | select hostname, operatingsystem 

# Obter todas as políticas de senha refinadas
Get-ADFineGrainedPasswordPolicy -filter * 

# Listar a política de senha do domínio conectado
Get-ADDefaultDomainPasswordPolicy 

# Backup remoto do estado do sistema do Active Directory
# Isso fará o backup dos dados de estado do sistema dos controladores de domínio. 
# Altere o nome do DC para o nome do servidor e altere o caminho do backup. 
# O caminho do backup pode ser um disco local ou um caminho UNC
invoke-command -ComputerName DC-Name -scriptblock {wbadmin start systemstateback up -backupTarget:"Backup-Path" -quiet}
 
# Comandos do PowerShell de usuário do AD
# Obter usuário e listar todas as propriedades (atributos)
# Alterar nome de usuário para samAccountName da conta
Get-ADUser username -Properties *
 
# Obter propriedades específicas do usuário e da lista
# Basta adicionar o que você deseja exibir após selecionar
Get-ADUser username -Properties * | Select name, department, title
 
# Obter todos os usuários do Active Directory no domínio
Get-ADUser -Filter *
 
# Obter todos os usuários de uma UO específica
# OU = o caminho distinto da OU
Get-ADUser -SearchBase “OU=ADPRO Users,dc=ad,dc=activedirectorypro.com” -Filter *
 
# Obter usuários do AD por nome
# Este comando encontrará todos os usuários que têm a palavra robert no nome. Basta alterar robert para a palavra que você deseja pesquisar.
get-Aduser -Filter {name -like "*robert*"}
 
# Obter todas as contas de usuário desabilitadas
Search-ADAccount -AccountDisabled | select name

# Desativar conta de usuário
Disable-ADAccount -Identity rallen

# Ativar conta de usuário
Enable-ADAccount -Identity rallen
 
# Obter todas as contas com senha definida para nunca expirar
get-aduser -filter * -properties Name, PasswordNeverExpires | where {$_.passwordNeverExpires -eq "true" } | Select-Object DistinguishedName,Name,Enabled

# Localizar todas as contas de usuário bloqueadas
Search-ADAccount -LockedOut

# Desbloquear conta de usuário
Unlock-ADAccount –Identity john.smith
 
# Listar todas as contas de usuário desativadas
Search-ADAccount -AccountDisabled

# Forçar alteração de senha no próximo login
Set-ADUser -Identity username -ChangePasswordAtLogon $true

# Mover um único usuário para uma nova UO
# Você precisará do distinguishedName do usuário e da UO de destino
Move-ADObject -Identity "CN=Test User (0001),OU=ADPRO Users,DC=ad,DC=activedirectorypro,DC=com" -TargetPath "OU=HR,OU=ADPRO Users,DC=ad,DC=activedirectorypro,DC=com"

# Mover usuários para uma UO de um CSV
# Configure um csv com um campo de nome e uma lista dos usuários sAmAccountNames. Em seguida, basta alterar o caminho da UO de destino.
# Specify target OU. $TargetOU = "OU=HR,OU=ADPRO Users,DC=ad,DC=activedirectorypro,DC=com" # Read user sAMAccountNames from csv file (field labeled "Name"). Import-Csv -Path Users.csv | ForEach-Object { # Retrieve DN of User. $UserDN = (Get-ADUser -Identity $_.Name).distinguishedName # Move user to target OU. Move-ADObject -Identity $UserDN -TargetPath $TargetOU }

# Comandos de grupo do AD
# Obter todos os membros de um grupo de segurança
Get-ADGroupMember -identity “HR Full”

# Obter todos os grupos de segurança
# Isso listará todos os grupos de segurança em um domínio
Get-ADGroup -filter *
 
# Adicionar usuário ao grupo
# Altere o nome do grupo para o grupo do AD ao qual você deseja adicionar usuários
Add-ADGroupMember -Identity group-name -Members Sser1, user2
 
# Exportar usuários de um grupo
# Isso exportará os membros do grupo para um CSV, alterará o nome do grupo para o grupo que você deseja exportar.
Get-ADGroupMember -identity “Group-name” | select name | Export-csv -path C:OutputGroupmembers.csv -NoTypeInformation

# Obter grupo por palavra-chave
# Encontre um grupo por palavra-chave. Útil se você não tiver certeza do nome, altere o nome do grupo.
get-adgroup -filter * | Where-Object {$_.name -like "*group-name*"}

# Importar uma lista de usuários para um grupo
$members = Import-CSV c:itadd-to-group.csv | Select-Object -ExpandProperty samaccountname Add-ADGroupMember -Identity hr-n-drive-rw -Members $members
 
# Comandos do computador AD
# Obter todos os computadores
# Isso listará todos os computadores no domínio
Get-AdComputer -filter *

# Obter todos os computadores por nome
# Isso listará todos os computadores no domínio e exibirá apenas o nome do host
Get-ADComputer -filter * | select name
 
# Obter todos os computadores de uma UO
Get-ADComputer -SearchBase "OU=DN" -Filter *
 
# Obter uma contagem de todos os computadores no domínio
Get-ADComputer -filter * | measure

# Obtenha todos os computadores com Windows 10
# Altere o Windows 10 para qualquer sistema operacional que você deseja pesquisar. Este é um dos principais comandos PowerShell para Active Directory
Get-ADComputer -filter {OperatingSystem -Like '*Windows 10*'} -property * | select name, operatingsystem

# Obter uma contagem de todos os computadores por sistema operacional
# Isso fornecerá uma contagem de todos os computadores e os agrupará pelo sistema operacional. Um ótimo comando para fornecer um inventário rápido de computadores no AD.
Get-ADComputer -Filter "name -like '*'" -Properties operatingSystem | group -Property operatingSystem | Select Name,Count
 
# Excluir um único computador
Remove-ADComputer -Identity "USER04-SRV4"
 
# Excluir uma lista de contas de computador
# Adicione os nomes de host a um arquivo de texto e execute o comando abaixo.
Get-Content -Path C:ComputerList.txt | Remove-ADComputer

# Excluir computadores de uma UO
Get-ADComputer -SearchBase "OU=DN" -Filter * | Remote-ADComputer

# Seção Política de Grupo
# Obter todos os comandos relacionados ao GPO
get-command -Module grouppolicy

# Obter todos os GPOs por status
get-GPO -all | select DisplayName, gpostatus
 
# Faça backup de todos os GPOs no domínio
Backup-Gpo -All -Path E:GPObackup
