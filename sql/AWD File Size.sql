SELECT * 
FROM Backup_BackupHistory bbh
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = bbh.InstanceID
WHERE ServerName = 'C1DBD045'
AND DatabaseName = 'AWDP'
AND BackupStartDate > GETDATE() - 30



SELECT TOP 10 *
FROM Perf_FileSpace pfs
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = pfs.InstanceID
WHERE 
