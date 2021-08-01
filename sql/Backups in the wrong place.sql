SELECT * 
FROM Backup_DataDomainFiles_Bloomington b
INNER JOIN 
	(SELECT '%' + TRIM(SRVR_NM) + '%' SRVR_NM FROM OPENQUERY(SERVINFO, 
	'SELECT SRVR_NM 
	FROM CCDB2.MDB_SRVR_NAME_PROPERTIES 
	WHERE LOCATION <> ''BLOOMINGTON'' 
	AND DBMS = ''SQL'' ORDER BY LOCATION')) s
ON b.FileName LIKE s.SRVR_NM
WHERE Created > GETDATE() - 1



SELECT * 
FROM Backup_DataDomainFiles_Aurora b
INNER JOIN 
	(SELECT '%' + TRIM(SRVR_NM) + '%' SRVR_NM FROM OPENQUERY(SERVINFO, 
	'SELECT SRVR_NM 
	FROM CCDB2.MDB_SRVR_NAME_PROPERTIES 
	WHERE LOCATION <> ''AURORA'' 
	AND DBMS = ''SQL'' ORDER BY LOCATION')) s
ON b.FileName LIKE s.SRVR_NM
WHERE Created > GETDATE() - 1

SELECT * 
FROM Backup_DataDomainFiles_Chaska b
INNER JOIN 
	(SELECT '%' + TRIM(SRVR_NM) + '%' SRVR_NM FROM OPENQUERY(SERVINFO, 
	'SELECT SRVR_NM 
	FROM CCDB2.MDB_SRVR_NAME_PROPERTIES 
	WHERE LOCATION <> ''CHASKA'' 
	AND DBMS = ''SQL'' ORDER BY LOCATION')) s
ON b.FileName LIKE s.SRVR_NM
WHERE Created > GETDATE() - 1


/*

SELECT * FROM OPENQUERY(SERVINFO, 
	'SELECT * 
	FROM CCDB2.MDB_SRVR_NAME_PROPERTIES 
	WHERE DBMS = ''SQL'' ORDER BY SRVR_NM')


	*/