SELECT REPLACE(command, '\\blm-bak-10-dd\sql_test', '\\s01ddaesd001d\01_sqltestcifs') FROM msdb..sysjobsteps WHERE command LIKE '%blm-bak-10-dd%'



UPDATE msdb..sysjobsteps 
SET command = REPLACE(command, '\\blm-bak-10-dd\sql_test', '\\s01ddaesd001d\01_sqltestcifs')
WHERE command LIKE '%blm-bak-10-dd%'