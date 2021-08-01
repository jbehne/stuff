WITH alldd AS (
SELECT * FROM Backup_DataDomainFiles_Aurora
UNION ALL
SELECT * FROM Backup_DataDomainFiles_Bloomington
UNION ALL
SELECT * FROM Backup_DataDomainFiles_Chaska
)

SELECT DatabaseName, MIN(BackupStartDate) OldestBackup, SUM(BackupSize) TotalSize
FROM vw_AllBackupHistory bh
INNER JOIN alldd ON alldd.FileName = bh.BackupLocation
WHERE DatabaseName IN (
'AWDP',
'AWDPR',
'AWDP_XA_TRAN_CHECK'
)
GROUP BY DatabaseName
GO

WITH alldd AS (
SELECT * FROM Backup_DataDomainFiles_Aurora
UNION ALL
SELECT * FROM Backup_DataDomainFiles_Bloomington
UNION ALL
SELECT * FROM Backup_DataDomainFiles_Chaska
)

SELECT DatabaseName, MIN(BackupStartDate) OldestBackup, SUM(BackupSize) TotalSize
FROM vw_AllBackupHistory bh
INNER JOIN alldd ON alldd.FileName = bh.BackupLocation
WHERE DatabaseName IN (
'LIFESUITE_REPORTS',
'LIFESUITE_REPORTS_NEW',
'LIFESUITE_REPORTS_OLD',
'HOAPS_P1',
'LIFESUITE_HUB_P1',
'LIFESUITE_P1',
'PROVIDERLIST_PROD_OLD',
'APSDB0P1',
'LIFESUITE_UTILITIES',
'PROVIDERLIST_INT_OLD',
'HOAPS_LARA',
'PROVIDERLIST_QA_OLD',
'REPORTSERVER_LARATEMPDB',
'APSDB0T1',
'PROVIDERLIST_XENA_OLD')
GROUP BY DatabaseName

