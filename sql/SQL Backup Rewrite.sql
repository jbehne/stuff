USE [SQLADMIN]
GO

-- This proc executes the backup type specified using the options table
ALTER PROC [dbo].[usp_BackupDatabases] (@type varchar(12) = 'FULL')
AS
	-- VERSION 1.3
	DECLARE @db varchar(1024), @compress char(1) = 'N', @fullfiles smallint = 1, @dt nvarchar(24),
		@difffiles smallint = 1, @logfiles smallint = 1, @path varchar(2048), @cmd nvarchar(max),
		@version float, @primary tinyint = null, @errorcount smallint = 0, @runtype varchar(12);
	
	-- Create the timestamp for the filename
	SELECT @dt = '_' + CAST(DATEPART(YEAR, GETDATE()) AS nvarchar) + 
		RIGHT('00' + CONVERT(NVARCHAR(2), DATEPART(MONTH, GETDATE())), 2) +
		RIGHT('00' + CONVERT(NVARCHAR(2), DATEPART(DAY, GETDATE())), 2) + '_' +
		RIGHT('00' + CONVERT(NVARCHAR(2), DATEPART(HOUR, GETDATE())), 2) +
		RIGHT('00' + CONVERT(NVARCHAR(2), DATEPART(MINUTE, GETDATE())), 2) +
		RIGHT('00' + CONVERT(NVARCHAR(2), DATEPART(SECOND, GETDATE())), 2) + '_';

	-- If this is 2012+ check to see if this is an AAG
	-- If not an AAG, @primary is null, if yes @primary is 1 for primary and 0 for replica
	SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10));
	IF @version >= 11
	BEGIN
		SELECT @primary = CASE WHEN @@servername = primary_replica THEN 1 ELSE 0 END
		FROM sys.dm_hadr_availability_group_states
	END;

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
			WHERE DatabaseName NOT IN ('model', 'ReportServerTempDB')
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
		-- Set the type to a local var so that it can be changed ad hoc
		SET @runtype = @type;

		-- If a DIFF is being run this will change the type to a full for master/msdb to ensure daily backups
		IF @type = 'DIFF' AND (@db = 'master' OR @db = 'msdb')
		BEGIN
			SET @runtype = 'FULL';
		END;

		-- If no full backup exists yet change the type to a full
		IF @type = 'DIFF' OR @type = 'LOG'
		BEGIN
			IF NOT EXISTS (SELECT TOP 1 physical_device_name   
				FROM msdb.dbo.backupset a 
				INNER JOIN msdb.dbo.backupmediafamily b      
				ON a.media_set_id = b.media_set_id      
				WHERE database_name = @db
				AND type = 'D')
			BEGIN
				SET @runtype = 'FULL';
			END;
		END;
				
		-- This IF/ELSE block will process the command for FULL/DIFF/LOG
		IF @runtype = 'FULL'
		BEGIN
			IF @primary = 0
			BEGIN
				IF EXISTS (SELECT database_name FROM sys.availability_databases_cluster WHERE database_name = @db)
				BEGIN
					FETCH NEXT FROM c_backup INTO @db, @path, @fullfiles, @difffiles, @logfiles, @compress;
					continue;
				END;
			END;

			SET @cmd = 'BACKUP DATABASE [' + @db + '] TO ';
			IF @fullfiles > 1
			BEGIN
				WHILE @fullfiles >= 1
				BEGIN
					SET @cmd = @cmd + 'DISK = ''' + @path + '\' + @db + '\' + @db + @dt + @runtype + '_' + 
						CAST(@fullfiles AS nvarchar) + '.bak'', ';
					SET @fullfiles = @fullfiles - 1;
				END;

				SET @cmd = LEFT(@cmd, LEN(@cmd) - 2) + '''';
			END;

			ELSE
			BEGIN
				SET @cmd = @cmd + 'DISK = ''' + @path + '\' + @db + '\' + @db + @dt + @runtype + '.bak''';
			END;
		END;

		ELSE IF @runtype = 'DIFF'
		BEGIN
			IF @primary = 0
			BEGIN
				IF EXISTS (SELECT database_name FROM sys.availability_databases_cluster WHERE database_name = @db)
				BEGIN
					FETCH NEXT FROM c_backup INTO @db, @path, @fullfiles, @difffiles, @logfiles, @compress;
					continue;
				END;
			END;

			SET @cmd = 'BACKUP DATABASE [' + @db + '] TO ';
			IF @difffiles > 1
			BEGIN
				WHILE @difffiles >= 1
				BEGIN
					SET @cmd = @cmd + 'DISK = ''' + @path + '\' + @db + '\' + @db + @dt + @runtype + '_' + 
						CAST(@difffiles AS nvarchar) + '.bak'', ';
					SET @difffiles = @difffiles - 1;
				END;

				SET @cmd = LEFT(@cmd, LEN(@cmd) - 2) + ''' WITH DIFFERENTIAL';
			END;

			ELSE
			BEGIN
				SET @cmd = @cmd + 'DISK = ''' + @path + '\' + @db + '\' + @db + @dt + @runtype + '.bak'' WITH DIFFERENTIAL';
			END;
		END;

		ELSE IF @runtype = 'LOG'
		BEGIN
			IF @primary = 1
			BEGIN
				IF EXISTS (SELECT database_name FROM sys.availability_databases_cluster WHERE database_name = @db)
				BEGIN
					FETCH NEXT FROM c_backup INTO @db, @path, @fullfiles, @difffiles, @logfiles, @compress;
					continue;
				END;
			END;

			SET @cmd = 'BACKUP LOG [' + @db + '] TO ';
			IF @logfiles > 1
			BEGIN
				WHILE @logfiles >= 1
				BEGIN
					SET @cmd = @cmd + 'DISK = ''' + @path + '\' + @db + '\' + @db + @dt + @runtype + '_' + 
						CAST(@logfiles AS nvarchar) + '.trn'', ';
					SET @logfiles = @logfiles - 1;
				END;

				SET @cmd = LEFT(@cmd, LEN(@cmd) - 2) + '''';
			END;

			ELSE
			BEGIN
				SET @cmd = @cmd + 'DISK = ''' + @path + '\' + @db + '\' + @db + @dt + @runtype + '.trn''';
			END;
		END;

		-- If compression is on and it is a diff, append compression command
		IF @compress = 'Y' AND @runtype = 'DIFF'
		BEGIN
			SET @cmd = @cmd + ', COMPRESSION';
		END;

		-- Otherwise if compression is on, append the full WITH COMPRESSION command
		ELSE IF @compress = 'Y'
		BEGIN
			SET @cmd = @cmd + ' WITH COMPRESSION';
		END;

		-- Output for status
		PRINT 'Backing up ' + @db + ' ';

		-- Perform the backup command in a try catch to prevent job failure on error
		BEGIN TRY		
			--PRINT @cmd -- Used for Testing
			EXEC (@cmd);
		END TRY

		-- Catch execution errors, output the error, increment the count, and continue running
		BEGIN CATCH
			PRINT ERROR_MESSAGE();
			SET @errorcount = @errorcount + 1;
		END CATCH;

		-- Load the next row
		FETCH NEXT FROM c_backup INTO @db, @path, @fullfiles, @difffiles, @logfiles, @compress;
	END;

	-- Clean up
	CLOSE c_backup;
	DEALLOCATE c_backup;

	-- Last,if execution errors occured, fail the job to signal error(s) occurred.
	IF @errorcount > 0
	BEGIN
		RAISERROR('Errors found, job failed. ', 16 ,1);
	END;