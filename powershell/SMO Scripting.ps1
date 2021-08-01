<#
    Method 1 - sqlps/sqlserver module
#>
#cd SQLSERVER:\
#cd sql\C1DBD534\Default\Databases\
#cd LEDB0T1
#cd tables

$tables = @()
$triggers = @()
$scripts = @()

$tables = Get-ChildItem SQLSERVER:\sql\C1DBD534\Default\Databases\LEDB0T1\tables
foreach ($t in $tables)
{
    $triggers += Get-ChildItem "SQLSERVER:\sql\C1DBD534\Default\Databases\LEDB0T1\tables\dbo.$($t.Name)\triggers"
}

foreach ($t in $triggers)
{
    $script = $t.Script()
    $script = $script.Replace("CREATE TRIGGER", "ALTER TRIGGER")
    $script = $script.Replace("raiserror @errno @errmsg", "raiserror(@errmsg, @errno, 1) ")

}


<#
    Method 2 - SMO
#>
$server = "C1DBD534"
$database = "LEDB0T1"

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
$SMOServer = New-Object ('Microsoft.SqlServer.Management.Smo.Server') -ArgumentList $server
$SMODatabase = $SMOServer.Databases[$database]

foreach ($table in $SMODatabase.Tables)
{
    foreach ($trigger in $table.Triggers)
    {
        $script = $trigger.Script()
        $script = $script.Replace("raiserror @errno @errmsg", "raiserror(@errmsg, @errno, 1) ")
        $script = $script.Replace("SET ANSI_NULLS ON", "SET ANSI_NULLS ON`r`nGO;`r`n")
        $script = $script.Replace("SET QUOTED_IDENTIFIER ON", "SET QUOTED_IDENTIFIER ON`r`nGO;`r`n")

    
        Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "DROP TRIGGER $trigger"
        Invoke-Sqlcmd -ServerInstance $server -Database $database -Query [string]$script
    }
}