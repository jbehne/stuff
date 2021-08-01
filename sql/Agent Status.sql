CREATE TABLE Alert_AgentStatus (InstanceID smallint, LastCheck smalldatetime, AgentStatus bit);
CREATE CLUSTERED INDEX CIX_Alert_AgentStatus ON Alert_AgentStatus (InstanceID) WITH (DATA_COMPRESSION=PAGE);
GO

CREATE PROC usp_Alert_UpdateAgentStatus (@InstanceID smallint, @AgentStatus bit)
AS
BEGIN
	DELETE Alert_AgentStatus
	WHERE LastCheck < DATEADD(HOUR, -12, GETDATE());

	IF NOT EXISTS (SELECT InstanceID FROM Alert_AgentStatus WHERE InstanceID = @InstanceID)
		INSERT Alert_AgentStatus (InstanceID, LastCheck, AgentStatus)
		VALUES (@InstanceID, GETDATE(), @AgentStatus);

	ELSE
		UPDATE Alert_AgentStatus
		SET AgentStatus = @AgentStatus, LastCheck = GETDATE()
		WHERE InstanceID = @InstanceID;
END


SELECT * FROM Alert_AgentStatus