REM Este script foi criaro para importar drivers para dentro da pasta C:\Windows\System32\DriverStore
REM A Microsoft exige o uso de ferramentas como pnputil ou dism, que validam e registram os drivers corretamente.
REM Script criado por Eduardo Popovici
REM /add-driver → adiciona o driver ao Driver Store
REM C:\DriversBKP\*.inf → aponta para os arquivos .inf
REM /subdirs → percorre todas as subpastas
REM /install → já tenta instalar o driver no dispositivo compatível

pnputil /add-driver C:\DriversBKP\*.inf /subdirs /install
