SELECT * 
FROM sys.dm_exec_connections
CROSS APPLY sys.dm_exec_sql_text(most_recent_sql_handle)
WHERE session_id = 194

sp_who2