SELECT NTILE(4) OVER (ORDER BY Version, ServerName) ID, ServerName
INTO #tmp
FROM Perf_MonitoredServers
WHERE IsActive = 1;

WITH cte1 AS (
	SELECT ROW_NUMBER() OVER (ORDER BY ID) Row, ServerName
	FROM #tmp a
	WHERE a.ID = 1),
cte2 AS (
	SELECT ROW_NUMBER() OVER (ORDER BY ID) Row, ServerName
	FROM #tmp a
	WHERE a.ID = 2),
cte3 AS (
	SELECT ROW_NUMBER() OVER (ORDER BY ID) Row, ServerName
	FROM #tmp a
	WHERE a.ID = 3),
cte4 AS (
	SELECT ROW_NUMBER() OVER (ORDER BY ID) Row, ServerName
	FROM #tmp a
	WHERE a.ID = 4)

SELECT a.ServerName a, b.ServerName b, c.ServerName c, d.ServerName d
FROM cte1 a
LEFT OUTER JOIN cte2 b ON a.Row = b.Row
LEFT OUTER JOIN cte3 c ON b.Row = c.Row
LEFT OUTER JOIN cte4 d ON c.Row = d.Row


DROP TABLE #tmp;