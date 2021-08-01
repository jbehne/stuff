select max(collectiontime) from perf_counterdata where instanceid = 1 and collectiontime > dateadd(DAY, -12, getdate())

select * from Perf_MonitoredServers_data

select * from perf_errorlog



SELECT COUNT(*), 
	CASE WHEN Edition LIKE 'Enterprise%' THEN 'Enterprise' ELSE 'Standard' END Edition,
	CASE WHEN Version LIKE '10%' THEN '2008R2'
		WHEN Version LIKE '11%' THEN '2012'
		WHEN Version LIKE '12%' THEN '2014'
		WHEN Version LIKE '13%' THEN '2016'
		WHEN Version LIKE '14%' THEN '2017'
		WHEN Version LIKE '15%' THEN '2019' END Version
FROM Perf_MonitoredServers_Data
GROUP BY Edition, Version


GO
WITH list AS (
SELECT 
	CASE WHEN Edition LIKE 'Enterprise%' THEN 'Enterprise' ELSE 'Standard' END Edition,
	CASE WHEN Version LIKE '10%' THEN '2008R2'
		WHEN Version LIKE '11%' THEN '2012'
		WHEN Version LIKE '12%' THEN '2014'
		WHEN Version LIKE '13%' THEN '2016'
		WHEN Version LIKE '14%' THEN '2017'
		WHEN Version LIKE '15%' THEN '2019' END Version
FROM Perf_MonitoredServers_Data
UNION ALL
SELECT 
	CASE WHEN Edition LIKE 'Enterprise%' THEN 'Enterprise' ELSE 'Standard' END Edition,
	CASE WHEN Version LIKE '10%' THEN '2008R2'
		WHEN Version LIKE '11%' THEN '2012'
		WHEN Version LIKE '12%' THEN '2014'
		WHEN Version LIKE '13%' THEN '2016'
		WHEN Version LIKE '14%' THEN '2017'
		WHEN Version LIKE '15%' THEN '2019' END Version
FROM C1DBD536.SQLMONITOR.dbo.Perf_MonitoredServers_Data)

SELECT COUNT(*), Edition FROM list GROUP BY Edition
UNION ALL
SELECT COUNT(*), Version FROM list GROUP BY Version