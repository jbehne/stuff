INSERT TestHeap VALUES (RAND() * 10000, NEWID(), REPLACE(NEWID(), '-', ''))
GO 200

SELECT * FROM TestHeap
DELETE TestHeap WHERE id BETWEEN 3000 and 4500
DELETE TestHeap WHERE id BETWEEN 1000 and 1500

USE SQLADMIN
GO
--EXEC usp_Index_History
GO


select * from Maintenance_IndexHistory

EXEC usp_Index_AllDatabases

[usp_Index_RebuildHeaps] 'SQLMONITOR', 1
usp_Index_ManageNonClusteredIndexes 'SQLMONITOR', 1


USE SQLMONITOR;
SELECT o.*, ips.*
FROM sys.dm_db_index_physical_stats (DB_ID(), null, null, null, null) ips
INNER JOIN sys.objects o ON o.object_id = ips.object_id 
WHERE index_type_desc = 'HEAP'
