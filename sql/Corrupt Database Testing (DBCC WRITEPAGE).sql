USE master
GO
CREATE DATABASE Test
GO

USE Test
GO
CREATE TABLE test (id int identity, data varchar(36));
GO
INSERT test SELECT 'TEST MESSAGE'
GO 

-- Get the page # of the table
DBCC IND ('Test', 'test', -1);
-- Turn on TF 3604 for DBCC output
DBCC TRACEON(3604);
-- View the page to get the offsets for the row and column
DBCC PAGE ('Test', 1, 300, 3);
-- Look at the data before changes
SELECT * FROM test;
-- Get the integer offset of the varchar data
SELECT CONVERT(int, 0xf) + CONVERT(int, 0x60)

-- Edit the page in the cache
DBCC WRITEPAGE ('Test', 1, 300, 111, 12, 0x454545454545454545454545, 0); -- Write to page in buffer
-- Check the page
DBCC PAGE ('Test', 1, 300, 3)  -- WITH TABLERESULTS;
-- Query the data
SELECT * FROM test;

-- Now we're going to wreak havoc
ALTER DATABASE Test SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- Edit the page on the disk, bypass buffer
DBCC WRITEPAGE ('Test', 1, 300, 111, 12, 0x666666666666666666666666, 1); -- Bypass buffer
-- Check the page
DBCC PAGE ('Test', 1, 300, 3)  -- WITH TABLERESULTS;
-- Lets try to query this...
SELECT * FROM test;

--USE master
--DBCC CHECKDB ('Test') WITH NO_INFOMSGS
--DBCC CHECKDB ('Test', 'REPAIR_REBUILD') 
--DBCC CHECKDB ('Test', 'REPAIR_ALLOW_DATA_LOSS') -- Row is destroyed
--SELECT * FROM test;
--ALTER DATABASE Test SET MULTI_USER WITH ROLLBACK IMMEDIATE;

/*
 Page position in hex (Visual Studio)
 Page number * 8192 -> Go To Offset -> Type 0nXXXXXXXX where X = value above
 SELECT 300 * 8192  -- 0n2457600

SELECT CONVERT(int, 0xf) + CONVERT(int, 0x60)

*/


/*
use master
drop database test

SQLADMIN..DatabaseIntegrityCheck @databases='Test'
*/