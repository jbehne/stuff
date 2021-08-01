$servers = (Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName
#$servers += (Invoke-Sqlcmd -ServerInstance C1DBD536 -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName
$certs = @()

foreach($server in $servers)
{

    $server
    $certs += Invoke-Command -ComputerName $server -ScriptBlock { Get-ChildItem "Cert:\LocalMachine\My" } | Select-Object PSComputerName, NotBefore, NotAfter, Thumbprint, SerialNumber, Issuer, Subject

}


$certs | Write-SqlTableData -ServerInstance C1DBD069 -Database SQLMONITOR -TableName Server_Certificates -SchemaName dbo

<#
Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "CREATE TABLE Server_Certificates (PSComputerName varchar(512), NotBefore datetime, NotAfter datetime, Thumbprint varchar(128), SerialNumber varchar(128), Issuer varchar(128), Subject varchar(256))"
Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "DROP TABLE Server_Certificates"



Invoke-Command -ComputerName C1DBD052 -ScriptBlock { Get-ChildItem "Cert:\LocalMachine\My" } | Select *
#>

