USE [msdb]
GO


EXEC msdb.dbo.sp_add_job @job_name=N'Maintenance - IndexOptimize', 
		@description=N'Source: https://ola.hallengren.com', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'CCsaid'


EXEC msdb.dbo.sp_add_jobserver @job_name=N'Maintenance - IndexOptimize', @server_name = N'(local)'
		

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Maintenance - IndexOptimize', @step_name=N'IndexOptimize - USER_DATABASES', 
		@command=N'EXECUTE [dbo].[IndexOptimize]
			@Databases = ''ALL_DATABASES'',
			@FragmentationLow = NULL,
			@FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_OFFLINE'',
			@FragmentationHigh = ''INDEX_REBUILD_OFFLINE'',
			@FragmentationLevel1 = 5,
			@FragmentationLevel2 = 30,
			@UpdateStatistics = ''ALL'',
			@OnlyModifiedStatistics = ''Y'',
			@StatisticsSample = 100', 
		@database_name=N'SQLADMIN'


EXEC msdb.dbo.sp_add_jobschedule @job_name=N'Maintenance - IndexOptimize', @name=N'Daily 12am', 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@active_start_date=20190101, 
		@active_start_time=0




