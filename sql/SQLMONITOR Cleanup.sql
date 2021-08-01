select 'EXEC usp_DeleteMonitoredServer ''' + ServerName + '''',
* from Perf_MonitoredServers where lastupdated < getdate() - 30

delete from Perf_MonitoredServers where lastupdated < getdate() - 90

EXEC usp_DeleteMonitoredServer 'C1DBD028'
GO
EXEC usp_DeleteMonitoredServer 'C1DBD040'
GO
EXEC usp_DeleteMonitoredServer 'C1DBD055'
GO
EXEC usp_DeleteMonitoredServer 'C1DBD057'
GO
EXEC usp_DeleteMonitoredServer 'C1DBD088'
GO
EXEC usp_DeleteMonitoredServer 'C1DBD222'