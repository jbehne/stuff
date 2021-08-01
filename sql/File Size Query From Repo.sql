SELECT * 
FROM C1DBD536.SQLMONITOR.dbo.Perf_FileSpace pfs
INNER JOIN C1DBD536.SQLMONITOR.dbo.Perf_MonitoredServers pms ON pms.InstanceID = pfs.InstanceID
WHERE ServerName = 'C1DBD727'
AND CollectionTime BETWEEN '11/13/18 7:40' AND '11/13/18 7:46'
AND DBName = 'FNCDB0Q1'
