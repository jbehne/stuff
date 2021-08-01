SELECT DBName, MAX(BackupEndDate)
FROM Alert_DatabaseStatus ads
LEFT OUTER JOIN Backup_BackupHistory bbh ON bbh.DatabaseName = ads.DBName
GROUP BY DBName


--SELECT * FROM Backup_BackupHistory

DROP TABLE Backup_DataDomainFiles_Bloomington
CREATE TABLE Backup_DataDomainFiles_Bloomington (FileName varchar(max), Created smalldatetime, SizeKB bigint);
CREATE CLUSTERED INDEX CIX_Backup_DataDomainFiles_Bloomington ON Backup_DataDomainFiles_Bloomington (Created) WITH (DATA_COMPRESSION=PAGE)

DROP TABLE Backup_DataDomainFiles_Aurora
CREATE TABLE Backup_DataDomainFiles_Aurora (FileName varchar(max), Created smalldatetime, SizeKB bigint);
CREATE CLUSTERED INDEX CIX_Backup_DataDomainFiles_Aurora ON Backup_DataDomainFiles_Aurora (Created) WITH (DATA_COMPRESSION=PAGE)

DROP TABLE Backup_DataDomainFiles_Chaska
CREATE TABLE Backup_DataDomainFiles_Chaska (FileName varchar(max), Created smalldatetime, SizeKB bigint);
CREATE CLUSTERED INDEX CIX_Backup_DataDomainFiles_Chaska ON Backup_DataDomainFiles_Chaska (Created) WITH (DATA_COMPRESSION=PAGE)

-- C1DBD069..SQLMONITOR
SELECT 'Remove-Item "' + FileName + '"' FROM Backup_DataDomainFiles_Bloomington WHERE FileName NOT LIKE '%COLD%' AND FileName NOT LIKE '%ENCRYPTION%' AND Created < GETDATE() - 60
UNION ALL
SELECT 'Remove-Item "' + FileName + '"' FROM Backup_DataDomainFiles_Aurora WHERE FileName NOT LIKE '%COLD%' AND FileName NOT LIKE '%ENCRYPTION%' AND Created < GETDATE() - 60
UNION ALL
SELECT 'Remove-Item "' + FileName + '"' FROM Backup_DataDomainFiles_Chaska WHERE FileName NOT LIKE '%COLD%' AND FileName NOT LIKE '%ENCRYPTION%' AND Created < GETDATE() - 60
--ORDER BY Created;

SELECT DATEPART(yyyy, Created) Year, SUM(SizeKB) / 1024 / 1024 SizeGB
FROM Backup_DataDomainFiles_Bloomington 
GROUP BY DATEPART(yyyy, Created)
ORDER BY Year;


SELECT * FROM Backup_DataDomainFiles_Bloomington WHERE FileName LIKE '%cold%' and filename like '%prod%'
SELECT * FROM Backup_DataDomainFiles_Bloomington WHERE FileName LIKE '%Encryption%'