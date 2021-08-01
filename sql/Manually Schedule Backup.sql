WITH ids AS (
SELECT InstanceID 
FROM Perf_MonitoredServers WHERE IsActive = 1
EXCEPT
SELECT DISTINCT InstanceID 
FROM Maintenance_BackupSchedule_Full),
loc AS (
SELECT * 
FROM OPENQUERY(SERVINFO, 'SELECT * FROM CCDB2.MDB_SRVR_NAME_PROPERTIES'))

SELECT ServerName, Version, Location 
FROM Perf_MonitoredServers pms
INNER JOIN ids ON ids.InstanceID = pms.InstanceID
LEFT OUTER JOIN loc ON loc.SRVR_NM = pms.ServerName
--WHERE ServerName LIKE '%DBD%'
ORDER BY ServerName

GO

WITH ids AS (
SELECT InstanceID 
FROM C1DBD536.SQLMONITOR.dbo.Perf_MonitoredServers WHERE IsActive = 1
EXCEPT
SELECT DISTINCT InstanceID 
FROM C1DBD536.SQLMONITOR.dbo.Maintenance_BackupSchedule_Full),
loc AS (
SELECT * 
FROM OPENQUERY(SERVINFO, 'SELECT * FROM CCDB2.MDB_SRVR_NAME_PROPERTIES'))

SELECT ServerName, Version, Location 
FROM C1DBD536.SQLMONITOR.dbo.Perf_MonitoredServers pms
INNER JOIN ids ON ids.InstanceID = pms.InstanceID
LEFT OUTER JOIN loc ON loc.SRVR_NM = pms.ServerName
--WHERE ServerName LIKE '%DBD%'
ORDER BY ServerName

/*
EXEC usp_GetBackupTimes 'C1DBD010'

EXEC usp_GenerateBackupSchedule 'Saturday', '080000', '180000'
*/