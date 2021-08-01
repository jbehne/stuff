$Global:repository = $args[0]

$query = "
IF EXISTS (
	SELECT * 
	FROM sysjobactivity ja
	INNER JOIN sysjobs j ON j.job_id = ja.job_id
	WHERE name LIKE 'Maintenance - Indexing'
	AND DATEDIFF(HOUR, start_execution_date, GETDATE()) > 4
	AND stop_execution_date IS NULL)
BEGIN
	EXEC sp_stop_job @job_name = 'Maintenance - Indexing'
END;

IF EXISTS (
	SELECT * 
	FROM sysjobactivity ja
	INNER JOIN sysjobs j ON j.job_id = ja.job_id
	WHERE name LIKE 'Maintenance - Integrity'
	AND DATEDIFF(HOUR, start_execution_date, GETDATE()) > 4
	AND stop_execution_date IS NULL)
BEGIN
	EXEC sp_stop_job @job_name = 'Maintenance - Integrity'
END;"

$servers = (Invoke-Sqlcmd -ServerInstance $Global:repository -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName

foreach ($server in $servers)
{
    Invoke-Sqlcmd -ServerInstance $server -Database msdb -Query $query
}