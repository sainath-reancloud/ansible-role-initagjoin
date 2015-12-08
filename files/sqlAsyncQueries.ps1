Param(
    [string]$runAsUser,
    [string]$runAsPassword,
    [string]$SqlServerName
)

$password = $runAsPassword | ConvertTo-SecureString -asPlainText -Force
$username = $runAsUser 
$credential = New-Object System.Management.Automation.PSCredential($username,$password) 

Invoke-Command -ComputerName $SqlServerName -Credential $credential {Param($SqlServerName)
    $query1 = "IF NOT EXISTS (SELECT * FROM sys.asymmetric_keys WHERE name = 'MSCRMSqlClrKey') BEGIN CREATE ASYMMETRIC KEY MSCRMSqlClrKey FROM EXECUTABLE FILE = '\\Crmdeploy\c$\Program Files\Microsoft Dynamics CRM\tools\Microsoft.Crm.SqlClr.Helper.dll'; END"
    $query2 = "IF NOT EXISTS (SELECT * FROM sys.syslogins WHERE name = 'MSCRMSqlClrLogin') BEGIN CREATE LOGIN MSCRMSqlClrLogin FROM ASYMMETRIC KEY MSCRMSqlClrKey GRANT UNSAFE ASSEMBLY TO MSCRMSqlClrLogin END"
    Invoke-Sqlcmd -HostName $SqlServerName -Database master -Query $query1
    Invoke-Sqlcmd -HostName $SqlServerName -Database master -Query $query2
} -Args $SqlServerName
