$query = "
CREATE PROC usp_IntegrityCheck
AS
	DECLARE @db varchar(512);
	DECLARE alldb CURSOR STATIC FORWARD_ONLY READ_ONLY
	FOR
	SELECT name FROM sys.databases WHERE name <> 'tempdb' ORDER BY name;

	OPEN alldb
	FETCH NEXT FROM alldb INTO @db;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		DBCC CHECKDB (@db) WITH NO_INFOMSGS;
	END;

	CLOSE alldb;
	DEALLOCATE alldb;
GO

USE [msdb]
GO

IF EXISTS (SELECT name FROM sysjobs WHERE name = 'Maintenance - Integrity')
	EXEC msdb.dbo.sp_delete_job @job_name=N'Maintenance - Integrity';

EXEC msdb.dbo.sp_add_job @job_name=N'Maintenance - Integrity', 
		@owner_login_name=N'CCsaid';

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Maintenance - Integrity', @step_name=N'Run Integrity', 
		@step_id=1, 
		@on_success_action=3, 
		@on_fail_action=2, 
		@subsystem=N'TSQL', 
		@command=N'usp_IntegrityCheck', 
		@database_name=N'SQLADMIN';

EXEC msdb.dbo.sp_add_jobserver @job_name=N'Maintenance - Integrity', @server_name = N'(local)';

"
$servers = (Invoke-Sqlcmd -ServerInstance C1DBD536 -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName

foreach ($server in $servers)
{
    $server
    Invoke-Sqlcmd -ServerInstance $server -Database SQLADMIN -Query $query
}




$servers = @()
$servers += "C1DBD536"
$servers += "C1DBD500"
$servers += "C1DBD403"
$servers += "C1DBD409"
$servers += "C1DBD407"
$servers += "C1DBD411"
$servers += "C1DBD420"
$servers += "C1DBD510"
$servers += "C1DBD511"
$servers += "C1DBD507"
$servers += "C1DBD504"
$servers += "C1DBD513"
$servers += "C1DBD421"
$servers += "C1DBD422"
$servers += "C1DBD430"
$servers += "C1DBD502"
$servers += "C1DBD514"
$servers += "C1DBD516"
$servers += "C1DBD521"
$servers += "C1DBD522"
$servers += "C1DBD525"
foreach ($server in $servers)
{
    Invoke-Sqlcmd -ServerInstance $server -Database master -Query "DROP PROC usp_IntegrityCheck"
   
}