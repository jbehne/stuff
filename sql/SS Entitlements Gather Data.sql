/* GET ACCOUNTS */

MERGE SS_Entitlement_Account AS target
USING (
	SELECT name, 
	CASE WHEN isntgroup = 1 THEN 'ADGROUP'
	WHEN isntuser = 1 THEN 'ADUSER'
	ELSE 'LOCAL' END type
	FROM syslogins) AS source (name, type)
ON (source.name = target.AccountName AND source.type = target.type)
WHEN NOT MATCHED BY TARGET THEN
	INSERT (AccountName, Type)
	VALUES (source.name, source.type)
OUTPUT $action, GETDATE(), inserted.* INTO SS_Entitlement_Account_History;

GO
/*
SELECT * FROM SS_Entitlement_Account
SELECT * FROM SS_Entitlement_Account_History
DELETE SS_Entitlement_Account
DELETE SS_Entitlement_Account_History
*/

/**/
--CREATE TABLE SS_Entitlement_ServerAccountAccess (UserID int, ServerID int, Class nvarchar(512), Permission nvarchar(512), Type nvarchar(512));
WITH srvprm AS (
SELECT DISTINCT @@SERVERNAME ServerName, Name, class_desc Class, permission_name Permission, state_desc PermType
FROM sys.server_permissions perm
INNER JOIN sys.server_principals prin ON perm.grantee_principal_id = prin.principal_id),
srvprmacct AS (
SELECT * FROM srvprm s
INNER JOIN SS_Entitlement_Account ea ON ea.AccountName = s.name)

MERGE SS_Entitlement_ServerAccountAccess AS target
USING (
	SELECT UserID, ServerID, Class, Permission, PermType
	FROM srvprmacct spa
	INNER JOIN SS_Entitlement_Server es ON es.ServerName = spa.ServerName) AS source (UserID, ServerID, Class, Permission, Type)
ON (source.UserID = target.UserID AND source.ServerID = target.ServerID)
WHEN NOT MATCHED BY TARGET THEN
	INSERT (UserID, ServerID, Class, Permission, Type) VALUES (source.UserID, source.ServerID, source.Class, source.Permission, source.Type)
WHEN NOT MATCHED BY SOURCE 
	THEN DELETE
OUTPUT $action, GETDATE(), inserted.*, deleted.*;
/**/

DECLARE @sa TABLE (ServerRole varchar(512), MemberName varchar(512), MemberSID varchar(128));

INSERT @sa
EXEC sp_helpsrvrolemember;

SELECT ServerRole, MemberName FROM @sa ORDER BY MemberName;

/**/

SELECT s.name Role, sc.name + '.' + so.name Object, 
		CASE action WHEN 26 THEN 'REFERENCES'
			 WHEN 178 THEN 'CREATE FUNCTION'
			 WHEN 193 THEN 'SELECT'
			 WHEN 195 THEN 'INSERT'
			 WHEN 196 THEN 'DELETE'
			 WHEN 197 THEN 'UPDATE'
			 WHEN 198 THEN 'CREATE TABLE'
			 WHEN 203 THEN 'CREATE DATABASE'
			 WHEN 207 THEN 'CREATE VIEW'
			 WHEN 222 THEN 'CREATE PROCEDURE'
			 WHEN 224 THEN 'EXECUTE'
			 WHEN 228 THEN 'BACKUP DATABASE'
			 WHEN 233 THEN 'CREATE DEFAULT'
			 WHEN 235 THEN 'BACKUP LOG'
			 WHEN 236 THEN 'CREATE RULE'
		END AS Action,
		CASE protecttype 
			WHEN 204 THEN 'GRANT_W_GRANT '
			WHEN 205 THEN 'GRANT '
			WHEN 206 THEN 'DENY '
			ELSE 'BOGUS'
		END AS Type
	FROM sys.sysprotects sp 
	INNER JOIN sys.objects so ON so.object_id = sp.id 
	INNER JOIN sys.sysusers s ON sp.uid = s.uid 
	INNER JOIN sys.schemas sc ON sc.schema_id = so.schema_id
	WHERE issqlrole = 1 OR isapprole = 1

	UNION ALL

	SELECT name Role, '_DB_GLOBAL' Object, permission_name Action, state_desc Type
	FROM .sys.database_permissions perm
	INNER JOIN sys.database_principals prin ON prin.principal_id = perm.grantee_principal_id
	WHERE class_desc = 'DATABASE'
	AND type_desc = 'DATABASE_ROLE'
	ORDER BY s.name


	/**/

	SELECT su.name AS Role, sysusers_1.name AS UserName
FROM dbo.sysusers su
INNER JOIN dbo.sysmembers sm ON su.uid = sm.groupuid 
INNER JOIN dbo.sysusers sysusers_1 ON sm.memberuid = sysusers_1.uid
WHERE sysusers_1.name <> 'dbo'
ORDER BY Role, UserName

/**/

SELECT     s.name [User], sc.name + '.' + so.name Object, 
		CASE action WHEN 26 THEN 'REFERENCES'
			 WHEN 178 THEN 'CREATE FUNCTION'
			 WHEN 193 THEN 'SELECT'
			 WHEN 195 THEN 'INSERT'
			 WHEN 196 THEN 'DELETE'
			 WHEN 197 THEN 'UPDATE'
			 WHEN 198 THEN 'CREATE TABLE'
			 WHEN 203 THEN 'CREATE DATABASE'
			 WHEN 207 THEN 'CREATE VIEW'
			 WHEN 222 THEN 'CREATE PROCEDURE'
			 WHEN 224 THEN 'EXECUTE'
			 WHEN 228 THEN 'BACKUP DATABASE'
			 WHEN 233 THEN 'CREATE DEFAULT'
			 WHEN 235 THEN 'BACKUP LOG'
			 WHEN 236 THEN 'CREATE RULE'
		END AS Action, 
		CASE protecttype 
			WHEN 204 THEN 'GRANT_W_GRANT '
			WHEN 205 THEN 'GRANT '
			WHEN 206 THEN 'DENY '
			ELSE 'BOGUS'
		END AS Type, grantor
	FROM sys.sysprotects sp 
	INNER JOIN sys.objects so ON so.object_id = sp.id 
	INNER JOIN sys.sysusers s ON sp.uid = s.uid 
	INNER JOIN sys.schemas sc ON sc.schema_id = so.schema_id
	WHERE issqluser = 1
	
	UNION ALL

	SELECT name [User], '_DB_GLOBAL' Object, permission_name Action, state_desc Type, grantor_principal_id
	FROM sys.database_permissions perm
	INNER JOIN sys.database_principals prin ON prin.principal_id = perm.grantee_principal_id
	WHERE class_desc = 'DATABASE'
	AND type_desc = 'SQL_USER'
	AND name <> 'dbo'
	ORDER BY s.name