cls
Write-Host
Write-Host "Revertendo Snapshots. Aguarde..."
Write-Host

Get-VM | Get-VMSnapshot | Restore-VMSnapshot -Confirm:$false -Verbose
