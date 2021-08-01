/*
select * from Perf_MonitoredServers where servername = 'V01DBSWIN009'
select * from Perf_MonitoredServers where servername = 'V01DBSWIN007'
select * from Perf_Counters

V01DBSWIN007 = 105
V01DBSWIN009 = 106

96	SQLServer:Database Replica	Transaction Delay
97	SQLServer:Database Replica	Mirrored Write Transactions/sec

Latency = Delay / Transactions

*/


-- CTE for delay counter
WITH delay AS (
SELECT * FROM Perf_CounterData (nolock)
WHERE CounterID IN (96)
AND InstanceID in (105, 106)
AND value <> 0
AND CollectionTime > getdate() - 14),
-- CTE for transaction counter
trans as (
SELECT * FROM Perf_CounterData (nolock)
WHERE CounterID IN (97)
AND InstanceID in (105, 106)
AND value <> 0
AND CollectionTime > getdate() - 14)

-- Join the tables and perform the division to get latency
SELECT d.InstanceID, d.Instance, d.CollectionTime, d.Value / t.Value LatencyMS
FROM delay d
INNER JOIN trans t ON d.InstanceID = t.InstanceID
	AND t.CollectionTime = d.CollectionTime
	AND t.Instance = d.Instance