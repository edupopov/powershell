<#
.SYNOPSIS
    Instala (aplica) um papel de parede de Tela de Bloqueio copiando a imagem localmente
    e configurando chaves do Personalization CSP no Registro.

.DESCRIPTION
    - Cria a estrutura de pastas (se necessário)
    - Copia a imagem do diretório do pacote para o destino local
    - Configura chaves em HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP
    - Gera log detalhado para troubleshooting

.NOTES
    Recomendado executar como SYSTEM (Intune Win32).
    A imagem deve estar no mesmo diretório do script (pacote .intunewin).

    Como usar no seu pacote Win32 (do jeito que você já padronizou)

Coloque esse Install-LockScreenWallpaper.ps1 junto com:

Install-LockScreenWallpaper.bat
LockScreen-Wallpaper-Default.jpg
demais arquivos do pacote

E no Install-LockScreenWallpaper.bat, deixe algo assim (padrão simples):
@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File ".\Install-LockScreenWallpaper.ps1"
exit /b %errorlevel%

Dica prática (iniciante): onde olhar o log
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\LockScreenWallpaper-Install.log

#>

#region ====== CONFIGURAÇÕES (PERSONALIZE AQUI) ======

# Nome do arquivo de imagem presente no pacote Win32
$ImageFileName = "LockScreen-Wallpaper-Default.jpg"

# Pasta de destino no dispositivo (onde a imagem será armazenada)
$DestinationFolder = "C:\ProgramData\Company\LockScreen"

# Nome final da imagem no destino (pode manter igual ao original)
$DestinationFileName = $ImageFileName

# Diretório de logs
$LogFolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile   = Join-Path $LogFolder "LockScreenWallpaper-Install.log"

#endregion

#region ====== FUNÇÕES ======

function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("INFO","SUCCESS","WARN","ERROR")][string]$Level = "INFO"
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$timestamp][$Level] $Message"

    # Console (útil em execução manual)
    Write-Output $line

    # Arquivo
    if (!(Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    }
    Add-Content -Path $LogFile -Value $line
}

function Ensure-Folder {
    param([Parameter(Mandatory=$true)][string]$Path)

    if (!(Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        Write-Log "Criado diretório: $Path" "SUCCESS"
    } else {
        Write-Log "Diretório já existe: $Path" "INFO"
    }
}

#endregion

#region ====== EXECUÇÃO ======

try {
    Write-Log "==== Início da instalação do Lock Screen Wallpaper ====" "INFO"

    # Descobre o diretório do script (onde está o arquivo de imagem no pacote)
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    Write-Log "Diretório do pacote/script: $ScriptRoot" "INFO"

    # Caminhos completos
    $SourceImagePath      = Join-Path $ScriptRoot $ImageFileName
    $DestinationImagePath = Join-Path $DestinationFolder $DestinationFileName

    Write-Log "Imagem (origem): $SourceImagePath" "INFO"
    Write-Log "Imagem (destino): $DestinationImagePath" "INFO"

    # Valida existência da imagem no pacote
    if (!(Test-Path $SourceImagePath)) {
        throw "Arquivo de imagem não encontrado no pacote: $SourceImagePath"
    }

    # Garante pasta de destino
    Ensure-Folder -Path $DestinationFolder

    # (Opcional) limpeza de imagens antigas no destino (mantém apenas a atual)
    # Se quiser manter histórico, comente esse bloco.
    Get-ChildItem -Path $DestinationFolder -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne $DestinationFileName } |
        ForEach-Object {
            try {
                Remove-Item $_.FullName -Force -ErrorAction Stop
                Write-Log "Removido arquivo antigo: $($_.FullName)" "INFO"
            } catch {
                Write-Log "Falha ao remover arquivo antigo: $($_.FullName) | $($_.Exception.Message)" "WARN"
            }
        }

    # Copia a nova imagem para o destino
    Copy-Item -Path $SourceImagePath -Destination $DestinationImagePath -Force
    Write-Log "Imagem copiada com sucesso para: $DestinationImagePath" "SUCCESS"

    # Configura as chaves do Personalization CSP
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"

    if (!(Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
        Write-Log "Chave de registro criada: $RegPath" "SUCCESS"
    } else {
        Write-Log "Chave de registro já existe: $RegPath" "INFO"
    }

    # Algumas implantações usam LockScreenImagePath, outras LockScreenImageUrl.
    # Setamos ambas para maximizar compatibilidade (caminho local).
    New-ItemProperty -Path $RegPath -Name "LockScreenImagePath"   -Value $DestinationImagePath -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $RegPath -Name "LockScreenImageUrl"    -Value $DestinationImagePath -PropertyType String -Force | Out-Null

    # Status = 1 geralmente indica aplicado/ativo no contexto CSP (usado também em troubleshooting)
    New-ItemProperty -Path $RegPath -Name "LockScreenImageStatus" -Value 1 -PropertyType DWord  -Force | Out-Null

    Write-Log "Registro atualizado: LockScreenImagePath/Url/Status" "SUCCESS"

    # Validação rápida (log)
    $p = (Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue)
    Write-Log "Validação (Registro): Path=$($p.LockScreenImagePath) | Url=$($p.LockScreenImageUrl) | Status=$($p.LockScreenImageStatus)" "INFO"

    Write-Log "==== Fim da instalação do Lock Screen Wallpaper (OK) ====" "SUCCESS"
    exit 0
}
catch {
    Write-Log "ERRO: $($_.Exception.Message)" "ERROR"
    Write-Log "==== Fim da instalação do Lock Screen Wallpaper (FALHA) ====" "ERROR"
    exit 1
}

#endregion
