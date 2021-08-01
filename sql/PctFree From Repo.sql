DECLARE @pctfree int = 0;
SELECT @pctfree = CounterID FROM Perf_Counters WHERE Class = 'LogicalDisk' AND Counter = '% Free Space';

WITH lasttime
AS (
	SELECT InstanceID, MAX(CollectionTime) CollectionTime
	FROM Perf_CounterData
	WHERE CollectionTime > DATEADD(HOUR, -2, GETDATE())
	AND CounterID = @pctfree
	GROUP BY InstanceID
),
pctfree 
AS (
	SELECT pcd.InstanceID, Instance, Value, CounterID
	FROM Perf_CounterData pcd
	INNER JOIN lasttime lt ON lt.InstanceID = pcd.InstanceID AND lt.CollectionTime = pcd.CollectionTime
	WHERE pcd.CounterID = @pctfree
)

SELECT ServerName, Instance, 100 - Value PctUsed
FROM pctfree pct
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = pct.InstanceID
WHERE Instance <> 'harddiskvolume1'
AND 100 - Value >= 70
ORDER BY ServerName, Instance;