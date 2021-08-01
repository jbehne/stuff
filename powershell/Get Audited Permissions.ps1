<#
    #####################################################################################################
    # f_Collect FUNCTION                                                                                 #
    #####################################################################################################
    
    The f_Collect function takes an instance object (which consists of a server and database name.
    
#>
function f_Collect ($instance) {
    $repositoryconnection = New-Object system.data.SqlClient.SQLConnection("Data Source=C1DBD069;Integrated Security=SSPI;Database=DBASUPP")
    $repositoryconnection.Open()
        
    $bc = New-Object ("System.Data.SqlClient.SqlBulkCopy") $repositoryconnection
    $bc.BatchSize = 100000
    $bc.EnableStreaming = "True"
    $bc.BulkCopyTimeout = 120

    $sqlconn = New-Object System.Data.SqlClient.SQLConnection("Server=$($instance.ServerName);Database=$($instance.DatabaseName);Integrated Security=true")
    $sqlconn.Open()

    #-- LOCAL ACCOUNTS WITH SERVER ROLE PERMISSIONS
    $query = "SELECT @@SERVERNAME ServerName, role.name AS RoleName, member.name AS MemberName
            FROM sys.server_role_members  
            JOIN sys.server_principals AS role  
                ON sys.server_role_members.role_principal_id = role.principal_id  
            JOIN sys.server_principals AS member  
                ON sys.server_role_members.member_principal_id = member.principal_id
            WHERE member.type = 'S'"

    $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($query, $sqlconn)
    $sqlreader = $sqlcmd.ExecuteReader()    
    $bc.DestinationTableName = "Permissions_ServerRole_Stage"
    $bc.WriteToServer($sqlreader)
    $sqlreader.Close()


    #-- LOCAL ACCOUNTS WITH SERVER PERMISSIONS
    $query = "SELECT DISTINCT @@SERVERNAME ServerName, 'SERVER' DatabaseName, Name, class_desc Class, permission_name Permission, state_desc Type
                FROM sys.server_permissions perm
                INNER JOIN sys.server_principals prin ON perm.grantee_principal_id = prin.principal_id
                WHERE prin.type = 'S'
                AND Name NOT LIKE '##%'
                AND perm.type <> 'COSQ';"

    $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($query, $sqlconn)
    $sqlreader = $sqlcmd.ExecuteReader()    
    $bc.DestinationTableName = "Permissions_Server_Stage"
    $bc.WriteToServer($sqlreader)
    $sqlreader.Close()


    #-- LOCAL ACCOUNTS IN ROLES
    $query = "SELECT @@SERVERNAME ServerName, DB_NAME() DatabaseName, su.name AS Role, sysusers_1.name AS UserName
            FROM dbo.sysusers su
            INNER JOIN dbo.sysmembers sm ON su.uid = sm.groupuid 
            INNER JOIN dbo.sysusers sysusers_1 ON sm.memberuid = sysusers_1.uid
            WHERE sysusers_1.name <> 'dbo'
            AND sysusers_1.issqluser = 1"

    $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($query, $sqlconn)
    $sqlreader = $sqlcmd.ExecuteReader()    
    $bc.DestinationTableName = "Permissions_AccountsInRoles"
    $bc.WriteToServer($sqlreader)
    $sqlreader.Close()


    #-- ROLE EXPLICIT SECURITY GRANTS
    $query = "SELECT @@SERVERNAME ServerName, DB_NAME() DatabaseName, s.name Role, sc.name + '.' + so.name Object, 
                   CASE action WHEN 26 THEN 'REFERENCES'
                                 WHEN 178 THEN 'CREATE FUNCTION'
                                 WHEN 193 THEN 'SELECT'
                                 WHEN 195 THEN 'INSERT'
                                 WHEN 196 THEN 'DELETE'
                                 WHEN 197 THEN 'UPDATE'
                                 WHEN 198 THEN 'CREATE TABLE'
                                 WHEN 203 THEN 'CREATE DATABASE'
                                 WHEN 207 THEN 'CREATE VIEW'
                                 WHEN 222 THEN 'CREATE PROCEDURE'
                                 WHEN 224 THEN 'EXECUTE'
                                 WHEN 228 THEN 'BACKUP DATABASE'
                                 WHEN 233 THEN 'CREATE DEFAULT'
                                 WHEN 235 THEN 'BACKUP LOG'
                                 WHEN 236 THEN 'CREATE RULE'
                   END AS Action,
                   CASE protecttype 
                          WHEN 204 THEN 'GRANT_W_GRANT '
                          WHEN 205 THEN 'GRANT '
                          ELSE 'REVOKE'
                   END AS Type
            FROM sys.sysprotects sp 
            INNER JOIN sys.objects so ON so.object_id = sp.id 
            INNER JOIN sys.sysusers s ON sp.uid = s.uid 
            INNER JOIN sys.schemas sc ON sc.schema_id = so.schema_id
            WHERE issqlrole = 1 OR isapprole = 1

            UNION ALL

            SELECT @@SERVERNAME ServerName, DB_NAME() DatabaseName, name Role, '_DB_GLOBAL' Object, permission_name Action, state_desc Type
            FROM .sys.database_permissions perm
            INNER JOIN sys.database_principals prin ON prin.principal_id = perm.grantee_principal_id
            WHERE class_desc = 'DATABASE'
            AND type_desc = 'DATABASE_ROLE'
            ORDER BY s.name"

    $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($query, $sqlconn)
    $sqlreader = $sqlcmd.ExecuteReader()    
    $bc.DestinationTableName = "Permissions_AccountAccess"
    $bc.WriteToServer($sqlreader)
    $sqlreader.Close()


    #-- LOCAL ACCOUNT EXPLICIT SECURITY GRANTS
    $query = "SELECT @@SERVERNAME ServerName, DB_NAME() DatabaseName, s.name [User], sc.name + '.' + so.name Object, 
                    CASE action WHEN 26 THEN 'REFERENCES'
                            WHEN 178 THEN 'CREATE FUNCTION'
                            WHEN 193 THEN 'SELECT'
                            WHEN 195 THEN 'INSERT'
                            WHEN 196 THEN 'DELETE'
                            WHEN 197 THEN 'UPDATE'
                            WHEN 198 THEN 'CREATE TABLE'
                            WHEN 203 THEN 'CREATE DATABASE'
                            WHEN 207 THEN 'CREATE VIEW'
                            WHEN 222 THEN 'CREATE PROCEDURE'
                            WHEN 224 THEN 'EXECUTE'
                            WHEN 228 THEN 'BACKUP DATABASE'
                            WHEN 233 THEN 'CREATE DEFAULT'
                            WHEN 235 THEN 'BACKUP LOG'
                            WHEN 236 THEN 'CREATE RULE'
                    END AS Action,
                    CASE protecttype 
                            WHEN 204 THEN 'GRANT_W_GRANT '
                            WHEN 205 THEN 'GRANT '
                            ELSE 'REVOKE'
                    END AS Type
            FROM sys.sysprotects sp 
            INNER JOIN sys.objects so ON so.object_id = sp.id 
            INNER JOIN sys.sysusers s ON sp.uid = s.uid 
            INNER JOIN sys.schemas sc ON sc.schema_id = so.schema_id
            WHERE issqlrole = 0 
            AND isapprole = 0

            UNION ALL

            SELECT @@SERVERNAME ServerName, DB_NAME() DatabaseName, name Role, '_DB_GLOBAL' Object, permission_name Action, state_desc Type
            FROM .sys.database_permissions perm
            INNER JOIN sys.database_principals prin ON prin.principal_id = perm.grantee_principal_id
            WHERE class_desc = 'DATABASE'
            AND type_desc <> 'DATABASE_ROLE'
            AND permission_name <> 'CONNECT'
            ORDER BY s.name"

    $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($query, $sqlconn)
    $sqlreader = $sqlcmd.ExecuteReader()    
    $bc.DestinationTableName = "Permissions_RoleAccess"
    $bc.WriteToServer($sqlreader)
    $sqlreader.Close()
}

<#
    #####################################################################################################
    # wf_Collect WORKFLOW                                                                                 #
    #####################################################################################################
    
    The wf_exists workflow calls the f_exists function for every instance in the array passed to it.
    The calls are made in parallel, throttled to 4 threads.
#>
workflow wf_Collect ($instances) {
    foreach -parallel -throttlelimit 4 ($instance in $instances) {
        f_Collect $instance
    }
}

<#
    #####################################################################################################
    # f_exists FUNCTION                                                                                 #
    #####################################################################################################
    
    The f_exists function takes an instance object (which consists of a server and database name.
    This will query the server to check if the database exists and update the repository table.
#>

function f_exists ($instance) {
    $query = "IF EXISTS (SELECT name FROM sys.databases WHERE name = '$($instance.DatabaseName)')
                SELECT 1 Exist
                ELSE
                SELECT 0 Exist"

    $exists = (Invoke-Sqlcmd -ServerInstance $instance.ServerName -Query $query).Exist

    Invoke-Sqlcmd -ServerInstance C1DBD069 -Database DBASUPP -Query "UPDATE Permissions_DatabaseList SET IsExists = $exists WHERE ServerName = '$($instance.ServerName)' AND DatabaseName = '$($instance.DatabaseName)'"
}

<#
    #####################################################################################################
    # wf_exists WORKFLOW                                                                                 #
    #####################################################################################################
    
    The wf_exists workflow calls the f_exists function for every instance in the array passed to it.
    The calls are made in parallel, throttled to 4 threads.
#>
workflow wf_exists ($instances) {
    foreach -parallel -throttlelimit 4 ($instance in $instances) {
        f_exists $instance
    }
}


# Set the repository server and database
$server = "C1DBD069"
$database = "DBASUPP"

# Reload the server/database list from SERVINFO
$query = "SET NOCOUNT ON;
        TRUNCATE TABLE Permissions_DatabaseList;

        INSERT Permissions_DatabaseList
        SELECT *, null FROM OPENQUERY(SERVINFO, 'SELECT SRVR_NM, DB_NM, APP_NM, DB_COMMENTS
        FROM CCDB2.MDB_DB_DATA
        WHERE AUDIT_FLG_INDR = ''Y''
        AND DBMS = ''SQL''');"

Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query

# Execute the workflow to verify databases exist
$servers = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "SELECT ServerName, DatabaseName FROM Permissions_DatabaseList"
wf_exists $servers

# Execute the workflow to load permissions into the repo
$servers = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "SELECT ServerName, DatabaseName FROM Permissions_DatabaseList WHERE IsExists = 1"
wf_Collect $servers

# Copy a distinct list of server roles from staging (reduces duplicates from multiple db's on same server)
$query = "INSERT Permissions_ServerRole
            SELECT DISTINCT ServerName, RoleName, MemberName FROM Permissions_ServerRole_Stage;
            TRUNCATE TABLE Permissions_ServerRole_Stage;"
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query

# Copy a distinct list of server permissions from staging (reduces duplicates from multiple db's on same server)
$query = "INSERT Permissions_Server
            SELECT DISTINCT ServerName, RoleName, UserName, ObjectName, ActionName, AccessType FROM Permissions_Server_Stage;
            TRUNCATE TABLE Permissions_Server_Stage;"
Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query
