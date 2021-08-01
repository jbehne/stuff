USE [SQLMONITOR]
GO
/*
CREATE TABLE Security_ServerRoles_History (ChangeDate smalldatetime,
	ChangeType varchar(64), InstanceID smallint, ServerRole varchar(512),
	MemberName varchar(512));
GO

CREATE CLUSTERED INDEX CIX_Security_ServerRoles_History ON Security_ServerRoles_History (InstanceID)
WITH (DATA_COMPRESSION=PAGE)
GO

CREATE TABLE Security_Logins_History (ChangeDate smalldatetime,
	ChangeType varchar(64), InstanceID smallint, LoginName varchar(1024),
	CreateDate smalldatetime, UpdateDate smalldatetime, DBName varchar(512),
	DenyLogin bit, HasAccess bit, isNTname bit,	isNTgroup bit, isNTuser bit)
GO

CREATE CLUSTERED INDEX CIX_Security_Logins_History ON Security_Logins_History (InstanceID)
WITH (DATA_COMPRESSION=PAGE)
GO
*/

ALTER PROC usp_Security_Merge
AS
BEGIN

SET NOCOUNT ON;

-- This table variable will be re-used throughout to check if a server was loaded
-- If a server fails to load we do not want to delete the security
DECLARE @instance TABLE (InstanceID smallint);

/************************      Database Role Members        **************************/
-- Table variable to record changes to history
DECLARE @rolemembers TABLE (ChangeDate datetime, ChangeType varchar(512), InstanceID smallint, DatabaseName varchar(512), 
	Role varchar(512), MemberName varchar(512));

-- Compare staging to the active server list and add any ID's that are missing
INSERT @instance
SELECT DISTINCT pms.InstanceID
FROM Perf_MonitoredServers pms
LEFT OUTER JOIN Security_DatabaseRoleMembers_Stage sdr ON sdr.InstanceID = pms.InstanceID
WHERE sdr.DatabaseName IS NULL
AND (IsActive = 1 OR IsPushActive = 1);

-- Remove security records if a server has been decommissioned and output to history
DELETE Security_DatabaseRoleMembers
OUTPUT GETDATE(), 'Server Decom', deleted.InstanceID, deleted.DatabaseName,
	deleted.Role, deleted.MemberName INTO @rolemembers
WHERE InstanceID IN (
	SELECT InstanceID 
	FROM Perf_MonitoredServers
	WHERE IsActive = 0 AND IsPushActive = 0)

-- Merge staging data.  
-- When stage matches, just update the LastUpdate to show it has been checked
-- When stage doesn't match add or delete as needed, output the actions
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
WHEN NOT MATCHED BY SOURCE AND t.InstanceID NOT IN (SELECT InstanceID FROM @instance) THEN
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
	INTO @rolemembers;

-- Insert changes to history for INSERT and DELETE, an UPDATE is only when a timestamp is updated, not a data change
INSERT Security_DatabaseRoleMembers_History
SELECT * FROM @rolemembers
WHERE ChangeType <> 'UPDATE';


/************************      Database Role Permissions        **************************/
DELETE @instance;
DECLARE @rolepermissions TABLE (ChangeDate datetime, ChangeType varchar(512), InstanceID smallint, DatabaseName varchar(512), 
	Role varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512));

INSERT @instance
SELECT DISTINCT pms.InstanceID
FROM Perf_MonitoredServers pms
LEFT OUTER JOIN Security_DatabaseRolePermissions_Stage sdr ON sdr.InstanceID = pms.InstanceID
WHERE sdr.DatabaseName IS NULL
AND (IsActive = 1 OR IsPushActive = 1);

DELETE Security_DatabaseRolePermissions
OUTPUT GETDATE(), 'Server Decom', deleted.InstanceID, deleted.DatabaseName,
	deleted.Role, deleted.Object, deleted.ObjectType, deleted.Action, deleted.AccessType INTO @rolepermissions
WHERE InstanceID IN (
	SELECT InstanceID 
	FROM Perf_MonitoredServers
	WHERE IsActive = 0 AND IsPushActive = 0)

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
WHEN NOT MATCHED BY SOURCE AND t.InstanceID NOT IN (SELECT InstanceID FROM @instance) THEN
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
	INTO @rolepermissions;

INSERT Security_DatabaseRolePermissions_History
SELECT * FROM @rolepermissions
WHERE ChangeType <> 'UPDATE';



/************************      Database User Permissions        **************************/
DELETE @instance;
DECLARE @userpermissions TABLE (ChangeDate datetime, ChangeType varchar(512), InstanceID smallint, DatabaseName varchar(512), 
	UserName varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512));

INSERT @instance
SELECT DISTINCT pms.InstanceID
FROM Perf_MonitoredServers pms
LEFT OUTER JOIN Security_DatabaseUserPermissions_Stage sdr ON sdr.InstanceID = pms.InstanceID
WHERE sdr.DatabaseName IS NULL
AND (IsActive = 1 OR IsPushActive = 1);

DELETE Security_DatabaseUserPermissions
OUTPUT GETDATE(), 'Server Decom', deleted.InstanceID, deleted.DatabaseName,
	deleted.UserName, deleted.Object, deleted.ObjectType, deleted.Action, deleted.AccessType INTO @userpermissions
WHERE InstanceID IN (
	SELECT InstanceID 
	FROM Perf_MonitoredServers
	WHERE IsActive = 0 AND IsPushActive = 0)

MERGE Security_DatabaseUserPermissions AS t
USING (SELECT * FROM Security_DatabaseUserPermissions_Stage) AS s
ON (t.InstanceID = s.InstanceID 
	AND t.DatabaseName = s.DatabaseName
	AND t.UserName = s.UserName
	AND t.Object = s.Object
	AND t.ObjectType = s.ObjectType
	AND t.Action = s.Action
	AND t.AccessType = s.AccessType)
WHEN MATCHED THEN
	UPDATE SET LastUpdate = GETDATE()
WHEN NOT MATCHED BY TARGET THEN
	INSERT (InstanceID, DatabaseName, UserName, Object, ObjectType, Action, AccessType, LastUpdate) 
	VALUES (InstanceID, DatabaseName, UserName, Object, ObjectType, Action, AccessType, GETDATE())
WHEN NOT MATCHED BY SOURCE AND t.InstanceID NOT IN (SELECT InstanceID FROM @instance) THEN
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
	INTO @userpermissions;

INSERT Security_DatabaseUserPermissions_History
SELECT * FROM @userpermissions
WHERE ChangeType <> 'UPDATE';


/************************      Logins       **************************/
DELETE @instance;
DECLARE @logins TABLE (ChangeDate datetime, ChangeType varchar(512), InstanceID smallint, 
	LoginName varchar(1024), CreateDate smalldatetime, UpdateDate smalldatetime, DBName varchar(512), 
	DenyLogin bit, HasAccess bit, isNTname bit, isNTgroup bit, isNTuser bit);

INSERT @instance
SELECT DISTINCT pms.InstanceID
FROM Perf_MonitoredServers pms
LEFT OUTER JOIN Security_Logins_Stage sdr ON sdr.InstanceID = pms.InstanceID
WHERE sdr.LoginName IS NULL
AND (IsActive = 1 OR IsPushActive = 1);

DELETE Security_Logins
OUTPUT GETDATE(), 'Server Decom', deleted.InstanceID, deleted.LoginName, deleted.CreateDate,
	deleted.UpdateDate, deleted.DBName, deleted.DenyLogin, deleted.HasAccess, deleted.isNTname,
	deleted.isNTgroup, deleted.isNTuser INTO @logins
WHERE InstanceID IN (
	SELECT InstanceID 
	FROM Perf_MonitoredServers
	WHERE IsActive = 0 AND IsPushActive = 0)

MERGE Security_Logins AS t
USING (SELECT * FROM Security_Logins_Stage) AS s
ON (t.InstanceID = s.InstanceID 
	AND t.LoginName = s.LoginName
	AND t.CreateDate = s.CreateDate
--  AND t.UpdateDate = s.UpdateDate -- This will cause an INSERT/DELETE everytime the UpdateDate changes
	AND t.DBName = s.DBName
	AND t.DenyLogin = s.DenyLogin
	AND t.HasAccess = s.HasAccess
	AND t.isNTname = s.isNTname
	AND t.isNTgroup = s.isNTgroup
	AND t.isNTuser = s.isNTuser)
WHEN MATCHED THEN
	UPDATE SET LastUpdate = GETDATE(), t.UpdateDate = s.UpdateDate
WHEN NOT MATCHED BY TARGET THEN
	INSERT (InstanceID, LoginName, CreateDate, UpdateDate, DBName, DenyLogin, HasAccess,
		isNTname, isNTgroup, isNTuser, LastUpdate) 
	VALUES (InstanceID, LoginName, CreateDate, UpdateDate, DBName, DenyLogin, HasAccess,
		isNTname, isNTgroup, isNTuser, GETDATE())
WHEN NOT MATCHED BY SOURCE AND t.InstanceID NOT IN (SELECT InstanceID FROM @instance) THEN
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



/************************      Server Permissions        **************************/
DELETE @instance;
DECLARE @serveraccess TABLE (ChangeDate datetime, ChangeType varchar(512), InstanceID smallint, 
	UserName varchar(512), Class varchar(512), Permission varchar(512), Type varchar(512));

INSERT @instance
SELECT DISTINCT pms.InstanceID
FROM Perf_MonitoredServers pms
LEFT OUTER JOIN Security_ServerPermissions_Stage sdr ON sdr.InstanceID = pms.InstanceID
WHERE sdr.UserName IS NULL
AND (IsActive = 1 OR IsPushActive = 1);

DELETE Security_ServerPermissions
OUTPUT GETDATE(), 'Server Decom', deleted.InstanceID, deleted.UserName,
	deleted.Class, deleted.Permission, deleted.Type INTO @serveraccess
WHERE InstanceID IN (
	SELECT InstanceID 
	FROM Perf_MonitoredServers
	WHERE IsActive = 0 AND IsPushActive = 0)

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
WHEN NOT MATCHED BY SOURCE AND t.InstanceID NOT IN (SELECT InstanceID FROM @instance) THEN
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



/************************      Server Roles      **************************/
DELETE @instance;
DECLARE @serverroles TABLE (ChangeDate datetime, ChangeType varchar(512), InstanceID smallint, 
	ServerRole varchar(512), MemberName varchar(512));

INSERT @instance
SELECT DISTINCT pms.InstanceID
FROM Perf_MonitoredServers pms
LEFT OUTER JOIN Security_ServerRoles_Stage sdr ON sdr.InstanceID = pms.InstanceID
WHERE sdr.ServerRole IS NULL
AND (IsActive = 1 OR IsPushActive = 1);

DELETE Security_ServerRoles
OUTPUT GETDATE(), 'Server Decom', deleted.InstanceID, 
	deleted.ServerRole, deleted.MemberName INTO @serverroles
WHERE InstanceID IN (
	SELECT InstanceID 
	FROM Perf_MonitoredServers
	WHERE IsActive = 0 AND IsPushActive = 0)

MERGE Security_ServerRoles AS t
USING (SELECT * FROM Security_ServerRoles_Stage) AS s
ON (t.InstanceID = s.InstanceID 
	AND t.ServerRole = s.ServerRole
	AND t.MemberName = s.MemberName)
WHEN MATCHED THEN
	UPDATE SET LastUpdate = GETDATE()
WHEN NOT MATCHED BY TARGET THEN
	INSERT (InstanceID, ServerRole, MemberName, LastUpdate) 
	VALUES (InstanceID, ServerRole, MemberName, GETDATE())
WHEN NOT MATCHED BY SOURCE AND t.InstanceID NOT IN (SELECT InstanceID FROM @instance) THEN
	DELETE 
OUTPUT GETDATE(), $action, 
	CASE $action
		WHEN 'INSERT' THEN inserted.InstanceID
		WHEN 'DELETE' THEN deleted.InstanceID END,
	CASE $action
		WHEN 'INSERT' THEN inserted.ServerRole
		WHEN 'DELETE' THEN deleted.ServerRole END,
	CASE $action
		WHEN 'INSERT' THEN inserted.MemberName
		WHEN 'DELETE' THEN deleted.MemberName END
	INTO @serverroles;

INSERT Security_ServerRoles_History
SELECT * FROM @serverroles
WHERE ChangeType <> 'UPDATE';


END;
GO







