USE SQLADMIN
GO

IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Maintenance_IndexHistory')
	DROP TABLE dbo.Maintenance_IndexHistory
GO

CREATE TABLE dbo.Maintenance_IndexHistory(
	StartTime datetime ,
	EndTime datetime ,
	Command varchar(max)) 
GO

-- Proc used to show friendly version of history table (translate object ID's to names)
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_Index_History')
	DROP PROC [dbo].[usp_Index_History];
GO

ALTER PROC [dbo].[usp_Index_ManageClusteredIndexes] (@database varchar(512), @printonly bit = 0)
AS
/*
	This proc rebuilds (>30%) or reorganizes (<30%) the indexes of the given database.
*/
	-- VERSION 2.0
	SET NOCOUNT ON;

	-- Heap of variables needed
	DECLARE @tbl varchar(512), @ix varchar(512), @pt int, @frag decimal(12, 8), 
		@pg int, @online varchar(4), @partition varchar(4), @cmd nvarchar(max), @dbid int,
		@tableid int, @indexid int, @schema varchar(512), @pagelocks bit, @starttime datetime;

	-- Table variable will hold the list of all indexes
	DECLARE @list TABLE (DatabaseName varchar(1024), SchemaName varchar(512), TableName varchar(1024),
		IndexName varchar(1024), PartitionNumber int, Fragmentation float, Pages bigint, OnlineEnabled bit,
		TableID int, IndexID int, TypeDesc varchar(128), AllowPageLocks bit);

	-- Get the id of the passed database
	SELECT @dbid = DB_ID(@database);
	
	-- Build the select statement for the passed in database
	SET @cmd = 'SELECT 
	DB_NAME(ps.database_id) [DatabaseName], sc.name [SchemaName],  o.name [TableName], si.name [IndexName], 
	partition_number [PartitionNumber], ps.avg_fragmentation_in_percent [Fragmentation], page_count [Pages],
	CASE WHEN EXISTS(
		SELECT DISTINCT table_name
		FROM [' + @database + '].INFORMATION_SCHEMA.COLUMNS
		WHERE data_type IN (''text'', ''ntext'', ''image'', ''xml'', ''geography'')
		AND table_name COLLATE SQL_Latin1_General_CP1_CI_AS = o.name COLLATE SQL_Latin1_General_CP1_CI_AS
		OR
		data_type IN (''varchar'', ''nvarchar'', ''varbinary'')
		AND character_maximum_length = -1
		AND table_name COLLATE SQL_Latin1_General_CP1_CI_AS = o.name COLLATE SQL_Latin1_General_CP1_CI_AS) THEN ''0'' 
		ELSE 
			CASE WHEN si.type_desc LIKE ''%COLUMNSTORE%'' THEN ''0'' ELSE ''1'' END END OnlineEnabled,
	si.object_id, si.index_id, index_type_desc, allow_page_locks
	FROM sys.dm_db_index_physical_stats (' + CAST(@dbid as varchar) + ', NULL, NULL, NULL, NULL) ps
	INNER JOIN [' + @database + '].sys.indexes si ON ps.object_id = si.object_id AND ps.index_id = si.index_id
	INNER JOIN [' + @database + '].sys.objects o ON o.object_id = ps.object_id
	INNER JOIN [' + @database + '].sys.schemas sc ON sc.schema_id = o.schema_id
	WHERE ps.database_id = ' + CAST(@dbid as varchar)

	-- Execute the dynamic command and insert to table variable
	INSERT @list EXEC(@cmd);

	-- Create cursor to loop through each index that meets the criteria (CLUSTERED & >5% frag)
	-- The query also determines if the index can be rebuid online or by partition
	DECLARE indexmaintenance CURSOR STATIC FORWARD_ONLY READ_ONLY
	FOR
	SELECT SchemaName, TableName, IndexName, PartitionNumber, Fragmentation, Pages,
	CASE WHEN (SELECT @@VERSION) LIKE '%Enterprise%'
	THEN
		CASE WHEN OnlineEnabled = 0
		THEN 'NO' ELSE 'YES' END
	ELSE 'NO' END AS [OnlineEnabled],
	CASE WHEN (SELECT MAX(PartitionNumber) 
		FROM @list
		WHERE IndexName = t.IndexName
		AND TableName = t.TableName) > 1
		THEN 'YES' ELSE 'NO' END AS [Partition],
	TableID, IndexID, AllowPageLocks
	FROM @list t
	WHERE IndexName IS NOT NULL
	AND TypeDesc = 'CLUSTERED INDEX'
	AND Fragmentation >= 5

	-- Open the cursor and fetch the first record into the variables
	OPEN indexmaintenance
	FETCH NEXT FROM indexmaintenance
	INTO @schema, @tbl, @ix, @pt, @frag, @pg, @online, @partition, @tableid, @indexid, @pagelocks
 
	-- Continue while records exist
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		-- If < 30% and partitioned, reorg the partition
		IF @frag < 30 AND @partition = 'YES' AND @pagelocks = 1
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REORGANIZE PARTITION = ' + CAST(@pt AS varchar)
		-- If > 30% and partitioned, rebuild the partition
		ELSE IF @partition = 'YES'
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REBUILD PARTITION = ' + CAST(@pt AS varchar)
		-- If it is under 30% reorg the index
		ELSE IF @frag < 30 AND @pagelocks = 1
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REORGANIZE'
		-- If the index is more than 1GB or marked as not supporting online do a rebuild
		ELSE IF @pg > 131072 OR @online = 'NO'
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REBUILD'
		-- If it makes it to this point the index is available to rebuild as an online operation
		ELSE
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REBUILD WITH (ONLINE=ON)'
   
		-- If printonly 1 was passed it will just print the command
		IF @printonly = 1
			PRINT @cmd      
		ELSE
		BEGIN
			-- Write start time to history
			SET @starttime = GETDATE();
	 		INSERT SQLADMIN.dbo.Maintenance_IndexHistory (StartTime, Command)
			SELECT @starttime, @cmd;

			-- Execute the command
			EXEC(@cmd)

			-- Update complete time
			UPDATE SQLADMIN.dbo.Maintenance_IndexHistory
			SET EndTime = GETDATE()
			WHERE StartTime = @starttime
			AND Command = @cmd;
		END

		--Get the next row
		FETCH NEXT FROM indexmaintenance
		INTO @schema, @tbl, @ix, @pt, @frag, @pg, @online, @partition, @tableid, @indexid, @pagelocks
	END
 
	-- Clean up
	CLOSE indexmaintenance
	DEALLOCATE indexmaintenance
GO


ALTER PROC [dbo].[usp_Index_ManageNonClusteredIndexes] (@database varchar(512), @printonly bit = 0)
AS
/*
	This proc rebuilds (>30%) or reorganizes (<30%) the indexes of the given database.
*/
	-- VERSION 2.0
	SET NOCOUNT ON;

	-- Heap of variables needed
	DECLARE @tbl varchar(512), @ix varchar(512), @pt int, @frag decimal(12, 8), 
		@pg int, @online varchar(4), @partition varchar(4), @cmd nvarchar(max), @dbid int,
		@tableid int, @indexid int, @schema varchar(512), @pagelocks bit, @starttime datetime;

	-- Table variable will hold the list of all indexes
	DECLARE @list TABLE (DatabaseName varchar(1024), SchemaName varchar(512), TableName varchar(1024),
		IndexName varchar(1024), PartitionNumber int, Fragmentation float, Pages bigint, OnlineEnabled bit,
		TableID int, IndexID int, TypeDesc varchar(128), AllowPageLocks bit);

	-- Get the id of the passed database
	SELECT @dbid = DB_ID(@database);
	
	-- Build the select statement for the passed in database
	SET @cmd = 'SELECT 
	DB_NAME(ps.database_id) [DatabaseName], sc.name [SchemaName],  o.name [TableName], si.name [IndexName], 
	partition_number [PartitionNumber], ps.avg_fragmentation_in_percent [Fragmentation], page_count [Pages],
	CASE WHEN EXISTS(
		SELECT DISTINCT table_name
		FROM [' + @database + '].INFORMATION_SCHEMA.COLUMNS
		WHERE data_type IN (''text'', ''ntext'', ''image'', ''xml'', ''geography'')
		AND table_name COLLATE SQL_Latin1_General_CP1_CI_AS = o.name COLLATE SQL_Latin1_General_CP1_CI_AS
		OR
		data_type IN (''varchar'', ''nvarchar'', ''varbinary'')
		AND character_maximum_length = -1
		AND table_name COLLATE SQL_Latin1_General_CP1_CI_AS = o.name COLLATE SQL_Latin1_General_CP1_CI_AS) THEN ''0'' 
		ELSE 
			CASE WHEN si.type_desc LIKE ''%COLUMNSTORE%'' THEN ''0'' ELSE ''1'' END END OnlineEnabled,
	si.object_id, si.index_id, index_type_desc, allow_page_locks
	FROM sys.dm_db_index_physical_stats (' + CAST(@dbid as varchar) + ', NULL, NULL, NULL, NULL) ps
	INNER JOIN [' + @database + '].sys.indexes si ON ps.object_id = si.object_id AND ps.index_id = si.index_id
	INNER JOIN [' + @database + '].sys.objects o ON o.object_id = ps.object_id
	INNER JOIN [' + @database + '].sys.schemas sc ON sc.schema_id = o.schema_id
	WHERE ps.database_id = ' + CAST(@dbid as varchar)

	-- Execute the dynamic command and insert to table variable
	INSERT @list EXEC(@cmd);

	-- Create cursor to loop through each index that meets the criteria (CLUSTERED & >5% frag)
	-- The query also determines if the index can be rebuid online or by partition
	DECLARE indexmaintenance CURSOR STATIC FORWARD_ONLY READ_ONLY
	FOR
	SELECT SchemaName, TableName, IndexName, PartitionNumber, Fragmentation, Pages,
	CASE WHEN (SELECT @@VERSION) LIKE '%Enterprise%'
	THEN
		CASE WHEN OnlineEnabled = 0
		THEN 'NO' ELSE 'YES' END
	ELSE 'NO' END AS [OnlineEnabled],
	CASE WHEN (SELECT MAX(PartitionNumber) 
		FROM @list
		WHERE IndexName = t.IndexName
		AND TableName = t.TableName) > 1
		THEN 'YES' ELSE 'NO' END AS [Partition],
	TableID, IndexID, AllowPageLocks
	FROM @list t
	WHERE IndexName IS NOT NULL
	AND TypeDesc <> 'CLUSTERED INDEX'
	AND Fragmentation >= 5

	-- Open the cursor and fetch the first record into the variables
	OPEN indexmaintenance
	FETCH NEXT FROM indexmaintenance
	INTO @schema, @tbl, @ix, @pt, @frag, @pg, @online, @partition, @tableid, @indexid, @pagelocks
 
	-- Continue while records exist
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		-- If < 30% and partitioned, reorg the partition
		IF @frag < 30 AND @partition = 'YES' AND @pagelocks = 1
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REORGANIZE PARTITION = ' + CAST(@pt AS varchar)
		-- If > 30% and partitioned, rebuild the partition
		ELSE IF @partition = 'YES'
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REBUILD PARTITION = ' + CAST(@pt AS varchar)
		-- If it is under 30% reorg the index
		ELSE IF @frag < 30 AND @pagelocks = 1
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REORGANIZE'
		-- If the index is more than 1GB or marked as not supporting online do a rebuild
		ELSE IF @pg > 131072 OR @online = 'NO'
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REBUILD'
		-- If it makes it to this point the index is available to rebuild as an online operation
		ELSE
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REBUILD WITH (ONLINE=ON)'
   
		-- If printonly 1 was passed it will just print the command
		IF @printonly = 1
			PRINT @cmd      
		ELSE
		BEGIN
			-- Write start time to history
			SET @starttime = GETDATE();
	 		INSERT SQLADMIN.dbo.Maintenance_IndexHistory (StartTime, Command)
			SELECT @starttime, @cmd;

			-- Execute the command
			EXEC(@cmd)

			-- Update complete time
			UPDATE SQLADMIN.dbo.Maintenance_IndexHistory
			SET EndTime = GETDATE()
			WHERE StartTime = @starttime
			AND Command = @cmd;
		END

		--Get the next row
		FETCH NEXT FROM indexmaintenance
		INTO @schema, @tbl, @ix, @pt, @frag, @pg, @online, @partition, @tableid, @indexid, @pagelocks
	END
 
	-- Clean up
	CLOSE indexmaintenance
	DEALLOCATE indexmaintenance
GO

ALTER PROC [dbo].[usp_Index_RebuildHeaps] (@database varchar(512), @printonly bit = 0)
AS 
/*
	This proc rebuilds all heap tables that are more than 5% fragmented
*/
	-- Version 1.4
	SET NOCOUNT ON;

	-- Table will hold the table name from the cursor, cmd will hold the rebuild command
	DECLARE @table varchar(max), @schema varchar(max), @cmd varchar(max);
	DECLARE @starttime datetime, @dbid int, @histcmd varchar(max);

	-- Get the id of the passed database
	SELECT @dbid = DB_ID(@database);

	-- Create a cursor to loop through all heap names > 5% fragmented 
	SET @cmd = '
	DECLARE RebuildHeaps CURSOR STATIC FORWARD_ONLY READ_ONLY 
	FOR
	SELECT DISTINCT o.name TableName, s.name SchemaName
	FROM [' + @database + '].sys.dm_db_index_physical_stats (' + CAST(@dbid AS varchar) + ', null, null, null, null) ips
	INNER JOIN [' + @database + '].sys.objects o ON o.object_id = ips.object_id
	INNER JOIN [' + @database + '].sys.schemas s ON s.schema_id = o.schema_id
	WHERE index_type_desc = ''HEAP''
	AND avg_fragmentation_in_percent > 5;';

	EXEC (@cmd);

	-- Open and fetch the first record 
	OPEN RebuildHeaps;
	FETCH NEXT FROM RebuildHeaps INTO @table, @schema;
 
	-- While there are records, loop through each one
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Create the rebuild command
		SELECT @cmd = 'ALTER TABLE [' + @database + '].[' + @schema + '].[' + @table + '] REBUILD';        
 
		-- Print/Execute command if 1 was passed in
		IF (@printonly = 1)
		BEGIN
			PRINT @cmd;
		END;
		ELSE
		BEGIN
			-- Write start time to history
			SET @starttime = GETDATE();
	 		INSERT SQLADMIN.dbo.Maintenance_IndexHistory (StartTime, Command)
			SELECT @starttime, @cmd;

			-- Execute the command
			EXEC(@cmd)

			-- Update complete time
			UPDATE SQLADMIN.dbo.Maintenance_IndexHistory
			SET EndTime = GETDATE()
			WHERE StartTime = @starttime
			AND Command = @cmd;
			
			EXEC(@histcmd);
		END;
		-- Fetch the next record
		FETCH NEXT FROM RebuildHeaps INTO @table, @schema;
	END
 
	-- Close and deallocate cursor
	CLOSE RebuildHeaps;
	DEALLOCATE RebuildHeaps;
GO

ALTER PROC [dbo].[usp_Statistics_Update] (@printonly bit = 0)
AS
/*
	Rebuild statistics with fullscan if more than 5% of the records have changed.
	This proc does not take a database as an input, instead it will automatically
	run against all databases by itself.
*/
	-- Version 1.3
	SET NOCOUNT ON;

	-- Table variable for databases
	DECLARE @dblist TABLE (id smallint IDENTITY, name varchar(512));
	-- Table variable for list of stats
	DECLARE @list TABLE (DatabaseName varchar(512), SchemaName varchar(512), TableName varchar(512), TableID int);
	-- Variables for the cursor
	DECLARE @database varchar(512), @schema varchar(512), @table varchar(512), @tableid int, 
		@count smallint, @db varchar(512), @cmd varchar(max), @version int, @starttime datetime;

	-- If this is 2012+ check to see if this is an AAG
	-- If not an AAG, @primary is null, if yes @primary is 1 for primary and 0 for replica
	SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10));
	IF @version >= 11
	BEGIN
		INSERT @dblist
		SELECT name 
		FROM sys.databases 
		WHERE name <> 'tempdb'
		AND is_read_only = 0
		AND compatibility_level > 80
		EXCEPT
		SELECT DatabaseName FROM Maintenance_Exclude WHERE IndexingOn = 0
		EXCEPT
		SELECT database_name FROM sys.availability_databases_cluster;
	END;

	ELSE
	BEGIN
		INSERT @dblist
		SELECT name 
		FROM sys.databases 
		WHERE name <> 'tempdb'
		AND is_read_only = 0
		AND compatibility_level > 80
		EXCEPT
		SELECT DatabaseName FROM Maintenance_Exclude WHERE IndexingOn = 0;
	END;

	SELECT @count = MAX(id) FROM @dblist;

	WHILE @count > 0
	BEGIN
		SELECT @db = name FROM @dblist WHERE id = @count
		PRINT @db
		SET @cmd = 'USE [' + @db + ']; 
			SELECT DISTINCT ''' + @db + ''' DBName, sc.name, o.name, o.object_id
			FROM sys.stats s
			INNER JOIN sys.objects o ON o.object_id = s.object_id
			INNER JOIN sys.schemas sc ON o.schema_id = sc.schema_id
			CROSS APPLY sys.dm_db_stats_properties (s.object_id, stats_id)
			WHERE o.is_ms_shipped = 0
			AND modification_counter / rows > .05'

		INSERT @list
		EXEC (@cmd);

		SET @count = @count - 1
	END;

	-- Create the cursor from the table variable
	DECLARE statsmaintenance CURSOR STATIC FORWARD_ONLY READ_ONLY
	FOR
	SELECT * FROM @list;

	-- Open the cursor and get the first record
	OPEN statsmaintenance
	FETCH NEXT FROM statsmaintenance
	INTO @database, @schema, @table, @tableid;
 
	-- Loop while there are records
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @cmd = 'UPDATE STATISTICS [' + @database + '].[' + @schema + '].[' + @table + '] WITH FULLSCAN'; 

		-- If printonly is specified just print
		IF @printonly = 1
			PRINT @cmd
		ELSE
		BEGIN
			-- Write start time to history
			SET @starttime = GETDATE();
	 		INSERT SQLADMIN.dbo.Maintenance_IndexHistory (StartTime, Command)
			SELECT @starttime, @cmd;

			-- Execute the command
			EXEC(@cmd)

			-- Update complete time
			UPDATE SQLADMIN.dbo.Maintenance_IndexHistory
			SET EndTime = GETDATE()
			WHERE StartTime = @starttime
			AND Command = @cmd;
		END

		-- Get the next record
		FETCH NEXT FROM statsmaintenance
		INTO @database, @schema, @table, @tableid;
	END

	-- Clean up the cursor
	CLOSE statsmaintenance;
	DEALLOCATE statsmaintenance;
  GO

  EXEC msdb.dbo.sp_update_jobstep @job_name= 'Maintenance - Indexing' , @step_id=2 , 
		@command=N'DELETE Maintenance_IndexHistory WHERE StartTime < GETDATE() - 14'


