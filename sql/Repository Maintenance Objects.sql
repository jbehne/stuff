USE SQLMONITOR;
GO

IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Maintenance_Window')
	DROP TABLE Maintenance_Window;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Maintenance_BackupOptions')
	DROP TABLE Maintenance_BackupOptions;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Maintenance_BackupSchedule_Full')
	DROP TABLE Maintenance_BackupSchedule_Full;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Maintenance_BackupSchedule_Diff')
	DROP TABLE Maintenance_BackupSchedule_Diff;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Maintenance_BackupSchedule_Log')
	DROP TABLE Maintenance_BackupSchedule_Log;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Maintenance_Schedule_Stage')
	DROP TABLE Maintenance_Schedule_Stage;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_Maintenance_MergeSchedules')
	DROP PROC usp_Maintenance_MergeSchedules;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'vw_Maintenance_BackupSchedule_Full')
	DROP VIEW vw_Maintenance_BackupSchedule_Full;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'vw_Maintenance_BackupSchedule_Diff')
	DROP VIEW vw_Maintenance_BackupSchedule_Diff;
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'vw_Maintenance_BackupSchedule_Log')
	DROP VIEW vw_Maintenance_BackupSchedule_Log;	

-- Start and end time of maintenance window
CREATE TABLE Maintenance_Window (InstanceID smallint, StartTime smalldatetime, EndTime smalldatetime);
GO
CREATE CLUSTERED INDEX CIX_Maintenance_Window ON Maintenance_Window (InstanceID) WITH (DATA_COMPRESSION=PAGE);
GO

-- Backup options
CREATE TABLE Maintenance_BackupOptions (InstanceID smallint, DatabaseName varchar(1024), BackupLocation varchar(2048), 
	FullBackupFiles smallint, DiffBackupFiles smallint, LogBackupFiles smallint, Compressed char(1));
GO
CREATE CLUSTERED INDEX CIX_Maintenance_BackupOptions ON Maintenance_BackupOptions (InstanceID) WITH (DATA_COMPRESSION=PAGE);
GO

-- Job schedule of backups
CREATE TABLE Maintenance_BackupSchedule_Full (InstanceID smallint, JobEnabled bit, ScheduleEnabled bit, 
freq_type smallint, freq_interval smallint, freq_subday_type smallint, 
freq_subday_interval smallint, freq_relative_interval smallint, freq_recurrence_factor smallint,
active_start_time int, active_end_time int);
GO
CREATE CLUSTERED INDEX CIX_Maintenance_BackupSchedule_Full ON Maintenance_BackupSchedule_Full (InstanceID) WITH (DATA_COMPRESSION=PAGE);
GO
CREATE TABLE Maintenance_BackupSchedule_Diff (InstanceID smallint, JobEnabled bit, ScheduleEnabled bit,  
freq_type smallint, freq_interval smallint, freq_subday_type smallint, 
freq_subday_interval smallint, freq_relative_interval smallint, freq_recurrence_factor smallint,
active_start_time int, active_end_time int);
GO
CREATE CLUSTERED INDEX CIX_Maintenance_BackupSchedule_Diff ON Maintenance_BackupSchedule_Diff (InstanceID) WITH (DATA_COMPRESSION=PAGE);
GO
CREATE TABLE Maintenance_BackupSchedule_Log (InstanceID smallint, JobEnabled bit, ScheduleEnabled bit,  
freq_type smallint, freq_interval smallint, freq_subday_type smallint, 
freq_subday_interval smallint, freq_relative_interval smallint, freq_recurrence_factor smallint,
active_start_time int, active_end_time int);
GO
CREATE CLUSTERED INDEX CIX_Maintenance_BackupSchedule_Log ON Maintenance_BackupSchedule_Log (InstanceID) WITH (DATA_COMPRESSION=PAGE);
GO

CREATE TABLE Maintenance_Schedule_Stage (InstanceID smallint, JobType varchar(128), JobEnabled bit, ScheduleEnabled bit,  
freq_type smallint, freq_interval smallint, freq_subday_type smallint, 
freq_subday_interval smallint, freq_relative_interval smallint, freq_recurrence_factor smallint,
active_start_time int, active_end_time int);
GO
CREATE CLUSTERED INDEX CIX_Maintenance_Schedule_Stage ON Maintenance_Schedule_Stage (InstanceID) WITH (DATA_COMPRESSION=PAGE);
GO

CREATE PROC usp_Maintenance_MergeSchedules
AS
BEGIN
	TRUNCATE TABLE Maintenance_BackupSchedule_Full;
	
	INSERT Maintenance_BackupSchedule_Full
	SELECT InstanceID, JobEnabled, ScheduleEnabled, freq_type, freq_interval, freq_subday_type
		, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_time, active_end_time 
	FROM Maintenance_Schedule_Stage WHERE JobType = 'Backup FULL';

	TRUNCATE TABLE Maintenance_BackupSchedule_Diff;
	
	INSERT Maintenance_BackupSchedule_Diff
	SELECT InstanceID, JobEnabled, ScheduleEnabled, freq_type, freq_interval, freq_subday_type
		, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_time, active_end_time 
	FROM Maintenance_Schedule_Stage WHERE JobType = 'Backup DIFF';

	TRUNCATE TABLE Maintenance_BackupSchedule_Log;
	
	INSERT Maintenance_BackupSchedule_Log
	SELECT InstanceID, JobEnabled, ScheduleEnabled, freq_type, freq_interval, freq_subday_type
		, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_time, active_end_time 
	FROM Maintenance_Schedule_Stage WHERE JobType = 'Backup LOG';
END
GO


CREATE VIEW vw_Maintenance_BackupSchedule_Full
AS
SELECT 
	ServerName,
    CASE [jobenabled]
        WHEN 1 THEN 'Yes'
        WHEN 0 THEN 'No'
      END AS [JobEnabled],
    CASE [scheduleenabled]
        WHEN 1 THEN 'Yes'
        WHEN 0 THEN 'No'
      END AS [ScheduleEnabled]
    , CASE 
        WHEN [freq_type] = 64 THEN 'Start automatically when SQL Server Agent starts'
        WHEN [freq_type] = 128 THEN 'Start whenever the CPUs become idle'
        WHEN [freq_type] IN (4,8,16,32) THEN 'Recurring'
        WHEN [freq_type] = 1 THEN 'One Time'
      END [ScheduleType]
    , CASE [freq_type]
        WHEN 1 THEN 'One Time'
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly'
        WHEN 16 THEN 'Monthly'
        WHEN 32 THEN 'Monthly - Relative to Frequency Interval'
        WHEN 64 THEN 'Start automatically when SQL Server Agent starts'
        WHEN 128 THEN 'Start whenever the CPUs become idle'
      END [Occurrence]
    , CASE [freq_type]
        WHEN 4 THEN 'Occurs every ' + CAST([freq_interval] AS VARCHAR(3)) + ' day(s)'
        WHEN 8 THEN 'Occurs every ' + CAST([freq_recurrence_factor] AS VARCHAR(3)) 
                    + ' week(s) on '
                    + CASE WHEN [freq_interval] & 1 = 1 THEN 'Sunday' ELSE '' END
                    + CASE WHEN [freq_interval] & 2 = 2 THEN ', Monday' ELSE '' END
                    + CASE WHEN [freq_interval] & 4 = 4 THEN ', Tuesday' ELSE '' END
                    + CASE WHEN [freq_interval] & 8 = 8 THEN ', Wednesday' ELSE '' END
                    + CASE WHEN [freq_interval] & 16 = 16 THEN ', Thursday' ELSE '' END
                    + CASE WHEN [freq_interval] & 32 = 32 THEN ', Friday' ELSE '' END
                    + CASE WHEN [freq_interval] & 64 = 64 THEN ', Saturday' ELSE '' END
        WHEN 16 THEN 'Occurs on Day ' + CAST([freq_interval] AS VARCHAR(3)) 
                     + ' of every '
                     + CAST([freq_recurrence_factor] AS VARCHAR(3)) + ' month(s)'
        WHEN 32 THEN 'Occurs on '
                     + CASE [freq_relative_interval]
                        WHEN 1 THEN 'First'
                        WHEN 2 THEN 'Second'
                        WHEN 4 THEN 'Third'
                        WHEN 8 THEN 'Fourth'
                        WHEN 16 THEN 'Last'
                       END
                     + ' ' 
                     + CASE [freq_interval]
                        WHEN 1 THEN 'Sunday'
                        WHEN 2 THEN 'Monday'
                        WHEN 3 THEN 'Tuesday'
                        WHEN 4 THEN 'Wednesday'
                        WHEN 5 THEN 'Thursday'
                        WHEN 6 THEN 'Friday'
                        WHEN 7 THEN 'Saturday'
                        WHEN 8 THEN 'Day'
                        WHEN 9 THEN 'Weekday'
                        WHEN 10 THEN 'Weekend day'
                       END
                     + ' of every ' + CAST([freq_recurrence_factor] AS VARCHAR(3)) 
                     + ' month(s)'
      END AS [Recurrence]
    , CASE [freq_subday_type]
        WHEN 1 THEN 'Occurs once at ' 
                    + STUFF(
                 STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 2 THEN 'Occurs every ' 
                    + CAST([freq_subday_interval] AS VARCHAR(3)) + ' Second(s) between ' 
                    + STUFF(
                   STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 4 THEN 'Occurs every ' 
                    + CAST([freq_subday_interval] AS VARCHAR(3)) + ' Minute(s) between ' 
                    + STUFF(
                   STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 8 THEN 'Occurs every ' 
                    + CAST([freq_subday_interval] AS VARCHAR(3)) + ' Hour(s) between ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
      END [Frequency]
FROM Maintenance_BackupSchedule_Full bsf
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = bsf.InstanceID

GO

CREATE VIEW vw_Maintenance_BackupSchedule_Diff
AS
SELECT 
	ServerName,
    CASE [jobenabled]
        WHEN 1 THEN 'Yes'
        WHEN 0 THEN 'No'
      END AS [JobEnabled],
    CASE [scheduleenabled]
        WHEN 1 THEN 'Yes'
        WHEN 0 THEN 'No'
      END AS [ScheduleEnabled]
    , CASE 
        WHEN [freq_type] = 64 THEN 'Start automatically when SQL Server Agent starts'
        WHEN [freq_type] = 128 THEN 'Start whenever the CPUs become idle'
        WHEN [freq_type] IN (4,8,16,32) THEN 'Recurring'
        WHEN [freq_type] = 1 THEN 'One Time'
      END [ScheduleType]
    , CASE [freq_type]
        WHEN 1 THEN 'One Time'
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly'
        WHEN 16 THEN 'Monthly'
        WHEN 32 THEN 'Monthly - Relative to Frequency Interval'
        WHEN 64 THEN 'Start automatically when SQL Server Agent starts'
        WHEN 128 THEN 'Start whenever the CPUs become idle'
      END [Occurrence]
    , CASE [freq_type]
        WHEN 4 THEN 'Occurs every ' + CAST([freq_interval] AS VARCHAR(3)) + ' day(s)'
        WHEN 8 THEN 'Occurs every ' + CAST([freq_recurrence_factor] AS VARCHAR(3)) 
                    + ' week(s) on '
                    + CASE WHEN [freq_interval] & 1 = 1 THEN 'Sunday' ELSE '' END
                    + CASE WHEN [freq_interval] & 2 = 2 THEN ', Monday' ELSE '' END
                    + CASE WHEN [freq_interval] & 4 = 4 THEN ', Tuesday' ELSE '' END
                    + CASE WHEN [freq_interval] & 8 = 8 THEN ', Wednesday' ELSE '' END
                    + CASE WHEN [freq_interval] & 16 = 16 THEN ', Thursday' ELSE '' END
                    + CASE WHEN [freq_interval] & 32 = 32 THEN ', Friday' ELSE '' END
                    + CASE WHEN [freq_interval] & 64 = 64 THEN ', Saturday' ELSE '' END
        WHEN 16 THEN 'Occurs on Day ' + CAST([freq_interval] AS VARCHAR(3)) 
                     + ' of every '
                     + CAST([freq_recurrence_factor] AS VARCHAR(3)) + ' month(s)'
        WHEN 32 THEN 'Occurs on '
                     + CASE [freq_relative_interval]
                        WHEN 1 THEN 'First'
                        WHEN 2 THEN 'Second'
                        WHEN 4 THEN 'Third'
                        WHEN 8 THEN 'Fourth'
                        WHEN 16 THEN 'Last'
                       END
                     + ' ' 
                     + CASE [freq_interval]
                        WHEN 1 THEN 'Sunday'
                        WHEN 2 THEN 'Monday'
                        WHEN 3 THEN 'Tuesday'
                        WHEN 4 THEN 'Wednesday'
                        WHEN 5 THEN 'Thursday'
                        WHEN 6 THEN 'Friday'
                        WHEN 7 THEN 'Saturday'
                        WHEN 8 THEN 'Day'
                        WHEN 9 THEN 'Weekday'
                        WHEN 10 THEN 'Weekend day'
                       END
                     + ' of every ' + CAST([freq_recurrence_factor] AS VARCHAR(3)) 
                     + ' month(s)'
      END AS [Recurrence]
    , CASE [freq_subday_type]
        WHEN 1 THEN 'Occurs once at ' 
                    + STUFF(
                 STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 2 THEN 'Occurs every ' 
                    + CAST([freq_subday_interval] AS VARCHAR(3)) + ' Second(s) between ' 
                    + STUFF(
                   STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 4 THEN 'Occurs every ' 
                    + CAST([freq_subday_interval] AS VARCHAR(3)) + ' Minute(s) between ' 
                    + STUFF(
                   STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 8 THEN 'Occurs every ' 
                    + CAST([freq_subday_interval] AS VARCHAR(3)) + ' Hour(s) between ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
      END [Frequency]
FROM Maintenance_BackupSchedule_Diff bsf
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = bsf.InstanceID

Go


CREATE VIEW vw_Maintenance_BackupSchedule_Log
AS
SELECT 
	ServerName,
    CASE [jobenabled]
        WHEN 1 THEN 'Yes'
        WHEN 0 THEN 'No'
      END AS [JobEnabled],
    CASE [scheduleenabled]
        WHEN 1 THEN 'Yes'
        WHEN 0 THEN 'No'
      END AS [ScheduleEnabled]
    , CASE 
        WHEN [freq_type] = 64 THEN 'Start automatically when SQL Server Agent starts'
        WHEN [freq_type] = 128 THEN 'Start whenever the CPUs become idle'
        WHEN [freq_type] IN (4,8,16,32) THEN 'Recurring'
        WHEN [freq_type] = 1 THEN 'One Time'
      END [ScheduleType]
    , CASE [freq_type]
        WHEN 1 THEN 'One Time'
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly'
        WHEN 16 THEN 'Monthly'
        WHEN 32 THEN 'Monthly - Relative to Frequency Interval'
        WHEN 64 THEN 'Start automatically when SQL Server Agent starts'
        WHEN 128 THEN 'Start whenever the CPUs become idle'
      END [Occurrence]
    , CASE [freq_type]
        WHEN 4 THEN 'Occurs every ' + CAST([freq_interval] AS VARCHAR(3)) + ' day(s)'
        WHEN 8 THEN 'Occurs every ' + CAST([freq_recurrence_factor] AS VARCHAR(3)) 
                    + ' week(s) on '
                    + CASE WHEN [freq_interval] & 1 = 1 THEN 'Sunday' ELSE '' END
                    + CASE WHEN [freq_interval] & 2 = 2 THEN ', Monday' ELSE '' END
                    + CASE WHEN [freq_interval] & 4 = 4 THEN ', Tuesday' ELSE '' END
                    + CASE WHEN [freq_interval] & 8 = 8 THEN ', Wednesday' ELSE '' END
                    + CASE WHEN [freq_interval] & 16 = 16 THEN ', Thursday' ELSE '' END
                    + CASE WHEN [freq_interval] & 32 = 32 THEN ', Friday' ELSE '' END
                    + CASE WHEN [freq_interval] & 64 = 64 THEN ', Saturday' ELSE '' END
        WHEN 16 THEN 'Occurs on Day ' + CAST([freq_interval] AS VARCHAR(3)) 
                     + ' of every '
                     + CAST([freq_recurrence_factor] AS VARCHAR(3)) + ' month(s)'
        WHEN 32 THEN 'Occurs on '
                     + CASE [freq_relative_interval]
                        WHEN 1 THEN 'First'
                        WHEN 2 THEN 'Second'
                        WHEN 4 THEN 'Third'
                        WHEN 8 THEN 'Fourth'
                        WHEN 16 THEN 'Last'
                       END
                     + ' ' 
                     + CASE [freq_interval]
                        WHEN 1 THEN 'Sunday'
                        WHEN 2 THEN 'Monday'
                        WHEN 3 THEN 'Tuesday'
                        WHEN 4 THEN 'Wednesday'
                        WHEN 5 THEN 'Thursday'
                        WHEN 6 THEN 'Friday'
                        WHEN 7 THEN 'Saturday'
                        WHEN 8 THEN 'Day'
                        WHEN 9 THEN 'Weekday'
                        WHEN 10 THEN 'Weekend day'
                       END
                     + ' of every ' + CAST([freq_recurrence_factor] AS VARCHAR(3)) 
                     + ' month(s)'
      END AS [Recurrence]
    , CASE [freq_subday_type]
        WHEN 1 THEN 'Occurs once at ' 
                    + STUFF(
                 STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 2 THEN 'Occurs every ' 
                    + CAST([freq_subday_interval] AS VARCHAR(3)) + ' Second(s) between ' 
                    + STUFF(
                   STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 4 THEN 'Occurs every ' 
                    + CAST([freq_subday_interval] AS VARCHAR(3)) + ' Minute(s) between ' 
                    + STUFF(
                   STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
        WHEN 8 THEN 'Occurs every ' 
                    + CAST([freq_subday_interval] AS VARCHAR(3)) + ' Hour(s) between ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
                    + ' & ' 
                    + STUFF(
                    STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
      END [Frequency]
FROM Maintenance_BackupSchedule_Log bsf
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = bsf.InstanceID

GO

CREATE VIEW vw_Maintenance_BackupOptions
AS
SELECT ServerName, DatabaseName, BackupLocation, FullBackupFiles, DiffBackupFiles, LogBackupFiles, Compressed
FROM Maintenance_BackupOptions bo
INNER JOIN Perf_MonitoredServers pms ON bo.InstanceID = pms.InstanceID

GO

/*
SELECT * FROM msdb..sysjobs 
SELECT * FROM msdb..sysjobschedules 
SELECT * FROM msdb..sysschedules
--SELECT * FROM msdb..sysjobs_view

SELECT * FROM Maintenance_Schedule_Stage
SELECT * FROM Maintenance_BackupSchedule_Full
SELECT * FROM Maintenance_BackupSchedule_Diff
SELECT * FROM Maintenance_BackupSchedule_Log
*/

