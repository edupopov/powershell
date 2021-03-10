clear
$ipaddress=Get-Content -Path D:\Users\anaedua\Desktop\Transfer\Ip.txt

$results = @()

ForEach ($i in $ipaddress)
 {
  
$o=new-object psobject

$o | Add-Member -MemberType NoteProperty -Name hostname -Value ([System.Net.Dns]::GetHostByAddress($i).HostName)
$results +=$o
}

$results | Select-Object -Property hostname | Export-Csv D:\Users\anaedua\Desktop\Transfer\machinenames.csv
