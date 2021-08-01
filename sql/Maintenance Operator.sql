USE [msdb]
GO
EXEC msdb.dbo.sp_add_operator @name=N'SQLTEAM', 
		@enabled=1, 
		@pager_days=0, 
		@email_address=N'sqlteam@countryfinancial.com'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name='Maintenance - Backup - AAG USER_DATABASES - FULL',
		@notify_level_email=2, 
		@notify_level_page=2, 
		@notify_email_operator_name=N'SQLTEAM'
GO

EXEC msdb.dbo.sp_update_job @job_name='Maintenance - Backup - AAG USER_DATABASES - LOG',
		@notify_level_email=2, 
		@notify_level_page=2, 
		@notify_email_operator_name=N'SQLTEAM'
		EXEC msdb.dbo.sp_update_job @job_name='Maintenance - Backup - ALL_DATABASES - FULL',
		@notify_level_email=2, 
		@notify_level_page=2, 
		@notify_email_operator_name=N'SQLTEAM'
		EXEC msdb.dbo.sp_update_job @job_name='Maintenance - IndexOptimize - AAG USER_DATABASES',
		@notify_level_email=2, 
		@notify_level_page=2, 
		@notify_email_operator_name=N'SQLTEAM'
		EXEC msdb.dbo.sp_update_job @job_name='Maintenance - IndexOptimize - USER_DATABASES',
		@notify_level_email=2, 
		@notify_level_page=2, 
		@notify_email_operator_name=N'SQLTEAM'
		EXEC msdb.dbo.sp_update_job @job_name='Maintenance - IntegrityCheck - AAG USER_DATABASES',
		@notify_level_email=2, 
		@notify_level_page=2, 
		@notify_email_operator_name=N'SQLTEAM'
		EXEC msdb.dbo.sp_update_job @job_name='Maintenance - IntegrityCheck - SYSTEM_DATABASES',
				@notify_level_email=2, 
		@notify_level_page=2, 
		@notify_email_operator_name=N'SQLTEAM'