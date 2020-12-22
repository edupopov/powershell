# Renomear computador pelo powershell
$info = Get-WmiObject -Class Win32_computerSystem # Cria a variável que armazena informações da máquina por WMI
$info # Mostra as informações coletadas
$info.Rename("Cliente02") # Utiliza a infomração coletada e o parametro rename muda o nome da estação que deve estar em aspas duplas
# Agora é só reiniciar seu computador
# Lembrando que é possível mudar nomes de estações em volume
