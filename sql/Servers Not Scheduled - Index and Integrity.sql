-- Who is NOT schedule for indexing
with indexing as (
	SELECT InstanceID FROM Perf_MonitoredServers WHERE IsActive = 1
	EXCEPT
	SELECT InstanceID FROM Maintenance_IndexingSchedule)

SELECT ServerName 
FROM Perf_MonitoredServers pms
INNER JOIN indexing ON indexing.InstanceID = pms.InstanceID
ORDER BY ServerName

GO

-- Who is NOT scheduled for checkdb
with integrity as (
	SELECT InstanceID FROM Perf_MonitoredServers WHERE IsActive = 1
	EXCEPT
	SELECT InstanceID FROM Maintenance_IntegritySchedule)

SELECT ServerName 
FROM Perf_MonitoredServers pms
INNER JOIN integrity ON integrity.InstanceID = pms.InstanceID
ORDER BY ServerName


