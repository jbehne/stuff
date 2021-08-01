CREATE TYPE tvp_Security_DatabaseUserPermissions 
AS TABLE (InstanceID smallint, DatabaseName varchar(512), UserName varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512));
GO

CREATE TABLE Security_DatabaseUserPermissions_History (ChangeDate smalldatetime, ChangeType varchar(64),
	InstanceID smallint, DatabaseName varchar(512), UserName varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512))
GO

CREATE CLUSTERED INDEX CIX_Security_DatabaseUserPermissions_History ON Security_DatabaseUserPermissions_History (ChangeDate)
	WITH (DATA_COMPRESSION=PAGE);
GO

CREATE PROC usp_Merge_Security_DatabaseUserPermissions (@tbl tvp_Security_DatabaseUserPermissions READONLY, 
	@id smallint, @db varchar(512))
AS
	CREATE TABLE #tmp (ChangeDate smalldatetime, ChangeType varchar(64),
	InstanceID smallint, DatabaseName varchar(512), UserName varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512))

	MERGE Security_DatabaseUserPermissions AS t
	USING (SELECT * FROM @tbl) AS s
	ON (t.InstanceID = s.InstanceID 
		AND t.DatabaseName = s.DatabaseName
		AND t.UserName = s.UserName
		AND t.Object = s.Object
		AND t.ObjectType = s.ObjectType
		AND t.Action = s.Action
		AND t.AccessType = s.AccessType)
	WHEN MATCHED AND t.InstanceID = @id AND t.DatabaseName = @db THEN
		UPDATE SET LastUpdate = GETDATE()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (InstanceID, DatabaseName, UserName, Object, ObjectType, Action, AccessType, LastUpDate) 
		VALUES (InstanceID, DatabaseName, UserName, Object, ObjectType, Action, AccessType, GETDATE())
	WHEN NOT MATCHED BY SOURCE AND t.InstanceID = @id AND t.DatabaseName = @db THEN
		DELETE
	OUTPUT GETDATE(), $action, 
		CASE $action
			WHEN 'INSERT' THEN inserted.InstanceID
			WHEN 'DELETE' THEN deleted.InstanceID END,
		CASE $action
			WHEN 'INSERT' THEN inserted.DatabaseName
			WHEN 'DELETE' THEN deleted.DatabaseName END,
		CASE $action
			WHEN 'INSERT' THEN inserted.UserName
			WHEN 'DELETE' THEN deleted.UserName END,
		CASE $action
			WHEN 'INSERT' THEN inserted.Object
			WHEN 'DELETE' THEN deleted.Object END,
		CASE $action
			WHEN 'INSERT' THEN inserted.ObjectType
			WHEN 'DELETE' THEN deleted.ObjectType END,
		CASE $action
			WHEN 'INSERT' THEN inserted.Action
			WHEN 'DELETE' THEN deleted.Action END,
		CASE $action
			WHEN 'INSERT' THEN inserted.AccessType
			WHEN 'DELETE' THEN deleted.AccessType END
		INTO #tmp;
		
		INSERT Security_DatabaseUserPermissions_History
		SELECT * FROM #tmp
		WHERE ChangeType <> 'UPDATE';