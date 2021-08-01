USE SQLMONITOR
CREATE TABLE Backup_Ignore (InstanceID smallint, DatabaseName varchar(256));
CREATE CLUSTERED INDEX CIX_Backup_Ignore ON Backup_Ignore (InstanceID) WITH (DATA_COMPRESSION=PAGE);