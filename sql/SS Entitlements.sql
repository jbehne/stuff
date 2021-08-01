CREATE TABLE SS_Entitlement_Server (ServerID int IDENTITY PRIMARY KEY, ServerName nvarchar(512));
CREATE TABLE SS_Entitlement_Database (DatabaseID int IDENTITY PRIMARY KEY, ServerID int, DatabaseName nvarchar(512));
CREATE TABLE SS_Entitlement_Account (UserID int IDENTITY PRIMARY KEY, AccountName nvarchar(512), Type nvarchar(12));

CREATE TABLE SS_Entitlement_DatabaseRole (RoleID int IDENTITY PRIMARY KEY, RoleName nvarchar(512), DatabaseID int);
CREATE TABLE SS_Entitlement_DatabaseRoleAccess (RoleID int, Object nvarchar(512), Action nvarchar(24), Type nvarchar(1024));
CREATE TABLE SS_Entitlement_DatabaseRoleAccount (RoleID int, UserID int);

CREATE TABLE SS_Entitlement_DatabaseAccountAccess (UserID int, DatabaseID int, Object nvarchar(512), Action nvarchar(24), Type nvarchar(512));


CREATE TABLE SS_Entitlement_ServerAccountAccess (UserID int, ServerID int, Class nvarchar(512), Permission nvarchar(512), Type nvarchar(512));



CREATE TABLE SS_Entitlement_Account_History (Operation nvarchar(24), ChangeDate datetime, UserID int, AccountName nvarchar(512), Type nvarchar(12));


