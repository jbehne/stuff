CREATE TABLE Alert_Definition (
	AlertID smallint IDENTITY
	, AlertName varchar(256)
	, CheckIntervalMinutes smallint		--How often to check for this condition
	, CheckTimeSpanMinutes smallint		--How far back to look for cumulative data (0 being just the last value)
	, Aggregation varchar(12)			--How to roll up data (AVG, MIN, MAX, SUM)
	, CounterID smallint
	, CounterInstance varchar(512)		--If this is meant to reference a specific counter instance, null selects all
	, EvaluationType varchar(5)			--Operator to use ( >, <, <=, etc)
	, WarningThreshold decimal(18,2)	--Threshold to be considered a warning
	, CriticalThreshold decimal(18,2)	--Threshold to be considered critical
);
GO

CREATE CLUSTERED INDEX CIX_Alert_Definition ON Alert_Definition (AlertID) WITH (DATA_COMPRESSION=PAGE);

CREATE TABLE Alert_Event (
	EventTime smalldatetime
	, AlertID smallint
	, InstanceID smallint
	, CounterInstance varchar(512)
	, CounterValue decimal(18,2)
	, AcknowledgedTime smalldatetime
);
GO

CREATE CLUSTERED INDEX CIX_Alert_Event ON Alert_Event (EventTime) WITH (DATA_COMPRESSION=PAGE);
GO

CREATE TABLE Alert_Status (
	AlertID smallint
	, LastCheck smalldatetime
);
GO

CREATE CLUSTERED INDEX CIX_Alert_Status ON Alert_Status (AlertID) WITH (DATA_COMPRESSION=PAGE);
GO

/*
	1. Select servers
	2. Select AlertID where LastCheck > Interval
	3. Create select SQL from definition
	4. Store output to Alert_Event
*/