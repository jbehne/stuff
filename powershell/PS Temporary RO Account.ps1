$create = "CREATE LOGIN [tempRO] WITH PASSWORD=N'P@ssword1', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF; 
EXEC sp_msforeachdb 'USE [?]; CREATE USER [tempRO] FOR LOGIN [tempRO]; ALTER ROLE [db_datareader] ADD MEMBER [tempRO]'; GRANT EXECUTE TO [tempRO]"

$drop = "EXEC sp_msforeachdb 'USE [?]; DROP USER [tempRO];'; DROP LOGIN [tempRO];"

Invoke-Sqlcmd -ServerInstance V01DBSWIN144 -Query $create
Invoke-Sqlcmd -ServerInstance V01DBSWIN146 -Query $create
Invoke-Sqlcmd -ServerInstance V01DBSWIN147 -Query $create


Invoke-Sqlcmd -ServerInstance V01DBSWIN144 -Query $drop
Invoke-Sqlcmd -ServerInstance V01DBSWIN146 -Query $drop
Invoke-Sqlcmd -ServerInstance V01DBSWIN147 -Query $drop