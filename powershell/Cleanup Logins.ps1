$list = Get-Content C:\Users\Public\Documents\list.csv | Select -Skip 1

foreach($l in $list)
{
    $server = $l.Split(',')[1]
    $account = $l.Split(',')[0]

    $login = Invoke-Sqlcmd -ServerInstance $server -Query "SELECT @@servername, name FROM syslogins WHERE name = '$account'"
    $users = Invoke-Sqlcmd -ServerInstance $server -Query "EXEC sp_msforeachdb 'USE [?]; SELECT ''?'', name FROM sysusers WHERE name = ''$account'''"
    if ($users -eq $null)
    {
        "No users found in $server - dropping login $($login.Name)" | Out-Host
        Invoke-Sqlcmd -ServerInstance $server -Query "DROP LOGIN [$($login.name)]"
    }

    else
    {
        "$server has users my man" | Out-Host
    }
}