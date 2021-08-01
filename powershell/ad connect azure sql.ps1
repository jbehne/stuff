$query = "SELECT 1"
$Username = "ID93137@countryfinancial.com"
$Password = "M9snYEaL"
$Database = "sbtestdb001"
$Server = 'sb-database-sql-001.database.windows.net'
$Port = 1433

$cxnString = "Server=$Server;Authentication=Active Directory Password;UID=$UserName;PWD=$Password;Database=$Database"
$cxn = New-Object System.Data.SqlClient.SqlConnection($cxnString)
$cxn.Open()
$cmd = New-Object System.Data.SqlClient.SqlCommand($query, $cxn)
$cmd.CommandTimeout = 120
$ds = New-Object System.Data.DataSet 
$adapter = New-Object System.Data.SqlClient.SQLDataAdapter($cmd) 
$adapter.Fill($ds) | Out-Null
$ds.Tables[0]
$cxn.Close()