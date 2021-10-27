# Define input parameters
$cred = Get-credential

Write-host "Obtendo lista de servidores de $computer"

#Read file
$computers = get-content "D:\Scripts\servers.txt
foreach (#computer in $computers) {

  # Connect to WMI
  $wmi = get-wmiobject -class "Win32_OperatingSystem" `
    -Credential $cred -namespace "root\cimv2" -computer $computer
  
  # Restart Computer
  foreach ($item in $wmi) {
    $wmi.reboot()
    write-host "Reiniciando o servidor $computer"
    }
   }
