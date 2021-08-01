select * from [dbo].[Version_SQLList] -- Add loaddate

--CREATE VIEW vw_AllMonitoredServers
--AS
--SELECT 'Production' Environment, * FROM Perf_MonitoredServers
--UNION ALL
--SELECT 'Test' Environment, * FROM C1DBD536.SQLMONITOR.dbo.Perf_MonitoredServers

SELECT * FROM vw_AllMonitoredServers

-- Step 1 - Get the file from website
-- Step 2 - ETL the spreadsheet into 069 repo
-- Step 3 - Query current version joined to max version (joined to SERVINFO variance)
-- Step 4 - Create report with step 3 query
-- Step 5 - Create data driven subscription to send report to DBASUPP

-- Exclude 2008 R2's



SELECT Environment, 
	CASE SUBSTRING(Version, 0, 3) 
		WHEN 10 THEN 'SQL2008R2'
		WHEN 11 THEN 'SQL2012'
		WHEN 12 THEN 'SQL2014'
		WHEN 13 THEN 'SQL2016'
		WHEN 14 THEN 'SQL2017'
	END Version 
FROM vw_AllMonitoredServers WHERE ServerName = 'V06DBSWIN500'