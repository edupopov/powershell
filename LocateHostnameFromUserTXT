# d:\Users\anaedua\Desktop\Transfer\usuarios.txt
# Get-ADComputer -Filter * -Properties ipv4Address, OperatingSystem | Format-List Name, ipv4*, oper* > c:\users\robertwe\desktop\computers.txt
# Get-ADComputer -Filter * -Properties ipv4Address, OperatingSystem | select Name, ipv4Address, OperatingSystem | out-file c:\users\robertwe\desktop\computers.txt -Append

$computers = Get-Content d:\Users\anaedua\Desktop\Transfer\usuarios2.txt

foreach ($computer in $computers) {
     $wmi = Get-WmiObject -ComputerName $computer -Class win32_computersystem
     $output = [ordered]@{
          Host = $computer
          User = $wmi.username
     }
     $report = New-Object -TypeName PSObject -Property $output
     Write-Output $report
}
