SELECT 
	startEpoch AS ChatInitiated
,	startEpoch + (COALESCE(waitTime, 0) / 1000) AS ChatJoinedTime
,	COALESCE(waitTime, 0) AS ChatWaitTime
,	endEpoch AS ChatEndTime
,	(endEpoch - startEpoch) - (COALESCE(waitTime, 0) / 1000) AS ChatHandleTime
,	AbandonFlag AS ChatAbandoned
,	endEpoch - startEpoch AS ChatAbandonTime
FROM sa_login_session
INNER JOIN dbo.sa_session_event_join ON sa_session_event_join.sessionID =  sa_login_session.id 
INNER JOIN dbo.sa_event_history ON sa_event_history.id = sa_session_event_join.eventID and eventType = 4 
INNER JOIN dbo.call_req ON call_req.id = sa_event_history.sd_obj_id 



SELECT TOP 10 * FROM Call_Req 
SELECT TOP 10 * FROM sa_login_session

SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'sa_login_session'
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'call_req'

SELECT sa_login_session.id as sessionid, dbo.hex(userID) as logonid, startEpoch, endEpoch, waitTime, supportLength, Question, QueuedEpoch, QueuedTime, OnHoldEpoch, OnHoldTime, HandledTime, AbandonFlag, IsWebClient, call_req.ref_num as ticketnum 
FROM dbo.sa_login_session 
INNER JOIN dbo.sa_session_event_join ON sa_session_event_join.sessionID =  sa_login_session.id 
INNER JOIN dbo.sa_event_history ON sa_event_history.id = sa_session_event_join.eventID and eventType = 4 
INNER JOIN dbo.call_req ON call_req.id = sa_event_history.sd_obj_id 
