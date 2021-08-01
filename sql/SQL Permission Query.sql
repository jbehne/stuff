-- LOCAL ACCOUNTS ONLY
SELECT * FROM sysusers WHERE isntuser = 0 AND isntgroup = 0


-- LOCAL ACCOUNTS WITH SERVER ROLE PERMISSIONS
SELECT @@SERVERNAME ServerName, 'SERVER' DatabaseName, role.name AS RoleName, member.name AS MemberName
FROM sys.server_role_members  
JOIN sys.server_principals AS role  
    ON sys.server_role_members.role_principal_id = role.principal_id  
JOIN sys.server_principals AS member  
    ON sys.server_role_members.member_principal_id = member.principal_id
WHERE member.type = 'S'


-- LOCAL ACCOUNTS WITH EXPLICIT SERVER ACCESS
SELECT DISTINCT @@SERVERNAME ServerName, 'SERVER' DatabaseName, Name, class_desc Class, permission_name Permission, state_desc Type
FROM sys.server_permissions perm
INNER JOIN sys.server_principals prin ON perm.grantee_principal_id = prin.principal_id
WHERE prin.type = 'S'
AND Name NOT LIKE '##%'
AND perm.type <> 'COSQ';


-- LOCAL ACCOUNTS IN ROLES
SELECT @@SERVERNAME ServerName, DB_NAME() DatabaseName, su.name AS Role, sysusers_1.name AS UserName
FROM dbo.sysusers su
INNER JOIN dbo.sysmembers sm ON su.uid = sm.groupuid 
INNER JOIN dbo.sysusers sysusers_1 ON sm.memberuid = sysusers_1.uid
WHERE sysusers_1.name <> 'dbo'
AND sysusers_1.issqluser = 1

-- ROLE EXPLICIT SECURITY GRANTS
SELECT @@SERVERNAME ServerName, DB_NAME() DatabaseName,s.name Role, sc.name + '.' + so.name Object, 
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
              ELSE 'REVOKE'
       END AS Type,*
FROM sys.sysprotects sp 
INNER JOIN sys.objects so ON so.object_id = sp.id 
INNER JOIN sys.sysusers s ON sp.uid = s.uid 
INNER JOIN sys.schemas sc ON sc.schema_id = so.schema_id
WHERE issqlrole = 1 OR isapprole = 1 AND is_ms_shipped = 0

UNION ALL

SELECT @@SERVERNAME ServerName, DB_NAME() DatabaseName,name Role, '_DB_GLOBAL' Object, permission_name Action, state_desc Type
FROM .sys.database_permissions perm
INNER JOIN sys.database_principals prin ON prin.principal_id = perm.grantee_principal_id
WHERE class_desc = 'DATABASE'
AND type_desc = 'DATABASE_ROLE'
ORDER BY s.name



-- LOCAL ACCOUNT EXPLICIT SECURITY GRANTS
SELECT @@SERVERNAME ServerName, DB_NAME() DatabaseName, s.name [User], sc.name + '.' + so.name Object, 
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
                ELSE 'REVOKE'
        END AS Type
FROM sys.sysprotects sp 
INNER JOIN sys.objects so ON so.object_id = sp.id 
INNER JOIN sys.sysusers s ON sp.uid = s.uid 
INNER JOIN sys.schemas sc ON sc.schema_id = so.schema_id
WHERE issqlrole = 0 
AND isapprole = 0

UNION ALL

SELECT @@SERVERNAME ServerName, DB_NAME() DatabaseName, name Role, '_DB_GLOBAL' Object, permission_name Action, state_desc Type
FROM .sys.database_permissions perm
INNER JOIN sys.database_principals prin ON prin.principal_id = perm.grantee_principal_id
WHERE class_desc = 'DATABASE'
AND type_desc <> 'DATABASE_ROLE'
AND permission_name <> 'CONNECT'
ORDER BY s.name
