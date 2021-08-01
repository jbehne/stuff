$worksheets = Get-ExcelSheetInfo "\\alliance\dfs\dba\DBMS\SQL Server\Capacity Planning\MSSQL-Capacity.xlsx" | Where Name -NotLike "*Query*"

foreach($worksheet in $worksheets)
{
    $date = [datetime]$worksheet.Name
    $date = $date.AddDays(19)
    $date = [string]$date

    ,$import = Import-Excel $worksheet.Path -WorksheetName $worksheet.Name -EndColumn 6 -DataOnly | Select @{ Name = 'CollectDate';  Expression = {$date}}, *

    Write-SqlTableData -ServerInstance C1DBD069 -DatabaseName SQLMONITOR -SchemaName dbo -TableName Capacity_Planning -Force -InputData $import
}
