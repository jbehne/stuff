USE msdb

SELECT * FROM backupfile
SELECT * FROM backupfilegroup
SELECT * FROM backupset
SELECT * FROM backupmediafamily
SELECT * FROM backupmediaset





SELECT database_name, name, backup_start_date, backup_finish_date, backup_size FROM backupset