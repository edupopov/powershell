#################################################
#        Configura auditoria de pastas          #
#################################################

$folders = "E:\"
$User = "Everyone"
$Rules = "Delete,DeleteSubdirectoriesAndFiles,ChangePermissions"
$InheritType = "ContainerInherit,ObjectInherit"
$AuditType = "Success"
$hostn = hostname
foreach($folder in $folders)
{
    try
    {
        $ACL = $folder | Get-Acl -Audit -ErrorAction Stop

        $AccessRule = New-Object System.Security.AccessControl.FileSystemAuditRule($user,$Rules,$InheritType,"None",$AuditType)
        $ACL.SetAuditRule($AccessRule)
        $ACL | Set-Acl $Folder -ErrorAction Stop
        write-host "Setting Audit Rules on $folder"
    }
    catch
    {
        Write-Error -ErrorRecord $_
    }
}
