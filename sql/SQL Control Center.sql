USE [ControlCenter];
GO

CREATE TABLE Database_Active (DatabaseID uniqueidentifier, DatabaseName varchar(12), CreatedDate date, 
	DatabaseOwner varchar(512),	RetentionDays smallint);