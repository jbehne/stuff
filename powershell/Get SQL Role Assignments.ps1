$servers = @()
#$servers += "C1DBD044,CECDBPDP"
$servers += "V01DBSWIN147,CECDBPDP"
#$servers += "C1DBD044,CEWIPPDP"
$servers += "V01DBSWIN146,CEWIPPDP"
$servers += "C1DBD212,FNCDB0P1"
$servers += "C1DBD212,HFLDB002"
$servers += "C1DBD049,IWORKS"
$servers += "C1DBD102,LIFESUITE_P1"
$servers += "C1DBD051,LIFESUITE_REPORTS"
$servers += "C1DBD051,LIFESUITE_REPORTS_OLD"
$servers += "C2APP003,LMRKGEN"
$servers += "C1DBD035,OCGPC0P2"
$servers += "C1DBD035,OCGPC0P2_STG_PROFILE"
$servers += "C1DBD035,OCGPC0T2"
$servers += "C1DBD020,PPILOT"
$servers += "C1DBD007,TAI_COUNTRY_PROD"

$query = "SELECT @@SERVERNAME ServerName, DB_NAME() DatabaseName, su.name AS Role, sysusers_1.name AS UserName
            FROM dbo.sysusers su
            INNER JOIN dbo.sysmembers sm ON su.uid = sm.groupuid 
            INNER JOIN dbo.sysusers sysusers_1 ON sm.memberuid = sysusers_1.uid
            WHERE sysusers_1.name <> 'dbo'"

Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "CREATE TABLE temppermission (ServerName varchar(512), DatabaseName varchar(512), Role varchar(512), UserName varchar(512));"
$repositoryconnection = New-Object system.data.SqlClient.SQLConnection("Data Source=C1DBD069;Integrated Security=SSPI;Database=SQLMONITOR")
$repositoryconnection.Open()
        
$bc = New-Object ("System.Data.SqlClient.SqlBulkCopy") $repositoryconnection
$bc.BatchSize = 100000
$bc.EnableStreaming = "True"
$bc.BulkCopyTimeout = 120

foreach ($server in $servers)
{
    $sqlconn = New-Object System.Data.SqlClient.SQLConnection("Server=$($server.Split(',')[0]);Database=$($server.Split(',')[1]);Integrated Security=true")
    $sqlconn.Open()

    $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($query, $sqlconn)
    $sqlreader = $sqlcmd.ExecuteReader()    
    $bc.DestinationTableName = "temppermission"
    $bc.WriteToServer($sqlreader)
    $sqlreader.Close()
    $sqlconn.Close()
}

Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "SELECT * FROM temppermission"
