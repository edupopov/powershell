@echo off

REM ==========================================================
REM Script: Enable-BitLocker-OSOnly.cmd
REM Autor : Criado por Eduardo Popovici
REM
REM Objetivo:
REM   - Habilitar BitLocker de forma totalmente transparente
REM   - Criptografar APENAS a unidade do sistema operacional (C:)
REM   - Criar protetores obrigatórios (TPM + Recovery Password)
REM   - Salvar a chave de recuperação em C:\DOT1X\
REM   - Nenhuma interação com o usuário
REM   - Ideal para uso em imagem / pós-imagem / Task Sequence
REM ==========================================================

REM Caminho do utilitário oficial do BitLocker
set MBD=%SystemRoot%\System32\manage-bde.exe

REM Diretório para salvar a chave de recuperação
set KEYDIR=C:\DOT1X

REM ==========================================================
REM 1) Garantir diretório de saída da chave
REM ==========================================================
REM Cria a pasta C:\DOT1X caso não exista
if not exist %KEYDIR% (
    mkdir %KEYDIR%
)

REM ==========================================================
REM 2) Criar protetor de BOOT (TPM)
REM ==========================================================
REM Para unidade do sistema operacional, o BitLocker só inicia
REM a criptografia se existir um protetor de inicialização.
REM O TPM permite desbloqueio automático sem PIN ou interação.
%MBD% -protectors -add C: -tpm

REM ==========================================================
REM 3) Criar protetor de RECUPERAÇÃO (Recovery Password)
REM ==========================================================
REM Este protetor é obrigatório para recuperação em caso de falha.
REM A saída do comando contém a senha de 48 dígitos, que é salva
REM em arquivo texto para guarda local ou posterior escrow.
%MBD% -protectors -add C: -rp > %KEYDIR%\BitLocker-Key.txt

REM ==========================================================
REM 4) Habilitar BitLocker no disco do sistema
REM ==========================================================
REM -usedspaceonly     -> criptografa apenas blocos usados (rápido)
REM -skiphardwaretest  -> evita prompt e permite execução automática
REM A criptografia inicia após o reboot.
%MBD% -on C: -usedspaceonly -skiphardwaretest

REM ==========================================================
REM 5) Reinicialização obrigatória
REM ==========================================================
REM O reboot é necessário para que o TPM arme a proteção
REM e o BitLocker inicie a criptografia do volume do SO.
shutdown -r -t 10

exit /b 0
