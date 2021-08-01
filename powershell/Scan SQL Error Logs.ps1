

$servers = (Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName

foreach ($s in $servers)
{
    $query = "EXEC xp_readerrorlog 0, 1, N'Logon', N'', '20190109 12:00:00', '20190110 10:32:00', 'ASC' "
    $s | Out-Host
    "***********************************************************************************" | Out-Host
    Invoke-Sqlcmd -ServerInstance $s -Query $query
    "***********************************************************************************" | Out-Host
}


<#
C1DBD061
C1DBD034
#>