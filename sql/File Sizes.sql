SELECT db.name, mf.name, type_desc, size/128 sizeMB, 
CASE WHEN (max_size = -1 OR max_size = 268435456) THEN 'Unlimited' ELSE CAST(max_size/128 AS varchar) END maxsize,
CASE WHEN is_percent_growth = 1 THEN CAST(growth AS varchar) + ' %' ELSE CAST(growth/128 AS varchar) + ' MB' END growth
FROM sys.master_files mf
INNER JOIN sys.databases db ON db.database_id = mf.database_id
WHERE db.name NOT IN ('master', 'model', 'msdb')



