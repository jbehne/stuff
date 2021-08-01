SELECT GroupName, ServerName, DatabaseName 
FROM Restore_Access ra
INNER JOIN Restore_Access_Groups rag ON ra.GroupID = rag.GroupID
INNER JOIN SQLMONITOR.dbo.Perf_MonitoredServers pms ON pms.InstanceID = ra.InstanceID
WHERE GroupName = ''

SELECT * FROM Restore_Access_Groups ORDER BY GroupName

SELECT ServerName + '.' + DBName ServerDatabase
FROM SQLMONITOR.dbo.Alert_DatabaseStatus ads
INNER JOIN SQLMONITOR.dbo.Perf_MonitoredServers pms ON pms.InstanceID = ads.InstanceID
WHERE DBName NOT IN ('master', 'model', 'msdb', 'tempdb', 'ReportServer', 'ReportServerTempDB')
ORDER BY ServerName, DBName


CREATE UNIQUE INDEX UIX_Restore_Access_Groups ON Restore_Access_Groups (GroupName);

begin tran rollback
DELETE Restore_Access
WHERE GroupID = (SELECT GroupID FROM Restore_Access_Groups WHERE GroupName = 'OCGBC0D1_UPDATE_TABVIEW')
AND InstanceID = (SELECT InstanceID FROM SQLMONITOR.dbo.Perf_MonitoredServers WHERE ServerName = 'C1APP666')
AND DatabaseName = 'InforCETenant_0dfb9c54-5c1c-4af3-a908-e4cfabcdd90b'




SELECT * FROM Restore_Access_Groups
SELECT * FROM Restore_Access