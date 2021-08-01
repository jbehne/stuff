USE SQLADMIN;
GO

IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Maintenance_IndexHistory')
	DROP TABLE Maintenance_IndexHistory;
GO
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_Index_History')
	DROP PROC usp_Index_History;
GO
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_Index_RebuildHeaps')
	DROP PROC usp_Index_RebuildHeaps;
GO
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_Index_ManageClusteredIndexes')
	DROP PROC usp_Index_ManageClusteredIndexes;
GO
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_Index_ManageNonClusteredIndexes')
	DROP PROC usp_Index_ManageNonClusteredIndexes;
GO
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_Statistics_Update')
	DROP PROC usp_Statistics_Update;
GO
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_Index_AllDatabases')
	DROP PROC usp_Index_AllDatabases;
GO

-- Tracking table for what has been updated
CREATE TABLE [dbo].[Maintenance_IndexHistory](
	DBid smallint
	, Time smalldatetime
	, ObjectID int
	, IndexID int
	, Type tinyint); -- 1 = HEAP, 2 = INDEX, 3 = STAT
GO

CREATE CLUSTERED INDEX CIX_Maintenance_IndexHistory ON Maintenance_IndexHistory (Time);
GO

-- Proc used to show friendly version of history table (translate object ID's to names)
CREATE PROC usp_Index_History
AS
	-- Version 1.0
	DECLARE @list TABLE (DatabaseID int, ObjectID int, IndexID int, TableName varchar(512), IndexName varchar(512));
	INSERT @list
	EXEC sp_msforeachdb N'USE [?]; SELECT DB_ID(), o.object_id, i.index_id, o.name, i.name
		FROM sys.objects o
		LEFT OUTER JOIN sys.indexes i ON o.object_id = i.object_id'

	SELECT DISTINCT Time, d.name DatabaseName, TableName, IndexName, 
	CASE ih.Type 
		WHEN 1 THEN 'HEAP'
		WHEN 2 THEN 'INDEX'
		WHEN 3 THEN 'STAT'
		END Type
	FROM Maintenance_IndexHistory ih
	INNER JOIN @list o ON o.ObjectID = ih.ObjectID 
		AND o.DatabaseID = ih.DBid 
		AND o.IndexID = ih.IndexID
	INNER JOIN sys.databases d ON d.database_id = dbid
GO

CREATE PROC usp_Index_RebuildHeaps (@database varchar(512), @printonly bit = 0)
AS 
/*
	This proc rebuilds all heap tables that are more than 5% fragmented
*/
	-- Version 1.2
	SET NOCOUNT ON;

	-- Table will hold the table name from the cursor, cmd will hold the rebuild command
	DECLARE @table varchar(max), @schema varchar(max), @cmd varchar(max);

	-- Create a cursor to loop through all heap names > 5% fragmented 
	SET @cmd = '
	DECLARE RebuildHeaps CURSOR STATIC FORWARD_ONLY READ_ONLY 
	FOR
	SELECT OBJECT_NAME(object_id) TableName, SCHEMA_NAME(object_id) SchemaName
	FROM [' + @database + '].sys.dm_db_index_physical_stats (DB_ID(), null, null, null, null) ips
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
			-- Execute the rebuild
			EXEC(@cmd);

			-- Output to history
			INSERT Maintenance_IndexHistory (DBid, Time, ObjectID, IndexID, Type)
			EXEC ('SELECT DB_ID(''[' + @database + ']''), GETDATE(), object_id, 0, 1
			FROM [' + @database + '].sys.objects 
			WHERE name = ''' + @table + '''');
		END;
		-- Fetch the next record
		FETCH NEXT FROM RebuildHeaps INTO @table, @schema;
	END
 
	-- Close and deallocate cursor
	CLOSE RebuildHeaps;
	DEALLOCATE RebuildHeaps;
GO
 
CREATE PROC usp_Index_ManageClusteredIndexes (@database varchar(512), @printonly bit = 0)
AS
/*
	This proc rebuilds (>30%) or reorganizes (<30%) the indexes of the given database.
*/
	-- Version 1.0
	SET NOCOUNT ON;

	-- Heap of variables needed
	DECLARE @tbl varchar(512), @ix varchar(512), @pt int, @frag decimal(12, 8), 
		@pg int, @online varchar(4), @partition varchar(4), @cmd nvarchar(max), @dbid int,
		@tableid int, @indexid int, @schema varchar(512);

	-- Table variable will hold the list of all indexes
	DECLARE @list TABLE (DatabaseName varchar(1024), SchemaName varchar(512), TableName varchar(1024),
		IndexName varchar(1024), PartitionNumber int, Fragmentation float, Pages bigint, OnlineEnabled bit,
		TableID int, IndexID int, TypeDesc varchar(128));

	-- Get the id of the passed database
	SELECT @dbid = DB_ID(@database);
	
	-- Build the select statement for the passed in database
	SET @cmd = 'SELECT 
	DB_NAME(ps.database_id) [DatabaseName], sc.name [SchemaName],  o.name [TableName], si.name [IndexName], 
	partition_number [PartitionNumber], ps.avg_fragmentation_in_percent [Fragmentation], page_count [Pages],
	CASE WHEN EXISTS(
		SELECT DISTINCT table_name
		FROM [' + @database + '].INFORMATION_SCHEMA.COLUMNS
		WHERE data_type IN (''text'', ''ntext'', ''image'', ''xml'')
		AND table_name COLLATE SQL_Latin1_General_CP1_CI_AS = o.name COLLATE SQL_Latin1_General_CP1_CI_AS
		OR
		data_type IN (''varchar'', ''nvarchar'', ''varbinary'')
		AND character_maximum_length = -1
		AND table_name COLLATE SQL_Latin1_General_CP1_CI_AS = o.name COLLATE SQL_Latin1_General_CP1_CI_AS) THEN ''0'' ELSE ''1'' END OnlineEnabled,
	si.object_id, si.index_id, index_type_desc
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
		WHERE IndexName = t.IndexName) > 1
		THEN 'YES' ELSE 'NO' END AS [Partition],
	TableID, IndexID
	FROM @list t
	WHERE IndexName IS NOT NULL
	AND TypeDesc = 'CLUSTERED INDEX'
	AND Fragmentation >= 5

	-- Open the cursor and fetch the first record into the variables
	OPEN indexmaintenance
	FETCH NEXT FROM indexmaintenance
	INTO @schema, @tbl, @ix, @pt, @frag, @pg, @online, @partition, @tableid, @indexid
 
	-- Continue while records exist
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		-- If fragmentation is under 30% and it is partitioned, reorg only the partition
		IF @frag < 30 AND @partition = 'YES'
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REORGANIZE PARTITION = ' + CAST(@pt AS varchar)
		-- If it is partitioned and not under 30% then rebuild only the partition
		ELSE IF @partition = 'YES'
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REBUILD PARTITION = ' + CAST(@pt AS varchar)
		-- If it is under 30% reorg the index
		ELSE IF @frag < 30 
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
			-- Execute the command
			EXEC(@cmd)

			-- Write to history
	 		INSERT SQLADMIN.dbo.Maintenance_IndexHistory (DBid, Time, ObjectID, IndexID, Type)
			SELECT DB_ID(@database), GETDATE(), @tableid, @indexid, 2;
		END

		--Get the next row
		FETCH NEXT FROM indexmaintenance
		INTO @schema, @tbl, @ix, @pt, @frag, @pg, @online, @partition, @tableid, @indexid
	END
 
	-- Clean up
	CLOSE indexmaintenance
	DEALLOCATE indexmaintenance
GO

CREATE PROC usp_Index_ManageNonClusteredIndexes (@database varchar(512), @printonly bit = 0)
AS
/*
	This proc rebuilds (>30%) or reorganizes (<30%) the indexes of the given database.
*/
	-- Version 1.0
	SET NOCOUNT ON;

	-- Heap of variables needed
	DECLARE @tbl varchar(512), @ix varchar(512), @pt int, @frag decimal(12, 8), 
		@pg int, @online varchar(4), @partition varchar(4), @cmd nvarchar(max), @dbid int,
		@tableid int, @indexid int, @schema varchar(512);

	-- Table variable will hold the list of all indexes
	DECLARE @list TABLE (DatabaseName varchar(1024), SchemaName varchar(512), TableName varchar(1024),
		IndexName varchar(1024), PartitionNumber int, Fragmentation float, Pages bigint, OnlineEnabled bit,
		TableID int, IndexID int, TypeDesc varchar(128));

	-- Get the id of the passed database
	SELECT @dbid = DB_ID(@database);
	
	-- Build the select statement for the passed in database
	SET @cmd = 'SELECT 
	DB_NAME(ps.database_id) [DatabaseName], sc.name [SchemaName],  o.name [TableName], si.name [IndexName], 
	partition_number [PartitionNumber], ps.avg_fragmentation_in_percent [Fragmentation], page_count [Pages],
	CASE WHEN EXISTS(
		SELECT DISTINCT table_name
		FROM [' + @database + '].INFORMATION_SCHEMA.COLUMNS
		WHERE data_type IN (''text'', ''ntext'', ''image'', ''xml'')
		AND table_name COLLATE SQL_Latin1_General_CP1_CI_AS = o.name COLLATE SQL_Latin1_General_CP1_CI_AS
		OR
		data_type IN (''varchar'', ''nvarchar'', ''varbinary'')
		AND character_maximum_length = -1
		AND table_name COLLATE SQL_Latin1_General_CP1_CI_AS = o.name COLLATE SQL_Latin1_General_CP1_CI_AS) THEN ''0'' ELSE ''1'' END OnlineEnabled,
	si.object_id, si.index_id, index_type_desc
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
		WHERE IndexName = t.IndexName) > 1
		THEN 'YES' ELSE 'NO' END AS [Partition],
	TableID, IndexID
	FROM @list t
	WHERE IndexName IS NOT NULL
	AND TypeDesc <> 'CLUSTERED INDEX'
	AND Fragmentation >= 5

	-- Open the cursor and fetch the first record into the variables
	OPEN indexmaintenance
	FETCH NEXT FROM indexmaintenance
	INTO @schema, @tbl, @ix, @pt, @frag, @pg, @online, @partition, @tableid, @indexid
 
	-- Continue while records exist
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		-- If fragmentation is under 30% and it is partitioned, reorg only the partition
		IF @frag < 30 AND @partition = 'YES'
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REORGANIZE PARTITION = ' + CAST(@pt AS varchar)
		-- If it is partitioned and not under 30% then rebuild only the partition
		ELSE IF @partition = 'YES'
			SET @cmd = 'ALTER INDEX [' + @ix + '] ON [' + @database + '].[' + @schema + '].[' + @tbl + '] REBUILD PARTITION = ' + CAST(@pt AS varchar)
		-- If it is under 30% reorg the index
		ELSE IF @frag < 30 
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
			-- Execute the command
			EXEC(@cmd)

			-- Write to history
	 		INSERT SQLADMIN.dbo.Maintenance_IndexHistory (DBid, Time, ObjectID, IndexID, Type)
			SELECT DB_ID(@database), GETDATE(), @tableid, @indexid, 2;
		END

		--Get the next row
		FETCH NEXT FROM indexmaintenance
		INTO @schema, @tbl, @ix, @pt, @frag, @pg, @online, @partition, @tableid, @indexid
	END
 
	-- Clean up
	CLOSE indexmaintenance
	DEALLOCATE indexmaintenance
GO

CREATE PROC usp_Statistics_Update (@printonly bit = 0)
AS
/*
	Rebuild statistics with fullscan if more than 5% of the records have changed.
	This proc does not take a database as an input, instead it will automatically
	run against all databases by itself.
*/
	-- Version 1.0
	SET NOCOUNT ON;

	-- Table variable for list of stats
	DECLARE @list TABLE (DatabaseName varchar(512), SchemaName varchar(512), TableName varchar(512), TableID int);
	-- Variables for the cursor
	DECLARE @database varchar(512), @schema varchar(512), @table varchar(512), @tableid int;

	-- Use the builtin proc sp_msforeachdb to read each database's stats 
	INSERT @list
	EXEC sp_msforeachdb 'USE [?];
		IF (''?'' <> ''tempdb'')
		SELECT DISTINCT ''?'' DBName, sc.name, o.name, o.object_id
		FROM sys.stats s
		INNER JOIN sys.objects o ON o.object_id = s.object_id
		INNER JOIN sys.schemas sc ON o.schema_id = sc.schema_id
		CROSS APPLY sys.dm_db_stats_properties (s.object_id, stats_id)
		WHERE o.is_ms_shipped = 0
		AND modification_counter / rows > .05';

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
		-- If printonly is specified just print
		IF @printonly = 1
			PRINT 'UPDATE STATISTICS [' + @database + '].[' + @schema + '].[' + @table + '] WITH FULLSCAN';
		ELSE
		BEGIN
			-- Execute the update
			EXEC('UPDATE STATISTICS [' + @database + '].[' + @schema + '].[' + @table + '] WITH FULLSCAN');
				
			-- Write to the history table		
			INSERT SQLADMIN.dbo.Maintenance_IndexHistory (DBid, Time, ObjectID, IndexID, Type)
			SELECT DB_ID(@database), GETDATE(), @tableid, 0, 3;
		END

		-- Get the next record
		FETCH NEXT FROM statsmaintenance
		INTO @database, @schema, @table, @tableid;
	END
  
	-- Clean up the cursor
	CLOSE statsmaintenance;
	DEALLOCATE statsmaintenance;
GO

CREATE PROC usp_Index_AllDatabases (@printonly bit = 0)
AS
	-- Version 1.2
	SET NOCOUNT ON;

	-- Create a variable and cursor to loop through each database (not tempdb)
	DECLARE @db varchar(512);
	DECLARE alldb CURSOR STATIC FORWARD_ONLY READ_ONLY
	FOR
	SELECT name FROM sys.databases WHERE name <> 'tempdb' ORDER BY name;

	OPEN alldb
	FETCH NEXT FROM alldb INTO @db;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		/*
			Rebuilding a HEAP or a CLUSTERED INDEX automatically forces a rebuild
			of all other indexes on the table.

			The idea here is to rebuild all HEAPS, then all CLUSTERED INDEXES,
			after that do another check to see what indexes are left that meet
			the criteria for maintenance.
		*/
		PRINT @db

		EXEC usp_Index_RebuildHeaps @db, @printonly;
		EXEC usp_Index_ManageClusteredIndexes @db, @printonly;
		EXEC usp_Index_ManageNonClusteredIndexes @db, @printonly;

		FETCH NEXT FROM alldb INTO @db;
	END;

	CLOSE alldb;
	DEALLOCATE alldb;

	-- Finally run the stats proc to update any outdated stats
	EXEC usp_Statistics_Update @printonly ;
GO

-- Job to run indexing and cleanup history
USE [msdb]
GO

IF EXISTS (SELECT name FROM sysjobs WHERE name = 'Maintenance - Indexing')
	EXEC msdb.dbo.sp_delete_job @job_name=N'Maintenance - Indexing';

EXEC msdb.dbo.sp_add_job @job_name=N'Maintenance - Indexing', 
		@owner_login_name=N'CCsaid';

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Maintenance - Indexing', @step_name=N'Run indexing', 
		@step_id=1, 
		@on_success_action=3, 
		@on_fail_action=2, 
		@subsystem=N'TSQL', 
		@command=N'usp_Index_AllDatabases', 
		@database_name=N'SQLADMIN';

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Maintenance - Indexing', @step_name=N'Cleanup history', 
		@step_id=2, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@subsystem=N'TSQL', 
		@command=N'DELETE Maintenance_IndexHistory WHERE Time < GETDATE() - 30', 
		@database_name=N'SQLADMIN';

EXEC msdb.dbo.sp_add_jobserver @job_name=N'Maintenance - Indexing', @server_name = N'(local)';

