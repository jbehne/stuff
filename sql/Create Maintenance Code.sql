USE SQLADMIN

-- Index Optimize can be run against all databases
EXECUTE [dbo].[IndexOptimize]
	@Databases = 'ALL_DATABASES',
	@FragmentationLow = NULL,
	@FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_OFFLINE',
	@FragmentationHigh = 'INDEX_REBUILD_OFFLINE',
	@FragmentationLevel1 = 5,
	@FragmentationLevel2 = 30,
	@UpdateStatistics = 'ALL',
	@OnlyModifiedStatistics = 'Y',
	@StatisticsSample = 100


-- Integrity can be run on all databases
EXECUTE [dbo].[DatabaseIntegrityCheck]
@Databases = 'ALL_DATABASES',
@TimeLimit = 1


-- Backups need to be set separately for AAG and non-AAG due to the path
EXECUTE [dbo].[DatabaseBackup]
@Databases = 'AVAILABILITY_GROUP_DATABASES',
@Directory = N'\\blm-bak-10-dd\sql_test\V01LSTWIN502',
@BackupType = 'FULL',
@ChangeBackupType = 'Y'

EXECUTE [dbo].[DatabaseBackup]
@Databases = 'AVAILABILITY_GROUP_DATABASES',
@Directory = N'\\blm-bak-10-dd\sql_test\V01DBSWIN502',
@BackupType = 'FULL',
@ChangeBackupType = 'Y'




--SELECT * FROM Perf_FileSpace WHERE Type = 'ROWS' AND CollectionTime > GETDATE() - 1 AND Size > 500000

SELECT * FROM Backup_Options

CREATE TABLE Backup_Options (DatabaseName varchar(512), Path varchar(512), Files smallint, Compressed bit);
GO

CREATE PROC usp_AddNewDatabasesToBackup 
AS 
	SET NOCOUNT ON;

	INSERT Backup_Options (DatabaseName)
	SELECT name FROM sys.databases WHERE name <> 'tempdb'
	EXCEPT 
	SELECT DatabaseName FROM Backup_Options;

	DECLARE @Domain varchar(100), @key varchar(100), @Path varchar(512);
	SET @key = 'SYSTEM\ControlSet001\Services\Tcpip\Parameters\';
	EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@key,@value_name='Domain',@value=@Domain OUTPUT;
	SELECT @Path = '\\blm-bak-10-dd\' + 
		CASE @Domain 
			WHEN 'corp.alliance.lan' THEN 'sql_prod' 
			WHEN 'alliancedev.lan' THEN 'sql_dev'  
			WHEN 'allianceqa.lan' THEN 'sql_qa' 
			ELSE 'sql_dev' END 
			+ '\' + @@SERVERNAME;

	UPDATE Backup_Options SET Path = @Path, Files = 1, Compressed = 0 WHERE Path IS NULL;
GO