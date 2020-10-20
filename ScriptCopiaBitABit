#################################################
#           Script de cópia bit a bit           #
#################################################

Import-Module BitsTransfer

$bitsjob = Start-BitsTransfer –source origem -destination destino -Asynchronous

while( ($bitsjob.JobState.ToString() -eq 'Transferring') -or ($bitsjob.JobState.ToString() -eq 'Connecting') )

{

Write-host $bitsjob.JobState.ToString()

$Proc = ($bitsjob.BytesTransferred / $bitsjob.BytesTotal) * 100

Write-Host $Proc "%”

Sleep 3

}

Complete-BitsTransfer -BitsJob $bitsjob

Write-Host "Transferência concluída. Pressione qualquer tecla para fechar a janela..."

$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
