SELECT session_id
FROM sys.dm_exec_sessions s
INNER JOIN msdb..sysjobs j ON SUBSTRING(s.program_name, 48, 16) = REPLACE(RIGHT(CAST(j.job_id AS varchar(48)), 17), '-', '')
WHERE j.name = 'Wait'
AND s.program_name LIKE 'SQLAgent - TSQL JobStep%'


