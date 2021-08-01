USE [master]
GO

/****** Object:  Login [ALLIANCE\iWorks]    Script Date: 1/14/2019 9:30:56 AM ******/
CREATE LOGIN [ALLIANCE\iWorks] FROM WINDOWS WITH DEFAULT_DATABASE=[iWorksXREF], DEFAULT_LANGUAGE=[us_english]
GO

/****** Object:  Login [ALLIANCE\iWorksITS]    Script Date: 1/14/2019 9:30:56 AM ******/
CREATE LOGIN [ALLIANCE\iWorksITS] FROM WINDOWS WITH DEFAULT_DATABASE=[iWorks], DEFAULT_LANGUAGE=[us_english]
GO

/****** Object:  Login [ALLIANCE\iWorksITSDBUpdate]    Script Date: 1/14/2019 9:30:56 AM ******/
CREATE LOGIN [ALLIANCE\iWorksITSDBUpdate] FROM WINDOWS WITH DEFAULT_DATABASE=[iWorks], DEFAULT_LANGUAGE=[us_english]
GO

/****** Object:  Login [ALLIANCE\z_iWorksBatch]    Script Date: 1/14/2019 9:30:56 AM ******/
CREATE LOGIN [ALLIANCE\z_iWorksBatch] FROM WINDOWS WITH DEFAULT_DATABASE=[iWorksXREF], DEFAULT_LANGUAGE=[us_english]
GO

/* For security reasons the login is created disabled and with a random password. */
/****** Object:  Login [EPSDBA]    Script Date: 1/14/2019 9:30:56 AM ******/
CREATE LOGIN [EPSDBA] WITH PASSWORD=N'BmpUE+jioYWmZ4bRTbEuPjLukhQfq5MMBsTvet1oMzw=', SID=0x8BFEAB7017939E4D984E7691C17B4C4D, DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF,DEFAULT_DATABASE=[iWorks]
GO


/* For security reasons the login is created disabled and with a random password. */
/****** Object:  Login [z_mr_iworks]    Script Date: 1/14/2019 9:30:56 AM ******/
CREATE LOGIN [z_mr_iworks] WITH PASSWORD=N'xyU2fuxoRfOfREoJnaWVdTiG+y2N2NnKIC2auVE/UqY=', SID=0x7967B3C462A2FE4D979547217ABCE331,DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO



SELECT * FROM syslogins