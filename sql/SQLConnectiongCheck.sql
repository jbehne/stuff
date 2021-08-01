CREATE TABLE Alert_ConnectionStatus (InstanceID smallint, LastCheck smalldatetime, Ping bit, SQLConnection bit);
GO
CREATE CLUSTERED INDEX CIX_Alert_ConnectionStatus ON Alert_ConnectionStatus (InstanceID) WITH (DATA_COMPRESSION=PAGE);
GO
CREATE TABLE Alert_ConnectionStatusChange (InstanceID smallint, ChangeTime smalldatetime, Ping bit, SQLConnection bit);
GO
CREATE CLUSTERED INDEX CIX_Alert_ConnectionStatusChange ON Alert_ConnectionStatusChange (ChangeTime) WITH (DATA_COMPRESSION=PAGE);
GO
CREATE TABLE Alert_ConnectionStatusQuiet (InstanceID smallint, StartTime smalldatetime, EndTime smalldatetime);
GO
CREATE CLUSTERED INDEX CIX_Alert_ConnectionStatusQuiet ON Alert_ConnectionStatusQuiet (InstanceID) WITH (DATA_COMPRESSION=PAGE);
GO

CREATE PROC usp_Alert_GetConnectionStatusServers 
AS
BEGIN
	WITH newservers
	AS (
		SELECT InstanceID FROM Perf_MonitoredServers WHERE IsActive = 1
		EXCEPT
		SELECT InstanceID FROM Alert_ConnectionStatus
	)

	INSERT Alert_ConnectionStatus
	SELECT InstanceID, '1/1/1900', 1, 1 FROM newservers;

	DELETE acs
	FROM Alert_ConnectionStatus acs
	INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = acs.InstanceID
	WHERE IsActive = 0;

	WITH ids
	AS (
		SELECT InstanceID FROM Alert_ConnectionStatus
		EXCEPT
		SELECT InstanceID FROM Alert_ConnectionStatusQuiet
		WHERE GETDATE() BETWEEN StartTime AND EndTime
	)

	SELECT acs.InstanceID, ServerName 
	FROM ids acs
	INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = acs.InstanceID; 
END;
GO

CREATE PROC usp_Alert_UpdateConnectionStatus (@InstanceID smallint, @Ping bit, @SQLConnection bit)
AS
BEGIN
	DECLARE @lastPing bit, @lastSQLConnection bit;

	SELECT @lastPing = Ping, @lastSQLConnection = SQLConnection FROM Alert_ConnectionStatus WHERE InstanceID = @InstanceID;

	IF (@lastPing <> @Ping OR @lastSQLConnection <> @SQLConnection)
	BEGIN
		UPDATE Alert_ConnectionStatus
		SET Ping = @Ping, SQLConnection = @SQLConnection, LastCheck = GETDATE()
		WHERE InstanceID = @InstanceID;

		INSERT Alert_ConnectionStatusChange (InstanceID, ChangeTime, Ping, SQLConnection)
		VALUES (@InstanceID, GETDATE(), @Ping, @SQLConnection);
	END;
	ELSE
	BEGIN
		UPDATE Alert_ConnectionStatus
		SET LastCheck = GETDATE()
		WHERE InstanceID = @InstanceID;
	END;
END;
GO
