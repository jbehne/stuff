/*
	Default backup schedule:
	FULL - occurs once a week starting at a set day/hour
	DIFF - occurs 6 times a week on the same hour as FULL
	LOG - occurs every 2 hours bases on the FULL hour - if FULL is even, LOG starts odd and vice versa

	@freq_type
	1	Once
	4	Daily
	8	Weekly

	@freq_interval
	if @freq_type = 1 (once)	frequency_interval is unused.
	if @freq_type = 4 (daily)	Every frequency_interval days.
	if @freq_type = 8 (weekly)	frequency_interval is one or more of the following (combined with an OR logical operator):
		1 = Sunday
		2 = Monday
		4 = Tuesday
		8 = Wednesday
		16 = Thursday
		32 = Friday
		64 = Saturday
		(127 total)

	@freq_subday_type
	1	At the specified time
	4	Minutes
	8	Hours

	@freq_subday_interval
	if @freq_subday_type = 4 then every X minutes
	if @freq_subday_type = 8 then every X hours

	@active_start_date 
	Date on which job execution can begin. The date is formatted as YYYYMMDD.

	@active_start_time
	The time is formatted as HHMMSS on a 24-hour clock.

	@active_end_time
	The time is formatted as HHMMSS on a 24-hour clock.

*/

-- Line 46 has the values to be passed in
DECLARE @day varchar(24) = 'MONDAY', @fullstarttime char(6) = '050000', @diffstarttime char(6) = '200000';
DECLARE @full_freq_interval tinyint, @full_active_start_time int, @fullTSQL varchar(max);
DECLARE @diff_freq_interval tinyint = 127, @diff_active_start_time int, @diffTSQL varchar(max);
DECLARE @log_active_start_time int, @logTSQL varchar(max);
DECLARE @offset int;

SELECT @full_freq_interval =
	CASE @day
	WHEN 'SUNDAY' THEN 1
	WHEN 'MONDAY' THEN 2
	WHEN 'TUESDAY' THEN 4
	WHEN 'WEDNESDAY' THEN 8
	WHEN 'THURSDAY' THEN 16
	WHEN 'FRIDAY' THEN 32
	WHEN 'SATURDAY' THEN 64 END;

SELECT @diff_freq_interval = @diff_freq_interval - @full_freq_interval;
SELECT @full_active_start_time = CAST(@fullstarttime AS int);
SELECT @diff_active_start_time = CAST(@diffstarttime AS int);

IF (SELECT CAST(SUBSTRING(@fullstarttime, 1, 2) AS int) % 2) > 0
	SELECT @log_active_start_time = 0;
ELSE
	SELECT @log_active_start_time = 010000;

SELECT @offset = 
	CASE ABS(CHECKSUM(NEWID()) % 3) + 1
	WHEN 1 THEN 0
	WHEN 2 THEN 1500
	WHEN 3 THEN 3000
	ELSE 4500 END;

SELECT @full_active_start_time = @full_active_start_time + @offset
SELECT @diff_active_start_time = @diff_active_start_time + @offset
SELECT @log_active_start_time = @log_active_start_time + @offset


SELECT @fullTSQL = '
EXEC msdb.dbo.sp_add_jobschedule @job_name = ''Maintenance - Backup FULL'', @name=N''' + @day + ' ' + CAST(@full_active_start_time AS varchar(8)) + ''', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=' + CAST(@full_freq_interval AS varchar(8)) + ',  
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190101, 
		@active_end_date=99991231, 
		@active_start_time=' + CAST(@full_active_start_time AS varchar(8)) + ',  
		@active_end_time=235959
'

SELECT @diffTSQL = '
EXEC msdb.dbo.sp_add_jobschedule @job_name=''Maintenance - Backup DIFF'', @name=N''Daily (Except ' + @day + ') ' + CAST(@diff_active_start_time AS varchar(8)) + ''', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=' + CAST(@diff_freq_interval AS varchar(8)) + ', 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190101, 
		@active_end_date=99991231, 
		@active_start_time=' + CAST(@diff_active_start_time AS varchar(8)) + ', 
		@active_end_time=235959'

SELECT @logTSQL = '
EXEC msdb.dbo.sp_add_jobschedule @job_name=''Maintenance - Backup LOG'', @name=N''Every 2 hours'', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=2, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190228, 
		@active_end_date=99991231, 
		@active_start_time=' + CAST(@log_active_start_time AS varchar(8)) + ',  
		@active_end_time=235959
'

PRINT @fullTSQL
PRINT @diffTSQL
PRINT @logTSQL

/*
USE [msdb]
GO


EXEC msdb.dbo.sp_add_jobschedule @job_name='Maintenance - Backup DIFF', @name=N'Daily 6am', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=125, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190228, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959

EXEC msdb.dbo.sp_add_jobschedule @job_name = 'Maintenance - Backup FULL', @name=N'Monday 6am', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=2, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190228, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959

EXEC msdb.dbo.sp_add_jobschedule @job_name='Maintenance - Backup LOG', @name=N'Every 2 hours', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=2, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190228, 
		@active_end_date=99991231, 
		@active_start_time=10000, 
		@active_end_time=235959

*/