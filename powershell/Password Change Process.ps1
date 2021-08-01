#Get-Service -ComputerName C1DBD536 | Where Name -like "*sql*" | Select Name, DisplayName, Status

function f_GetServerInformation ($server)
{
    $results = @()
    $service = Get-WmiObject -ComputerName $server -Class Win32_Service | Where Name -like "*sql*" | Select Name, State, StartName
    $startup = (Invoke-Sqlcmd -ServerInstance $server -Query "SELECT sqlserver_start_time FROM sys.dm_os_sys_info").sqlserver_start_time.ToString("MM/dd/yyyy hh:mm:ss")
    return $results
}

workflow wf_LoadServers ($servers)
{
    $results = @()
    
    foreach -parallel ($server in $servers)
    {
        $WORKFLOW:results += f_GetServerInformation $server
    }

    $results
}

$query = "
    SELECT TOP 3 * FROM OPENQUERY(SERVINFO,
    'SELECT a.SRVR_NM 
    FROM CCDB2.MDB_DBMS_DATA a
    INNER JOIN CCDB2.MDB_SRVR_NAME_PROPERTIES b ON a.SRVR_NM = b.SRVR_NM
    WHERE b.DBMS = ''SQL''
    AND ENVIRONMENT <> ''PROD''
    AND DBMS_TYP = ''SQL SERVER''');"

$servers = (Invoke-Sqlcmd -ServerInstance C1DBD069 -Query $query).SRVR_NM

wf_LoadServers $servers

<#

Get-WmiObject -ComputerName C1DBD536 -Class Win32_Service | Where Name -like "*sql*" | Select Name, State, StartName
Invoke-Sqlcmd -ServerInstance C1DBD536 -Query "SELECT sqlserver_start_time FROM sys.dm_os_sys_info"

#>

<#
# Inputs
  Environment (prod/test)
  Time of pw change
  Checkbox for filter only issues


# display
datatable - server, start time, sql svc acct name, sql status, agent status, is status, rs status

<change the svc account if it does not match MSSQLSERVER>

# change pw
highlight servers -> change pw menu
1. set pw
2. restart services


Also - change passwords for:
*  Report server data sources
*  IIS web pools UTL777, UTL209
*  For prod only - update linked server for z_sqlint

#>