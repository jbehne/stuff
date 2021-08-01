CREATE VIEW vw_AllMissingBackups
AS
SELECT ServerName, ads.DBName, MAX(bbh.BackupEndDate) BackupEndDate
FROM Alert_DatabaseStatus ads
LEFT OUTER JOIN Backup_BackupHistory bbh ON bbh.DatabaseName = ads.DBName AND ads.InstanceID = bbh.InstanceID
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = ads.InstanceID
AND ads.DBName <> 'SQLADMIN'
AND ads.DBName <> 'tempdb'
GROUP BY ServerName, ads.DBName
HAVING MAX(COALESCE(bbh.BackupEndDate, '1/1/1900')) < GETDATE() - 3

UNION ALL

SELECT ServerName, ads.DBName, MAX(bbh.BackupEndDate) BackupEndDate
FROM C1DBD536.SQLMONITOR.dbo.Alert_DatabaseStatus ads
LEFT OUTER JOIN C1DBD536.SQLMONITOR.dbo.Backup_BackupHistory bbh ON bbh.DatabaseName = ads.DBName AND ads.InstanceID = bbh.InstanceID
INNER JOIN C1DBD536.SQLMONITOR.dbo.Perf_MonitoredServers pms ON pms.InstanceID = ads.InstanceID
AND ads.DBName <> 'SQLADMIN'
AND ads.DBName <> 'tempdb'
GROUP BY ServerName, ads.DBName
HAVING MAX(COALESCE(bbh.BackupEndDate, '1/1/1900')) < GETDATE() - 3
