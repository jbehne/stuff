SELECT * FROM [dbo].[Restore_Request] rr
INNER JOIN [dbo].[Backup_Request] br ON br.Backup_Request_ID = rr.Backup_Request_ID
UNION ALL
SELECT * FROM [dbo].[Restore_Request] rr
INNER JOIN [dbo].[Backup_Request_History] bh ON bh.Backup_Request_ID = rr.Backup_Request_ID
