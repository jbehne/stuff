$servers = (Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName

foreach($server in $servers)
{
    $server

    if (Test-Path "\\$server\C$\Program Files\Microsoft SQL Server\MSRS*.MSSQLSERVER\Reporting Services\ReportServer\rsreportserver.config")
    {
        [xml]$doc = Get-Content "\\$server\C$\Program Files\Microsoft SQL Server\MSRS*.MSSQLSERVER\Reporting Services\ReportServer\rsreportserver.config"
        $doc.Configuration.URLReservations.Application[0].URLs.URL.UrlString
    }

}


