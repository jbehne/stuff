WITH ctrdata
AS (
	SELECT ServerName, Class + '\' + Counter Counter, Value
	FROM Perf_CounterData pcd
	INNER JOIN Perf_Counters pc ON pc.CounterID = pcd.CounterID
	INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = pcd.InstanceID
	WHERE CollectionTime BETWEEN DATEADD(dd, -1, GETDATE()) AND GETDATE()
	AND pc.CounterID IN (83,90,93,95)
)

SELECT ServerName
	, [Processor\% Processor Time] ServerCPU
	, [Memory\Pages/sec] MemoryPaging
	, [Paging File\% Usage] PageFileUsage
	, [Process\% Processor Time] SQLCPU
FROM (SELECT ServerName, Counter, Value FROM ctrdata) Source
PIVOT (AVG(Value) 
	FOR Counter IN ([Processor\% Processor Time]
	, [Memory\Pages/sec]
	, [Paging File\% Usage]
	, [Process\% Processor Time])) pvt
ORDER BY ServerCPU DESC

/*
83	Processor	% Processor Time
90	Memory	Pages/sec
93	Paging File	% Usage
95	Process	% Processor Time


*/