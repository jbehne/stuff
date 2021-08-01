with oracle AS (
SELECT * FROM OPENQUERY(X1DBD021, 'SELECT TARGET_NAME, TARGET_TYPE, AVAILABILITY_STATUS
        FROM   sysman.mgmt$availability_CURRENT
        WHERE  target_type IN (''host'', ''oracle_database'')
        ORDER BY TARGET_TYPE DESC')
UNION ALL
SELECT * FROM OPENQUERY(X1DBD030, 'SELECT TARGET_NAME, TARGET_TYPE, AVAILABILITY_STATUS
        FROM   sysman.mgmt$availability_CURRENT
        WHERE  target_type IN (''host'', ''oracle_database'')
        ORDER BY TARGET_TYPE DESC')
/*UNION ALL
SELECT * FROM OPENQUERY(X1DBD531, 'SELECT TARGET_NAME, TARGET_TYPE, AVAILABILITY_STATUS
        FROM   sysman.mgmt$availability_CURRENT
        WHERE  target_type IN (''host'', ''oracle_database'')
        ORDER BY TARGET_TYPE DESC')	
UNION ALL
SELECT * FROM OPENQUERY(X6DBD600, 'SELECT TARGET_NAME, TARGET_TYPE, AVAILABILITY_STATUS
        FROM   sysman.mgmt$availability_CURRENT
        WHERE  target_type IN (''host'', ''oracle_database'')
        ORDER BY TARGET_TYPE DESC')				
UNION ALL
SELECT * FROM OPENQUERY(V06DBORHL510, 'SELECT TARGET_NAME, TARGET_TYPE, AVAILABILITY_STATUS
        FROM   sysman.mgmt$availability_CURRENT
        WHERE  target_type IN (''host'', ''oracle_database'')
        ORDER BY TARGET_TYPE DESC')*/
)

SELECT TARGET_NAME, TARGET_TYPE, 
	CASE WHEN AVAILABILITY_STATUS = 'Target Up' THEN 'ONLINE' ELSE 'OFFLINE' END AVAILABILITY_STATUS
FROM oracle

GO
WITH prod AS (
	SELECT COUNT(InstanceID) [Count], 
	CASE WHEN SQLConnection = 0 THEN 'OFFLINE' ELSE 'ONLINE' END SQLConnection
	FROM Alert_ConnectionStatus
	GROUP BY SQLConnection),
test AS (
	SELECT COUNT(InstanceID)  [Count], 
	CASE WHEN SQLConnection = 0 THEN 'OFFLINE' ELSE 'ONLINE' END SQLConnection
	FROM C1DBD536.SQLMONITOR.dbo.Alert_ConnectionStatus
	GROUP BY SQLConnection)

SELECT p.Count + t.Count Count, p.SQLConnection
FROM prod p 
INNER JOIN test t ON t.SQLConnection = p.SQLConnection

GO

SELECT ServerName, LastCheck,
CASE WHEN Ping = 0 THEN 'OFFLINE' ELSE 'ONLINE' END Ping,
CASE WHEN SQLConnection = 0 THEN 'OFFLINE' ELSE 'ONLINE' END SQLConnection
FROM Alert_ConnectionStatus acs
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = acs.InstanceID
WHERE SQLConnection = 0
UNION ALL
SELECT ServerName, LastCheck,
CASE WHEN Ping = 0 THEN 'OFFLINE' ELSE 'ONLINE' END Ping,
CASE WHEN SQLConnection = 0 THEN 'OFFLINE' ELSE 'ONLINE' END SQLConnection
FROM C1DBD536.SQLMONITOR.dbo.Alert_ConnectionStatus acs
INNER JOIN C1DBD536.SQLMONITOR.dbo.Perf_MonitoredServers pms ON pms.InstanceID = acs.InstanceID
WHERE SQLConnection = 0

GO

with prod AS (
	SELECT COUNT(*) [Count], Status 
	FROM Alert_DatabaseStatus
	GROUP BY Status),
test AS (
SELECT COUNT(*) [Count], Status 
	FROM C1DBD536.SQLMONITOR.dbo.Alert_DatabaseStatus
	GROUP BY Status)

SELECT COALESCE(p.Count, 0) + COALESCE(t.Count, 0) Count, p.Status
FROM prod p 
FULL OUTER JOIN test t ON t.Status = p.Status

GO


SELECT ServerName, DBName, LastCheck, Status
FROM Alert_DatabaseStatus acs
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = acs.InstanceID
WHERE Status <> 'ONLINE'
UNION ALL
SELECT ServerName, DBName, LastCheck, Status
FROM C1DBD536.SQLMONITOR.dbo.Alert_DatabaseStatus acs
INNER JOIN C1DBD536.SQLMONITOR.dbo.Perf_MonitoredServers pms ON pms.InstanceID = acs.InstanceID
WHERE Status <> 'ONLINE'