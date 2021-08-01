CREATE PROC usp_Index_RebuildHeaps (@printonly bit = 0)
AS 
/*
	This proc rebuilds all heap tables that are more than 5% fragmented
*/
-- Table will hold the table name from the cursor, cmd will hold the rebuild command
DECLARE @table varchar(max), @cmd varchar(max);

-- Create a cursor to loop through all heap names > 5% fragmented 
DECLARE RebuildHeaps CURSOR STATIC FORWARD_ONLY READ_ONLY 
FOR
SELECT OBJECT_NAME(object_id) TableName
FROM sys.dm_db_index_physical_stats (DB_ID(), null, null, null, null) ips
WHERE index_type_desc = 'HEAP'
AND avg_fragmentation_in_percent > 5;

-- Open and fetch the first record 
OPEN RebuildHeaps;
FETCH NEXT FROM RebuildHeaps INTO @table;
 
-- While there are records, loop through each one
WHILE @@FETCH_STATUS = 0
BEGIN
	-- Create the rebuild command
    SELECT @cmd = 'ALTER TABLE [' + @table + '] REBUILD';        
 
	-- Print/Execute command
	if (@printonly = 1)
		PRINT @cmd;
	else
		EXEC(@cmd);
 
	-- Fetch the next record
    FETCH NEXT FROM RebuildHeaps INTO @table;
END
 
-- Close and deallocate cursor
CLOSE RebuildHeaps;
DEALLOCATE RebuildHeaps;
 
GO
 
SELECT
DB_NAME(ps.database_id) [DatabaseName], OBJECT_NAME(ps.OBJECT_ID) [TableName], si.name [IndexName], 
partition_number [PartitionNumber], ps.avg_fragmentation_in_percent [Fragmentation], page_count [Pages]
INTO #tmp
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS ps
INNER JOIN sys.indexes AS si ON ps.OBJECT_ID = si.OBJECT_ID AND ps.index_id = si.index_id
WHERE ps.database_id = DB_ID()
 
 
DECLARE @tbl varchar(512), @ix varchar(512), @pt int, @frag decimal(12, 8), 
    @pg int, @online varchar(4), @partition varchar(4), @cmd nvarchar(512)
DECLARE indexmaintenance CURSOR STATIC FORWARD_ONLY READ_ONLY
FOR
SELECT TableName, IndexName, PartitionNumber, Fragmentation, Pages,
CASE WHEN (SELECT @@VERSION) LIKE '%Enterprise%'
THEN
    CASE WHEN (SELECT DISTINCT table_name
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE data_type IN ('text', 'ntext', 'image', 'xml')
        AND table_name = t.TableName
        OR
        data_type IN ('varchar', 'nvarchar', 'varbinary')
        AND character_maximum_length = -1
        AND table_name = t.TableName) IS NOT NULL
    THEN 'NO' ELSE 'YES' END
ELSE 'NO' END AS [OnlineEnabled],
CASE WHEN (SELECT MAX(PartitionNumber) 
    FROM #tmp 
    WHERE IndexName = t.IndexName) > 1
    THEN 'YES' ELSE 'NO' END AS [Partition]
FROM #tmp t
WHERE IndexName IS NOT NULL
AND Fragmentation >= 5
 
OPEN indexmaintenance
FETCH NEXT FROM indexmaintenance
INTO @tbl, @ix, @pt, @frag, @pg, @online, @partition
 
WHILE (@@FETCH_STATUS = 0)
BEGIN
    IF @frag < 30 AND @partition = 'YES'
        SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @tbl + '] REORGANIZE PARTITION = ' + CAST(@pt AS varchar)
    ELSE IF @partition = 'YES'
        SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @tbl + '] REBUILD PARTITION = ' + CAST(@pt AS varchar)
    ELSE IF @frag < 30 
        SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @tbl + '] REORGANIZE'
    ELSE IF @pg > 131072 OR @online = 'NO'
        SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @tbl + '] REBUILD'
    ELSE
        SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @tbl + '] REBUILD WITH (ONLINE=ON)'
   
    PRINT @cmd      
    --EXEC sp_executesql @cmd
     
    FETCH NEXT FROM indexmaintenance
    INTO @tbl, @ix, @pt, @frag, @pg, @online, @partition
END
 
CLOSE indexmaintenance
DEALLOCATE indexmaintenance
  
DROP TABLE #tmp


SELECT DISTINCT o.name
FROM sys.stats s
INNER JOIN sys.objects o ON o.object_id = s.object_id
CROSS APPLY sys.dm_db_stats_properties (s.object_id, stats_id)
WHERE o.is_ms_shipped = 0
AND last_updated < GETDATE() - 4
AND modification_counter / rows > .1