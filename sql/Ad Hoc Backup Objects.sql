-- TABLES
CREATE TABLE Backup_Request (Backup_Request_ID UNIQUEIDENTIFIER, ServerName varchar(256), DatabaseName varchar(512), FileName varchar(1024), RequestDate smalldatetime, Requestor varchar(128), RequestorEmail varchar(128), RetentionDays smallint, Size bigint);
GO
CREATE TABLE Backup_Request_History (Backup_Request_ID UNIQUEIDENTIFIER, ServerName varchar(256), DatabaseName varchar(512), FileName varchar(1024), RequestDate smalldatetime, Requestor varchar(128), RequestorEmail varchar(128), RetentionDays smallint, RemovalDate datetime);
GO
--CREATE DROP TABLE Restore_Request (Restore_Request_ID int IDENTITY, ServerName varchar(256), DatabaseName varchar(512), RestoreCommand varchar(max), RequestDate datetime, Requestor varchar(128), ApprovalID varchar(128));
--GO


CREATE TABLE [dbo].[Restore_Request](
	[Restore_Request_ID] UNIQUEIDENTIFIER NOT NULL,
	[Backup_Request_ID] UNIQUEIDENTIFIER NOT NULL,
	[RequestDate] [smalldatetime] NOT NULL,
	[CompleteDate] [smalldatetime] NULL,
	[Requestor] [varchar](128) NOT NULL,
	[RequestorEmail] [varchar](128) NOT NULL,
	);
GO

CREATE TABLE Restore_Access_Groups (GroupID int IDENTITY, GroupName varchar(512));
GO
CREATE TABLE Restore_Access (GroupID int, InstanceID int, DatabaseName varchar(512));
GO


-- EMAIL NOTIFY PROC
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_BackupEmailNotification')
	DROP PROC usp_BackupEmailNotification;
GO

CREATE PROC usp_BackupEmailNotification (@id UNIQUEIDENTIFIER)
AS
BEGIN
	DECLARE @tableHTML  NVARCHAR(MAX) ;  
	DECLARE @user varchar(128), @server varchar(128), @db varchar(512), @to varchar(1024), @subject varchar(1024);

	SELECT @user = Requestor, @server = ServerName, @db = DatabaseName,
		@to = 'dbasupp@countryfinancial.com;' + RequestorEmail 
	FROM Backup_Request 
	WHERE Backup_Request_ID = @id 

	SELECT @subject = 'Ad Hoc Backup Completed - ' + @server + '.' + @db + ' requested by ' + @user;

	SET @tableHTML =  
		N'<H1>Ad Hoc Backup Request</H1>' +  
		N'<table border="0">'; 
	SELECT @tableHTML += '<tr><td>ServerName</td><td>' + ServerName + '</td></tr>' +          
			'<tr><td>DatabaseName</td><td>' + DatabaseName + '</td></tr>' + 
			'<tr><td>RequestDate</td><td>' + CONVERT(varchar, RequestDate, 101) + ' ' + CONVERT(varchar, RequestDate, 108) + '</td></tr>' + 
			'<tr><td>Requestor</td><td>' + Requestor + '</td></tr>' + 
			'<tr><td>RequestorEmail</td><td>' + RequestorEmail + '</td></tr>' +    
			'<tr><td>RetentionDays</td><td>' + CAST(RetentionDays AS varchar) + '</td></tr>' +  
			'<tr><td>BackupSizeKB</td><td>' + CAST(Size AS varchar) + '</td></tr>'
	FROM Backup_Request  
	WHERE Backup_Request_ID = @id
	
	SET @tableHTML += N'</table>' ;  
		
	EXEC msdb.dbo.sp_send_dbmail @recipients=@to,  
		@subject = @subject,  
		@body = @tableHTML,  
		@body_format = 'HTML' ; 
END
GO

IF EXISTS (SELECT name FROM sys.objects WHERE name = 'usp_RestoreEmailNotification')
	DROP PROC usp_RestoreEmailNotification;
GO

CREATE PROC usp_RestoreEmailNotification (@id UNIQUEIDENTIFIER)
AS
BEGIN
	DECLARE @tableHTML  NVARCHAR(MAX) ;  
	DECLARE @user varchar(128), @server varchar(128), @db varchar(512), @to varchar(1024), @subject varchar(1024);

	SELECT @user = r.Requestor, @server = ServerName, @db = DatabaseName,
		@to = 'dbasupp@countryfinancial.com;' + r.RequestorEmail 
	FROM Restore_Request r
	INNER JOIN Backup_Request b ON b.Backup_Request_ID = r.Backup_Request_ID
	WHERE Restore_Request_ID = @id 

	SELECT @subject = 'Ad Hoc Restore Completed - ' + @server + '.' + @db + ' requested by ' + @user;

	SET @tableHTML =  
		N'<H1>Ad Hoc Restore Request</H1>' +  
		N'<table border="0">'; 
	SELECT @tableHTML += '<tr><td>ServerName</td><td>' + ServerName + '</td></tr>' +          
			'<tr><td>DatabaseName</td><td>' + DatabaseName + '</td></tr>' + 
			'<tr><td>RequestDate</td><td>' + CONVERT(varchar, r.RequestDate, 101) + ' ' + CONVERT(varchar, r.RequestDate, 108) + '</td></tr>' + 
			'<tr><td>Restore To Date</td><td>' + CONVERT(varchar, b.RequestDate, 101) + ' ' + CONVERT(varchar, r.RequestDate, 108) + '</td></tr>' + 
			'<tr><td>Requestor</td><td>' + r.Requestor + '</td></tr>' + 
			'<tr><td>RequestorEmail</td><td>' + r.RequestorEmail + '</td></tr>' 
	FROM Restore_Request r
	INNER JOIN Backup_Request b ON b.Backup_Request_ID = r.Backup_Request_ID
	WHERE Restore_Request_ID = @id
	
	SET @tableHTML += N'</table>' ;  
		
	EXEC msdb.dbo.sp_send_dbmail @recipients=@to,  
		@subject = @subject,  
		@body = @tableHTML,  
		@body_format = 'HTML' ; 
END
GO


-- BACKUP JOB
USE [msdb]
GO

EXEC msdb.dbo.sp_add_job @job_name=N'AdHocBackup_RunQueue', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'CCsaid'

EXEC msdb.dbo.sp_add_jobstep @job_name=N'AdHocBackup_RunQueue', @step_name=N'PS', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=N'powershell.exe E:\Powershell\PS_AdHocBackup.ps1', 
		@flags=0

EXEC msdb.dbo.sp_update_job @job_name=N'AdHocBackup_RunQueue', @start_step_id = 1

EXEC msdb.dbo.sp_add_jobschedule @job_name=N'AdHocBackup_RunQueue', @name=N'Every 15 minutes', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20181203, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=115959, 
		@schedule_uid=N'357df6e7-4fae-48ff-9908-bf36e5d791b4'

EXEC msdb.dbo.sp_add_jobserver @job_name=N'AdHocBackup_RunQueue', @server_name = N'(local)'
GO

-- CLEANUP JOB
USE [msdb]
GO

EXEC msdb.dbo.sp_add_job @job_name=N'AdHocBackup_Cleanup', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'CCsaid'

EXEC msdb.dbo.sp_add_jobstep @job_name=N'AdHocBackup_Cleanup', @step_name=N'PS', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=N'powershell.exe E:\PS_AdHocBackup_Cleaner.ps1', 
		@flags=0

EXEC msdb.dbo.sp_update_job @job_name=N'AdHocBackup_Cleanup', @start_step_id = 1

EXEC msdb.dbo.sp_add_jobschedule @job_name=N'AdHocBackup_Cleanup', @name=N'Daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20181204, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959, 
		@schedule_uid=N'89a006b7-cc93-4e2d-a2a3-3cc8bc56c85e'

EXEC msdb.dbo.sp_add_jobserver @job_name=N'AdHocBackup_Cleanup', @server_name = N'(local)'





