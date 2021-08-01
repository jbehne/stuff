USE SQLADMIN;
GO

-- Cleanup old objects
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'MaintenanceWindow')
	DROP TABLE MaintenanceWindow;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Backup_Options')
	DROP TABLE Backup_Options;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Backup_DefaultLocation')
	DROP TABLE Backup_DefaultLocation;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_AddNewDatabasesToBackup')
	DROP PROC usp_AddNewDatabasesToBackup;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_BackupDatabases')
	DROP PROC usp_BackupDatabases;

-- Start and end time of maintenance window
CREATE TABLE MaintenanceWindow (StartTime smalldatetime, EndTime smalldatetime);
GO

-- Backup default location for new databases
CREATE TABLE Backup_DefaultLocation (BackupLocation varchar(2048));
GO

-- Auto set the default location to Aurora
DECLARE @Domain varchar(100), @key varchar(100), @Path varchar(512);
SET @key = 'SYSTEM\ControlSet001\Services\Tcpip\Parameters\';
EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@key,@value_name='Domain',@value=@Domain OUTPUT;
INSERT Backup_DefaultLocation
SELECT '\\s01ddaesd001d\' + 
	CASE @Domain 
		WHEN 'corp.alliance.lan' THEN '01_sqlprodcifs' 
		WHEN 'alliancedev.lan' THEN '01_sqltestcifs'  
		WHEN 'allianceqa.lan' THEN '01_sqlqacifs' 
		ELSE '01_sqltestcifs' END 
		+ '\' + @@SERVERNAME;

-- Backup options
CREATE TABLE Backup_Options (DatabaseName varchar(1024), BackupLocation varchar(2048), FullBackupFiles smallint, 
	DiffBackupFiles smallint, LogBackupFiles smallint, Compressed char(1));
GO

-- This proc is run to make sure all databases have options set
CREATE PROC usp_AddNewDatabasesToBackup 
AS 
	-- VERSION 1.2
	SET NOCOUNT ON;

	-- Remove options for databases that no longer exist
	DELETE Backup_Options 
	WHERE DatabaseName NOT IN (SELECT name FROM sys.databases);

	-- Add new databases that do no exist
	INSERT Backup_Options (DatabaseName)
	SELECT name FROM sys.databases WHERE name <> 'tempdb'
	EXCEPT 
	SELECT DatabaseName FROM Backup_Options;

	-- Determine the backup path from the domain
	/*
	DECLARE @Domain varchar(100), @key varchar(100), @Path varchar(512);
	SET @key = 'SYSTEM\ControlSet001\Services\Tcpip\Parameters\';
	EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@key,@value_name='Domain',@value=@Domain OUTPUT;
	SELECT @Path = '\\s01ddaesd001d\' + 
		CASE @Domain 
			WHEN 'corp.alliance.lan' THEN '01_sqlprodcifs' 
			WHEN 'alliancedev.lan' THEN '01_sqltestcifs'  
			WHEN 'allianceqa.lan' THEN '01_sqlqacifs' 
			ELSE '01_sqltestcifs' END 
			+ '\' + @@SERVERNAME;
	*/
	DECLARE @Path varchar(512);
	SELECT @Path = BackupLocation FROM Backup_DefaultLocation;

	-- Set default options
	UPDATE Backup_Options SET BackupLocation = @Path, FullBackupFiles = 1, DiffBackupFiles = 1, 
		LogBackupFiles = 1, Compressed = 'N' WHERE BackupLocation IS NULL;

	-- Set AAG database path to Listener name
	IF EXISTS (SELECT dns_name FROM sys.availability_group_listeners)
	BEGIN
		SELECT @Path = REPLACE(@Path, @@SERVERNAME, dns_name) FROM sys.availability_group_listeners;
		
		UPDATE Backup_Options SET BackupLocation = @Path
		WHERE DatabaseName IN (SELECT database_name FROM sys.availability_databases_cluster);
	END
GO

-- This proc executes the backup type specified using the options table
CREATE PROC usp_BackupDatabases (@type varchar(12) = 'FULL')
AS
	-- VERSION 1.1
	DECLARE @db varchar(1024), @compress char(1) = 'N', @fullfiles smallint = 1, 
		@difffiles smallint = 1, @logfiles smallint = 1, @path varchar(2048), @cmd nvarchar(max);
	
	-- If this is a FULL or DIFF we want all databases backed up, if LOG we only want full recovery databases
	IF (@type = 'FULL' OR @type = 'DIFF')
		DECLARE c_backup CURSOR FOR
			SELECT DatabaseName, BackupLocation, FullBackupFiles, DiffBackupFiles, LogBackupFiles, Compressed FROM Backup_Options;
	ELSE
		DECLARE c_backup CURSOR FOR
			SELECT DatabaseName, BackupLocation, FullBackupFiles, DiffBackupFiles, LogBackupFiles, Compressed 
			FROM Backup_Options bo
			INNER JOIN sys.databases d ON d.name = bo.DatabaseName
			WHERE recovery_model = 1;	
	
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
GO

-- Backup Job
USE [msdb]
GO

IF EXISTS (SELECT name FROM sysjobs WHERE name = 'Maintenance - Backup FULL')
	EXEC sp_delete_job @job_name = N'Maintenance - Backup FULL';

EXEC msdb.dbo.sp_add_job @job_name=N'Maintenance - Backup FULL', 
		@description=N'Database Backups', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'CCsaid';

EXEC msdb.dbo.sp_add_jobserver @job_name=N'Maintenance - Backup FULL', @server_name = N'(local)';

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Maintenance - Backup FULL', @step_name=N'New Databases', 
		@command=N'[dbo].[usp_AddNewDatabasesToBackup]', 
		@database_name=N'SQLADMIN',
		@on_success_action=3;

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Maintenance - Backup FULL', @step_name=N'Backup', 
		@command=N'usp_BackupDatabases ''FULL''', 
		@database_name=N'SQLADMIN';
GO

IF EXISTS (SELECT name FROM sysjobs WHERE name = 'Maintenance - Backup DIFF')
	EXEC sp_delete_job @job_name = N'Maintenance - Backup DIFF';

EXEC msdb.dbo.sp_add_job @job_name=N'Maintenance - Backup DIFF', 
		@description=N'Database Backups', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'CCsaid';

EXEC msdb.dbo.sp_add_jobserver @job_name=N'Maintenance - Backup DIFF', @server_name = N'(local)';

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Maintenance - Backup DIFF', @step_name=N'New Databases', 
		@command=N'[dbo].[usp_AddNewDatabasesToBackup]', 
		@database_name=N'SQLADMIN',
		@on_success_action=3;

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Maintenance - Backup DIFF', @step_name=N'Backup', 
		@command=N'usp_BackupDatabases ''DIFF''', 
		@database_name=N'SQLADMIN';
GO

IF EXISTS (SELECT name FROM sysjobs WHERE name = 'Maintenance - Backup LOG')
	EXEC sp_delete_job @job_name = N'Maintenance - Backup LOG';

EXEC msdb.dbo.sp_add_job @job_name=N'Maintenance - Backup LOG', 
		@description=N'Database Backups', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'CCsaid';

EXEC msdb.dbo.sp_add_jobserver @job_name=N'Maintenance - Backup LOG', @server_name = N'(local)';

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Maintenance - Backup LOG', @step_name=N'New Databases', 
		@command=N'usp_BackupDatabases ''LOG''', 
		@database_name=N'SQLADMIN',
		@on_success_action=3;

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Maintenance - Backup LOG', @step_name=N'Backup', 
		@command=N'[dbo].[usp_AddNewDatabasesToBackup]', 
		@database_name=N'SQLADMIN';



--EXEC [DatabaseBackup] 
--	@Databases = 'Sandbox'
--	, @Directory = 'E:\'
--	, @BackupType = 'FULL' -- FULL, DIFF, LOG
--	, @Compress = null -- Y, N, null
--	, @ChangeBackupType = 'Y' -- Y or N (This will take a full if a log or diff can't be taken)
--	, @NumberOfFiles = 1 -- 1 to 64

/*
SELECT * FROM Backup_Options

UPDATE Backup_Options SET BackupLocation = REPLACE(BackupLocation, 'sql_dev', '01_sqltestcifs');
UPDATE Backup_Options SET BackupFiles = 4 WHERE DatabaseName = 'SQLMONITOR';

SELECT * FROM sys.databases

usp_AddNewDatabasesToBackup

usp_BackupDatabases 'FULL';
usp_BackupDatabases 'DIFF';
usp_BackupDatabases 'LOG';
*/