Get-Process -Name chrome -ErrorAction SilentlyContinue | Stop-Process -PassThru 

Remove-Item "C:\Windows\temp\Chrome"  -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue

$MSItoUninstallName = 'Google Chrome'
New-PSDrive -Name Hkey_Classes_Root -PSProvider Registry -Root Hkey_Classes_Root\Installer\Products | Out-Null
$a = Get-ChildItem Hkey_Classes_Root: | ForEach-Object {Get-ItemProperty $_.Pspath}
foreach($name in $a){
if($name.ProductName -like $MSItoUninstallName){

$EndingPath = $name.Pspath | Split-Path -leaf
Set-Location HKey_Classes_Root:
#Write-Host "Erasing HKey_Classes_Root:\$endingPath"
Remove-Item -Path "HKey_Classes_Root:\$endingPath" -Recurse -Force
Get-PSDrive | Remove-PSDrive -Force
}
}

$chrome64 = "C:\Program Files\Google"
$chrome32 = "C:\Program Files (x86)\Google"
If ($chrome64){Remove-Item $chrome64 -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue}
if ($chrome32){Remove-Item $chrome32 -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue}


$CCMComObject = New-Object -ComObject 'UIResource.UIResourceMgr
$CacheInfo = $CCMComObject.GetCacheInfo().GetCacheElements()
ForEach ($CacheItem in $CacheInfo) {

$null = $CCMComObject.GetCacheInfo().DeleteCacheElement([string]$($CacheItem.CacheElementID))}
