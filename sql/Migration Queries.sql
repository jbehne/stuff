ALTER TABLE Migration2008 ADD ContactPrimary varchar(256);
ALTER TABLE Migration2008 ADD ContactSecondary varchar(256);
ALTER TABLE Migration2008 ADD ContactManager varchar(256);

UPDATE Migration2008 SET DBA = 'JEREMY.BEHNE' WHERE DBA = 'Jeremy'
UPDATE Migration2008 SET DBA = 'JOHN.CAMERON' WHERE DBA = 'John'
UPDATE Migration2008 SET DBA = 'ROBERT.MONTGOMERY' WHERE DBA = 'Robert'
UPDATE Migration2008 SET DBA = 'JASON.SHELL' WHERE DBA = 'Jason'
UPDATE Migration2008 SET DBA = 'SHAWN.ARNOLD' WHERE DBA = 'Shawn'
UPDATE Migration2008 SET DBA = 'KELLY.KILHOFFER' WHERE DBA = 'Kelly'
UPDATE Migration2008 SET DBA = 'RON.CARLISLE' WHERE DBA = 'Ron'

SELECT DISTINCT DBA FROM Migration2008 
SELECT * FROM Migration2008 WHERE DBA = 'Kris'


SELECT * FROM Migration2008
WHERE Status <> 'DECOMMISSIONED'

SELECT Status, COUNT(Status)
FROM Migration2008
GROUP BY Status
GO

WITH servinfo AS (
	SELECT * FROM OPENQUERY(SERVINFO, 'SELECT * FROM CCDB2.MDB_APPLICATION')
)

UPDATE m
SET m.ContactPrimary = s.APP_CONTACT_PRIMARY,
m.ContactSecondary = APP_CONTACT_SECONDARY,
m.ContactManager = APP_MANAGER
FROM Migration2008 m
INNER JOIN servinfo s ON m.ApplicationName = s.APP_NM
WHERE Status <> 'DECOMMISSIONED'



-- Status Count
SELECT Status, COUNT(Status) Total
FROM DBASUPP.dbo.Migration2008
GROUP BY Status
GO

-- Complete vs not complete
SELECT 'COMPLETE', COUNT(Status)
FROM DBASUPP.dbo.Migration2008
WHERE Status IN ('COMPLETE', 'DECOMMISSIONED')
UNION ALL
SELECT 'REMAINING', COUNT(Status)
FROM DBASUPP.dbo.Migration2008
WHERE Status IN ('ESTIMATED','NO DATE','TBD DECOM','UNSUPPORTED')
GO

-- Not complete by manager
SELECT ContactManager, COUNT(ContactManager) Total
FROM DBASUPP.dbo.Migration2008
WHERE Status NOT IN ('COMPLETE', 'DECOMMISSIONED')
GROUP BY ContactManager
ORDER BY ContactManager
GO



SELECT DISTINCT ContactManager FROM DBASUPP.dbo.Migration2008 WHERE ContactManager <> 'NULL' ORDER BY ContactManager
SELECT * FROM DBASUPP.dbo.Migration2008 WHERE ContactManager = 'ADAM.SHAKE'
