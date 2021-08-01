CREATE PROC usp_IntegrityCheck
AS
DECLARE @cmd nvarchar(max);

DECLARE checkdb CURSOR
FOR
SELECT 'DBCC CHECKDB (''' + name + ''') WITH NO_INFOMSGS;' FROM sys.databases WHERE name <> 'tempdb' ORDER BY name;

OPEN checkdb;
FETCH NEXT FROM checkdb INTO @cmd;

WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC sp_executesql @cmd;
	FETCH NEXT FROM checkdb INTO @cmd;
END

CLOSE checkdb;
DEALLOCATE checkdb;

