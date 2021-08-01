USE [SQLMONITOR]
GO

--CREATE TABLE Maintenance_BackupSchedule_LogByDay (InstanceID smallint, BackupTime time, Day varchar(12));
--CREATE CLUSTERED INDEX CIX_Maintenance_BackupSchedule_LogByDay ON Maintenance_BackupSchedule_LogByDay (InstanceID)
--	WITH (DATA_COMPRESSION=PAGE);

CREATE PROC usp_GetBackupScheduleByDay_Log
AS

SET NOCOUNT ON;

DECLARE @server varchar(24), @interval tinyint, @time time, @day varchar(12);
DECLARE @tmp AS TABLE (ServerName varchar(24), interval tinyint, Time time, Day varchar(12));
DECLARE @schedule AS TABLE (ServerName varchar(24), Time time, Day varchar(12));
DECLARE @days AS TABLE (theday varchar(12));
INSERT @days VALUES ('Monday'), ('Tuesday'), ('Wednesday'), ('Thursday'), 
	('Friday'), ('Saturday'), ('Sunday');

INSERT @tmp
SELECT
	ServerName
    , freq_subday_interval
	, CAST(STUFF(STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':') AS time) time
	, theday
FROM Maintenance_BackupSchedule_Log bsf
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = bsf.InstanceID
CROSS APPLY @days; 

DECLARE c CURSOR 
FOR SELECT * FROM @tmp;

OPEN c;

FETCH NEXT FROM c
INTO @server, @interval, @time, @day;

WHILE @@FETCH_STATUS = 0
BEGIN
	WHILE @time < '23:59:59'
	BEGIN
		INSERT @schedule VALUES (@server, @time, @day);

		IF @time >= '20:00'
			break;

		SET @time = DATEADD(hh, @interval, @time);
	END

	FETCH NEXT FROM c
	INTO @server, @interval, @time, @day;
END

CLOSE c;
DEALLOCATE c;

TRUNCATE TABLE Maintenance_BackupSchedule_LogByDay;

INSERT Maintenance_BackupSchedule_LogByDay
SELECT InstanceID, Time, Day
FROM @schedule s
INNER JOIN Perf_MonitoredServers pms ON pms.ServerName = s.ServerName;

GO


