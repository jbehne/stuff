USE SQLADMIN
GO

EXEC usp_AddNewDatabasesToBackup;
GO

SELECT * FROM Backup_Options
GO

UPDATE Backup_Options SET Compressed = 'Y'
WHERE DatabaseName = 'AWDP'


SELECT name, size/128 SizeMB, * FROM sys.master_files order by size desc