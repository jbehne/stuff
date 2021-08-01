$query = "
DECLARE @tblbackup TABLE (txt varchar(max));
INSERT @tblbackup
EXEC sp_helptext 'usp_BackupDatabases';

DECLARE @tbladdnewdb TABLE (txt varchar(max));
INSERT @tbladdnewdb
EXEC sp_helptext 'usp_AddNewDatabasesToBackup';

DECLARE @tblindexheaps TABLE (txt varchar(max));
INSERT @tblindexheaps
EXEC sp_helptext 'usp_Index_RebuildHeaps';

DECLARE @tblindexcix TABLE (txt varchar(max));
INSERT @tblindexcix
EXEC sp_helptext 'usp_Index_ManageClusteredIndexes';

DECLARE @tblindexix TABLE (txt varchar(max));
INSERT @tblindexix
EXEC sp_helptext 'usp_Index_ManageNonClusteredIndexes';

DECLARE @tblindeix TABLE (txt varchar(max));
INSERT @tblindeix
EXEC sp_helptext 'usp_Index_ManageNonClusteredIndexes';

DECLARE @tblindex TABLE (txt varchar(max));
INSERT @tblindex
EXEC sp_helptext 'usp_Index_AllDatabases';

DECLARE @tblstats TABLE (txt varchar(max));
INSERT @tblstats
EXEC sp_helptext 'usp_Statistics_Update';

DECLARE @tblcheck TABLE (txt varchar(max));
INSERT @tblcheck
EXEC sp_helptext 'usp_IntegrityCheck';

SELECT @@SERVERNAME ServerName, 
(SELECT REPLACE(REPLACE(SUBSTRING(txt, CHARINDEX('VERSION ', txt, 0) + 8, 5), CHAR(13), ''), CHAR(10), '')  FROM @tblbackup WHERE txt LIKE '%--%VERSION%') usp_BackupDatabases,
(SELECT REPLACE(REPLACE(SUBSTRING(txt, CHARINDEX('VERSION ', txt, 0) + 8, 5), CHAR(13), ''), CHAR(10), '') FROM @tbladdnewdb WHERE txt LIKE '%--%VERSION%') usp_AddNewDatabasesToBackup,
(SELECT REPLACE(REPLACE(SUBSTRING(txt, CHARINDEX('VERSION ', txt, 0) + 8, 5), CHAR(13), ''), CHAR(10), '') FROM @tblindexheaps WHERE txt LIKE '%--%VERSION%') usp_Index_RebuildHeaps,
(SELECT REPLACE(REPLACE(SUBSTRING(txt, CHARINDEX('VERSION ', txt, 0) + 8, 5), CHAR(13), ''), CHAR(10), '') FROM @tblindexcix WHERE txt LIKE '%--%VERSION%') usp_Index_ManageClusteredIndexes,
(SELECT REPLACE(REPLACE(SUBSTRING(txt, CHARINDEX('VERSION ', txt, 0) + 8, 5), CHAR(13), ''), CHAR(10), '') FROM @tblindexix WHERE txt LIKE '%--%VERSION%') usp_Index_ManageNonClusteredIndexes,
(SELECT REPLACE(REPLACE(SUBSTRING(txt, CHARINDEX('VERSION ', txt, 0) + 8, 5), CHAR(13), ''), CHAR(10), '') FROM @tblindex WHERE txt LIKE '%--%VERSION%') usp_Index_AllDatabases,
(SELECT REPLACE(REPLACE(SUBSTRING(txt, CHARINDEX('VERSION ', txt, 0) + 8, 5), CHAR(13), ''), CHAR(10), '') FROM @tblstats WHERE txt LIKE '%--%VERSION%') usp_Statistics_Update,
(SELECT REPLACE(REPLACE(SUBSTRING(txt, CHARINDEX('VERSION ', txt, 0) + 8, 5), CHAR(13), ''), CHAR(10), '') FROM @tblcheck WHERE txt LIKE '%--%VERSION%') usp_IntegrityCheck
"

$servers = (Invoke-Sqlcmd -ServerInstance C1DBD536 -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName
$servers += (Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName
$result = @()

foreach ($server in $servers)
{
    $result += Invoke-Sqlcmd -ServerInstance $server -Database SQLADMIN -Query $query
}

Invoke-SqlCmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "TRUNCATE TABLE Maintenance_Versions"
Write-SqlTableData -ServerInstance C1DBD069 -DatabaseName SQLMONITOR -SchemaName dbo -TableName Maintenance_Versions -InputData $result