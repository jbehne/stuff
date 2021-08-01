SELECT ServerName, ChangeTime, Ping, SQLConnection 
FROM Alert_ConnectionStatusChange acss
INNER JOIN Perf_MonitoredServers pms ON pms.InstanceID = acss.InstanceID
ORDER BY ChangeTime

/*
Connection Status runs 5am-6pm CST

How do we add an extra notification layer without generating false positives that make us ignore alerts?

Scenario #1 
Alert if the Ping and/or SQLConnection has been 0 (failed) for longer than 15 minutes or 3 cycles (1 cycle = 5 minutes).

Scenario #2
Alert if the Ping and/or SQLConnection has had 6 events within 30 minutes or 6 cycles

*/

/*
	CQP - this was noticed by John checking on the daily ETL jobs, could not connect to V01DBSWIN147
	146 and 147 ended up on the same host and overloaded it with CPU requests
	Two fixes:
		1. Node affinity set to prevent machines from landing on same host
		2. CPU cores available to guest were reduced on 144,146,147

	TO DO:
		1. Identify oversized servers
		2. Identify large resource users and work with VM team to ensure affinity prevents them from sharing a host
		3. Create additional monitoring/alerting to scan for this type of situation (server not down, but not processing requests)
		4. Set ETL job to email upon completion, pass or fail
		5. Set up a job to scan for jobs that should be completed by ??? time?
		6. Check performance charts during that time/servers
*/