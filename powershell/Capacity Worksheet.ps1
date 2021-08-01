# \\alliance\dfs\DBA\DBMS\SQL Server\Capacity Planning\MSSQL-Capacity.xlsx

$uid = Read-Host -Prompt "UserID"
$pwd = Read-Host -Prompt "Password"

Connect-VIServer -Server v01vsiapl007.countrylan.com -AllLinked -User $uid -Password $pwd

$excel = New-Object -ComObject Excel.Application
$workbook = $excel.WorkBooks.Open('\\alliance\dfs\DBA\DBMS\SQL Server\Capacity Planning\MSSQL-Capacity.xlsx')
$lastsheet = $workbook.Worksheets.Count - 1
$workbook.Sheets[$lastsheet].Copy($workbook.Sheets[$lastsheet])
$worksheet = $workbook.Sheets[$lastsheet]
$worksheet.Name = "$(Get-Date -Format MMMyyy)"
#$excel.Visible = $true
$worksheet.Move([System.Reflection.Missing]::Value, $workbook.Sheets.Item($lastsheet + 1))

$worksheet.Range("A2:D1000").Clear()
$worksheet.Range("F2:F1000").Clear()

$query = "SELECT TRIM(MDB_SRVR_DATA.SRVR_NM) SRVR_NM, MDB_SRVR_DATA.SRVR_MDL, COALESCE(MDB_SRVR_DATA.RAM_MB, 0) RAM_MB, COALESCE(MDB_SRVR_DATA.PROCESSORS_AVAIL, 0) PROCESSORS_AVAIL
    FROM CCDB2.MDB_DBMS_DATA MDB_DBMS_DATA, CCDB2.MDB_SRVR_DATA MDB_SRVR_DATA
    WHERE MDB_SRVR_DATA.SRVR_NM = MDB_DBMS_DATA.SRVR_NM AND ((MDB_DBMS_DATA.DBMS_TYP='SQL SERVER') OR (MDB_DBMS_DATA.DBMS_TYP='SSRS'))
    ORDER BY MDB_SRVR_DATA.SRVR_NM;"
$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=SERVINFO;uid=$uid;pwd=$pwd"
$conn.Open()
$cmd = New-object System.Data.Odbc.OdbcCommand($query,$conn)
$reader = $cmd.ExecuteReader()

$x = 2
while ($reader.Read())
{
    $worksheet.Cells.Item($x, 1) = $reader[0]
    $worksheet.Cells.Item($x, 2) = $reader[1]
    $worksheet.Cells.Item($x, 3) = $reader[2]
    $worksheet.Cells.Item($x, 4) = $reader[3]

    $vm = Get-VM -Name $reader[0] -ErrorAction SilentlyContinue | Where PowerState -EQ "PoweredOn" | Select Name, Guest, NumCpu, CoresPerSocket, MemoryGB, VMHost -First 1
    
    if ($vm -ne $null)
    {
        $worksheet.Cells.Item($x, 6) = $vm.VMHost.Name

        if ($vm.NumCpu -ne $null)
        {
            if ($vm.NumCpu -gt $reader[3])
            {
                $worksheet.Cells.Item($x, 4) = $vm.NumCpu
            }
        }

        if ($vm.MemoryGB -ne $null)
        {
            if ($vm.MemoryGB -gt $reader[2])
            {
                $worksheet.Cells.Item($x, 3) = $vm.MemoryGB
            }
        }
    }

    else
    {
        $worksheet.Cells.Item($x, 6) = $worksheet.Cells.Item($x, 2)
    }

    $x++
}

$conn.Close()

$workbook.Save()
$workbook.Close()
$excel.Quit()