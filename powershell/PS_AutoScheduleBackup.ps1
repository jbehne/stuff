<#
    Script:     PS_AutoScheduleBackup.ps1
    Parameters: <none>
    Usage:      Manual execution only
    Purpose:    This script analyzes the backup history of a server's databases
                and determines the best tme to schedule the new maintenance. It
                also sets the schedule and outputs the code to update SERVINFO.
#> 

# Get a list of active servers to apply scheduling, remove servers already scheduled.

$query = "
SELECT ServerName, Version 
FROM Perf_MonitoredServers 
WHERE ServerName IN (
'C1DBD031',
'C1DBD037',
'C1DBD045',
'V01DBSWIN010',
'V01DBSWIN011',
'V01DBSWIN025',
'V01DBSWIN026'
) order by servername
"

# Execute the query and store the servernames in $servers
$servers = Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query $query

# Create an empty array for SERVINFO update queries
$servinfo = @()

# Loop through each server
foreach ($server in $servers)
{
    # Execute the proc to get the top most common backup time and insert into variables
    $backuptimes = Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "EXEC usp_GetBackupTimes '$($server.ServerName)'"

    $FULLdayofweek = $backuptimes[0].Day
    $FULLhour = "$($backuptimes[0].Hour)0000"
    $DIFFhour = "$($backuptimes[1].Hour)0000"

    # If no log backups were found (like an empty server) then schedule DIFF at the same hour as FULL
    if ($FULLdayofweek -eq $null)
    {
        $FULLdayofweek = $backuptimes.Day
        $FULLhour = "$($backuptimes.Hour)0000"
        $DIFFhour = "$($backuptimes.Hour)0000"
    }

    # Execute this proc by passing in the variables from the previous proc and save the output
    $scheduleSQL = Invoke-Sqlcmd -ServerInstance C1DBD069 -Database SQLMONITOR -Query "EXEC usp_GenerateBackupSchedule '$FULLdayofweek', '$FULLhour', '$DIFFhour'" 
    
    # The first line returned is informational for output to the console
    "$($server.ServerName) will be scheduled as $($scheduleSQL[0].schedule)"

    # Execute the remaining 3 lines which are the TSQL statements to schedule each job
    Invoke-Sqlcmd -ServerInstance $($server.ServerName) -Query $scheduleSQL[1].schedule
    Invoke-Sqlcmd -ServerInstance $($server.ServerName) -Query $scheduleSQL[2].schedule
    Invoke-Sqlcmd -ServerInstance $($server.ServerName) -Query $scheduleSQL[3].schedule

    # If this is a 2008 server then apply the 1.2b hotfix to the backup proc in SQLADMIN
    if ($server.Version -lt 11) 
    {
        Invoke-Sqlcmd -ServerInstance $($server.ServerName) -Database SQLADMIN -InputFile '\\C1UTL209\e$\sqlserver\SQL monitor code\BackupHotfix2008.sql'
        "$($server.ServerName) has been patched for 2008"
    }

    # Add the update statement needed to set the backup_grp in SERVINFO
    $servinfo += "UPDATE CCDB2.MDB_DB_DATA
                    SET BACKUP_GRP = 'Z', DB_COMMENTS = COALESCE(DB_COMMENTS, '') CONCAT ' JPB moved to new backup plan'
                    WHERE SRVR_NM = '$($server.ServerName)'
                    AND BACKUP_GRP <> 'Z';"
}

# Output the SERVINFO commands to be executed (Note to self - automate this too)
$servinfo