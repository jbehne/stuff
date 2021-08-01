#XBSPAY

$code = @()

<# Code to generate the code #>
$code += (Invoke-SqlCmd -ServerInstance V01DBSWIN506 -Query "SELECT 'Invoke-SqlCmd -ServerInstance ' + @@servername + ' -Query `"CREATE DATABASE ' + REPLACE(name, 'XBSHUB', 'XBSPAY') + ';`";' FROM sys.databases WHERE name LIKE 'XBSHUB%'").Column1
$code += (Invoke-SqlCmd -ServerInstance V01LSTWIN502 -Query "SELECT 'Invoke-SqlCmd -ServerInstance ' + @@servername + ' -Query `"CREATE DATABASE ' + REPLACE(name, 'XBSHUB', 'XBSPAY') + ';`";' FROM sys.databases WHERE name LIKE 'XBSHUB%'").Column1
$code += (Invoke-SqlCmd -ServerInstance ABPLSTQA01   -Query "SELECT 'Invoke-SqlCmd -ServerInstance ' + @@servername + ' -Query `"CREATE DATABASE ' + REPLACE(name, 'XBSHUB', 'XBSPAY') + ';`";' FROM sys.databases WHERE name LIKE 'XBSHUB%'").Column1
$code += (Invoke-SqlCmd -ServerInstance ABPLSTQA02   -Query "SELECT 'Invoke-SqlCmd -ServerInstance ' + @@servername + ' -Query `"CREATE DATABASE ' + REPLACE(name, 'XBSHUB', 'XBSPAY') + ';`";' FROM sys.databases WHERE name LIKE 'XBSHUB%'").Column1

$code += (Invoke-SqlCmd -ServerInstance V01LSTWIN502 -Query "SELECT 'Invoke-SqlCmd -ServerInstance ' + @@servername + ' -Query `"BACKUP DATABASE ' + REPLACE(name, 'XBSHUB', 'XBSPAY') + ' TO DISK=''E:\' + REPLACE(name, 'XBSHUB', 'XBSPAY') + '_tmp.bak'' WITH COMPRESSION;`";' FROM sys.databases WHERE name LIKE 'XBSHUB%'").Column1
$code += (Invoke-SqlCmd -ServerInstance ABPLSTQA01 -Query "SELECT 'Invoke-SqlCmd -ServerInstance ' + @@servername + ' -Query `"BACKUP DATABASE ' + REPLACE(name, 'XBSHUB', 'XBSPAY') + ' TO DISK=''E:\' + REPLACE(name, 'XBSHUB', 'XBSPAY') + '_tmp.bak'' WITH COMPRESSION;`";' FROM sys.databases WHERE name LIKE 'XBSHUB%'").Column1
$code += (Invoke-SqlCmd -ServerInstance ABPLSTQA02 -Query "SELECT 'Invoke-SqlCmd -ServerInstance ' + @@servername + ' -Query `"BACKUP DATABASE ' + REPLACE(name, 'XBSHUB', 'XBSPAY') + ' TO DISK=''E:\' + REPLACE(name, 'XBSHUB', 'XBSPAY') + '_tmp.bak'' WITH COMPRESSION;`";' FROM sys.databases WHERE name LIKE 'XBSHUB%'").Column1


$code += (Invoke-SqlCmd -ServerInstance V01LSTWIN502 -Query "SELECT 'Invoke-SqlCmd -ServerInstance ' + @@servername + ' -Query `"ALTER AVAILABILITY GROUP ' + (SELECT name FROM sys.availability_groups) + ' ADD DATABASE ' + REPLACE(name, 'XBSHUB', 'XBSPAY') + ';`";' FROM sys.databases WHERE name LIKE 'XBSHUB%'").Column1
$code += (Invoke-SqlCmd -ServerInstance ABPLSTQA01 -Query "SELECT 'Invoke-SqlCmd -ServerInstance ' + @@servername + ' -Query `"ALTER AVAILABILITY GROUP ' + (SELECT name FROM sys.availability_groups) + ' ADD DATABASE ' + REPLACE(name, 'XBSHUB', 'XBSPAY') + ';`";' FROM sys.databases WHERE name LIKE 'XBSHUB%'").Column1
$code += (Invoke-SqlCmd -ServerInstance ABPLSTQA02 -Query "SELECT 'Invoke-SqlCmd -ServerInstance ' + @@servername + ' -Query `"ALTER AVAILABILITY GROUP ' + (SELECT name FROM sys.availability_groups) + ' ADD DATABASE ' + REPLACE(name, 'XBSHUB', 'XBSPAY') + ';`";' FROM sys.databases WHERE name LIKE 'XBSHUB%'").Column1



$code



Invoke-SqlCmd -ServerInstance V01DBSWIN506 -Query "CREATE DATABASE XBSPAYD1;";
Invoke-SqlCmd -ServerInstance V01DBSWIN506 -Query "CREATE DATABASE XBSPAYD2;";
Invoke-SqlCmd -ServerInstance V01DBSWIN506 -Query "CREATE DATABASE XBSPAYD4;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "CREATE DATABASE XBSPAYD3;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "CREATE DATABASE XBSPAYI1;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "CREATE DATABASE XBSPAYI2;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "CREATE DATABASE XBSPAYI4;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "CREATE DATABASE XBSPAYI5;";
Invoke-SqlCmd -ServerInstance V01DBSWIN703 -Query "CREATE DATABASE XBSPAYQ1;";
Invoke-SqlCmd -ServerInstance V01DBSWIN705 -Query "CREATE DATABASE XBSPAYS1;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "BACKUP DATABASE XBSPAYD3 TO DISK='E:\XBSPAYD3_tmp.bak' WITH COMPRESSION;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "BACKUP DATABASE XBSPAYI1 TO DISK='E:\XBSPAYI1_tmp.bak' WITH COMPRESSION;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "BACKUP DATABASE XBSPAYI2 TO DISK='E:\XBSPAYI2_tmp.bak' WITH COMPRESSION;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "BACKUP DATABASE XBSPAYI4 TO DISK='E:\XBSPAYI4_tmp.bak' WITH COMPRESSION;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "BACKUP DATABASE XBSPAYI5 TO DISK='E:\XBSPAYI5_tmp.bak' WITH COMPRESSION;";
Invoke-SqlCmd -ServerInstance V01DBSWIN703 -Query "BACKUP DATABASE XBSPAYQ1 TO DISK='E:\XBSPAYQ1_tmp.bak' WITH COMPRESSION;";
Invoke-SqlCmd -ServerInstance V01DBSWIN705 -Query "BACKUP DATABASE XBSPAYS1 TO DISK='E:\XBSPAYS1_tmp.bak' WITH COMPRESSION;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "ALTER AVAILABILITY GROUP ABPAAGINT01 ADD DATABASE XBSPAYD3;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "ALTER AVAILABILITY GROUP ABPAAGINT01 ADD DATABASE XBSPAYI1;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "ALTER AVAILABILITY GROUP ABPAAGINT01 ADD DATABASE XBSPAYI2;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "ALTER AVAILABILITY GROUP ABPAAGINT01 ADD DATABASE XBSPAYI4;";
Invoke-SqlCmd -ServerInstance V01DBSWIN503 -Query "ALTER AVAILABILITY GROUP ABPAAGINT01 ADD DATABASE XBSPAYI5;";
Invoke-SqlCmd -ServerInstance V01DBSWIN703 -Query "ALTER AVAILABILITY GROUP ABPAAGQA01 ADD DATABASE XBSPAYQ1;";
Invoke-SqlCmd -ServerInstance V01DBSWIN705 -Query "ALTER AVAILABILITY GROUP ABPAAGQA02 ADD DATABASE XBSPAYS1;";

XBSPAYD1
XBSPAYD2
XBSPAYD4
XBSPAYD3
XBSPAYI1
XBSPAYI2
XBSPAYI4
XBSPAYI5
XBSPAYQ1
XBSPAYS1