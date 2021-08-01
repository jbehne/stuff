$server = "C1DBD536"
$db = "SQLMONITOR"
$table = "Security_ServerPermissions"

$result = Invoke-Sqlcmd -ServerInstance $server -Database $db -Query "SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '$table'"
$outDataType = ""
$outNameOnly = ""

foreach ($r in $result)
{
    if ([string]$r.CHARACTER_MAXIMUM_LENGTH -ne "")
    {
        $outDataType += $r.COLUMN_NAME + " " + $r.DATA_TYPE + "(" + $r.CHARACTER_MAXIMUM_LENGTH + "), "
    }
    else
    {
        $outDataType += $r.COLUMN_NAME + " " + $r.DATA_TYPE + ", "
    }

    $outNameOnly += $r.COLUMN_NAME + ", "
}

$outDataType
$outNameOnly