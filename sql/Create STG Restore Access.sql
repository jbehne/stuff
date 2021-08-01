INSERT Restore_Access_Groups
SELECT DISTINCT DBName + '_UPDATE_TABVIEW' 
FROM SQLMONITOR..Alert_DatabaseStatus ds
WHERE DBName like 'OCG%'

INSERT Restore_Access
SELECT GroupID, ds.InstanceID, DBName 
FROM SQLMONITOR..Alert_DatabaseStatus ds
INNER JOIN Restore_Access_Groups ag ON ag.GroupName = DBName + '_UPDATE_TABVIEW' 
WHERE DBName like 'OCG%'


SELECT * FROM Restore_Access_Groups
SELECT * FROM Restore_Access

IF EXISTS (SELECT GroupName FROM Restore_Access_Groups WHERE GroupName IN (''))
SELECT 'True' HasAccess ELSE SELECT 'False' HasAccess;

INSERT Restore_Access_Groups VALUES ('ITS DBAS');


SELECT Backup_Request_ID, br.ServerName, br.DatabaseName, RequestDate
FROM Restore_Access_Groups rag
INNER JOIN Restore_Access ra ON ra.GroupID = rag.GroupID
INNER JOIN SQLMONITOR.dbo.Perf_MonitoredServers pms ON pms.InstanceID = ra.InstanceID
INNER JOIN Backup_Request br ON br.DatabaseName = ra.DatabaseName AND br.ServerName = pms.ServerName
WHERE GroupName IN ('OCGBC0D1_UPDATE_TABVIEW');