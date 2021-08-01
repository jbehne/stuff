USE [SQLMONITOR]
GO

--CREATE TABLE Maintenance_BackupSchedule_FullDiffByDay (InstanceID smallint, BackupTime time, Day varchar(12));
--CREATE CLUSTERED INDEX CIX_Maintenance_BackupSchedule_FullDiffByDay ON Maintenance_BackupSchedule_FullDiffByDay (InstanceID)
--	WITH (DATA_COMPRESSION=PAGE);

CREATE PROC usp_GetBackupScheduleByDay_FullDiff
AS

SET NOCOUNT ON;

TRUNCATE TABLE Maintenance_BackupSchedule_FullDiffByDay;

WITH diffsched AS (
SELECT 
	ServerName
    , CASE [freq_type]
        WHEN 8 THEN ''
                    + CASE WHEN [freq_interval] & 1 = 1 THEN 'Sunday' ELSE '' END
                    + CASE WHEN [freq_interval] & 2 = 2 THEN ', Monday' ELSE '' END
                    + CASE WHEN [freq_interval] & 4 = 4 THEN ', Tuesday' ELSE '' END
                    + CASE WHEN [freq_interval] & 8 = 8 THEN ', Wednesday' ELSE '' END
                    + CASE WHEN [freq_interval] & 16 = 16 THEN ', Thursday' ELSE '' END
                    + CASE WHEN [freq_interval] & 32 = 32 THEN ', Friday' ELSE '' END
                    + CASE WHEN [freq_interval] & 64 = 64 THEN ', Saturday' ELSE '' END
      END AS [Recurrence]
    , CASE [freq_subday_type]
        WHEN 1 THEN '' 
                    + STUFF(
                 STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
      END [Frequency]
FROM Maintenance_BackupSchedule_Diff bsf
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = bsf.InstanceID),
fullsched AS (
SELECT 
	ServerName
    , CASE [freq_type]
        WHEN 8 THEN ''
                    + CASE WHEN [freq_interval] & 1 = 1 THEN 'Sunday' ELSE '' END
                    + CASE WHEN [freq_interval] & 2 = 2 THEN ', Monday' ELSE '' END
                    + CASE WHEN [freq_interval] & 4 = 4 THEN ', Tuesday' ELSE '' END
                    + CASE WHEN [freq_interval] & 8 = 8 THEN ', Wednesday' ELSE '' END
                    + CASE WHEN [freq_interval] & 16 = 16 THEN ', Thursday' ELSE '' END
                    + CASE WHEN [freq_interval] & 32 = 32 THEN ', Friday' ELSE '' END
                    + CASE WHEN [freq_interval] & 64 = 64 THEN ', Saturday' ELSE '' END
      END AS [Recurrence]
    , CASE [freq_subday_type]
        WHEN 1 THEN '' 
                    + STUFF(
                 STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
                                , 3, 0, ':')
                            , 6, 0, ':')
      END [Frequency]
FROM Maintenance_BackupSchedule_Full bsf
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = bsf.InstanceID)


INSERT Maintenance_BackupSchedule_FullDiffByDay
SELECT InstanceID, Frequency, TRIM(r.value) Day
FROM diffsched d
INNER JOIN Perf_MonitoredServers pms ON pms.ServerName = d.ServerName
CROSS APPLY string_split(Recurrence, ',') r
WHERE r.value <> ''
UNION ALL
SELECT InstanceID, Frequency, TRIM(r.value) Day
FROM fullsched f
INNER JOIN Perf_MonitoredServers pms ON pms.ServerName = f.ServerName
CROSS APPLY string_split(Recurrence, ',') r
WHERE r.value <> '';



GO


