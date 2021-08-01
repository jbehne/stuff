$server = "C1DBD522"

$features = @()
$dbs = Invoke-Sqlcmd -ServerInstance $server -Query "SELECT name FROM sys.databases"
foreach ($db in $dbs)
{
    $features += Invoke-Sqlcmd -ServerInstance $server -Database $db.name -Query "SELECT @@SERVERNAME, DB_NAME(), feature_name FROM sys.dm_db_persisted_sku_features;"
}

$features