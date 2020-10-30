###############################################################
# CONFIGURAR VÁRIOS IPs EM UMA MESMA NIC POR LINHA DE COMANDO #
###############################################################

FOR /L %A IN (1,1,10) DO netsh interface ipv4 add address "Ethernet" 192.168.%A.7 255.255.255.0

# Use o FOR para essa atividade
# %A - Deve substituir a parte do endereço que será acrescido
# (1,1,10) - Aqui estou dizendo que o primeiro endereço começa em 1, indo de 1 em 1 até 10
# Este script atribui os endereços 192.168.1.7 até 192.168.10.7 - note que adicionei endereços de final 7 nas sub-redes 1 até 10
