# Check the SQL service to verify stopped.
Get-Service -ComputerName V01DBSWIN025 -Name MSSQLSERVER

# Change the password of agent and engine
$service = gwmi win32_service -computer V01DBSWIN025 -filter "name='SQLSERVERAGENT'"
$service.change($null,$null,$null,$null,$null,$null,$null,"xxx")

$service = gwmi win32_service -computer V01DBSWIN025 -filter "name='MSSQLSERVER'"
$service.change($null,$null,$null,$null,$null,$null,$null,"xxx")

# Start agent (which starts engine)
Get-Service -ComputerName V01DBSWIN025 -Name SQLSERVERAGENT | Start-Service

# Check for other services (RS, IS, etc) and repeat pw change for those.
Get-Service -ComputerName V01DBSWIN025 | Where DisplayName -like "*SQL*"



# Restart services
Get-Service -ComputerName C1DBD070 -Name MSSQLSERVER | Restart-Service -Force
Get-Service -ComputerName C1DBD070 -Name SQLSERVERAGENT | Restart-Service -Force


# Check start time          
Invoke-SqlCmd -ServerInstance MMDBD103 -Query "SELECT sqlserver_start_time FROM sys.dm_os_sys_info"

