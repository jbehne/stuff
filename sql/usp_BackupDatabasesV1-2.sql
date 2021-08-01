USE [SQLADMIN]
GO
/****** Object:  StoredProcedure [dbo].[usp_BackupDatabases]    Script Date: 5/15/2019 8:21:21 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- This proc executes the backup type specified using the options table
ALTER PROC [dbo].[usp_BackupDatabases] (@type varchar(12) = 'FULL')
AS
	-- VERSION 1.2
	DECLARE @db varchar(1024), @compress char(1) = 'N', @fullfiles smallint = 1, 
		@difffiles smallint = 1, @logfiles smallint = 1, @path varchar(2048), @cmd nvarchar(max);
	
	-- If this is a FULL or DIFF we want all databases backed up, if LOG we only want full recovery databases
	IF (@type = 'FULL')
		DECLARE c_backup CURSOR FOR
			SELECT DatabaseName, BackupLocation, FullBackupFiles, DiffBackupFiles, LogBackupFiles, Compressed 
			FROM Backup_Options
			WHERE BackupLocation <> '' AND BackupLocation IS NOT NULL;
	ELSE IF (@type = 'DIFF')
		DECLARE c_backup CURSOR FOR
			SELECT DatabaseName, BackupLocation, FullBackupFiles, DiffBackupFiles, LogBackupFiles, Compressed 
			FROM Backup_Options
			WHERE DatabaseName NOT IN ('master', 'model', 'msdb', 'ReportServerTempDB')
			AND BackupLocation <> '' AND BackupLocation IS NOT NULL;
	ELSE
		DECLARE c_backup CURSOR FOR
			SELECT DatabaseName, BackupLocation, FullBackupFiles, DiffBackupFiles, LogBackupFiles, Compressed 
			FROM Backup_Options bo
			INNER JOIN sys.databases d ON d.name = bo.DatabaseName
			WHERE recovery_model = 1
			AND DatabaseName NOT IN ('master', 'model', 'msdb', 'ReportServerTempDB')
			AND BackupLocation <> '' AND BackupLocation IS NOT NULL;
	
	-- Open the cursor and run each backup sequentially using the options
	OPEN c_backup;
	FETCH NEXT FROM c_backup INTO @db, @path, @fullfiles, @difffiles, @logfiles, @compress;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @cmd = 'EXEC DatabaseBackup @Databases = @db, @Directory = @path, @BackupType = @type 
			, @Compress = @compress, @ChangeBackupType = ''Y'', @NumberOfFiles = @files';			
		
		IF (@type = 'FULL')
			EXEC sp_executesql @cmd, N'@db varchar(1024), @path varchar(2048), @type varchar(12), @compress char(1), 
				@files smallint', @db, @path, @type, @compress, @fullfiles;
		ELSE IF (@type = 'DIFF')
			EXEC sp_executesql @cmd, N'@db varchar(1024), @path varchar(2048), @type varchar(12), @compress char(1), 
				@files smallint', @db, @path, @type, @compress, @difffiles;
		ELSE
			EXEC sp_executesql @cmd, N'@db varchar(1024), @path varchar(2048), @type varchar(12), @compress char(1), 
				@files smallint', @db, @path, @type, @compress, @logfiles;
						
		FETCH NEXT FROM c_backup INTO @db, @path, @fullfiles, @difffiles, @logfiles, @compress;
	END

	CLOSE c_backup;
	DEALLOCATE c_backup;
