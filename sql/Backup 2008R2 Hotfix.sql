USE [SQLADMIN]
GO
/****** Object:  StoredProcedure [dbo].[usp_AddNewDatabasesToBackup]    Script Date: 4/4/2019 1:46:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- This proc is run to make sure all databases have options set
ALTER PROC [dbo].[usp_AddNewDatabasesToBackup] 
AS 
	-- VERSION 1.2b (2008 R2 Hotfix)
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

	DECLARE @version float
	SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))

	-- Set AAG database path to Listener name
	IF @version >= 11
	BEGIN
		IF EXISTS (SELECT dns_name FROM sys.availability_group_listeners)
		BEGIN
			SELECT @Path = REPLACE(@Path, @@SERVERNAME, dns_name) FROM sys.availability_group_listeners;
		
			UPDATE Backup_Options SET BackupLocation = @Path
			WHERE DatabaseName IN (SELECT database_name FROM sys.availability_databases_cluster);
		END
	END
