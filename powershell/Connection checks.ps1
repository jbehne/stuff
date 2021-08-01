$query = "SELECT DISTINCT SRVR_NM 
FROM CCDB2.MDB_DB_DATA
WHERE DBMS = 'SQL'
AND DB_STAT IN ('PROD');"
$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=SERVINFO;uid=OC96322;pwd=nMC0Ct3C"
$conn.Open()
$cmd = New-object System.Data.Odbc.OdbcCommand($query,$conn)

$ds = New-Object System.Data.DataSet 
$adapter = New-Object System.Data.odbc.OdbcDataAdapter($cmd) 
$adapter.Fill($ds) | Out-Null

$ds.Tables[0] | Format-Table

$conn.Close()

foreach ($s in $ds.Tables[0].Rows)
{
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = " + $s.SRVR_NM + "; Database = master; Integrated Security = True;"
    try
    {
        $SqlConnection.Open()
        $SqlConnection.Close()
    }

    catch
    {
        $s.SRVR_NM + " failed to connect."
    }
}