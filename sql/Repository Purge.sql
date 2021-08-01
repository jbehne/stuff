SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME

CREATE TABLE Purge_PolicyTables (TableName varchar(512), DateColumn varchar(512), RetentionDays smallint);
GO
INSERT Purge_PolicyTables VALUES 
('Alert_ConnectionStatusChange', 'ChangeTime', 180),
('Backup_BackupHistory', 'BackupEndDate', 365),
('Error_Log', 'ErrorTime', 180),
('Maintenance_JobDuration', 'StartDate', 365),
('Perf_CounterData', 'CollectionTime', 365),
('Perf_ErrorLog', 'ErrorDate', 45),
('Perf_FileIO', 'CollectionTime', 365),
('Perf_FileSpace', 'CollectionTime', 365),
('Perf_MemoryGrants', 'CollectionTime', 365),
('Perf_Sessions', 'CollectionTime', 365),
('Perf_WaitStatistics', 'CollectionTime', 365);
GO




DECLARE @deletecmd nvarchar(max), @countcmd nvarchar(max), @count bigint;
DECLARE c_delete CURSOR
FOR SELECT 'DELETE TOP (100000) FROM ' + TableName + ' WHERE ' + 
	DateColumn + ' <= GETDATE() - ' + CAST(RetentionDays AS varchar)
	FROM Purge_PolicyTables;

OPEN c_delete;
FETCH NEXT FROM c_delete INTO @deletecmd;

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @countcmd = REPLACE(@deletecmd, 'DELETE TOP (100000)', 'SELECT @count = COUNT(*)');

	EXEC sp_executesql @countcmd, N'@count bigint out', @count out;
	WHILE @count > 0
	BEGIN
		EXEC sp_executesql @deletecmd;
		EXEC sp_executesql @countcmd, N'@count bigint out', @count out;
	END

	FETCH NEXT FROM c_delete INTO @deletecmd;
END

CLOSE c_delete;
DEALLOCATE c_delete;