SELECT * FROM Backup_DataDomainFiles_Aurora
SELECT * FROM Backup_DataDomainFiles_Chaska
SELECT * FROM Backup_DataDomainFiles_Bloomington
GO


SELECT 'Aurora Test', SUM(SizeKB)/1024/1024 SizeGB FROM Backup_DataDomainFiles_Aurora WHERE FileName LIKE '%sqltest%'
UNION ALL


SELECT * FROM Backup_DataDomainFiles_Chaska
UNION ALL


SELECT * FROM Backup_DataDomainFiles_Bloomington	





SELECT * FROM Backup_BackupHistory
WHERE BackupLocation not like '\\BLM%'
AND BackupLocation not like '\\m1%'
AND BackupLocation not like '\\s01%'
AND BackupStartDate > GETDATE() - 3