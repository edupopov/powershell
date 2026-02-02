REM Scrip Criado pelo Eduardo Popovici
REM /add-driver → adiciona o driver ao Driver Store
REM C:\DriversBKP\*.inf → aponta para os arquivos .inf
REM /subdirs → percorre todas as subpastas
REM /install → já tenta instalar o driver no dispositivo compatível
REM Onde os drivers ficam depois - C:\Windows\System32\DriverStore\FileRepository
REM Nunca copie arquivos manualmente para essa pasta - Isso pode corromper o Driver Store e causar erros de inicialização
REM Restaurar drivers após formatação - pnputil /add-driver
REM Instalar drivers automaticamente - pnputil /add-driver /install
REM Imagem offline / WIM - dism /add-driver

pnputil /add-driver C:\DriversBKP\*.inf /subdirs /install
