$query = "

"

$servers = (Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName
$servers += (Invoke-Sqlcmd -ServerInstance C1DBD536 -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName

foreach ($server in $servers)
{
    $server
    Invoke-Sqlcmd -ServerInstance $server -Database SQLADMIN -Query $query
}