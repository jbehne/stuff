DROP DATABASE [OCGPC0Q4]
GO

CREATE DATABASE [OCGPC0Q4]
GO


alter database [OCGPC0Q4]
set READ_COMMITTED_SNAPSHOT ON
WITH ROLLBACK IMMEDIATE
GO 


USE [OCGPC0Q4]
GO
/****** Object:  User [ALLIANCE\OCGPC0Q4_READ_TABVIEW]    Script Date: 12/19/2018 1:49:13 PM ******/
CREATE USER [ALLIANCE\OCGPC0Q4_READ_TABVIEW] FOR LOGIN [ALLIANCE\OCGPC0Q4_READ_TABVIEW]
GO
/****** Object:  User [ALLIANCE\OCGPC0Q4_UPDATE_TABVIEW]    Script Date: 12/19/2018 1:49:13 PM ******/
CREATE USER [ALLIANCE\OCGPC0Q4_UPDATE_TABVIEW] FOR LOGIN [ALLIANCE\OCGPC0Q4_UPDATE_TABVIEW]
GO
/****** Object:  User [zt_hopetestdb]    Script Date: 12/19/2018 1:49:13 PM ******/
CREATE USER [zt_hopedb] FOR LOGIN [zt_hopedb] WITH DEFAULT_SCHEMA=[dbo]
GO
CREATE USER [zt_quic_qabatch] FOR LOGIN [zt_quic_qabatch] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [ALLIANCE\OCGPC0Q4_READ_TABVIEW]
GO
ALTER ROLE [db_datareader] ADD MEMBER [ALLIANCE\OCGPC0Q4_UPDATE_TABVIEW]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [ALLIANCE\OCGPC0Q4_UPDATE_TABVIEW]
GO
ALTER ROLE [db_owner] ADD MEMBER [zt_hopedb]
GO
ALTER ROLE [db_owner] ADD MEMBER [zt_quic_qabatch]