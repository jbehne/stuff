DROP TABLE Perf_ClusteredServers;
DROP TABLE Perf_Applications;
GO

CREATE TABLE Perf_Applications (ApplicationID smallint IDENTITY, ApplicationName varchar(64),
	PrimaryContact varchar(64), SecondaryContact varchar(64), Manager varchar(64), Comments varchar(256),
	AuditSystemName varchar(128));

CREATE CLUSTERED INDEX CIX_Perf_Applications ON Perf_Applications (ApplicationID) WITH (DATA_COMPRESSION=PAGE);

CREATE TABLE Perf_ClusteredServers (ClusterID smallint IDENTITY, Environment varchar(4), InstanceID smallint, 
	ClusterName varchar(12), AAGName varchar(12), ListenerName varchar(12), ApplicationID smallint);

CREATE CLUSTERED INDEX CIX_Perf_ClusteredServers ON Perf_ClusteredServers (ClusterID) WITH (DATA_COMPRESSION=PAGE);

INSERT Perf_Applications
SELECT APP_NM, APP_CONTACT_PRIMARY, APP_CONTACT_SECONDARY, APP_MANAGER, APP_COMMENTS, AUDIT_SYSTEM_NM
FROM OPENQUERY (SERVINFO, 'SELECT * FROM ccdb2.MDB_APPLICATION');

SELECT * FROM Perf_Applications


INSERT Perf_ClusteredServers 
SELECT 'PROD', InstanceID, 'ADFCLTPRD01', 'ADFAAGPRD01', 'ADFLSTPRD01', 
	(SELECT ApplicationID FROM Perf_Applications WHERE ApplicationName LIKE 'ACTIVE DIRECTORY FEDERATION')
FROM Perf_MonitoredServers pms
WHERE ServerName IN ('V01DBSWIN010', 'V01DBSWIN011')

SELECT * FROM Perf_ClusteredServers
GO

CREATE VIEW vw_ClusterInfo
AS
SELECT ApplicationName, Environment, ServerName, ClusterName, AAGName, ListenerName
FROM Perf_ClusteredServers pcs
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = pcs.InstanceID
INNER JOIN Perf_Applications pa ON pa.ApplicationID = pcs.ApplicationID
WHERE Environment = 'PROD'
UNION ALL
SELECT ApplicationName, Environment, ServerName, ClusterName, AAGName, ListenerName
FROM Perf_ClusteredServers pcs
INNER JOIN C1DBD536.SQLMONITOR.dbo.Perf_MonitoredServers pms ON pms.InstanceID = pcs.InstanceID
INNER JOIN Perf_Applications pa ON pa.ApplicationID = pcs.ApplicationID
WHERE Environment = 'TEST'