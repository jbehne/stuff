CREATE TABLE Permissions_ServerRole_Stage (ServerName varchar(24), RoleName varchar(128), MemberName varchar(128));
CREATE TABLE Permissions_ServerRole (ServerName varchar(24), RoleName varchar(128), MemberName varchar(128));

CREATE TABLE Permissions_Server_Stage (ServerName varchar(24), RoleName varchar(128), UserName varchar(128), ObjectName varchar(256), ActionName varchar(128), AccessType varchar(128));
CREATE TABLE Permissions_Server (ServerName varchar(24), RoleName varchar(128), UserName varchar(128), ObjectName varchar(256), ActionName varchar(128), AccessType varchar(128));

CREATE TABLE Permissions_AccountsInRoles (ServerName varchar(24), DatabaseName varchar(256), RoleName varchar(128), MemberName varchar(128));

CREATE TABLE Permissions_AccountAccess (ServerName varchar(24), DatabaseName varchar(256), UserName varchar(128), ObjectName varchar(256), ActionName varchar(128), AccessType varchar(128));

CREATE TABLE Permissions_RoleAccess (ServerName varchar(24), DatabaseName varchar(256), RoleName varchar(128),ObjectName varchar(256), ActionName varchar(128), AccessType varchar(128));

CREATE TABLE Permissions_DatabaseList (ServerName varchar(24), DatabaseName varchar(256), ApplicationName varchar(128), Comments varchar(1024), IsExists bit);

/*
DROP TABLE Permissions_ServerRole_Stage
DROP TABLE Permissions_ServerRole
DROP TABLE Permissions_Server_Stage
DROP TABLE Permissions_Server
DROP TABLE Permissions_Server_Stage 
DROP TABLE Permissions_Server
DROP TABLE Permissions_AccountsInRoles
DROP TABLE Permissions_AccountAccess 
DROP TABLE Permissions_RoleAccess
DROP TABLE Permissions_DatabaseList
*/