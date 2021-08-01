/*
select * from users join widgets on widgets.id = (
    select id from widgets
    where widgets.user_id = users.id
    order by created_at desc
    limit 1
)
*/

WITH times AS (
SELECT  ServerName, acs1.ChangeTime DownTime, 
(SELECT TOP 1 ChangeTime 
	FROM Alert_ConnectionStatusChange
	WHERE SQLConnection = 1
	AND ChangeTime > acs1.ChangeTime
	AND InstanceID = acs1.InstanceID) UpTime
FROM Alert_ConnectionStatusChange acs1
INNER JOIN Perf_MonitoredServers pms ON acs1.InstanceID = pms.InstanceID
WHERE acs1.SQLConnection = 0)

SELECT *, DATEDIFF(MINUTE, DownTime, UpTime) TotalTime
FROM times
ORDER BY DownTime