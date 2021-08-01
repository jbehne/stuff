SELECT * 
FROM Perf_CounterData pcd
INNER JOIN Perf_Counters pc ON pc.CounterID = pcd.CounterID
WHERE InstanceID = 1
AND CollectionTime BETWEEN '2018-07-20 11:44:00' AND '2018-07-20 11:46:00'