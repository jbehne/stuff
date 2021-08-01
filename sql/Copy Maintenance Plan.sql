SELECT        
    name, 
    id, 
    description, 
    createdate, 
    folderid, 
    ownersid, 
    cast(
        cast(
            replace(
                cast(
                    CAST(packagedata AS VARBINARY(MAX)) AS varchar(max)
                ), 
            'V01DBSWIN502', 'V01DBSWIN503') 
        as XML) 
    as VARBINARY(MAX)) as packagedata, 
    packageformat, 
    packagetype, 
    vermajor, 
    verminor, 
    verbuild, 
    vercomments, 
    verid, 
    isencrypted, 
    readrolesid, 
    writerolesid

FROM
    msdb.dbo.sysssispackages AS sysssispackages_1
WHERE        
    (name = 'Cleanup')