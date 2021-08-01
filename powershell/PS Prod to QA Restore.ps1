Export-DbaUser -SqlInstance C1DBD725 -Database SAMDB0Q1 -FilePath C:\users\Public\Documents\Users\SAMDB0Q1.txt
Invoke-SqlCmd -ServerInstance C1DBD065 -Query "BACKUP DATABASE SAMDB0P1 TO DISK = '\\s01ddaesd001d\01_sqlprodcifs\C1DBD065\SAMDB0P1.bak' WITH COMPRESSION, COPY_ONLY" -QueryTimeout 0
Invoke-SqlCmd -ServerInstance C1DBD725 -Query "ALTER DATABASE SAMDB0Q1 SET SINGLE_USER; DROP DATABASE SAMDB0Q1;" -QueryTimeout 0
Invoke-SqlCmd -ServerInstance C1DBD725 -Query "RESTORE DATABASE SAMDB0Q1 FROM DISK = '\\s01ddaesd001d\01_sqlprodcifs\C1DBD065\SAMDB0P1.bak'" -QueryTimeout 0
$dropusers = Invoke-SqlCmd -ServerInstance C1DBD725 -Database SAMDB0Q1 -Query "SELECT name FROM sys.sysusers WHERE issqlrole = 0 AND UID > 4"
foreach ($u in $dropusers)
{
    Invoke-SqlCmd -ServerInstance C1DBD725 -Database SAMDB0Q1 -Query "DROP USER [$($u.name)]"
    $u
}
Invoke-SqlCmd -ServerInstance C1DBD725 -Database SAMDB0Q1 -InputFile C:\users\Public\Documents\Users\SAMDB0Q1.txt