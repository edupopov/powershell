#################################################
#                 060 PXE DHCP                  #
#################################################

C:\WINDOWS\system32>netsh
netsh>dhcp
netsh dhcp>server \\<server_machine_name>
netsh dhcp>add optiondef 60 PXEClient String 0 comment=PXE support
netsh dhcp>set optionvalue 60 STRING PXEClient
netsh dhcp>exit
