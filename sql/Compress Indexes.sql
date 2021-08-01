-- This will geenerate scripts for an 'offline' rebuild, faster and less space used, but will block all transactions during execution
SELECT DISTINCT o.name, i.name, i.type_desc, rows,
	CASE WHEN i.name IS NULL
		THEN 'ALTER TABLE [' + o.name + '] REBUILD WITH (DATA_COMPRESSION=PAGE);'
		ELSE 'ALTER INDEX [' + i.name + '] ON [' + o.name + '] REBUILD WITH (DATA_COMPRESSION=PAGE);'
	END [Statement]
FROM sys.indexes (NOLOCK) i
INNER JOIN sys.objects (NOLOCK) o ON i.object_id = o.object_id
INNER JOIN sys.partitions (NOLOCK) p ON p.object_id = o.object_id
WHERE o.is_ms_shipped = 0
AND data_compression = 0
ORDER BY rows, type_desc DESC;


-- This will geenerate scripts for an 'online' rebuild, slower and requires double the space, but does not cause blocking during execution
SELECT DISTINCT o.name, i.name, i.type_desc, rows,
	CASE WHEN i.name IS NULL
		THEN 'ALTER TABLE [' + o.name + '] REBUILD WITH (DATA_COMPRESSION=PAGE,ONLINE=ON);'
		ELSE 'ALTER INDEX [' + i.name + '] ON [' + o.name + '] REBUILD WITH (DATA_COMPRESSION=PAGE,ONLINE=ON);'
	END [Statement]
FROM sys.indexes (NOLOCK) i
INNER JOIN sys.objects (NOLOCK) o ON i.object_id = o.object_id
INNER JOIN sys.partitions (NOLOCK) p ON p.object_id = o.object_id
WHERE o.is_ms_shipped = 0
AND data_compression = 0
ORDER BY rows, type_desc DESC;


/*  This will tell you which index it is processing.

SELECT t.*
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t;


sp_who2

*/