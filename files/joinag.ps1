Param(
    [string]$runAsUser,
    [string]$runAsPassword,
    [string]$SharePath,
    [string]$sqlDBName,
    [string]$SqlServerName,
    [string]$SecondarySqlServerName,
    [string]$DCServerName,
    [string]$AgName,
    [string]$AgListener
)

$ErrorActionPreference = "Stop"

$password = $runAsPassword | ConvertTo-SecureString -asPlainText -Force
$username = $runAsUser 
$credential = New-Object System.Management.Automation.PSCredential($username,$password)           

$dbname = $sqlDBName
$SharePath = "\\" + $SharePath + "\"
$DatabaseBackupFile = $SharePath + $dbname + "_BK.bak"
$LogBackupFile = $SharePath + $dbName + "_BK.trn"


#Change Recovery mode to Full of new DB and back up database
Invoke-Command -ComputerName $SqlServerName -Credential $credential {param($SqlServerName,$dbname,$DatabaseBackupFile,$LogBackupFile)
   [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null
   $srv = new-object ('Microsoft.SqlServer.Management.Smo.Server') $SqlServerName
   $db = $srv.Databases.Item($dbname)
   $db.RecoveryModel = 'Full'
   $db.Alter()

   #Back up to share
   Backup-SqlDatabase -Database $dbname -BackupFile $DatabaseBackupFile -ServerInstance $SqlServerName
   Backup-SqlDatabase -Database $dbname -BackupFile $LogBackupFile -ServerInstance $SqlServerName -BackupAction 'Log'

} -Args $SqlServerName,$dbname,$DatabaseBackupFile,$LogBackupFile

#Restore DB to secondary SQL server
Invoke-Command -ComputerName $SecondarySqlServerName -Credential $credential {param($dbname,$DatabaseBackupFile,$LogBackupFile,$SecondarySqlServerName)
   Restore-SqlDatabase -Database $dbname -BackupFile $DatabaseBackupFile -ServerInstance $SecondarySqlServerName -NoRecovery
   Restore-SqlDatabase -Database $dbname -BackupFile $LogBackupFile -ServerInstance $SecondarySqlServerName -RestoreAction 'Log' -NoRecovery
} -Args $dbname,$DatabaseBackupFile,$LogBackupFile,$SecondarySqlServerName

# Now enable AG on primary SQL
Invoke-Command -ComputerName $SqlServerName -Credential $credential {param($SqlServerName,$dbname,$AgName)
   $MyAgPrimaryPath = "SQLSERVER:\SQL\" + $SqlServerName + "\DEFAULT\AvailabilityGroups\" + $AgName
   Add-SqlAvailabilityDatabase -Path $MyAgPrimaryPath -Database $dbname
} -Args $SqlServerName,$dbname,$AgName

# Finally enable AG on secondary SQL
Invoke-Command -ComputerName $SecondarySqlServerName -Credential $credential {param($SecondarySqlServerName,$dbname,$AgName)
   $MyAgSecondaryPath =  "SQLSERVER:\SQL\" + $SecondarySqlServerName + "\DEFAULT\AvailabilityGroups\" + $AgName
   Add-SqlAvailabilityDatabase -Path $MyAgSecondaryPath -Database $dbname
} -Args $SecondarySqlServerName,$dbname,$AgName

# Cleanup the Backup files on share
Invoke-Command -ComputerName $DCServerName -Credential $credential {param($DatabaseBackupFile,$LogBackupFile)
    $origPath = pwd
    Set-Location -Path HKCU:\
    if(Test-Path "filesystem::$DatabaseBackupFile")    {
       Remove-Item "filesystem::$DatabaseBackupFile"
    }
    else    {
       Write-Host "Path $DatabaseBackupFile does not exist"
    }
    if(Test-Path "filesystem::$LogBackupFile")    {
       Remove-Item "filesystem::$LogBackupFile"
    }
    else    {
       Write-Host "Path $LogBackupFile does not exist"
    }
    Set-Location -Path $origPath
} -Args $DatabaseBackupFile,$LogBackupFile

