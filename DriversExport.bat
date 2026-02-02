@echo off
setlocal enabledelayedexpansion

REM Script criado para exporar drivers de um equipamento antes da formatação
REM Script Criado por Eduardo Popovici
REM Scrip verifica se existe uma pasta chamada DriversBKP
REM Se não houver, ele cria e lá exporta os drivers do equipamento

REM === Caminho do backup ===
set BACKUP_DIR=C:\DriversBKP

echo.
echo [*] Verificando pasta de destino: %BACKUP_DIR%

REM === Cria a pasta se não existir ===
if not exist "%BACKUP_DIR%" (
    echo [*] Pasta nao existe. Criando...
    mkdir "%BACKUP_DIR%"
    if errorlevel 1 (
        echo [ERRO] Falha ao criar a pasta "%BACKUP_DIR%". Execute como Administrador.
        exit /b 1
    )
) else (
    echo [*] Pasta ja existe. Prosseguindo...
)

echo.
echo [*] Exportando drivers com DISM...
dism /online /export-driver /destination:"%BACKUP_DIR%"
if errorlevel 1 (
    echo [ERRO] O DISM encontrou um erro ao exportar os drivers.
    echo     - Verifique se o prompt foi aberto como Administrador.
    echo     - Verifique espaco em disco.
    exit /b 1
)

echo.
echo [OK] Exportacao concluida com sucesso em: %BACKUP_DIR%
endlocal
