/*
USE [master]
RESTORE DATABASE [DM] FROM  DISK = N'\\blm-bak-10-dd\sql_prod\V01DBSWIN147\DM\DM_backup_201901110401.FILE1.bak',  
DISK = N'\\blm-bak-10-dd\sql_prod\V01DBSWIN147\DM\DM_backup_201901110401.FILE2.bak',  
DISK = N'\\blm-bak-10-dd\sql_prod\V01DBSWIN147\DM\DM_backup_201901110401.FILE3.bak',  
DISK = N'\\blm-bak-10-dd\sql_prod\V01DBSWIN147\DM\DM_backup_201901110401.FILE4.bak' 
WITH  FILE = 1,  MOVE N'DM' TO N'J:\Data\DM.mdf',  MOVE N'DM_log' TO N'L:\Data\DM_log.ldf',  NOUNLOAD,  REPLACE,  STATS = 5

GO


USE [master]
RESTORE DATABASE [ODS] FROM  DISK = N'\\blm-bak-10-dd\sql_prod\V01DBSWIN147\ODS\ODS_backup_201901110541.FILE1.bak',  
DISK = N'\\blm-bak-10-dd\sql_prod\V01DBSWIN147\ODS\ODS_backup_201901110541.FILE2.bak',  
DISK = N'\\blm-bak-10-dd\sql_prod\V01DBSWIN147\ODS\ODS_backup_201901110541.FILE3.bak',  
DISK = N'\\blm-bak-10-dd\sql_prod\V01DBSWIN147\ODS\ODS_backup_201901110541.FILE4.bak' 
WITH  FILE = 1,  MOVE N'ODS' TO N'M:\Data\ODS.mdf',  MOVE N'ODS_log' TO N'K:\Data\ODS_log.ldf',  NOUNLOAD,  REPLACE,  STATS = 5

GO


*/

Exec sp_change_users_login 'report'

Exec sp_change_users_login 'update_one', 'MMRPTID', 'MMRPTID'
Exec sp_change_users_login 'update_one', 'WebFocus', 'WebFocus'
Exec sp_change_users_login 'update_one', 'GARDEF', 'GARDEF'
Exec sp_change_users_login 'update_one', 'RDAPP', 'RDAPP'
Exec sp_change_users_login 'update_one', 'CQPPDP', 'CQPPDP'