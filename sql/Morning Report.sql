SELECT * FROM vw_AllError_Log WHERE IsResolved = 0 AND ErrorTime > GETDATE() - 1
SELECT * FROM vw_AllMonitoredServersErrors WHERE ErrorDate > GETDATE() - 1

 
