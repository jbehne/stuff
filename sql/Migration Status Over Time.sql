--SELECT * FROM Alert_ConnectionStatusChange

--SELECT FORMAT(StatusDate, 'MMMM') + ' ' + FORMAT(StatusDate, 'yyyy'), COUNT(*) 
--FROM DBASUPP.[dbo].[Migration2008]
--GROUP BY FORMAT(StatusDate, 'MMMM') + ' ' + FORMAT(StatusDate, 'yyyy')
--ORDER BY FORMAT(StatusDate, 'MMMM') + ' ' + FORMAT(StatusDate, 'yyyy')
--EXEC DBASUPP.dbo.usp_MigrationResult

ALTER PROC usp_MigrationResult
AS

CREATE TABLE #result (Status varchar(128), Year int, MonthNo int, Month varchar(36), Number int);
DECLARE @total int, @status varchar(128), @year int, @monthno int, @month varchar(36), @number int ;
SELECT @total = COUNT(*) FROM DBASUPP.[dbo].[Migration2008];

DECLARE c_total CURSOR FOR 
WITH total AS (
	SELECT 'Complete' Status, 2018 Year, 04 MonthNo, 'April' Month, 0 Number
	UNION ALL
	SELECT 
		'Complete' Status, FORMAT(StatusDate, 'yyyy') Year, FORMAT(StatusDate, 'MM') MonthNo, 
		FORMAT(StatusDate, 'MMMM') Month, COUNT(*) Number
	FROM DBASUPP.[dbo].[Migration2008]
	WHERE StatusDate < GETDATE()
	AND Status IN ('COMPLETE', 'DECOMMISSIONED')
	GROUP BY FORMAT(StatusDate, 'yyyy'), FORMAT(StatusDate, 'MM'), FORMAT(StatusDate, 'MMMM')
	UNION ALL
	SELECT 'Scheduled', 2019, DATEPART(MONTH, DATEADD(MONTH, -1, GETDATE())), '', 0
	UNION ALL
	SELECT 
		'Scheduled' Status, FORMAT(StatusDate, 'yyyy') Year, FORMAT(StatusDate, 'MM') MonthNo, 
		FORMAT(StatusDate, 'MMMM') Month, COUNT(*) Number
	FROM DBASUPP.[dbo].[Migration2008]
	WHERE StatusDate >= GETDATE()
	AND Status IN ('TBD DECOM', 'ESTIMATED')
	GROUP BY FORMAT(StatusDate, 'yyyy'), FORMAT(StatusDate, 'MM'), FORMAT(StatusDate, 'MMMM')
)

SELECT * FROM total;

OPEN c_total;
FETCH NEXT FROM c_total INTO @status, @year, @monthno, @month, @number;
PRINT @@FETCH_STATUS

WHILE @@FETCH_STATUS = 0
BEGIN
	PRINT @month
	SET @total = @total - @number;
	INSERT #result VALUES (@status, @year, @monthno, @month, @total);
	FETCH NEXT FROM c_total INTO @status, @year, @monthno, @month, @number;
END

SELECT * FROM #result;

CLOSE c_total;  
DEALLOCATE c_total;  
DROP TABLE #result

--SELECT *
--FROM DBASUPP.[dbo].[Migration2008]
