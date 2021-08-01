
CREATE PROC [dbo].[usp_EmailNotification] (@id int)
AS
BEGIN
	DECLARE @tableHTML  NVARCHAR(MAX) ;  
	DECLARE @user varchar(128), @server varchar(128), @db varchar(512), @to varchar(1024), @subject varchar(1024);

	SELECT @user = Requestor, @db = DatabaseName,
		@to = 'dbasupp@countryfinancial.com;' + RequestorEmail 
	FROM Database_Active 
	WHERE DatabaseID = @id 

	SELECT @subject = 'Ad Hoc Backup Completed - ' + @server + '.' + @db + ' request by ' + @user;

	SET @tableHTML =  
		N'<H1>Ad Hoc Backup Request</H1>' +  
		N'<table border="0">'; 
	SELECT @tableHTML += '<tr><td>ServerName</td><td>' + ServerName + '</td></tr>' +          
			'<tr><td>DatabaseName</td><td>' + DatabaseName + '</td></tr>' + 
			'<tr><td>RequestDate</td><td>' + CONVERT(varchar, RequestDate, 101) + '</td></tr>' + 
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