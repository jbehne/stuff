/*
# This will grab all current running jobs from the maintenance table and their duration in hours.
# Any indexing operation running more than x hours is then identified and a stop command is built.
# A cursor then loops through the command table to stop all jobs that met the criteria.
# JB 12/3/14
*/

USE [msdb]

DECLARE @stopcommands TABLE (cmd varchar(1000));
DECLARE @cmd varchar(1000);

/* -- # This is the original code used to identify indexing jobs at runtime.
--WITH cteRunningJobs
--AS
--(SELECT j.name, DATEDIFF(hh, ja.start_execution_date, GETDATE()) runtime
--FROM sysjobactivity ja
--INNER JOIN sysjobs j ON j.job_id = ja.job_id
--WHERE stop_execution_date IS NULL
--AND start_execution_date IS NOT NULL
--AND name LIKE '%index%')
*/

WITH cteRunningJobs
AS
(SELECT j.job_name, j.duration_limit, DATEDIFF(hh, ja.start_execution_date, GETDATE()) runtime
FROM sysjobactivity ja
INNER JOIN DB_DBA..JobDurationLimits j ON j.job_id = ja.job_id
WHERE stop_execution_date IS NULL
AND start_execution_date IS NOT NULL)

INSERT @stopcommands 
SELECT 'EXEC sp_stop_job @job_name = ''' + job_name + ''''
FROM cteRunningJobs
WHERE runtime >= duration_limit;

DECLARE stopcursor CURSOR STATIC FOR
SELECT cmd FROM @stopcommands;

OPEN stopcursor;

FETCH NEXT FROM stopcursor INTO @cmd;

WHILE @@FETCH_STATUS = 0
BEGIN
EXEC (@cmd);
FETCH NEXT FROM stopcursor INTO @cmd;
END

CLOSE stopcursor;
DEALLOCATE stopcursor;



/*
# Maintenance table setup.
*/
USE [DB_DBA]
CREATE TABLE JobDurationLimits (job_name varchar(max), job_id uniqueidentifier, duration_limit int);

INSERT JobDurationLimits
SELECT name, job_id, 2
FROM msdb..sysjobs
WHERE name LIKE '%index%'

SELECT * FROM JobDurationLimits
