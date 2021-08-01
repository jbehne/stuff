$query = "SELECT DISTINCT SRVR_NM 
FROM CCDB2.MDB_DB_DATA
WHERE DBMS = 'SQL'
AND DB_STAT IN ('TEST', 'QA');"
$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=SERVINFO;uid=ID93137;pwd=J1pDV2Aa"
$conn.Open()
$cmd = New-object System.Data.Odbc.OdbcCommand($query,$conn)

$ds = New-Object System.Data.DataSet 
$adapter = New-Object System.Data.odbc.OdbcDataAdapter($cmd) 
$adapter.Fill($ds) | Out-Null

$ds.Tables[0] | Format-Table

$conn.Close()



Invoke-Sqlcmd -ServerInstance C1DBD069 -Query "SELECT * FROM OPENQUERY('
SELECT DISTINCT SRVR_NM 
FROM CCDB2.MDB_DB_DATA
WHERE DBMS = ''SQL''
AND DB_STAT IN (''TEST'', ''QA'')')"


<#
SELECT a.SRVR_NM, a.DB_NM, c.DBMS_VER, b.BACKUP_GRP,
START_AFTER_TIME,
NUM_THREADS,
NUM_DAYS_RECOV,
GRP_COMMENTS,
FREQUENCY_COMMENT,
NUM_BCKPS_MNTND
FROM CCDB2.MDB_DB_DATA a
INNER JOIN CCDB2.MDB_BACKUP_GROUP b ON a.BACKUP_GRP = b.BACKUP_GRP
INNER JOIN CCDB2.MDB_DBMS_DATA c ON c.SRVR_NM = a.SRVR_NM
WHERE c.DBMS = 'SQL'


#>