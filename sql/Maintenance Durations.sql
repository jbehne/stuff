SELECT name, dbo.agent_datetime(jh.run_date, jh.run_time), run_duration
FROM sysjobhistory jh
INNER JOIN sysjobs sj ON sj.job_id = jh.job_id
WHERE name LIKE 'Maintenance%'
AND step_id = 0
AND dbo.agent_datetime(jh.run_date, jh.run_time) > GETDATE() - 3


