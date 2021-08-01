SELECT 'ALTER INDEX [' + b.name + '] ON [' + o.name + '] REBUILD WITH (DATA_COMPRESSION=PAGE)'
--o.name, b.name
FROM sys.partitions a
INNER Join sys.indexes b ON b.object_id = a.object_id AND b.index_id = a.index_id
INNER JOIN sys.objects o on o.object_id = b.object_id
AND is_ms_shipped = 0
WHERE a.data_compression < 2
