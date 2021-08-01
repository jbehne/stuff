/*
	BUSINESS HOURS: 7am-5pm
*/

DECLARE @todaystart datetime, @todayend datetime, @yesterdaystart datetime, @yesterdayend datetime;
SELECT @todaystart = DATEADD(hh, 7, CAST(CAST(GETDATE() AS date) AS datetime)),
	@todayend =  DATEADD(hh, 17, CAST(CAST(GETDATE() AS date) AS datetime)),
	@yesterdaystart =  DATEADD(hh, 7, CAST(CAST(GETDATE() - 1 AS date) AS datetime)),
	@yesterdayend =  DATEADD(hh, 17, CAST(CAST(GETDATE() - 1 AS date) AS datetime));

WITH counters AS (
 SELECT CounterID, Class, Counter
 FROM Perf_Counters
 WHERE Counter IN ('% Processor Time', 'Pages/sec', '% Usage', 'Page life expectancy'))

SELECT 'TODAY' [Day], ServerName, CASE WHEN Class = 'Process' THEN 'Sql Server' ELSE Class END Class, 
	Counter, AVG(Value) AvgValue
FROM Perf_CounterData pcd
INNER JOIN counters c ON pcd.CounterID = c.CounterID
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = pcd.InstanceID
WHERE CollectionTime BETWEEN @todaystart AND @todayend
GROUP BY ServerName, Class, Counter
HAVING 
	(Counter = '% Processor Time' AND AVG(Value) > 85)
	OR (Counter = 'Pages/sec' AND AVG(Value) > 1000)
	OR (Counter = '% Usage' AND AVG(Value) > 30)
	OR (Counter = 'Page life expectancy' AND AVG(Value) < 600)
UNION ALL
SELECT 'YESTERDAY' [Day], ServerName, CASE WHEN Class = 'Process' THEN 'Sql Server' ELSE Class END Class, 
	Counter, AVG(Value) AvgValue
FROM Perf_CounterData pcd
INNER JOIN counters c ON pcd.CounterID = c.CounterID
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = pcd.InstanceID
WHERE CollectionTime BETWEEN @yesterdaystart AND @yesterdayend
GROUP BY ServerName, Class, Counter
HAVING 
	(Counter = '% Processor Time' AND AVG(Value) > 85)
	OR (Counter = 'Pages/sec' AND AVG(Value) > 1000)
	OR (Counter = '% Usage' AND AVG(Value) > 30)
	OR (Counter = 'Page life expectancy' AND AVG(Value) < 600)
ORDER BY [Day], ServerName, Class, Counter;