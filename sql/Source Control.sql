USE SQLMONITOR

--CREATE TABLE SourceControl_Databases (InstanceID smallint, DatabaseName varchar(512));
--CREATE CLUSTERED INDEX CIX_SourceControl_Databases ON SourceControl_Databases (InstanceID) WITH (DATA_COMPRESSION=PAGE)
--GO
--CREATE VIEW vw_SourceControl_Databases
--AS
--SELECT pms.ServerName, sc.DatabaseName
--FROM SourceControl_Databases sc
--INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = sc.InstanceID
--GO

SELECT * FROM Perf_MonitoredServers
SELECT * FROM SourceControl_Databases

INSERT SourceControl_Databases VALUES (1, 'SQLMONITOR');
INSERT SourceControl_Databases VALUES (1, 'MDBORHIST');