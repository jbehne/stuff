SELECT TOP 10 * FROM Security_DatabaseRolePermissions
SELECT TOP 10 * FROM Security_DatabaseRoleMembers
SELECT TOP 10 * FROM Security_DatabaseUserPermissions
SELECT TOP 10 * FROM Security_ServerPermissions
SELECT TOP 10 * FROM Security_ServerRoles
SELECT TOP 10 * FROM Security_Logins

CREATE CLUSTERED INDEX CIX_Security_DatabaseRolePermissions ON Security_DatabaseRolePermissions  (InstanceID) WITH (DATA_COMPRESSION=PAGE);
CREATE CLUSTERED INDEX CIX_Security_DatabaseRoleMembers		ON Security_DatabaseRoleMembers		 (InstanceID) WITH (DATA_COMPRESSION=PAGE);
CREATE CLUSTERED INDEX CIX_Security_DatabaseUserPermissions	ON Security_DatabaseUserPermissions	 (InstanceID) WITH (DATA_COMPRESSION=PAGE);
CREATE CLUSTERED INDEX CIX_Security_ServerPermissions		ON Security_ServerPermissions		 (InstanceID) WITH (DATA_COMPRESSION=PAGE);
CREATE CLUSTERED INDEX CIX_Security_ServerRoles				ON Security_ServerRoles				 (InstanceID) WITH (DATA_COMPRESSION=PAGE);
CREATE CLUSTERED INDEX CIX_Security_Logins			ON Security_Logins				 (InstanceID) WITH (DATA_COMPRESSION=PAGE);

SELECT TOP 10 * 
FROM Security_Logins l
INNER JOIN Security_DatabaseRoleMembers drm ON drm.InstanceID = l.InstanceID AND drm.MemberName = l.LoginName
INNER JOIN Security_DatabaseRolePermissions drp ON drp.InstanceID = drm.InstanceID AND drp.DatabaseName = drm.DatabaseName 
	AND drp.Role = drm.Role
INNER JOIN Security_DatabaseUserPermissions dup ON dup.InstanceID = l.InstanceID AND dup.UserName = l.LoginName
INNER JOIN Security_ServerPermissions sp ON sp.InstanceID = l.InstanceID AND sp.UserName = l.LoginName
INNER JOIN Security_ServerRoles sr ON sr.InstanceID = l.InstanceID AND sr.MemberName = l.LoginName


CREATE TABLE Security_Logins_Stage (InstanceID smallint, LoginName varchar(1024));