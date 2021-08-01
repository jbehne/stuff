/*	Counter type rules per MSDN:
			65792 - value as of query time
			1073939712 - base value used to calculate 537003264
				(537003264 value / 1073939712 value)
			272696576 - two samples divided by time
				(value2 - value1) / interval seconds
			1073874176 - uses base value of 1073939712 - two samples each
				(value2 - value1) / (base2 - base1)
		*/

		-- Amount of time to wait between samples.
		DECLARE @wait datetime = '00:00:10';
		DECLARE @time datetime = GETDATE();

		-- Two sample tables and final result set table.  
		-- The final result set stores the counter values as varchar for easy formatting
		-- such as including % signs, etc.
		DECLARE @one AS TABLE (object_name varchar(512), counter_name varchar(512), instance_name varchar(512), cntr_value float, cntr_type int);
		DECLARE @two AS TABLE (object_name varchar(512), counter_name varchar(512), instance_name varchar(512), cntr_value float, cntr_type int);
		DECLARE @result AS TABLE (collectiontime smalldatetime, object_name varchar(512), counter_name varchar(512), instance_name varchar(512), cntr_value float)

		-- Collect the first sample, minus type 65792 (realtime).
		INSERT @one 
			SELECT * 
			FROM sys.dm_os_performance_counters
			WHERE cntr_type <> 65792;

		-- Wait.
		WAITFOR DELAY @wait;

		-- Collect the second sample.  Note - filtering of counters can be done at this level to
		-- reduce server processing (which is fairly light), be sure the filter matches in both
		-- sample sets though.
		INSERT @two 
			SELECT * 
			FROM sys.dm_os_performance_counters
			WHERE cntr_type <> 65792;

		-- CTE's will get the base data needed for calculations from the sample tables.
		-- This CTE joins the value and base value from the second sample for calculation
		-- for the counter type 537003264.
		-- Note - This could be pulled directly from the DMV, but I have left it as-is
		-- as I am unsure of the accuracy.  This is the MSDN formula, but it may be better
		-- to compare both samples for the calculation.
		WITH perf_537003264
		AS (
			SELECT a.object_name, a.counter_name, a.instance_name, 
				CAST(a.cntr_value AS float) value, CAST(b.cntr_value AS float) base
			FROM @two a
			INNER JOIN @two b ON a.object_name = b.object_name 
				AND a.counter_name = REPLACE(b.counter_name, ' Base', '')
				AND a.instance_name = b.instance_name
			WHERE a.cntr_type = 537003264
			AND b.cntr_type = 1073939712
		),

		-- This CTE gets both sample values for the counter type 272696576 to be divided 
		-- by time passed.
		perf_272696576
		AS (
			SELECT a.object_name, a.counter_name, a.instance_name, 
				CAST(a.cntr_value AS float) value1, CAST(b.cntr_value AS float) value2
			FROM @one a
			INNER JOIN @two b ON a.object_name = b.object_name 
				AND a.counter_name = b.counter_name
				AND a.instance_name = b.instance_name
				AND a.cntr_type = b.cntr_type	
			WHERE a.cntr_type = 272696576
		),

		-- The next three CTE's are used to calculate the value for counter type 1073874176.
		-- This one suffers from many complexities caused by mismatched naming
		-- conventions - thanks Microsoft!  The first CTE gets the two sample values
		-- for the main value counter type.
		perf_1073874176
		AS (
			SELECT a.object_name, a.counter_name, a.instance_name, 
				CAST(a.cntr_value AS float) value1, CAST(b.cntr_value AS float) value2
			FROM @one a
			INNER JOIN @two b ON a.object_name = b.object_name 
				AND a.counter_name = b.counter_name
				AND a.instance_name = b.instance_name
				AND a.cntr_type = b.cntr_type	
			WHERE a.cntr_type = 1073874176
		),

		-- This CTE gets the two sample values for the base counter type to be used
		-- in calculating the above counter type.
		perf_1073939712
		AS (
			SELECT a.object_name, a.counter_name, a.instance_name, 
				CAST(a.cntr_value AS float) value1, CAST(b.cntr_value AS float) value2
			FROM @one a
			INNER JOIN @two b ON a.object_name = b.object_name 
				AND a.counter_name = b.counter_name
				AND a.instance_name = b.instance_name
				AND a.cntr_type = b.cntr_type	
			WHERE a.cntr_type = 1073939712
		),

		-- This CTE is where it gets weirder.  Because of poor naming, a UNION
		-- was needed to combine the base and value types properly to return all
		-- possible instances.  The difference between samples is calculated here
		-- to make the division operation easier later.
		perf_1073874176_1073939712
		AS (
			SELECT a.object_name, a.counter_name, a.instance_name, a.value2 - a.value1 value, b.value2 - b.value1 base 
			FROM perf_1073874176 a
			INNER JOIN perf_1073939712 b ON a.instance_name = b.instance_name
				AND REPLACE(a.counter_name, ' (ms)', '') = REPLACE(REPLACE(REPLACE(b.counter_name, ' BS', ''), ' (ms)', ''), ' base', '')
				AND a.object_name = b.object_name

			UNION

			SELECT a.object_name, a.counter_name, a.instance_name, a.value2 - a.value1 value, b.value2 - b.value1 base 
			FROM perf_1073874176 a
			INNER JOIN perf_1073939712 b ON a.instance_name = b.instance_name
				AND REPLACE(REPLACE(REPLACE(a.counter_name, 'Avg ', ''), 'Avg. ', ''), ' (ms)', '') = REPLACE(REPLACE(b.counter_name, ' (ms)', ''), ' base', '')
				AND a.object_name = b.object_name
		)

		-- Now it is time to calculate all values and insert them into the final result set.
		-- UNION ALLs are used to make each calculation a separate entity.
		-- First up, the type 537003264 is a simple value divided by base (catching /0).
		INSERT @result
		SELECT @time, object_name, counter_name, instance_name, 
			CASE WHEN base = 0 THEN 0 ELSE value / base END
		FROM perf_537003264

		UNION ALL

		-- This is the calculation for type 272696576, using the wait value in seconds.
		SELECT @time, object_name, counter_name, instance_name, 
			(value2 - value1) / DATEPART(s, @wait)
		FROM perf_272696576

		UNION ALL

		-- This is the calculation for type 1073874176, by this point it is a simple
		-- division of value and base (checking for /0 errors).
		SELECT @time, object_name, counter_name, instance_name, 
			CASE WHEN base = 0 THEN 0 ELSE value / base END
			FROM perf_1073874176_1073939712

		UNION ALL

		-- The final select just grabs the counter type 65792, which is "realtime".
		SELECT @time, object_name, counter_name, instance_name, cntr_value
		FROM sys.dm_os_performance_counters
		WHERE cntr_type = 65792;

		-- The final result set.  This is where filtering could be easily handled
		-- to keep the code above (a little more) readable.  An insert to a physical
		-- table in the admin database could be added here as well for a recurring job
		-- to capture historical performance (and can easily convert into a proc for
		-- the same purpose).
		WITH result
		AS (
			SELECT CollectionTime, SUBSTRING(object_name, CHARINDEX(':', object_name, 0) + 1, LEN(object_name)) Object_Name, 
				Counter_Name, Instance_Name, Cntr_Value
			FROM @result)

--		INSERT Perf_CounterData
		SELECT CollectionTime, RTRIM(Object_Name), RTRIM(Counter_Name), RTRIM(Instance_Name), Cntr_Value
		FROM result
		WHERE Counter_Name IN ('Page Life Expectancy', 'Free list stalls/sec', 'Lazy writes/sec', 'Page reads/sec', 'Page writes/sec',
			'Database pages', 'Target pages')
		AND Object_Name = 'Buffer Manager'

		UNION ALL

		SELECT CollectionTime, RTRIM(Object_Name), RTRIM(Counter_Name), RTRIM(Instance_Name), Cntr_Value 
		FROM result
		WHERE Counter_Name IN ('User Connections', 'Logins/sec', 'Connection Reset/sec', 'Logouts/sec',
			'Processes blocked', 'Active Temp Tables')
		AND Object_Name = 'General Statistics'

		UNION ALL

		SELECT CollectionTime, RTRIM(Object_Name), RTRIM(Counter_Name), RTRIM(Instance_Name), Cntr_Value 
		FROM result
		WHERE Object_Name = 'Locks'
		AND Instance_Name <> '_Total'

		UNION ALL

		SELECT CollectionTime, RTRIM(Object_Name), RTRIM(Counter_Name), RTRIM(Instance_Name), Cntr_Value 
		FROM result
		WHERE Counter_Name IN ('Workfiles Created/sec', 'Worktables Created/sec', 'Page Splits/sec', 'Full Scans/sec', 
			'Index Searches/sec', 'Table Lock Escalations/sec', 'Page compression attempts/sec', 'Pages compressed/sec')
		AND Object_Name = 'Access Methods'

		UNION ALL

		SELECT CollectionTime, RTRIM(Object_Name), RTRIM(Counter_Name), RTRIM(Instance_Name), Cntr_Value 
		FROM result
		WHERE Counter_Name IN ('SQL Compilations/sec', 'SQL Re-Compilations/sec', 'Batch Requests/sec')
		AND Object_Name = 'SQL Statistics'

		UNION ALL

		SELECT CollectionTime, RTRIM(Object_Name), RTRIM(Counter_Name), RTRIM(Instance_Name), Cntr_Value 
		FROM result
		WHERE Object_Name IN ('Database Replica', 'Availability Replica', 'SQL Errors', 'Plan Cache', 'Memory Manager', 'Wait Statistics')
		AND Instance_Name <> '_Total'

		UNION ALL

		SELECT CollectionTime, RTRIM(Object_Name), RTRIM(Counter_Name), RTRIM(Instance_Name), Cntr_Value 
		FROM result
		WHERE Counter_Name IN ('Transactions/sec', 'Active Transactions', 'Backup/Restore Throughput/sec',
			'DBCC Logical Scan Bytes/sec', 'Log Flush Waits/sec', 'Log Growths', 'Log Shrinks', 'Log Truncations')
		AND Object_Name = 'Databases'
		AND Instance_Name NOT IN ('master', 'model', 'msdb', '_total', 'mssqlsystemresource')

		UNION ALL

		SELECT CollectionTime, RTRIM(Object_Name), RTRIM(Counter_Name), RTRIM(Instance_Name), Cntr_Value 
		FROM result
		WHERE Counter_Name IN ('Latch Waits/sec', 'Average Latch Wait Time (ms)', 'Total Latch Wait Time (ms)')
		AND Object_Name = 'Latches'

		UNION ALL

		SELECT CollectionTime, RTRIM(Object_Name), RTRIM(Counter_Name), RTRIM(Instance_Name), Cntr_Value 
		FROM result
		WHERE Counter_Name IN ('Cached Cursor Counts', 'Active cursors', 'Cursor memory usage')
		AND Object_Name = 'Cursor Manager by Type'
		AND Instance_Name <> '_Total'     
		
		UNION ALL		
		
		SELECT @time, 'Server', 'Total Server Memory (MB)', '', total_physical_memory_kb/1024 FROM sys.dm_os_sys_memory           
		
		UNION ALL

		SELECT @time, 'SQLServer:Memory Manager', 'Max Server Memory (MB)', '', value FROM sys.configurations WHERE name like '%max server memory%'                                                                          