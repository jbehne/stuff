
SELECT COUNT(*) FROM Perf_CounterData WHERE Counter LIKE '%  '
SELECT COUNT(*) FROM Perf_CounterData WHERE Class LIKE '%  '

DECLARE @id int = 90
WHILE @id > 0
BEGIN
	UPDATE TOP(100000) Perf_CounterData
	SET Counter = RTRIM(Counter)
	WHERE Counter LIKE '%  '

	SET @id = @id - 1
END

UPDATE TOP(1000000) Perf_CounterData
SET Class = RTRIM(Class)
WHERE Class LIKE '%  '      


SELECT SUM(CAST(DATALENGTH(InstanceID) AS bigint)) FROM Perf_CounterData
SELECT SUM(CAST(DATALENGTH(CollectionTime) AS bigint)) FROM Perf_CounterData
SELECT SUM(CAST(DATALENGTH(Instance) AS bigint)) FROM Perf_CounterData


