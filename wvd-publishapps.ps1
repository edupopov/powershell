<#PSScriptInfo
.VERSION 1.0.1
.GUID 46c6e63c-4d14-48f3-a479-8056222b6c28
.AUTHOR jason.byway@microsoft.com
.COMPANYNAME Microsoft Australia
.COPYRIGHT 
.TAGS 
.LICENSEURI 
.PROJECTURI 
.ICONURI 
.EXTERNALMODULEDEPENDENCIES Microsoft.RDInfra.RDPowershell
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>

<# 

.DESCRIPTION 
 Connect to Windows Virtual Desktop Service, list all RemoteApp App Groups and then allow admin to publish RemoteApps from selection 

#> 

function wvd-publishapps {
    Param(
            [Parameter(Mandatory = $false, ValueFromPipeline=$false, HelpMessage ="Enter your Tenant Name")]
            [ValidateNotNullorEmpty()]
            [string] $TenantName,
 
            [Parameter(Mandatory = $false, ValueFromPipeline=$false, HelpMessage ="Enter your Host Pool")]
            [ValidateNotNullorEmpty()]
            [string] $HostPool,

            [Parameter(Mandatory = $false, ValueFromPipeline=$false, HelpMessage ="Enter your App Group Name")]
            [ValidateNotNullorEmpty()]
            [string] $AppGroupName,
 
            [Parameter(Mandatory = $false, ValueFromPipeline=$false)]
            [string] $DeploymentURL = "https://rdbroker.wvd.microsoft.com") #default WVD Broker Service

    Try 
        {
            #Check if user is already connected to WVD Service and catch error if not
            Write-Host "Please wait - checking for connection to WVD Service" -ForegroundColor Gray
            $RDSContext = Get-RdsContext -ErrorAction Stop
            Write-Host "WVD Context Found - Continuing" -ForegroundColor Gray

        }
    
    Catch  
        
        {
            #Connect to WVD Service as user is not already connected
            Write-Warning "You are not currently connected to the WVD Service - attempting to login...."
    
            
            #Connect to WVD Service
            Add-RdsAccount -DeploymentUrl $DeploymentURL | out-host
            Write-host "[SUCCESS] Logged into your WVD Service" -ForegroundColor Green | out-host
        
        }

    # Check if Host Pool Information has been passed through and if not then enumerate RemoteApp Resource Types they have permission to access
    If(!$TenantName -or !$HostPool -or !$AppGroupName)
        {
          $apppools = @()
          $tenant = Get-RdsTenant
          Write-Host "Obtaining list of RemoteApp AppGroups across your tenants. Please wait." -ForegroundColor Gray | out-host
          Foreach ($i in $tenant)
            {
                $hosts = Get-RdsHostPool -TenantName $i.TenantName
                    
                Foreach ($j in $hosts)
                    {
                        $apppools += Get-RdsAppGroup -TenantName $j.Tenantname -HostPoolName $j.HostPoolName 
 
                    }
       
            }
          $apppools = $apppools | Where-Object {$_.ResourceType -like 'RemoteApp'} | Out-GridView -Title "Please choose your AppGroup..." -OutputMode Single 
          $apppools
          
          If(!$apppools)
            {
              NoSelectionHandling  
            }
          Else 
            {
                #Define parameter variables to continue script
                $TenantName = $apppools.TenantName
                $AppGroupName = $apppools.AppGroupName
                $HostPool = $apppools.HostPoolName
                Write-Host "$AppGroupName on $HostPool selected. Obtaining list of published apps - please wait." -ForegroundColor Gray
            }
        }
    
    # List apps published to the AppGroup
    $apps = get-rdsstartmenuapp -TenantName $TenantName -HostPoolName $HostPool -AppGroupName $AppGroupName
    
    # Send output to array for cleaner grid view
    $publish = foreach ($item in $Apps)
        {
            $item | select FriendlyName, FilePath, CommandLineArguments, AppAlias, IconPath, IconIndex
        }

    #Output to a grid-view - multiple values accepted
    $publish = $publish | Out-GridView -Title "Select App to publish" -OutputMode Multiple

    # If apps not selected write an error and prompt user for input
    If (!$publish)
        {
            NoSelectionHandling
        }

    Else 
        {
            Write-Host "You have chosen to publish the following applications:"
            $publish | ft FriendlyName, FilePath -AutoSize

            #Confirm if you want to proceed
            Write-Host -nonewline "Do you want to proceed? (Y/N): "
            $Response = Read-Host
            Write-Host " "

            # If not Y then end script

            If ($Response -ne "Y")
                {
                    Write-Host -ForegroundColor Green "[COMPLETE] Ending Script"
                    Break
               
                }

            Else 
                {
                    #Publish the Remote App to the App Group  
                    $GetError = @()
                    $newapp = foreach ($i in $publish)
                        {

                            $publish = New-RdsRemoteApp -TenantName $TenantName -HostPoolName $HostPool -AppGroupName $AppGroupName -Name $i.AppAlias -FilePath $i.FilePath -FriendlyName $i.FriendlyName -IconIndex $i.IconIndex -IconPath $i.IconPath -ErrorAction SilentlyContinue -ErrorVariable GetError | out-host -ErrorAction SilentlyContinue
                                
                           
                            If($GetError) 
                                {
                                    
                                   Write-Host "Whoops! The script continued however the following app failed to publish." -ForegroundColor DarkYellow
                                   Write-host -NoNewline "$GetError" -ForegroundColor DarkYellow 
                                   Write-host " "
                                }
                            
                            Else
                                {
                                Write-Host " "
                                }
                        $GetError = ""
                        
                        }
                   Write-Host "Successfully Completed." -ForegroundColor Green     
                }
        }
}

function NoSelectionHandling {
            Write-Host -NoNewline "You have not made a selection. Would you like to try restart? (Y/N): " -ForegroundColor Red
            $Response = Read-Host
        
                If ($Response -ne "Y")
                    {
                        Write-Host "Exiting. Goodbye."
                        Break
                    }
                
                # Restart function with existing parameters if user chooses to try again
                Else {
                        wvd-publishapps #-TenantName $TenantName -HostPool $HostPool -AppGroupName $AppGroupName
                     }

}
