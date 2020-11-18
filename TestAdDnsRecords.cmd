# Salvar como TestAdDnsRecords.cmd
# Executar como TestAdDnsRecords.cmd | more

@setlocal
@REM Test AD DNS domains for presence.
@REM For details see: http://serverfault.com/a/811622/253701

nslookup -type=srv _kerberos._tcp.%userdnsdomain%.
nslookup -type=srv _kerberos._udp.%userdnsdomain%.
@echo .

nslookup -type=srv _kpasswd._tcp.%userdnsdomain%.
nslookup -type=srv _kpasswd._udp.%userdnsdomain%.
@echo .

nslookup -type=srv _ldap._tcp.%userdnsdomain%.
@echo .

nslookup -type=srv _ldap._tcp.dc._msdcs.%userdnsdomain%.
@echo .

nslookup -type=srv _ldap._tcp.pdc._msdcs.%userdnsdomain%.
@echo .

@REM Those next few lines here are forest specific:
@REM Change the next line your current domain is not also the forest root.
@SET "DNSFORESTNAME=%USERDNSDOMAIN%"

nslookup -type=srv _ldap._tcp.gc._msdcs.%DNSFORESTNAME%.
@echo .

nslookup -type=srv _gc._tcp.%DNSFORESTNAME%.
