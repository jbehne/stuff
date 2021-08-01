USE [msdb];
GO

ALTER PROC usp_UpdateEAPCredential (@password varchar(128))
AS
BEGIN
	DECLARE @cmd nvarchar(1028);
	SET @cmd = 'ALTER CREDENTIAL [z_eapp] WITH IDENTITY = N''ALLIANCE\z_eapp'', SECRET = N''' + @password + ''';';
	EXEC (@cmd);
	EXEC sp_start_job @job_name = 'Test z_eapp Credential';
END;
GO


SELECT * FROM sys.credentials

/*
IF NOT EXISTS (SELECT * FROM sys.sysusers WHERE name = 'z_eapp')
	CREATE USER [z_eapp] FROM LOGIN [z_eapp];
GO

USE [msdb]
GO
GRANT EXECUTE ON usp_UpdateEAPCredential TO [z_eapp];
GO
USE master
GRANT ALTER ANY CREDENTIAL TO [z_eapp];
GO


USE [msdb]
GO
CREATE USER [z_eapp] FOR LOGIN [z_eapp]
GO
USE [msdb]
GO
--EXEC sp_addrolemember N'SQLAgentUserRole', N'z_eapp'
GO
GRANT EXECUTE ON sp_start_job TO z_eapp
GO
EXEC msdb.dbo.sp_grant_login_to_proxy @proxy_name=N'z_Eapp', @login_name=N'z_eapp'
GO
*/




	EXECUTE AS USER = 'z_eapp';
	USE [msdb]
	EXEC usp_UpdateEAPCredential '';
	
	--EXEC msdb..sp_start_job @job_name = 'Test zt_eapp Credential';
	REVERT;


*/