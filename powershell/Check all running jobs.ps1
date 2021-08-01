$cmd = "SELECT @@servername server,
    j.name AS job_name,
    ja.start_execution_date,      
    ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id
FROM msdb.dbo.sysjobactivity ja 
LEFT JOIN msdb.dbo.sysjobhistory jh 
    ON ja.job_history_id = jh.instance_id
JOIN msdb.dbo.sysjobs j 
ON ja.job_id = j.job_id
JOIN msdb.dbo.sysjobsteps js
    ON ja.job_id = js.job_id
    AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
AND start_execution_date is not null
AND stop_execution_date is null;"

$servers = (Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "SELECT * FROM vw_AllMonitoredServers WHERE IsActive = 1").ServerName

foreach ($server in $servers)
{
    Invoke-Sqlcmd -ServerInstance $server -Query $cmd
}