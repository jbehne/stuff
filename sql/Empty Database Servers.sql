WITH servers AS (
SELECT * FROM OPENQUERY (SERVINFO, 'SELECT * FROM CCDB2.MDB_DBMS_DATA WHERE DBMS_TYP = ''SQL SERVER''')),
dbs AS (
SELECT * FROM OPENQUERY (SERVINFO, 'SELECT * FROM CCDB2.MDB_DB_DATA WHERE DBMS_INSTANCE_NM = ''SQL'''))

--SELECT s.SRVR_NM, d.DB_NM
--FROM servers s 
--LEFT OUTER JOIN dbs d ON d.SRVR_NM = s.SRVR_NM
--AND d.DB_NM NOT IN ('master', 'model', 'msdb', 'tempdb', 'SQLADMIN', 'ReportServer', 'ReportServerTempDB')
--ORDER BY s.SRVR_NM

SELECT s.SRVR_NM, s.APP_NM, s.DBMS_COMMENTS, COALESCE(COUNT(d.DB_NM), 0) 
FROM servers s 
LEFT OUTER JOIN dbs d ON d.SRVR_NM = s.SRVR_NM
AND d.DB_NM NOT IN ('master', 'model', 'msdb', 'tempdb', 'SQLADMIN', 'ReportServer', 'ReportServerTempDB')
GROUP BY s.SRVR_NM, s.APP_NM, s.DBMS_COMMENTS
ORDER BY COALESCE(COUNT(d.DB_NM), 0) 


