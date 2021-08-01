Invoke-Sqlcmd -ServerInstance C1DBD500 -Database Test -Query "SELECT * FROM test"
Invoke-Sqlcmd -ServerInstance C1DBD500 -Database Test -Query "BEGIN TRAN; UPDATE test SET data = 'TEST MESSAGE BROKEN'"
Invoke-Sqlcmd -ServerInstance C1DBD500 -Database Test -Query "SELECT * FROM test"
Invoke-Sqlcmd -ServerInstance C1DBD500 -Database Test -Query "CHECKPOINT"
Get-Service -ComputerName C1DBD500 -Name mssqlserver | Stop-Service -Force -NoWait

Copy-Item \\C1DBD500\E$\DATA\MSSQL12.MSSQLSERVER\MSSQL\DATA\Test.mdf C:\Users\Public\Documents

$bytes  = [System.IO.File]::ReadAllBytes("C:\Users\Public\Documents\Test.mdf")
$offset = 2457600 + 111
for ($x = 0; $x -lt 19; $x++)
{
    $bytes[$offset + $x] = 0x0
}

[System.IO.File]::WriteAllBytes("C:\Users\Public\Documents\Test.mdf", $bytes)

Copy-Item C:\Users\Public\Documents\Test.mdf \\C1DBD500\E$\DATA\MSSQL12.MSSQLSERVER\MSSQL\DATA
Get-Service -ComputerName C1DBD500 -Name sqlserveragent | Start-Service



<#
Remove-Item \\C1DBD500\E$\DATA\MSSQL12.MSSQLSERVER\MSSQL\DATA\Test.mdf
Remove-Item \\C1DBD500\E$\DATA\MSSQL12.MSSQLSERVER\MSSQL\DATA\Test_log.ldf

#>