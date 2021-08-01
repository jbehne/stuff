CREATE TABLE Alert_DatabaseStatus (InstanceID smallint, DBName varchar(512), LastCheck smalldatetime, Status varchar(128));
CREATE CLUSTERED INDEX CIX_Alert_DatabaseStatus ON Alert_DatabaseStatus (InstanceID) WITH (DATA_COMPRESSION = PAGE);
GO

CREATE TABLE Alert_DatabaseStatus_Stage (InstanceID smallint, DBName varchar(512), Status varchar(128));
CREATE CLUSTERED INDEX CIX_Alert_DatabaseStatus_Stage ON Alert_DatabaseStatus_Stage (InstanceID) WITH (DATA_COMPRESSION = PAGE);
GO

CREATE PROC [dbo].[usp_Alert_UpdateDatabaseStatus]
AS
BEGIN
	SET NOCOUNT ON;

	with newdb AS (
		SELECT InstanceID, DBName 
		FROM Alert_DatabaseStatus_Stage
		EXCEPT 
		SELECT InstanceID, DBName 
		FROM Alert_DatabaseStatus)

	INSERT Alert_DatabaseStatus
		SELECT ads.InstanceID, ads.DBName, GETDATE(), ads.Status 
		FROM Alert_DatabaseStatus_Stage ads
		INNER JOIN newdb n ON n.InstanceID = ads.InstanceID
			AND n.DBName = ads.DBName;

	with changedb AS (
		SELECT InstanceID, DBName, Status 
		FROM Alert_DatabaseStatus_Stage
		EXCEPT 
		SELECT InstanceID, DBName, Status 
		FROM Alert_DatabaseStatus)

	UPDATE ads
	SET ads.Status = c.Status
	FROM Alert_DatabaseStatus ads
	INNER JOIN changedb c ON ads.InstanceID = c.InstanceID
		AND c.DBName = ads.DBName;

	UPDATE ads
	SET LastCheck = GETDATE()
	FROM Alert_DatabaseStatus ads
	INNER JOIN Alert_DatabaseStatus_Stage adss ON ads.InstanceID = adss.InstanceID
		AND adss.DBName = ads.DBName
END;