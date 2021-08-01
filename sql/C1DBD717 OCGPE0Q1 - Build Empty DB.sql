USE master
DROP DATABASE [OCGPE0Q1]
GO

/****** Object:  Database [OCGPE0Q1]    Script Date: 12/14/2018 11:13:22 AM ******/
CREATE DATABASE [OCGPE0Q1]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'OCGPE0Q1', FILENAME = N'l:\data\MSSQL12.MSSQLSERVER\MSSQL\DATA\OCGPE0Q1.mdf' , SIZE = 100MB , MAXSIZE = UNLIMITED, FILEGROWTH = 100MB )
 LOG ON 
( NAME = N'OCGPE0Q1_log', FILENAME = N'm:\data\MSSQL12.MSSQLSERVER\MSSQL\DATA\OCGPE0Q1_log.ldf' , SIZE = 100MB , MAXSIZE = 2048GB , FILEGROWTH = 100MB )
GO

alter database OCGPE0Q1
set READ_COMMITTED_SNAPSHOT ON
WITH ROLLBACK IMMEDIATE
GO 

USE [OCGPE0Q1]
GO
/****** Object:  User [ALLIANCE\OCGPE0Q1_READ_TABVIEW]    Script Date: 12/14/2018 11:13:06 AM ******/
CREATE USER [ALLIANCE\OCGPE0Q1_READ_TABVIEW] FOR LOGIN [ALLIANCE\OCGPE0Q1_READ_TABVIEW]
GO
/****** Object:  User [ALLIANCE\OCGPE0Q1_UPDATE_TABVIEW]    Script Date: 12/14/2018 11:13:06 AM ******/
CREATE USER [ALLIANCE\OCGPE0Q1_UPDATE_TABVIEW] FOR LOGIN [ALLIANCE\OCGPE0Q1_UPDATE_TABVIEW]
GO
/****** Object:  User [zt_hopedb]    Script Date: 12/14/2018 11:13:06 AM ******/
CREATE USER [zt_hopedb] FOR LOGIN [zt_hopedb] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [ALLIANCE\OCGPE0Q1_READ_TABVIEW]
GO
ALTER ROLE [db_owner] ADD MEMBER [ALLIANCE\OCGPE0Q1_UPDATE_TABVIEW]
GO
ALTER ROLE [db_backupoperator] ADD MEMBER [ALLIANCE\OCGPE0Q1_UPDATE_TABVIEW]
GO
ALTER ROLE [db_datareader] ADD MEMBER [ALLIANCE\OCGPE0Q1_UPDATE_TABVIEW]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [ALLIANCE\OCGPE0Q1_UPDATE_TABVIEW]
GO
ALTER ROLE [db_owner] ADD MEMBER [zt_hopedb]
GO
