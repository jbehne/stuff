USE [SQLADMIN]
GO
/****** Object:  StoredProcedure [dbo].[usp_AddNewDatabasesToBackup]    Script Date: 7/8/2019 12:14:57 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- This proc is run to make sure all databases have options set
ALTER PROC [dbo].[usp_AddNewDatabasesToBackup] 
AS 
	-- VERSION 1.3
	SET NOCOUNT ON;

	-- Remove options for databases that no longer exist
	DELETE Backup_Options 
	WHERE DatabaseName NOT IN (SELECT name FROM sys.databases);

	-- Add new databases that do no exist
	INSERT Backup_Options (DatabaseName)
	SELECT name FROM sys.databases WHERE name <> 'tempdb'
	EXCEPT 
	SELECT DatabaseName FROM Backup_Options;

	DECLARE @Path varchar(512);
	SELECT @Path = BackupLocation FROM Backup_DefaultLocation;

	-- Set default options
	UPDATE Backup_Options SET BackupLocation = @Path, FullBackupFiles = 1, DiffBackupFiles = 1, 
		LogBackupFiles = 1, Compressed = 'N' WHERE BackupLocation IS NULL;

	-- Create subdirectories if they do not exist
	DECLARE @dir varchar(max), @subdir varchar(512), @cmd varchar(max);
	DECLARE @ResultSet TABLE  (Directory varchar(200));

	SELECT @dir = BackupLocation FROM Backup_DefaultLocation;

	INSERT INTO @ResultSet
	EXEC master.dbo.xp_subdirs @dir;

	DECLARE c_dirs CURSOR FOR
		SELECT DatabaseName FROM Backup_Options
		EXCEPT
		SELECT Directory FROM @ResultSet;

	OPEN c_dirs;

	FETCH NEXT FROM c_dirs INTO @subdir;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @cmd = 'EXEC master.sys.xp_create_subdir ''' + @dir + '\' + @subdir + '''';
		EXEC (@cmd);

		FETCH NEXT FROM c_dirs INTO @subdir;
	END;

	CLOSE c_dirs;
	DEALLOCATE c_dirs;

	-- Get SQL vrsn for AAG check
	DECLARE @version float
	SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))

	-- If 2012+, set AAG database path to Listener name where database is clustered
	IF @version >= 11
	BEGIN
		IF EXISTS (SELECT dns_name FROM sys.availability_group_listeners)
		BEGIN
			SELECT @Path = REPLACE(@Path, @@SERVERNAME, dns_name) FROM sys.availability_group_listeners;
		
			UPDATE Backup_Options SET BackupLocation = @Path
			WHERE DatabaseName IN (SELECT database_name FROM sys.availability_databases_cluster);
		END
	END
