CREATE PROC usp_DeleteMonitoredServer @servername varchar(512)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @id smallint, @count int;
	SELECT @id = InstanceID FROM Perf_MonitoredServers WHERE ServerName = @servername;
	
	SELECT @count = COUNT(*) FROM Perf_CounterData WHERE InstanceID = @id;
	WHILE @count > 0
	BEGIN
		DELETE TOP (10000) FROM Perf_CounterData WHERE InstanceID = @id;
		SELECT @count = COUNT(*) FROM Perf_CounterData WHERE InstanceID = @id;
	END;

	SELECT @count = COUNT(*) FROM Perf_FileIO WHERE InstanceID = @id;
	WHILE @count > 0
	BEGIN
		DELETE TOP (10000) FROM Perf_FileIO WHERE InstanceID = @id;
		SELECT @count = COUNT(*) FROM Perf_FileIO WHERE InstanceID = @id;
	END;

	SELECT @count = COUNT(*) FROM Perf_FileSpace WHERE InstanceID = @id;
	WHILE @count > 0
	BEGIN
		DELETE TOP (10000) FROM Perf_FileSpace WHERE InstanceID = @id;
		SELECT @count = COUNT(*) FROM Perf_FileSpace WHERE InstanceID = @id;
	END;

	SELECT @count = COUNT(*) FROM Perf_Sessions WHERE InstanceID = @id;
	WHILE @count > 0
	BEGIN
		DELETE TOP (10000) FROM Perf_Sessions WHERE InstanceID = @id;
		SELECT @count = COUNT(*) FROM Perf_Sessions WHERE InstanceID = @id;
	END;

	SELECT @count = COUNT(*) FROM Perf_IndexUsageStatistics WHERE InstanceID = @id;
	WHILE @count > 0
	BEGIN
		DELETE TOP (10000) FROM Perf_IndexUsageStatistics WHERE InstanceID = @id;
		SELECT @count = COUNT(*) FROM Perf_IndexUsageStatistics WHERE InstanceID = @id;
	END;

	SELECT @count = COUNT(*) FROM Perf_MemoryGrants WHERE InstanceID = @id;
	WHILE @count > 0
	BEGIN
		DELETE TOP (10000) FROM Perf_MemoryGrants WHERE InstanceID = @id;
		SELECT @count = COUNT(*) FROM Perf_MemoryGrants WHERE InstanceID = @id;
	END;

	SELECT @count = COUNT(*) FROM Perf_WaitStatistics WHERE InstanceID = @id;
	WHILE @count > 0
	BEGIN
		DELETE TOP (10000) FROM Perf_WaitStatistics WHERE InstanceID = @id;
		SELECT @count = COUNT(*) FROM Perf_WaitStatistics WHERE InstanceID = @id;
	END;

	SELECT @count = COUNT(*) FROM Backup_BackupHistory WHERE InstanceID = @id;
	WHILE @count > 0
	BEGIN
		DELETE TOP (10000) FROM Backup_BackupHistory WHERE InstanceID = @id;
		SELECT @count = COUNT(*) FROM Backup_BackupHistory WHERE InstanceID = @id;
	END;

	DELETE Security_DatabaseRoleMembers WHERE InstanceID = @id;
	DELETE Security_DatabaseRolePermissions WHERE InstanceID = @id;
	DELETE Security_DatabaseUserPermissions WHERE InstanceID = @id;
	DELETE Security_ServerPermissions WHERE InstanceID = @id;
	DELETE Security_ServerRoles WHERE InstanceID = @id;

	DELETE Perf_MonitoredServers WHERE InstanceID = @id;
END;
GO