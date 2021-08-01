USE [SQLMONITOR]
GO

/****** Object:  StoredProcedure [dbo].[usp_PurgeData]    Script Date: 4/22/2019 7:38:02 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROC [dbo].[usp_PurgeData] 
AS
BEGIN
	DECLARE @dt datetime
	SELECT @dt = DATEADD(mm, -15, GETDATE())

	WHILE (SELECT COUNT(*) FROM Perf_MemoryGrants WHERE CollectionTime < @dt) > 1
	BEGIN
		DELETE TOP (10000) FROM Perf_MemoryGrants WHERE CollectionTime < @dt;
	END;

	WHILE (SELECT COUNT(*) FROM Perf_MemoryClerks WHERE CollectionTime < @dt) > 1
	BEGIN
		DELETE TOP (10000) FROM Perf_MemoryClerks WHERE CollectionTime < @dt;
	END;

	WHILE (SELECT COUNT(*) FROM Perf_FileIO WHERE CollectionTime < @dt) > 1
	BEGIN
		DELETE TOP (10000) FROM Perf_FileIO WHERE CollectionTime < @dt;
	END;

	WHILE (SELECT COUNT(*) FROM Perf_CounterData WHERE CollectionTime < @dt) > 1
	BEGIN
		DELETE TOP (10000) FROM Perf_CounterData WHERE CollectionTime < @dt;
	END;

	WHILE (SELECT COUNT(*) FROM Perf_FileSpace WHERE CollectionTime < @dt) > 1
	BEGIN
		DELETE TOP (10000) FROM Perf_FileSpace WHERE CollectionTime < @dt;
	END;

	WHILE (SELECT COUNT(*) FROM Perf_IndexUsageStatistics WHERE LastStartUp < @dt) > 1
	BEGIN
		DELETE TOP (10000) FROM Perf_IndexUsageStatistics WHERE LastStartUp < @dt;
	END;

	WHILE (SELECT COUNT(*) FROM Perf_Sessions WHERE CollectionTime < @dt) > 1
	BEGIN
		DELETE TOP (10000) FROM Perf_Sessions WHERE CollectionTime < @dt;
	END;

	WHILE (SELECT COUNT(*) FROM Perf_WaitStatistics WHERE CollectionTime < @dt) > 1
	BEGIN
		DELETE TOP (10000) FROM Perf_WaitStatistics WHERE CollectionTime < @dt;
	END;
END;
GO


