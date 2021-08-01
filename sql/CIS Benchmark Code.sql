USE SQLMONITOR
GO

IF EXISTS (SELECT name FROM sys.objects WHERE name = 'CIS_BenchMarkData_Current')
	DROP TABLE CIS_BenchMarkData_Current
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'CIS_BenchMarkData_History')
	DROP TABLE CIS_BenchMarkData_History
IF EXISTS (SELECT name FROM sys.objects WHERE name = 'CIS_BenchMarkQuery')
	DROP TABLE CIS_BenchMarkQuery

CREATE TABLE CIS_BenchMarkData_Current (
CollectionDate smalldatetime -- Datetime of collection
, BenchMarkID float -- The numeric ID of the benchmark
, ServerName varchar(16) -- The name.  Of the server.  Come on guys.
, DatabaseName varchar(256) -- You can guess this one.
, CurrentValue varchar(24) -- Returned value of the query
, GoldValue varchar(24) -- The gold standard value that we expect to see 
);

CREATE CLUSTERED INDEX CIX_CIS_BenchMarkData_Current ON CIS_BenchMarkData_Current (CollectionDate, BenchMarkID) 
	WITH (DATA_COMPRESSION=PAGE);
GO

CREATE TABLE CIS_BenchMarkData_History (CollectionDate smalldatetime, BenchMarkID float, 
	ServerName varchar(16), DatabaseName varchar(256), CurrentValue varchar(24), GoldValue varchar(24));
CREATE CLUSTERED INDEX CIX_CIS_BenchMarkData_History ON CIS_BenchMarkData_History (CollectionDate, BenchMarkID) 
	WITH (DATA_COMPRESSION=PAGE);
GO

CREATE TABLE CIS_BenchMarkQuery (
BenchMarkID float -- The number of the benchmark (like 1.2)
, DB_BENCHMARK_FLG char(1) -- This is 0/1 where 0 do not check
, ORIGINAL_BENCHMARK_QUERY varchar(max) -- This is the query to run
, BENCHMARK_LEVEL varchar(16) -- This shows whether the query should run for every database (DB) or just once per instance (INSTANCE)
, DBMS_QUERYTYPE varchar(10) -- This represents TSQL or POSH query type
, BENCHMARK_VALUE varchar(10) -- This is our gold value at the time of execution (saved in case it changes)
)
;

CREATE CLUSTERED INDEX CIX_CIS_BenchMarkQuery ON CIS_BenchMarkQuery (BenchMarkID) 
	WITH (DATA_COMPRESSION=PAGE);
GO

/*
SELECT * FROM CIS_BenchMarkData_Current
SELECT * FROM CIS_BenchMarkQuery
*/