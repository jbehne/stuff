USE SQLMONITOR
GO

CREATE TABLE Maintenance_JobName (JobID tinyint IDENTITY, JobName varchar(512));
CREATE CLUSTERED INDEX CIX_Maintenance_JobName ON Maintenance_JobName (JobID) WITH (DATA_COMPRESSION=PAGE);
GO

INSERT Maintenance_JobName VALUES ('Maintenance - Backup FULL'),
('Maintenance - Backup LOG'),
('Maintenance - Backup DIFF');

CREATE TABLE Maintenance_JobDuration_Stage (InstanceID smallint, JobName varchar(512), StartDate smalldatetime, Duration smallint);
GO

CREATE TABLE Maintenance_JobDuration (InstanceID smallint, JobID tinyint, StartDate smalldatetime, Duration smallint);
CREATE CLUSTERED INDEX CIX_Maintenance_JobDuration ON Maintenance_JobDuration (StartDate) WITH (DATA_COMPRESSION=PAGE);
CREATE INDEX IX_Maintenance_JobDuration_InstanceID ON Maintenance_JobDuration (InstanceID) WITH (DATA_COMPRESSION=PAGE);

GO

CREATE PROC usp_MergeJobDuration
AS

INSERT Maintenance_JobDuration
SELECT InstanceID, JobID, StartDate, Duration 
FROM Maintenance_JobDuration_Stage jds
INNER JOIN Maintenance_JobName jn ON jds.JobName = jn.JobName
EXCEPT
SELECT InstanceID, JobID, StartDate, Duration 
FROM Maintenance_JobDuration;

GO

CREATE VIEW vw_JobDuration
AS
SELECT ServerName, JobName, StartDate, Duration
FROM Maintenance_JobDuration jd
INNER JOIN Maintenance_JobName jn ON jn.JobID = jd.JobID
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = jd.InstanceID

/*
SELECT * FROM vw_JobDuration
*/