INSERT JobHistory
SELECT * FROM OPENQUERY(X1DBD030, 
'select job_name, status, TO_CHAR(start_time,''mm/dd/yyyy HH24:mi:ss'' ) start_time,TO_CHAR(end_time,''mm/dd/yyyy HH24:mi:ss'' ) end_time from SYSMAN.MGMT$JOB_EXECUTION_HISTORY
where job_name not like ''SI_%''
and job_name not like ''CAW%''
and job_name not like ''DIAGNOSTIC%''
and job_name not like ''SWLIB%''
and job_name not like ''SUP_VIOL%''
and job_name not like ''CFWCORE%''
and job_name not like ''MDADATA%''
and job_name not like ''DOWNLOAD%''
and job_name not like ''JVMD%''
and job_name not like ''SOFTWARE%''
and job_name not like ''VERSION%''
and status not in (''Waiting'',''Scheduled'')
and start_time > (sysdate -1)
order by start_time')

EXCEPT 

SELECT * FROM JobHistory

/*
CREATE TABLE JobHistory (JOB_NAME varchar(1024), STATUS varchar(1024), START_TIME smalldatetime, END_TIME smalldatetime);
CREATE CLUSTERED INDEX CIX_JobHistory ON JobHistory (START_TIME) WITH (DATA_COMPRESSION=PAGE);
*/