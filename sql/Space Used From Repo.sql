DECLARE @freespace int = 0, @pctfree int = 0;
SELECT @freespace = CounterID FROM Perf_Counters WHERE Class = 'LogicalDisk' AND Counter = 'Free Megabytes';
SELECT @pctfree = CounterID FROM Perf_Counters WHERE Class = 'LogicalDisk' AND Counter = '% Free Space';

WITH lasttime
AS (
	SELECT InstanceID, MAX(CollectionTime) CollectionTime
	FROM Perf_CounterData
	WHERE CollectionTime > DATEADD(HOUR, -2, GETDATE())
	AND CounterID = @freespace
	GROUP BY InstanceID
),
spcfree
AS (
	SELECT pcd.InstanceID, Instance, Value, CounterID
	FROM Perf_CounterData pcd
	INNER JOIN lasttime lt ON lt.InstanceID = pcd.InstanceID AND lt.CollectionTime = pcd.CollectionTime
	WHERE CounterID = @freespace
),
pctfree 
AS (
	SELECT pcd.InstanceID, Instance, Value, CounterID
	FROM Perf_CounterData pcd
	INNER JOIN lasttime lt ON lt.InstanceID = pcd.InstanceID AND lt.CollectionTime = pcd.CollectionTime
	WHERE pcd.CounterID = @pctfree
),
total
AS (
	SELECT DISTINCT spcfree.InstanceID, spcfree.Instance, spcfree.Value FreeMB, 
		ROUND((spcfree.Value / pctfree.Value * 100) - spcfree.Value, 0) UsedMB
	FROM spcfree
	INNER JOIN pctfree ON spcfree.InstanceID = pctfree.InstanceID
		AND spcfree.Instance = pctfree.Instance
	WHERE spcfree.Instance <> 'harddiskvolume1'
)

SELECT ServerName, Instance, FreeMB, UsedMB, UsedMB / FreeMB * 100 PctUsed
FROM total t
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = t.InstanceID;