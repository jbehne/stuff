DECLARE @maxtime datetime, @counterID1 int, @counterID2 int;
--SELECT @maxtime = MAX(CollectionTime) FROM Perf_CounterData WHERE InstanceID = @id;
SELECT @counterID1 = counterID FROM Perf_Counters WHERE Counter = '% free space';
SELECT @counterID2 = counterID FROM Perf_Counters WHERE Counter = 'free megabytes';

WITH pctfree
AS (
	SELECT * 
	FROM Perf_CounterData
	WHERE CollectionTime > DATEADD(MI, -6, GETDATE())
	AND counterID = @counterID1)


SELECT ServerName, pc.CollectionTime, pc.Instance, pc.Value FreeMB,
	ROUND((pc.Value / pf.Value * 100) - pc.Value, 0) UsedMB
FROM Perf_CounterData pc
INNER JOIN pctfree pf ON pc.CollectionTime = pf.CollectionTime
	AND pc.Instance = pf.Instance
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = pc.InstanceID
WHERE  pc.counterID = @counterID2
ORDER BY ServerName,Instance DESC;