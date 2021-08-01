CREATE TABLE Security_DatabaseRoleMembers_History (ChangeDate smalldatetime, ChangeType varchar(64),
	InstanceID smallint, DatabaseName varchar(512), Role varchar(512), MemberName varchar(512))
GO

CREATE CLUSTERED INDEX CIX_Security_DatabaseRoleMembers_History ON Security_DatabaseRoleMembers_History (ChangeDate)
	WITH (DATA_COMPRESSION=PAGE);
GO

SELECT * FROM Security_DatabaseRoleMembers 
SELECT * FROM Security_DatabaseRoleMembers_Stage
SELECT * FROM Security_DatabaseRoleMembers_History

TRUNCATE TABLE Security_DatabaseRoleMembers_History

DELETE Security_DatabaseRoleMembers WHERE InstanceID = 1
DELETE Security_DatabaseRoleMembers_Stage WHERE InstanceID <> 1

DELETE Security_DatabaseRoleMembers WHERE DatabaseName = 'ReportServer'
DELETE Security_DatabaseRoleMembers_Stage WHERE DatabaseName = 'SQLMONITOR'


-- MERGE

DECLARE @temp TABLE (ChangeDate datetime, ChangeType varchar(512), InstanceID smallint, DatabaseName varchar(512), 
	Role varchar(512), MemberName varchar(512));
DECLARE @instance TABLE (InstanceID smallint);

INSERT @instance
SELECT DISTINCT pms.InstanceID
FROM Perf_MonitoredServers pms
LEFT OUTER JOIN Security_DatabaseRoleMembers_Stage sdr ON sdr.InstanceID = pms.InstanceID
WHERE sdr.DatabaseName IS NULL
AND (IsActive = 1 OR IsPushActive = 1)

INSERT Security_DatabaseRoleMembers_Stage
SELECT InstanceID, DatabaseName, Role, MemberName 
FROM Security_DatabaseRoleMembers
WHERE InstanceID IN (SELECT InstanceID FROM @instance);

MERGE Security_DatabaseRoleMembers AS t
USING (SELECT * FROM Security_DatabaseRoleMembers_Stage) AS s
ON (t.InstanceID = s.InstanceID 
	AND t.DatabaseName = s.DatabaseName
	AND t.Role = s.Role
	AND t.MemberName = s.MemberName)
WHEN MATCHED THEN
	UPDATE SET LastUpdate = GETDATE()
WHEN NOT MATCHED BY TARGET THEN
	INSERT (InstanceID, DatabaseName, Role, MemberName, LastUpdate) 
	VALUES (InstanceID, DatabaseName, Role, MemberName, GETDATE())
WHEN NOT MATCHED BY SOURCE THEN
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
		WHEN 'INSERT' THEN inserted.MemberName
		WHEN 'DELETE' THEN deleted.MemberName END
	INTO @temp;

INSERT Security_DatabaseRoleMembers_History
SELECT * FROM @temp
WHERE ChangeType <> 'UPDATE';
GO


--Role permissions
SELECT TOP 10 * FROM Security_DatabaseRolePermissions 
SELECT TOP 10 * FROM Security_DatabaseRolePermissions_Stage
SELECT * FROM Security_DatabaseRolePermissions_History

TRUNCATE TABLE Security_DatabaseRolePermissions_History


DECLARE @temp TABLE (ChangeDate datetime, ChangeType varchar(512), InstanceID smallint, DatabaseName varchar(512), 
	Role varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512));
DECLARE @instance TABLE (InstanceID smallint);

INSERT @instance
SELECT DISTINCT pms.InstanceID
FROM Perf_MonitoredServers pms
LEFT OUTER JOIN Security_DatabaseRolePermissions_Stage sdr ON sdr.InstanceID = pms.InstanceID
WHERE sdr.DatabaseName IS NULL
AND (IsActive = 1 OR IsPushActive = 1)

INSERT Security_DatabaseRolePermissions_Stage
SELECT InstanceID, DatabaseName, Role, Object, ObjectType, Action, AccessType 
FROM Security_DatabaseRolePermissions
WHERE InstanceID IN (SELECT InstanceID FROM @instance);

MERGE Security_DatabaseRolePermissions AS t
USING (SELECT * FROM Security_DatabaseRolePermissions_Stage) AS s
ON (t.InstanceID = s.InstanceID 
	AND t.DatabaseName = s.DatabaseName
	AND t.Role = s.Role
	AND t.Object = s.Object
	AND t.ObjectType = s.ObjectType
	AND t.Action = s.Action
	AND t.AccessType = s.AccessType)
WHEN MATCHED THEN
	UPDATE SET LastUpdate = GETDATE()
WHEN NOT MATCHED BY TARGET THEN
	INSERT (InstanceID, DatabaseName, Role, Object, ObjectType, Action, AccessType , LastUpdate) 
	VALUES (InstanceID, DatabaseName, Role, Object, ObjectType, Action, AccessType , GETDATE())
WHEN NOT MATCHED BY SOURCE THEN
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
	INTO @temp;

INSERT Security_DatabaseRolePermissions_History
SELECT * FROM @temp
WHERE ChangeType <> 'UPDATE';
GO

--LOGINS

SELECT * FROM Security_Logins
SELECT * FROM Security_Logins_Stage
SELECT * FROM Security_Logins_History

DECLARE @instance TABLE (InstanceID smallint);
DECLARE @logins TABLE (ChangeDate datetime, ChangeType varchar(512), InstanceID smallint, 
	LoginName varchar(1024), CreateDate smalldatetime, UpdateDate smalldatetime, DBName varchar(512), 
	DenyLogin bit, HasAccess bit, isNTname bit, isNTgroup bit, isNTuser bit);

INSERT @instance
SELECT DISTINCT pms.InstanceID
FROM Perf_MonitoredServers pms
LEFT OUTER JOIN Security_Logins_Stage sdr ON sdr.InstanceID = pms.InstanceID
WHERE sdr.LoginName IS NULL
AND (IsActive = 1 OR IsPushActive = 1);

INSERT Security_Logins_Stage
SELECT InstanceID, LoginName, CreateDate, UpdateDate, DBName, DenyLogin, HasAccess,
	isNTname, isNTgroup, isNTuser
FROM Security_Logins
WHERE InstanceID IN (SELECT InstanceID FROM @instance);

MERGE Security_Logins AS t
USING (SELECT * FROM Security_Logins_Stage) AS s
ON (t.InstanceID = s.InstanceID 
	AND t.LoginName = s.LoginName
	AND t.CreateDate = s.CreateDate
	AND t.UpdateDate = s.UpdateDate
	AND t.DBName = s.DBName
	AND t.DenyLogin = s.DenyLogin
	AND t.HasAccess = s.HasAccess
	AND t.isNTname = s.isNTname
	AND t.isNTgroup = s.isNTgroup
	AND t.isNTuser = s.isNTuser)
WHEN MATCHED THEN
	UPDATE SET LastUpdate = GETDATE()
WHEN NOT MATCHED BY TARGET THEN
	INSERT (InstanceID, LoginName, CreateDate, UpdateDate, DBName, DenyLogin, HasAccess,
		isNTname, isNTgroup, isNTuser, LastUpdate) 
	VALUES (InstanceID, LoginName, CreateDate, UpdateDate, DBName, DenyLogin, HasAccess,
		isNTname, isNTgroup, isNTuser, GETDATE())
WHEN NOT MATCHED BY SOURCE THEN
	DELETE 
OUTPUT GETDATE(), $action, 
	CASE $action
		WHEN 'INSERT' THEN inserted.InstanceID
		WHEN 'DELETE' THEN deleted.InstanceID END,
	CASE $action
		WHEN 'INSERT' THEN inserted.LoginName
		WHEN 'DELETE' THEN deleted.LoginName END,
	CASE $action
		WHEN 'INSERT' THEN inserted.CreateDate
		WHEN 'DELETE' THEN deleted.CreateDate END,
	CASE $action
		WHEN 'INSERT' THEN inserted.UpdateDate
		WHEN 'DELETE' THEN deleted.UpdateDate END,
	CASE $action
		WHEN 'INSERT' THEN inserted.DBName
		WHEN 'DELETE' THEN deleted.DBName END,
	CASE $action
		WHEN 'INSERT' THEN inserted.DenyLogin
		WHEN 'DELETE' THEN deleted.DenyLogin END,
	CASE $action
		WHEN 'INSERT' THEN inserted.HasAccess
		WHEN 'DELETE' THEN deleted.HasAccess END,
	CASE $action
		WHEN 'INSERT' THEN inserted.isNTname
		WHEN 'DELETE' THEN deleted.isNTname END,
	CASE $action
		WHEN 'INSERT' THEN inserted.isNTgroup
		WHEN 'DELETE' THEN deleted.isNTgroup END,
	CASE $action
		WHEN 'INSERT' THEN inserted.isNTuser
		WHEN 'DELETE' THEN deleted.isNTuser END
	INTO @logins;

INSERT Security_Logins_History
SELECT * FROM @logins
WHERE ChangeType <> 'UPDATE';

GO



-- Server perms
SELECT * FROM Security_ServerPermissions
SELECT * FROM Security_ServerPermissions_Stage
SELECT * FROM Security_ServerPermissions_History

DECLARE @instance TABLE (InstanceID smallint);

DELETE @instance;
DECLARE @serveraccess TABLE (ChangeDate datetime, ChangeType varchar(512), InstanceID smallint, 
	UserName varchar(512), Class varchar(512), Permission varchar(512), Type varchar(512));

INSERT @instance
SELECT DISTINCT pms.InstanceID
FROM Perf_MonitoredServers pms
LEFT OUTER JOIN Security_ServerPermissions_Stage sdr ON sdr.InstanceID = pms.InstanceID
WHERE sdr.UserName IS NULL
AND (IsActive = 1 OR IsPushActive = 1);

INSERT Security_ServerPermissions_Stage
SELECT InstanceID, UserName, Class, Permission, Type
FROM Security_ServerPermissions
WHERE InstanceID IN (SELECT InstanceID FROM @instance);

MERGE Security_ServerPermissions AS t
USING (SELECT * FROM Security_ServerPermissions_Stage) AS s
ON (t.InstanceID = s.InstanceID 
	AND t.UserName = s.UserName
	AND t.Class = s.Class
	AND t.Permission = s.Permission
	AND t.Type = s.Type)
WHEN MATCHED THEN
	UPDATE SET LastUpdate = GETDATE()
WHEN NOT MATCHED BY TARGET THEN
	INSERT (InstanceID, UserName, Class, Permission, Type, LastUpdate) 
	VALUES (InstanceID, UserName, Class, Permission, Type, GETDATE())
WHEN NOT MATCHED BY SOURCE THEN
	DELETE 
OUTPUT GETDATE(), $action, 
	CASE $action
		WHEN 'INSERT' THEN inserted.InstanceID
		WHEN 'DELETE' THEN deleted.InstanceID END,
	CASE $action
		WHEN 'INSERT' THEN inserted.UserName
		WHEN 'DELETE' THEN deleted.UserName END,
	CASE $action
		WHEN 'INSERT' THEN inserted.Class
		WHEN 'DELETE' THEN deleted.Class END,
	CASE $action
		WHEN 'INSERT' THEN inserted.Permission
		WHEN 'DELETE' THEN deleted.Permission END,
	CASE $action
		WHEN 'INSERT' THEN inserted.Type
		WHEN 'DELETE' THEN deleted.Type END
	INTO @serveraccess;

INSERT Security_ServerPermissions_History
SELECT * FROM @serveraccess
WHERE ChangeType <> 'UPDATE';
