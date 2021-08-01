-- Proc use last half hour
SELECT CollectionTime, ServerName, ProcCores, Counter, Value
FROM Perf_CounterData pcd
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = pcd.InstanceID
INNER JOIN Perf_Counters pc ON pc.CounterID = pcd.CounterID
WHERE Counter = '% Processor Time'
AND CollectionTime > DATEADD(MINUTE, -30, GETDATE())
ORDER BY Value DESC


-- Proc use on CQP last 8 hours
SELECT CollectionTime, ServerName, ProcCores, Counter, Value
FROM Perf_CounterData pcd
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = pcd.InstanceID
INNER JOIN Perf_Counters pc ON pc.CounterID = pcd.CounterID
WHERE Counter = '% Processor Time'
AND CollectionTime > DATEADD(HOUR, -8, GETDATE())
AND ServerName = 'V01DBSWIN144'
ORDER BY CollectionTime



DECLARE @tbl TABLE ([Index] VARCHAR(2000), [Name] VARCHAR(2000), [Internal_Value] VARCHAR(2000), [Character_Value] VARCHAR(2000)) ;
INSERT @tbl EXEC xp_msver;  SELECT Internal_Value FROM @tbl WHERE Name IN ('ProcessorCount');