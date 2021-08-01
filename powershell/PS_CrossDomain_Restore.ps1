# script directory
New-Item -ItemType Directory C:\Users\Public\Documents\Users

# server and database to replace
$destinationserver = "C1DBD516"
$destinationdatabase = "OCGCGII1"

# dump the users to a file
Export-DbaUser -SqlInstance $destinationserver -Database $destinationdatabase -Path "C:\Users\Public\Documents\Users\$destinationdatabase.txt"

# server and database to restore from
$hostserver = "C1DBD035"
$hostdatabase = "OCGCGIP1"

# get the latest full backup
$file = (Get-ChildItem "\\s01ddaesd001d\01_sqlprodcifs\$hostserver\$hostdatabase" | Where Name -Like "*FULL*" | Sort LastWriteTime | Select -last 1).FullName

# build the restore command (***NOTE - fix the logical file names!!!***)
$restore = "
RESTORE DATABASE [$destinationdatabase] FROM  
DISK = N'$file' 
WITH  FILE = 1,  
MOVE N'OCGCGIP1' TO N'L:\data\$destinationdatabase.mdf',  
MOVE N'OCGCGIP1_log' TO N'M:\data\$destinationdatabase`_log.ldf',  NOUNLOAD,  STATS = 5"

# drop destination database
Invoke-Sqlcmd -ServerInstance $destinationserver -Query "DROP DATABASE [$destinationdatabase]"

# execute restore command
Invoke-Sqlcmd -ServerInstance $destinationserver -Query $restore
$users = (Invoke-Sqlcmd -ServerInstance $destinationserver -Database $destinationdatabase -Query "SELECT * FROM sysusers WHERE hasdbaccess = 1 AND name <> 'dbo'").name
foreach ($user in $users)
{
    Invoke-Sqlcmd -ServerInstance $destinationserver -Database $destinationdatabase -Query "DROP SCHEMA [$user]"
    Invoke-Sqlcmd -ServerInstance $destinationserver -Database $destinationdatabase -Query "DROP USER [$user]"
}
Invoke-Sqlcmd -ServerInstance $destinationserver -Database $destinationdatabase -InputFile "C:\Users\Public\Documents\Users\$destinationdatabase.txt"