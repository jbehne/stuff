USE SQLMONITOR

ALTER TABLE [dbo].[Backup_BackupHistory] DROP CONSTRAINT [FK_Backup_BackupHistory_MonitoredServer]ALTER TABLE [dbo].[Backup_BackupHistory_Stage] DROP CONSTRAINT [FK_Backup_BackupHistory_Stage_MonitoredServer]ALTER TABLE [dbo].[Perf_CounterData] DROP CONSTRAINT [FK_Perf_CounterData_MonitoredServer]ALTER TABLE [dbo].[Perf_CounterData_Stage] DROP CONSTRAINT [FK_Perf_CounterData_Stage_MonitoredServer]ALTER TABLE [dbo].[Perf_ErrorLog] DROP CONSTRAINT [FK_Perf_ErrorLog_MonitoredServer]ALTER TABLE [dbo].[Perf_FileIO] DROP CONSTRAINT [FK_Perf_FileIO_MonitoredServer]ALTER TABLE [dbo].[Perf_FileSpace] DROP CONSTRAINT [FK_Perf_FileSpace_MonitoredServer]ALTER TABLE [dbo].[Perf_IndexUsageStatistics] DROP CONSTRAINT [FK_Perf_IndexUsageStatistics_MonitoredServer]ALTER TABLE [dbo].[Perf_IndexUsageStatistics_Stage] DROP CONSTRAINT [FK_Perf_IndexUsageStatistics_Stage_MonitoredServer]ALTER TABLE [dbo].[Perf_MemoryGrants] DROP CONSTRAINT [FK_Perf_MemoryGrants_MonitoredServer]ALTER TABLE [dbo].[Perf_MonitoredServers_History] DROP CONSTRAINT [FK_Perf_MonitoredServers_History_MonitoredServer]ALTER TABLE [dbo].[Perf_Sessions] DROP CONSTRAINT [FK_Perf_Sessions_MonitoredServer]ALTER TABLE [dbo].[Perf_WaitStatistics] DROP CONSTRAINT [FK_Perf_WaitStatistics_MonitoredServer]

ALTER TABLE Perf_MonitoredServers DROP CONSTRAINT PK_PerfMonitoredServers;
GO
ALTER TABLE Perf_MonitoredServers ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_MonitoredServers ADD CONSTRAINT PK_PerfMonitoredServers PRIMARY KEY CLUSTERED (InstanceID) WITH (DATA_COMPRESSION=PAGE);
GO

SELECT 'ALTER TABLE ' + TABLE_NAME + ' ALTER COLUMN ' + COLUMN_NAME + ' smallint;'
FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'InstanceID' AND DATA_TYPE = 'int'

ALTER TABLE Backup_BackupHistory ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Backup_BackupHistory_Stage ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_FileIO ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_MemoryGrants ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_CounterData_Stage ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_FileSpace ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_IndexUsageStatistics ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_IndexUsageStatistics_Stage ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_Sessions ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_WaitStatistics ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_ErrorLog ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_MonitoredServers_History ALTER COLUMN InstanceID smallint;
GO
ALTER TABLE Perf_CounterData ALTER COLUMN InstanceID smallint;


ALTER TABLE [dbo].[Backup_BackupHistory] WITH CHECK ADD CONSTRAINT [FK_Backup_BackupHistory_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Backup_BackupHistory_Stage] WITH CHECK ADD CONSTRAINT [FK_Backup_BackupHistory_Stage_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Perf_CounterData] WITH CHECK ADD CONSTRAINT [FK_Perf_CounterData_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Perf_CounterData_Stage] WITH CHECK ADD CONSTRAINT [FK_Perf_CounterData_Stage_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Perf_ErrorLog] WITH CHECK ADD CONSTRAINT [FK_Perf_ErrorLog_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Perf_FileIO] WITH CHECK ADD CONSTRAINT [FK_Perf_FileIO_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Perf_FileSpace] WITH CHECK ADD CONSTRAINT [FK_Perf_FileSpace_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Perf_IndexUsageStatistics] WITH CHECK ADD CONSTRAINT [FK_Perf_IndexUsageStatistics_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Perf_IndexUsageStatistics_Stage] WITH CHECK ADD CONSTRAINT [FK_Perf_IndexUsageStatistics_Stage_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Perf_MemoryGrants] WITH CHECK ADD CONSTRAINT [FK_Perf_MemoryGrants_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Perf_MonitoredServers_History] WITH CHECK ADD CONSTRAINT [FK_Perf_MonitoredServers_History_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Perf_Sessions] WITH CHECK ADD CONSTRAINT [FK_Perf_Sessions_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) ALTER TABLE [dbo].[Perf_WaitStatistics] WITH CHECK ADD CONSTRAINT [FK_Perf_WaitStatistics_MonitoredServer] FOREIGN KEY([InstanceID]) REFERENCES [dbo].[Perf_MonitoredServers] ([InstanceID]) 