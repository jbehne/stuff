Invoke-Sqlcmd -ServerInstance C1DBD500 -Query "ALTER DATABASE [Test] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; EXEC master.dbo.sp_detach_db @dbname = N'Test'"
Copy-Item \\C1DBD500\E$\DATA\MSSQL12.MSSQLSERVER\MSSQL\DATA\Test.mdf C:\Users\Public\Documents
Invoke-Sqlcmd -ServerInstance C1DBD500 -Query "CREATE DATABASE [Test] ON ( FILENAME = N'E:\DATA\MSSQL12.MSSQLSERVER\MSSQL\DATA\Test.mdf' ),( FILENAME = N'E:\DATA\MSSQL12.MSSQLSERVER\MSSQL\DATA\Test_log.ldf' ) FOR ATTACH"


& "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe" C:\Users\Public\Documents\Test.mdf