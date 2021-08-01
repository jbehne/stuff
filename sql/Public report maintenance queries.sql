with servers as (
	SELECT DISTINCT ServerName
	FROM Perf_MonitoredServers pms
	INNER JOIN (
		SELECT SRVR_NM, DB_NM, APP_NM 
		FROM OPENQUERY (SERVINFO, 'SELECT * FROM CCDB2.MDB_DB_DATA WHERE DBMS = ''SQL''')) si
		ON si.SRVR_NM = pms.ServerName
	WHERE APP_NM = 'GENETEC')

SELECT bh.ServerName, DatabaseName, BackupStartDate, BackupEndDate, 
	CASE BackupType 
		WHEN 'L' THEN 'LOG'
		WHEN 'I' THEN 'DIFFERENTIAL'
		WHEN 'D' THEN 'FULL' END BackupType
FROM servers s
INNER JOIN vw_AllBackupHistory bh ON s.ServerName = bh.ServerName
WHERE BackupStartDate > GETDATE() - 1
AND DatabaseName NOT IN ('master', 'model', 'msdb', 'tempdb', 'SQLADMIN', 'ReportServer', 'ReportServerTempDB')
ORDER BY ServerName, DatabaseName, BackupStartDate
GO

with servers as (
	SELECT DISTINCT ServerName
	FROM vw_AllMonitoredServers pms
	INNER JOIN (
		SELECT SRVR_NM, DB_NM, APP_NM 
		FROM OPENQUERY (SERVINFO, 'SELECT * FROM CCDB2.MDB_DB_DATA WHERE DBMS = ''SQL''')) si
		ON si.SRVR_NM = pms.ServerName
	WHERE APP_NM = 'GENETEC')

SELECT s.ServerName, 'FULL', ScheduleType, Occurrence, Recurrence, Frequency 
FROM servers s
INNER JOIN vw_AllMaintenance_BackupSchedule_Full d ON d.ServerName = s.ServerName
UNION ALL
SELECT s.ServerName, 'DIFFERENTIAL', ScheduleType, Occurrence, Recurrence, Frequency 
FROM servers s
INNER JOIN vw_AllMaintenance_BackupSchedule_Diff d ON d.ServerName = s.ServerName
UNION ALL
SELECT s.ServerName, 'LOG', ScheduleType, Occurrence, Recurrence, Frequency 
FROM servers s
INNER JOIN vw_AllMaintenance_BackupSchedule_Log d ON d.ServerName = s.ServerName
ORDER BY s.ServerName
GO

with servers as (
	SELECT DISTINCT ServerName
	FROM Perf_MonitoredServers pms
	INNER JOIN (
		SELECT SRVR_NM, DB_NM, APP_NM 
		FROM OPENQUERY (SERVINFO, 'SELECT * FROM CCDB2.MDB_DB_DATA WHERE DBMS = ''SQL''')) si
		ON si.SRVR_NM = pms.ServerName
	WHERE APP_NM = 'GENETEC')

SELECT s.ServerName, JobEnabled, ScheduleEnabled, ScheduleType, Occurrence, Recurrence, Frequency 
FROM servers s
INNER JOIN vw_AllMaintenance_IndexingSchedule d ON d.ServerName = s.ServerName
ORDER BY s.ServerName
GO

with servers as (
	SELECT DISTINCT ServerName
	FROM Perf_MonitoredServers pms
	INNER JOIN (
		SELECT SRVR_NM, DB_NM, APP_NM 
		FROM OPENQUERY (SERVINFO, 'SELECT * FROM CCDB2.MDB_DB_DATA WHERE DBMS = ''SQL''')) si
		ON si.SRVR_NM = pms.ServerName
	WHERE APP_NM = 'GENETEC')

SELECT s.ServerName, JobEnabled, ScheduleEnabled, ScheduleType, Occurrence, Recurrence, Frequency 
FROM servers s
INNER JOIN vw_AllMaintenance_IntegritySchedule d ON d.ServerName = s.ServerName
ORDER BY s.ServerName


with servers as (
	SELECT DISTINCT ServerName
	FROM Perf_MonitoredServers pms
	INNER JOIN (
		SELECT SRVR_NM, DB_NM, APP_NM 
		FROM OPENQUERY (SERVINFO, 'SELECT * FROM CCDB2.MDB_DB_DATA WHERE DBMS = ''SQL''')) si
		ON si.SRVR_NM = pms.ServerName
	WHERE APP_NM = 'GENETEC')

SELECT s.ServerName, JobName, StartDate, EndDate,
	DATEDIFF(SECOND, StartDate, EndDate) DurationSeconds
FROM servers s
INNER JOIN vw_AllMaintenanceJobDuration d ON d.ServerName = s.ServerName
WHERE StartDate > GETDATE() - 1
ORDER BY s.ServerName, JobName, StartDate





with servers as (
	SELECT DISTINCT ServerName, Version, ProcCores, ServerMemory, COUNT(DB_NM) Databases
	FROM vw_AllMonitoredServers pms
	INNER JOIN (
		SELECT SRVR_NM, DB_NM, APP_NM 
		FROM OPENQUERY (SERVINFO, 'SELECT * FROM CCDB2.MDB_DB_DATA WHERE DBMS = ''SQL''')) si
		ON si.SRVR_NM = pms.ServerName
	WHERE APP_NM = 'FAS2000'
	GROUP BY ServerName, Version, ProcCores, ServerMemory)

SELECT ServerName,
	CASE WHEN Version LIKE '10%' THEN 'SQL 2008'
		 WHEN Version LIKE '11%' THEN 'SQL 2012'
		 WHEN Version LIKE '12%' THEN 'SQL 2014'
		 WHEN Version LIKE '13%' THEN 'SQL 2016'
		 WHEN Version LIKE '14%' THEN 'SQL 2017' END Version,
	Version VersionNumber, ProcCores ProcessorCores, ServerMemory, Databases AppDatabases,
	(SELECT COUNT(DatabaseName) 
		FROM vw_AllDatabaseStatus ds
		WHERE ServerName = servers.ServerName
		AND DatabaseName NOT IN ('master', 'model', 'msdb', 'tempdb', 'SQLADMIN', 'ReportServer', 'ReportServerTempDB')) InstanceDatabases
FROM servers
