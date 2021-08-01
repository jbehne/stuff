USE [master]
GO

ALTER PROC sp_who3
WITH EXECUTE AS 'ALLIANCE\z_sqlidk'
AS
SELECT ec.session_id SPID, es.status Status, login_name Login, host_name HostName, CASE WHEN blocked = 0 THEN null ELSE blocked END BlkBy,
	DB_NAME(database_id) DBName, cmd Command, cpu_time CPUTime, physical_io DiskIO, last_batch LastBatch, sp.program_name ProgramName, sp.spid SPID, request_id REQUESTID
FROM sys.dm_exec_connections ec
INNER JOIN sys.dm_exec_sessions es ON es.session_id = ec.session_id
INNER JOIN sys.sysprocesses sp ON ec.session_id = sp.spid;
GO

GRANT EXECUTE ON sp_who3 TO [ALLIANCE\EMSDB0P1_READ_TABVIEW]
GO

ALTER DATABASE master SET TRUSTWORTHY ON;
GO

EXEC sys.sp_MS_marksystemobject sp_who3;
GO

SELECT * FROM sys.objects WHERE name = 'sp_who3'
GO