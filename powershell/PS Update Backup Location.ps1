Invoke-SqlCmd -ServerInstance V05APPWIN001       -Database SQLADMIN -Query "SELECT * FROM Backup_DefaultLocation"
Invoke-SqlCmd -ServerInstance V06APPWIN003       -Database SQLADMIN -Query "SELECT * FROM Backup_DefaultLocation"






New-Item -ItemType Directory -Path \\s01ddaesd001d\01_sqlprodcifs\C1APP309    
New-Item -ItemType Directory -Path \\s01ddaesd001d\01_sqlprodcifs\C2APP003    
New-Item -ItemType Directory -Path \\s01ddaesd001d\01_sqlprodcifs\C2APP004    
New-Item -ItemType Directory -Path \\s01ddaesd001d\01_sqlprodcifs\V00DBSWIN001
New-Item -ItemType Directory -Path \\s01ddaesd001d\01_sqlprodcifs\V01DBSWIN302
New-Item -ItemType Directory -Path 



#$query = "UPDATE Backup_DefaultLocation SET BackupLocation = REPLACE(BackupLocation, '\\s01ddaesd001d\01_sqltestcifs', '\\m1-bak-10-dd\m1_sql_test')"
#$query = "UPDATE Backup_DefaultLocation SET BackupLocation = REPLACE(BackupLocation, '\\s01ddaesd001d\01_sqlqacifs', '\\m1-bak-10-dd\m1_sql_qa')"
#$query = "UPDATE Backup_DefaultLocation SET BackupLocation = REPLACE(BackupLocation, '\\s01ddaesd001d\01_sqltestcifs', '\\blm-bak-10-dd\sql_test')"
#$query = "UPDATE Backup_DefaultLocation SET BackupLocation = REPLACE(BackupLocation, '\\s01ddaesd001d\01_sqlqacifs', '\\blm-bak-10-dd\sql_qa')"
#$query = "UPDATE Backup_DefaultLocation SET BackupLocation = REPLACE(BackupLocation, '\\s01ddaesd001d\01_sqlprodcifs', '\\blm-bak-10-dd\sql_prod')"
#$query = "UPDATE Backup_DefaultLocation SET BackupLocation = REPLACE(BackupLocation, '\\s01ddaesd001d\01_sqlprodcifs', '\\m1-bak-10-dd\m1_sql_prod')"
#$query = "UPDATE Backup_DefaultLocation SET BackupLocation = REPLACE(BackupLocation, '\\blm-bak-10-dd\sql_qa', '\\s01ddaesd001d\01_sqlqacifs')"
#$query = "UPDATE Backup_DefaultLocation SET BackupLocation = REPLACE(BackupLocation, '\\blm-bak-10-dd\sql_test', '\\s01ddaesd001d\01_sqltestcifs')"
$query = "UPDATE Backup_DefaultLocation SET BackupLocation = REPLACE(BackupLocation, '\\blm-bak-10-dd\sql_prod', '\\s01ddaesd001d\01_sqlprodcifs')"


Invoke-SqlCmd -ServerInstance V00DBSWIN001     -Database SQLADMIN -Query $query



Invoke-SqlCmd -ServerInstance C1APP309      -Database SQLADMIN -Query "SELECT * FROM Backup_Options"
Invoke-SqlCmd -ServerInstance C2APP003      -Database SQLADMIN -Query "SELECT * FROM Backup_Options"
Invoke-SqlCmd -ServerInstance C2APP004      -Database SQLADMIN -Query "SELECT * FROM Backup_Options"
Invoke-SqlCmd -ServerInstance V00DBSWIN001  -Database SQLADMIN -Query "SELECT * FROM Backup_Options"
Invoke-SqlCmd -ServerInstance V01DBSWIN302  -Database SQLADMIN -Query "SELECT * FROM Backup_Options"

Invoke-SqlCmd -ServerInstance V01DBSWIN302  -Database SQLADMIN -Query "SELECT * FROM Backup_Options"
Invoke-SqlCmd -ServerInstance V01DBSWIN302  -Database SQLADMIN -Query "SELECT * FROM Backup_Options"



$query = "UPDATE Backup_Options SET BackupLocation = REPLACE(BackupLocation, '\\s01ddaesd001d\01_sqlqacifs', '\\m1-bak-10-dd\m1_sql_qa')"
$query = "UPDATE Backup_Options SET BackupLocation = REPLACE(BackupLocation, '\\s01ddaesd001d\01_sqltestcifs', '\\blm-bak-10-dd\sql_test')"
$query = "UPDATE Backup_Options SET BackupLocation = REPLACE(BackupLocation, '\\s01ddaesd001d\01_sqlqacifs', '\\blm-bak-10-dd\sql_qa')"
$query = "UPDATE Backup_Options SET BackupLocation = REPLACE(BackupLocation, '\\blm-bak-10-dd\sql_qa', '\\s01ddaesd001d\01_sqlqacifs')"
$query = "UPDATE Backup_Options SET BackupLocation = REPLACE(BackupLocation, '\\blm-bak-10-dd\sql_test', '\\s01ddaesd001d\01_sqltestcifs')"

Invoke-SqlCmd -ServerInstance C1DBD705     -Database SQLADMIN -Query $query


