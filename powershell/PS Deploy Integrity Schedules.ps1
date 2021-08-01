$query = "
with integrity as (
	SELECT InstanceID FROM Perf_MonitoredServers WHERE IsActive = 1
	EXCEPT
	SELECT InstanceID FROM Maintenance_IntegritySchedule)

SELECT ServerName 
FROM Perf_MonitoredServers pms
INNER JOIN integrity ON integrity.InstanceID = pms.InstanceID
ORDER BY ServerName
"

#$servers = (Invoke-Sqlcmd -ServerInstance C1DBD536 -Database SQLMONITOR -Query $query).ServerName
$hr = 16
$time = 0

$servers = @()
$servers += "C1APP309"
$servers += "C1APP388"
$servers += "C1APP390"
$servers += "C1APP399"
$servers += "C1DBD007"
$servers += "C1DBD010"
$servers += "C1DBD017"
$servers += "C1DBD030"
$servers += "C1DBD031"
$servers += "C1DBD033"
$servers += "C1DBD034"
$servers += "C1DBD035"
$servers += "C1DBD036"
$servers += "C1DBD037"
$servers += "C1DBD038"
$servers += "C1DBD039"
$servers += "C1DBD041"
$servers += "C1DBD042"
$servers += "C1DBD043"
$servers += "C1DBD045"
$servers += "C1DBD048"
$servers += "C1DBD051"
$servers += "C1DBD052"
$servers += "C1DBD053"
$servers += "C1DBD054"
$servers += "C1DBD056"
$servers += "C1DBD061"
$servers += "C1DBD065"
$servers += "C1DBD066"
$servers += "C1DBD067"
$servers += "C1DBD068"
$servers += "C1DBD069"


foreach ($server in $servers)
{
    $sql = "EXEC msdb.dbo.sp_add_jobschedule @job_name='Maintenance - Integrity', @name=N'Sunday " + "{0:00}" -f $hr + "{0:00}" -f $time + "', 
		    @enabled=1, 
		    @freq_type=8, 
		    @freq_interval=64, 
		    @freq_subday_type=1, 
		    @freq_subday_interval=0, 
		    @freq_relative_interval=0, 
		    @freq_recurrence_factor=1, 
		    @active_start_date=20190607, 
		    @active_end_date=99991231, 
		    @active_start_time=" + "{0:00}" -f $hr + "{0:00}" -f $time + "00, 
		    @active_end_time=235959"

    $server + " - " + "{0:00}" -f $hr + "{0:00}" -f $time

    Invoke-Sqlcmd -ServerInstance $server -Database SQLADMIN -Query $sql
    $time += 10
    if ($time -ge 60)
    {
        $time = 0
        $hr += 1
        if ($hr -ge 18)
        {
            $hr = 16
        }
    }
}