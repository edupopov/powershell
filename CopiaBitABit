#################################################
#                Cópia bit a bit                #
#################################################

Import-Module BitsTransfer
# Transferência de arquivos síncrona
Start-BitsTransfer –source origem -destination destino
# Transferência de arquivos assíncrona
Start-BitsTransfer –source origem -destination destino -asynchronous
Get-BitsTransfer | Complete-BitsTransfer
# Transferência com autenticação de usuário
Start-BitsTransfer –source origem -destination destino -Authentication NTLM -Credential Get-Credential
# Definir a prioridade da transferência
Start-BitsTransfer –source origem -destination destino -Priority low
# Verificar o status da transferência
Get-BitsTransfer | select DisplayName, BytesTotal, BytesTransferred, JobState | Format-Table -AutoSize
