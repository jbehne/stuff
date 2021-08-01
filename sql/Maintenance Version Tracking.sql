DROP TABLE Maintenance_Versions
GO
CREATE TABLE Maintenance_Versions (ServerName varchar(512)
	, BackupDatabases varchar(8)
	, AddNewDatabasesToBackup varchar(8)
	, Index_AllDatabases varchar(8)
	, Index_RebuildHeaps varchar(8)
	, Index_ManageClusteredIndexes varchar(8)
	, Index_ManageNonClusteredIndexes varchar(8)
	, Statistics_Update varchar(8)
	, IntegrityCheck varchar(8));

CREATE CLUSTERED INDEX CIX_Maintenance_Versions ON Maintenance_Versions (ServerName) WITH (DATA_COMPRESSION=PAGE);

CREATE TABLE Maintenance_CurrentVersion (MaintenanceProc varchar(128), Version varchar(8));
CREATE CLUSTERED INDEX CIX_Maintenance_CurrentVersion ON Maintenance_CurrentVersion (MaintenanceProc) WITH (DATA_COMPRESSION=PAGE);


INSERT Maintenance_CurrentVersion VALUES 
('BackupDatabases', '1.4'),
('AddNewDatabasesToBackup', '1.4'),
('Index_AllDatabases', '1.2'),
('Index_RebuildHeaps', '1.2'),
('Index_ManageClusteredIndexes', '1.2'),
('Index_ManageNonClusteredIndexes', '1.3'),
('Statistics_Update', '1.2'),
('IntegrityCheck', '1.1');

SELECT * 
FROM Maintenance_Versions 
WHERE BackupDatabases <> (SELECT Version FROM Maintenance_CurrentVersion WHERE MaintenanceProc = 'BackupDatabases')
OR AddNewDatabasesToBackup <> (SELECT Version FROM Maintenance_CurrentVersion WHERE MaintenanceProc = 'AddNewDatabasesToBackup')
OR Index_AllDatabases <> (SELECT Version FROM Maintenance_CurrentVersion WHERE MaintenanceProc = 'Index_AllDatabases')
OR Index_RebuildHeaps <> (SELECT Version FROM Maintenance_CurrentVersion WHERE MaintenanceProc = 'Index_RebuildHeaps')
OR Index_ManageClusteredIndexes <> (SELECT Version FROM Maintenance_CurrentVersion WHERE MaintenanceProc = 'Index_ManageClusteredIndexes')
OR Index_ManageNonClusteredIndexes <> (SELECT Version FROM Maintenance_CurrentVersion WHERE MaintenanceProc = 'Index_ManageNonClusteredIndexes')
OR Statistics_Update <> (SELECT Version FROM Maintenance_CurrentVersion WHERE MaintenanceProc = 'Statistics_Update')
OR IntegrityCheck <> (SELECT Version FROM Maintenance_CurrentVersion WHERE MaintenanceProc = 'IntegrityCheck')

/*
ServerName	usp_BackupDatabases	usp_AddNewDatabasesToBackup	usp_Index_RebuildHeaps	

usp_Index_ManageClusteredIndexes	usp_Index_ManageNonClusteredIndexes	usp_Index_AllDatabases	

usp_Statistics_Update	usp_IntegrityCheck


C1DBD069	1.4  	1.2  	1.2  	1.2  	1.2  	1.2  	1.1  	NULL
*/


