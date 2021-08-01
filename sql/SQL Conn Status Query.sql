--DROP PROC usp_Alert_GetConnectionStatusServers
--usp_Alert_GetConnectionStatusServers


SELECT COUNT(ServerName) [Count], 
CASE WHEN Ping = 0 THEN 'FAIL' ELSE 'Pass' END Ping
FROM Alert_ConnectionStatus acs
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = acs.InstanceID
GROUP BY Ping

SELECT COUNT(ServerName) [Count], 
CASE WHEN SQLConnection = 0 THEN 'FAIL' ELSE 'Pass' END SQLConnection
FROM Alert_ConnectionStatus acs
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = acs.InstanceID
GROUP BY SQLConnection

SELECT * FROM Alert_ConnectionStatusChange
SELECT * FROM Alert_ConnectionStatus


