-- Not sure how legit this is

SELECT CAST(DB_NAME(database_id)as VARCHAR(40)) database_name,
Convert(VARCHAR(20),last_commit_time,22) last_commit_time
,CAST(CAST(((DATEDIFF(s,last_commit_time,GetDate()))/3600) as varchar) + ' hour(s), '
+ CAST((DATEDIFF(s,last_commit_time,GetDate())%3600)/60 as varchar) + ' min, '
+ CAST((DATEDIFF(s,last_commit_time,GetDate())%60) as varchar) + ' sec' as VARCHAR(30)) time_behind_primary
,redo_queue_size
,redo_rate
,CONVERT(VARCHAR(20),DATEADD(mi,(redo_queue_size/redo_rate/60.0),GETDATE()),22) estimated_completion_time
,CAST((redo_queue_size/redo_rate/60.0) as decimal(10,2)) [estimated_recovery_time_minutes]
,(redo_queue_size/redo_rate) [estimated_recovery_time_seconds]
,CONVERT(VARCHAR(20),GETDATE(),22) [current_time]
FROM sys.dm_hadr_database_replica_states
WHERE last_redone_time is not null;

GO