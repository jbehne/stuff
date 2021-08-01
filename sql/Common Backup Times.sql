USE SQLMONITOR
GO

-- Find the most recurring hour of full backups
WITH ctefull AS (
SELECT DISTINCT DATENAME(dw, BackupStartDate) Day, DATEPART(HOUR, BackupStartDate) Hour, DatabaseName, COUNT(*) Count
FROM Backup_BackupHistory bh
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = bh.InstanceID
WHERE ServerName = 'C1DBD507'
AND BackupType = 'D'
GROUP BY DATENAME(dw, BackupStartDate), DATEPART(HH, BackupStartDate), DatabaseName)
, ctemax AS (
SELECT DISTINCT DatabaseName, MAX(Count) Count
FROM ctefull 
GROUP BY DatabaseName)


SELECT b.Day, b.Hour, COUNT(b.hour) Count
FROM ctemax a
INNER JOIN ctefull b ON a.DatabaseName = b.DatabaseName
	AND a.Count = b.Count
GROUP BY b.Day, b.Hour
ORDER BY Count DESC;

/*
-- This query is by database name
SELECT a.DatabaseName, b.Day, b.Hour
FROM ctemax a
INNER JOIN ctefull b ON a.DatabaseName = b.DatabaseName
	AND a.Count = b.Count
ORDER BY a.DatabaseName;
*/


-- Find the most recurring log backups
SELECT DISTINCT DATEPART(HH, BackupStartDate) Hour, COUNT(*) Count
FROM Backup_BackupHistory bh
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = bh.InstanceID
WHERE ServerName = 'C1DBD507'
AND BackupType = 'L'
GROUP BY DATEPART(HH, BackupStartDate)
ORDER BY Count DESC;

/*
-- This query is by database name
SELECT DISTINCT DatabaseName, DATENAME(dw, BackupStartDate) Day, DATEPART(HH, BackupStartDate) Hour, COUNT(*) Count
FROM Backup_BackupHistory bh
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = bh.InstanceID
WHERE ServerName = 'C1DBD502'
AND BackupType = 'L'
GROUP BY DATENAME(dw, BackupStartDate), DATEPART(HH, BackupStartDate), DatabaseName
ORDER BY DatabaseName;
*/

