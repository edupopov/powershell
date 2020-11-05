# O netstat exibe as conexões TCP ativas, portas nas quais o computador está ouvindo, estatísticas de Ethernet, tabela de roteamento IP, 
# estatísticas IPv4 (para os protocolos IP, ICMP, TCP e UDP) e estatísticas IPv6 (para os protocolos IPv6, ICMPv6, TCP over IPv6 e UDP sobre 
# protocolos IPv6). Para replicar essa funcionalidade no powershell temos o comando Get-NetTCPConnection, 
# que retorna um resultado semelhante, mas em forma de objetos.

Get-NetTCPConnection -State Listen

# Para filtrar mais ainda o resultado, podemos utilizar o parâmetro -LocalPort e enumerar as portas que desejamos 
# filtrar no resultado, caso não localize a porta, ela não será incluida no resultado:

Get-NetTCPConnection -State Listen -LocalPort 22,135,445,443
