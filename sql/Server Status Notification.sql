DROP TABLE Alert_ConnectionNotification;

CREATE TABLE Alert_ConnectionNotification (ID int IDENTITY, AlertTime smalldatetime, AlertMessage varchar(512), InstanceID smallint, NotificationSent bit);
CREATE CLUSTERED INDEX CIX_Alert_ConnectionNotification ON Alert_ConnectionNotification (ID) WITH (DATA_COMPRESSION=PAGE);

DELETE Alert_ConnectionStatusChange WHERE ChangeTime < GETDATE() - 30;
GO

ALTER PROC usp_Alert_ConnectionNotification
AS
	SET NOCOUNT ON;


	IF EXISTS (SELECT InstanceID 
				FROM Alert_ConnectionStatusQuiet 
				WHERE InstanceID = 0 
				AND GETDATE() BETWEEN StartTime AND EndTime)
	BEGIN
		return;
	END


	INSERT Alert_ConnectionNotification
	SELECT GETDATE(), 
		'SRV:' + ServerName + '_LSTCHK:' + FORMAT(LastCheck, 'MMdd_hh:mm', 'en-US' ) + '_SINCE:' +
		FORMAT(MAX(ChangeTime), 'MMdd_hh:mm', 'en-US'),
		acs.InstanceID, 0
	FROM Alert_ConnectionStatus acs
	INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = acs.InstanceID
	INNER JOIN Alert_ConnectionStatusChange acsc ON acsc.InstanceID = acs.InstanceID
	WHERE acs.SQLConnection = 0
	AND DATEDIFF(MINUTE, ChangeTime, LastCheck) >= 10
	AND acs.InstanceID NOT IN 
		(SELECT InstanceID 
		FROM Alert_ConnectionNotification 
		WHERE AlertTime > DATEADD(MINUTE, -30, GETDATE()))
	AND acs.InstanceID NOT IN
		(SELECT InstanceID 
		FROM Alert_ConnectionStatusQuiet 
		WHERE GETDATE() BETWEEN StartTime AND EndTime)
	GROUP BY acs.InstanceID, ServerName, LastCheck;

	DECLARE @to varchar(1024), @body varchar(1024), @count smallint, @list varchar(max)
	SELECT @count = COUNT(*) FROM Alert_ConnectionNotification WHERE NotificationSent = 0;
	IF @count > 1
	BEGIN
		SET @body = 'SERVERS_COUNT:' + CAST(@count AS varchar);
	END
	IF @count = 1
	BEGIN
		SELECT @body = AlertMessage FROM Alert_ConnectionNotification WHERE NotificationSent = 0;
	END
	ELSE
	BEGIN
		return;
	END

	UPDATE Alert_ConnectionNotification SET NotificationSent = 1;

	EXEC msdb.dbo.sp_send_dbmail  
    --@recipients = '6513188699@vtext.com;7086010095@txt.att.net;8655482785@txt.att.net',  
    @recipients = 'sqlteam@countryfinancial.com',  
    @body = @body,  
    @subject = 'SERVER DOWN' ; 

/*
How do we handle multiple servers down?
	If > 1 then include server list top 5 & include count
How often do we notify prod is down?  15 minutes
How do we initiate quiet times?  [dbo].[Alert_ConnectionStatusQuiet]
	INSERT Alert_ConnectionStatus VALUES (1, '1/25/19 1:00', '1/25/19 5:00') -- Suppress C1DBD069 for 4 hours
	INSERT Alert_ConnectionStatus VALUES (null, '1/25/19 1:00', '1/25/19 5:00') -- Suppress all servers for 4 hours

select * from perf_monitoredservers where servername not like '%DBD%' and servername not like '%DBS%' 

EXEC msdb.dbo.sp_send_dbmail  
    @recipients = '6513188699@vtext.com;7086010095@txt.att.net;8655482785@txt.att.net',  
    @body = 'SRV:C1DBD781_LSTCHK:01/24_06:52_SINCE:01/24_04:05',  
    @subject = 'SERVER DOWN' ;  
*/
/*
	6513188699@vtext.com
	7086010095@txt.att.net
	8655482785@txt.att.net
*/

SELECT * FROM Alert_ConnectionNotification
SELECT * FROM Alert_ConnectionStatus WHERE InstanceID = 85
SELECT * FROM Alert_ConnectionStatusChange WHERE InstanceID = 85

UPDATE Alert_ConnectionStatus SET SQLConnection = 0 WHERE InstanceID = 85;
INSERT Alert_ConnectionStatusChange VALUES (85, DATEADD(hh, -3, GETDATE()), 0, 0);



SELECT FORMAT (GETDATE(), 'MMddyy_hhmmss', 'en-US' )