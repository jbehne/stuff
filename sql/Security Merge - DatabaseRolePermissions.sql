--SELECT * FROM Security_DatabaseRolePermissions

CREATE TYPE tvp_Security_DatabaseRolePermissions 
AS TABLE (InstanceID smallint, DatabaseName varchar(512), Role varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512));
GO

CREATE TABLE Security_DatabaseRolePermissions_History (ChangeDate smalldatetime, ChangeType varchar(64),
	InstanceID smallint, DatabaseName varchar(512), Role varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512))
GO

CREATE CLUSTERED INDEX CIX_Security_DatabaseRolePermissions_History ON Security_DatabaseRolePermissions_History (ChangeDate)
	WITH (DATA_COMPRESSION=PAGE);
GO

CREATE PROC usp_Merge_Security_DatabaseRolePermissions (@tbl tvp_Security_DatabaseRolePermissions READONLY, 
	@id smallint, @db varchar(512))
AS
	CREATE TABLE #tmp (ChangeDate smalldatetime, ChangeType varchar(64),
	InstanceID smallint, DatabaseName varchar(512), Role varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512))

	MERGE Security_DatabaseRolePermissions AS t
	USING (SELECT * FROM @tbl) AS s
	ON (t.InstanceID = s.InstanceID 
		AND t.DatabaseName = s.DatabaseName
		AND t.Role = s.Role
		AND t.Object = s.Object
		AND t.ObjectType = s.ObjectType
		AND t.Action = s.Action
		AND t.AccessType = s.AccessType)
	WHEN MATCHED AND t.InstanceID = @id AND t.DatabaseName = @db THEN
		UPDATE SET LastUpdate = GETDATE()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (InstanceID, DatabaseName, Role, Object, ObjectType, Action, AccessType, LastUpDate) 
		VALUES (InstanceID, DatabaseName, Role, Object, ObjectType, Action, AccessType, GETDATE())
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
			WHEN 'INSERT' THEN inserted.Role
			WHEN 'DELETE' THEN deleted.Role END,
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
		
		INSERT Security_DatabaseRolePermissions_History
		SELECT * FROM #tmp
		WHERE ChangeType <> 'UPDATE';