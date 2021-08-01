USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name='Maintenance - Backup - AAG USER_DATABASES - FULL', @name=N'Wed night', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=8, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190129, 
		@active_end_date=99991231, 
		@active_start_time=200000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO

DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name='Maintenance - Backup - AAG USER_DATABASES - FULL', @name=N'Sunday afternoon', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190129, 
		@active_end_date=99991231, 
		@active_start_time=130000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO

DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name='Maintenance - Backup - AAG USER_DATABASES - LOG', @name=N'MTuThFSa Log', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=118, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190129, 
		@active_end_date=99991231, 
		@active_start_time=200000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO

DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'Maintenance - Backup - ALL_DATABASES - FULL', @name=N'9pm Non AAG Backup', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=42, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190129, 
		@active_end_date=99991231, 
		@active_start_time=210000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO

DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'Maintenance - IndexOptimize - AAG USER_DATABASES', @name=N'Weeknights 10pm', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=62, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190129, 
		@active_end_date=99991231, 
		@active_start_time=220000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO

DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'Maintenance - IndexOptimize - USER_DATABASES', @name=N'Weeknights 10:30pm', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=62, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190129, 
		@active_end_date=99991231, 
		@active_start_time=223000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO

DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name='Maintenance - IntegrityCheck - AAG USER_DATABASES', @name=N'Sunday 9pm', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190129, 
		@active_end_date=99991231, 
		@active_start_time=210000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO

DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name='Maintenance - IntegrityCheck - SYSTEM_DATABASES', @name=N'Sunday 11pm', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190129, 
		@active_end_date=99991231, 
		@active_start_time=230000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO
