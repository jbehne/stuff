
SELECT cp.ServerName, Edition, cp.ServerModel
FROM Perf_MonitoredServers_Data pmsd
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = pmsd.InstanceID
INNER JOIN Capacity_Planning cp ON cp.ServerName = pms.ServerName
WHERE CollectDate = '5/20/20'
AND Edition LIKE '%Enterprise%'
AND ServerModel NOT LIKE '%Aurora%'
ORDER BY Edition