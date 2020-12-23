$ReportFile = "C:\Temp\ADSiteInfo.CSV"
Remove-item $ReportFile -ErrorAction SilentlyContinue
$ThisString="AD Site,Location,Site Option,Current ISTG,Subnets,Servers,In Site Links,Bridgehead Servers"
Add-Content "$ReportFile" $ThisString

$CurForestName = "NetWrix.com"
$a = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext("Forest", $CurForestName)
[array]$ADSites=[System.DirectoryServices.ActiveDirectory.Forest]::GetForest($a).sites
$ADSites
ForEach ($Site in $ADSites)
{
    $SiteName = $Site.Name
    $SiteLocation = $site.Location
    $SiteOption = $Site.Options
    $SiteISTG = $Site.InterSiteTopologyGenerator

    [array] $SiteServers = $Site.Servers.Count
    [array] $SiteSubnets = $Site.Subnets.Count
    [array] $SiteLinks = $Site.SiteLinks.Count
    [array] $SiteBH = $Site.BridgeheadServers.Count

    $FinalVal=$SiteName+","+'"'+$SiteLocation+'"'+","+'"'+$SiteOptions+'"'+","+$SiteISTG+","+$SiteSubnets+","+$SiteServers+","+$SiteLinks+","+$SiteBH
    Add-Content "$ReportFile" $FinalVal          
}
