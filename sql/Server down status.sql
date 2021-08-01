SELECT ServerName, MAX(ChangeTime) DownSince, acs.Ping, acs.SQLConnection, acs.InstanceID
FROM Alert_ConnectionStatus acs
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = acs.InstanceID
INNER JOIN Alert_ConnectionStatusChange acsc ON acsc.InstanceID = acs.InstanceID
WHERE acs.SQLConnection = 0
GROUP BY ServerName, acs.Ping, acs.SQLConnection, acs.InstanceID

/*
C1DBD056 - SQL service stopped, restarted OK
C1DBD036 - SQL service stopped, restarted OK
C1APP390      - machine powered off and refuses to power on
V00APPWIN007  - machine powered off and refuses to power on
V00APPWIN008  - machine powered off and refuses to power on
*/

--SELECT * FROM Alert_ConnectionStatusQuiet

--INSERT Alert_ConnectionStatusQuiet VALUES (100, '10/20/19 00:00', '10/20/19 10:00')
--INSERT Alert_ConnectionStatusQuiet VALUES (143, '10/20/19 00:00', '10/20/19 10:00')
--INSERT Alert_ConnectionStatusQuiet VALUES (144, '10/20/19 00:00', '10/20/19 10:00')