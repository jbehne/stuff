/* Step 1 - Create login and user */
CREATE LOGIN [test] WITH PASSWORD=N'Password1', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;
GO
CREATE USER [test] FOR LOGIN [test];
GO
-- Note the SIDS match
SELECT * FROM master..syslogins WHERE name = 'test';
GO
SELECT * FROM sysusers WHERE name = 'test';
GO

/* Step 2 - Drop the login and then create it again*/
DROP LOGIN test;
GO
CREATE LOGIN [test] WITH PASSWORD=N'Password1', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;
GO
-- Note the SIDS are now different
SELECT * FROM master..syslogins WHERE name = 'test';
GO
SELECT * FROM sysusers WHERE name = 'test';
GO

/*  Step 3 - Use the builtin procedure to detect orphans and fix the orphan*/
EXEC sp_change_users_login @action = 'report';
GO
EXEC sp_change_users_login 'update_one', 'test', 'test';
GO
-- Note the SIDS match again
SELECT * FROM master..syslogins WHERE name = 'test';
GO
SELECT * FROM sysusers WHERE name = 'test';
GO
-- Note the report is now empty
EXEC sp_change_users_login @action = 'report';
GO

/*  Step 4 - Now things get interesting */
DROP LOGIN test
GO
CREATE LOGIN [test] WITH PASSWORD=N'Password1', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;
GO
DECLARE @sid varbinary(85), @dynamicsql nvarchar(512);
SELECT @sid = sid FROM sysusers WHERE name = 'test';
SET @dynamicsql = 'CREATE LOGIN [test2] WITH PASSWORD=N''Password1'', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF, SID=' + CONVERT(nvarchar(max), @sid, 1)
EXEC sp_executesql @dynamicsql
GO
-- Note test2 has the same sid as test, uh oh!
SELECT * FROM master..syslogins WHERE name LIKE 'test%'
GO
SELECT * FROM sysusers WHERE name = 'test'
GO
-- Check to see if test is still orphaned
EXEC sp_change_users_login @action = 'report';
GO

-- It's not orphaned, now the user is mapped to a completely different login!
-- So now the person that has the test2 credentials has the permissions of the person that had the test ID.

-- Clean it up!
DROP USER test
DROP LOGIN test
DROP LOGIN test2