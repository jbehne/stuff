IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Error_Log')
	DROP TABLE Error_Log;
GO
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'Error_FailedJobs_Stage')
	DROP TABLE Error_FailedJobs_Stage;
GO


CREATE TABLE Error_Log (ErrorID bigint IDENTITY, InstanceID smallint, ErrorTime smalldatetime, ErrorMsg varchar(MAX), IsResolved bit DEFAULT 0, Resolution varchar(2048));
CREATE CLUSTERED INDEX CIX_Error_Log ON Error_Log (ErrorTime) WITH (DATA_COMPRESSION=PAGE);
CREATE INDEX IX_Error_Log_ErrorID ON Error_Log (ErrorID) WITH (DATA_COMPRESSION=PAGE);
GO

--CREATE TABLE Error_FailedJobs (InstanceID smallint, RunTime smalldatetime, JobName varchar(512), StepName varchar(512), Message varchar(MAX));
--CREATE CLUSTERED INDEX CIX_Error_FailedJobs ON Error_FailedJobs (InstanceID) WITH (DATA_COMPRESSION=PAGE);

CREATE TABLE Error_FailedJobs_Stage (InstanceID smallint, RunTime smalldatetime, JobName varchar(512), StepName varchar(512), Message varchar(MAX));
GO

CREATE PROC usp_MergeFailedJobs
AS

INSERT Error_Log (InstanceID, ErrorTime, ErrorMsg)
SELECT InstanceID, RunTime, 'Job:' + JobName + ' Step:' + StepName + ' Msg:' + Message
FROM Error_FailedJobs_Stage
EXCEPT
SELECT InstanceID, ErrorTime, ErrorMsg
FROM Error_Log

/*
SELECT ServerName, * FROM Error_FailedJobs_Stage efs INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = efs.InstanceID 

SELECT ServerName, ErrorTime, ErrorMsg, IsResolved, Resolution
FROM Error_Log el
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = el.InstanceID
WHERE IsResolved = 0
ORDER BY ErrorTime

*/