--SELECT * FROM Permissions_ServerRole_Stage 
SELECT * FROM Permissions_ServerRole 
--SELECT * FROM Permissions_Server_Stage 
SELECT * FROM Permissions_Server
SELECT * FROM Permissions_AccountsInRoles
SELECT * FROM Permissions_AccountAccess 
SELECT * FROM Permissions_RoleAccess WHERE AccessType <> 'REVOKE'


SELECT ServerName, DatabaseName, ApplicationName, Comments, 
CASE WHEN IsExists = 1 THEN 'TRUE' ELSE 'FALSE' END DatabaseExists
FROM Permissions_DatabaseList

/*
TRUNCATE TABLE Permissions_Server_Stage 
TRUNCATE TABLE Permissions_Server
TRUNCATE TABLE Permissions_AccountsInRoles
TRUNCATE TABLE Permissions_AccountAccess 
TRUNCATE TABLE Permissions_RoleAccess
*/

