CREATE TABLE Security_ServerRoles_Stage (InstanceID smallint, ServerRole varchar(512), MemberName varchar(512));
CREATE TABLE Security_ServerPermissions_Stage (InstanceID smallint, UserName varchar(512), Class varchar(512), Permission varchar(512), Type varchar(512));
CREATE TABLE Security_DatabaseRolePermissions_Stage (InstanceID smallint, DatabaseName varchar(512), Role varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512));
CREATE TABLE Security_DatabaseRoleMembers_Stage (InstanceID smallint, DatabaseName varchar(512), Role varchar(512), MemberName varchar(512));
CREATE TABLE Security_DatabaseUserPermissions_Stage (InstanceID smallint, DatabaseName varchar(512), UserName varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512));


CREATE TABLE Security_ServerRoles (InstanceID smallint, ServerRole varchar(512), MemberName varchar(512), LastUpdate smalldatetime);
CREATE CLUSTERED INDEX CIX_Security_ServerRoles ON Security_ServerRoles (InstanceID) WITH (DATA_COMPRESSION=PAGE);
CREATE TABLE Security_ServerPermissions (InstanceID smallint, UserName varchar(512), Class varchar(512), Permission varchar(512), Type varchar(512), LastUpdate smalldatetime);
CREATE CLUSTERED INDEX CIX_Security_ServerPermissions ON Security_ServerPermissions (InstanceID) WITH (DATA_COMPRESSION=PAGE);
CREATE TABLE Security_DatabaseRolePermissions (InstanceID smallint, DatabaseName varchar(512), Role varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512), LastUpdate smalldatetime);
CREATE CLUSTERED INDEX CIX_Security_DatabaseRolePermissions ON Security_DatabaseRolePermissions (InstanceID) WITH (DATA_COMPRESSION=PAGE);
CREATE TABLE Security_DatabaseRoleMembers (InstanceID smallint, DatabaseName varchar(512), Role varchar(512), MemberName varchar(512), LastUpdate smalldatetime);
CREATE CLUSTERED INDEX CIX_Security_DatabaseRoleMembers ON Security_DatabaseRoleMembers (InstanceID) WITH (DATA_COMPRESSION=PAGE);
CREATE TABLE Security_DatabaseUserPermissions (InstanceID smallint, DatabaseName varchar(512), UserName varchar(512), Object varchar(512), ObjectType varchar(512), Action varchar(512), AccessType varchar(512), LastUpdate smalldatetime);
CREATE CLUSTERED INDEX CIX_Security_DatabaseUserPermissions ON Security_DatabaseUserPermissions (InstanceID) WITH (DATA_COMPRESSION=PAGE);


SELECT * FROM Security_ServerRoles_Stage 
SELECT * FROM Security_ServerPermissions_Stage 
SELECT * FROM Security_DatabaseRolePermissions_Stage
SELECT * FROM Security_DatabaseRoleMembers_Stage 
SELECT * FROM Security_DatabaseUserPermissions_Stage

SELECT * FROM Security_ServerRoles 
SELECT * FROM Security_ServerPermissions 
SELECT * FROM Security_DatabaseRolePermissions
SELECT * FROM Security_DatabaseRoleMembers 
SELECT * FROM Security_DatabaseUserPermissions

TRUNCATE TABLE Security_ServerRoles_Stage 
TRUNCATE TABLE Security_ServerPermissions_Stage 
TRUNCATE TABLE Security_DatabaseRolePermissions_Stage
TRUNCATE TABLE Security_DatabaseRoleMembers_Stage 
TRUNCATE TABLE Security_DatabaseUserPermissions_Stage


TRUNCATE TABLE Security_ServerRoles 
TRUNCATE TABLE Security_ServerPermissions 
TRUNCATE TABLE Security_DatabaseRolePermissions
TRUNCATE TABLE Security_DatabaseRoleMembers 
TRUNCATE TABLE Security_DatabaseUserPermissions


DROP TABLE Security_ServerRoles_Stage 
DROP TABLE Security_ServerPermissions_Stage 
DROP TABLE Security_DatabaseRolePermissions_Stage
DROP TABLE Security_DatabaseRoleMembers_Stage 
DROP TABLE Security_DatabaseUserPermissions_Stage

DROP TABLE Security_ServerRoles 
DROP TABLE Security_ServerPermissions 
DROP TABLE Security_DatabaseRolePermissions
DROP TABLE Security_DatabaseRoleMembers 
DROP TABLE Security_DatabaseUserPermissions