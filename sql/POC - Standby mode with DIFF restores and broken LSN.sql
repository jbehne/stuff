-- Step 1 - Take a vanilla backup of sandbox
BACKUP DATABASE Sandbox TO DISK = 'E:\Sandbox_Backup.bak' WITH INIT
GO

-- Step 2 - Restore backup to read only replica (WITH NORECOVERY is mandatory!!!)
RESTORE DATABASE Sandbox_RO FROM DISK = 'E:\Sandbox_Backup.bak'  WITH 
FILE = 1,  
MOVE N'Sandbox' TO N'E:\DATA\MSSQL12.MSSQLSERVER\MSSQL\DATA\Sandbox_RO.mdf',  
MOVE N'Sandbox_log' TO N'E:\DATA\MSSQL12.MSSQLSERVER\MSSQL\DATA\Sandbox_RO_log.ldf',  
NORECOVERY;
GO

-- Step 3 - Set the database to STANDBY and give it a standby file for transactions (NOT THE BACKUP FILE)
RESTORE DATABASE Sandbox_RO WITH STANDBY = 'E:\Sandbox_RO_Standby.bak';
GO

-- Step 4A - Check if this table exists in the read only copy
-- Step 4B - Open a new connection (query window) and USE [Sandbox_RO] now
USE [Sandbox_RO];
SELECT name FROM sys.objects WHERE name = 'ThisIsATest';

-- Step 5 - Create this table in the primary copy
USE [Sandbox];
CREATE TABLE ThisIsATest (id int);
GO

-- Step 6A - Take a new FULL from Sandbox, this will break the LSN chain of the replica
BACKUP DATABASE Sandbox TO DISK = 'E:\Sandbox_Backup2.bak' WITH INIT
-- Step 6B - Take a differential backup
BACKUP DATABASE Sandbox TO DISK = 'E:\Sandbox_Diff.bak' WITH COMPRESSION, DIFFERENTIAL, INIT;
GO

-- Step 7 - Restore will fail if connections are open to the DB.  Rollback and proceed.
-- Just like the full, restore with NORECOVERY first, then set STANDBY with a standby file.
ALTER DATABASE Sandbox_RO SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
RESTORE DATABASE Sandbox_RO FROM DISK = 'E:\Sandbox_Diff.bak'  WITH NORECOVERY;
GO
RESTORE DATABASE Sandbox_RO WITH STANDBY = 'E:\Sandbox_RO_Standby.bak';
GO
ALTER DATABASE Sandbox_RO SET MULTI_USER;

-- Step 8 - Check to see if the new table applied with the differential.
USE [Sandbox_RO];
SELECT name FROM sys.objects WHERE name = 'ThisIsATest';


-- Step 9 - Clean everything up.
USE [Sandbox];
DROP TABLE ThisIsATest;
GO
ALTER DATABASE Sandbox_RO SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
DROP DATABASE Sandbox_RO
GO