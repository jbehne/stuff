DECLARE @printonly bit = 1;
DECLARE @list TABLE (DatabaseName varchar(512), SchemaName varchar(512), TableName varchar(512), TableID int);
DECLARE @database varchar(512), @schema varchar(512), @table varchar(512), @tableid int;

INSERT @list
EXEC sp_msforeachdb 'USE [?];
	IF (''?'' <> ''tempdb'')
	SELECT DISTINCT ''?'' DBName, sc.name, o.name, o.object_id
	FROM sys.stats s
	INNER JOIN sys.objects o ON o.object_id = s.object_id
	INNER JOIN sys.schemas sc ON o.schema_id = sc.schema_id
	CROSS APPLY sys.dm_db_stats_properties (s.object_id, stats_id)
	WHERE o.is_ms_shipped = 0
	AND last_updated < GETDATE() - 7
	AND modification_counter / rows > .05';

DECLARE statsmaintenance CURSOR STATIC FORWARD_ONLY READ_ONLY
FOR
SELECT * FROM @list;

OPEN statsmaintenance
FETCH NEXT FROM statsmaintenance
INTO @database, @schema, @table, @tableid;
 
WHILE @@FETCH_STATUS = 0
BEGIN
	IF @printonly = 1
		PRINT 'UPDATE STATISTICS [' + @database + '].[' + @schema + '].[' + @table + '] WITH FULLSCAN';
	ELSE
	BEGIN
		EXEC('UPDATE STATISTICS [' + @database + '].[' + @schema + '].[' + @table + '] WITH FULLSCAN');
						
		INSERT SQLADMIN.dbo.Maintenance_IndexHistory (DBid, Time, ObjectID, IndexID, Type)
		SELECT DB_ID(@database), GETDATE(), @tableid, 0, 3;
	END

	FETCH NEXT FROM statsmaintenance
	INTO @database, @schema, @table, @tableid;
END
  
CLOSE statsmaintenance;
DEALLOCATE statsmaintenance;
