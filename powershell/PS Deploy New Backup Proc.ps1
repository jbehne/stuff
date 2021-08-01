# Query to check version.  Use builtin proc helptext to get text, search version, return servername if version matches.
$query = "SET NOCOUNT ON
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_BackupDatabases')
BEGIN
	DECLARE @tbl TABLE (txt varchar(max));

	INSERT @tbl
	EXEC sp_helptext 'usp_BackupDatabases'

	IF EXISTS (SELECT * FROM @tbl WHERE txt LIKE '%VERSION 1.1%')
		SELECT @@SERVERNAME
END"

# Create server array and query both test and prod repo for server list.
$servers = @()
$servers += (Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName
$servers += (Invoke-Sqlcmd -ServerInstance C1DBD536 -Database SQLMONITOR -Query "SELECT ServerName FROM Perf_MonitoredServers WHERE IsActive = 1").ServerName

# Create array for servers that are on the older version
$updateservers = @()

# Loop through the server list, if the query returns a servername capture that in the updateservers list.
foreach ($server in $servers)
{
    $server
    $updateserver = Invoke-Sqlcmd -ServerInstance $server -Database SQLADMIN -Query $query
    if ($updateserver -ne $null)
    {
        $updateservers += $updateserver
    }
}

# Loop through the list of servers requiring an update and push the new script to each one.
foreach ($updateserver in $updateservers)
{
    $updateserver.Column1
    Invoke-Sqlcmd -ServerInstance $updateserver.Column1 -Database SQLADMIN -InputFile C:\Users\Public\Documents\SQL\usp_BackupDatabasesV1-2.sql
}