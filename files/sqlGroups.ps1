Param(
[string]$runAsUser,
[string]$runAsPassword,
[string]$SqlServerName,
[string]$SecondarySqlServerName
)

$sysFQDN = [System.Net.Dns]::GetHostByName(($env:computerName)) | FL HostName | Out-String | %{ "{0}" -f $_.Split(':')[1].Trim() }
$sqlServer = $env:computername
$user = $usersToAdd

$password = $runAsPassword | ConvertTo-SecureString -asPlainText -Force
$username = $runAsUser 
$credential = New-Object System.Management.Automation.PSCredential($username,$password)

Invoke-Command -ComputerName $SqlServerName -Credential $credential  {
    Param(
        [string]$runAsUser,
        [string]$runAsPassword,
        [string]$SqlServerName,
        [string]$SecondarySqlServerName
    )

    $password = $runAsPassword | ConvertTo-SecureString -asPlainText -Force
    $username = $runAsUser 
    $credential = New-Object System.Management.Automation.PSCredential($username,$password)

    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null
     
    $svr = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $SqlServerName
    $PrivReportingGroup = $svr.Logins | where {$_.Name -match "PrivReportingGroup"} | Select-Object -ExpandProperty Name
    $ReportingGroup = $svr.Logins | where {$_.Name -match "ReportingGroup"} | where {$_.Name -notmatch "PrivReportingGroup"} | Select-Object -ExpandProperty Name
    if($ReportingGroup -eq $null){
        $ReportingGroup = $PrivReportingGroup.Replace('PrivReportingGroup','ReportingGroup')
        Function Add-WindowsAccountToSQLRole ([String]$Server, [String] $User){
         
            [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null
            $Svr = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $server                    
            if(-not($svr.Logins.Contains($User))){
                $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login $Server, $User
                $SqlUser.LoginType = 'WindowsUser'
                $SqlUser.Create()
                $LoginName = $SQLUser.Name
            }
         
        }
        Add-WindowsAccountToSQLRole $SqlServerName $ReportingGroup
    }
    $SQLAccessGroup = $svr.Logins | where {$_.Name -match "SQLAccessGroup"} | Select-Object -ExpandProperty Name

    Invoke-Command -ComputerName $SecondarySqlServerName -Credential $credential  {
        Param(
            [string]$sqlserver,
            [string]$PrivReportingGroup,
            [string]$ReportingGroup,
            [string]$SQLAccessGroup
        )
         
        Function Add-WindowsAccountToSQLRole ([String]$Server, [String] $User){
         
            [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null
            $Svr = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $server                    
            if(-not($svr.Logins.Contains($User))){
                $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login $Server, $User
                $SqlUser.LoginType = 'WindowsUser'
                $SqlUser.Create()
                $LoginName = $SQLUser.Name
            }
         
        }

        Add-WindowsAccountToSQLRole $sqlServer $PrivReportingGroup
        Add-WindowsAccountToSQLRole $sqlServer $ReportingGroup
        Add-WindowsAccountToSQLRole $sqlServer $SQLAccessGroup
    } -ArgumentList @($SecondarySqlServerName,$PrivReportingGroup,$ReportingGroup,$SQLAccessGroup)

} -ArgumentList @($runAsUser,$runAsPassword,$SqlServerName,$SecondarySqlServerName)
