USE [msdb]
GO
EXEC msdb.dbo.sp_update_jobstep @job_name=N'LcsLog_Purge', @step_id=1 , 
		@command=N'DECLARE @AAGPrimary int
SET @AAGPrimary = (SELECT sys.fn_hadr_is_primary_replica (''LcsLog''))
IF (@AAGPrimary = 0) 
BEGIN
    RAISERROR(''Database is not on the primary node'', 16, 1)
END
ELSE BEGIN
    PRINT (''Database is on the primary node'')
END'
GO

EXEC msdb.dbo.sp_update_jobstep @job_name=N'LcsCDR_UsageSummary', @step_id=1 , 
		@command=N'DECLARE @AAGPrimary int
SET @AAGPrimary = (SELECT sys.fn_hadr_is_primary_replica (''LcsCDR''))
IF (@AAGPrimary = 0) 
BEGIN
    RAISERROR(''Database is not on the primary node'', 16, 1)
END
ELSE BEGIN
    PRINT (''Database is on the primary node'')
END'
GO

EXEC msdb.dbo.sp_update_jobstep @job_name=N'LcsCDR_Purge', @step_id=1 , 
		@command=N'DECLARE @AAGPrimary int
SET @AAGPrimary = (SELECT sys.fn_hadr_is_primary_replica (''LcsCDR''))
IF (@AAGPrimary = 0) 
BEGIN
    RAISERROR(''Database is not on the primary node'', 16, 1)
END
ELSE BEGIN
    PRINT (''Database is on the primary node'')
END'
GO

EXEC msdb.dbo.sp_update_jobstep @job_name=N'QoEMetrics_Purge', @step_id=1 , 
		@command=N'DECLARE @AAGPrimary int
SET @AAGPrimary = (SELECT sys.fn_hadr_is_primary_replica (''QoEMetrics''))
IF (@AAGPrimary = 0) 
BEGIN
    RAISERROR(''Database is not on the primary node'', 16, 1)
END
ELSE BEGIN
    PRINT (''Database is on the primary node'')
END'
GO

EXEC msdb.dbo.sp_update_jobstep @job_name=N'QoEMetrics_UsageSummary', @step_id=1 , 
		@command=N'DECLARE @AAGPrimary int
SET @AAGPrimary = (SELECT sys.fn_hadr_is_primary_replica (''QoEMetrics''))
IF (@AAGPrimary = 0) 
BEGIN
    RAISERROR(''Database is not on the primary node'', 16, 1)
END
ELSE BEGIN
    PRINT (''Database is on the primary node'')
END'
GO

EXEC msdb.dbo.sp_update_jobstep @job_name=N'LcsLog_Purge', @step_id=1, @step_name=N'Check AAG step'
EXEC msdb.dbo.sp_update_jobstep @job_name=N'LcsCDR_UsageSummary', @step_id=1, @step_name=N'Check AAG step'
EXEC msdb.dbo.sp_update_jobstep @job_name=N'LcsCDR_Purge', @step_id=1, @step_name=N'Check AAG step'
EXEC msdb.dbo.sp_update_jobstep @job_name=N'QoEMetrics_Purge', @step_id=1, @step_name=N'Check AAG step'
EXEC msdb.dbo.sp_update_jobstep @job_name=N'QoEMetrics_UsageSummary', @step_id=1, @step_name=N'Check AAG step'
GO