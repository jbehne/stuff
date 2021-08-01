/*
Run this script on: PAYPILOT - Operational database

You are recommended to back up your database before running this script

Script created by SQL Compare version 11.6.10 from Red Gate Software Ltd at 8/29/2018 12:40:08 AM

*/
SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
SET XACT_ABORT ON
GO
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
GO
BEGIN TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPTrnSync]'
GO
ALTER procedure [dbo].[ppSPTrnSync]
(
@LogHdrId int
)
as

declare @Cd varchar(30)

declare stageTrnSyncd cursor for
select Cd FROM stageTrn

declare TrnSyncd cursor for
select Cd FROM Trn

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageTrnSyncd
fetch stageTrnSyncd into @Cd
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageTrn record and make sure that Trn records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Trn where Cd = @Cd)
  begin
    delete Trn	-- delete the existing record and insert it again from stageTrn
    where Cd = @Cd
  end

  insert into Trn
  select *  from stageTrn 
  where Cd = @Cd
  
  fetch stageTrnSyncd into @Cd

END
close stageTrnSyncd
deallocate stageTrnSyncd

/* -------------------------------------------------------------------------------------- 
     Each Trn record must exist in stageTrn - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open TrnSyncd
fetch TrnSyncd into @Cd
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageTrn where Cd = @Cd)
  begin
    delete Trn	-- delete the operational record with no match to the stage table
    where Cd = @Cd
  end

  fetch TrnSyncd into @Cd

END
close TrnSyncd
deallocate TrnSyncd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPTrnSync: Unable to sync the Trn table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPUpdatePref]'
GO
ALTER procedure [dbo].[ppSPUpdatePref]
(
	@Section                           varchar(50),
	@Entry                             varchar(50),
	@Value                             varchar(2048),
	@OprId                             varchar(30),      /* 07/CS2/001 */
	@ProfileId                         varchar(30),      /* 07/CS2/001 */
    @ProcessCd                         varchar(30),      /* 07/CS2/001 */
	@RecordKey					       varchar(500)      /* 07/CS2/001 */
)
as
begin

    if @Section is NULL or @Section = ''
    begin
      --RAISERROR  20000 'ppSPUpdatePref: value for Section is either NULL or invalid'
      select -1         /* return a non-zero value */
    end

    if @Entry is NULL or @Entry = ''
    begin
      --RAISERROR  20000 'ppSPUpdatePref: value for Entry is either NULL or invalid'
      select -2         /* return a non-zero value */
    end

    if @Value is NULL or @Value = ''
    begin
      --RAISERROR  20000 'ppSPUpdatePref: value for Value is either NULL or invalid'
      select -3         /* return a non-zero value */
    end

    set nocount on
    
	begin tran

    if exists (
        select 1 from dbo.PrefTable
         where Section = @Section
           and Entry = @Entry
		   and RecordKey = @RecordKey	   /* 07/CS2/001 */
            )
    begin
      update dbo.PrefTable
         set Value      = @Value,
             OprId      = @OprId,  			/* start - 07/CS2/001 */
		     ProfileId  = @ProfileId,
			 ProcessCd  = @ProcessCd,
			 RecordKey  = @RecordKey        /* end - 07/CS2/001 */
       where Section = @Section
         and Entry = @Entry
    	 and RecordKey = @RecordKey         /* 07/CS2/001 */
    end
    else begin
	  insert into PrefTable
        (
		Section,
		Entry,
		Value,
		OprId,                               /* start - 07/CS2/001 */
		ProfileId,
		ProcessCd,
        RecordKey					         /* end - 07/CS2/001 */
	        )
	  values	
	    (
		@Section,
		@Entry,
		@Value,
		@OprId,                              /* start - 07/CS2/001 */
		@ProfileId,
		@ProcessCd,
        @RecordKey					         /* end - 07/CS2/001 */
	        )
    end /* end Insert or Update */

    if (@@error!=0)
    begin
      --RAISERROR  20000 'ppSPUpdatePref: Unable to insert or update PrefTable data'
      rollback tran
      select -100         /* return a non-zero value */
    end
    else begin
      commit tran
    end
    
    set nocount off

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPVchChkConsolidate]'
GO
ALTER PROCEDURE [dbo].[ppSPVchChkConsolidate]
/* 
   -------------------------------------------------------------------------------------------
   04/01/2010: Reversed the mapping for XAmt2, XAmt4
   03/11/2010: Removed the delete(s): Vch and ArV
   03/11/2010: Revised to select the first (minimum) Vch row for each Chk regardless of SeqNum
   03/10/2010: Revised to ignore Chks with multiple Vch rows; this procedure will process
               only Vch rows with SeqNum = 1.
               Also, this procedure has been revised to include the same processing for
               the ArC / ArV tables.
               Error messages now specifically refer to Chk/ArC or ArC/ArV tables.
    This stored procedure consolidates Vch information into the Chk table.
    Asssumption: there is only 1 Vch row for each payment (Chk).
    Criteria: join on CTpId, ChkId
    Filter: Vch.SeqNum = 1, CTpId in (100,200)
    Mapping:
        Chk.TranTyp = 254 ( eTranNoHist - do NOT create Hst )
        Chk.Dt1     = Vch.InvDt
        Chk.PayRate = Vch.PayRate
        Chk.XAmt1   = Vch.AmtPd
        Chk.XAmt4   = Vch.DiscAmt
        Chk.XAmt2   = Vch.NetAmt
        Chk.TaxId   = Vch.VchId
        Chk.TaxTyp  = 'S'
    Delete Vch rows that have been aggregated.
   ---------------------------------------------------------------------------------
*/
as
begin
    
    declare @eTranNoHist smallint, @CTpId100 smallint, @CTpId200 smallint
    declare @TaxTyp varchar(1)
    declare @SeqNum float
    
    set @eTranNoHist      = 254
    set @CTpId100         = 100    
    set @CTpId200         = 200    
    set @TaxTyp           = 'S'
    
    set nocount on

    BEGIN TRAN

    update Chk
       set TranTyp = @eTranNoHist,
           Dt1     = v.InvDt,
           PayRate = v.PayRate,
           XAmt1   = v.AmtPd,
           XAmt4   = v.DiscAmt,
           XAmt2   = v.NetAmt,
           TaxId   = v.VchId,
           TaxTyp  = @TaxTyp
     from Vch v
     inner join Chk c on c.CTpId = v.CTpId and c.Id = v.ChkId
     where c.CTpId in (@CTpId100,@CTpId200)
       and v.seqnum = (
				select min(SeqNum) 
				  from Vch 
				 where CTpId = c.CTpId 
				   and ChkId = c.Id
					)
       
    if @@error <> 0 begin
      --RAISERROR 30000 'ppSPVchChkConsolidate: consolidation failed the Chk/Vch consolidation'
      rollback tran
      return
    end

    update ArC
       set TranTyp = @eTranNoHist,
           Dt1     = v.InvDt,
           PayRate = v.PayRate,
           XAmt1   = v.AmtPd,
           XAmt4   = v.DiscAmt,
           XAmt2   = v.NetAmt,
           TaxId   = v.VchId,
           TaxTyp  = @TaxTyp
     from ArV v
     inner join ArC c on c.CTpId = v.CTpId and c.Id = v.ChkId
     where c.CTpId in (@CTpId100,@CTpId200)
       and v.seqnum = (
				select min(SeqNum) 
				  from ArV 
				 where CTpId = c.CTpId 
				   and ChkId = c.Id
					)
       
    if @@error = 0 begin
      commit
    end
    else begin
      --RAISERROR 30000 'ppSPVchChkConsolidate: consolidation failed the ArC/ArV consolidation'
      rollback tran
    end

    set nocount off

end

return

/* end of stored procedure */
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPVndInsert]'
GO
/*
* Description: Insert Procedure for the table "dbo.Vnd"
* Created: 10/12/2010 at 17:05:41.295 by Embarcadero Rapid SQL 7.6
*/

ALTER PROCEDURE [dbo].[ppSPVndInsert]
(
	@Typ                                varchar(10),
	@Id                                 varchar(30),
	@SrchNam                            varchar(23),
	@Nam                                varchar(100),
	@Adr1                               varchar(100),
	@Adr2                               varchar(100),
	@Adr3                               varchar(100),
	@Adr4                               varchar(100),
	@City                               varchar(40),
	@State                              varchar(2),
	@Zip                                varchar(10),
	@CountryId                          varchar(15),
	@PhNum                              varchar(20),
	@Office                             varchar(60),
	@DeptCd                             varchar(40),
	@MailStop                           varchar(20),
	@RefNum                             varchar(30),
	@ExpAcct                            varchar(50),
	@TaxId                              varchar(9),
	@TaxTyp                             varchar(1),
	@Tax1099                            tinyint,
	@EftCd                              tinyint,
	@PrenoteCd                          tinyint,
	@EftBtch                            int,
	@BnkAcct                            varchar(25),
	@BnkRout                            varchar(20),
	@AcctNam                            varchar(21),
	@EftTypCd                           varchar(1),
	@BnkAcct2                           varchar(25),
	@BnkRout2                           varchar(20),
	@AcctNam2                           varchar(21),
	@EftTypCd2                          varchar(1),
	@BnkAcct3                           varchar(25),
	@BnkRout3                           varchar(20),
	@AcctNam3                           varchar(21),
	@EftTypCd3                          varchar(1),
	@AllocPct1                          decimal(6,3),
	@AllocPct2                          decimal(6,3),
	@AllocPct3                          decimal(6,3),
	@OptCd                              varchar(2),
	@GrpVndId                           varchar(30),
	@FrgnCd                             tinyint,
	@TaxState                           varchar(2),
	@AcctNum                            int,
	@Excl1099                           tinyint,
	@AttyCd                             tinyint,
	@FaxNum                             varchar(20),
	@FaxNumTyp                          tinyint,
	@FaxToNam                           varchar(50),
	@EmailAdr                           varchar(255),
	@Salutation                         varchar(40),
	@ClmRptTyp                          varchar(1),
	@AdviceTyp                          varchar(1),
	@TaxPayCd                           tinyint,
	@LastChgId                          varchar(30),
	@LastChgDt                          int,
	@LastChgTm                          int,
	@XCd1                               varchar(255),
	@XCd2                               varchar(50),
	@XCd3                               varchar(20),
	@XCd4                               varchar(20),
	@XCd5                               varchar(20),
	@XCd6                               varchar(20),
	@XCd7                               varchar(20),
	@XCd8                               varchar(20),
	@XCd9                               varchar(20),
	@XCd10                              varchar(20),
	@CardNum                            varchar(25),
	@CardTyp                            varchar(2),
	@MasterCd                           tinyint,
	@Nam1099                            varchar(100),
	@Typ1099                            varchar(5),
	@Inactive                           tinyint,
	@HoldCd                             tinyint,
	@W9Dt                               int,
	@WithholdDt                         int,
	@ACHAddendaTyp                      tinyint,
	@TrmId                              varchar(30),
	@Priority                           tinyint,
	@AltId                              varchar(30),
	@AltTyp                             varchar(10),
	@ConsolidateId                      varchar(30),
	@NoBulk                             tinyint,
	@EftEncrypt                         tinyint,
	@EftApprov                          tinyint,
	@EftApprovId                        varchar(30),
	@EftApprovDt                        int,
	@EftSetupId                         varchar(30),
	@EftSetupDt                         int,
	@ACHReadyEmailSent                  tinyint,
	@ActiveDt                           int,
	@ProviderId                         varchar(30),
	@BnkCd                              varchar(30),
	@MemberId                           varchar(30),
	@CustomCd                           varchar(30),
	@EftStatusDt                        int,
	@DueDtOverride                      tinyint,
	@HacOverride                        tinyint,
	@NoHacWhld                          tinyint,
	@NoAutoUpdate                       tinyint,
	@Nam2                               varchar(100),
	@Mortgagee                          varchar(100),
	@ClmntNum                           varchar(25),
	@ClaimNum                           varchar(30)
)
AS
BEGIN
	BEGIN TRAN
	INSERT INTO dbo.Vnd	(
		Typ,
		Id,
		SrchNam,
		Nam,
		Adr1,
		Adr2,
		Adr3,
		Adr4,
		City,
		State,
		Zip,
		CountryId,
		PhNum,
		Office,
		DeptCd,
		MailStop,
		RefNum,
		ExpAcct,
		TaxId,
		TaxTyp,
		Tax1099,
		EftCd,
		PrenoteCd,
		EftBtch,
		BnkAcct,
		BnkRout,
		AcctNam,
		EftTypCd,
		BnkAcct2,
		BnkRout2,
		AcctNam2,
		EftTypCd2,
		BnkAcct3,
		BnkRout3,
		AcctNam3,
		EftTypCd3,
		AllocPct1,
		AllocPct2,
		AllocPct3,
		OptCd,
		GrpVndId,
		FrgnCd,
		TaxState,
		AcctNum,
		Excl1099,
		AttyCd,
		FaxNum,
		FaxNumTyp,
		FaxToNam,
		EmailAdr,
		Salutation,
		ClmRptTyp,
		AdviceTyp,
		TaxPayCd,
		LastChgId,
		LastChgDt,
		LastChgTm,
		XCd1,
		XCd2,
		XCd3,
		XCd4,
		XCd5,
		XCd6,
		XCd7,
		XCd8,
		XCd9,
		XCd10,
		CardNum,
		CardTyp,
		MasterCd,
		Nam1099,
		Typ1099,
		Inactive,
		HoldCd,
		W9Dt,
		WithholdDt,
		ACHAddendaTyp,
		TrmId,
		Priority,
		AltId,
		AltTyp,
		ConsolidateId,
		NoBulk,
		EftEncrypt,
		EftApprov,
		EftApprovId,
		EftApprovDt,
		EftSetupId,
		EftSetupDt,
		ACHReadyEmailSent,
		ActiveDt,
		ProviderId,
		BnkCd,
		MemberId,
		CustomCd,
		EftStatusDt,
		DueDtOverride,
		HacOverride,
		NoHacWhld,
		NoAutoUpdate,
		Nam2,
		Mortgagee,
		ClmntNum,
		ClaimNum)
	VALUES	
	(
		@Typ,
		@Id,
		@SrchNam,
		@Nam,
		@Adr1,
		@Adr2,
		@Adr3,
		@Adr4,
		@City,
		@State,
		@Zip,
		@CountryId,
		@PhNum,
		@Office,
		@DeptCd,
		@MailStop,
		@RefNum,
		@ExpAcct,
		@TaxId,
		@TaxTyp,
		@Tax1099,
		@EftCd,
		@PrenoteCd,
		@EftBtch,
		@BnkAcct,
		@BnkRout,
		@AcctNam,
		@EftTypCd,
		@BnkAcct2,
		@BnkRout2,
		@AcctNam2,
		@EftTypCd2,
		@BnkAcct3,
		@BnkRout3,
		@AcctNam3,
		@EftTypCd3,
		@AllocPct1,
		@AllocPct2,
		@AllocPct3,
		@OptCd,
		@GrpVndId,
		@FrgnCd,
		@TaxState,
		@AcctNum,
		@Excl1099,
		@AttyCd,
		@FaxNum,
		@FaxNumTyp,
		@FaxToNam,
		@EmailAdr,
		@Salutation,
		@ClmRptTyp,
		@AdviceTyp,
		@TaxPayCd,
		@LastChgId,
		@LastChgDt,
		@LastChgTm,
		@XCd1,
		@XCd2,
		@XCd3,
		@XCd4,
		@XCd5,
		@XCd6,
		@XCd7,
		@XCd8,
		@XCd9,
		@XCd10,
		@CardNum,
		@CardTyp,
		@MasterCd,
		@Nam1099,
		@Typ1099,
		@Inactive,
		@HoldCd,
		@W9Dt,
		@WithholdDt,
		@ACHAddendaTyp,
		@TrmId,
		@Priority,
		@AltId,
		@AltTyp,
		@ConsolidateId,
		@NoBulk,
		@EftEncrypt,
		@EftApprov,
		@EftApprovId,
		@EftApprovDt,
		@EftSetupId,
		@EftSetupDt,
		@ACHReadyEmailSent,
		@ActiveDt,
		@ProviderId,
		@BnkCd,
		@MemberId,
		@CustomCd,
		@EftStatusDt,
		@DueDtOverride,
		@HacOverride,
		@NoHacWhld,
		@NoAutoUpdate,
		@Nam2,
		@Mortgagee,
		@ClmntNum,
		@ClaimNum
	);
    

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'Vnd_INS: Cannot insert data into Vnd'
        ROLLBACK TRAN
        RETURN(1)
    END;

    COMMIT TRAN;
    
    select scope_identity();

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[spArchivePayments]'
GO
ALTER  PROCEDURE [dbo].[spArchivePayments]
(
@archivebchnum int,
@Vchwhereclause varchar(500),
@Txtwhereclause varchar(500),
@ExAwhereclause varchar(500),
@Hstwhereclause varchar(500),
@Chkwhereclause varchar(500)
)
/* 
   --------------------------------------------------------------------------------- 
                                  V E R S I O N  7
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible for archiving payments. The following tables
    are included in the archiving process: Chk, Hst, ExA, TxT and Vch. 
    
    The calling application has the responsibility of passing "where clause" parameters
    to this stored procedure. Records are selected for archive based on the selection 
    criteria that is passed in the "where clause". 
    
    Also, the calling application has the responsibility of creating the batch history (Bch)
    record and it passes the Bch:Num to this procedure, as the first parameter.
    
    Dependencies:  vVchForArchive (view), vTxtForArchive (view), vExAForArchive (view), 
                   vHstForArchive (view), vChkForArchive (view)
                   
    Coding issues: none.
   ---------------------------------------------------------------------------------
*/
AS
BEGIN

  declare @Cmd nvarchar(4000)
  declare @TotPay decimal(14,2), @TotVoid decimal(14,2), @LowChkId decimal(11,0), @HiChkId decimal(11,0)
  declare @BchChkCnt int, @BchVoidCnt int

  set nocount on
  
  set @Vchwhereclause = RTRIM(@Vchwhereclause)
  set @Txtwhereclause = RTRIM(@Txtwhereclause)
  set @ExAwhereclause = RTRIM(@ExAwhereclause)
  set @Hstwhereclause = RTRIM(@Hstwhereclause)
  set @Chkwhereclause = RTRIM(@Chkwhereclause) 

  BEGIN TRAN
/* 
   --------------------------------------------------------------------------------- 
    First, insert each Vch record into the ArV table.
   ---------------------------------------------------------------------------------
*/       
    
    set @Cmd = 'INSERT INTO ArV SELECT v.* FROM vVchForArchive v, Chk c' + ' ' + @Vchwhereclause

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'spArchivePayments: Archive process failed (1)'
        ROLLBACK TRAN
        UPDATE Bch
        SET XCd1  = 'Failed Step 1', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 1', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END
/* 
   --------------------------------------------------------------------------------- 
    Next, nsert each TxT record into the ArT table.
   ---------------------------------------------------------------------------------
*/       
    set @Cmd = 'INSERT INTO ArT SELECT t.* FROM vTxTForArchive t, Chk c' + ' ' + @Txtwhereclause

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'spArchivePayments: Archive process failed (2)'
        ROLLBACK TRAN
        UPDATE Bch
        SET XCd1  = 'Failed Step 2', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 2', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END
/* 
   --------------------------------------------------------------------------------- 
    Insert each ExA record into the ArE table.
   ---------------------------------------------------------------------------------
*/       
    set @Cmd = 'INSERT INTO ArE SELECT e.* FROM vExAForArchive e, Chk c' + ' ' + @ExAwhereclause

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR 20000 'spArchivePayments: Archive process failed (3)'
        ROLLBACK TRAN
        UPDATE Bch
        SET XCd1  = 'Failed Step 3', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 3', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END
/* 
   --------------------------------------------------------------------------------- 
    Insert each Hst record into the ArH table.
   ---------------------------------------------------------------------------------
*/       
    set @Cmd = 'INSERT INTO ArH SELECT h.* FROM vHstForArchive h, Chk c' + ' ' + @Hstwhereclause

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'spArchivePayments: Archive process failed (4)'
        ROLLBACK TRAN
        UPDATE Bch
        SET XCd1  = 'Failed Step 4', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 4', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END

    set @Cmd = 'UPDATE ArH set ArcBch = ' + convert(varchar(30),@archivebchnum) + ' WHERE ArcBch = ' + convert(varchar(30),@@SPID)
    
    Exec sp_executesql @cmd  
  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'spArchivePayments: Archive process failed (5)'
        ROLLBACK TRAN
        UPDATE Bch
        SET XCd1  = 'Failed Step 5', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 5', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END

    set @Cmd = 'Insert into ArC SELECT * FROM vChkForArchive c' + ' ' + @Chkwhereclause

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'spArchivePayments: Archive process failed (6)'
        ROLLBACK TRAN
        UPDATE Bch
        SET XCd1  = 'Failed Step 6', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 6', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END

    SET rowcount 1
    IF NOT exists (select 1 from ArC where RecordId <> 0) BEGIN
     /* update a sinle ArC record to seed this column for the following WHILE loop */
      UPDATE ArC
      SET recordid = 1
    END
    WHILE exists (select Id from ArC where RecordId = 0) BEGIN
      UPDATE ArC
      SET recordid = (select max(recordid) from ArC) + 1
      WHERE RecordId = 0
    END
    SET rowcount 0    

    set @Cmd = 'UPDATE ArC set ArcBch = ' + convert(varchar(30),@archivebchnum) + ' WHERE ArcBch = ' + convert(varchar(30),@@SPID)
    Exec sp_executesql @cmd  
  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'spArchivePayments: Archive process failed (7)'
        ROLLBACK TRAN
        UPDATE Bch
        SET XCd1  = 'Failed Step 7', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 7', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END

/* 
   --------------------------------------------------------------------------------- 
    delete archived payments (Chk), history (Hst) and related child records.
   ---------------------------------------------------------------------------------
*/       
    set @Cmd = 'DELETE Vch FROM Vch v, Chk c' + ' ' + @Vchwhereclause
    Exec sp_executesql @cmd  
  
    IF (@@error!=0)
    BEGIN
      --RAISERROR  20000 'spArchivePayments: Archive process failed (8)'
      ROLLBACK TRAN
      UPDATE Bch
      SET XCd1  = 'Failed Step 8', 
          XNum1 = @@error
      WHERE Num = @archivebchnum
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 8', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END

    set @Cmd = 'DELETE Txt FROM Txt t, Chk c' + ' ' + @Txtwhereclause
    Exec sp_executesql @cmd  
  
    IF (@@error!=0)
    BEGIN
      --RAISERROR  20000 'spArchivePayments: Archive process failed (9)'
      ROLLBACK TRAN
      UPDATE Bch
      SET XCd1  = 'Failed Step 9', 
          XNum1 = @@error
      WHERE Num = @archivebchnum
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 9', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END

    set @Cmd = 'DELETE ExA FROM ExA e, Chk c' + ' ' + @ExAwhereclause
    Exec sp_executesql @cmd  
  
    IF (@@error!=0)
    BEGIN
      --RAISERROR  20000 'spArchivePayments: Archive process failed (10)'
      ROLLBACK TRAN
      UPDATE Bch
      SET XCd1  = 'Failed Step 10', 
          XNum1 = @@error
      WHERE Num = @archivebchnum
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 10', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END

    set @Cmd = 'DELETE Hst FROM Hst h, Chk c' + ' ' + @Hstwhereclause
    Exec sp_executesql @cmd  
  
    IF (@@error!=0)
    BEGIN
      --RAISERROR  20000 'spArchivePayments: Archive process failed (11)'
      ROLLBACK TRAN
      UPDATE Bch
      SET XCd1  = 'Failed Step 11', 
          XNum1 = @@error
      WHERE Num = @archivebchnum
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 11', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END

/* 07/PUB/037, Steve.  Changed the update of the TotVoid and BchVoidCnt to include codes 3,4,7,8  */
    set @TotPay     = (SELECT SUM(PayAmt) FROM Arc where ArcBch = @archivebchnum and VoidCd = 0)
    set @TotVoid    = (SELECT SUM(PayAmt) FROM Arc where ArcBch = @archivebchnum and VoidCd IN(1,2,3,4,7,8,9))
    set @BchChkCnt  = (SELECT COUNT(*) FROM Arc where ArcBch = @archivebchnum and VoidCd = 0)
    set @BchVoidCnt = (SELECT COUNT(*) FROM Arc where ArcBch = @archivebchnum and VoidCd IN(1,2,3,4,7,8,9))
    set @HiChkId    = (SELECT MAX(Id) FROM Arc where ArcBch = @archivebchnum)
    set @LowChkId   = (SELECT MIN(Id) FROM Arc where ArcBch = @archivebchnum)
  
    UPDATE Bch
    SET Amt1 = @TotPay,
      Amt2 = @TotVoid,
      Cnt1 = @BchChkCnt,
      Cnt2 = @BchVoidCnt,
      LowChkId = @LowChkId,
      HiChkId = @HiChkId
    WHERE Num = @archivebchnum
  
    IF (@@error!=0)
    BEGIN
      --RAISERROR  20000 'spArchivePayments: Archive process failed updating Bch record (12)'
      ROLLBACK TRAN
      UPDATE Bch
      SET XCd1  = 'Failed Step 12', 
          XNum1 = @@error
      WHERE Num = @archivebchnum
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 12', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END

    set @Cmd = 'DELETE Chk FROM Chk c' + ' ' + @Chkwhereclause
    Exec sp_executesql @cmd  
  
    IF (@@error!=0)
    BEGIN
      --RAISERROR  20000 'spArchivePayments: Archive process failed (13)'
      ROLLBACK TRAN
      UPDATE Bch
      SET XCd1  = 'Failed Step 13', 
          XNum1 = @@error
      WHERE Num = @archivebchnum
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Succeeded Step 13', 
            XNum1 = @@error
        WHERE Num = @archivebchnum
    END

  COMMIT TRAN

  set nocount off
    
  RETURN /* Return with a zero status to indicate a successful process */

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[spBackOutBankProcedureBatch]'
GO
ALTER   PROCEDURE [dbo].[spBackOutBankProcedureBatch]
(
@backoutbchnum int,
@OperId varchar(31)
)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible for backing out a Bch from the following 
    processes:
	1) Void
	2) Stale Date Bank File Batch
	3) Apply Paid Items 
    	4) Stop Payment Requests
    	5) Stop Payment Confirms
    	6) Stop Payments
    
    The calling application has the responsibility of passing the Bch:Num and the
    Glo:OprId to this procedure, as the only two (2) parameters.

    Dependencies:  BchTran (table) - this table must be populated during the 
                   Bank File processes.
                   
    Coding issues: none.
   ---------------------------------------------------------------------------------
*/
AS
BEGIN

  declare @ChkRecordId int, @Today int, @TranTyp tinyint, @BackOutTranTyp tinyint
  declare @eTranVoid smallint, @eTranUnVoid smallint, @eTranPd smallint
  declare @eTranStaleDtVoid smallint, @eTranStaleDtVoidBackout smallint
  declare @eTranUnPd smallint, @eTranStop smallint, @eTranUnStop smallint
  declare @eAutoVoidCd smallint, @eStopCd smallint, @eStaleDtVoidCd smallint, @eACHReturnCd smallint
  declare @eTranBldEft smallint, @eTranBackoutEft smallint
  declare @eTranBldIss smallint, @eTranBackoutIss smallint
  declare @eTranExport smallint, @eTranExportBackout smallint
  declare @eTranBackoutBnkImp smallint, @eTranReturn smallint
  declare @eTranGL smallint, @eTranGLBackout smallint
  declare @eTranStopSent smallint, @eTranUnStopSent smallint, @eStopReqCd tinyint
  declare @eTranStopConfirm smallint, @eTranUnStopConfirm smallint
  declare @eTranStopReject smallint, @eTranUnStopReject smallint

  declare @eACHPayBatch varchar(3), @eReconBatch  varchar(3), @eDeleteBatch varchar(3) 
  declare @eACHDebitBatch varchar(3), @eACHDebitAdviceBatch  varchar(3), @eACHPaymentAdviceBatch varchar(3) 
  declare @eACHReturnsBatch varchar(3), @eImportBatch varchar(3), @eStopSentBatch varchar(3)
  declare @eStopConfirmBatch varchar(3), @eOutstandChkMatchBatch varchar(3), @eACHPayPrenoteBatch  varchar(3) 
  declare @eOFACImportBatch varchar(3), @ePrintBatch varchar(3), @eIssChkBatch varchar(3) 
  declare @eStaleDtVoidBatch varchar(3), @eTestImportBatch varchar(3), @eUploadBatch varchar(3)
  declare @eArchiveBatch varchar(3), @eExportBatch varchar(3), @eVerifiedPayBatch varchar(3)
  declare @eACHDebitPrenoteBatch varchar(3), @eHaciendaCustomBatch varchar(3), @eHacienda480Batch varchar(3)
  declare @eUSAFederalBatch varchar(3), @eStaleDtVoidBnkFileBatch varchar(3), @eChkReturnBatch  varchar(3)

  declare @BchTyp varchar(3), @BchDt int, @BchTime int, @TranTime int

/* 
   ------------------------------------------------------------------------------------------ 
    The following statement converts the SQL date (today's date) to a Clarion date
   ------------------------------------------------------------------------------------------
*/  
  set @Today = datediff(dd, '12/28/1800', getdate())
  set @TranTime = convert(int,substring(convert(varchar(20),getdate(),108),1,2) + substring(convert(varchar(20),getdate(),108),4,2)) * 3600 + 30000 -- add an additional 2 minutes
  
/* 
   ------------------------------------------------------------------------------------------ 
    Following, are "pairs" of TranTyp values (equates) that Set / Reverse Bch processes
   ------------------------------------------------------------------------------------------
*/  
  set @eTranPd = 60
  set @eTranUnPd = 130
--
  set @eTranVoid = 190
  set @eTranUnVoid = 170
--
  set @eTranStaleDtVoid = 191
  set @eTranStaleDtVoidBackout = 192
--
  set @eTranReturn = 195
--
  set @eTranExport = 197
  set @eTranExportBackout = 198
--
  set @eTranStop = 110
  set @eTranUnStop = 160
--
  set @eTranStopSent = 114
  set @eTranUnStopSent = 134
--
  set @eTranStopConfirm = 112
  set @eTranUnStopConfirm = 132
--
  set @eTranStopReject = 113
  set @eTranUnStopReject = 133
--
  set @eTranBldEft = 210
  set @eTranBackoutEft = 211
--
  set @eTranBldIss = 220
  set @eTranBackoutIss = 221
--
  set @eTranGL = 242
  set @eTranGLBackout = 243
--
  set @eTranBackoutBnkImp = 222
  set @eStopReqCd = 7

/* 
   ------------------------------------------------------------------------------------------
     Void Cd initial values follow:
   ------------------------------------------------------------------------------------------
*/  
  set @eAutoVoidCd = 1
  set @eStopCd = 3
  set @eACHReturnCd = 8
  set @eStaleDtVoidCd = 9

/*
   --------------------------------------------------------------------------------- 
     Batch Types Follow
   ---------------------------------------------------------------------------------
*/
  set @eACHPayBatch       	= 'A' 
  set @eReconBatch        	= 'C' 
  set @eDeleteBatch       	= 'D' 
  set @eACHDebitBatch     	= 'E' 
  set @eACHDebitAdviceBatch     = 'F' 
  set @eACHPaymentAdviceBatch   = 'G' 
  set @eACHReturnsBatch   	= 'H' 
  set @eImportBatch       	= 'I'
  set @eStopSentBatch	= 'J'
  set @eStopConfirmBatch	= 'K'
  set @eOutstandChkMatchBatch   = 'M'
  set @eACHPayPrenoteBatch      = 'N' 
  set @eOFACImportBatch   	= 'O' 
  set @ePrintBatch        	= 'P' 
  set @eIssChkBatch       	= 'R' 
  set @eStaleDtVoidBatch  	= 'S' 
  set @eTestImportBatch   	= 'T' 
  set @eUploadBatch       	= 'U' 
  set @eArchiveBatch      	= 'V' 
  set @eExportBatch       	= 'X' 
  set @eVerifiedPayBatch  	= 'Y' 
  set @eACHDebitPrenoteBatch    = 'Z'
  set @eHaciendaCustomBatch	= '1'
  set @eHacienda480Batch	= '2'
  set @eUSAFederalBatch	        = '3'
  set @eStaleDtVoidBnkFileBatch = '4'
  set @eChkReturnBatch          = '5'
  
  declare Backout_Bnk_Process cursor for
  select BchTyp, BchDt, BchTime, ChkRecordId, TranTyp
  from vBnkProcess
  where BchNum = @backoutbchnum
  
  set nocount on
  
  BEGIN TRAN

    OPEN Backout_Bnk_Process
    FETCH Backout_Bnk_Process into @BchTyp, @BchDt, @BchTime, @ChkRecordId, @TranTyp
    WHILE @@fetch_status = 0
    BEGIN

      IF @TranTyp = @eTranVoid          	-- 1) Void back out
      BEGIN
        Update Chk 
        Set RcnBch = SavRcnBch,
	   UnVoidCd = VoidCd, 
           UnVoidId = @OperId, 
           UnVoidDt = @Today,
           VoidCd   = 0, 
           VoidDt   = 0,
           TranDt   = @Today,
           Trantime = @TranTime,
           TranId   = @OperId, 
           TranTyp  = @eTranUnVoid,     
           ChgDt    = @Today,
           ChgTime  = @TranTime,
           ChgId    = @OperId, 
           VoidId   = '', 
           RsnCd    = ''
        where RecordId = @ChkRecordId
          and TranTyp = @TranTyp
          and TranDt = @BchDt
        IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: 1) Backout process failed (eTranVoid)'
           ROLLBACK TRAN
           CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate a failure */
        END
      END

      IF (@TranTyp = @eTranStaleDtVoid or @TranTyp = @eStaleDtVoidBnkFileBatch)	-- 2) Stale Date Void Back out 
      BEGIN
        Update Chk 
        Set 
           UnVoidCd = VoidCd, 
           UnVoidId = @OperId, 
           UnVoidDt = @Today,
           VoidCd   = 0, 
           VoidDt   = 0, 
           VoidId   = '', 
           RsnCd    = '',
           PdBch    = 0,
           TranDt   = @Today,
           Trantime = @TranTime,
           TranId   = @OperId, 
           TranTyp  = @eTranStaleDtVoidBackout,
           ChgDt    = @Today,
           ChgTime  = @TranTime,
           ChgId    = @OperId
        where RecordId = @ChkRecordId
          and TranTyp = @TranTyp
          and TranDt = @BchDt
      IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: 2a) Backout process failed (eTranStaleDtVoid)'
           ROLLBACK TRAN
           CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
        END

        Update Chk 
        Set RcnBch    = SavRcnBch,
           SavRcnBch = 0
        where RecordId = @ChkRecordId
          and TranDt   = @Today
          and Trantime = @TranTime
          and TranId   = @OperId
          and TranTyp  = @eTranStaleDtVoidBackout
          and SavRcnBch > 0
        IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: 2b) Backout process failed (eTranStaleDtVoid)'
           ROLLBACK TRAN
           CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
        END
      END

      IF @TranTyp = @eTranPd			-- 3) Apply Paid Back out 
      BEGIN
        Update Chk 
        Set -- RcnBch  = SavRcnBch, - we have to fix this, maybe using the BchTran?
           PdCd     = 0,
           PdDt     = 0, 
           PdBch    = 0, 
           TranDt   = @Today,
           Trantime = @TranTime,
           TranId   = @OperId, 
           TranTyp  = @eTranUnPd,
           ChgDt    = @Today,
           ChgTime  = @TranTime,
           ChgId    = @OperId
        where RecordId = @ChkRecordId
          and PdCd <> 0
          and TranTyp = @TranTyp
          and TranDt = @BchDt
        IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: Backout process failed (eTranPd)'
           ROLLBACK TRAN
           CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
        END
      END
      
      IF @TranTyp = @eTranStopSent		-- 4) Stop Semt Back out
      BEGIN
        Update Chk 
        Set TranDt  = @Today,
           Trantime = @TranTime,
           TranId   = @OperId, 
           TranTyp  = @eTranUnStopSent,      
           ChgDt    = @Today,
           ChgTime  = @TranTime,
           ChgId    = @OperId
        where RecordId = @ChkRecordId
          and TranTyp = @TranTyp
          and TranDt = @BchDt
        IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: Backout process failed (eTranStopSent)'
           ROLLBACK TRAN
           CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
        END
          
        Update ChkStop
        Set ProcessDt = NULL,
        RequestBch    = NULL
        where RecordId = @ChkRecordId 
          and StatusCd = 0        
        IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: Backout ChkStop process failed (eTranStopSent)'
           ROLLBACK TRAN
           CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
        END

      END
      
      IF @TranTyp = @eTranStopConfirm  -- 5a) Stop Payment Confirms (Confirm) Back out
      BEGIN
        Update Chk 
        Set
	       UnVoidCd = VoidCd, 
           UnVoidId = @OperId, 
           UnVoidDt = @Today,
           RcnBch   = 0, 
           VoidCd   = 0, 
           VoidDt   = 0, 
           VoidId   = '', 
           RsnCd    = '',
           TranDt   = @Today,
           Trantime = @TranTime,
           TranId   = @OperId, 
           TranTyp  = @eTranUnStopConfirm,      
           ChgDt    = @Today,
           ChgTime  = @TranTime,
           ChgId    = @OperId
        from Chk c
        inner join ChkStop s on s.RecordId = c.RecordId
        where c.RecordId = @ChkRecordId
          and c.TranTyp = @TranTyp
          and c.TranDt = @BchDt
          and s.ConfirmCd = 1 -- Confirm
        IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: (5a) Backout process failed (eTranStopConfirm)'
           ROLLBACK TRAN
           CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
        END

        Update ChkStop 
        Set ConfirmBch = 0, 
            ConfirmId  = '',
            ConfirmCd  = 0
        where RecordId = @ChkRecordId
          and ConfirmCd = 1
        IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: (5a) Backout ChkStop process failed (eTranStopConfirm)'
           ROLLBACK TRAN
           CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
        END

      END
      
      IF @TranTyp = @eTranStopReject -- 5b) Stop Payment Confirm (Reject) Back out
      BEGIN
        Update Chk 
        Set
	       UnVoidCd = VoidCd, 
           UnVoidId = @OperId, 
           UnVoidDt = @Today,
           SavRcnBch = RcnBch, 
           RcnBch   = s.ConfirmBch, 
           VoidCd   = @eStopReqCd, 
           VoidDt   = 0, 
           VoidId   = '', 
           RsnCd    = '',
           TranDt   = @Today,
           Trantime = @TranTime,
           TranId   = @OperId, 
           TranTyp  = @eTranUnStopReject,      
           ChgDt    = @Today,
           ChgTime  = @TranTime,
           ChgId    = @OperId
        from Chk c
        inner join ChkStop s on s.RecordId = c.RecordId
        where c.RecordId = @ChkRecordId
          and c.TranTyp = @TranTyp
          and c.TranDt = @BchDt
          and s.ConfirmCd = 2	-- Reject
        IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: (5b) Backout process failed (@eTranUnStopReject)'
           ROLLBACK TRAN
           CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
        END

        Update ChkStop 
        Set ConfirmBch = 0, 
            ConfirmId  = '',
            ConfirmCd  = 0
        where RecordId = @ChkRecordId
          and ConfirmCd = 2	-- Reject
        IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: (5b) Backout ChkStop process failed (eTranStopConfirm)'
           ROLLBACK TRAN
           CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
        END
      END
      
      IF @TranTyp = @eTranStop			-- 6) Stop Payment Back out
      BEGIN
        Update Chk 
        Set 
	   UnVoidCd = VoidCd, 
           UnVoidId = @OperId, 
           UnVoidDt = @Today,
           SavRcnBch = RcnBch, 
           RcnBch   = 0, 
           VoidCd   = 0, 
           VoidDt   = 0, 
           VoidId   = '', 
           RsnCd    = '',
           TranDt   = @Today,
           Trantime = @TranTime,
           TranId   = @OperId, 
           TranTyp  = @eTranUnStop,      
           ChgDt    = @Today,
           ChgTime  = @TranTime,
           ChgId    = @OperId
        where RecordId = @ChkRecordId
          and TranTyp = @TranTyp
          and TranDt = @BchDt
        IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: Backout process failed (eTranStop)'
           ROLLBACK TRAN
           CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
        END

        Update ChkStop 
        Set RequestBch = 0, 
            ProcessDt = 0 
        where RecordId = @ChkRecordId
        IF (@@error!=0)
        BEGIN
           --RAISERROR  20000 'spBackoutAppliedBch: (6) Backout ChkStop process failed (eTranStopConfirm)'
           ROLLBACK TRAN
  CLOSE Backout_Bnk_Process
           DEALLOCATE Backout_Bnk_Process
           RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
        END
      END
      
      FETCH Backout_Bnk_Process into @BchTyp, @BchDt, @BchTime, @ChkRecordId, @TranTyp

    END /* End WHILE Loop */

    CLOSE Backout_Bnk_Process
    DEALLOCATE Backout_Bnk_Process

    Update Bch
    Set BckCd = 1 -- True
    where Num = @backoutbchnum

  COMMIT TRAN

  set nocount off
      
  RETURN /* Return with a zero status to indicate a successful process */
  
END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[SPChkReissue]'
GO
ALTER PROCEDURE [dbo].[SPChkReissue]
(
@CTpId smallint,
@OrigChkId decimal(11,0),
@ReissueChkId decimal(11,0)
)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible for creating the "child" records for
    reissued payments.
   ---------------------------------------------------------------------------------
*/       
AS
BEGIN

declare @Cmd nvarchar(4000)

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

  BEGIN TRAN

  INSERT INTO Vch
  SELECT
	CTpId,
	@ReissueChkId,
	SeqNum,
	DescTxt,
	VchId,
	InvId,
	CshAcct,
	ExpAcct,
	CostCtr,
	InsNam,
	ClmntNam,
	ClmntNum,
	ClaimNum,
	TranCd,
	PolId,
	InvDt,
	InvAmt,
	AmtPd,
	DiscAmt,
	NetAmt,
	ExpBch,
	DiagCd,
	RsnCd,
	Amt1,
	Amt2,
	Dt1,
	Dt2,
	Dt3,
	Dt4,
	Qty1,
	Qty2,
	Qty3,
	PayRate,
	XRate1,
	XRate2,
	XRate3,
	XRate4,
	XRate5,
	Time,
	Tax1099,
	XCd1,
	XCd2,
	XCd3,
	XCd4,
	XCd5,
	XCd6,
	XCd7,
	XCd8,
	XCd9,
	XCd10,
	TaxId,
	TaxTyp,
	Amt3,
	Amt4,
	Amt5,
	Dt5,
	Tax1099Cd,
	Typ1099,
    CommissionId
  FROM Vch
  WHERE CTpId = @CTpId
    AND ChkId = @OrigChkId

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'SPChkReissue: Vch Insert process failed while Reissuing a Chk (1)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  INSERT INTO Txt
  SELECT
	CTpId,
	@ReissueChkId,
	SeqNum,
	TextLine,
	XCd1,
	XCd2,
	XCd3,
	XCd4,
	XCd5,
	XAmt,
	XDt1
  FROM Txt
  WHERE CTpId = @CTpId
    AND ChkId = @OrigChkId

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'SPChkReissue: TXT insert process failed while Reissuing a Chk (2)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  INSERT INTO ExA
  SELECT
	CTpId,
	@ReissueChkId,
	ExpAcct,
	CostCtr,
	NetAmt,
	DebitAmt,
	CreditAmt,
	ExpBch,
	VoidCd,
	Tax1099,
	DescTxt,
	DiagCd,
	Typ,
	XCd1,
	XCd2,
	XCd3,
	XCd4,
	XCd5,
	XNum1,
	XNum2,
	XNum3,
	XAmt1,
	XAmt2,
	XAmt3,
	XDt1,
	XDt2,
	XDt3,
	XDt4,
	ExpBch2,
	ExpBch3,
	Accounting,
	InvId
  FROM ExA
  WHERE CTpId = @CTpId
    AND ChkId = @OrigChkId

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'SPChkReissue: ExA insert process failed while Reissuing a Chk (3)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END
  
  COMMIT TRAN

  set nocount off
    
  RETURN /* Return with a zero status to indicate a successful process */

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[spPrintChk]'
GO
ALTER Procedure [dbo].[spPrintChk] (
            @ParmBchNum int,
			@ParmRecordId int,
			@ParmOprId varchar(30), 
			@ParmRunId varchar(30), 
			@ParmRepRsn varchar(25), 
			@ParmCTpBnkId smallint, 
			@ParmCTpPrtChk tinyint
				)
AS

declare @BchDt int, @BchTime int, @PayAmt decimal(11,2), @PrtCnt tinyint
declare @TranTyp smallint, @eTranPrePrint smallint, @eTranPrt smallint, @eTranReprint smallint
declare @Today int

set @Today = convert(int,datediff(dd, '12/28/1800',getdate()))

begin tran

set @eTranPrePrint = 75
set @eTranPrt = 80
set @eTranReprint = 100
set @BchDt = 0
set @BchTime = 0

select @BchDt = Dt,
       @BchTime = Time
from Bch
where Num = @ParmBchNum

select @PayAmt = PayAmt,
       @PrtCnt = PrtCnt
from Chk
where RecordId = @ParmRecordId

if @ParmBchNum = 0 begin
  if @PayAmt = 0 begin
    set @TranTyp = @eTranPrePrint 
  end
  else begin
    set @TranTyp = @eTranPrt
  end
end
else begin
  if @PrtCnt = 0 begin
    set @TranTyp = @eTranPrt 
  end
  else begin
    set @TranTyp = @eTranReprint 
  end
end

if @PayAmt > 0 begin
  set @PrtCnt = @PrtCnt + 1
end
if @PayAmt = 0 begin
  if @ParmCTpPrtChk = 2 begin
    set @PrtCnt = @PrtCnt + 1
  end
end

update Chk
set TranDt   = @BchDt,
    TranTime = @BchTime,
    Tranid   = @ParmOprId,
    TranTyp  = @TranTyp,
    PrtDt    = @Today,
    PrtId    = @ParmOprId,
    PrtCnt   = @PrtCnt,
    PrtBch   = @ParmBchNum,
    ModVer   = ModVer + 1,
    RepRsn   = @ParmRepRsn
  /* BnkId    = @ParmCTpBnkId */
where RecordId = @ParmRecordId

if @@error <> 0
begin
  --RAISERROR ('Update Chk failure in stored proc spPrintChk; rolling back changes', 16,1)
  rollback transaction
  return
end

/*-----------------------------------------------------------------------------------------------
    Note: the Version 7 implementation of this stored procedure does NOT insert a row into the Hst
    table - the update to the Chk record causes the ChkUpdate trigger to fire - the trigger has
    the responsibility for inserting the new Hst row.
    
    PayPilot Version 6 does not use the ChkUpdate trigger. Therefore, any Version 6 implementation
    of this stored procedure must insert the Hst row.
  -----------------------------------------------------------------------------------------------*/  

commit tran

return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[spPrintChks]'
GO
ALTER Procedure [dbo].[spPrintChks] (
			@ParmBchNum int, 
			@ParmOprId varchar(30), 
			@ParmRunId varchar(30), 
			@ParmRepRsn varchar(25), 
			@ParmCTpBnkId smallint, 
			@ParmCTpPrtChk tinyint
				)
AS

declare @BchDt int, @BchTime int, @OperId varchar(30), @PrtBch int, @PayAmt decimal(11,2), @PrtCnt tinyint
declare @RepRsn varchar(25), @BnkId int, @ChkRecordId int
declare @TranTyp smallint, @eTranPrePrint smallint, @eTranPrt smallint, @eTranReprint smallint
declare @Today int

set @Today = convert(int,datediff(dd, '12/28/1800',getdate()))

begin tran

set @eTranPrePrint = 75
set @eTranPrt = 80
set @eTranReprint = 100

select @BchDt = Dt,
       @BchTime = Time,
       @OperId = OperId
from Bch
where Num = @ParmBchNum

declare ChksToProcess cursor for
select RecordId
from tProcess
where RunId = @ParmRunId
and OprId = @ParmOprId

open ChksToProcess
fetch ChksToProcess into @ChkRecordId
while @@fetch_status = 0 begin

  select @PrtBch = PrtBch,
         @PayAmt = PayAmt,
         @PrtCnt = PrtCnt,
         @RepRsn = RepRsn,
         @BnkId  = BnkId 
  from Chk
  where RecordId = @ChkRecordId

  if @PrtBch = 0 begin
    if @PayAmt = 0 begin
      set @TranTyp = @eTranPrePrint 
    end
    else begin
      set @TranTyp = @eTranPrt
    end
  end
  else begin
    set @TranTyp = @eTranReprint 
    set @RepRsn = @ParmRepRsn
  /* set @BnkId = @ParmCTpBnkId */
  end

  if @PayAmt > 0 begin
    set @PrtCnt = @PrtCnt + 1
  end
  if @PayAmt = 0 begin
    if @ParmCTpPrtChk = 2 begin
      set @PrtCnt = @PrtCnt + 1
    end
  end

  update Chk
  set TranDt   = @BchDt,
      TranTime = @BchTime,
      Tranid   = @OperId,
      TranTyp  = @TranTyp,
      PrtDt    = @Today,
      PrtId    = @OperId,
      PrtCnt   = PrtCnt + 1,
      PrtBch   = @ParmBchNum,
      ModVer   = ModVer + 1,
      RepRsn   = @RepRsn
    /* BnkId    = @BnkId */
  where RecordId = @ChkRecordId

  if @@error <> 0
  begin
    --RAISERROR ('Update Chk failure in stored proc spPrintChks; rolling back changes', 16,1)
    rollback transaction
    return
  end

/*-----------------------------------------------------------------------------------------------
    Note: the Version 7 implementation of this stored procedure does NOT insert a row into the Hst
    table - the update to the Chk record causes the ChkUpdate trigger to fire - the trigger has
    the responsibility for inserting the new Hst row.
    
    PayPilot Version 6 does not use the ChkUpdate trigger. Therefore, the Version 6 implementation
    of this stored procedure inserts the Hst row.
  -----------------------------------------------------------------------------------------------*/  

  fetch ChksToProcess into @ChkRecordId

end

commit tran

close ChksToProcess
deallocate ChksToProcess

return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[SPRcnBchUpdate]'
GO
ALTER procedure [dbo].[SPRcnBchUpdate]
(
@ParmBchnum int,
@ParmCTpId smallint
)
as

declare @vBchDt int, @vBchTime int, @vOperId varchar(30), @vBnkId int, @vChkRecordId int
declare @vTranTyp int, @eStopCd int, @eStopReqCd int, @eTranBldIss int
declare @eAutoVoidCd int, @eManVoidCd int, @eStaleDtVoidCd int, @eWriteOffCd int
declare @vErrMsg varchar(100)

set @eStopCd = 3
set @eStopReqCd = 7
set @eTranBldIss = 220
set @eAutoVoidCd = 1
set @eManVoidCd = 2
set @eStaleDtVoidCd = 9
set @eWriteOffCd = 4

set @vBnkId = (select BnkId from PayTyp where Id = @ParmCTpId)
if @vBnkId is NULL
begin
  set @vErrMsg = '@ParmCTpId: ' + convert(varchar(8),@ParmCTpId)
  print '@ParmCTpId: ' + convert(varchar(8),@ParmCTpId)
  return(1)
end

select @vBchDt   = Dt, 
       @vBchTime = Time,
       @vOperId  = OperId
from Bch 
where Num = @ParmBchnum

declare RecId_Curs cursor for
select RecordId
from Chk
inner join Bnk on Bnk.Id = Chk.BnkId
inner join BkH on BkH.Id = Bnk.BkHId
inner join BEH on BEH.Id = BkH.BEHId
where CHK.CTpId  = @ParmCTpId
  and CHK.BnkId  = @vBnkId
  and ((CHK.VoidCd = 0 AND BEH.Issue = 1) 
   or (CHK.VoidCd IN (@eStopCd, @eStopReqCd) AND BEH.Stop = 1)
   or (CHK.VoidCd IN (@eAutoVoidCd, @eManVoidCd, @eStaleDtVoidCd, @eWriteOffCd) AND BEH.Void = 1))
  and CHK.RcnBch = 0

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open RecId_Curs
fetch RecId_Curs into @vChkRecordId
while @@fetch_status = 0
begin
/* ---------------------------------------------------------------------------------------- 
     Read through each Chk row (as defined by the cursor) and update the RcnBch for the Chk
   ---------------------------------------------------------------------------------------- */       
  
  update Chk
  set TranDt = @vBchDt,
    TranTime = @vBchTime,
    Tranid   = @vOperId,
    TranTyp  = @eTranBldIss,
    ModVer   = ModVer + 1,
    ChgDt    = @vBchDt,
    ChgTime  = @vBchTime,
    ChgId    = @vOperId,
    RcnBch   = @ParmBchnum
  where RecordId = @vChkRecordId

  fetch RecId_Curs into @vChkRecordId

END
close RecId_Curs
deallocate RecId_Curs

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'SPRcnBcnUpdate: errors while processing the Chk table'
  ROLLBACK TRAN
  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[SPRcnBcnUpdate]'
GO
ALTER procedure [dbo].[SPRcnBcnUpdate]
(
@ParmBchnum int,
@ParmCTpId smallint
)
as

declare @vBchDt int, @vBchTime int, @vOperId varchar(30), @vBnkId int, @vChkRecordId int
declare @vTranTyp int, @eStopCd int, @eStopReqCd int, @eTranBldIss int
declare @eAutoVoidCd int, @eManVoidCd int, @eStaleDtVoidCd int, @eWriteOffCd int

set @eStopCd = 3
set @eStopReqCd = 7
set @eTranBldIss = 220
set @eAutoVoidCd = 1
set @eManVoidCd = 2
set @eStaleDtVoidCd = 9
set @eWriteOffCd = 4

declare RecId_Curs cursor for
select RecordId
from Chk
inner join Bnk on Bnk.Id = Chk.BnkId
inner join BkH on BkH.Id = Bnk.BkHId
inner join BEH on BEH.Id = BkH.BEHId
where CHK.CTpId  = @ParmCTpId
  and CHK.BnkId  = @vBnkId
  and ((CHK.VoidCd = 0 AND BEH.Issue = 1) 
   or (CHK.VoidCd IN (@eStopCd, @eStopReqCd) AND BEH.Stop = 1)
   or (CHK.VoidCd IN (@eAutoVoidCd, @eManVoidCd, @eStaleDtVoidCd, @eWriteOffCd) AND BEH.Void = 1))
  and CHK.RcnBch = 0

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open RecId_Curs
fetch RecId_Curs into @vChkRecordId
while @@fetch_status = 0
begin
/* ---------------------------------------------------------------------------------------- 
     Read through each Chk row (as defined by the cursor) and update the RcnBch for the Chk
   ---------------------------------------------------------------------------------------- */       

      update Chk
      set TranDt = @vBchDt,
        TranTime = @vBchTime,
        Tranid   = @vOperId,
        TranTyp  = @eTranBldIss,
        ModVer   = ModVer + 1,
        ChgDt    = @vBchDt,
        ChgTime  = @vBchTime,
        ChgId    = @vOperId,
        RcnBch   = @ParmBchnum
      where RecordId = @vChkRecordId


  fetch RecId_Curs into @vChkRecordId

END
close RecId_Curs
deallocate RecId_Curs

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'SPRcnBcnUpdate: errors while processing the Chk table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[spReissueTxtVch1]'
GO
ALTER   Procedure [dbo].[spReissueTxtVch1] (
@CopyFromRecordId int,
@CopyToRecordId int
)
AS

declare @CTpId smallint, @OrigChkId decimal(11,0), @ReissueChkId decimal(11,0), @VchId int

select @CTpId = (select CTpId from Chk where RecordId = @CopyFromRecordId),
       @OrigChkId = (select Id from Chk where RecordId = @CopyFromRecordId)
select @ReissueChkId = (select Id from Chk where RecordId = @CopyToRecordId)

declare vch_curs cursor for
select Id from Vch where CTpId = @CTpId and ChkId = @ReissueChkId

insert into Txt
select
  CTpId,
  @ReissueChkId,
  SeqNum,
  TextLine,
  XCd1,
  XCd2,
  XCd3,
  XCd4,
  XCd5,
  XAmt,
  XDt1
FROM Txt
WHERE CTpId = @CTpId
  AND ChkId = @OrigChkId

IF (@@error!=0)
BEGIN
    --RAISERROR  20000 'spReissueTxtVch1: TXT insert process failed while Reissuing a Chk (1)'
    ROLLBACK TRAN
    RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

/*-----------------------------------------------------------------------------------------------
   This procedure copies Vch1 child records (child to Vch) for a payment with the Chk is Reissued
  -----------------------------------------------------------------------------------------------*/  

if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Vch1]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
begin
  return
end

if @CopyFromRecordId = 0
begin
  --RAISERROR ('Invalid @CopyFromRecordId parameter value in stored proc spReissueVch1; rolling back changes', 16,1)
  return
end

if @CopyToRecordId = 0
begin
  --RAISERROR ('Invalid @CopyToRecordId parameter value in stored proc spReissueVch1; rolling back changes', 16,1)
  return
end

if not exists (
  select 1 from Vch1 v1 with (nolock) 
  INNER Join Vch v with (nolock) on v1.VchId = v.Id
  INNER JOIN Chk c with (nolock) on c.CTpId = v.CTpId AND c.Id = v.ChkId
  where c.RecordId = @CopyFromRecordId
   )
begin
  return
end

begin tran

  open vch_curs
  fetch vch_curs into @VchId
  while @@fetch_status = 0
  begin

   insert into Vch1
   select top 1
    @VchId,
    v1.XCd1,
    v1.XCd2,
    v1.XCd3,
    v1.XCd4,
    v1.XCd5,
    v1.XCd6,
    v1.XCd7,
    v1.XCd8,
    v1.XCd9,
    v1.XCd10,
    v1.XCd11,
    v1.XCd12,
    v1.XCd13,
    v1.XCd14,
    v1.XCd15,
    v1.XCd16,
    v1.XCd17,
    v1.XCd18,
    v1.XCd19,
    v1.XCd20,
    v1.XAmt1,
    v1.XAmt2,
    v1.XAmt3,
    v1.XAmt4,
    v1.XAmt5,
    v1.XAmt6,
    v1.XAmt7,
    v1.XAmt8,
    v1.XAmt9,
    v1.XAmt10,
    v1.XDt1,
    v1.XDt2,
    v1.XDt3,
    v1.XDt4,
    v1.XDt5,
    v1.XDt6,
    v1.XDt7,
    v1.XDt8,
    v1.XDt9,
    v1.XDt10,
    v1.XNum1,
    v1.XNum2,
    v1.XNum3,
    v1.XNum4,
    v1.XNum5,
    v1.XNum6,
    v1.XNum7,
    v1.XNum8,
    v1.XNum9,
    v1.XNum10
   from Vch1 v1 with (nolock) 
   inner Join Vch v with (nolock) on v1.VchId = v.Id
   inner JOIN Chk c with (nolock) on c.CTpId = v.CTpId AND c.Id = v.ChkId
   where c.RecordId = @CopyFromRecordId

   fetch vch_curs into @VchId

  end /* end of cursor While Loop */

  close vch_curs
  deallocate vch_curs

commit tran

return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[spRestoreAllArchivedPayments]'
GO
ALTER PROCEDURE [dbo].[spRestoreAllArchivedPayments]
/* 
   --------------------------------------------------------------------------------- 
   This stored procedure is responsible for restoring ALL previously archived payments. 
   The following tables are included in the restore process: Chk, Hst, ExA, TxT, Vch,
   and WHVch. 
    
   Coding issues: none.
   ---------------------------------------------------------------------------------
*/
AS
BEGIN

/* 
   --------------------------------------------------------------------------------- 
    Delete any duplicate rows in the ArC table
   ---------------------------------------------------------------------------------
*/       

  declare @Count int, @CTpId smallint, @Id decimal(13,0), @ModVer tinyint 

  declare DeleteDupsArC cursor LOCAL READ_ONLY FAST_FORWARD for
  select CTpId, Id, count(RecordId)
  from ArC
  group by CTpId, Id
  having count(RecordId) > 1

  open DeleteDupsArC
  fetch DeleteDupsArC into @CTpId, @Id, @Count
  while @@fetch_status = 0
  begin
	  if @Count > 1
	  begin
		Set @Count = @Count - 1
		Set rowcount @Count
		Delete from ArC where CTpId = @CTpId and Id = @Id
	end
	Set rowcount 0
	fetch DeleteDupsArC into @CTpId, @Id, @Count
  End
  Close DeleteDupsArC
  Deallocate DeleteDupsArC

  set rowcount 0
    
  print 'Successfully completed the check for duplicates in the ArC table'

/* 
   --------------------------------------------------------------------------------- 
    Delete any duplicate rows in the ArH table
   ---------------------------------------------------------------------------------
*/       

  declare DeleteDupsArH cursor LOCAL READ_ONLY FAST_FORWARD for
  select CTpId, Id, ModVer, count(RecordId)
  from ArH
  group by CTpId, Id, ModVer
  having count(RecordId) > 1

  open DeleteDupsArH
  fetch DeleteDupsArH into @CTpId, @Id, @ModVer, @Count
  while @@fetch_status = 0
  begin
	  if @Count > 1
	  begin
		Set @Count = @Count - 1
		Set rowcount @Count
		Delete from ArH where CTpId = @CTpId and Id = @Id and ModVer = @ModVer
	end
	Set rowcount 0
	fetch DeleteDupsArH into @CTpId, @Id, @ModVer, @Count
  End
  Close DeleteDupsArH
  Deallocate DeleteDupsArH

  set rowcount 0
    
  print 'Successfully completed the check for duplicates in the ArH table'

/* 
   --------------------------------------------------------------------------------- 
    Delete any duplicate rows in the target Chk table
   ---------------------------------------------------------------------------------
*/       

  delete Chk
  from Chk c
  inner join ArC a on a.CTpId = c.CTpId and a.Id = c.Id
    
  print 'Successfully completed deleting duplicates in the Chk table'

/* 
   --------------------------------------------------------------------------------- 
    Delete any duplicate rows in the target Hst table, using the ArC table as the driver
   ---------------------------------------------------------------------------------
*/       

  delete Hst
  from Hst c
  inner join ArC a on a.CTpId = c.CTpId and a.Id = c.Id
    
  print 'Successfully completed deleting duplicates in the Hst table matching on the Chk table'

/* 
   --------------------------------------------------------------------------------- 
    Delete any duplicate rows in the target Hst table
   ---------------------------------------------------------------------------------
*/       

  delete Hst
  from Hst h
  inner join ArH a on a.CTpId = h.CTpId and a.Id = h.Id and a.ModVer = h.ModVer
    
  print 'Successfully completed the check for duplicates in the Hst table'

/* 
   --------------------------------------------------------------------------------- 
    Delete any duplicate rows in the target Vch table
   ---------------------------------------------------------------------------------
*/       

  delete Vch
  from Vch v
  inner join ArV a on a.CTpId = v.CTpId and a.ChkId = v.ChkId and a.SeqNum = v.SeqNum
    
  print 'Successfully completed the check for duplicates in the Vch table'

/* 
   --------------------------------------------------------------------------------- 
    Delete any duplicate rows in the target ExA table
   ---------------------------------------------------------------------------------
*/       

  delete ExA
  from ExA e
  inner join ArE a on a.CTpId = e.CTpId and a.ChkId = e.ChkId and a.ExpAcct = e.ExpAcct and a.CostCtr = e.CostCtr and a.SeqNum = e.SeqNum
    
  print 'Successfully completed the check for duplicates in the ExA table'

/* 
   --------------------------------------------------------------------------------- 
    Delete any duplicate rows in the target Txt table
   ---------------------------------------------------------------------------------
*/       

  delete Txt
  from Txt t
  inner join ArT a on a.CTpId = t.CTpId and a.ChkId = t.ChkId and a.SeqNum = t.SeqNum
    
  print 'Successfully completed the check for duplicates in the ExA table'
  
  declare @Cmd nvarchar(4000), @howmanyArH int, @claTranDt int, @claTranTm int, @ChkRecordId int
  
  set nocount on

  BEGIN TRAN

    set @claTranDt = convert(int,datediff(dd, '12/28/1800',getdate())) -- convert today's date to Clarion
    set @claTranTm = convert(int,substring(convert(varchar(20),getdate(),108),1,2) + substring(convert(varchar(20),getdate(),108),4,2)) * 3600 + 30000 -- add an additional 2 minutes
    
    
/* 
   --------------------------------------------------------------------------------- 
    Next, restore each Chk record from the ArC table.
   ---------------------------------------------------------------------------------
*/       

    insert into Chk (
      	CTpId,
      	Id,
      	OrigId,
      	IdPre,
      	ModVer,
      	ModCd,
      	CmpId,
      	PayToNam1,
      	PayToNam2,
      	PayToNam3,
      	IssDt,
      	PayAmt,
      	OrigPayAmt,
      	ResrvAmt,
      	BnkId,
      	BnkNum,
      	LosDt,
      	Dt1,
      	Dt2,
      	Dt3,
      	Dt4,
      	Dt5,
      	Time1,
      	Time2,
      	TranCd,
      	TaxId,
      	TaxTyp,
      	Tax1099,
      	RptAmt1099,
      	SpltPay1099,
      	VndTyp,
      	VndId,
      	AgentTyp,
      	AgentId,
      	MailToNam,
      	MailToAdr1,
      	MailToAdr2,
      	MailToAdr3,
      	MailToAdr4,
      	MailToAdr5,
      	City,
      	State,
      	CntyCd,
      	CountryId,
      	ZipCd,
      	BillState,
      	BillDt,
      	PhNum1,
      	PhNum2,
      	FaxNum,
      	FaxNumTyp,
      	FaxToNam,
      	EmailAdr,
      	MrgId,
      	MrgId2,
      	PayCd,
      	PayToCd,
      	ReqId,
      	ExamId,
      	ExamNam,
      	AdjId,
      	CurId,
      	Office,
      	DeptCd,
      	MailStop,
      	ReissCd,
      	AtchCd,
      	ReqNum,
      	ImpBch,
      	ImpBnkBch,
      	PrtBch,
      	RcnBch,
      	SavRcnBch,
      	ExpBch,
      	PdBch,
      	VoidExpCd,
      	PrevVoidExpCd,
      	WriteOffExpCd,
      	SrchLtrCd,
      	PrtCnt,
      	RcnCd,
      	VoidCd,
      	VoidId,
      	VoidDt,
      	UnVoidCd,
      	UnVoidId,
      	UnVoidDt,
      	SigCd,
      	SigCd1,
      	SigCd2,
      	DrftCd,
      	DscCd,
      	RestCd,
      	XCd1,
      	XCd2,
      	XCd3,
      	XCd4,
      	XCd5,
      	XCd6,
      	XCd7,
      	XCd8,
      	XCd9,
      	XCd10,
      	PayRate,
      	XRate1,
      	XRate2,
      	XRate3,
      	XAmt1,
      	XAmt2,
      	XAmt3,
      	XAmt4,
      	XAmt5,
      	XAmt6,
      	XAmt7,
      	XAmt8,
      	XAmt9,
      	XAmt10,
      	SalaryAmt,
      	MaritalStat,
      	FedExempt,
      	StateExempt,
      	Day30Cd,
      	PstCd,
      	RsnCd,
      	PdCd,
      	PdDt,
      	ApprovCd,
      	ApprovDt,
      	ApprovId,
      	ApprovCd2,
      	ApprovDt2,
      	ApprovId2,
      	ApprovCd3,
      	ApprovDt3,
      	ApprovId3,
      	ApprovCd4,
      	ApprovDt4,
      	ApprovId4,
    	ApprovCd5,
      	ApprovDt5,
      	ApprovId5,
      	ApprovCd6,
      	ApprovDt6,
      	ApprovId6,
      	ApprovCd7,
      	ApprovDt7,
      	ApprovId7,
      	ApprovCd8,
      	ApprovDt8,
      	ApprovId8,
      	ApprovCd9,
      	ApprovDt9,
      	ApprovId9,
      	AddDt,
      	AddTime,
      	AddId,
      	ChgDt,
      	ChgTime,
      	ChgId,
      	SrceCd,
      	FrmCd,
        RefNum,
      	NamTyp,
      	LstNam,
      	FstNam,
      	MidInit,
      	Salutation,
      	AcctNum,
      	ExpAcct,
      	DebitAcct,
      	BnkAcct,
      	BnkRout,
      	AcctNam,
      	EftTypCd,
 	    BnkAcct2,
      	BnkRout2,
      	AcctNam2,
      	EftTypCd2,
      	BnkAcct3,
      	BnkRout3,
      	AcctNam3,
      	EftTypCd3,
      	AllocPct1,
      	AllocPct2,
      	AllocPct3,
      	OptCd,
      	EftTranCd,
      	AdviceTyp,
      	RepRsn,
      	EmployerTyp,
      	EmployerId,
      	EmployerNam,
      	EmployerAdr1,
      	EmployerAdr2,
      	EmployerAdr3,
      	ProviderTyp,
      	ProviderId,
      	ProviderNam,
      	CarrierTyp,
      	CarrierId,
      	PolId,
      	InsNam,
      	InsAdr1,
      	InsAdr2,
      	InsAdr3,
      	ClaimNum,
      	ClmntNum,
      	ClmntNam,
      	ClmntAdr1,
      	ClmntAdr2,
      	ClmntAdr3,
      	LosCause,
      	DiagCd1,
      	DiagCd2,
      	DiagCd3,
      	DiagCd4,
      	ForRsn1,
      	ForRsn2,
      	ForRsn3,
      	CommentTxt,
      	XNum1,
      	XNum2,
      	XNum3,
      	XNum4,
      	TransferOutBch,
      	TransferInBch,
      	VchCnt,
      	PrtDt,
      	PrtId,
      	TranDt,
      	TranTime,
      	TranTyp,
      	TranId,
      	BTpId,
      	ExamTyp,
      	Priority,
      	DeliveryDt,
      	CardNum,
      	CardTyp,
      	ExportStat,
      	PrevExportStat,
      	NoBulk,
      	Typ1099,
      	TrmId,
      	AltId,
      	AltTyp,
      	AthOver,
      	AthId,
      	AthCd,
      	MicrofilmID,
      	BlockSeqNum,
      	PrtBchOFAC,
      	ExpBch2,
      	ExpBch3,
      	PrenoteCd,
      	SavPdBch,
      	ACHTraceNum,
      	EscheatExportStat,
      	PrevEscheatExportStat,
      	RcdLock,
      	Tax1099Cd,
      	ClmntTaxId,
      	ManSigCd
              )
    select
      	CTpId,
      	Id,
      	OrigId,
      	IdPre,
      	ModVer,
      	ModCd,
      	CmpId,
      	PayToNam1,
      	PayToNam2,
      	PayToNam3,
      	IssDt,
      	PayAmt,
      	OrigPayAmt,
      	ResrvAmt,
      	BnkId,
      	BnkNum,
      	LosDt,
      	Dt1,
      	Dt2,
      	Dt3,
      	Dt4,
      	Dt5,
      	Time1,
      	Time2,
      	TranCd,
      	TaxId,
      	TaxTyp,
      	Tax1099,
      	RptAmt1099,
      	SpltPay1099,
      	VndTyp,
      	VndId,
      	AgentTyp,
      	AgentId,
      	MailToNam,
      	MailToAdr1,
      	MailToAdr2,
      	MailToAdr3,
      	MailToAdr4,
      	MailToAdr5,
      	City,
      	State,
      	CntyCd,
      	CountryId,
      	ZipCd,
      	BillState,
      	BillDt,
      	PhNum1,
      	PhNum2,
      	FaxNum,
      	FaxNumTyp,
      	FaxToNam,
      	EmailAdr,
      	MrgId,
      	MrgId2,
      	PayCd,
      	PayToCd,
      	ReqId,
      	ExamId,
      	ExamNam,
      	AdjId,
      	CurId,
      	Office,
      	DeptCd,
      	MailStop,
      	ReissCd,
      	AtchCd,
      	ReqNum,
      	ImpBch,
      	ImpBnkBch,
      	PrtBch,
      	RcnBch,
      	SavRcnBch,
      	ExpBch,
      	PdBch,
      	VoidExpCd,
      	PrevVoidExpCd,
   	    WriteOffExpCd,
      	SrchLtrCd,
      	PrtCnt,
      	RcnCd,
      	VoidCd,
      	VoidId,
      	VoidDt,
      	UnVoidCd,
      	UnVoidId,
      	UnVoidDt,
      	SigCd,
      	SigCd1,
      	SigCd2,
      	DrftCd,
      	DscCd,
      	RestCd,
      	XCd1,
      	XCd2,
      	XCd3,
      	XCd4,
      	XCd5,
      	XCd6,
      	XCd7,
      	XCd8,
      	XCd9,
      	XCd10,
      	PayRate,
      	XRate1,
      	XRate2,
      	XRate3,
      	XAmt1,
      	XAmt2,
      	XAmt3,
      	XAmt4,
      	XAmt5,
      	XAmt6,
      	XAmt7,
      	XAmt8,
      	XAmt9,
      	XAmt10,
      	SalaryAmt,
      	MaritalStat,
      	FedExempt,
      	StateExempt,
      	Day30Cd,
      	PstCd,
      	RsnCd,
      	PdCd,
      	PdDt,
      	ApprovCd,
      	ApprovDt,
      	ApprovId,
      	ApprovCd2,
      	ApprovDt2,
      	ApprovId2,
      	ApprovCd3,
      	ApprovDt3,
      	ApprovId3,
      	ApprovCd4,
      	ApprovDt4,
      	ApprovId4,
      	ApprovCd5,
      	ApprovDt5,
      	ApprovId5,
      	ApprovCd6,
      	ApprovDt6,
      	ApprovId6,
      	ApprovCd7,
      	ApprovDt7,
      	ApprovId7,
      	ApprovCd8,
      	ApprovDt8,
      	ApprovId8,
      	ApprovCd9,
      	ApprovDt9,
      	ApprovId9,
   	    AddDt,
      	AddTime,
      	AddId,
      	ChgDt,
      	ChgTime,
      	ChgId,
      	SrceCd,
      	FrmCd,
      	RefNum,
      	NamTyp,
      	LstNam,
      	FstNam,
      	MidInit,
      	Salutation,
      	AcctNum,
      	ExpAcct,
      	DebitAcct,
      	BnkAcct,
      	BnkRout,
      	AcctNam,
      	EftTypCd,
      	BnkAcct2,
      	BnkRout2,
      	AcctNam2,
      	EftTypCd2,
      	BnkAcct3,
      	BnkRout3,
      	AcctNam3,
      	EftTypCd3,
      	AllocPct1,
      	AllocPct2,
      	AllocPct3,
      	OptCd,
      	EftTranCd,
      	AdviceTyp,
      	RepRsn,
      	EmployerTyp,
      	EmployerId,
      	EmployerNam,
      	EmployerAdr1,
      	EmployerAdr2,
      	EmployerAdr3,
      	ProviderTyp,
      	ProviderId,
      	ProviderNam,
      	CarrierTyp,
      	CarrierId,
      	PolId,
      	InsNam,
      	InsAdr1,
      	InsAdr2,
      	InsAdr3,
      	ClaimNum,
      	ClmntNum,
      	ClmntNam,
      	ClmntAdr1,
      	ClmntAdr2,
      	ClmntAdr3,
      	LosCause,
      	DiagCd1,
      	DiagCd2,
      	DiagCd3,
      	DiagCd4,
      	ForRsn1,
      	ForRsn2,
      	ForRsn3,
      	CommentTxt,
      	XNum1,
      	XNum2,
      	XNum3,
      	XNum4,
      	TransferOutBch,
      	TransferInBch,
      	VchCnt,
      	PrtDt,
      	PrtId,
        @claTranDt,	-- TranDt
      	@claTranTm,	-- TranTime
      	252,
      	TranId,
      	BTpId,
      	ExamTyp,
      	Priority,
      	DeliveryDt,
      	CardNum,
      	CardTyp,
      	ExportStat,
      	PrevExportStat,
      	NoBulk,
      	Typ1099,
      	TrmId,
      	AltId,
      	AltTyp,
      	AthOver,
      	AthId,
      	AthCd,
      	MicrofilmID,
      	BlockSeqNum,
      	PrtBchOFAC,
      	ExpBch2,
      	ExpBch3,
      	PrenoteCd,
      	SavPdBch,
      	ACHTraceNum,
      	EscheatExportStat,
      	PrevEscheatExportStat,
      	RcdLock,
      	Tax1099Cd,
      	ClmntTaxId,
      	ManSigCd
    from Arc

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (1a)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    
    print 'Successfully completed the ArC to Chk table restore'

/* 
   --------------------------------------------------------------------------------- 
    Next, restore each ChkStop record from the ArChkStop table.
   ---------------------------------------------------------------------------------
*/       
      
    insert into ChkStop (
	 RecordId,
  	 ConfirmId,
	 ConfirmCd,
   	 ProcessDt,
	 RequestBch,
   	 ConfirmBch,
     StatusCd
            )
    select
	 s.RecordId,
  	 s.ConfirmId,
	 s.ConfirmCd,
   	 s.ProcessDt,
	 s.RequestBch,
   	 s.ConfirmBch,
     s.StatusCd
    from ArChkStop s

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (1b)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    
    print 'Successfully completed the ArChkStop to ChkStop table restore'

/* 
   --------------------------------------------------------------------------------- 
    Next, restore each ChkReissue record from the ArChkReissue table.
   ---------------------------------------------------------------------------------
*/       

    insert into ChkReissue (
	 SourceRecordId,
  	 ReIssRecordId,
	 OrigRecordId
            )
    select
     r.SourceRecordId,
     r.ReIssRecordId,
     r.OrigRecordId
    from ArChkReissue r

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (1c)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

  COMMIT TRAN
    
  print 'Successfully completed the ArChkReissue to ChkReissue table restore'

  BEGIN TRAN
    
/* 
   --------------------------------------------------------------------------------- 
    Next, restore each Txt record from the ArT table.
   ---------------------------------------------------------------------------------
*/       
    INSERT INTO Txt
    SELECT t.* 
    FROM ArT t

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (2)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

  COMMIT TRAN
    
  print 'Successfully completed the ArT to Txt table restore'

  BEGIN TRAN

/*
   --------------------------------------------------------------------------------- 
    Restore each ExA record from the ArE table.
   ---------------------------------------------------------------------------------
*/

    INSERT INTO ExA (
      	CTpId,
      	ChkId,
      	ExpAcct,
      	CostCtr,
      	NetAmt,
      	DebitAmt,
      	CreditAmt,
      	ExpBch,
      	VoidCd,
      	Tax1099,
      	DescTxt,
      	DiagCd,
      	Typ,
      	XCd1,
      	XCd2,
      	XCd3,
      	XCd4,
      	XCd5,
      	XNum1,
      	XNum2,
      	XNum3,
      	XAmt1,
      	XAmt2,
      	XAmt3,
      	XDt1,
      	XDt2,
      	XDt3,
      	XDt4,
      	ExpBch2,
      	ExpBch3,
      	Accounting,
      	InvId
            )
    SELECT 
      	e.CTpId,
      	e.ChkId,
      	e.ExpAcct,
    	e.CostCtr,
        e.NetAmt,
      	e.DebitAmt,
      	e.CreditAmt,
      	e.ExpBch,
      	e.VoidCd,
      	e.Tax1099,
      	e.DescTxt,
      	e.DiagCd,
      	e.Typ,
      	e.XCd1,
      	e.XCd2,
      	e.XCd3,
      	e.XCd4,
      	e.XCd5,
      	e.XNum1,
      	e.XNum2,
      	e.XNum3,
      	e.XAmt1,
      	e.XAmt2,
      	e.XAmt3,
      	e.XDt1,
      	e.XDt2,
      	e.XDt3,
      	e.XDt4,
      	e.ExpBch2,
      	e.ExpBch3,
      	e.Accounting,
      	e.InvId    
    FROM ArE e

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (3)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

  COMMIT TRAN
    
  print 'Successfully completed the ArE to ExA table restore'

  BEGIN TRAN

    delete Hst
    from Hst h
    inner join ArH a on a.CTpId = h.CTpId and a.Id = h.Id and a.ModVer = h.ModVer

  COMMIT TRAN

  BEGIN TRAN

/* 
   --------------------------------------------------------------------------------- 
    Restore each Hst record from the ArH table.
   ---------------------------------------------------------------------------------
*/       

    INSERT INTO Hst (
       	 CTpId,
       	 Id,
       	 OrigId,
       	 IdPre,
       	 ModVer,
       	 ModCd,
       	 CmpId,
       	 PayToNam1,
       	 PayToNam2,
       	 PayToNam3,
       	 IssDt,
       	 PayAmt,
       	 OrigPayAmt,
       	 ResrvAmt,
       	 BnkId,
       	 BnkNum,
       	 LosDt,
       	 Dt1,
       	 Dt2,
       	 Dt3,
       	 Dt4,
       	 Dt5,
       	 Time1,
       	 Time2,
       	 TranCd,
       	 TaxId,
       	 TaxTyp,
       	 Tax1099,
       	 RptAmt1099,
       	 SpltPay1099,
       	 VndTyp,
       	 VndId,
       	 AgentTyp,
       	 AgentId,
       	 MailToNam,
       	 MailToAdr1,
       	 MailToAdr2,
       	 MailToAdr3,
       	 MailToAdr4,
       	 MailToAdr5,
       	 City,
       	 State,
       	 CntyCd,
       	 CountryId,
       	 ZipCd,
       	 BillState,
       	 BillDt,
       	 PhNum1,
       	 PhNum2,
       	 FaxNum,
       	 FaxNumTyp,
       	 FaxToNam,
       	 EmailAdr,
       	 MrgId,
       	 MrgId2,
       	 PayCd,
       	 PayToCd,
       	 ReqId,
       	 ExamId,
       	 ExamNam,
       	 AdjId,
       	 CurId,
       	 Office,
       	 DeptCd,
       	 MailStop,
       	 ReissCd,
       	 AtchCd,
       	 ReqNum,
       	 ImpBch,
       	 ImpBnkBch,
       	 PrtBch,
       	 RcnBch,
       	 SavRcnBch,
       	 ExpBch,
       	 PdBch,
       	 VoidExpCd,
       	 PrevVoidExpCd,
       	 WriteOffExpCd,
       	 SrchLtrCd,
       	 PrtCnt,
       	 RcnCd,
       	 VoidCd,
       	 VoidId,
       	 VoidDt,
       	 UnVoidCd,
       	 UnVoidId,
       	 UnVoidDt,
       	 SigCd,
       	 SigCd1,
       	 SigCd2,
       	 DrftCd,
       	 DscCd,
       	 RestCd,
       	 XCd1,
       	 XCd2,
       	 XCd3,
       	 XCd4,
       	 XCd5,
       	 XCd6,
       	 XCd7,
       	 XCd8,
       	 XCd9,
       	 XCd10,
       	 PayRate,
       	 XRate1,
       	 XRate2,
       	 XRate3,
       	 XAmt1,
       	 XAmt2,
       	 XAmt3,
       	 XAmt4,
       	 XAmt5,
       	 XAmt6,
       	 XAmt7,
       	 XAmt8,
       	 XAmt9,
       	 XAmt10,
       	 SalaryAmt,
       	 MaritalStat,
       	 FedExempt,
       	 StateExempt,
       	 Day30Cd,
       	 PstCd,
       	 RsnCd,
       	 PdCd,
       	 PdDt,
       	 ApprovCd,
       	 ApprovDt,
       	 ApprovId,
       	 ApprovCd2,
       	 ApprovDt2,
       	 ApprovId2,
       	 ApprovCd3,
       	 ApprovDt3,
       	 ApprovId3,
       	 ApprovCd4,
       	 ApprovDt4,
       	 ApprovId4,
       	 ApprovCd5,
       	 ApprovDt5,
       	 ApprovId5,
     	 ApprovCd6,
       	 ApprovDt6,
       	 ApprovId6,
       	 ApprovCd7,
       	 ApprovDt7,
       	 ApprovId7,
       	 ApprovCd8,
       	 ApprovDt8,
       	 ApprovId8,
       	 ApprovCd9,
       	 ApprovDt9,
       	 ApprovId9,
       	 AddDt,
       	 AddTime,
       	 AddId,
       	 ChgDt,
       	 ChgTime,
       	 ChgId,
       	 SrceCd,
       	 FrmCd,
       	 RefNum,
     	 NamTyp,
       	 LstNam,
       	 FstNam,
       	 MidInit,
       	 Salutation,
       	 AcctNum,
       	 ExpAcct,
       	 DebitAcct,
       	 BnkAcct,
       	 BnkRout,
       	 AcctNam,
       	 EftTypCd,
       	 BnkAcct2,
       	 BnkRout2,
       	 AcctNam2,
       	 EftTypCd2,
       	 BnkAcct3,
       	 BnkRout3,
       	 AcctNam3,
       	 EftTypCd3,
       	 AllocPct1,
       	 AllocPct2,
       	 AllocPct3,
       	 OptCd,
       	 EftTranCd,
       	 AdviceTyp,
       	 RepRsn,
       	 EmployerTyp,
       	 EmployerId,
       	 EmployerNam,
       	 EmployerAdr1,
       	 EmployerAdr2,
       	 EmployerAdr3,
       	 ProviderTyp,
       	 ProviderId,
       	 ProviderNam,
       	 CarrierTyp,
       	 CarrierId,
       	 PolId,
 	     InsNam,
       	 InsAdr1,
       	 InsAdr2,
       	 InsAdr3,
       	 ClaimNum,
       	 ClmntNum,
       	 ClmntNam,
       	 ClmntAdr1,
       	 ClmntAdr2,
       	 ClmntAdr3,
       	 LosCause,
       	 DiagCd1,
       	 DiagCd2,
       	 DiagCd3,
       	 DiagCd4,
       	 ForRsn1,
       	 ForRsn2,
       	 ForRsn3,
       	 CommentTxt,
       	 XNum1,
       	 XNum2,
       	 XNum3,
       	 XNum4,
       	 TransferOutBch,
       	 TransferInBch,
       	 VchCnt,
       	 PrtDt,
       	 PrtId,
       	 TranDt,
       	 TranTime,
       	 TranTyp,
       	 TranId,
       	 BTpId,
       	 ExamTyp,
       	 Priority,
       	 DeliveryDt,
       	 CardNum,
       	 CardTyp,
       	 ExportStat,
       	 PrevExportStat,
       	 NoBulk,
       	 Typ1099,
       	 TrmId,
       	 AltId,
       	 AltTyp,
       	 AthOver,
       	 AthId,
       	 AthCd,
       	 MicrofilmID,
       	 BlockSeqNum,
       	 PrtBchOFAC,
       	 ExpBch2,
       	 ExpBch3,
       	 PrenoteCd,
       	 SavPdBch,
       	 ACHTraceNum,
       	 EscheatExportStat,
       	 PrevEscheatExportStat,
       	 RcdLock,
       	 Tax1099Cd,
       	 ClmntTaxId,
       	 ManSigCd,
         ChkRecordId 	
         	)	
     SELECT  
     	 CTpId,
       	 Id,
       	 OrigId,
       	 IdPre,
       	 ModVer,
       	 ModCd,
       	 CmpId,
       	 PayToNam1,
       	 PayToNam2,
       	 PayToNam3,
       	 IssDt,
       	 PayAmt,
       	 OrigPayAmt,
       	 ResrvAmt,
       	 BnkId,
       	 BnkNum,
       	 LosDt,
       	 Dt1,
       	 Dt2,
       	 Dt3,
       	 Dt4,
       	 Dt5,
       	 Time1,
       	 Time2,
       	 TranCd,
       	 TaxId,
       	 TaxTyp,
       	 Tax1099,
       	 RptAmt1099,
       	 SpltPay1099,
       	 VndTyp,
       	 VndId,
       	 AgentTyp,
       	 AgentId,
       	 MailToNam,
       	 MailToAdr1,
       	 MailToAdr2,
       	 MailToAdr3,
       	 MailToAdr4,
       	 MailToAdr5,
       	 City,
       	 State,
       	 CntyCd,
       	 CountryId,
       	 ZipCd,
       	 BillState,
       	 BillDt,
       	 PhNum1,
       	 PhNum2,
       	 FaxNum,
       	 FaxNumTyp,
       	 FaxToNam,
       	 EmailAdr,
       	 MrgId,
       	 MrgId2,
       	 PayCd,
       	 PayToCd,
       	 ReqId,
       	 ExamId,
       	 ExamNam,
       	 AdjId,
       	 CurId,
       	 Office,
       	 DeptCd,
       	 MailStop,
       	 ReissCd,
       	 AtchCd,
       	 ReqNum,
       	 ImpBch,
       	 ImpBnkBch,
       	 PrtBch,
       	 RcnBch,
       	 SavRcnBch,
       	 ExpBch,
       	 PdBch,
       	 VoidExpCd,
       	 PrevVoidExpCd,
       	 WriteOffExpCd,
       	 SrchLtrCd,
       	 PrtCnt,
       	 RcnCd,
       	 VoidCd,
       	 VoidId,
       	 VoidDt,
       	 UnVoidCd,
       	 UnVoidId,
       	 UnVoidDt,
       	 SigCd,
       	 SigCd1,
       	 SigCd2,
       	 DrftCd,
   	     DscCd,
       	 RestCd,
       	 XCd1,
       	 XCd2,
       	 XCd3,
       	 XCd4,
       	 XCd5,
       	 XCd6,
       	 XCd7,
       	 XCd8,
       	 XCd9,
       	 XCd10,
       	 PayRate,
       	 XRate1,
       	 XRate2,
       	 XRate3,
       	 XAmt1,
       	 XAmt2,
       	 XAmt3,
       	 XAmt4,
       	 XAmt5,
       	 XAmt6,
       	 XAmt7,
       	 XAmt8,
       	 XAmt9,
       	 XAmt10,
       	 SalaryAmt,
       	 MaritalStat,
       	 FedExempt,
       	 StateExempt,
       	 Day30Cd,
       	 PstCd,
       	 RsnCd,
       	 PdCd,
       	 PdDt,
       	 ApprovCd,
       	 ApprovDt,
       	 ApprovId,
       	 ApprovCd2,
       	 ApprovDt2,
       	 ApprovId2,
       	 ApprovCd3,
       	 ApprovDt3,
       	 ApprovId3,
       	 ApprovCd4,
       	 ApprovDt4,
       	 ApprovId4,
       	 ApprovCd5,
       	 ApprovDt5,
       	 ApprovId5,
       	 ApprovCd6,
       	 ApprovDt6,
       	 ApprovId6,
	     ApprovCd7,
       	 ApprovDt7,
       	 ApprovId7,
       	 ApprovCd8,
       	 ApprovDt8,
     	 ApprovId8,
       	 ApprovCd9,
       	 ApprovDt9,
       	 ApprovId9,
       	 AddDt,
       	 AddTime,
       	 AddId,
       	 ChgDt,
       	 ChgTime,
       	 ChgId,
       	 SrceCd,
       	 FrmCd,
       	 RefNum,
       	 NamTyp,
       	 LstNam,
       	 FstNam,
       	 MidInit,
       	 Salutation,
       	 AcctNum,
       	 ExpAcct,
       	 DebitAcct,
       	 BnkAcct,
       	 BnkRout,
       	 AcctNam,
       	 EftTypCd,
       	 BnkAcct2,
       	 BnkRout2,
       	 AcctNam2,
       	 EftTypCd2,
       	 BnkAcct3,
       	 BnkRout3,
       	 AcctNam3,
       	 EftTypCd3,
       	 AllocPct1,
       	 AllocPct2,
       	 AllocPct3,
       	 OptCd,
       	 EftTranCd,
       	 AdviceTyp,
       	 RepRsn,
       	 EmployerTyp,
       	 EmployerId,
       	 EmployerNam,
       	 EmployerAdr1,
       	 EmployerAdr2,
       	 EmployerAdr3,
       	 ProviderTyp,
       	 ProviderId,
       	 ProviderNam,
       	 CarrierTyp,
       	 CarrierId,
       	 PolId,
       	 InsNam,
       	 InsAdr1,
       	 InsAdr2,
       	 InsAdr3,
       	 ClaimNum,
       	 ClmntNum,
       	 ClmntNam,
       	 ClmntAdr1,
       	 ClmntAdr2,
       	 ClmntAdr3,
       	 LosCause,
       	 DiagCd1,
       	 DiagCd2,
       	 DiagCd3,
       	 DiagCd4,
       	 ForRsn1,
       	 ForRsn2,
       	 ForRsn3,
       	 CommentTxt,
       	 XNum1,
       	 XNum2,
       	 XNum3,
       	 XNum4,
       	 TransferOutBch,
       	 TransferInBch,
       	 VchCnt,
       	 PrtDt,
       	 PrtId,
       	 TranDt,
       	 TranTime,
       	 TranTyp,
       	 TranId,
       	 BTpId,
       	 ExamTyp,
       	 Priority,
       	 DeliveryDt,
       	 CardNum,
       	 CardTyp,
       	 ExportStat,
       	 PrevExportStat,
       	 NoBulk,
       	 Typ1099,
       	 TrmId,
       	 AltId,
       	 AltTyp,
       	 AthOver,
       	 AthId,
       	 AthCd,
       	 MicrofilmID,
       	 BlockSeqNum,
       	 PrtBchOFAC,
       	 ExpBch2,
       	 ExpBch3,
       	 PrenoteCd,
       	 SavPdBch,
       	 ACHTraceNum,
       	 EscheatExportStat,
       	 PrevEscheatExportStat,
       	 RcdLock,
       	 Tax1099Cd,
       	 ClmntTaxId,
       	 ManSigCd,
         NULL
    FROM ArH

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (4)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

  COMMIT TRAN
    
  print 'Successfully completed the ArH to Hst table restore'

  BEGIN TRAN

    update h
    set h.ChkRecordId = c.RecordId
    from Hst h
    inner join Chk c on c.CTpId = h.CTpId and c.Id = h.Id
    where h.ChkRecordId is NULL
    
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (4a)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

  COMMIT TRAN

  BEGIN TRAN

/* 
   --------------------------------------------------------------------------------- 
    Restore each Vch record from the ArV table.
   ---------------------------------------------------------------------------------
*/       

    INSERT INTO Vch (
     CTpId,
     ChkId,
     SeqNum,
     DescTxt,
     VchId,
     InvId,
     CshAcct,
     ExpAcct,
     CostCtr,
     InsNam,
     ClmntNam,
     ClmntNum,
     ClaimNum,
     TranCd,
     PolId,
     InvDt,
     InvAmt,
     AmtPd,
     DiscAmt,
     NetAmt,
     ExpBch,
     DiagCd,
     RsnCd,
     Amt1,
     Amt2,
     Dt1,
     Dt2,
     Dt3,
     Dt4,
     Qty1,
     Qty2,
     Qty3,
     PayRate,
     XRate1,
     XRate2,
     XRate3,
     XRate4,
     XRate5,
     Time,
     Tax1099,
     XCd1,
     XCd2,
     XCd3,
     XCd4,
     XCd5,
     XCd6,
     XCd7,
     XCd8,
     XCd9,
     XCd10,
     TaxId,
     TaxTyp,
     Amt3,
     Amt4,
     Amt5,
     Dt5,
     Tax1099Cd,
     Typ1099
         )
    SELECT 
      v.CTpId,
      v.ChkId,
      v.SeqNum,
      v.DescTxt,
      v.VchId,
      v.InvId,
      v.CshAcct,
      v.ExpAcct,
      v.CostCtr,
      v.InsNam,
      v.ClmntNam,
      v.ClmntNum,
      v.ClaimNum,
      v.TranCd,
      v.PolId,
      v.InvDt,
      v.InvAmt,
      v.AmtPd,
      v.DiscAmt,
      v.NetAmt,
      v.ExpBch,
      v.DiagCd,
      v.RsnCd,
      v.Amt1,
      v.Amt2,
      v.Dt1,
      v.Dt2,
      v.Dt3,
      v.Dt4,
      v.Qty1,
      v.Qty2,
      v.Qty3,
      v.PayRate,
      v.XRate1,
      v.XRate2,
      v.XRate3,
      v.XRate4,
      v.XRate5,
      v.Time,
      v.Tax1099,
      v.XCd1,
      v.XCd2,
      v.XCd3,
      v.XCd4,
      v.XCd5,
      v.XCd6,
      v.XCd7,
      v.XCd8,
      v.XCd9,
      v.XCd10,
      v.TaxId,
      v.TaxTyp,
      v.Amt3,
      v.Amt4,
      v.Amt5,
      v.Dt5,
      v.Tax1099Cd,
      v.Typ1099
    FROM ArV v
    inner join Arc c on c.CTpId = v.CTpId AND c.Id = v.ChkId

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (5)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

  COMMIT TRAN
    
  print 'Successfully completed the ArV to Vch table restore'

  BEGIN TRAN

    INSERT INTO WHApplied (
      HstRecordId,
      ExportBch1,
      ExportBch2
    	)
    SELECT
      HstRecordId,
      ExportBch1,
      ExportBch2
    FROM ArWHApplied

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed Process failed...unable to restore WHApplied records'
        ROLLBACK TRAN
        RETURN(1)  -- Return a non-zero status to the calling process to indicate failure 
    END

  COMMIT TRAN
    
  print 'Successfully completed the ArWHApplied to WHApplied table restore'

  BEGIN TRAN

    INSERT INTO WHVch (
	  VchId,
	  WHTypId,
	  WHAmt	
    	)
    SELECT
	  VchId,
	  WHTypId,
	  WHAmt	
    FROM ArWHVch

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (6)'
        ROLLBACK TRAN
        RETURN(1)  -- Return a non-zero status to the calling process to indicate failure 
    END

  COMMIT TRAN
    
  print 'Successfully completed the ArChkReissue to ChkReissue table restore'

/*
   --------------------------------------------------------------------------------- 
    delete ALL archived payment tables.
   ---------------------------------------------------------------------------------
*/

  delete ArChkStop

  delete ArChkReissue
 
  delete ArH

  delete ArWHVch

  delete ArWHApplied

  delete ArV

  delete ArT

  delete ArE

  delete ArC

  set nocount off
    
  RETURN /* Return with a zero status to indicate a successful process */

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[spRestoreSelectedArchivedPayments]'
GO
ALTER PROCEDURE [dbo].[spRestoreSelectedArchivedPayments]
(
@ParmRecordId int
)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible for restoring previously archived payments. 
    The following tables are included in the restore process: Chk, Hst, ExA, TxT, Vch,
    and WHVch. 
    
    The calling application has the responsibility of passing the RecordId to this 
    procedure. The application will pass 1 RecordId for each call to this procedure.
    The RecordIds are stored in a Clarion queue, for a selected group of payments that
    will be restored.
    
    Coding issues: none.
   ---------------------------------------------------------------------------------
*/
AS
BEGIN

  declare @HstRecordId int, @HstCTpId smallint, @HstId decimal, @HstModVer tinyint
  declare @Cmd nvarchar(4000), @claTranDt int, @claTranTm int, @ChkRecordId int

  set nocount on

  BEGIN TRAN

    set @claTranDt = convert(int,datediff(dd, '12/28/1800',getdate())) -- convert today's date to Clarion
    set @claTranTm = convert(int,substring(convert(varchar(20),getdate(),108),1,2) + substring(convert(varchar(20),getdate(),108),4,2)) * 3600 + 30000 -- add an additional 2 minutes

/* 
   --------------------------------------------------------------------------------- 
    First, restore each Chk record from the ArC table.
   ---------------------------------------------------------------------------------
*/       

    insert into Chk (
      	CTpId,
      	Id,
      	OrigId,
      	IdPre,
      	ModVer,
      	ModCd,
      	CmpId,
      	PayToNam1,
      	PayToNam2,
      	PayToNam3,
      	IssDt,
      	PayAmt,
      	OrigPayAmt,
      	ResrvAmt,
      	BnkId,
      	BnkNum,
      	LosDt,
      	Dt1,
      	Dt2,
      	Dt3,
      	Dt4,
      	Dt5,
      	Time1,
      	Time2,
      	TranCd,
      	TaxId,
      	TaxTyp,
      	Tax1099,
      	RptAmt1099,
      	SpltPay1099,
      	VndTyp,
      	VndId,
      	AgentTyp,
      	AgentId,
      	MailToNam,
      	MailToAdr1,
      	MailToAdr2,
      	MailToAdr3,
      	MailToAdr4,
      	MailToAdr5,
      	City,
      	State,
      	CntyCd,
      	CountryId,
      	ZipCd,
      	BillState,
      	BillDt,
      	PhNum1,
      	PhNum2,
      	FaxNum,
      	FaxNumTyp,
      	FaxToNam,
      	EmailAdr,
      	MrgId,
      	MrgId2,
      	PayCd,
      	PayToCd,
      	ReqId,
      	ExamId,
      	ExamNam,
      	AdjId,
      	CurId,
      	Office,
      	DeptCd,
      	MailStop,
      	ReissCd,
      	AtchCd,
      	ReqNum,
      	ImpBch,
      	ImpBnkBch,
      	PrtBch,
      	RcnBch,
      	SavRcnBch,
      	ExpBch,
      	PdBch,
      	VoidExpCd,
      	PrevVoidExpCd,
      	WriteOffExpCd,
      	SrchLtrCd,
      	PrtCnt,
      	RcnCd,
      	VoidCd,
      	VoidId,
      	VoidDt,
      	UnVoidCd,
      	UnVoidId,
      	UnVoidDt,
      	SigCd,
      	SigCd1,
      	SigCd2,
      	DrftCd,
      	DscCd,
      	RestCd,
      	XCd1,
      	XCd2,
      	XCd3,
      	XCd4,
      	XCd5,
      	XCd6,
      	XCd7,
      	XCd8,
      	XCd9,
      	XCd10,
      	PayRate,
      	XRate1,
      	XRate2,
      	XRate3,
      	XAmt1,
      	XAmt2,
      	XAmt3,
      	XAmt4,
      	XAmt5,
      	XAmt6,
      	XAmt7,
      	XAmt8,
      	XAmt9,
      	XAmt10,
      	SalaryAmt,
      	MaritalStat,
      	FedExempt,
      	StateExempt,
      	Day30Cd,
      	PstCd,
      	RsnCd,
      	PdCd,
      	PdDt,
      	ApprovCd,
      	ApprovDt,
      	ApprovId,
      	ApprovCd2,
      	ApprovDt2,
      	ApprovId2,
      	ApprovCd3,
      	ApprovDt3,
      	ApprovId3,
      	ApprovCd4,
      	ApprovDt4,
      	ApprovId4,
      	ApprovCd5,
      	ApprovDt5,
      	ApprovId5,
      	ApprovCd6,
      	ApprovDt6,
      	ApprovId6,
      	ApprovCd7,
      	ApprovDt7,
      	ApprovId7,
      	ApprovCd8,
      	ApprovDt8,
      	ApprovId8,
      	ApprovCd9,
      	ApprovDt9,
      	ApprovId9,
      	AddDt,
      	AddTime,
      	AddId,
      	ChgDt,
      	ChgTime,
      	ChgId,
      	SrceCd,
      	FrmCd,
      	RefNum,
      	NamTyp,
      	LstNam,
      	FstNam,
      	MidInit,
      	Salutation,
      	AcctNum,
      	ExpAcct,
      	DebitAcct,
      	BnkAcct,
      	BnkRout,
      	AcctNam,
      	EftTypCd,
      	BnkAcct2,
      	BnkRout2,
      	AcctNam2,
      	EftTypCd2,
      	BnkAcct3,
      	BnkRout3,
      	AcctNam3,
      	EftTypCd3,
        AllocPct1,
      	AllocPct2,
      	AllocPct3,
      	OptCd,
      	EftTranCd,
      	AdviceTyp,
      	RepRsn,
      	EmployerTyp,
      	EmployerId,
      	EmployerNam,
      	EmployerAdr1,
      	EmployerAdr2,
      	EmployerAdr3,
      	ProviderTyp,
      	ProviderId,
      	ProviderNam,
      	CarrierTyp,
      	CarrierId,
      	PolId,
      	InsNam,
      	InsAdr1,
      	InsAdr2,
      	InsAdr3,
      	ClaimNum,
      	ClmntNum,
      	ClmntNam,
      	ClmntAdr1,
      	ClmntAdr2,
      	ClmntAdr3,
      	LosCause,
      	DiagCd1,
      	DiagCd2,
      	DiagCd3,
      	DiagCd4,
      	ForRsn1,
      	ForRsn2,
      	ForRsn3,
      	CommentTxt,
      	XNum1,
      	XNum2,
      	XNum3,
      	XNum4,
      	TransferOutBch,
      	TransferInBch,
      	VchCnt,
      	PrtDt,
      	PrtId,
      	TranDt,
      	TranTime,
      	TranTyp,
      	TranId,
      	BTpId,
      	ExamTyp,
      	Priority,
      	DeliveryDt,
      	CardNum,
      	CardTyp,
      	ExportStat,
      	PrevExportStat,
      	NoBulk,
      	Typ1099,
      	TrmId,
      	AltId,
      	AltTyp,
      	AthOver,
      	AthId,
      	AthCd,
      	MicrofilmID,
      	BlockSeqNum,
      	PrtBchOFAC,
      	ExpBch2,
      	ExpBch3,
      	PrenoteCd,
      	SavPdBch,
      	ACHTraceNum,
      	EscheatExportStat,
      	PrevEscheatExportStat,
      	RcdLock,
      	Tax1099Cd,
      	ClmntTaxId,
      	ManSigCd
              )
    select
      	CTpId,
      	Id,
      	OrigId,
      	IdPre,
      	ModVer,
      	ModCd,
      	CmpId,
      	PayToNam1,
      	PayToNam2,
      	PayToNam3,
      	IssDt,
      	PayAmt,
      	OrigPayAmt,
      	ResrvAmt,
      	BnkId,
      	BnkNum,
      	LosDt,
      	Dt1,
      	Dt2,
      	Dt3,
      	Dt4,
      	Dt5,
      	Time1,
      	Time2,
      	TranCd,
      	TaxId,
      	TaxTyp,
      	Tax1099,
      	RptAmt1099,
      	SpltPay1099,
      	VndTyp,
      	VndId,
      	AgentTyp,
      	AgentId,
      	MailToNam,
      	MailToAdr1,
      	MailToAdr2,
      	MailToAdr3,
      	MailToAdr4,
      	MailToAdr5,
      	City,
      	State,
      	CntyCd,
      	CountryId,
      	ZipCd,
      	BillState,
      	BillDt,
      	PhNum1,
      	PhNum2,
      	FaxNum,
      	FaxNumTyp,
      	FaxToNam,
      	EmailAdr,
      	MrgId,
      	MrgId2,
      	PayCd,
      	PayToCd,
      	ReqId,
      	ExamId,
      	ExamNam,
      	AdjId,
      	CurId,
      	Office,
      	DeptCd,
      	MailStop,
      	ReissCd,
      	AtchCd,
      	ReqNum,
      	ImpBch,
      	ImpBnkBch,
      	PrtBch,
      	RcnBch,
      	SavRcnBch,
      	ExpBch,
      	PdBch,
      	VoidExpCd,
      	PrevVoidExpCd,
      	WriteOffExpCd,
      	SrchLtrCd,
      	PrtCnt,
      	RcnCd,
      	VoidCd,
      	VoidId,
      	VoidDt,
      	UnVoidCd,
      	UnVoidId,
      	UnVoidDt,
      	SigCd,
      	SigCd1,
      	SigCd2,
      	DrftCd,
      	DscCd,
      	RestCd,
      	XCd1,
      	XCd2,
      	XCd3,
      	XCd4,
      	XCd5,
      	XCd6,
      	XCd7,
      	XCd8,
      	XCd9,
      	XCd10,
      	PayRate,
      	XRate1,
      	XRate2,
      	XRate3,
      	XAmt1,
      	XAmt2,
      	XAmt3,
      	XAmt4,
      	XAmt5,
      	XAmt6,
      	XAmt7,
      	XAmt8,
      	XAmt9,
      	XAmt10,
      	SalaryAmt,
      	MaritalStat,
      	FedExempt,
      	StateExempt,
      	Day30Cd,
      	PstCd,
      	RsnCd,
      	PdCd,
      	PdDt,
      	ApprovCd,
      	ApprovDt,
      	ApprovId,
      	ApprovCd2,
      	ApprovDt2,
      	ApprovId2,
      	ApprovCd3,
      	ApprovDt3,
      	ApprovId3,
      	ApprovCd4,
      	ApprovDt4,
      	ApprovId4,
      	ApprovCd5,
      	ApprovDt5,
      	ApprovId5,
      	ApprovCd6,
      	ApprovDt6,
      	ApprovId6,
      	ApprovCd7,
      	ApprovDt7,
      	ApprovId7,
      	ApprovCd8,
      	ApprovDt8,
      	ApprovId8,
      	ApprovCd9,
      	ApprovDt9,
      	ApprovId9,
      	AddDt,
      	AddTime,
      	AddId,
      	ChgDt,
      	ChgTime,
      	ChgId,
      	SrceCd,
      	FrmCd,
      	RefNum,
      	NamTyp,
      	LstNam,
      	FstNam,
      	MidInit,
      	Salutation,
      	AcctNum,
      	ExpAcct,
      	DebitAcct,
      	BnkAcct,
      	BnkRout,
      	AcctNam,
      	EftTypCd,
      	BnkAcct2,
      	BnkRout2,
      	AcctNam2,
      	EftTypCd2,
      	BnkAcct3,
      	BnkRout3,
      	AcctNam3,
      	EftTypCd3,
      	AllocPct1,
      	AllocPct2,
      	AllocPct3,
      	OptCd,
      	EftTranCd,
      	AdviceTyp,
      	RepRsn,
      	EmployerTyp,
      	EmployerId,
      	EmployerNam,
      	EmployerAdr1,
      	EmployerAdr2,
      	EmployerAdr3,
      	ProviderTyp,
      	ProviderId,
      	ProviderNam,
      	CarrierTyp,
      	CarrierId,
      	PolId,
      	InsNam,
      	InsAdr1,
      	InsAdr2,
      	InsAdr3,
      	ClaimNum,
      	ClmntNum,
      	ClmntNam,
      	ClmntAdr1,
      	ClmntAdr2,
      	ClmntAdr3,
      	LosCause,
      	DiagCd1,
      	DiagCd2,
      	DiagCd3,
      	DiagCd4,
      	ForRsn1,
      	ForRsn2,
      	ForRsn3,
      	CommentTxt,
      	XNum1,
      	XNum2,
      	XNum3,
      	XNum4,
      	TransferOutBch,
      	TransferInBch,
      	VchCnt,
      	PrtDt,
      	PrtId,
      	TranDt,
      	TranTime,
      	TranTyp,
      	TranId,
      	BTpId,
      	ExamTyp,
      	Priority,
      	DeliveryDt,
      	CardNum,
      	CardTyp,
      	ExportStat,
      	PrevExportStat,
      	NoBulk,
      	Typ1099,
      	TrmId,
      	AltId,
      	AltTyp,
      	AthOver,
      	AthId,
      	AthCd,
      	MicrofilmID,
      	BlockSeqNum,
      	PrtBchOFAC,
      	ExpBch2,
      	ExpBch3,
      	PrenoteCd,
      	SavPdBch,
      	ACHTraceNum,
      	EscheatExportStat,
      	PrevEscheatExportStat,
      	RcdLock,
      	Tax1099Cd,
      	ClmntTaxId,
      	ManSigCd
    from Arc
    where RecordId = @ParmRecordId

    if @@error <> 0
    begin
      --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (1)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    end

/* 
   --------------------------------------------------------------------------------- 
    Next, restore each ChkStop record from the ArChkStop table.
   ---------------------------------------------------------------------------------
*/       

    insert into ChkStop (
	     RecordId,
    	 ConfirmId,
	     ConfirmCd,
    	 ProcessDt,
	     RequestBch,
    	 ConfirmBch
            )
    select
	     RecordId,
    	 ConfirmId,
	     ConfirmCd,
    	 ProcessDt,
	     RequestBch,
    	 ConfirmBch
    from ArChkStop
    where RecordId = @ParmRecordId     

    IF (@@error!=0)
    BEGIN
      --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (1a)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
   
    delete ArChkStop
    from ArChkStop
    where RecordId = @ParmRecordId     

/* 
   --------------------------------------------------------------------------------- 
    Next, restore each ChkReissue record from the ArChkReissue table.
   ---------------------------------------------------------------------------------
*/       
     
    insert into ChkReissue (
	 SourceRecordId,
  	 ReIssRecordId,
	 OrigRecordId
            )
    select
	SourceRecordId,
	ReIssRecordId,
	OrigRecordId
    from ArChkReissue
    where ReIssRecordId = @ParmRecordId

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (1d)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
      
    delete ArChkReissue
    from ArChkReissue
    where ReIssRecordId = @ParmRecordId

/* 
   --------------------------------------------------------------------------------- 
    Next, restore each Txt record from the ArT table.
   ---------------------------------------------------------------------------------
*/       
    INSERT INTO Txt
    SELECT t.* 
    FROM ArT t
    inner join Arc c on t.CTpId = c.CTpId and t.ChkId = c.Id
     where c.RecordId = @ParmRecordId

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (2)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
/*
   --------------------------------------------------------------------------------- 
    Restore each ExA record from the ArE table.
   ---------------------------------------------------------------------------------
*/
    INSERT INTO ExA (
      	CTpId,
      	ChkId,
      	ExpAcct,
      	CostCtr,
      	NetAmt,
      	DebitAmt,
      	CreditAmt,
      	ExpBch,
      	VoidCd,
      	Tax1099,
      	DescTxt,
      	DiagCd,
      	Typ,
      	XCd1,
      	XCd2,
      	XCd3,
      	XCd4,
      	XCd5,
      	XNum1,
      	XNum2,
      	XNum3,
      	XAmt1,
      	XAmt2,
      	XAmt3,
      	XDt1,
      	XDt2,
      	XDt3,
      	XDt4,
      	ExpBch2,
      	ExpBch3,
      	Accounting,
      	InvId
            )
    SELECT 
      	e.CTpId,
      	e.ChkId,
      	e.ExpAcct,
      	e.CostCtr,
        e.NetAmt,
      	e.DebitAmt,
      	e.CreditAmt,
      	e.ExpBch,
      	e.VoidCd,
      	e.Tax1099,
      	e.DescTxt,
      	e.DiagCd,
      	e.Typ,
      	e.XCd1,
      	e.XCd2,
      	e.XCd3,
      	e.XCd4,
      	e.XCd5,
      	e.XNum1,
      	e.XNum2,
      	e.XNum3,
      	e.XAmt1,
      	e.XAmt2,
      	e.XAmt3,
      	e.XDt1,
      	e.XDt2,
      	e.XDt3,
      	e.XDt4,
      	e.ExpBch2,
      	e.ExpBch3,
      	e.Accounting,
      	e.InvId    
    FROM ArE e
    inner join ArC c on e.CTpId = c.CTpId and e.ChkId = c.Id
     where c.RecordId = @ParmRecordId

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (3)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

/* 
   --------------------------------------------------------------------------------- 
    Restore each Hst record from the ArH table.
   ---------------------------------------------------------------------------------
*/  

    declare hst_archived cursor for
    select RecordId, CTpId, Id, ModVer
    from ArH
    where ChkRecordId = @ParmRecordId

    declare @ArcHstRecordId int, @CTpId smallint, @Id decimal, @ModVer tinyint, @HowmanyArH smallint

    open hst_archived
    fetch hst_archived into @ArcHstRecordId, @CTpId, @Id, @ModVer

    while @@fetch_status = 0
    begin

      IF EXISTS (SELECT 1 FROM Hst WHERE CTpId = @CTpId AND Id = @Id AND ModVer = @ModVer)
      BEGIN
        DELETE Hst WHERE CTpId = @CTpId AND Id = @Id AND ModVer = @ModVer
      END

      print 'ArH RecordId to be restored to Hst: ' + convert(varchar(30),@ArcHstRecordId)
      set @howmanyArH = (select count(*) FROM ArH WHERE CTpId = @CTpId AND Id = @Id)
      print 'Count of ArH records for this RecordId = ' + convert(varchar(30),@howmanyArH)
      
      set @ChkRecordId = (select RecordId from Chk where CTpId = @CTpId and Id = @Id)
      if @ChkRecordId is NULL
      begin
        set @ChkRecordId = 0
      end
      
      INSERT INTO Hst (
       	 CTpId,
       	 Id,
       	 OrigId,
       	 IdPre,
       	 ModVer,
       	 ModCd,
       	 CmpId,
       	 PayToNam1,
       	 PayToNam2,
       	 PayToNam3,
       	 IssDt,
       	 PayAmt,
       	 OrigPayAmt,
       	 ResrvAmt,
       	 BnkId,
       	 BnkNum,
       	 LosDt,
       	 Dt1,
       	 Dt2,
       	 Dt3,
       	 Dt4,
       	 Dt5,
       	 Time1,
       	 Time2,
       	 TranCd,
       	 TaxId,
       	 TaxTyp,
       	 Tax1099,
       	 RptAmt1099,
       	 SpltPay1099,
       	 VndTyp,
       	 VndId,
       	 AgentTyp,
       	 AgentId,
       	 MailToNam,
       	 MailToAdr1,
       	 MailToAdr2,
       	 MailToAdr3,
       	 MailToAdr4,
       	 MailToAdr5,
       	 City,
       	 State,
       	 CntyCd,
       	 CountryId,
       	 ZipCd,
       	 BillState,
       	 BillDt,
       	 PhNum1,
       	 PhNum2,
       	 FaxNum,
       	 FaxNumTyp,
       	 FaxToNam,
       	 EmailAdr,
       	 MrgId,
       	 MrgId2,
       	 PayCd,
       	 PayToCd,
       	 ReqId,
       	 ExamId,
       	 ExamNam,
       	 AdjId,
       	 CurId,
       	 Office,
       	 DeptCd,
       	 MailStop,
       	 ReissCd,
       	 AtchCd,
       	 ReqNum,
       	 ImpBch,
       	 ImpBnkBch,
       	 PrtBch,
       	 RcnBch,
       	 SavRcnBch,
       	 ExpBch,
       	 PdBch,
       	 VoidExpCd,
       	 PrevVoidExpCd,
       	 WriteOffExpCd,
       	 SrchLtrCd,
       	 PrtCnt,
       	 RcnCd,
       	 VoidCd,
       	 VoidId,
       	 VoidDt,
       	 UnVoidCd,
       	 UnVoidId,
       	 UnVoidDt,
       	 SigCd,
       	 SigCd1,
       	 SigCd2,
       	 DrftCd,
       	 DscCd,
       	 RestCd,
       	 XCd1,
       	 XCd2,
       	 XCd3,
       	 XCd4,
       	 XCd5,
       	 XCd6,
       	 XCd7,
       	 XCd8,
       	 XCd9,
       	 XCd10,
       	 PayRate,
       	 XRate1,
       	 XRate2,
       	 XRate3,
       	 XAmt1,
       	 XAmt2,
       	 XAmt3,
       	 XAmt4,
       	 XAmt5,
       	 XAmt6,
       	 XAmt7,
       	 XAmt8,
       	 XAmt9,
       	 XAmt10,
       	 SalaryAmt,
       	 MaritalStat,
       	 FedExempt,
       	 StateExempt,
       	 Day30Cd,
       	 PstCd,
       	 RsnCd,
       	 PdCd,
       	 PdDt,
       	 ApprovCd,
       	 ApprovDt,
       	 ApprovId,
       	 ApprovCd2,
       	 ApprovDt2,
       	 ApprovId2,
       	 ApprovCd3,
       	 ApprovDt3,
       	 ApprovId3,
       	 ApprovCd4,
       	 ApprovDt4,
       	 ApprovId4,
       	 ApprovCd5,
       	 ApprovDt5,
       	 ApprovId5,
       	 ApprovCd6,
       	 ApprovDt6,
       	 ApprovId6,
       	 ApprovCd7,
       	 ApprovDt7,
       	 ApprovId7,
       	 ApprovCd8,
       	 ApprovDt8,
       	 ApprovId8,
       	 ApprovCd9,
       	 ApprovDt9,
       	 ApprovId9,
       	 AddDt,
       	 AddTime,
       	 AddId,
       	 ChgDt,
       	 ChgTime,
       	 ChgId,
       	 SrceCd,
       	 FrmCd,
       	 RefNum,
       	 NamTyp,
       	 LstNam,
       	 FstNam,
       	 MidInit,
       	 Salutation,
       	 AcctNum,
       	 ExpAcct,
       	 DebitAcct,
       	 BnkAcct,
       	 BnkRout,
       	 AcctNam,
       	 EftTypCd,
       	 BnkAcct2,
       	 BnkRout2,
       	 AcctNam2,
       	 EftTypCd2,
       	 BnkAcct3,
       	 BnkRout3,
       	 AcctNam3,
       	 EftTypCd3,
       	 AllocPct1,
       	 AllocPct2,
       	 AllocPct3,
       	 OptCd,
       	 EftTranCd,
       	 AdviceTyp,
       	 RepRsn,
       	 EmployerTyp,
       	 EmployerId,
       	 EmployerNam,
       	 EmployerAdr1,
       	 EmployerAdr2,
       	 EmployerAdr3,
       	 ProviderTyp,
       	 ProviderId,
       	 ProviderNam,
       	 CarrierTyp,
       	 CarrierId,
       	 PolId,
       	 InsNam,
       	 InsAdr1,
       	 InsAdr2,
       	 InsAdr3,
       	 ClaimNum,
       	 ClmntNum,
       	 ClmntNam,
       	 ClmntAdr1,
       	 ClmntAdr2,
       	 ClmntAdr3,
       	 LosCause,
       	 DiagCd1,
       	 DiagCd2,
       	 DiagCd3,
       	 DiagCd4,
       	 ForRsn1,
       	 ForRsn2,
       	 ForRsn3,
       	 CommentTxt,
       	 XNum1,
       	 XNum2,
       	 XNum3,
       	 XNum4,
       	 TransferOutBch,
       	 TransferInBch,
       	 VchCnt,
       	 PrtDt,
       	 PrtId,
       	 TranDt,
       	 TranTime,
       	 TranTyp,
       	 TranId,
       	 BTpId,
       	 ExamTyp,
       	 Priority,
       	 DeliveryDt,
       	 CardNum,
       	 CardTyp,
       	 ExportStat,
       	 PrevExportStat,
       	 NoBulk,
       	 Typ1099,
       	 TrmId,
       	 AltId,
       	 AltTyp,
       	 AthOver,
       	 AthId,
       	 AthCd,
       	 MicrofilmID,
       	 BlockSeqNum,
       	 PrtBchOFAC,
       	 ExpBch2,
       	 ExpBch3,
       	 PrenoteCd,
       	 SavPdBch,
       	 ACHTraceNum,
       	 EscheatExportStat,
       	 PrevEscheatExportStat,
       	 RcdLock,
       	 Tax1099Cd,
       	 ClmntTaxId,
       	 ManSigCd,
         ChkRecordId 	
         	)	
       SELECT  
       	 CTpId,
       	 Id,
       	 OrigId,
       	 IdPre,
       	 ModVer,
       	 ModCd,
       	 CmpId,
       	 PayToNam1,
  	     PayToNam2,
       	 PayToNam3,
       	 IssDt,
       	 PayAmt,
       	 OrigPayAmt,
       	 ResrvAmt,
       	 BnkId,
       	 BnkNum,
       	 LosDt,
       	 Dt1,
       	 Dt2,
       	 Dt3,
       	 Dt4,
       	 Dt5,
       	 Time1,
       	 Time2,
       	 TranCd,
       	 TaxId,
       	 TaxTyp,
       	 Tax1099,
       	 RptAmt1099,
       	 SpltPay1099,
       	 VndTyp,
       	 VndId,
       	 AgentTyp,
       	 AgentId,
       	 MailToNam,
       	 MailToAdr1,
       	 MailToAdr2,
       	 MailToAdr3,
       	 MailToAdr4,
       	 MailToAdr5,
       	 City,
       	 State,
       	 CntyCd,
       	 CountryId,
       	 ZipCd,
       	 BillState,
       	 BillDt,
       	 PhNum1,
       	 PhNum2,
       	 FaxNum,
       	 FaxNumTyp,
       	 FaxToNam,
       	 EmailAdr,
       	 MrgId,
       	 MrgId2,
       	 PayCd,
       	 PayToCd,
       	 ReqId,
       	 ExamId,
       	 ExamNam,
       	 AdjId,
       	 CurId,
       	 Office,
       	 DeptCd,
       	 MailStop,
       	 ReissCd,
       	 AtchCd,
       	 ReqNum,
       	 ImpBch,
       	 ImpBnkBch,
       	 PrtBch,
       	 RcnBch,
       	 SavRcnBch,
       	 ExpBch,
       	 PdBch,
       	 VoidExpCd,
       	 PrevVoidExpCd,
       	 WriteOffExpCd,
       	 SrchLtrCd,
       	 PrtCnt,
       	 RcnCd,
       	 VoidCd,
       	 VoidId,
       	 VoidDt,
       	 UnVoidCd,
       	 UnVoidId,
       	 UnVoidDt,
       	 SigCd,
       	 SigCd1,
       	 SigCd2,
       	 DrftCd,
       	 DscCd,
       	 RestCd,
       	 XCd1,
       	 XCd2,
       	 XCd3,
       	 XCd4,
       	 XCd5,
       	 XCd6,
       	 XCd7,
       	 XCd8,
       	 XCd9,
       	 XCd10,
       	 PayRate,
       	 XRate1,
       	 XRate2,
       	 XRate3,
       	 XAmt1,
       	 XAmt2,
       	 XAmt3,
       	 XAmt4,
       	 XAmt5,
       	 XAmt6,
       	 XAmt7,
       	 XAmt8,
       	 XAmt9,
       	 XAmt10,
       	 SalaryAmt,
       	 MaritalStat,
       	 FedExempt,
       	 StateExempt,
       	 Day30Cd,
       	 PstCd,
       	 RsnCd,
       	 PdCd,
       	 PdDt,
       	 ApprovCd,
       	 ApprovDt,
       	 ApprovId,
       	 ApprovCd2,
       	 ApprovDt2,
       	 ApprovId2,
       	 ApprovCd3,
       	 ApprovDt3,
       	 ApprovId3,
       	 ApprovCd4,
       	 ApprovDt4,
       	 ApprovId4,
       	 ApprovCd5,
       	 ApprovDt5,
       	 ApprovId5,
       	 ApprovCd6,
       	 ApprovDt6,
       	 ApprovId6,
       	 ApprovCd7,
       	 ApprovDt7,
       	 ApprovId7,
       	 ApprovCd8,
       	 ApprovDt8,
       	 ApprovId8,
       	 ApprovCd9,
       	 ApprovDt9,
       	 ApprovId9,
       	 AddDt,
       	 AddTime,
       	 AddId,
       	 ChgDt,
       	 ChgTime,
       	 ChgId,
       	 SrceCd,
       	 FrmCd,
       	 RefNum,
       	 NamTyp,
       	 LstNam,
       	 FstNam,
       	 MidInit,
       	 Salutation,
       	 AcctNum,
       	 ExpAcct,
       	 DebitAcct,
       	 BnkAcct,
       	 BnkRout,
       	 AcctNam,
       	 EftTypCd,
       	 BnkAcct2,
       	 BnkRout2,
       	 AcctNam2,
       	 EftTypCd2,
       	 BnkAcct3,
       	 BnkRout3,
       	 AcctNam3,
       	 EftTypCd3,
       	 AllocPct1,
       	 AllocPct2,
       	 AllocPct3,
       	 OptCd,
       	 EftTranCd,
       	 AdviceTyp,
       	 RepRsn,
       	 EmployerTyp,
       	 EmployerId,
       	 EmployerNam,
       	 EmployerAdr1,
       	 EmployerAdr2,
       	 EmployerAdr3,
       	 ProviderTyp,
       	 ProviderId,
       	 ProviderNam,
       	 CarrierTyp,
       	 CarrierId,
       	 PolId,
       	 InsNam,
       	 InsAdr1,
       	 InsAdr2,
       	 InsAdr3,
       	 ClaimNum,
       	 ClmntNum,
       	 ClmntNam,
       	 ClmntAdr1,
       	 ClmntAdr2,
       	 ClmntAdr3,
       	 LosCause,
       	 DiagCd1,
       	 DiagCd2,
       	 DiagCd3,
       	 DiagCd4,
       	 ForRsn1,
       	 ForRsn2,
       	 ForRsn3,
       	 CommentTxt,
       	 XNum1,
       	 XNum2,
       	 XNum3,
       	 XNum4,
       	 TransferOutBch,
       	 TransferInBch,
       	 VchCnt,
       	 PrtDt,
       	 PrtId,
       	 TranDt,
       	 TranTime,
       	 TranTyp,
       	 TranId,
       	 BTpId,
       	 ExamTyp,
       	 Priority,
       	 DeliveryDt,
       	 CardNum,
       	 CardTyp,
       	 ExportStat,
       	 PrevExportStat,
       	 NoBulk,
       	 Typ1099,
       	 TrmId,
       	 AltId,
       	 AltTyp,
       	 AthOver,
       	 AthId,
       	 AthCd,
       	 MicrofilmID,
       	 BlockSeqNum,
       	 PrtBchOFAC,
       	 ExpBch2,
       	 ExpBch3,
       	 PrenoteCd,
       	 SavPdBch,
       	 ACHTraceNum,
       	 EscheatExportStat,
       	 PrevEscheatExportStat,
       	 RcdLock,
       	 Tax1099Cd,
       	 ClmntTaxId,
       	 ManSigCd,
         @ChkRecordId 	
      FROM ArH
      WHERE RecordId = @ArcHstRecordId
  
      fetch hst_archived into @ArcHstRecordId, @CTpId, @Id, @ModVer

    end

    close hst_archived
    deallocate hst_archived

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (4)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

/* 
   ------------------------------------------------------------------------------------------ 
    Apply the Restore TranTyp which will create an appropriate Hst record
   ------------------------------------------------------------------------------------------
*/       
    set @Cmd = 'UPDATE Chk SET TranTyp = 252, TranDt = ' + convert(varchar(20),@claTranDt) + ', TranTime = '  + convert(varchar(20),@claTranTm) + ' WHERE RecordId = ' + convert(varchar(20),@ParmRecordId)

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (4a)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

/* 
   --------------------------------------------------------------------------------- 
    Restore each Vch record from the ArV table.
   ---------------------------------------------------------------------------------
*/       

    INSERT INTO Vch (
     CTpId,
     ChkId,
     SeqNum,
     DescTxt,
     VchId,
     InvId,
     CshAcct,
     ExpAcct,
     CostCtr,
     InsNam,
     ClmntNam,
     ClmntNum,
     ClaimNum,
     TranCd,
     PolId,
     InvDt,
     InvAmt,
     AmtPd,
     DiscAmt,
     NetAmt,
     ExpBch,
     DiagCd,
     RsnCd,
     Amt1,
     Amt2,
     Dt1,
     Dt2,
     Dt3,
     Dt4,
     Qty1,
     Qty2,
     Qty3,
     PayRate,
     XRate1,
     XRate2,
     XRate3,
     XRate4,
     XRate5,
     Time,
     Tax1099,
     XCd1,
     XCd2,
     XCd3,
     XCd4,
     XCd5,
     XCd6,
     XCd7,
     XCd8,
     XCd9,
     XCd10,
     TaxId,
     TaxTyp,
     Amt3,
     Amt4,
     Amt5,
     Dt5,
     Tax1099Cd,
     Typ1099
         )
    SELECT 
      v.CTpId,
      v.ChkId,
      v.SeqNum,
      v.DescTxt,
      v.VchId,
      v.InvId,
      v.CshAcct,
      v.ExpAcct,
      v.CostCtr,
      v.InsNam,
      v.ClmntNam,
      v.ClmntNum,
      v.ClaimNum,
      v.TranCd,
      v.PolId,
      v.InvDt,
      v.InvAmt,
      v.AmtPd,
      v.DiscAmt,
      v.NetAmt,
      v.ExpBch,
      v.DiagCd,
      v.RsnCd,
      v.Amt1,
      v.Amt2,
      v.Dt1,
      v.Dt2,
      v.Dt3,
      v.Dt4,
      v.Qty1,
      v.Qty2,
      v.Qty3,
      v.PayRate,
      v.XRate1,
      v.XRate2,
      v.XRate3,
      v.XRate4,
      v.XRate5,
      v.Time,
      v.Tax1099,
      v.XCd1,
      v.XCd2,
      v.XCd3,
      v.XCd4,
      v.XCd5,
      v.XCd6,
      v.XCd7,
      v.XCd8,
      v.XCd9,
      v.XCd10,
      v.TaxId,
      v.TaxTyp,
      v.Amt3,
      v.Amt4,
      v.Amt5,
      v.Dt5,
      v.Tax1099Cd,
      v.Typ1099
    FROM ArV v
    inner join Arc c on v.CTpId = c.CTpId and v.ChkId = c.Id
     where c.RecordId = @ParmRecordId

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (5)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

    INSERT INTO WHApplied (
	  HstRecordId,
      ExportBch1,
	  ExportBch2
    	)
    SELECT
	  a.HstRecordId,
      a.ExportBch1,
	  a.ExportBch2
    FROM ArWHApplied a
    inner join ArH h on a.HstRecordId = h.RecordId
     where h.ChkRecordId = @ParmRecordId

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed Process failed...unable to restore WHApplied records'
        ROLLBACK TRAN
        RETURN(1)  -- Return a non-zero status to the calling process to indicate failure 
    END

    INSERT INTO WHVch (
	  VchId,
	  WHTypId,
	  WHAmt	
    	)
    SELECT
	  a.VchId,
	  a.WHTypId,
	  a.WHAmt	
    FROM ArWHVch a
    inner join ArV v on a.VchId = v.Id
    inner join Arc c on v.ChkId = c.Id
     where c.RecordId = @ParmRecordId

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (6)'
        ROLLBACK TRAN
        RETURN(1)  -- Return a non-zero status to the calling process to indicate failure 
    END

/*
   --------------------------------------------------------------------------------- 
    delete archived payments (ArC), history (ArH) and related child records.
   ---------------------------------------------------------------------------------
*/
  
  DELETE ArH
   WHERE ChkRecordId = @ParmRecordId

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (8)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END
  
  DELETE ArWHVch
    FROM ArWHVch a
    inner join ArV v on a.VchId = v.Id
    inner join Arc c on v.ChkId = c.Id
   WHERE c.RecordId = @ParmRecordId

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (9)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END
  
  DELETE ArWHApplied
    FROM ArWHApplied a
    inner join ArH h on h.RecordId = a.HstRecordId
    inner join ArC c on c.RecordId = h.ChkRecordId
   WHERE h.ChkRecordId = @ParmRecordId

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Unable to clean up ArWHApplied'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  DELETE ArV
    FROM ArV v
    inner join Arc c on v.CTpId = c.CTpId and v.ChkId = c.Id
     where c.RecordId = @ParmRecordId
   
  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (10)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  DELETE ArT
    FROM ArT t
    inner join Arc c on t.CTpId = c.CTpId and t.ChkId = c.Id
    where c.RecordId = @ParmRecordId

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (11)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  DELETE ArE
    FROM ArE e
    inner join Arc c on e.CTpId = c.CTpId and e.ChkId = c.Id
    where c.RecordId = @ParmRecordId

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (12)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END
  
  DELETE ArC
   WHERE RecordId = @ParmRecordId

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppspRestoreSelectedArchivedPayments: Restore process failed (7)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  COMMIT TRAN

  set nocount off
    
  RETURN /* Return with a zero status to indicate a successful process */

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[spRestoreArchivedPayments]'
GO
ALTER PROCEDURE [dbo].[spRestoreArchivedPayments]
(
@archivebchnum int,
@ParmRecordId int
)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible for restoring previously archived payments. 
    The following tables are included in the restore process: Chk, Hst, ExA, TxT, Vch,
    and WHVch. 
    
    The calling application has the responsibility of passing the Bch:Num or the RecordId
    to this procedure, as parameters. If the RecordId (@ParmRecordId) is passed to this
    procedure, in lieu of the Bch:Num (@archivebchnum), then we restore individual Chk
    records by calling the subordinate procedure, spRestoreSelectedArchivedPayments.
    
    Coding issues: none.
   ---------------------------------------------------------------------------------
*/
AS
BEGIN

  declare @Cmd nvarchar(4000), @howmanyArH int, @claTranDt int, @claTranTm int, @ChkRecordId int
  
  if (@archivebchnum = 0 and @ParmRecordId <> 0)  -- if we are restoring a specific payments, then
  begin                                           -- call spRestoreSelectedArchivedPayments
    exec spRestoreSelectedArchivedPayments @ParmRecordId
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'spRestoreSelectedArchivedPayments: Restore process failed (0)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    Return /* Return a zero status to the calling process to indicate success */
  end
  
  set nocount on

  BEGIN TRAN

    set @claTranDt = convert(int,datediff(dd, '12/28/1800',getdate())) -- convert today's date to Clarion
    set @claTranTm = convert(int,substring(convert(varchar(20),getdate(),108),1,2) + substring(convert(varchar(20),getdate(),108),4,2)) * 3600 + 30000 -- add an additional 2 minutes

/* 
   --------------------------------------------------------------------------------- 
    Next, restore each Chk record from the ArC table.
   ---------------------------------------------------------------------------------
*/       

    declare chk_archived cursor for
    select RecordId, ModVer
    from Arc
    where ArcBch = @archivebchnum

    declare @ArcChkRecordId int, @ModVer tinyint

    open chk_archived
    fetch chk_archived into @ArcChkRecordId, @ModVer

    while @@fetch_status = 0
    begin

      set @ModVer = @ModVer + 1

      insert into Chk (
      	CTpId,
      	Id,
      	OrigId,
      	IdPre,
      	ModVer,
      	ModCd,
      	CmpId,
      	PayToNam1,
      	PayToNam2,
      	PayToNam3,
      	IssDt,
      	PayAmt,
      	OrigPayAmt,
      	ResrvAmt,
      	BnkId,
      	BnkNum,
      	LosDt,
      	Dt1,
      	Dt2,
      	Dt3,
      	Dt4,
      	Dt5,
      	Time1,
      	Time2,
      	TranCd,
      	TaxId,
      	TaxTyp,
      	Tax1099,
      	RptAmt1099,
      	SpltPay1099,
      	VndTyp,
      	VndId,
      	AgentTyp,
      	AgentId,
      	MailToNam,
      	MailToAdr1,
      	MailToAdr2,
      	MailToAdr3,
      	MailToAdr4,
      	MailToAdr5,
      	City,
      	State,
      	CntyCd,
      	CountryId,
      	ZipCd,
      	BillState,
      	BillDt,
      	PhNum1,
      	PhNum2,
      	FaxNum,
      	FaxNumTyp,
      	FaxToNam,
      	EmailAdr,
      	MrgId,
      	MrgId2,
      	PayCd,
      	PayToCd,
      	ReqId,
      	ExamId,
      	ExamNam,
      	AdjId,
      	CurId,
      	Office,
      	DeptCd,
      	MailStop,
      	ReissCd,
      	AtchCd,
      	ReqNum,
      	ImpBch,
      	ImpBnkBch,
      	PrtBch,
      	RcnBch,
      	SavRcnBch,
      	ExpBch,
      	PdBch,
      	VoidExpCd,
      	PrevVoidExpCd,
      	WriteOffExpCd,
      	SrchLtrCd,
      	PrtCnt,
      	RcnCd,
      	VoidCd,
      	VoidId,
      	VoidDt,
      	UnVoidCd,
      	UnVoidId,
      	UnVoidDt,
      	SigCd,
      	SigCd1,
      	SigCd2,
      	DrftCd,
      	DscCd,
      	RestCd,
      	XCd1,
      	XCd2,
      	XCd3,
      	XCd4,
      	XCd5,
      	XCd6,
      	XCd7,
      	XCd8,
      	XCd9,
      	XCd10,
      	PayRate,
      	XRate1,
      	XRate2,
      	XRate3,
      	XAmt1,
      	XAmt2,
      	XAmt3,
      	XAmt4,
      	XAmt5,
      	XAmt6,
      	XAmt7,
      	XAmt8,
      	XAmt9,
      	XAmt10,
      	SalaryAmt,
      	MaritalStat,
      	FedExempt,
      	StateExempt,
      	Day30Cd,
      	PstCd,
      	RsnCd,
      	PdCd,
      	PdDt,
      	ApprovCd,
      	ApprovDt,
      	ApprovId,
      	ApprovCd2,
      	ApprovDt2,
      	ApprovId2,
      	ApprovCd3,
      	ApprovDt3,
      	ApprovId3,
      	ApprovCd4,
      	ApprovDt4,
      	ApprovId4,
    	ApprovCd5,
      	ApprovDt5,
      	ApprovId5,
      	ApprovCd6,
      	ApprovDt6,
      	ApprovId6,
      	ApprovCd7,
      	ApprovDt7,
      	ApprovId7,
      	ApprovCd8,
      	ApprovDt8,
      	ApprovId8,
      	ApprovCd9,
      	ApprovDt9,
      	ApprovId9,
      	AddDt,
      	AddTime,
      	AddId,
      	ChgDt,
      	ChgTime,
      	ChgId,
      	SrceCd,
      	FrmCd,
        RefNum,
      	NamTyp,
      	LstNam,
      	FstNam,
      	MidInit,
      	Salutation,
      	AcctNum,
      	ExpAcct,
      	DebitAcct,
      	BnkAcct,
      	BnkRout,
      	AcctNam,
      	EftTypCd,
 	    BnkAcct2,
      	BnkRout2,
      	AcctNam2,
      	EftTypCd2,
      	BnkAcct3,
      	BnkRout3,
      	AcctNam3,
      	EftTypCd3,
      	AllocPct1,
      	AllocPct2,
      	AllocPct3,
      	OptCd,
      	EftTranCd,
      	AdviceTyp,
      	RepRsn,
      	EmployerTyp,
      	EmployerId,
      	EmployerNam,
      	EmployerAdr1,
      	EmployerAdr2,
      	EmployerAdr3,
      	ProviderTyp,
      	ProviderId,
      	ProviderNam,
      	CarrierTyp,
      	CarrierId,
      	PolId,
      	InsNam,
      	InsAdr1,
      	InsAdr2,
      	InsAdr3,
      	ClaimNum,
      	ClmntNum,
      	ClmntNam,
      	ClmntAdr1,
      	ClmntAdr2,
      	ClmntAdr3,
      	LosCause,
      	DiagCd1,
      	DiagCd2,
      	DiagCd3,
      	DiagCd4,
      	ForRsn1,
      	ForRsn2,
      	ForRsn3,
      	CommentTxt,
      	XNum1,
      	XNum2,
      	XNum3,
      	XNum4,
      	TransferOutBch,
      	TransferInBch,
      	VchCnt,
      	PrtDt,
      	PrtId,
      	TranDt,
      	TranTime,
      	TranTyp,
      	TranId,
      	BTpId,
      	ExamTyp,
      	Priority,
      	DeliveryDt,
      	CardNum,
      	CardTyp,
      	ExportStat,
      	PrevExportStat,
      	NoBulk,
      	Typ1099,
      	TrmId,
      	AltId,
      	AltTyp,
      	AthOver,
      	AthId,
      	AthCd,
      	MicrofilmID,
      	BlockSeqNum,
      	PrtBchOFAC,
      	ExpBch2,
      	ExpBch3,
      	PrenoteCd,
      	SavPdBch,
      	ACHTraceNum,
      	EscheatExportStat,
      	PrevEscheatExportStat,
      	RcdLock,
      	Tax1099Cd,
      	ClmntTaxId,
      	ManSigCd
              )
      select
      	CTpId,
      	Id,
      	OrigId,
      	IdPre,
      	@ModVer,
      	ModCd,
      	CmpId,
      	PayToNam1,
      	PayToNam2,
      	PayToNam3,
      	IssDt,
      	PayAmt,
      	OrigPayAmt,
      	ResrvAmt,
      	BnkId,
      	BnkNum,
      	LosDt,
      	Dt1,
      	Dt2,
      	Dt3,
      	Dt4,
      	Dt5,
      	Time1,
      	Time2,
      	TranCd,
      	TaxId,
      	TaxTyp,
      	Tax1099,
      	RptAmt1099,
      	SpltPay1099,
      	VndTyp,
      	VndId,
      	AgentTyp,
      	AgentId,
      	MailToNam,
      	MailToAdr1,
      	MailToAdr2,
      	MailToAdr3,
      	MailToAdr4,
      	MailToAdr5,
      	City,
      	State,
      	CntyCd,
      	CountryId,
      	ZipCd,
      	BillState,
      	BillDt,
      	PhNum1,
      	PhNum2,
      	FaxNum,
      	FaxNumTyp,
      	FaxToNam,
      	EmailAdr,
      	MrgId,
      	MrgId2,
      	PayCd,
      	PayToCd,
      	ReqId,
      	ExamId,
      	ExamNam,
      	AdjId,
      	CurId,
      	Office,
      	DeptCd,
      	MailStop,
      	ReissCd,
      	AtchCd,
      	ReqNum,
      	ImpBch,
      	ImpBnkBch,
      	PrtBch,
      	RcnBch,
      	SavRcnBch,
      	ExpBch,
      	PdBch,
      	VoidExpCd,
      	PrevVoidExpCd,
   	    WriteOffExpCd,
      	SrchLtrCd,
      	PrtCnt,
      	RcnCd,
      	VoidCd,
      	VoidId,
      	VoidDt,
      	UnVoidCd,
      	UnVoidId,
      	UnVoidDt,
      	SigCd,
      	SigCd1,
      	SigCd2,
      	DrftCd,
      	DscCd,
      	RestCd,
      	XCd1,
      	XCd2,
      	XCd3,
      	XCd4,
      	XCd5,
      	XCd6,
      	XCd7,
      	XCd8,
      	XCd9,
      	XCd10,
      	PayRate,
      	XRate1,
      	XRate2,
      	XRate3,
      	XAmt1,
      	XAmt2,
      	XAmt3,
      	XAmt4,
      	XAmt5,
      	XAmt6,
      	XAmt7,
      	XAmt8,
      	XAmt9,
      	XAmt10,
      	SalaryAmt,
      	MaritalStat,
      	FedExempt,
      	StateExempt,
      	Day30Cd,
      	PstCd,
      	RsnCd,
      	PdCd,
      	PdDt,
      	ApprovCd,
      	ApprovDt,
      	ApprovId,
      	ApprovCd2,
      	ApprovDt2,
      	ApprovId2,
      	ApprovCd3,
      	ApprovDt3,
      	ApprovId3,
      	ApprovCd4,
      	ApprovDt4,
      	ApprovId4,
      	ApprovCd5,
      	ApprovDt5,
      	ApprovId5,
      	ApprovCd6,
      	ApprovDt6,
      	ApprovId6,
      	ApprovCd7,
      	ApprovDt7,
      	ApprovId7,
      	ApprovCd8,
      	ApprovDt8,
      	ApprovId8,
      	ApprovCd9,
      	ApprovDt9,
      	ApprovId9,
   	    AddDt,
      	AddTime,
      	AddId,
      	ChgDt,
      	ChgTime,
      	ChgId,
      	SrceCd,
      	FrmCd,
      	RefNum,
      	NamTyp,
      	LstNam,
      	FstNam,
      	MidInit,
      	Salutation,
      	AcctNum,
      	ExpAcct,
      	DebitAcct,
      	BnkAcct,
      	BnkRout,
      	AcctNam,
      	EftTypCd,
      	BnkAcct2,
      	BnkRout2,
      	AcctNam2,
      	EftTypCd2,
      	BnkAcct3,
      	BnkRout3,
      	AcctNam3,
      	EftTypCd3,
      	AllocPct1,
      	AllocPct2,
      	AllocPct3,
      	OptCd,
      	EftTranCd,
      	AdviceTyp,
      	RepRsn,
      	EmployerTyp,
      	EmployerId,
      	EmployerNam,
      	EmployerAdr1,
      	EmployerAdr2,
      	EmployerAdr3,
      	ProviderTyp,
      	ProviderId,
      	ProviderNam,
      	CarrierTyp,
      	CarrierId,
      	PolId,
      	InsNam,
      	InsAdr1,
      	InsAdr2,
      	InsAdr3,
      	ClaimNum,
      	ClmntNum,
      	ClmntNam,
      	ClmntAdr1,
      	ClmntAdr2,
      	ClmntAdr3,
      	LosCause,
      	DiagCd1,
      	DiagCd2,
      	DiagCd3,
      	DiagCd4,
      	ForRsn1,
      	ForRsn2,
      	ForRsn3,
      	CommentTxt,
      	XNum1,
      	XNum2,
      	XNum3,
      	XNum4,
      	TransferOutBch,
      	TransferInBch,
      	VchCnt,
      	PrtDt,
      	PrtId,
/*      @claTranDt,	-- TranDt,   -- 07/NC/024
      	@claTranTm,	-- TranTime, -- 07/NC/024
*/
      	TranDt,      -- 07/NC/024
      	TranTime,    -- 07/NC/024
      	252,         -- 07/NC/024
      	TranId,
      	BTpId,
      	ExamTyp,
      	Priority,
      	DeliveryDt,
      	CardNum,
      	CardTyp,
      	ExportStat,
      	PrevExportStat,
      	NoBulk,
      	Typ1099,
      	TrmId,
      	AltId,
      	AltTyp,
      	AthOver,
      	AthId,
      	AthCd,
      	MicrofilmID,
      	BlockSeqNum,
      	PrtBchOFAC,
      	ExpBch2,
      	ExpBch3,
      	PrenoteCd,
      	SavPdBch,
      	ACHTraceNum,
      	EscheatExportStat,
      	PrevEscheatExportStat,
      	RcdLock,
      	Tax1099Cd,
      	ClmntTaxId,
      	ManSigCd
      from Arc
      where RecordId = @ArcChkRecordId

      IF (@@error!=0)
      BEGIN
          --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (1a)'
          ROLLBACK TRAN
          RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
      END

      fetch chk_archived into @ArcChkRecordId, @ModVer

    end

    close chk_archived
    deallocate chk_archived

    if @@error <> 0
    begin
      --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (1b)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    end

/* 
   --------------------------------------------------------------------------------- 
    Next, restore each ChkStop record from the ArChkStop table.
   ---------------------------------------------------------------------------------
*/       
      
    insert into ChkStop (
	 RecordId,
  	 ConfirmId,
	 ConfirmCd,
   	 ProcessDt,
	 RequestBch,
   	 ConfirmBch,
     StatusCd
            )
    select
	 s.RecordId,
  	 s.ConfirmId,
	 s.ConfirmCd,
   	 s.ProcessDt,
	 s.RequestBch,
   	 s.ConfirmBch,
     s.StatusCd
    from ArChkStop s
    inner join Arc c on c.RecordId = s.RecordId
    where  c.ArcBch = @archivebchnum

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (1c)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

    delete ArChkStop
    from ArChkStop s
    inner join Arc c on c.RecordId = s.RecordId
    where  c.ArcBch = @archivebchnum
/* 
   --------------------------------------------------------------------------------- 
    Next, restore each ChkReissue record from the ArChkReissue table.
   ---------------------------------------------------------------------------------
*/       

    insert into ChkReissue (
	 SourceRecordId,
  	 ReIssRecordId,
	 OrigRecordId
            )
    select
     r.SourceRecordId,
     r.ReIssRecordId,
     r.OrigRecordId
    from ArChkReissue r
    inner join Arc c on c.RecordId = r.ReIssRecordId
    where  c.ArcBch = @archivebchnum

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (1d)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

    delete ArChkReissue
    from ArChkReissue r
    inner join Arc c on c.RecordId = r.ReIssRecordId
    where c.ArcBch = @archivebchnum

/* 
   --------------------------------------------------------------------------------- 
    Next, restore each Txt record from the ArT table.
   ---------------------------------------------------------------------------------
*/       
    INSERT INTO Txt
    SELECT t.* 
    FROM ArT t
    inner join Arc c on c.CTpId = t.CTpId and c.Id = t.ChkId
    WHERE c.ArcBch = @archivebchnum

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (2)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
/*
   --------------------------------------------------------------------------------- 
    Restore each ExA record from the ArE table.
   ---------------------------------------------------------------------------------
*/

    INSERT INTO ExA (
      	CTpId,
      	ChkId,
      	ExpAcct,
      	CostCtr,
      	NetAmt,
      	DebitAmt,
      	CreditAmt,
      	ExpBch,
      	VoidCd,
      	Tax1099,
      	DescTxt,
      	DiagCd,
      	Typ,
      	XCd1,
      	XCd2,
      	XCd3,
      	XCd4,
      	XCd5,
      	XNum1,
      	XNum2,
      	XNum3,
      	XAmt1,
      	XAmt2,
      	XAmt3,
      	XDt1,
      	XDt2,
      	XDt3,
      	XDt4,
      	ExpBch2,
      	ExpBch3,
      	Accounting,
      	InvId
            )
    SELECT 
      	e.CTpId,
      	e.ChkId,
      	e.ExpAcct,
    	e.CostCtr,
        e.NetAmt,
      	e.DebitAmt,
      	e.CreditAmt,
      	e.ExpBch,
      	e.VoidCd,
      	e.Tax1099,
      	e.DescTxt,
      	e.DiagCd,
      	e.Typ,
      	e.XCd1,
      	e.XCd2,
      	e.XCd3,
      	e.XCd4,
      	e.XCd5,
      	e.XNum1,
      	e.XNum2,
      	e.XNum3,
      	e.XAmt1,
      	e.XAmt2,
      	e.XAmt3,
      	e.XDt1,
      	e.XDt2,
      	e.XDt3,
      	e.XDt4,
      	e.ExpBch2,
      	e.ExpBch3,
      	e.Accounting,
      	e.InvId    
    FROM ArE e
    inner join ArC c on c.CTpId = e.CTpId and c.Id = e.ChkId
    WHERE c.ArcBch = @archivebchnum

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (3)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

/* 
   --------------------------------------------------------------------------------- 
    First, restore each Hst record from the ArH table.
   ---------------------------------------------------------------------------------
*/       
    set @howmanyArH = (select count(*) FROM ArH WHERE ArcBch = @archivebchnum)
    print 'ArH records to be restored to Hst: ' + convert(varchar(30),@howmanyArH)

    declare hst_archived cursor for
    select RecordId, CTpId, Id, ModVer
    from ArH
    where ArcBch = @archivebchnum

    declare @ArcHstRecordId int, @CTpId smallint, @Id decimal

    open hst_archived
    fetch hst_archived into @ArcHstRecordId, @CTpId, @Id, @ModVer

    while @@fetch_status = 0
    begin

      IF EXISTS (SELECT 1 FROM Hst WHERE CTpId = @CTpId AND Id = @Id AND ModVer = @ModVer)
      BEGIN
        DELETE Hst WHERE CTpId = @CTpId AND Id = @Id AND ModVer = @ModVer
      END

      print 'ArH RecordId to be restored to Hst: ' + convert(varchar(30),@ArcHstRecordId)
      set @howmanyArH = (select count(*) FROM ArH WHERE CTpId = @CTpId AND Id = @Id)
      print 'Count of ArH records for this RecordId = ' + convert(varchar(30),@howmanyArH)

      set @ChkRecordId = (select RecordId from Chk where CTpId = @CTpId and Id = @Id)
      if @ChkRecordId is NULL
      begin
        set @ChkRecordId = 0
      end
      
      INSERT INTO Hst (
       	 CTpId,
       	 Id,
       	 OrigId,
       	 IdPre,
       	 ModVer,
       	 ModCd,
       	 CmpId,
       	 PayToNam1,
       	 PayToNam2,
       	 PayToNam3,
       	 IssDt,
       	 PayAmt,
       	 OrigPayAmt,
       	 ResrvAmt,
       	 BnkId,
       	 BnkNum,
       	 LosDt,
       	 Dt1,
       	 Dt2,
       	 Dt3,
       	 Dt4,
       	 Dt5,
       	 Time1,
       	 Time2,
       	 TranCd,
       	 TaxId,
       	 TaxTyp,
       	 Tax1099,
       	 RptAmt1099,
       	 SpltPay1099,
       	 VndTyp,
       	 VndId,
       	 AgentTyp,
       	 AgentId,
       	 MailToNam,
       	 MailToAdr1,
       	 MailToAdr2,
       	 MailToAdr3,
       	 MailToAdr4,
       	 MailToAdr5,
       	 City,
       	 State,
       	 CntyCd,
       	 CountryId,
       	 ZipCd,
       	 BillState,
       	 BillDt,
       	 PhNum1,
       	 PhNum2,
       	 FaxNum,
       	 FaxNumTyp,
       	 FaxToNam,
       	 EmailAdr,
       	 MrgId,
       	 MrgId2,
       	 PayCd,
       	 PayToCd,
       	 ReqId,
       	 ExamId,
       	 ExamNam,
       	 AdjId,
       	 CurId,
       	 Office,
       	 DeptCd,
       	 MailStop,
       	 ReissCd,
       	 AtchCd,
       	 ReqNum,
       	 ImpBch,
       	 ImpBnkBch,
       	 PrtBch,
       	 RcnBch,
       	 SavRcnBch,
       	 ExpBch,
       	 PdBch,
       	 VoidExpCd,
       	 PrevVoidExpCd,
       	 WriteOffExpCd,
       	 SrchLtrCd,
       	 PrtCnt,
       	 RcnCd,
       	 VoidCd,
       	 VoidId,
       	 VoidDt,
       	 UnVoidCd,
       	 UnVoidId,
       	 UnVoidDt,
       	 SigCd,
       	 SigCd1,
       	 SigCd2,
       	 DrftCd,
       	 DscCd,
       	 RestCd,
       	 XCd1,
       	 XCd2,
       	 XCd3,
       	 XCd4,
       	 XCd5,
       	 XCd6,
       	 XCd7,
       	 XCd8,
       	 XCd9,
       	 XCd10,
       	 PayRate,
       	 XRate1,
       	 XRate2,
       	 XRate3,
       	 XAmt1,
       	 XAmt2,
       	 XAmt3,
       	 XAmt4,
       	 XAmt5,
       	 XAmt6,
       	 XAmt7,
       	 XAmt8,
       	 XAmt9,
       	 XAmt10,
       	 SalaryAmt,
       	 MaritalStat,
       	 FedExempt,
       	 StateExempt,
       	 Day30Cd,
       	 PstCd,
       	 RsnCd,
       	 PdCd,
       	 PdDt,
       	 ApprovCd,
       	 ApprovDt,
       	 ApprovId,
       	 ApprovCd2,
       	 ApprovDt2,
       	 ApprovId2,
       	 ApprovCd3,
       	 ApprovDt3,
       	 ApprovId3,
       	 ApprovCd4,
       	 ApprovDt4,
       	 ApprovId4,
       	 ApprovCd5,
       	 ApprovDt5,
       	 ApprovId5,
     	 ApprovCd6,
       	 ApprovDt6,
       	 ApprovId6,
       	 ApprovCd7,
       	 ApprovDt7,
       	 ApprovId7,
       	 ApprovCd8,
       	 ApprovDt8,
       	 ApprovId8,
       	 ApprovCd9,
       	 ApprovDt9,
       	 ApprovId9,
       	 AddDt,
       	 AddTime,
       	 AddId,
       	 ChgDt,
       	 ChgTime,
       	 ChgId,
       	 SrceCd,
       	 FrmCd,
       	 RefNum,
     	 NamTyp,
       	 LstNam,
       	 FstNam,
       	 MidInit,
       	 Salutation,
       	 AcctNum,
       	 ExpAcct,
       	 DebitAcct,
       	 BnkAcct,
       	 BnkRout,
       	 AcctNam,
       	 EftTypCd,
       	 BnkAcct2,
       	 BnkRout2,
       	 AcctNam2,
       	 EftTypCd2,
       	 BnkAcct3,
       	 BnkRout3,
       	 AcctNam3,
       	 EftTypCd3,
       	 AllocPct1,
       	 AllocPct2,
       	 AllocPct3,
       	 OptCd,
       	 EftTranCd,
       	 AdviceTyp,
       	 RepRsn,
       	 EmployerTyp,
       	 EmployerId,
       	 EmployerNam,
       	 EmployerAdr1,
       	 EmployerAdr2,
       	 EmployerAdr3,
       	 ProviderTyp,
       	 ProviderId,
       	 ProviderNam,
       	 CarrierTyp,
       	 CarrierId,
       	 PolId,
 	     InsNam,
       	 InsAdr1,
       	 InsAdr2,
       	 InsAdr3,
       	 ClaimNum,
       	 ClmntNum,
       	 ClmntNam,
       	 ClmntAdr1,
       	 ClmntAdr2,
       	 ClmntAdr3,
       	 LosCause,
       	 DiagCd1,
       	 DiagCd2,
       	 DiagCd3,
       	 DiagCd4,
       	 ForRsn1,
       	 ForRsn2,
       	 ForRsn3,
       	 CommentTxt,
       	 XNum1,
       	 XNum2,
       	 XNum3,
       	 XNum4,
       	 TransferOutBch,
       	 TransferInBch,
       	 VchCnt,
       	 PrtDt,
       	 PrtId,
       	 TranDt,
       	 TranTime,
       	 TranTyp,
       	 TranId,
       	 BTpId,
       	 ExamTyp,
       	 Priority,
       	 DeliveryDt,
       	 CardNum,
       	 CardTyp,
       	 ExportStat,
       	 PrevExportStat,
       	 NoBulk,
       	 Typ1099,
       	 TrmId,
       	 AltId,
       	 AltTyp,
       	 AthOver,
       	 AthId,
       	 AthCd,
       	 MicrofilmID,
       	 BlockSeqNum,
       	 PrtBchOFAC,
       	 ExpBch2,
       	 ExpBch3,
       	 PrenoteCd,
       	 SavPdBch,
       	 ACHTraceNum,
       	 EscheatExportStat,
       	 PrevEscheatExportStat,
       	 RcdLock,
       	 Tax1099Cd,
       	 ClmntTaxId,
       	 ManSigCd,
         ChkRecordId 	
         	)	
       SELECT  
       	 CTpId,
       	 Id,
       	 OrigId,
       	 IdPre,
       	 ModVer,
       	 ModCd,
       	 CmpId,
       	 PayToNam1,
       	 PayToNam2,
       	 PayToNam3,
       	 IssDt,
       	 PayAmt,
       	 OrigPayAmt,
       	 ResrvAmt,
       	 BnkId,
       	 BnkNum,
       	 LosDt,
       	 Dt1,
       	 Dt2,
       	 Dt3,
       	 Dt4,
       	 Dt5,
       	 Time1,
       	 Time2,
       	 TranCd,
       	 TaxId,
       	 TaxTyp,
       	 Tax1099,
       	 RptAmt1099,
       	 SpltPay1099,
       	 VndTyp,
       	 VndId,
       	 AgentTyp,
       	 AgentId,
       	 MailToNam,
       	 MailToAdr1,
       	 MailToAdr2,
       	 MailToAdr3,
       	 MailToAdr4,
       	 MailToAdr5,
       	 City,
       	 State,
       	 CntyCd,
       	 CountryId,
       	 ZipCd,
       	 BillState,
       	 BillDt,
       	 PhNum1,
       	 PhNum2,
       	 FaxNum,
       	 FaxNumTyp,
       	 FaxToNam,
       	 EmailAdr,
       	 MrgId,
       	 MrgId2,
       	 PayCd,
       	 PayToCd,
       	 ReqId,
       	 ExamId,
       	 ExamNam,
       	 AdjId,
       	 CurId,
       	 Office,
       	 DeptCd,
       	 MailStop,
       	 ReissCd,
       	 AtchCd,
       	 ReqNum,
       	 ImpBch,
       	 ImpBnkBch,
       	 PrtBch,
       	 RcnBch,
       	 SavRcnBch,
       	 ExpBch,
       	 PdBch,
       	 VoidExpCd,
       	 PrevVoidExpCd,
       	 WriteOffExpCd,
       	 SrchLtrCd,
       	 PrtCnt,
       	 RcnCd,
       	 VoidCd,
       	 VoidId,
       	 VoidDt,
       	 UnVoidCd,
       	 UnVoidId,
       	 UnVoidDt,
       	 SigCd,
       	 SigCd1,
       	 SigCd2,
       	 DrftCd,
   	     DscCd,
       	 RestCd,
       	 XCd1,
       	 XCd2,
       	 XCd3,
       	 XCd4,
       	 XCd5,
       	 XCd6,
       	 XCd7,
       	 XCd8,
       	 XCd9,
       	 XCd10,
       	 PayRate,
       	 XRate1,
       	 XRate2,
       	 XRate3,
       	 XAmt1,
       	 XAmt2,
       	 XAmt3,
       	 XAmt4,
       	 XAmt5,
       	 XAmt6,
       	 XAmt7,
       	 XAmt8,
       	 XAmt9,
       	 XAmt10,
       	 SalaryAmt,
       	 MaritalStat,
       	 FedExempt,
       	 StateExempt,
       	 Day30Cd,
       	 PstCd,
       	 RsnCd,
       	 PdCd,
       	 PdDt,
       	 ApprovCd,
       	 ApprovDt,
       	 ApprovId,
       	 ApprovCd2,
       	 ApprovDt2,
       	 ApprovId2,
       	 ApprovCd3,
       	 ApprovDt3,
       	 ApprovId3,
       	 ApprovCd4,
       	 ApprovDt4,
       	 ApprovId4,
       	 ApprovCd5,
       	 ApprovDt5,
       	 ApprovId5,
       	 ApprovCd6,
       	 ApprovDt6,
       	 ApprovId6,
	     ApprovCd7,
       	 ApprovDt7,
       	 ApprovId7,
       	 ApprovCd8,
       	 ApprovDt8,
     	 ApprovId8,
       	 ApprovCd9,
       	 ApprovDt9,
       	 ApprovId9,
       	 AddDt,
       	 AddTime,
       	 AddId,
       	 ChgDt,
       	 ChgTime,
       	 ChgId,
       	 SrceCd,
       	 FrmCd,
       	 RefNum,
       	 NamTyp,
       	 LstNam,
       	 FstNam,
       	 MidInit,
       	 Salutation,
       	 AcctNum,
       	 ExpAcct,
       	 DebitAcct,
       	 BnkAcct,
       	 BnkRout,
       	 AcctNam,
       	 EftTypCd,
       	 BnkAcct2,
       	 BnkRout2,
       	 AcctNam2,
       	 EftTypCd2,
       	 BnkAcct3,
       	 BnkRout3,
       	 AcctNam3,
       	 EftTypCd3,
       	 AllocPct1,
       	 AllocPct2,
       	 AllocPct3,
       	 OptCd,
       	 EftTranCd,
       	 AdviceTyp,
       	 RepRsn,
       	 EmployerTyp,
       	 EmployerId,
       	 EmployerNam,
       	 EmployerAdr1,
       	 EmployerAdr2,
       	 EmployerAdr3,
       	 ProviderTyp,
       	 ProviderId,
       	 ProviderNam,
       	 CarrierTyp,
       	 CarrierId,
       	 PolId,
       	 InsNam,
       	 InsAdr1,
       	 InsAdr2,
       	 InsAdr3,
       	 ClaimNum,
       	 ClmntNum,
       	 ClmntNam,
       	 ClmntAdr1,
       	 ClmntAdr2,
       	 ClmntAdr3,
       	 LosCause,
       	 DiagCd1,
       	 DiagCd2,
       	 DiagCd3,
       	 DiagCd4,
       	 ForRsn1,
       	 ForRsn2,
       	 ForRsn3,
       	 CommentTxt,
       	 XNum1,
       	 XNum2,
       	 XNum3,
       	 XNum4,
       	 TransferOutBch,
       	 TransferInBch,
       	 VchCnt,
       	 PrtDt,
       	 PrtId,
       	 TranDt,
       	 TranTime,
       	 TranTyp,
       	 TranId,
       	 BTpId,
       	 ExamTyp,
       	 Priority,
       	 DeliveryDt,
       	 CardNum,
       	 CardTyp,
       	 ExportStat,
       	 PrevExportStat,
       	 NoBulk,
       	 Typ1099,
       	 TrmId,
       	 AltId,
       	 AltTyp,
       	 AthOver,
       	 AthId,
       	 AthCd,
       	 MicrofilmID,
       	 BlockSeqNum,
       	 PrtBchOFAC,
       	 ExpBch2,
       	 ExpBch3,
       	 PrenoteCd,
       	 SavPdBch,
       	 ACHTraceNum,
       	 EscheatExportStat,
       	 PrevEscheatExportStat,
       	 RcdLock,
       	 Tax1099Cd,
       	 ClmntTaxId,
       	 ManSigCd,
         @ChkRecordId 	
      FROM ArH
      WHERE RecordId = @ArcHstRecordId
  
      fetch hst_archived into @ArcHstRecordId, @CTpId, @Id, @ModVer

    end

    close hst_archived
    deallocate hst_archived

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (4)'
     ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

/* 
   --------------------------------------------------------------------------------- 
    Restore each Vch record from the ArV table.
   ---------------------------------------------------------------------------------
*/       

    INSERT INTO Vch (
     CTpId,
     ChkId,
     SeqNum,
     DescTxt,
     VchId,
     InvId,
     CshAcct,
     ExpAcct,
     CostCtr,
     InsNam,
     ClmntNam,
     ClmntNum,
     ClaimNum,
     TranCd,
     PolId,
     InvDt,
     InvAmt,
     AmtPd,
     DiscAmt,
     NetAmt,
     ExpBch,
     DiagCd,
     RsnCd,
     Amt1,
     Amt2,
     Dt1,
     Dt2,
     Dt3,
     Dt4,
     Qty1,
     Qty2,
     Qty3,
     PayRate,
     XRate1,
     XRate2,
     XRate3,
     XRate4,
     XRate5,
     Time,
     Tax1099,
     XCd1,
     XCd2,
     XCd3,
     XCd4,
     XCd5,
     XCd6,
     XCd7,
     XCd8,
     XCd9,
     XCd10,
     TaxId,
     TaxTyp,
     Amt3,
     Amt4,
     Amt5,
     Dt5,
     Tax1099Cd,
     Typ1099
         )
    SELECT 
      v.CTpId,
      v.ChkId,
      v.SeqNum,
      v.DescTxt,
      v.VchId,
      v.InvId,
      v.CshAcct,
      v.ExpAcct,
      v.CostCtr,
      v.InsNam,
      v.ClmntNam,
      v.ClmntNum,
      v.ClaimNum,
      v.TranCd,
      v.PolId,
      v.InvDt,
      v.InvAmt,
      v.AmtPd,
      v.DiscAmt,
      v.NetAmt,
      v.ExpBch,
      v.DiagCd,
      v.RsnCd,
      v.Amt1,
      v.Amt2,
      v.Dt1,
      v.Dt2,
      v.Dt3,
      v.Dt4,
      v.Qty1,
      v.Qty2,
      v.Qty3,
      v.PayRate,
      v.XRate1,
      v.XRate2,
      v.XRate3,
      v.XRate4,
      v.XRate5,
      v.Time,
      v.Tax1099,
      v.XCd1,
      v.XCd2,
      v.XCd3,
      v.XCd4,
      v.XCd5,
      v.XCd6,
      v.XCd7,
      v.XCd8,
      v.XCd9,
      v.XCd10,
      v.TaxId,
      v.TaxTyp,
      v.Amt3,
      v.Amt4,
      v.Amt5,
      v.Dt5,
      v.Tax1099Cd,
      v.Typ1099
    FROM ArV v
    inner join Arc c on c.CTpId = v.CTpId and c.Id = v.ChkId
    WHERE c.ArcBch = @archivebchnum

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (5)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

    INSERT INTO WHApplied (
      HstRecordId,
      ExportBch1,
      ExportBch2
    	)
    SELECT
      HstRecordId,
      ExportBch1,
      ExportBch2
    FROM ArWHApplied
    WHERE ArcBch = @archivebchnum

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed Process failed...unable to restore WHApplied records'
        ROLLBACK TRAN
        RETURN(1)  -- Return a non-zero status to the calling process to indicate failure 
    END

    INSERT INTO WHVch (
	  VchId,
	  WHTypId,
	  WHAmt	
    	)
    SELECT
	  VchId,
	  WHTypId,
	  WHAmt	
    FROM ArWHVch
    WHERE ArcBch = @archivebchnum

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (6)'
        ROLLBACK TRAN
        RETURN(1)  -- Return a non-zero status to the calling process to indicate failure 
    END

/*
   --------------------------------------------------------------------------------- 
    delete archived payments (ArC), history (ArH) and related child records.
   ---------------------------------------------------------------------------------
*/
  
  DELETE ArH
   WHERE ArcBch = @archivebchnum

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (8)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END
  
  DELETE ArWHVch
   WHERE ArcBch = @archivebchnum

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (9)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END
  
  DELETE ArWHApplied
   WHERE ArcBch = @archivebchnum

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPRestoreArchivedPayments: Unable to clean up ArWHApplied'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  DELETE ArV
    FROM ArV v
    inner join Arc c on c.CTpId = v.CTpId and c.Id = v.ChkId
    WHERE c.ArcBch = @archivebchnum    
   
  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (10)'
 ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  DELETE ArT
    FROM ArT t
    inner join Arc c on t.CTpId = c.CTpId and t.ChkId = c.Id
      where c.ArcBch = @archivebchnum    

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (11)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  DELETE ArE
    FROM ArE e
    inner join Arc c on e.CTpId = c.CTpId AND e.ChkId = c.Id
     where c.ArcBch = @archivebchnum    

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (12)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END
  
  DELETE ArC
   WHERE ArcBch = @archivebchnum

  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPRestoreArchivedPayments: Restore process failed (13)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  COMMIT TRAN

  set nocount off
    
  RETURN /* Return with a zero status to indicate a successful process */

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ChkUpdateLog]'
GO
ALTER Procedure [dbo].[ChkUpdateLog] (@RecordId int)
AS

  INSERT Log
   (
  MsgTyp,
  MsgNum,
  ChkId,
  CTpId,
  Dt,
  Tm,
  Typ
   )
  Select 'E',
  '9997',
  Id,
  CTpId,
  ChgDt,
  ChgTime,
  'ZZZ'
  from Chk
  where RecordId = @RecordId

  if @@error <> 0
  begin
    --RAISERROR ('Insert Log record failure in stored proc ChkUpdateLog; rolling back changes', 16,1)
    rollback transaction
    return
  end

  Return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPAbaMaint]'
GO
ALTER procedure [dbo].[ppSPAbaMaint]
as

declare @RoutNum varchar(20)

declare AbaUpdtd cursor for
select RoutNum FROM Aba

declare stageAbaUpdtd cursor for
select RoutNum FROM stageAba

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open AbaUpdtd
fetch AbaUpdtd into @RoutNum
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each Aba record and make sure that stageAba records are Identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from stageAba where RoutNum = @RoutNum)
  begin
    delete stageAba	-- delete the existing record and insert it again from Aba
    where RoutNum = @RoutNum
  end

  insert into stageAba
  select * from Aba
  where RoutNum = @RoutNum

  fetch AbaUpdtd into @RoutNum

END
close AbaUpdtd
deallocate AbaUpdtd

/* -------------------------------------------------------------------------------------- 
     Each stageAba record must exist in Aba - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open stageAbaUpdtd
fetch stageAbaUpdtd into @RoutNum
while @@fetch_status = 0
begin

  if NOT exists (select 1 from Aba where RoutNum = @RoutNum)
  begin
    delete stageAba	-- delete the stage record with no match to the operational table
    where RoutNum = @RoutNum
  end

  fetch stageAbaUpdtd into @RoutNum

END
close stageAbaUpdtd
deallocate stageAbaUpdtd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing to this point.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPAbaMaint: Cannot update the stageAba table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off

Exec ppSPLastMaintDate
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPAbaSync]'
GO
ALTER procedure [dbo].[ppSPAbaSync]
(
@LogHdrId int
)
as

declare @RoutNum varchar(20)

declare stageAbaSyncd cursor for
select RoutNum FROM stageAba

declare AbaSyncd cursor for
select RoutNum FROM Aba

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageAbaSyncd
fetch stageAbaSyncd into @RoutNum
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageAba record and make sure that Aba records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Aba where RoutNum = @RoutNum)
  begin
    delete Aba	-- delete the existing record and insert it again from stageAba
    where RoutNum = @RoutNum
  end

  insert into Aba
  select *  from stageAba 
  where RoutNum = @RoutNum
  
  fetch stageAbaSyncd into @RoutNum

END
close stageAbaSyncd
deallocate stageAbaSyncd

/* -------------------------------------------------------------------------------------- 
     Each Aba record must exist in stageAba - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open AbaSyncd
fetch AbaSyncd into @RoutNum
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageAba where RoutNum = @RoutNum)
  begin
    delete Aba	-- delete the operational record with no match to the stage table
    where RoutNum = @RoutNum
  end

  fetch AbaSyncd into @RoutNum

END
close AbaSyncd
deallocate AbaSyncd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPAbaSync: Unable to sync the Aba table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPActSync]'
GO
ALTER procedure [dbo].[ppSPActSync]
(
@LogHdrId int
)
as

declare @Cd varchar(50)

declare stageActSyncd cursor for
select Cd FROM stageAct

declare ActSyncd cursor for
select Cd FROM Act

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageActSyncd
fetch stageActSyncd into @Cd
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageAct record and make sure that Act records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Act where Cd = @Cd)
  begin
    delete Act	-- delete the existing record and insert it again from stageAct
    where Cd = @Cd
  end

  insert into Act
  select *  from stageAct 
  where Cd = @Cd
  
  fetch stageActSyncd into @Cd

END
close stageActSyncd
deallocate stageActSyncd

/* -------------------------------------------------------------------------------------- 
     Each Act record must exist in stageAct - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open ActSyncd
fetch ActSyncd into @Cd
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageAct where Cd = @Cd)
  begin
    delete Act	-- delete the operational record with no match to the stage table
    where Cd = @Cd
  end

  fetch ActSyncd into @Cd

END
close ActSyncd
deallocate ActSyncd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPActSync: Unable to sync the Act table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPAdminDownloadMaint]'
GO
ALTER   PROCEDURE [dbo].[ppSPAdminDownloadMaint]
(
@TableName varchar(30),
@action varchar(30)
)
AS
BEGIN

set nocount off

BEGIN TRAN

if @action = 'INS'
begin
  if NOT exists (select 1 from stageMaint where TableName = @TableName)
  begin
    Insert into stageMaint(TableName, LastAdminMaintDate)
    Values(@TableName, GetDate())
  end
end
else begin
  Delete stageMaint
  where TableName = @TableName
end

IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPAdminDownloadMaint: Unable to update the stageMaint table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

Delete stageMaint
where TableName is NULL

COMMIT TRAN
set nocount off

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPImportFromStaging]'
GO
ALTER PROCEDURE [dbo].[ppSPImportFromStaging]
(
@WorkStationId varchar(30),
@DtTm varchar(30),
@UploadBchNum int
)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible for importing PointPay staged records
    into the PayPilot operational, online data store. Staged records are loaded
    via BCP after being transferred (FTP) from the client workstations.
   ---------------------------------------------------------------------------------
*/       
AS
BEGIN
/* 
   --------------------------------------------------------------------------------- 
    Declare, and initialize, all variables that will be used by this procedure.
   ---------------------------------------------------------------------------------
*/       
    declare @howmany int, @howmanyInserted int, @howmanyHst int
    declare @BchNum int, @OrigPrtBch int, @NewPrtBch int
    declare @howmanyBch int, @howmanyBchInserted int
    declare @LogHdrId int, @RunDt int, @RunTime int, @CTpId smallint
    declare @ChkCTpId smallint, @ChkId decimal(11,0)
    declare @ChkCnt int, @VoidCnt int, @TotPay dec(14,2), @TotVoid dec(14,2)
    declare @OprId varchar(30), @FunctionTyp varchar(20)
    declare @HdrCommentTxt varchar(255), @DtlCommentTxt varchar(255)
    declare @Typ varchar(2), @PrtCd varchar(2), @RefBchNum varchar(16)
    declare @TableName varchar(50), @LogTyp varchar(10)
    declare @Status varchar(30), @SuccessStatus varchar(30), @FailureStatus varchar(30)
    declare @ChildRecordCTpId smallint, @ChildRecordChkId decimal(11,0)
    declare @OperId varchar(30), @MaxUsedChkId int, @CTpChkCnt int, @RngId smallint
    declare @ChkIssuedRecordId int, @RecordId int
    declare @HiChkId decimal(11,0), @SeqNum int, @OutSeqNum int
    declare @AppName varchar(30), @AppDesc varchar(30), @InstanceId int

    set nocount on
    set transaction isolation level serializable /* the highest level of isolation */
    
    select @RunDt   = ( select convert(int,datediff(dd,getdate(),'12/28/1800'),101) * -1 )
    select @RunTime = ( select (datepart(hh,getdate()) * 60 * 60 + datepart(mm,getdate())* 60 + datepart(ss,getdate())) * 100 )

    select top 1 
          @CTpId  = CTpId,
          @ChkCnt = count(PayAmt)
     from stageChk
    where UploadBchNum = @UploadBchNum
      and WorkStationId = @WorkStationId 
      and importdatetime is null
    group by CTpId
			
    select @TotPay  = sum(PayAmt) 
     from stageChk 
    where UploadBchNum = @UploadBchNum
      and WorkStationId = @WorkStationId 
      and importdatetime is null
      and VoidCd = 0
			
    select @TotVoid = sum(PayAmt), 
           @VoidCnt = count(PayAmt) 
     from stageChk 
    where UploadBchNum = @UploadBchNum
      and WorkStationId = @WorkStationId 
      and importdatetime is null
      and VoidCd <> 0 

    set @FunctionTyp    = 'IMPTOHOST'
    set @HdrCommentTxt  = 'PointPay Import from Staging'
    set @OprId           = 'ppImport'
    set @Typ             = 'I'
    set @PrtCd           = ' '
    set @RefBchNum       = ' '
    set @howmanyInserted = 0
    set @howmanyBchInserted = 0
    set @LogHdrId        = 0
    set @LogTyp         = 'IMPTOHOST'
    set @Status          = ''
    set @SuccessStatus   = 'Success'
    set @FailureStatus   = 'Failed'
    set @AppName         = 'ppSPImportFromStaging'
    set @AppDesc         = 'PointPay Payments Upload'
    set @InstanceId      = 0
/* 
   --------------------------------------------------------------------------------- 
    Create a Batch History record (Bch) that defines this process as an Import
    This record is created prior to beginning the Transaction in order to record
    this activity regardless of the success or failure of the entire process.
    Nore, the following Insert Bch/BcD was moved to this comment area on 3/11/2006 
    insert into Bch (Typ, Dt, Time, OperId, PrtCd, RefBchNum, WorkstationId, DateTime, PPayOprId)
    values (@Typ, @RunDt, @RunTime, @OprId, @PrtCd, @RefBchNum, @WorkStationId, @DtTm, @OprId)
    select @BchNum = scope_identity()
    Now, insert into the BcD table:
    insert into BcD (BchNum, FileName, XCnt1, XCnt2, XAmt1, XAmt2)
    values (@BchNum, @FileName, @ChkCnt, @VoidCnt, @TotPay, @TotVoid)
   ---------------------------------------------------------------------------------
    call the psiSP_LogHdrIns stored procedure which will Insert the LogHdr record,
    and it will return the LogHdrId (@LogHdrId) for use in this procedure
   ---------------------------------------------------------------------------------
*/       

    Exec @LogHdrId = psiSP_LogHdrIns @FunctionTyp, @UploadBchNum, @FailureStatus, @HdrCommentTxt, @WorkStationId, @OprId, 'R', @AppName, @AppDesc, @InstanceId
      
    UPDATE dbo.LogHdr
    SET BchNum = @UploadBchNum
    WHERE LogHdrId = @LogHdrId

/* 
   --------------------------------------------------------------------------------- 
    Count the number of Chk records which will be imported from the staging table.
    This count is used, within a Loop structure, to control the number of times
    that the Loop code is executed.
    
    Also, determine the BcH batch Num to be imported by selecting the "Top 1" record.
    Eventually the Chk table will be expanded to include the BcH.Num column
    which will allow multiple BcH batches to be imported with a single call to
    this procedure. The setting of the BcH batch Num will be done within the 
    Transaction but it will be done outside of the stageChk processing Loop.
   ---------------------------------------------------------------------------------
*/  
    select @howmanyBch = count(WorkstationId) 
      from dbo.stageBch
     where UploadBchNum = @UploadBchNum
       and WorkstationId = @WorkStationId
       and DateTime = @DtTm 
       and ImportDateTime is NULL

    if @howmanyBch is NULL begin
      set @howmanyBch = 0
    end

    if @howmanyBch = 0 begin
      set @TableName     = NULL
      set @DtlCommentTxt = 'No Bch records are available for Import for Workstation: ' + @WorkStationId + ' and DateTime: ' + @DtTm
      INSERT into dbo.LogDtl (LogHdrId, TableName, LogTyp, CommentTxt, DateTime)
      values (@LogHdrId, @TableName, @LogTyp, @DtlCommentTxt, GetDate())    
    end
    
    select @howmany = @ChkCnt
    if @howmany is NULL begin
      set @howmany = 0
    end

    if @howmany = 0 begin
      set @TableName     = NULL
      set @DtlCommentTxt = 'No Chk records are available for Import for Workstation: ' + @WorkStationId + ' and DateTime: ' + @DtTm
      INSERT into dbo.LogDtl (LogHdrId, TableName, LogTyp, CommentTxt, DateTime)
      values (@LogHdrId, @TableName, @LogTyp, @DtlCommentTxt, GetDate())    
    end

    if @howmany = 0 or @howmanyBch = 0 begin
      update dbo.LogHdr
      set status     = @SuccessStatus,
          CommentTxt = 'No Chk or Bch records are available for Import for Workstation: ' + @WorkStationId + ' and DateTime: ' + @DtTm
      where LogHdrId = @LogHdrId

      set nocount off
    
      return /* Return with a zero status to indicate a successful process */
    end
/* 
   --------------------------------------------------------------------------------- 
    Now, begin the Transaction that Inserts records into the BcH (operator batch),
    Chk, Hst, and ExA records. The source of these records is the staging tables
    that are "counterparts" of the operational data stores.
    (e.g. Chk...stageChk, Hst...stageHst)
   ---------------------------------------------------------------------------------
*/       
    BEGIN TRAN
/* --------------------------------------------------------------------------------- 
    Insert each of the Bch records, from the stageBch table
   --------------------------------------------------------------------------------- */       
  WHILE @howmanyBchInserted < @howmanyBch
    BEGIN
  /* ---------------------------------------------------------------------- 
       First, update the Out record, for the operator, with the 
       last used ChkId.
     ---------------------------------------------------------------------- */       
      select top 1 @OperId = OperId,
                   @CTpId = CTpId,
                   @MaxUsedChkId = HiChkId,
                   @CTpChkCnt = Cnt1
      from dbo.stageBch
      where WorkstationId = @WorkStationId
        and DateTime = @DtTm
        and UploadBchNum = @UploadBchNum
        and Typ = 'U' 
        and ImportDateTime is NULL

      select @RngId = RngId 
        from dbo.PayTyp 
       where Id = @CTpId

      if @RngId is NULL
      begin
        set @RngId = 0
      end

      if @CTpChkCnt is NULL
      begin
        set @CTpChkCnt = 0
      end

      select @OutSeqNum = SeqNum 
        from dbo.Out
       where OprId = @OperId
         and CTpId = @CTpId
         and RngId = @RngId
         and LowChkId <= @MaxUsedChkId
         and HiChkId >= @MaxUsedChkId
                 
      if @OutSeqNum is NULL
      begin
        set @OutSeqNum = 0
      end
      
    /* ---------------------------------------------------------------------- 
         update the Host status to "current" only if there is NOT a greater
         record that already has a "current" status.
       ---------------------------------------------------------------------- */       
      if NOT exists (
                select 1 from dbo.Out
                  where OprId = @OperId
                    and CTpId = @CTpId
                    and RngId = @RngId
                    and SeqNum > @OutSeqNum
                    and Status = 1  -- an Current record that's beyond, or greater than, the record that we are updating
                 )
      begin
          update dbo.Out
          set LastChkId = @MaxUsedChkId,
              LastChgId = @OprId,
              ChkCnt = ( HiChkId - @MaxUsedChkId ),
              Status = 1  -- this is the Current Out record
          where OprId = @OperId
            and CTpId = @CTpId
            and RngId = @RngId
            and LowChkId  <= @MaxUsedChkId
            and HiChkId   >= @MaxUsedChkId
            and LastChkId <= @MaxUsedChkId
      end
      else begin
          update dbo.Out
          set LastChkId = @MaxUsedChkId,
              LastChgId = @OprId,
              ChkCnt = ( HiChkId - @MaxUsedChkId )
          where OprId = @OperId
            and CTpId = @CTpId
            and RngId = @RngId
            and LowChkId <= @MaxUsedChkId
            and  HiChkId >= @MaxUsedChkId
            and LastChkId <= @MaxUsedChkId
      end

 /* ---------------------------------------------------------------------- 
       Next, set the Out status to "Inactive" if the ChkCnt = 0 and
       the status is "current".
     ---------------------------------------------------------------------- */       
       update dbo.Out
       set Status = 2,
           LastChgId = @OprId
       where OprId = @OperId
         and CTpId = @CTpId
         and RngId = @RngId
         and HiChkId = @MaxUsedChkId
         and ChkCnt = 0
         and Status = 1

 /* ---------------------------------------------------------------------- 
       Update prior Out reords if they are still set to Active.
     ---------------------------------------------------------------------- */       
       update dbo.Out
       set Status = 2,
           ChkCnt = 0,
           LastChkId = HiChkId,
           LastChgId = @OprId
       where OprId = @OperId
         and CTpId = @CTpId
         and RngId = @RngId
         and HiChkId <= @MaxUsedChkId
      
 /* ---------------------------------------------------------------------- 
       Is there a "next" active record that needs to be set to 
       the "current" status?
     ---------------------------------------------------------------------- */       
       if exists
                (
            select 1 from dbo.Out
	        where OprId = @OperId
          	  and CTpId = @CTpId
	          and RngId = @RngId
              and HiChkId = @MaxUsedChkId
              and Status = 2 -- we just set this to "inactive"
                 )
       begin
         if exists
                (
            select 1 from dbo.Out
	        where OprId = @OperId
          	  and CTpId = @CTpId
	          and RngId = @RngId
              and LowChkId > @MaxUsedChkId
    	      and ChkCnt > 0
          	  and Status = 0
                 )
         begin
    	/* then, set the "next" record to "Current" */
           select top 1 @SeqNum = SeqNum
  	       from dbo.Out
   	       where OprId = @OperId
      	     and CTpId = @CTpId
	         and RngId = @RngId
             and LowChkId > @MaxUsedChkId
	         and ChkCnt > 0
      	     and Status = 0
           update dbo.Out
           set Status = 1,
               LastChgId = @OprId
           where SeqNum = @SeqNum
         end
       end
      
 /* ---------------------------------------------------------------------- 
       If there are any negative values for ChkCnt, initialize them to 0
     ---------------------------------------------------------------------- */       

       update dbo.Out
          set ChkCnt = 0
        where ChkCnt < 0

  /* 
     --------------------------------------------------------------------------------- 
      Create the 1st LogDtl record for this process. First, set the TableName
      and DtlCommentTxt variables. The LogDtl record documents that we are 
      updating the Out (Outside Issue) records to synchronize the Host Out
      records with the client Out records.
     ---------------------------------------------------------------------------------
  */       
      set @TableName      = 'Out'
      set @DtlCommentTxt = 'Updated the Outside Issue table'
      INSERT into dbo.LogDtl (LogHdrId, TableName, LogTyp, CommentTxt, DateTime)
      values (@LogHdrId, @TableName, @LogTyp, @DtlCommentTxt, GetDate())

      set @TableName      = 'Out'
      set @DtlCommentTxt = 'Last Check # used for ' + @OperId + ' was: ' + convert(varchar(11),@MaxUsedChkId)
      INSERT into dbo.LogDtl (LogHdrId, TableName, LogTyp, CommentTxt, DateTime)
      values (@LogHdrId, @TableName, @LogTyp, @DtlCommentTxt, GetDate())
  /*
     ---------------------------------------------------------------------- 
       End of the updates to the Out records, for the operator, with the
       last used ChkId, ChkCnt, Status, etc.
     ----------------------------------------------------------------------

     ---------------------------------------------------------------------- 
       Continue processing by setting the OrigNum and OrigOperId values in 
       the stageBch record equal to the Bch.Num value.
     ----------------------------------------------------------------------
   */       
      Update dbo.stageBch
      Set OrigNum = Num,
          OrigOprId = OperId
      where WorkstationId = @WorkStationId
        and DateTime = @DtTm 
        and UploadBchNum = @UploadBchNum
        and (OrigNum = 0 or OrigNum is NULL)

  /*
     ---------------------------------------------------------------------- 
       Insert Bch records by transforming and copying recordds from the 
       stageBch table.
     ----------------------------------------------------------------------
   */       

      INSERT INTO dbo.Bch
      SELECT 
       	 Typ,
       	 Dt,
       	 Time,
       	 OperId,
       	 CTpId,
       	 LowChkId,
       	 HiChkId,
       	 PrtCd,
       	 BckCd,
       	 SndCd,
       	 SndDt,
       	 RepRsn,
       	 Amt1,
       	 Amt2,
       	 Amt3,
       	 Amt4,
       	 Amt5,
       	 Amt6,
       	 Amt7,
       	 Amt8,
       	 Cnt1,
       	 Cnt2,
    	 Cnt3,
       	 Cnt4,
       	 Cnt5,
       	 Cnt6,
   	     Cnt7,
       	 Cnt8,
       	 MultCd,
       	 MultTyp,
       	 FilNam,
       	 EftTxt,
       	 EftNum,
       	 EftCls,
       	 EftDesc,
       	 EftDt,
       	 EftEffDt,
       	 RefBchNum,
       	 XCd1,
       	 XCd2,
       	 XCd3,
       	 XCd4,
       	 XCd5,
       	 XNum1,
       	 XNum2,
       	 XNum3,
       	 XAmt1,
       	 XAmt2,
       	 XAmt3,
       	 DateTime,
       	 WorkstationId,
       	 UploadBchNum,
       	 OrigNum,
       	 OrigOprId,
       	 OrigDateTime,
         PreventBackout,
         NULL as RunId
       FROM dbo.stageBch
--       WHERE OrigNum = @UploadBchNum
--         AND WorkstationId    = @WorkStationId
       WHERE WorkstationId = @WorkStationId
         AND DateTime      = @DtTm 
         AND ImportDateTime is NULL
      SELECT @BchNum = scope_identity()

      SET @howmanyBchInserted = @howmanyBchInserted + 1

/* 
   --------------------------------------------------------------------------------- 
    Update the stageBcH record with the Import date and time as well as the 
    procedure's Operator Id. This prevents the batch from being imported a 2nd time.
   ---------------------------------------------------------------------------------
*/       
      UPDATE dbo.stageBcH
      SET ImportDateTime = GetDate(),
          ImportOprId = @OprId
--       WHERE OrigNum = @UploadBchNum
--         AND WorkstationId = @WorkStationId
--         AND DateTime = @DtTm 
--         AND ImportDateTime is NULL
       WHERE WorkstationId = @WorkStationId
         AND DateTime      = @DtTm 
         AND ImportDateTime is NULL
/* 
   --------------------------------------------------------------------------------- 
    Create the 2nd LogDtl record for this process. First, set the TableName
    and DtlCommentTxt variables. The LogDtl record documents that we are 
    importing the BcH (Batch Operator) record from the stageBcH table.
   ---------------------------------------------------------------------------------
*/       
      set @TableName      = 'BcH'
      set @DtlCommentTxt = 'Inserted BcH Batch: ' + rtrim(@BchNum) + ' from stageBch: ' + rtrim(@UploadBchNum)
      
      INSERT into dbo.LogDtl (LogHdrId, TableName, LogTyp, CommentTxt, DateTime)
      values (@LogHdrId, @TableName, @LogTyp, @DtlCommentTxt, GetDate())
      
    END /* END of Bch Loop */
   
/* 
   --------------------------------------------------------------------------------- 
    Begin importing each stageChk record, and it's associated "child" records,
    within the Loop (WHILE) structure. We use the @howmany variable (derived
    above) to determine the # of times to process stageChk records, within the
    Loop. This process MUST be updated to also use the BcHNum column in order to import
    only the stageChk records that belong to the specific BcH batch.
   ---------------------------------------------------------------------------------
*/       
    WHILE @howmanyInserted < @howmany
    BEGIN
/* --------------------------------------------------------------------------------- 
    Get the CTpId and Id for the record that will be imported.
   --------------------------------------------------------------------------------- */       
      SELECT top 1 @ChkCTpId = CTpId, @ChkId = Id, @RecordId = RecordId
      FROM dbo.stageChk
      WHERE WorkstationId = @WorkStationId
        AND UploadBchNum = @UploadBchNum
        AND ImportDateTime is NULL
        
/* --------------------------------------------------------------------------------- 
    Does this payment (CTpId and Id) exist already in the operational table?
   --------------------------------------------------------------------------------- */       
      IF EXISTS
    	(
    	   SELECT 1 FROM dbo.Chk
	        WHERE CTpId = @ChkCTpId
                  AND Id = @ChkId
    	)
      BEGIN
        update dbo.LogHdr
        set CommentTxt = @HdrCommentTxt + ', duplicate payments found in the Operational Chk table'
        where LogHdrId = @LogHdrId

        insert into dbo.stageChkDup
        select * from dbo.stageChk
         where CTpId = @ChkCTpId
           and Id = @ChkId
           and UploadBchNum = @UploadBchNum
          
        update dbo.stageChk
        set ImportDateTime = GetDate()
        where RecordId = @RecordId
          and UploadBchNum = @UploadBchNum
          and ImportDateTime is NULL

        set @DtlCommentTxt = 'DUPLICATE CTpId: ' + convert(varchar(11),@ChkCTpId) + ', Id: ' + convert(varchar(11),@ChkId) 
        set @TableName = 'stageChkDup'
      
        insert into dbo.LogDtl (LogHdrId, TableName, LogTyp, CommentTxt, DateTime)
        values (@LogHdrId, @TableName, @LogTyp, @DtlCommentTxt, GetDate())
        
        insert into dbo.stageHstDup
        select * from dbo.stageHst
         where CTpId = @ChkCTpId
           and Id = @ChkId
           and UploadBchNum = @UploadBchNum
           and ImportDateTime is NULL

        update dbo.stageHst
        set ImportDateTime = GetDate()
        where CTpId = @ChkCTpId
          and Id = @ChkId
          and UploadBchNum = @UploadBchNum
          and ImportDateTime is NULL
          
        set @howmanyInserted = @howmanyInserted + 1

        CONTINUE    -- proceed to the top of the While Loop to read the next stageChk record

      END
/* --------------------------------------------------------------------------------- 
    Insert the Chk record, from the stageChk record, the RecordId is an Identity
    column.
   --------------------------------------------------------------------------------- */       
      SELECT @OrigPrtBch = PrtBch 
        FROM dbo.stageChk 
       WHERE RecordId = @RecordId
         AND UploadBchNum = @UploadBchNum
         AND PrtBch is NOT NULL
         AND PrtBch <> 0
         
      IF @OrigPrtBch is NOT NULL and @OrigPrtBch <> 0
      BEGIN
        SELECT @NewPrtBch = Num
          FROM dbo.Bch
         WHERE OrigNum = @OrigPrtBch

        UPDATE stageChk
           Set PrtBch = @NewPrtBch
         WHERE RecordId = @RecordId
           AND UploadBchNum = @UploadBchNum
           AND PrtBch <> 0

        UPDATE stageHst
           Set PrtBch = @NewPrtBch
         WHERE CTpId = @ChkCTpId
           AND Id = @ChkId
           AND PrtBch <> 0
      END

      INSERT INTO dbo.Chk
      SELECT *
        FROM dbo.vstageChk
       WHERE CTpId = @ChkCTpId
         AND Id = @ChkId
         AND UploadBchNum = @UploadBchNum
 
      INSERT INTO dbo.ChkIssued (RecordId) -- this supports view vChkExport
      SELECT RecordId
        FROM dbo.Chk 
       WHERE CTpId = @ChkCTpId
         AND Id = @ChkId
         AND IssDt <> 0 /* an Issued Chk */

      set @howmanyInserted = @howmanyInserted + 1
/* --------------------------------------------------------------------------------- 
    Derive the Comment field, for the LogDtl record, the Payment Type (CTpId), and
    the Check Id (Id) from the stageChk record that we just inserted into the Chk table.
   --------------------------------------------------------------------------------- */       
     select @DtlCommentTxt   = (
                                 select top 1 'CTpId: ' + rtrim(CTpId) + ', Id: ' + rtrim(Id)
                                 from dbo.vstageChk
     where CTpId = @ChkCTpId
       and Id = @ChkId
                                  )
/* --------------------------------------------------------------------------------- 
    Set the TableName to 'Chk', for the LogDtl record insert, and insert the LogDtl
    record. We are inserted a record with the columns = the variables derived above.
   --------------------------------------------------------------------------------- */       
      set @TableName = 'Chk'
      
      insert into dbo.LogDtl (LogHdrId, TableName, LogTyp, CommentTxt, DateTime)
      values (@LogHdrId, @TableName, @LogTyp, @DtlCommentTxt, GetDate())
    
/* --------------------------------------------------------------------------------- 
    Set the Datetime/Operator stamp for the imported stageChk record. This prevents
    the record from being imported again, and it provides an audit trail of imported
    records.
   --------------------------------------------------------------------------------- */       
      update dbo.stageChk
      set ImportDateTime = GetDate()
      where RecordId = @RecordId
        and UploadBchNum = @UploadBchNum
        and ImportDateTime is NULL
/* --------------------------------------------------------------------------------- 
    Insert the Hst record(s), from the stageHst record, using the 
    CTpId and Check Id that were derived above for the "child" records.
   --------------------------------------------------------------------------------- */      
      INSERT INTO dbo.Hst
      SELECT *
      FROM dbo.vstageHst
      WHERE CTpId = @ChkCTpId
        AND Id = @ChkId
        AND UploadBchNum = @UploadBchNum

/* After the Hst rows have been inserted, updte their ChkRecordId to associate to their parent Chk row */        
      UPDATE dbo.Hst
      SET ChkRecordId = (
            SELECT RecordId
              FROM dbo.Chk 
             WHERE CTpId = @ChkCTpId
               AND Id = @ChkId
                    )
      WHERE CTpId = @ChkCTpId
        AND Id = @ChkId
        AND ChkRecordId is NULL
        
/* --------------------------------------------------------------------------------- 
    Derive the Comment field, for the LogDtl record, the Payment Type (CTpId), and
    the Check Id (Id) from the stageHst record that we just inserted into the Hst table.
   --------------------------------------------------------------------------------- */       
      IF EXISTS
            (
             select 1
               from dbo.vstageHst
              where CTpId = @ChkCTpId
                and Id = @ChkId
                and UploadBchNum = @UploadBchNum
              )
      BEGIN
        SET @DtlCommentTxt = (
                                select top 1 'CTpId: ' + rtrim(CTpId) + ', Id: ' + rtrim(Id)
                                from dbo.vstageHst
                                where CTpId = @ChkCTpId
                                  and Id = @ChkId
                                  and UploadBchNum = @UploadBchNum
                            )
                     
        SET @howmanyHst = (
                        select count(*)
                            from dbo.vstageHst
                            where CTpId = @ChkCTpId
                              and Id = @ChkId
                              and UploadBchNum = @UploadBchNum
                            )  
        SET @DtlCommentTxt = @DtlCommentTxt + ', Hst record count for this Chk = ' + convert(varchar(5),@howmanyHst)
      END
      IF NOT EXISTS
            (
             select 1
               from dbo.vstageHst
              where CTpId = @ChkCTpId
                and Id = @ChkId
                and UploadBchNum = @UploadBchNum
              )
      BEGIN
        SET @DtlCommentTxt = 'No Hst records are available for Import'
      END
/* --------------------------------------------------------------------------------- 
    Set the TableName to 'Hst', for the LogDtl record insert, and insert the LogDtl
    record. We are inserted a record with the columns = the variables derived above.
   --------------------------------------------------------------------------------- */       
      set @TableName = 'Hst'

      insert into dbo.LogDtl (LogHdrId, TableName, LogTyp, CommentTxt, DateTime)
      values (@LogHdrId, @TableName, @LogTyp, @DtlCommentTxt, GetDate())
    
/* --------------------------------------------------------------------------------- 
    Set the Datetime/Operator stamp for the imported stageHst record. This prevents
    the record from being imported again, and it provides an audit trail of imported
    records.
   --------------------------------------------------------------------------------- */       
      update dbo.stageHst
      set ImportDateTime = GetDate()
      where CTpId = @ChkCTpId
        and Id = @ChkId
        and UploadBchNum = @UploadBchNum
        and ImportDateTime is NULL

    END /* END of stageChk record Loop */

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing to this point. Update the LogHdr record with the appropriate "success"
    or "failure" status.
   --------------------------------------------------------------------------------- */       
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPImportFromStaging: Cannot insert data into ppSPImportFromStaging'
        ROLLBACK TRAN

        update dbo.LogHdr
    set status = @FailureStatus
        where LogHdrId = @LogHdrId

        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
  
    update dbo.LogHdr
    set status = @SuccessStatus
    where LogHdrId = @LogHdrId

    COMMIT TRAN

    set nocount off
    
    RETURN /* Return with a zero status to indicate a successful process */

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPBnkMaint]'
GO
ALTER procedure [dbo].[ppSPBnkMaint]
as

declare @Id int

declare BnkUpdtd cursor for
select Id FROM Bnk

declare stageBnkUpdtd cursor for
select Id FROM stageBnk

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open BnkUpdtd
fetch BnkUpdtd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each Bnk record and make sure that stageBnk records are Identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from stageBnk where Id = @Id)
  begin
    delete stageBnk	-- delete the existing record and insert it again from Bnk
    where Id = @Id
  end

  insert into stageBnk
  select * from Bnk
  where Id = @Id

  fetch BnkUpdtd into @Id

END
close BnkUpdtd
deallocate BnkUpdtd

/* -------------------------------------------------------------------------------------- 
     Each stageBnk record must exist in Bnk - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open stageBnkUpdtd
fetch stageBnkUpdtd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from Bnk where Id = @Id)
  begin
    delete stageBnk	-- delete the stage record with no match to the operational table
    where Id = @Id
  end

  fetch stageBnkUpdtd into @Id

END
close stageBnkUpdtd
deallocate stageBnkUpdtd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing to this point.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPBnkMaint: Cannot update the stageBnk table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off

Exec ppSPLastMaintDate


 --identifies the last time that Admin maintenance was applied
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPBnkSync]'
GO
ALTER procedure [dbo].[ppSPBnkSync]
(
@LogHdrId int
)
as

declare @id int

declare stageBnkSyncd cursor for
select Id FROM stageBnk

declare BnkSyncd cursor for
select Id FROM Bnk

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageBnkSyncd
fetch stageBnkSyncd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageBnk record and make sure that Bnk records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Bnk where Id = @Id)
  begin
    delete Bnk	-- delete the existing record and insert it again from stageBnk
    where Id = @Id
  end

  insert into Bnk
  select *  from stageBnk 
  where Id = @Id
  
  fetch stageBnkSyncd into @Id

END
close stageBnkSyncd
deallocate stageBnkSyncd

/* -------------------------------------------------------------------------------------- 
     Each Bnk record must exist in stageBnk - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open BnkSyncd
fetch BnkSyncd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageBnk where Id = @Id)
  begin
    delete Bnk	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch BnkSyncd into @Id

END
close BnkSyncd
deallocate BnkSyncd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPBnkSync: Unable to sync the Bnk table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPBTpMaint]'
GO
ALTER procedure [dbo].[ppSPBTpMaint]
as

declare @Id int

declare BTpUpdtd cursor for
select Id FROM BTp

declare stageBTpUpdtd cursor for
select Id FROM stageBTp

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open BTpUpdtd
fetch BTpUpdtd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each BTp record and make sure that stageBTp records are Identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from stageBTp where Id = @Id)
  begin
    delete stageBTp	-- delete the existing record and insert it again from BTp
    where Id = @Id
  end

  insert into stageBTp
  select * from BTp
  where Id = @Id

  fetch BTpUpdtd into @Id

END
close BTpUpdtd
deallocate BTpUpdtd

/* -------------------------------------------------------------------------------------- 
     Each stageBTp record must exist in BTp - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open stageBTpUpdtd
fetch stageBTpUpdtd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from BTp where Id = @Id)
  begin
    delete stageBTp	-- delete the stage record with no match to the operational table
    where Id = @Id
  end

  fetch stageBTpUpdtd into @Id

END
close stageBTpUpdtd
deallocate stageBTpUpdtd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing to this point.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPBTpMaint: Cannot update the stageBTp table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off

Exec ppSPLastMaintDate



 --identifies the last time that Admin maintenance was applied
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPBTpSync]'
GO
ALTER  procedure [dbo].[ppSPBTpSync]
(
@LogHdrId int
)
as

declare @id varchar(16)

declare stageBTpSyncd cursor for
select Id FROM stageBTp

declare BTpSyncd cursor for
select Id FROM BTp

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageBTpSyncd
fetch stageBTpSyncd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageBTp record and make sure that BTp records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from BTp where Id = @Id)
  begin
    delete BTp	-- delete the existing record and insert it again from stageBTp
    where Id = @Id
  end

  insert into BTp
  select *  from stageBTp 
  where Id = @Id
  
  fetch stageBTpSyncd into @Id

END
close stageBTpSyncd
deallocate stageBTpSyncd

/* -------------------------------------------------------------------------------------- 
     Each BTp record must exist in stageBTp - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open BTpSyncd
fetch BTpSyncd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageBTp where Id = @Id)
  begin
    delete BTp	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch BTpSyncd into @Id

END
close BTpSyncd
deallocate BTpSyncd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPBTpSync: Unable to sync the BTp table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPCalSync]'
GO
ALTER procedure [dbo].[ppSPCalSync]
(
@LogHdrId int
)
as

declare @RecordId int

declare stageCalSynRecordId cursor for
select RecordId FROM stageCal

declare CalSynRecordId cursor for
select RecordId FROM Cal

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageCalSynRecordId
fetch stageCalSynRecordId into @RecordId
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageCal record and make sure that Cal records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Cal where RecordId = @RecordId)
  begin
    delete Cal	-- delete the existing record and insert it again from stageCal
    where RecordId = @RecordId
  end

  set identity_insert Cal on

  insert into Cal
  	(RecordId,
	 Dt,
	 Type,
	 DescTxt,
	 XCd1,
	 XCd2,
	 XCd3,
	 XCd4,
	 XCd5,
	 XNum1,
	 XNum2,
	 XNum3,
	 LastChgId,
	 LastChgDt,
	 LastChgTm)
  select 	RecordId,
	Dt,
	Type,
	DescTxt,
	XCd1,
	XCd2,
	XCd3,
	XCd4,
	XCd5,
	XNum1,
	XNum2,
	XNum3,
	LastChgId,
	LastChgDt,
	LastChgTm
  from stageCal 
  where RecordId = @RecordId

  set identity_insert Cal off
  
  fetch stageCalSynRecordId into @RecordId

END
close stageCalSynRecordId
deallocate stageCalSynRecordId

/* -------------------------------------------------------------------------------------- 
     Each Cal record must exist in stageCal - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open CalSynRecordId
fetch CalSynRecordId into @RecordId
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageCal where RecordId = @RecordId)
  begin
    delete Cal	-- delete the operational record with no match to the stage table
    where RecordId = @RecordId
  end

  fetch CalSynRecordId into @RecordId

END
close CalSynRecordId
deallocate CalSynRecordId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransCalion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPCalSync: Unable to sync the Cal table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPChkPayInsert]'
GO
ALTER  procedure [dbo].[ppSPChkPayInsert]
(
@ParmRunId varchar(18)
)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is a major participant in the Chk import process. This
    procedure is responsible for migrating the "staged" Pay data to the operational
    tables.
   ---------------------------------------------------------------------------------
*/
AS
BEGIN
    
    if @ParmRunId is NULL or @ParmRunId = ''
    begin
      return
    end
    
    declare @ImpBch int, @LogHdrId int, @RecordsToProcess int, @RecordsProcessed int, @RcnBch int
    
    update ImportRequest
       set StartDt   = convert(int,datediff(dd, '12/28/1800',getdate())),
           StartTime = datediff(s, dateadd(dd, datediff(dd,0,getdate()), 0), getdate()) * 100
     where RunId = @ParmRunId
    
    select @ImpBch   = BchNum,
           @LogHdrId = LogHdrId
      from ImportRequest
     where RunId = @ParmRunId
    
    select @RecordsToProcess = (
                        select count(CTpId) from stageChkPay
                        where ImpBch = @ImpBch
                                )
     
    set nocount on

    set rowcount 100      /* process 100 records within each iteration of the loop */

    begin tran
/* 
   --------------------------------------------------------------------------------- 
    Import the Chk record if it does not exist already on the Chk table.
   ---------------------------------------------------------------------------------
*/
    while @RecordsProcessed < @RecordsToProcess
    begin
  
    
      insert into Chk (
  		  CTpId,
  		  Id,
  		  AltSrt,
  		  AltSrt1,
  		  ModVer,
  		  CmpId,
  		  PayToNam1,
  		  IssDt,
  		  PayAmt,
  		  BnkId,
  		  VoidCd,
  		  VoidId,
  		  VoidDt,
  		  AddDt,
  		  AddTime,
  		  AddId,
  		  SrceCd,
  		  RepRsn,
  		  TranDt,
  		  TranTime,
  		  TranTyp,
  		  TranId,
  		  PrtDt,
  		  PrtBch,
  		  PrtCnt,
  		  ImpBch,
  		  PdCd,
  		  PdDt,
  		  PdBch,
  		  MailToNam,
  		  MailToAdr1,
  		  MailToAdr2,
  		  MailToAdr3,
  		  MailToAdr4,
  		  InsNam,
  		  InsAdr1,
  		  InsAdr2,
  		  InsAdr3,
  		  InsAdr4,
  		  VndTyp,
  		  VndId,
  		  PayCd,
  		  PayToCd,
  		  Dt1,
  		  Dt2,
  		  XCd1,
  		  XCd2,
  		  XCd3,
  		  XCd4,
  		  XCd5,
  		  SalaryAmt,
  		  XAmt1,
  		  XAmt2,
  		  XAmt3,
  		  XAmt4,
  		  XAmt5,
  		  XAmt6,
  		  XAmt7,
  		  XAmt8,
  		  XAmt9,
  		  XAmt10,
  		  Office,
  		  PolId,
  		  MaritalStat,
  		  FedExempt,
  		  StateExempt,
  		  XRate1,
  		  XRate2,
  		  LstNam,
  		  FstNam,
  		  MidInit,
  		  Salutation,
  		  DiagCd1,
  		  DiagCd2,
  		  FrmCd,
  		  PstCd,
  		  RestCd,
  		  ForRsn1,
  		  ForRsn2,
  		  CommentTxt,
  		  DeptCd,
  		  MailStop,
  		  ReqId,
          RcnBch
              )
  	  select 
	      CTpId,
  		  Id,
  		  AltSrt,
  		  AltSrt1,
  		  ModVer,
  		  CmpId,
  		  PayToNam1,
  		  IssDt,
  		  PayAmt,
  		  BnkId,
  		  VoidCd,
  		  VoidId,
  		  VoidDt,
  		  AddDt,
  		  AddTime,
  		  AddId,
  		  SrceCd,
  		  RepRsn,
  		  TranDt,
  		  TranTime,
  		  TranTyp,
  		  TranId,
  		  PrtDt,
  		  PrtBch,
  		  PrtCnt,
  		  ImpBch,
  		  PdCd,
  		  PdDt,
  		  PdBch,
  		  MailToNam,
  		  MailToAdr1,
  		  MailToAdr2,
  		  MailToAdr3,
  		  MailToAdr4,
  		  InsNam,
  		  InsAdr1,
  		  InsAdr2,
  		  InsAdr3,
  		  InsAdr4,
  		  VndTyp,
  		  VndId,
  		  PayCd,
  		  PayToCd,
  		  Dt1,
  		  Dt2,
  		  XCd1,
  		  XCd2,
  		  XCd3,
  		  XCd4,
  		  XCd5,
  		  SalaryAmt,
  		  XAmt1,
  		  XAmt2,
  		  XAmt3,
  		  XAmt4,
  		  XAmt5,
  		  XAmt6,
  		  XAmt7,
  		  XAmt8,
  		  XAmt9,
  		  XAmt10,
  		  Office,
  		  PolId,
  		  MaritalStat,
  		  FedExempt,
  		  StateExempt,
  		  XRate1,
  		  XRate2,
  		  LstNam,
  		  FstNam,
  		  MidInit,
  		  Salutation,
  		  DiagCd1,
  		  DiagCd2,
  		  FrmCd,
  		  PstCd,
  		  RestCd,
  		  ForRsn1,
  		  ForRsn2,
  		  CommentTxt,
  		  DeptCd,
  		  MailStop,
  		  ReqId,
          @RcnBch
      from stageChkPay
      where ImpBch = @ImpBch
        and CTpId not in (select CTpId from Chk)
        and Id    not in (select Id from Chk)
      
      select @RecordsProcessed = (
                select count(c.Id) 
                from Chk c
                inner join stageChkPay s on s.CTpId = c.CTpId and s.Id = c.Id
                                )
      
    end /* end while loop */
    
    set rowcount 0
/* 
   --------------------------------------------------------------------------------- 
    Import the Txt records that are associated with the parent (Chk) record.
   ---------------------------------------------------------------------------------
*/
    insert into Txt (
		CTpId,
		ChkId,
		SeqNum,
		TextLine,
		XCd1,
		XCd2,
		XCd3,
		XCd4,
		XCd5
            )
    select 
		CTpId,
		ChkId,
		SeqNum,
		TextLine,
		XCd1,
		XCd2,
		XCd3,
		XCd4,
		XCd5
    from StageTxtPay
    where RunId = @ParmRunId

/* 
   --------------------------------------------------------------------------------- 
    Import the Vch records that are associated with the parent (Chk) record.
   ---------------------------------------------------------------------------------
*/
    insert into Vch (
      	CTpId,
		ChkId,
		SeqNum,
		DescTxt,
		InvId,
		NetAmt,
		AmtPd,
		TranCd,
		XCd1,
		XCd2,
		XCd3,
		XCd4,
		XCd5,
		XCd6,
		XCd7,
		Dt1,
		Dt2,
		PayRate,
		XRate1,
		XRate2,
		XRate3,
		XRate4,
		XRate5,
		Qty1,
		Qty2,
		CshAcct,
		ExpAcct,
		CostCtr
            )
    select 
      	CTpId,
		ChkId,
		SeqNum,
		DescTxt,
		InvId,
		NetAmt,
		AmtPd,
		TranCd,
		XCd1,
		XCd2,
		XCd3,
		XCd4,
		XCd5,
		XCd6,
		XCd7,
		Dt1,
		Dt2,
		PayRate,
		XRate1,
		XRate2,
		XRate3,
		XRate4,
		XRate5,
		Qty1,
		Qty2,
		CshAcct,
		ExpAcct,
		CostCtr
    from StageVchPay
    where RunId = @ParmRunId
      
    if (@@error!=0)
    begin
      --RAISERROR  20000 'ppSPChkPayInsert: import failed from the stageChkPay table to the Chk Table'
      ROLLBACK
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    end
      
    update ImportRequest
       set RecordsProcessed = (
                    select count(CTpId) from stageChkPay
                    where ImpBch = @ImpBch
                               )
    where RunId = @ParmRunId
       
    commit  /* commit transaction */

    set nocount off

end

 /* end of stored procedure */
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPChSSync]'
GO
ALTER procedure [dbo].[ppSPChSSync]
(
@LogHdrId int
)
as

declare @Id smallint

declare stageChSSynId cursor for
select Id FROM stageChS

declare ChSSynId cursor for
select Id FROM ChS

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageChSSynId
fetch stageChSSynId into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageChS record and make sure that ChS records are identiChS
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from ChS where Id = @Id)
  begin
    delete ChS	-- delete the existing record and insert it again from stageChS
    where Id = @Id
  end

  insert into ChS
  select 	* from stageChS 
  where Id = @Id
  
  fetch stageChSSynId into @Id

END
close stageChSSynId
deallocate stageChSSynId

/* -------------------------------------------------------------------------------------- 
     Each ChS record must exist in stageChS - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open ChSSynId
fetch ChSSynId into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageChS where Id = @Id)
  begin
    delete ChS	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch ChSSynId into @Id

END
close ChSSynId
deallocate ChSSynId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransChSion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPChSSync: Unable to sync the ChS table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the ChSling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPClmSync]'
GO
ALTER procedure [dbo].[ppSPClmSync]
(
@LogHdrId int
)
as

set nocount on

 set identity_insert Clm on
 
 insert into Clm
  	(Id,
	Num,
	LosDt,
	PolId,
	CmpId,
	InsNam,
	AgentTyp,
	AgentId,
	AddDt,
	ChgDt)
  select 
  	Id,
	Num,
	LosDt,
	PolId,
	CmpId,
	InsNam,
	AgentTyp,
	AgentId,
    AddDt,
	ChgDt
  from stageClm 
  where Id not in (select Id from Clm)
    and Num not in (select Num from Clm)

  set identity_insert Clm off

  IF (@@error!=0)
  BEGIN
    --RAISERROR  20000 'ppSPClmSync: Unable to sync (Insert) to the Clm table (1)'
    print 'completed the inserts, but with errors...'
    RETURN
  END

  update c
      set 
        c.LosDt         = s.LosDt,
        c.PolId          = s.PolId,
    	c.CmpId        = s.CmpId,
    	c.InsNam       = s.InsNam,
    	c.AgentTyp     = s.AgentTyp,
    	c.AgentId       = s.AgentId,
    	c.AddDt         = s.AddDt,
    	c.ChgDt         = s.ChgDt
  from dbo.Clm c
  inner join stageClm s on s.Id = c.Id and s.Num = c.Num
  
  IF (@@error!=0)
  BEGIN
    --RAISERROR  20000 'ppSPClmSync: Unable to sync (update) to the Clm table (1)'
    print 'completed the updates to the Clm table, but without error'
    RETURN
  END
  
  print 'completed the updates to the Clm table without error'

set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPCntSync]'
GO
ALTER procedure [dbo].[ppSPCntSync]
(
@LogHdrId int
)
as

declare @Id varchar(15)

declare stageCntSynId cursor for
select Id FROM stageCnt

declare CntSynId cursor for
select Id FROM Cnt

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageCntSynId
fetch stageCntSynId into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageCnt record and make sure that Cnt records are identiCnt
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Cnt where Id = @Id)
  begin
    delete Cnt	-- delete the existing record and insert it again from stageCnt
    where Id = @Id
  end

  insert into Cnt
  select 	* from stageCnt 
  where Id = @Id
  
  fetch stageCntSynId into @Id

END
close stageCntSynId
deallocate stageCntSynId

/* -------------------------------------------------------------------------------------- 
     Each Cnt record must exist in stageCnt - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open CntSynId
fetch CntSynId into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageCnt where Id = @Id)
  begin
    delete Cnt	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch CntSynId into @Id

END
close CntSynId
deallocate CntSynId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransCntion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPCntSync: Unable to sync the Cnt table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the Cntling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPComMaint]'
GO
ALTER procedure [dbo].[ppSPComMaint]
as

declare @Id smallint

declare ComUpdtd cursor for
select Id FROM Com

declare stageComUpdtd cursor for
select Id FROM stageCom

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open ComUpdtd
fetch ComUpdtd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each Com record and make sure that stageCom records are Identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from stageCom where Id = @Id)
  begin
    delete stageCom	-- delete the existing record and insert it again from Com
    where Id = @Id
  end

  insert into stageCom
  select * from Com
  where Id = @Id

  fetch ComUpdtd into @Id

END
close ComUpdtd
deallocate ComUpdtd

/* -------------------------------------------------------------------------------------- 
     Each stageCom record must exist in Com - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open stageComUpdtd
fetch stageComUpdtd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from Com where Id = @Id)
  begin
    delete stageCom	-- delete the stage record with no match to the operational table
    where Id = @Id
  end

  fetch stageComUpdtd into @Id

END
close stageComUpdtd
deallocate stageComUpdtd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing to this point.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPComMaint: Cannot update the stageCom table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off

Exec ppSPLastMaintDate



 --identifies the last time that Admin maintenance was applied
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPComSync]'
GO
ALTER procedure [dbo].[ppSPComSync]
(
@LogHdrId int
)
as

declare @id smallint

declare stageComSyncd cursor for
select Id FROM stageCom

declare ComSyncd cursor for
select Id FROM Com

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageComSyncd
fetch stageComSyncd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageCom record and make sure that Com records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Com where Id = @Id)
  begin
    delete Com	-- delete the existing record and insert it again from stageCom
    where Id = @Id
  end

  set identity_insert Com on
  
  insert into Com (
	Id,
	DescTxt,
	BaudRate,
	Parity,
	Data,
	Stop,
	Port,
	Locked,
	DialDelay,
	DialTimeout,
	ModemInit,
	DialPrefix,
	DialSuffix,
	ConnectString,
	Error1,
	Error2,
	Error3,
	Error4,
	AbortDial,
	Hangup,
	RedialAbort,
	FTPCd,
	FTPTyp,
	FTPPgm,
	Protocol,
	PhoneNumber,
	PhoneNumber2,
	UserName,
	Password,
	AccountNum,
	OptionNum,
	LogOnStr,
	LogOffStr,
	FilNam,
	IPAdr,
	LogOnFilNam,
	AckFilNam,
	LastChgId,
	LastChgDt,
	LastChgTm,
	Prompt1,
	Prompt2,
	Prompt3,
	Prompt4,
	Prompt5,
	Prompt6,
	Prompt7,
	Prompt8,
	Prompt9,
	Prompt10,
	Prompt11,
	Prompt12,
	Prompt13,
	Prompt14,
	Prompt15,
	Prompt16,
	Prompt17,
	Prompt18,
	Prompt19,
	Prompt20,
	Response1,
	Response2,
	Response3,
	Response4,
	Response5,
	Response6,
	Response7,
	Response8,
	Response9,
	Response10,
	Response11,
	Response12,
	Response13,
	Response14,
	Response15,
	Response16,
	Response17,
	Response18,
	Response19,
	Response20,
	UserDefined1,
	UserDefined2,
	UserDefined3,
	UserDefined4,
	UserDefined5,
	UserDefined6,
	UserDefined7,
	UserDefined8,
	UserDefined9,
	UserDefined10,
	UserDefined11,
	UserDefined12,
	UserDefined13,
	UserDefined14,
	UserDefined15,
	UserDefined16,
	UserDefined17,
	UserDefined18,
	UserDefined19,
	UserDefined20,
	HostFilNam,
	XCd1,
	XCd2,
	XCd3,
	XCd4,
	XCd5,
	XCd6,
	XCd7,
	XCd8,
	XCd9,
	XCd10,
	XCd11,
	XCd12,
	XCd13,
	XCd14,
	XCd15,
	RemoteDir,
	RemoteFileName,
	HostSubDir,
	HostFileSet,
	LocalPath,
	LocalFileSet,
	StatPath,
	CopyToPath,
	LogTyp,
	LogFilePath,
	LogFileName,
	FTPPort,
	WinTitle,
	DynStatFileName,
	PassiveMode,
	HideProgressWin,
	ActionAfterTransfer
        )
  select
	Id,
	DescTxt,
	BaudRate,
	Parity,
	Data,
	Stop,
	Port,
	Locked,
	DialDelay,
	DialTimeout,
	ModemInit,
	DialPrefix,
	DialSuffix,
	ConnectString,
	Error1,
	Error2,
	Error3,
	Error4,
	AbortDial,
	Hangup,
	RedialAbort,
	FTPCd,
	FTPTyp,
	FTPPgm,
	Protocol,
	PhoneNumber,
	PhoneNumber2,
	UserName,
	Password,
	AccountNum,
	OptionNum,
	LogOnStr,
	LogOffStr,
	FilNam,
	IPAdr,
	LogOnFilNam,
	AckFilNam,
	LastChgId,
	LastChgDt,
	LastChgTm,
	Prompt1,
	Prompt2,
	Prompt3,
	Prompt4,
	Prompt5,
	Prompt6,
	Prompt7,
	Prompt8,
	Prompt9,
	Prompt10,
	Prompt11,
	Prompt12,
	Prompt13,
	Prompt14,
	Prompt15,
	Prompt16,
	Prompt17,
	Prompt18,
	Prompt19,
	Prompt20,
	Response1,
	Response2,
	Response3,
	Response4,
	Response5,
	Response6,
	Response7,
	Response8,
	Response9,
	Response10,
	Response11,
	Response12,
	Response13,
	Response14,
	Response15,
	Response16,
	Response17,
	Response18,
	Response19,
	Response20,
	UserDefined1,
	UserDefined2,
	UserDefined3,
	UserDefined4,
	UserDefined5,
	UserDefined6,
	UserDefined7,
	UserDefined8,
	UserDefined9,
	UserDefined10,
	UserDefined11,
	UserDefined12,
	UserDefined13,
	UserDefined14,
	UserDefined15,
	UserDefined16,
	UserDefined17,
	UserDefined18,
	UserDefined19,
	UserDefined20,
	HostFilNam,
	XCd1,
	XCd2,
	XCd3,
	XCd4,
	XCd5,
	XCd6,
	XCd7,
	XCd8,
	XCd9,
	XCd10,
	XCd11,
	XCd12,
	XCd13,
	XCd14,
	XCd15,
	RemoteDir,
	RemoteFileName,
	HostSubDir,
	HostFileSet,
	LocalPath,
	LocalFileSet,
	StatPath,
	CopyToPath,
	LogTyp,
	LogFilePath,
	LogFileName,
	FTPPort,
	WinTitle,
	DynStatFileName,
	PassiveMode,
	HideProgressWin,
	ActionAfterTransfer
  from dbo.stageCom
  where Id = @Id
  
  set identity_insert Com off
  
  fetch stageComSyncd into @Id

END
close stageComSyncd
deallocate stageComSyncd

/* -------------------------------------------------------------------------------------- 
     Each Com record must exist in stageCom - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open ComSyncd
fetch ComSyncd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageCom where Id = @Id)
  begin
    delete Com	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch ComSyncd into @Id

END
close ComSyncd
deallocate ComSyncd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPComSync: Unable to sync the Com table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPConvertFromStaging]'
GO
ALTER PROCEDURE [dbo].[ppSPConvertFromStaging]
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible for converting staged records
    into the PayPilot operational data store. Staged records are loaded
    via a Clarion conversion program.
   ---------------------------------------------------------------------------------
*/       
AS
BEGIN
/* 
   --------------------------------------------------------------------------------- 
    Declare, and initialize, all variables that will be used by this procedure.
   ---------------------------------------------------------------------------------
*/       
    declare @FileName varchar(255), @time int, @seconds int
    declare @howmany int, @howmanyInserted int, @howmanyHst int
    declare @BchNum int, @StageBchNum int, @UploadBchNum int, @NumOriginal int
    declare @SaveNumOriginal int, @NumCurrent int
    declare @howmanyBch int, @howmanyBchInserted int
    declare @RunDt int, @RunTime int, @CTpId smallint, @Id decimal(11,0), @ChkId decimal(11,0), @ModVer tinyint
    declare @ChkCnt int, @VoidCnt int, @TotPay dec(14,2), @TotVoid dec(14,2)
    declare @Typ varchar(2), @PrtCd varchar(2), @RefBchNum varchar(16)
    declare @OperId varchar(30), @MaxUsedChkId int, @CTpChkCnt int, @RngId smallint
    declare @ChkIssuedRecordId int, @HiChkId decimal(11,0), @SeqNum int, @OutSeqNum int
    declare @RecordId int
    declare @ImpBch int, @ImpBnkBch int, @PrtBch int, @RcnBch int
    declare @SavRcnBch int, @ExpBch int, @PdBch int
    declare @NewImpBch int, @NewImpBnkBch int, @NewPrtBch int, @NewRcnBch int
    declare @NewSavRcnBch int, @NewExpBch int, @NewPdBch int
    
    declare chk_convert cursor for
        select CTpId, Id, ImpBch, ImpBnkBch, PrtBch, RcnBch, SavRcnBch, ExpBch, PdBch
        from stageChk
    open chk_convert
    
    declare hst_convert cursor for
        select RecordId, ImpBch, ImpBnkBch, PrtBch, RcnBch, SavRcnBch, ExpBch, PdBch
        from stageHst
    open hst_convert
    
    declare vch_convert cursor for
        select CTpId, ChkId, SeqNum, ExpBch
        from stageVch
    open vch_convert

    set nocount on
    set transaction isolation level serializable /* the highest level of isolation */

    select @RunDt   = ( select convert(int,datediff(dd,getdate(),'12/28/1800'),101) * -1 )
    select @RunTime = ( select (datepart(hh,getdate()) * 60 * 60 + datepart(mm,getdate())* 60 + datepart(ss,getdate())) * 100 )

    set @Typ             = 'I'
    set @PrtCd           = ' '
    set @RefBchNum       = ' '
    set @howmanyInserted = 0
    set @howmanyBchInserted = 0
    set @NumOriginal     = 0
    set @SaveNumOriginal = 0

    delete from Bch WHERE Num > 100000000

    select @NumCurrent = max(Num)
    from dbo.Bch

    if @NumCurrent is NULL
    begin
      set @NumCurrent = 0
    end

/* 
   --------------------------------------------------------------------------------- 
    Count the number of Chk records which will be imported from the staging table.
    This count is used, within a Loop structure, to control the number of times
    that the Loop code is executed.

    Also, determine the BcH batch Num to be imported by selecting the "Top 1" record.
    Eventually the Chk table will be expanded to include the BcH.Num column
    which will allow multiple BcH batches to be imported with a single call to
    this procedure. The setting of the BcH batch Num will be done within the 
    Transaction but it will be done outside of the stageChk processing Loop.
   ---------------------------------------------------------------------------------
*/  
    select @howmanyBch = (
                       select count(1) from dbo.stageBch
                      )
    if @howmanyBch is NULL begin
      set @howmanyBch = 0
    end

    select @howmany = (
                       select count(1) from dbo.stageChk 
                      )
    if @howmany is NULL begin
      set @howmany = 0
    end

    if @howmany = 0 begin
      set nocount off
      print 'No Chk records are available for Import: '
      close chk_convert
      close hst_convert
      close vch_convert
      deallocate chk_convert
      deallocate hst_convert
      deallocate vch_convert
      return
    end

    if @howmany = 0 or @howmanyBch = 0 begin
      set nocount off
      print 'No Chk records are available for Import: '
      close chk_convert
      close hst_convert
      close vch_convert
      deallocate chk_convert
      deallocate hst_convert
      deallocate vch_convert
      return
      return /* Return with a zero status to indicate a successful process */
    end
/* 
   --------------------------------------------------------------------------------- 
    Now, begin the Transaction that Inserts records into the BcH (operator batch),
    Chk, Hst, and Vch records.
    (e.g. Chk...stageChk, Hst...stageHst)
   ---------------------------------------------------------------------------------
*/       
    BEGIN TRAN
/* --------------------------------------------------------------------------------- 
    Insert each of the Bch records, from the stageBch table
   --------------------------------------------------------------------------------- */       
   
    WHILE @howmanyBchInserted < @howmanyBch
    BEGIN
 
      SELECT top 1 @NumOriginal = Num
        FROM dbo.stageBch
       WHERE Num > @SaveNumOriginal
       ORDER By Num
       
      set @SaveNumOriginal = @NumOriginal
      set @NumCurrent = @NumCurrent + 1

      INSERT INTO dbo.BchXRef (
         NumOriginal,
         NumCurrent
            )
      VALUES (
         @NumOriginal,
         @NumCurrent
            )

      INSERT INTO dbo.Bch (
         Num,
         Typ,
         Dt,
         [Time],
         OperId,
         CTpId,
         LowChkId,
         HiChkId,
         PrtCd,
         BckCd,
         SndCd,
         SndDt,
         RepRsn,
         Amt1,
         Amt2,
         Amt3,
         Amt4,
         Amt5,
         Amt6,
         Amt7,
         Amt8,
         Cnt1,
         Cnt2,
         Cnt3,
         Cnt4,
         Cnt5,
         Cnt6,
         Cnt7,
         Cnt8,
         MultCd,
         MultTyp,
         FilNam,
         EftTxt,
         EftNum,
         EftCls,
         EftDesc,
         EftDt,
         EftEffDt,
         RefBchNum,
         XCd1,
         XCd2,
         XCd3,
         XCd4,
         XCd5,
         XNum1,
         XNum2,
         XNum3
            )
      SELECT
         @NumCurrent,
         Typ,
         Dt,
         [Time],
         OperId,
         CTpId,
         LowChkId,
         HiChkId,
         PrtCd,
         BckCd,
         SndCd,
         SndDt,
         RepRsn,
         Amt1,
         Amt2,
         Amt3,
         Amt4,
         Amt5,
         Amt6,
         Amt7,
         Amt8,
         Cnt1,
         Cnt2,
         Cnt3,
         Cnt4,
         Cnt5,
         Cnt6,
         Cnt7,
         Cnt8,
         MultCd,
         MultTyp,
         FilNam,
         EftTxt,
         EftNum,
         EftCls,
         EftDesc,
         EftDt,
         EftEffDt,
         RefBchNum,
         XCd1,
         XCd2,
         XCd3,
         XCd4,
         XCd5,
         XNum1,
         XNum2,
         XNum3
      FROM dbo.stageBch
      where num = @NumOriginal
      
      set @howmanyBchInserted = @howmanyBchInserted + 1

    END /* END of Bch Loop */

/*
   --------------------------------------------------------------------------------- 
    Begin importing each stageChk record, and it's associated "child" records
   ---------------------------------------------------------------------------------
*/       
    fetch chk_convert 
        into @CTpId, @Id, @ImpBch, @ImpBnkBch, @PrtBch, @RcnBch, @SavRcnBch, @ExpBch, @PdBch 
    while @@fetch_status = 0
    begin

/* --------------------------------------------------------------------------------- 
    Insert the Chk record, from the stageChk record, the RecordId is an Identity
    column.
   --------------------------------------------------------------------------------- */       

      select @NewImpBch     = NumCurrent from BchXRef where NumOriginal = @ImpBch
      select @NewImpBnkBch  = NumCurrent from BchXRef where NumOriginal = @ImpBnkBch
      select @NewPrtBch     = NumCurrent from BchXRef where NumOriginal = @PrtBch
      select @NewRcnBch     = NumCurrent from BchXRef where NumOriginal = @RcnBch
      select @NewSavRcnBch  = NumCurrent from BchXRef where NumOriginal = @SavRcnBch
      select @NewExpBch     = NumCurrent from BchXRef where NumOriginal = @ExpBch
      select @NewPdBch      = NumCurrent from BchXRef where NumOriginal = @PdBch

      INSERT INTO dbo.Chk (
		CTpId,
		Id,
		OrigId,
		AltSrt,
		AltSrt1,
		IdPre,
		ModVer,
		ModCd,
		CmpId,
		PayToNam1,
		PayToNam2,
		PayToNam3,
		IssDt,
		PayAmt,
		OrigPayAmt,
		ResrvAmt,
		BnkId,
		BnkNum,
		LosDt,
		Dt1,
		Dt2,
		Dt3,
		Dt4,
		Dt5,
		Time1,
		Time2,
		TranCd,
		TaxId,
		TaxTyp,
		Tax1099,
		RptAmt1099,
		SpltPay1099,
		VndTyp,
		VndId,
		AgentTyp,
		AgentId,
		MailToNam,
		MailToAdr1,
		MailToAdr2,
		MailToAdr3,
		MailToAdr4,
		MailToAdr5,
		City,
		State,
		CntyCd,
		CountryId,
		ZipCd,
		BillState,
		BillDt,
		PhNum1,
		PhNum2,
		FaxNum,
		FaxNumTyp,
		FaxToNam,
		EmailAdr,
		MrgId,
		MrgId2,
		PayCd,
		PayToCd,
		ReqId,
		ExamId,
		ExamNam,
		AdjId,
		CurId,
		Office,
		DeptCd,
		MailStop,
		ReissCd,
		AtchCd,
		ReqNum,
		ImpBch,
		ImpBnkBch,
		PrtBch,
		RcnBch,
		SavRcnBch,
		ExpBch,
		PdBch,
		VoidExpCd,
		PrevVoidExpCd,
		WriteOffExpCd,
		SrchLtrCd,
		PrtCnt,
		RcnCd,
		VoidCd,
		VoidId,
		VoidDt,
		UnVoidCd,
		UnVoidId,
		UnVoidDt,
		SigCd,
		SigCd1,
		SigCd2,
		DrftCd,
		DscCd,
		RestCd,
		XCd1,
		XCd2,
		XCd3,
		XCd4,
		XCd5,
		XCd6,
		XCd7,
		XCd8,
		XCd9,
		XCd10,
		PayRate,
		XRate1,
		XRate2,
		XRate3,
		XAmt1,
		XAmt2,
		XAmt3,
		XAmt4,
		XAmt5,
		XAmt6,
		XAmt7,
		XAmt8,
		XAmt9,
		XAmt10,
		SalaryAmt,
		MaritalStat,
		FedExempt,
		StateExempt,
		Day30Cd,
		PstCd,
		RsnCd,
		PdCd,
		PdDt,
		ApprovCd,
		ApprovDt,
		ApprovId,
		ApprovCd2,
		ApprovDt2,
		ApprovId2,
		ApprovCd3,
		ApprovDt3,
		ApprovId3,
		ApprovCd4,
		ApprovDt4,
		ApprovId4,
		ApprovCd5,
		ApprovDt5,
		ApprovId5,
		ApprovCd6,
		ApprovDt6,
		ApprovId6,
		ApprovCd7,
		ApprovDt7,
		ApprovId7,
		ApprovCd8,
		ApprovDt8,
		ApprovId8,
		ApprovCd9,
		ApprovDt9,
		ApprovId9,
		AddDt,
		AddTime,
		AddId,
		ChgDt,
		ChgTime,
		ChgId,
		SrceCd,
		FrmCd,
		RefNum,
		NamTyp,
		LstNam,
		FstNam,
		MidInit,
		Salutation,
		AcctNum,
		ExpAcct,
		DebitAcct,
		BnkAcct,
		BnkRout,
		AcctNam,
		EftTypCd,
		BnkAcct2,
		BnkRout2,
		AcctNam2,
		EftTypCd2,
		BnkAcct3,
		BnkRout3,
		AcctNam3,
		EftTypCd3,
		AllocPct1,
		AllocPct2,
		AllocPct3,
		OptCd,
		EftTranCd,
		AdviceTyp,
		RepRsn,
		EmployerTyp,
		EmployerId,
		EmployerNam,
		EmployerAdr1,
		EmployerAdr2,
		EmployerAdr3,
		ProviderTyp,
		ProviderId,
		ProviderNam,
		CarrierTyp,
		CarrierId,
		PolId,
		InsNam,
		InsAdr1,
		InsAdr2,
		InsAdr3,
		ClaimNum,
		ClmntNum,
		ClmntNam,
		ClmntAdr1,
		ClmntAdr2,
		ClmntAdr3,
		LosCause,
		DiagCd1,
		DiagCd2,
		DiagCd3,
		DiagCd4,
		ForRsn1,
		ForRsn2,
		ForRsn3,
		CommentTxt,
		XNum1,
		XNum2,
		XNum3,
		XNum4,
		TransferOutBch,
		TransferInBch,
		VchCnt,
		PrtDt,
		PrtId,
		TranDt,
		TranTime,
		TranTyp,
		TranId,
		BTpId,
		ExamTyp,
		Priority,
		DeliveryDt,
		CardNum,
		CardTyp,
		ExportStat,
		PrevExportStat
                )
      SELECT            
		CTpId,
		Id,
		OrigId,
		AltSrt,
		AltSrt1,
		IdPre,
		ModVer,
		ModCd,
		CmpId,
		PayToNam1,
		PayToNam2,
		PayToNam3,
		IssDt,
		PayAmt,
		OrigPayAmt,
		ResrvAmt,
		BnkId,
		BnkNum,
		LosDt,
		Dt1,
		Dt2,
		Dt3,
		Dt4,
		Dt5,
		Time1,
		Time2,
		TranCd,
		TaxId,
		TaxTyp,
		Tax1099,
		RptAmt1099,
		SpltPay1099,
		VndTyp,
		VndId,
		AgentTyp,
		AgentId,
		MailToNam,
		MailToAdr1,
		MailToAdr2,
		MailToAdr3,
		MailToAdr4,
		MailToAdr5,
		City,
		State,
		CntyCd,
		CountryId,
		ZipCd,
		BillState,
		BillDt,
		PhNum1,
		PhNum2,
		FaxNum,
		FaxNumTyp,
		FaxToNam,
		EmailAdr,
		MrgId,
		MrgId2,
		PayCd,
		PayToCd,
		ReqId,
		ExamId,
		ExamNam,
		AdjId,
		CurId,
		Office,
		DeptCd,
		MailStop,
		ReissCd,
		AtchCd,
		ReqNum,
		@NewImpBch,
		@NewImpBnkBch,
		@NewPrtBch,
		@NewRcnBch,
		@NewSavRcnBch,
		@NewExpBch,
		@NewPdBch,
		VoidExpCd,
		PrevVoidExpCd,
		WriteOffExpCd,
		SrchLtrCd,
		PrtCnt,
		RcnCd,
		VoidCd,
		VoidId,
		VoidDt,
		UnVoidCd,
		UnVoidId,
		UnVoidDt,
		SigCd,
		SigCd1,
		SigCd2,
		DrftCd,
		DscCd,
		RestCd,
		XCd1,
		XCd2,
		XCd3,
		XCd4,
		XCd5,
		XCd6,
		XCd7,
		XCd8,
		XCd9,
		XCd10,
		PayRate,
		XRate1,
		XRate2,
		XRate3,
		XAmt1,
		XAmt2,
		XAmt3,
		XAmt4,
		XAmt5,
		XAmt6,
		XAmt7,
		XAmt8,
		XAmt9,
		XAmt10,
		SalaryAmt,
		MaritalStat,
		FedExempt,
		StateExempt,
		Day30Cd,
		PstCd,
		RsnCd,
		PdCd,
		PdDt,
		ApprovCd,
		ApprovDt,
		ApprovId,
		ApprovCd2,
		ApprovDt2,
		ApprovId2,
		ApprovCd3,
		ApprovDt3,
		ApprovId3,
		ApprovCd4,
		ApprovDt4,
		ApprovId4,
		ApprovCd5,
		ApprovDt5,
		ApprovId5,
		ApprovCd6,
		ApprovDt6,
		ApprovId6,
		ApprovCd7,
		ApprovDt7,
		ApprovId7,
		ApprovCd8,
		ApprovDt8,
		ApprovId8,
		ApprovCd9,
		ApprovDt9,
		ApprovId9,
		AddDt,
		AddTime,
		AddId,
		ChgDt,
		ChgTime,
		ChgId,
		SrceCd,
		FrmCd,
		RefNum,
		NamTyp,
		LstNam,
		FstNam,
		MidInit,
		Salutation,
		AcctNum,
		ExpAcct,
		DebitAcct,
		BnkAcct,
		BnkRout,
		AcctNam,
		EftTypCd,
		BnkAcct2,
		BnkRout2,
		AcctNam2,
		EftTypCd2,
		BnkAcct3,
		BnkRout3,
		AcctNam3,
		EftTypCd3,
		AllocPct1,
		AllocPct2,
		AllocPct3,
		OptCd,
		EftTranCd,
		AdviceTyp,
		RepRsn,
		EmployerTyp,
		EmployerId,
		EmployerNam,
		EmployerAdr1,
		EmployerAdr2,
		EmployerAdr3,
		ProviderTyp,
		ProviderId,
		ProviderNam,
		CarrierTyp,
		CarrierId,
		PolId,
		InsNam,
		InsAdr1,
		InsAdr2,
		InsAdr3,
		ClaimNum,
		ClmntNum,
		ClmntNam,
		ClmntAdr1,
		ClmntAdr2,
		ClmntAdr3,
		LosCause,
		DiagCd1,
		DiagCd2,
		DiagCd3,
		DiagCd4,
		ForRsn1,
		ForRsn2,
		ForRsn3,
		CommentTxt,
		XNum1,
		XNum2,
		XNum3,
		XNum4,
		TransferOutBch,
		TransferInBch,
		VchCnt,
		PrtDt,
		PrtId,
		TranDt,
		TranTime,
		TranTyp,
		TranId,
		BTpId,
		ExamTyp,
		Priority,
		DeliveryDt,
		CardNum,
		CardTyp,
		ExportStat,
		PrevExportStat
	  FROM dbo.stageChk
	  WHERE CTpId = @CTpId
	    AND    Id = @Id 

      set @howmanyInserted = @howmanyInserted + 1
                                 
/* --------------------------------------------------------------------------------- 
    Insert the Hst record(s), from the stageHst record, using the 
    CTpId and Check Id that were derived above for the "child" records.
   --------------------------------------------------------------------------------- */       

      fetch chk_convert 
          into @CTpId, @Id, @ImpBch, @ImpBnkBch, @PrtBch, @RcnBch, @SavRcnBch, @ExpBch, @PdBch 

    end /* END of stageChk cursor Loop */

    close chk_convert
    deallocate Chk_convert

/* 
   --------------------------------------------------------------------------------- 
    Begin importing each stageHst record, and it's associated "child" records
   ---------------------------------------------------------------------------------
*/       
    set @howmanyInserted = 0

    fetch hst_convert 
        into @RecordId, @ImpBch, @ImpBnkBch, @PrtBch, @RcnBch, @SavRcnBch, @ExpBch, @PdBch 
    while @@fetch_status = 0
    begin

/* --------------------------------------------------------------------------------- 
    Insert the Hst record, from the stageHst record
   --------------------------------------------------------------------------------- */       

      select @NewImpBch     = NumCurrent from BchXRef where NumOriginal = @ImpBch
      select @NewImpBnkBch  = NumCurrent from BchXRef where NumOriginal = @ImpBnkBch
      select @NewPrtBch     = NumCurrent from BchXRef where NumOriginal = @PrtBch
      select @NewRcnBch     = NumCurrent from BchXRef where NumOriginal = @RcnBch
      select @NewSavRcnBch  = NumCurrent from BchXRef where NumOriginal = @SavRcnBch
      select @NewExpBch     = NumCurrent from BchXRef where NumOriginal = @ExpBch
      select @NewPdBch      = NumCurrent from BchXRef where NumOriginal = @PdBch

      INSERT INTO dbo.Hst (
		CTpId,
		Id,
		OrigId,
		IdPre,
		ModVer,
		ModCd,
		CmpId,
		PayToNam1,
		PayToNam2,
		PayToNam3,
		IssDt,
		PayAmt,
		OrigPayAmt,
		ResrvAmt,
		BnkId,
		BnkNum,
		LosDt,
		Dt1,
		Dt2,
		Dt3,
		Dt4,
		Dt5,
		Time1,
		Time2,
		TranCd,
		TaxId,
		TaxTyp,
		Tax1099,
		RptAmt1099,
		SpltPay1099,
		VndTyp,
		VndId,
		AgentTyp,
		AgentId,
		MailToNam,
		MailToAdr1,
		MailToAdr2,
		MailToAdr3,
		MailToAdr4,
		MailToAdr5,
		City,
		State,
		CntyCd,
		CountryId,
		ZipCd,
		BillState,
		BillDt,
		PhNum1,
		PhNum2,
		FaxNum,
		FaxNumTyp,
		FaxToNam,
		EmailAdr,
		MrgId,
		MrgId2,
		PayCd,
		PayToCd,
		ReqId,
		ExamId,
		ExamNam,
		AdjId,
		CurId,
		Office,
		DeptCd,
		MailStop,
		ReissCd,
		AtchCd,
		ReqNum,
		ImpBch,
		ImpBnkBch,
		PrtBch,
		RcnBch,
		SavRcnBch,
		ExpBch,
		PdBch,
		VoidExpCd,
		PrevVoidExpCd,
		WriteOffExpCd,
		SrchLtrCd,
		PrtCnt,
		RcnCd,
		VoidCd,
		VoidId,
		VoidDt,
		UnVoidCd,
		UnVoidId,
		UnVoidDt,
		SigCd,
		SigCd1,
		SigCd2,
		DrftCd,
		DscCd,
		RestCd,
		XCd1,
		XCd2,
		XCd3,
		XCd4,
		XCd5,
		XCd6,
		XCd7,
		XCd8,
		XCd9,
		XCd10,
		PayRate,
		XRate1,
		XRate2,
		XRate3,
		XAmt1,
		XAmt2,
		XAmt3,
		XAmt4,
		XAmt5,
		XAmt6,
		XAmt7,
		XAmt8,
		XAmt9,
		XAmt10,
		SalaryAmt,
		MaritalStat,
		FedExempt,
		StateExempt,
		Day30Cd,
		PstCd,
		RsnCd,
		PdCd,
		PdDt,
		ApprovCd,
		ApprovDt,
		ApprovId,
		ApprovCd2,
		ApprovDt2,
		ApprovId2,
		ApprovCd3,
		ApprovDt3,
		ApprovId3,
		ApprovCd4,
		ApprovDt4,
		ApprovId4,
		ApprovCd5,
		ApprovDt5,
		ApprovId5,
		ApprovCd6,
		ApprovDt6,
		ApprovId6,
		ApprovCd7,
		ApprovDt7,
		ApprovId7,
		ApprovCd8,
		ApprovDt8,
		ApprovId8,
		ApprovCd9,
		ApprovDt9,
		ApprovId9,
		AddDt,
		AddTime,
		AddId,
		ChgDt,
		ChgTime,
		ChgId,
		SrceCd,
		FrmCd,
		RefNum,
		NamTyp,
		LstNam,
		FstNam,
		MidInit,
		Salutation,
		AcctNum,
		ExpAcct,
		DebitAcct,
		BnkAcct,
		BnkRout,
		AcctNam,
		EftTypCd,
		BnkAcct2,
		BnkRout2,
		AcctNam2,
		EftTypCd2,
		BnkAcct3,
		BnkRout3,
		AcctNam3,
		EftTypCd3,
		AllocPct1,
		AllocPct2,
		AllocPct3,
		OptCd,
		EftTranCd,
		AdviceTyp,
		RepRsn,
		EmployerTyp,
		EmployerId,
		EmployerNam,
		EmployerAdr1,
		EmployerAdr2,
		EmployerAdr3,
		ProviderTyp,
		ProviderId,
		ProviderNam,
		CarrierTyp,
		CarrierId,
		PolId,
		InsNam,
		InsAdr1,
		InsAdr2,
		InsAdr3,
		ClaimNum,
		ClmntNum,
		ClmntNam,
		ClmntAdr1,
		ClmntAdr2,
		ClmntAdr3,
		LosCause,
		DiagCd1,
		DiagCd2,
		DiagCd3,
		DiagCd4,
		ForRsn1,
		ForRsn2,
		ForRsn3,
		CommentTxt,
		XNum1,
		XNum2,
		XNum3,
		XNum4,
		TransferOutBch,
		TransferInBch,
		VchCnt,
		PrtDt,
		PrtId,
		TranDt,
		TranTime,
		TranTyp,
		TranId,
		BTpId,
		ExamTyp,
		Priority,
		DeliveryDt,
		CardNum,
		CardTyp,
		ExportStat,
		PrevExportStat
            )
      SELECT            
		CTpId,
		Id,
		OrigId,
		IdPre,
		ModVer,
		ModCd,
		CmpId,
		PayToNam1,
		PayToNam2,
		PayToNam3,
		IssDt,
		PayAmt,
		OrigPayAmt,
		ResrvAmt,
		BnkId,
		BnkNum,
		LosDt,
		Dt1,
		Dt2,
		Dt3,
		Dt4,
		Dt5,
		Time1,
		Time2,
		TranCd,
		TaxId,
		TaxTyp,
		Tax1099,
		RptAmt1099,
		SpltPay1099,
		VndTyp,
		VndId,
		AgentTyp,
		AgentId,
		MailToNam,
		MailToAdr1,
		MailToAdr2,
		MailToAdr3,
		MailToAdr4,
		MailToAdr5,
		City,
		State,
		CntyCd,
		CountryId,
		ZipCd,
		BillState,
		BillDt,
		PhNum1,
		PhNum2,
		FaxNum,
		FaxNumTyp,
		FaxToNam,
		EmailAdr,
		MrgId,
		MrgId2,
		PayCd,
		PayToCd,
		ReqId,
		ExamId,
		ExamNam,
		AdjId,
		CurId,
		Office,
		DeptCd,
		MailStop,
		ReissCd,
		AtchCd,
		ReqNum,
		@NewImpBch,
		@NewImpBnkBch,
		@NewPrtBch,
		@NewRcnBch,
		@NewSavRcnBch,
		@NewExpBch,
		@NewPdBch,
		VoidExpCd,
		PrevVoidExpCd,
		WriteOffExpCd,
		SrchLtrCd,
		PrtCnt,
		RcnCd,
		VoidCd,
		VoidId,
		VoidDt,
		UnVoidCd,
		UnVoidId,
		UnVoidDt,
		SigCd,
		SigCd1,
		SigCd2,
		DrftCd,
		DscCd,
		RestCd,
		XCd1,
		XCd2,
		XCd3,
		XCd4,
		XCd5,
		XCd6,
		XCd7,
		XCd8,
		XCd9,
		XCd10,
		PayRate,
		XRate1,
		XRate2,
		XRate3,
		XAmt1,
		XAmt2,
		XAmt3,
		XAmt4,
		XAmt5,
		XAmt6,
		XAmt7,
		XAmt8,
		XAmt9,
		XAmt10,
		SalaryAmt,
		MaritalStat,
		FedExempt,
		StateExempt,
		Day30Cd,
		PstCd,
		RsnCd,
		PdCd,
		PdDt,
		ApprovCd,
		ApprovDt,
		ApprovId,
		ApprovCd2,
		ApprovDt2,
		ApprovId2,
		ApprovCd3,
		ApprovDt3,
		ApprovId3,
		ApprovCd4,
		ApprovDt4,
		ApprovId4,
		ApprovCd5,
		ApprovDt5,
		ApprovId5,
		ApprovCd6,
		ApprovDt6,
		ApprovId6,
		ApprovCd7,
		ApprovDt7,
		ApprovId7,
		ApprovCd8,
		ApprovDt8,
		ApprovId8,
		ApprovCd9,
		ApprovDt9,
		ApprovId9,
		AddDt,
		AddTime,
		AddId,
		ChgDt,
		ChgTime,
		ChgId,
		SrceCd,
		FrmCd,
		RefNum,
		NamTyp,
		LstNam,
		FstNam,
		MidInit,
		Salutation,
		AcctNum,
		ExpAcct,
		DebitAcct,
		BnkAcct,
		BnkRout,
		AcctNam,
		EftTypCd,
		BnkAcct2,
		BnkRout2,
		AcctNam2,
		EftTypCd2,
		BnkAcct3,
		BnkRout3,
		AcctNam3,
		EftTypCd3,
		AllocPct1,
		AllocPct2,
		AllocPct3,
		OptCd,
		EftTranCd,
		AdviceTyp,
		RepRsn,
		EmployerTyp,
		EmployerId,
		EmployerNam,
		EmployerAdr1,
		EmployerAdr2,
		EmployerAdr3,
		ProviderTyp,
		ProviderId,
		ProviderNam,
		CarrierTyp,
		CarrierId,
		PolId,
		InsNam,
		InsAdr1,
		InsAdr2,
		InsAdr3,
		ClaimNum,
		ClmntNum,
		ClmntNam,
		ClmntAdr1,
		ClmntAdr2,
		ClmntAdr3,
		LosCause,
		DiagCd1,
		DiagCd2,
		DiagCd3,
		DiagCd4,
		ForRsn1,
		ForRsn2,
		ForRsn3,
		CommentTxt,
		XNum1,
		XNum2,
		XNum3,
		XNum4,
		TransferOutBch,
		TransferInBch,
		VchCnt,
		PrtDt,
		PrtId,
		TranDt,
		TranTime,
		TranTyp,
		TranId,
		BTpId,
		ExamTyp,
		Priority,
		DeliveryDt,
		CardNum,
		CardTyp,
		ExportStat,
		PrevExportStat
	  FROM dbo.stageHst
	  WHERE RecordId = @RecordId

      set @howmanyInserted = @howmanyInserted + 1
                                 
/* --------------------------------------------------------------------------------- 
    Insert the Hst record(s), from the stageHst record, using the 
    CTpId and Check Id that were derived above for the "child" records.
   --------------------------------------------------------------------------------- */       

      fetch hst_convert 
          into @RecordId, @ImpBch, @ImpBnkBch, @PrtBch, @RcnBch, @SavRcnBch, @ExpBch, @PdBch 

    end /* END of stageHst cursor Loop */

    close hst_convert
    deallocate hst_convert
/* 
   --------------------------------------------------------------------------------- 
    Begin importing each stageVch record
   ---------------------------------------------------------------------------------
*/       
    fetch vch_convert into @CTpId, @ChkId, @SeqNum, @ExpBch
    while @@fetch_status = 0
    begin

/* --------------------------------------------------------------------------------- 
    Insert the Vch record, from the stageVch record
   --------------------------------------------------------------------------------- */       

      select @NewExpBch = NumCurrent from BchXRef where NumOriginal = @ExpBch

      INSERT INTO dbo.Vch (
		CTpId,
		ChkId,
		SeqNum,
		DescTxt,
		VchId,
		InvId,
		CshAcct,
		ExpAcct,
		CostCtr,
		InsNam,
		ClmntNam,
		ClmntNum,
		ClaimNum,
		TranCd,
		PolId,
		InvDt,
		InvAmt,
		AmtPd,
		DiscAmt,
		NetAmt,
		ExpBch,
		DiagCd,
		RsnCd,
		Amt1,
		Amt2,
		Dt1,
		Dt2,
		Dt3,
		Dt4,
		Qty1,
		Qty2,
		Qty3,
		PayRate,
		XRate1,
		XRate2,
		XRate3,
		XRate4,
		XRate5,
		[Time],
		Tax1099,
		XCd1,
		XCd2,
		XCd3,
		XCd4,
		XCd5,
		XCd6,
		XCd7,
		XCd8,
		XCd9,
		XCd10
            )
      SELECT
		CTpId,
		ChkId,
		SeqNum,
		DescTxt,
		VchId,
		InvId,
		CshAcct,
		ExpAcct,
		CostCtr,
		InsNam,
		ClmntNam,
		ClmntNum,
		ClaimNum,
		TranCd,
		PolId,
		InvDt,
		InvAmt,
		AmtPd,
		DiscAmt,
		NetAmt,
		@NewExpBch,
		DiagCd,
		RsnCd,
		Amt1,
		Amt2,
		Dt1,
		Dt2,
		Dt3,
		Dt4,
		Qty1,
		Qty2,
		Qty3,
		PayRate,
		XRate1,
		XRate2,
		XRate3,
		XRate4,
		XRate5,
		[Time],
		Tax1099,
		XCd1,
		XCd2,
		XCd3,
		XCd4,
		XCd5,
		XCd6,
		XCd7,
		XCd8,
		XCd9,
		XCd10
       FROM dbo.stageVch
      WHERE CTpId = @CTpId
        AND ChkId = @ChkId
        AND SeqNum = @SeqNum
        
      set @howmanyInserted = @howmanyInserted + 1
                                 
/* --------------------------------------------------------------------------------- 
    Insert the Vch record(s), from the stageVch record, using the 
    CTpId, Check Id, and SeqNum.
   --------------------------------------------------------------------------------- */       

      fetch vch_convert into @CTpId, @ChkId, @SeqNum, @ExpBch

    end /* END of stageVch cursor Loop */

    close vch_convert
    deallocate vch_convert

    update Chk 
      set Chk.PrtDt = (SELECT Dt FROM Bch WHERE Num = Chk.PrtBch)
    where Chk.PrtBch is NOT NULL 
      and Chk.PrtBch <> 0
      and Chk.PrtDt = 0

    update Hst 
      set Hst.PrtDt = (SELECT Dt FROM Bch WHERE Num = Hst.PrtBch)
    where Hst.PrtBch is NOT NULL 
      and Hst.PrtBch <> 0
      and Hst.PrtDt = 0

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing to this point.
   --------------------------------------------------------------------------------- */       
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPConvertFromStaging: Cannot insert data into ppSPConvertFromStaging'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

    COMMIT TRAN

    update Chk 
      set Chk.PrtDt = (SELECT Dt FROM Bch WHERE Num = Chk.PrtBch)
    where Chk.PrtBch is NOT NULL 
      and Chk.PrtBch <> 0
      and Chk.PrtDt = 0

    update Hst 
      set Hst.PrtDt = (SELECT Dt FROM Bch WHERE Num = Hst.PrtBch)
    where Hst.PrtBch is NOT NULL 
      and Hst.PrtBch <> 0
      and Hst.PrtDt = 0

    set nocount off

    UPDATE Chk 
      SET TranDt = (SELECT Dt FROM Bch WHERE Num = Chk.PrtBch),
          TranTime = (SELECT Time FROM Bch WHERE Num = Chk.PrtBch),
          TranId = (SELECT OperId FROM Bch WHERE Num = Chk.PrtBch)
    WHERE CTpId = 20
      AND TranTyp = 80
      AND TranDt = 0
    
    
    UPDATE Hst 
      SET TranDt = (SELECT Dt FROM Bch WHERE Num = Hst.PrtBch),
          TranTime = (SELECT Time FROM Bch WHERE Num = Hst.PrtBch),
          TranId = (SELECT OperId FROM Bch WHERE Num = Hst.PrtBch)
    WHERE CTpId = 20
      AND TranTyp = 80
      AND TranDt = 0


    RETURN /* Return with a zero status to indicate a successful process */

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPCstSync]'
GO
ALTER procedure [dbo].[ppSPCstSync]
(
@LogHdrId int
)
as

declare @Cd varchar(50)

declare stageCstSynCd cursor for
select Cd FROM stageCst

declare CstSynCd cursor for
select Cd FROM Cst

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageCstSynCd
fetch stageCstSynCd into @Cd
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageCst record and make sure that Cst records are identiCst
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Cst where Cd = @Cd)
  begin
    delete Cst	-- delete the existing record and insert it again from stageCst
    where Cd = @Cd
  end

  insert into Cst
  select 	* from stageCst 
  where Cd = @Cd
  
  fetch stageCstSynCd into @Cd

END
close stageCstSynCd
deallocate stageCstSynCd

/* -------------------------------------------------------------------------------------- 
     Each Cst record must exist in stageCst - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open CstSynCd
fetch CstSynCd into @Cd
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageCst where Cd = @Cd)
  begin
    delete Cst	-- delete the operational record with no match to the stage table
    where Cd = @Cd
  end

  fetch CstSynCd into @Cd

END
close CstSynCd
deallocate CstSynCd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransCstion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPCstSync: Unable to sync the Cst table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the Cstling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPCtxMaint]'
GO
ALTER procedure [dbo].[ppSPCtxMaint]
as

declare @Id int

declare CtxUpdtd cursor for
select Id FROM Ctx

declare stageCtxUpdtd cursor for
select Id FROM stageCtx

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open CtxUpdtd
fetch CtxUpdtd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each Ctx record and make sure that stageCtx records are Identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from stageCtx where Id = @Id)
  begin
    delete stageCtx	-- delete the existing record and insert it again from Ctx
    where Id = @Id
  end

  insert into stageCtx
  select * from Ctx
  where Id = @Id

  fetch CtxUpdtd into @Id

END
close CtxUpdtd
deallocate CtxUpdtd

/* -------------------------------------------------------------------------------------- 
     Each stageCtx record must exist in Ctx - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open stageCtxUpdtd
fetch stageCtxUpdtd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from Ctx where Id = @Id)
  begin
    delete stageCtx	-- delete the stage record with no match to the operational table
    where Id = @Id
  end

  fetch stageCtxUpdtd into @Id

END
close stageCtxUpdtd
deallocate stageCtxUpdtd

/* --------------------------------------------------------------------------------- 
    Ctxmit, or Rollback the Transaction, based on the success or failure of the
    processing to this point.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPCtxMaint: Cannot update the stageCtx table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off

Exec ppSPLastMaintDate


 --identifies the last time that Admin maintenance was applied
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPCtxSync]'
GO
ALTER procedure [dbo].[ppSPCtxSync]
(
@LogHdrId int
)
as

declare @id int,
    @OutChkCntThreshold tinyint,
	@CommunicationType tinyint,
	@PPayRebuildPaymentsFileOnResnd tinyint,
	@PPaySaveUploadPaymentsFile tinyint,
	@PPayUploadFileAgingDays smallint,
	@PPayStagingDatabaseAgingDays smallint,
	@PPaySaveDownloadAdminFile tinyint,
	@PPayDownloadAdminAgingDays smallint,
	@SaveUploadPaymentsFile tinyint,
	@UploadFileAgingDays smallint,
	@StagingDatabaseAgingDays smallint,
	@SaveDownloadAdminFile tinyint,
	@DownloadAdminAgingDays smallint,
    @PrintServProcessId int,
    @TempTblAging smallint,
    @WebSvcs tinyint
    

declare stageCtxSyncd cursor for
select OutChkCntThreshold,
	CommunicationType,
	PPayRebuildPaymentsFileOnResnd,
	PPaySaveUploadPaymentsFile,
	PPayUploadFileAgingDays,
	PPayStagingDatabaseAgingDays,
	PPaySaveDownloadAdminFile,
	PPayDownloadAdminAgingDays,
	SaveUploadPaymentsFile,
	UploadFileAgingDays,
	StagingDatabaseAgingDays,
	SaveDownloadAdminFile,
	DownloadAdminAgingDays,
    PrintServProcessId,
    TempTblAging,
    WebSvcs
FROM stageCtx

declare CtxSyncd cursor for
select Id FROM Ctx

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageCtxSyncd
fetch stageCtxSyncd into
	@OutChkCntThreshold,
	@CommunicationType,
	@PPayRebuildPaymentsFileOnResnd,
	@PPaySaveUploadPaymentsFile,
	@PPayUploadFileAgingDays,
	@PPayStagingDatabaseAgingDays,
	@PPaySaveDownloadAdminFile,
	@PPayDownloadAdminAgingDays,
	@SaveUploadPaymentsFile,
	@UploadFileAgingDays,
	@StagingDatabaseAgingDays,
	@SaveDownloadAdminFile,
	@DownloadAdminAgingDays,
    @PrintServProcessId,
    @TempTblAging,
    @WebSvcs
    
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageCtx record and make sure that Ctx records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Ctx)
  begin
    update Ctx
	set PPayRebuildPaymentsFileOnResnd = @PPayRebuildPaymentsFileOnResnd    
    
    update Ctx
    set OutChkCntThreshold 			    = @OutChkCntThreshold,
        CommunicationType			    = @CommunicationType,
        PPaySaveUploadPaymentsFile		= @PPaySaveUploadPaymentsFile,
        PPayUploadFileAgingDays		    = @PPayUploadFileAgingDays,
        PPayStagingDatabaseAgingDays	= @PPayStagingDatabaseAgingDays,
        PPaySaveDownloadAdminFile		= @PPaySaveDownloadAdminFile,
        PPayDownloadAdminAgingDays		= @PPayDownloadAdminAgingDays,
        SaveUploadPaymentsFile		    = @SaveUploadPaymentsFile,
        UploadFileAgingDays			    = @UploadFileAgingDays,
        StagingDatabaseAgingDays		= @StagingDatabaseAgingDays,
        SaveDownloadAdminFile			= @SaveDownloadAdminFile,
        DownloadAdminAgingDays		    = @DownloadAdminAgingDays,
        PrintServProcessId              = @PrintServProcessId,
        TempTblAging                    = @TempTblAging,
        WebSvcs                         = @WebSvcs
  end

  fetch stageCtxSyncd into 
	@OutChkCntThreshold,
	@CommunicationType,
	@PPayRebuildPaymentsFileOnResnd,
	@PPaySaveUploadPaymentsFile,
	@PPayUploadFileAgingDays,
	@PPayStagingDatabaseAgingDays,
	@PPaySaveDownloadAdminFile,
	@PPayDownloadAdminAgingDays,
	@SaveUploadPaymentsFile,
	@UploadFileAgingDays,
	@StagingDatabaseAgingDays,
	@SaveDownloadAdminFile,
	@DownloadAdminAgingDays,
    @PrintServProcessId,
    @TempTblAging,
    @WebSvcs

END
close stageCtxSyncd
deallocate stageCtxSyncd

/* -------------------------------------------------------------------------------------- 
     Each Ctx record must exist in stageCtx - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open CtxSyncd
fetch CtxSyncd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageCtx where Id = @Id)
  begin
    delete Ctx	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch CtxSyncd into @Id

END
close CtxSyncd
deallocate CtxSyncd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPCtxSync: Unable to sync the Ctx table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPCurSync]'
GO
ALTER procedure [dbo].[ppSPCurSync]
(
@LogHdrId int
)
as

declare @Id varchar(4)

declare stageCurSynId cursor for
select Id FROM stageCur

declare CurSynId cursor for
select Id FROM Cur

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageCurSynId
fetch stageCurSynId into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageCur record and make sure that Cur records are identiCur
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Cur where Id = @Id)
  begin
    delete Cur	-- delete the existing record and insert it again from stageCur
    where Id = @Id
  end

  insert into Cur
  select 	* from stageCur 
  where Id = @Id
  
  fetch stageCurSynId into @Id

END
close stageCurSynId
deallocate stageCurSynId

/* -------------------------------------------------------------------------------------- 
     Each Cur record must exist in stageCur - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open CurSynId
fetch CurSynId into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageCur where Id = @Id)
  begin
    delete Cur	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch CurSynId into @Id

END
close CurSynId
deallocate CurSynId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransCurion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPCurSync: Unable to sync the Cur table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the Curling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPCusSync]'
GO
ALTER procedure [dbo].[ppSPCusSync]
(
@LogHdrId int
)
as

declare @Typ varchar(1), @Id varchar(30)

declare stageCusSynId cursor for
select Typ, Id FROM stageCus

declare CusSynId cursor for
select Typ, Id FROM Cus

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageCusSynId
fetch stageCusSynId into @Typ, @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageCus record and make sure that Cus records are identiCus
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Cus where Typ = @Typ and Id = @Id)
  begin
    delete Cus	-- delete the existing record and insert it again from stageCus
    where Typ = @Typ and Id = @Id
  end

  insert into Cus
  select 	* from stageCus 
  where Typ = @Typ and Id = @Id
  
  fetch stageCusSynId into @Typ, @Id

END
close stageCusSynId
deallocate stageCusSynId

/* -------------------------------------------------------------------------------------- 
     Each Cus record must exist in stageCus - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open CusSynId
fetch CusSynId into @Typ, @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageCus where Typ =@Typ and Id = @Id)
  begin
    delete Cus	-- delete the operational record with no match to the stage table
    where Typ = @Typ and Id = @Id
  end

  fetch CusSynId into @Typ, @Id

END
close CusSynId
deallocate CusSynId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransCusion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPCusSync: Unable to sync the Cus table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the Cusling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPCuTSync]'
GO
ALTER procedure [dbo].[ppSPCuTSync]
(
@LogHdrId int
)
as

declare @Typ varchar(1)

declare stageCuTSynId cursor for
select Typ FROM stageCuT

declare CuTSynId cursor for
select Typ FROM CuT

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageCuTSynId
fetch stageCuTSynId into @Typ
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageCuT record and make sure that CuT records are identiCuT
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from CuT where Typ = @Typ)
  begin
    delete CuT	-- delete the existing record and insert it again from stageCuT
    where Typ = @Typ
  end

  insert into CuT
  select 	* from stageCuT 
  where Typ = @Typ
  
  fetch stageCuTSynId into @Typ

END
close stageCuTSynId
deallocate stageCuTSynId

/* -------------------------------------------------------------------------------------- 
     Each CuT record must exist in stageCuT - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open CuTSynId
fetch CuTSynId into @Typ
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageCuT where Typ =@Typ)
  begin
    delete CuT	-- delete the operational record with no match to the stage table
    where Typ = @Typ
  end

  fetch CuTSynId into @Typ

END
close CuTSynId
deallocate CuTSynId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransCuTion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPCuTSync: Unable to sync the CuT table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the CuTling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPDeletePayments]'
GO


ALTER PROCEDURE [dbo].[ppSPDeletePayments]
(
@ParmDelBch int, -- use this BchNum to update the Delete Bch
@ParmImpBch int,
@ParmCTpId smallint,
@ParmLowChkId decimal(11,0),
@ParmHiChkId decimal(11,0),
@ParmOnlyPaidItems tinyint
)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible for deleting payments.
   ---------------------------------------------------------------------------------
*/       
AS
BEGIN

  declare @SelectCriteria nvarchar(4000), @WhereClause nvarchar(4000), @WhereChildClause nvarchar(4000)
  declare @CTpIdSubQuery nvarchar(4000), @IdSubQuery nvarchar(4000), @DelChkCmd nvarchar(4000)
  declare @DelVchCmd nvarchar(4000), @DelExACmd nvarchar(4000), @DelHstCmd nvarchar(4000)
  declare @DelTxtCmd nvarchar(4000), @LogInsert nvarchar(4000)
  declare @BchChkCnt int, @BchVoidCnt int, @BchTotPay decimal(13,2), @BchTotVoid decimal(13,2)
  declare @BchLowChkId decimal(11,0), @BchHiChkId decimal(11,0)
  declare @LowChkId decimal(11,0), @HiChkId decimal(11,0), @MaxHiChkId decimal(11,0)
  declare @LogTyp varchar(10), @LogBlank char(1), @ProcName varchar(30)
  declare @eAutoVoidCd tinyint, @eManVoidCd tinyint, @eStaleDtVoidCd tinyint, @eStopCd tinyint, @eWriteOffCd tinyint
  declare @cVoidCd char(1), @cStopCd char(1), @cWriteOffCd char(1)

  set nocount on

  set @LowChkId       = @ParmLowChkId
  set @HiChkId        = @ParmHiChkId
  set @DelChkCmd      = 'Delete from Chk'   
  set @DelHstCmd      = 'Delete from Hst'   
  set @DelExACmd      = 'Delete from ExA'   
  set @DelTxtCmd      = 'Delete from Txt'   
  set @DelVchCmd      = 'Delete from Vch'   
  set @SelectCriteria = 'Select Id, CTpId from Chk'
  set @CTpIdSubQuery  = '(select distinct CTpId from Chk where ImpBch = ' + rtrim(convert(varchar(11),@ParmImpBch)) + ')'
  set @IdSubQuery     = '(select Id from Chk where ImpBch = ' + rtrim(convert(varchar(11),@ParmImpBch))

/* 
   --------------------------------------------------------------------------------- 
    First, build the selection criteria, based on the input parameters.
   ---------------------------------------------------------------------------------
*/       
  if @ParmImpBch <> 0
  begin
    set @WhereClause      = ' where CTpId in ' + @CTpIdSubQuery + ' and Id in ' + @IdSubQuery
    set @WhereChildClause = ' where CTpId in ' + @CTpIdSubQuery + ' and ChkId in ' + @IdSubQuery
    if @ParmOnlyPaidItems <> 0
    begin
      set @WhereClause = @WhereClause + ' and PdCd <> 0'
      set @WhereChildClause = @WhereChildClause + ' and PdCd <> 0'
    end
  end
  else begin
    set @MaxHiChkId = (select max(Id) from Chk where CtpId = @ParmCTpId and Id <= @HiChkId)
    set @WhereClause = ' where CTpId = ' + rtrim(convert(varchar(11),@ParmCTpId)) + ' and Id between ' + rtrim(convert(varchar(11),@LowChkId)) + ' and ' + rtrim(convert(varchar(11),@MaxHiChkId))
    set @WhereChildClause = ' where CTpId = ' + rtrim(convert(varchar(11),@ParmCTpId)) + ' and ChkId between ' + rtrim(convert(varchar(11),@LowChkId)) + ' and ' + rtrim(convert(varchar(11),@MaxHiChkId))
    if @ParmOnlyPaidItems <> 0
    begin
      set @WhereClause = @WhereClause + ' and PdCd <> 0'
      set @WhereChildClause = @WhereChildClause + ' and PdCd <> 0'
    end
  end

  if @ParmImpBch <> 0
  begin
    set @WhereClause      = @WhereClause + ')'
    set @WhereChildClause = @WhereChildClause + ')'		-- this completes the child "where clause"
  end

  set nocount on

  set @WhereClause      = rtrim(@WhereClause)
  set @WhereChildClause = rtrim(@WhereChildClause)
  set @DelChkCmd        = @DelChkCmd + @WhereClause
  set @DelHstCmd        = @DelHstCmd + @WhereClause
  set @DelExACmd        = @DelExACmd + @WhereChildClause
  set @DelTxtCmd        = @DelTxtCmd + @WhereChildClause
  set @DelVchCmd        = @DelVchCmd + @WhereChildClause

/* -- examine each command for development purposes  
  select @WhereClause
  select @DelChkCmd
  select @DelHstCmd
  select @DelExACmd
  select @DelTxtCmd
  select @DelVchCmd
*/

  set transaction isolation level serializable /* the highest level of isolation */

  BEGIN TRAN

  /* 
   --------------------------------------------------------------------------------- 
      delete history (Hst) and all related child records for each Chk
   ---------------------------------------------------------------------------------
  */
  Exec sp_executesql @DelVchCmd
  IF (@@error!=0)
  BEGIN
    --RAISERROR  20000 'ppSPDeletePayments: Delete Payments process failed (Vch)'
    ROLLBACK TRAN
    UPDATE Bch
    SET XCd1  = 'Failed Step Delete Vch', 
        XNum1 = @@error
    WHERE Num = @ParmDelBch
    RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  Exec sp_executesql @DelTxtCmd
  IF (@@error!=0)
  BEGIN
    --RAISERROR  20000 'ppSPDeletePayments: Delete Payments process failed (Txt)'
    ROLLBACK TRAN
    UPDATE Bch
    SET XCd1  = 'Failed Step Delete Txt', 
        XNum1 = @@error
    WHERE Num = @ParmDelBch
    RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  Exec sp_executesql @DelExACmd
  IF (@@error!=0)
  BEGIN
    --RAISERROR  20000 'ppSPDeletePayments: Delete Payments process failed (ExA)'
    ROLLBACK TRAN
    UPDATE Bch
    SET XCd1  = 'Failed Step Delete ExA', 
        XNum1 = @@error
    WHERE Num = @ParmDelBch
    RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  Exec sp_executesql @DelHstCmd
  IF (@@error!=0)
  BEGIN
    --RAISERROR  20000 'ppSPDeletePayments: Delete Payments process failed (Hst)'
    ROLLBACK TRAN
    UPDATE Bch
    SET XCd1  = 'Failed Step Delete Hst', 
        XNum1 = @@error
    WHERE Num = @ParmDelBch
    RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  /* 
   --------------------------------------------------------------------------------- 
    Aggregate appropriate Bch values from the payments that are about to be deleted
   ---------------------------------------------------------------------------------
  */
  
  if @ParmImpBch <> 0
  begin -- Aggregate Bch totals for the selected Bch
    if @ParmOnlyPaidItems = 0
    begin -- All Items, Paid and Unpaid
      select @BchTotPay   = sum(PayAmt),
             @BchChkCnt   = count(Id),
             @BchLowChkId = min(Id),
             @BchHiChkId  = max(Id)
      from Chk 
      where ImpBch = @ParmImpBch
        and VoidCd = 0      

      select @BchTotVoid = sum(PayAmt),
             @BchVoidCnt = count(Id)
      from Chk 
      where ImpBch = @ParmImpBch 
        and VoidCd <> 0      
    end
    else begin -- Paid Items Only
      select @BchTotPay   = sum(PayAmt),
             @BchChkCnt   = count(Id),
             @BchLowChkId = min(Id),
             @BchHiChkId  = max(Id)
      from Chk 
      where ImpBch = @ParmImpBch
        and PdCd <> 0
        and VoidCd = 0      

      select @BchTotVoid = sum(PayAmt),
             @BchVoidCnt = count(Id)
      from Chk 
      where ImpBch = @ParmImpBch 
        and PdCd <> 0
        and VoidCd <> 0      
    end
  end
  else begin -- Aggregate Bch totals for the selected CTpId (Payment Type)
    if @ParmOnlyPaidItems = 0
    begin -- All Items, Paid and Unpaid
      select @BchTotPay   = sum(PayAmt),
             @BchChkCnt   = count(Id),
             @BchLowChkId = min(Id),
             @BchHiChkId  = max(Id)
      from Chk 
      where CTpId = @ParmCTpId
        and Id between @LowChkId and @MaxHiChkId
        and VoidCd = 0      

      select @BchTotVoid = sum(PayAmt),
             @BchVoidCnt = count(Id)
      from Chk 
      where CTpId = @ParmCTpId 
        and Id between @LowChkId and @MaxHiChkId
        and VoidCd <> 0      
    end
    else begin -- Paid Items Only
      select @BchTotPay   = sum(PayAmt),
             @BchChkCnt   = count(Id),
             @BchLowChkId = min(Id),
             @BchHiChkId  = max(Id)
      from Chk 
      where CTpId = @ParmCTpId 
        and Id between @LowChkId and @MaxHiChkId
        and PdCd <> 0
        and VoidCd = 0      

      select @BchTotVoid = sum(PayAmt),
             @BchVoidCnt = count(Id)
      from Chk 
      where CTpId = @ParmCTpId 
        and Id between @LowChkId and @MaxHiChkId
        and PdCd <> 0
        and VoidCd <> 0      
    end
  end

  /* 
   --------------------------------------------------------------------------------- 
      now that the child records have been deleted, and the Bch values have been
      accumulated, delete the Payments.
   ---------------------------------------------------------------------------------
  */
  Exec sp_executesql @DelChkCmd
  IF (@@error!=0)
  BEGIN
    --RAISERROR  20000 'ppSPDeletePayments: Delete Payments process failed (Chk)'
    ROLLBACK TRAN
    UPDATE Bch
    SET XCd1  = 'Failed Step Delete Chk', 
        XNum1 = @@error
    WHERE Num = @ParmDelBch
    RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  /* 
   --------------------------------------------------------------------------------- 
      delete rows from the ChkControl table that do not have a Chk "parent" row
   ---------------------------------------------------------------------------------
  */
  
  delete t 
  from ChkControl t
  left outer join Chk c on c.RecordId = t.ChkRecordId
  where c.RecordId is NULL
    
  update Bch
  set Amt1     = @BchTotPay,
      Amt2     = @BchTotVoid,
      Cnt1     = @BchChkCnt,
      Cnt2     = @BchVoidCnt,
      LowChkId = @BchLowChkId,
      HiChkId  = @BchHiChkId
  where Num = @ParmDelBch

  if @ParmImpBch <> 0 and @ParmDelBch <> 0
  begin -- when we have an Import Bch parameter, tie the Delete Bch to the Import Bch
    update Bch
    set BckCd     = 1, -- True
        RefBchNum = @ParmDelBch
    where Num = @ParmImpBch
  end

  COMMIT TRAN

  set nocount off
    
  RETURN /* Return with a zero status to indicate a successful process */

END

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPEmailDistListEmiEmnCopy]'
GO
ALTER Procedure [dbo].[ppSPEmailDistListEmiEmnCopy] (
            @ParmEMIId int,
            @Request varchar(1), -- (A)ppend or (R)eplace
            @ParmFromOprId varchar(30) -- the Opr who is signed into PayPilot
		)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible for copying EMN "child" rows for the
    requested EMI "parent" record. The EMN rows for the @ParmEMIId are copied to all
    other EMI parents of the same Typ (e.g. 'Approval')
   ---------------------------------------------------------------------------------
*/       
AS

declare @OprId varchar(30), @FromOprId varchar(30), @NextEMIId int, @Typ varchar(20)

if @Request is NULL begin
  --RAISERROR ('Email setup failure in stored proc ppSPEmailDistListEmiEmnCopy; Request parm is NULL', 16,1)
  return
end

if not (@Request = 'A' or @Request = 'R') begin
  --RAISERROR ('Email setup failure in stored proc ppSPEmailDistListEmiEmnCopy; Request parm is INVALID', 16,1)
  return
end

select @Typ = Typ from EMI where Id = @ParmEMIId
if @Typ is NULL begin
  --RAISERROR ('Email setup failure in stored proc ppSPEmailDistListEmiEmnCopy; EMI:Typ is NULL', 16,1)
  return
end

declare CopyEMIRows cursor for
select Id from EMI
 where Id <> @ParmEMIId
   and Typ = @Typ -- the EMI must be the same "Typ" of EMI record as the source

begin tran

if @Request = 'R' -- (R)eplace existing child rows
begin
  delete EMN
  where EMIId in (select Id from EMI where Id <> @ParmEMIId)
    and FromOprId = @ParmFromOprId
end

declare CopyEMNRows cursor for
select n.OprId from EMN n
inner join EMI i on i.Id = n.EMIId
where i.Id = @ParmEMIId
  and i.Typ = 'Approval'
  and n.FromOprId = @ParmFromOprId

open CopyEMNRows
fetch CopyEMNRows into @OprId
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each EMN record and copy it to each EMI parent of the same Typ
   -------------------------------------------------------------------------------------- */       

  open CopyEMIRows
  fetch CopyEMIRows into @NextEMIId
  while @@fetch_status = 0
  begin

    if not exists (
	select 1 from EMN 
        where EMIId = @NextEMIId 
          and OprId = @OprId
          and FromOprId = @ParmFromOprId
		)
    begin
      insert into EMN (
  	    EMIId,
	    OprId,
        FromOprId
	        )      
      values (
  	  @NextEMIId,
	  @OprId,
        @ParmFromOprId
	)
    end

    fetch CopyEMIRows into @NextEMIId  -- read the next EMI row

  end
  close CopyEMIRows

  fetch CopyEMNRows into @OprId

end
close CopyEMNRows
deallocate CopyEMNRows
deallocate CopyEMIRows

if @@error <> 0
begin
  --RAISERROR ('Email setup failure in stored proc ppSPEmailDistListEmiEmnCopy; rolling back changes', 16,1)
  rollback transaction
  return
end

commit tran

return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPEMISync]'
GO
ALTER procedure [dbo].[ppSPEMISync]
(
@LogHdrId int
)
as

declare @Id int

declare stageEMISynId cursor for
select Id FROM stageEMI

declare EMISynId cursor for
select Id FROM EMI

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageEMISynId
fetch stageEMISynId into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageEMI record and make sure that EMI records are identiEMI
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from EMI where Id = @Id)
  begin
    delete EMI	-- delete the existing record and insert it again from stageEMI
    where Id = @Id
  end

  set identity_insert EMI on
  
  insert into EMI
    (Id,
	Typ,
	DescText,
	FromEmailAdr,
	SubjectMrgId,
	MsgMrgId,
	CTpId,
	OverrideFromEmailAdr)
  select
	Id,
	Typ,
	DescText,
	FromEmailAdr,
	SubjectMrgId,
	MsgMrgId,
	CTpId,
	OverrideFromEmailAdr
  from stageEMI 
  where Id = @Id

  set identity_insert EMI off
  
  fetch stageEMISynId into @Id

END
close stageEMISynId
deallocate stageEMISynId

/* -------------------------------------------------------------------------------------- 
     Each EMI record must exist in stageEMI - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open EMISynId
fetch EMISynId into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageEMI where Id =@Id)
  begin
    delete EMI	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch EMISynId into @Id

END
close EMISynId
deallocate EMISynId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransEMIion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPEMISync: Unable to sync the EMI table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the EMIling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPEMNSync]'
GO
ALTER procedure [dbo].[ppSPEMNSync]
(
@LogHdrId int
)
as

declare @Id int

declare stageEMNSynId cursor for
select Id FROM stageEMN

declare EMNSynId cursor for
select Id FROM EMN

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageEMNSynId
fetch stageEMNSynId into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageEMN record and make sure that EMN records are identiEMN
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from EMN where Id = @Id)
  begin
    delete EMN	-- delete the existing record and insert it again from stageEMN
    where Id = @Id
  end

  set identity_insert EMN on
  
  insert into EMN
    (Id,
	EMIId,
	OprId,
	FromOprId)
  select
	Id,
	EMIId,
	OprId,
	FromOprId
  from stageEMN 
  where Id = @Id

  set identity_insert EMN off
  
  fetch stageEMNSynId into @Id

END
close stageEMNSynId
deallocate stageEMNSynId

/* -------------------------------------------------------------------------------------- 
     Each EMN record must exist in stageEMN - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open EMNSynId
fetch EMNSynId into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageEMN where Id =@Id)
  begin
    delete EMN	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch EMNSynId into @Id

END
close EMNSynId
deallocate EMNSynId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransEMNion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPEMNSync: Unable to sync the EMN table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the EMNling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPFLTSync]'
GO
ALTER procedure [dbo].[ppSPFLTSync]
(
@LogHdrId int
)
as

declare @Id int

declare stageFLTSynId cursor for
select Id FROM stageFLT

declare FLTSynId cursor for
select Id FROM FLT

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageFLTSynId
fetch stageFLTSynId into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageFLT record and make sure that FLT records are identiFLT
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from FLT where Id = @Id)
  begin
    delete FLT	-- delete the existing record and insert it again from stageFLT
    where Id = @Id
  end

  insert into FLT
  select * from stageFLT 
  where Id = @Id

  fetch stageFLTSynId into @Id

END
close stageFLTSynId
deallocate stageFLTSynId

/* -------------------------------------------------------------------------------------- 
     Each FLT record must exist in stageFLT - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open FLTSynId
fetch FLTSynId into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageFLT where Id =@Id)
  begin
    delete FLT	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch FLTSynId into @Id

END
close FLTSynId
deallocate FLTSynId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransFLTion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPFLTSync: Unable to sync the FLT table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the FLTling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPGetVndTrmId]'
GO
ALTER PROCEDURE [dbo].[ppSPGetVndTrmId]
(
@ImpBchNum int
)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible for updating each check's payment terms for
    checks imported for vendors who are assigned to a group vendor.
   ---------------------------------------------------------------------------------
*/       
AS
BEGIN

declare @Cmd nvarchar(4000)

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

update Chk
set TrmId = (
        select grp.TrmId 
        from Vnd grp
        inner join Vnd v2 on v2.Typ = grp.Typ and v2.Id = grp.Id
        inner join Chk c2 on c2.VndTyp = v2.Typ and c2.VndId = v2.Id
        where c2.RecordId = c1.RecordId
            )
from Chk c1
inner join Vnd v1 on v1.Typ = c1.VndTyp and v1.Id = c1.VndId
and c1.ImpBch = @ImpBchNum

IF (@@error!=0)
BEGIN
    --RAISERROR  20000 'ppSPGetVndTrmId: updating Checks for Group TrmId has failed'
    ROLLBACK TRAN
    RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END
  
COMMIT TRAN

set nocount off
    
RETURN /* Return with a zero status to indicate a successful process */

END

 /* Procedure */
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPInsertReportRequest]'
GO


ALTER PROCEDURE [dbo].[ppSPInsertReportRequest]
(
	@RequestDt                          int,
	@RequestTime                        int,
	@RunId                              varchar(18),
	@OprId                              varchar(30),
	@PrtPgm                             varchar(10),
	@FilterCriteria                     varchar(500),
	@SortCriteria                       varchar(500),
	@DetailSummay                       varchar(1),
	@BchOrDate                          varchar(1),
	@Dest                               varchar(1),
	@CTpId                              smallint,
	@RptCopies                          tinyint,
	@StartDt                            int,
	@StartTime                          int,
	@EndDt                              int,
	@EndTime                            int,
	@ErrorCd                            int,
	@ErrorTyp                           varchar(1),
	@CancelDt                           int,
	@CancelTime                         int,
	@CancelOprId                        varchar(30),
	@BchNum                             int,
	@Status                             varchar(20),
	@CreateNonTraditional               tinyint,
	@PrintRpt                           tinyint,
	@ImageFolder                        varchar(255),
	@EmiId                              int,
	@RptId                              int
)
AS
BEGIN
	BEGIN TRAN
	INSERT INTO dbo.ReportRequest	(
		RequestDt,
		RequestTime,
		RunId,
		OprId,
		PrtPgm,
		FilterCriteria,
		SortCriteria,
		DetailSummay,
		BchOrDate,
		Dest,
		CTpId,
		RptCopies,
		StartDt,
		StartTime,
		EndDt,
		EndTime,
		ErrorCd,
		ErrorTyp,
		CancelDt,
		CancelTime,
		CancelOprId,
		BchNum,
		Status,
		CreateNonTraditional,
		PrintRpt,
		ImageFolder,
		EmiId,
		RptId)
	VALUES	
	(
		@RequestDt,
		@RequestTime,
		@RunId,
		@OprId,
		@PrtPgm,
		@FilterCriteria,
		@SortCriteria,
		@DetailSummay,
		@BchOrDate,
		@Dest,
		@CTpId,
		@RptCopies,
		@StartDt,
		@StartTime,
		@EndDt,
		@EndTime,
		@ErrorCd,
		@ErrorTyp,
		@CancelDt,
		@CancelTime,
		@CancelOprId,
		@BchNum,
		@Status,
		@CreateNonTraditional,
		@PrintRpt,
		@ImageFolder,
		@EmiId,
		@RptId
	)

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ReportRequest_INS: Cannot insert data into ReportRequest_INS '
        ROLLBACK TRAN
        RETURN(1)
    END

    COMMIT TRAN
END

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPInsPrinterSelect]'
GO
ALTER   procedure [dbo].[ppSPInsPrinterSelect]
(
@ParmRunId varchar(18),
@ParmGrpId smallint
)
as

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

/* -------------------------------------------------------------------------------------- 
    For each PrinterDefault record for the GrpId parameter insert a PrinterSelect record
    for the passed RunId parameter.
   -------------------------------------------------------------------------------------- */       

  insert into PrinterSelect (
     RunId, 
	 PrinterTyp, 
	 PriorityCd,
	 ServPrinterId, 
	 BinId, 
	 SuppBinId,
     ChkCnt,
     PageCnt,
     PaperCnt,
     EnvCnt
        )
  select @ParmRunId, 
	 d.PrinterTyp, 
	 d.PriorityCd,
	 d.ServPrinterId, 
	 d.BinId, 
	 d.SuppBinId,
     0 ChkCnt,
     0 PageCnt,
     0 PaperCnt,
     0 EnvCnt
    from PrinterDefault d
   inner join ServPrinter s on s.Id = d.ServPrinterId
   where d.GrpId = @ParmGrpId
     and s.ActiveCd = 1
     and ((d.PrinterTyp = 'check' and s.PrintChk = 1) or 
          (d.PrinterTyp = 'copy'  and s.PrintCopy = 1) or
          (d.PrinterTyp = 'register' and s.PrintReg = 1))
  
/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPInsPrinterSelect: Unable to load the PrinterSelect table'
  ROLLBACK TRAN
  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPLogDtlInsert]'
GO
ALTER procedure [dbo].[ppSPLogDtlInsert]
(
	@LogHdrId                           int,
	@TableName                          varchar(50),
	@LogTyp                             varchar(30),
	@CommentTxt                         varchar(1000),
	@IndexTxt                           varchar(255),
	@ErrorCode                          int,
	@ErrorTxt                           varchar(255),
	@ProcedureName                      varchar(30),
	@RoutineName                        varchar(30),
	@Location                           int,
	@MsgNum                             int,
	@MsgTyp                             varchar(1),
	@PayAmt                             decimal(11,2),
    @XMLDescXML                         nvarchar(4000)
)
as
begin

    declare @LogDtlId int, @XMLDesc nvarchar(4000)
    
    if @LogHdrId is NULL or @LogHdrId = 0
    begin
      --RAISERROR  20000 'ppSPLogDtlInsert: the LogHdrId is either 0 or NULL; this is invalid'
      select -1         /* return a non-zero value */
    end

    set nocount on
    
	begin tran
    
	insert into dbo.LogDtl	(
		LogHdrId,
		MsgNum,
		CommentTxt,
		ErrorCode,
		RoutineName,
		MsgTyp,
		IndexTxt,
		ErrorTxt,
		TableName,
		Location,
		PayAmt,
		LogTyp,
		ProcedureName,
		DateTime)
	values	
	(
		@LogHdrId,
		@MsgNum,
		@CommentTxt,
		@ErrorCode,
		@RoutineName,
		@MsgTyp,
		@IndexTxt,
		@ErrorTxt,
		@TableName,
		@Location,
		@PayAmt,
		@LogTyp,
		@ProcedureName,
		GetDate()
	)

    if (@@error!=0)
    begin
      --RAISERROR  20000 'ppSPLogDtlInsert: Unable to insert data into LogDtl'
      rollback tran
      select -1         /* return a non-zero value */
    end

    set @LogDtlId = (select scope_identity())
    
    set @XMLDesc = convert(nvarchar(4000), @XMLDescXML)
    
    if @XMLDesc <> '' and @XMLDesc is not NULL
    begin
      insert into dbo.LogDtlXML (
		LogDtlId,
        XMLDesc)
	  values	
	  (
		@LogDtlId,
        @XMLDesc
      )
    end
    
    select @LogDtlId /* return the LogDtl scope_identity() to the calling application */

    commit tran

    set nocount off

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPMarkChksPrinted]'
GO
ALTER PROCEDURE [dbo].[ppSPMarkChksPrinted] 
(
@CTpId smallint,
@LowChkId int,
@HiChkId int,
@CTpDfltPrtDt char(1),
@OprId varchar(30)
)
AS
declare @eTranMarkPrt smallint, @Date int, @Time int

set nocount on

set @eTranMarkPrt = 82
set @Date = convert(int,datediff(dd, '12/28/1800',getdate()))
set @Time = convert(int,substring(convert(varchar(20),getdate(),108),1,2) + substring(convert(varchar(20),getdate(),108),4,2)) * 3600 + 30000

if @CTpId = 0
begin
  --RAISERROR  20000 'ppSPMarkChksPrinted: Unable to process...Payment Type = 0'
  ROLLBACK TRAN
  RETURN /* Return a non-zero status to the calling process to indicate failure */
end

if @LowChkId = 0
begin
  --RAISERROR  20000 'ppSPMarkChksPrinted: Unable to process...LowChkId = 0'
  ROLLBACK TRAN
  RETURN /* Return a non-zero status to the calling process to indicate failure */
end

if @HiChkId = 0
begin
  --RAISERROR  20000 'ppSPMarkChksPrinted: Unable to process...@HiChkId = 0'
  ROLLBACK TRAN
  RETURN /* Return a non-zero status to the calling process to indicate failure */
end

set rowcount 100

While exists (
	      select 1
	        from Chk 
	       where CTpId = @CTpId 
		 and Id between @LowChkId and @HiChkId
		 and PrtCnt = 0
		 and VoidCd = 0
		 )
Begin

  Begin Tran

	if @CTpDfltPrtDt = 'A'
	begin
		update Chk
		set PrtCnt   =  1,
			PrtBch   = -2,
			ModVer   = ModVer + 1,
			TranTyp  = @eTranMarkPrt,
			ChgDt    = @Date,
			ChgTime  = @Time,
			TranDt   = @Date,
			TranTime = @Time,
			TranId   = @OprId,
			PrtDt    = AddDt		-- use the Chk.AddDt when the DfltPrtDt = 'A'
		from Chk
		where CTpId = @CTpId
		  and Id between @LowChkId and @HiChkId
		  and PrtCnt = 0
		  and VoidCd = 0
	end
	else
	begin
		update Chk
		set PrtCnt   =  1,
			PrtBch   = -2,
			ModVer   = ModVer + 1,
			TranTyp  = @eTranMarkPrt,
			ChgDt    = @Date,
			ChgTime  = @Time,
			TranDt   = @Date,
			TranTime = @Time,
			TranId   = @OprId,
			PrtDt    = IssDt		-- use the Chk.AddDt when the DfltPrtDt = 'A'
		from Chk
		where CTpId = @CTpId
		  and Id between @LowChkId and @HiChkId
		  and PrtCnt = 0
          and VoidCd = 0
    end -- begin

    if (@@error!=0)
    begin
        --RAISERROR  20000 'ppSPMarkChksPrinted: stored proc unable to update Checks as printed'
        ROLLBACK TRAN
        RETURN /* Return a non-zero status to the calling process to indicate failure */
    end

  commit tran /* end Tran */

end /* end of Loop */

set nocount off

select count(RecordId) 'Id' from chk  
where CTpId = @CTpId
  AND Id      >= @LowChkId
  AND Id      <= @HiChkId
  AND TranDt   = @Date
  AND TranTime = @Time
  AND TranId   = @OprId
  AND TranTyp  = @eTranMarkPrt
  AND PrtCnt   = 1
  AND PrtBch   = -2

set rowcount 0

return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPMarkChksPrinted_Publix]'
GO
ALTER   PROCEDURE [dbo].[ppSPMarkChksPrinted_Publix]
AS

Declare @CTpId smallint, @LowChkId int, @HiChkId int, @OprId varchar(30), @eTranMarkPrt smallint, @Date int, @Time int

/* Set parameters using values stored in tblUpdatePrintStatus_Publix */
Set @CTPID = (Select Value From tblUpdatePrintStatus_Publix Where Variable = 'PaymentTypeID')
Set @LowChkID = (Select Value From tblUpdatePrintStatus_Publix Where Variable = 'LowChkID')
Set @HiChkID = (Select Value From tblUpdatePrintStatus_Publix Where Variable = 'HighChkID')
Set @OprID = (Select Value From tblUpdatePrintStatus_Publix Where Variable = 'OperatorID')
Set @eTranMarkPrt = 82
Set @Date = convert(int,datediff(dd, '12/28/1800',getdate()))
Set @Time = convert(int,substring(convert(varchar(20),getdate(),108),1,2) + substring(convert(varchar(20),getdate(),108),4,2)) * 3600 + 30000

if @CTpId = 0
begin
  --RAISERROR  20000 'ppSPMarkChksPrinted: Unable to process...Payment Type = 0'
  ROLLBACK TRAN
  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
end

if @LowChkId = 0
begin
  --RAISERROR  20000 'ppSPMarkChksPrinted: Unable to process...LowChkId = 0'
  ROLLBACK TRAN
  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
end

if @HiChkId = 0
begin
  --RAISERROR  20000 'ppSPMarkChksPrinted: Unable to process...@HiChkId = 0'
  ROLLBACK TRAN
  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
end

set rowcount 1000

While exists (
	      select 1
	        from Chk 
	       where CTpId = @CTpId 
		 and Id between @LowChkId and @HiChkId
		 and PrtCnt = 0
		 )
Begin

  Begin Tran

    update Chk
    set PrtCnt   =  1,
        PrtBch   = -2,
        ModVer   = ModVer + 1,
        TranTyp  = @eTranMarkPrt,
        ChgDt    = @Date,
        ChgTime  = @Time,
        TranDt   = @Date,
        TranTime = @Time,
        TranId   = @OprId,
        PrtDt    = IssDt		-- use the Chk.IssDt when the DfltPrtDt <> 'A'
    from Chk
    where CTpId = @CTpId
      and Id between @LowChkId and @HiChkId
      and PrtCnt = 0

    if (@@error!=0)
    begin
        --RAISERROR  20000 'ppSPMarkChksPrinted: stored proc unable to update Checks as printed'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    end

  commit tran /* end Tran */

end /* end of Loop */

set rowcount 0
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPMrgSync]'
GO
ALTER procedure [dbo].[ppSPMrgSync]
(
@LogHdrId int
)
as

declare @Id varchar(15), @Typ varchar(2)

declare stageMrgSynId cursor for
select Id, Typ FROM stageMrg

declare MrgSynId cursor for
select Id, Typ FROM Mrg

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageMrgSynId
fetch stageMrgSynId into @Id, @Typ
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageMrg record and make sure that Mrg records are identiMrg
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Mrg where Id = @Id and Typ = @Typ)
  begin
    delete Mrg	-- delete the existing record and insert it again from stageMrg
    where Id = @Id and Typ = @Typ
  end

  insert into Mrg
  select * from stageMrg 
  where Id = @Id and Typ = @Typ
  
  fetch stageMrgSynId into @Id, @Typ

end
close stageMrgSynId
deallocate stageMrgSynId

/* -------------------------------------------------------------------------------------- 
     Each Mrg record must exist in stageMrg - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open MrgSynId
fetch MrgSynId into @Id, @Typ
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageMrg where Id = @Id and Typ = @Typ)
  begin
    delete Mrg	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch MrgSynId into @Id, @Typ

END
close MrgSynId
deallocate MrgSynId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransMrgion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPMrgSync: Unable to sync the Mrg table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the Mrgling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPOATSync]'
GO
ALTER procedure [dbo].[ppSPOATSync]
(
@LogHdrId int
)
as

declare @OprId varchar(30), @PayCd varchar(30)

declare stageOATSynOprId cursor for
select OprId, PayCd FROM stageOAT

declare OATSynOprId cursor for
select OprId, PayCd FROM OAT

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageOATSynOprId
fetch stageOATSynOprId into @OprId, @PayCd
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageOAT record and make sure that OAT records are OprIdentiOAT
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from OAT where OprId = @OprId and PayCd = @PayCd)
  begin
    delete OAT	-- delete the existing record and insert it again from stageOAT
    where OprId = @OprId and PayCd = @PayCd
  end

  insert into OAT
  select * from stageOAT 
  where OprId = @OprId and PayCd = @PayCd
  
  fetch stageOATSynOprId into @OprId, @PayCd

end
close stageOATSynOprId
deallocate stageOATSynOprId

/* -------------------------------------------------------------------------------------- 
     Each OAT record must exist in stageOAT - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open OATSynOprId
fetch OATSynOprId into @OprId, @PayCd
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageOAT where OprId = @OprId and PayCd = @PayCd)
  begin
    delete OAT	-- delete the operational record with no match to the stage table
    where OprId = @OprId and PayCd = @PayCd
  end

  fetch OATSynOprId into @OprId, @PayCd

END
close OATSynOprId
deallocate OATSynOprId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransOATion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPOATSync: Unable to sync the OAT table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the OATling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPOEMMaint]'
GO
ALTER procedure [dbo].[ppSPOEMMaint]
as

declare @OprId varchar(30)

declare OEMUpdtd cursor for
select OprId FROM OEM

declare stageOEMUpdtd cursor for
select OprId FROM stageOEM

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open OEMUpdtd
fetch OEMUpdtd into @OprId
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each OEM record and make sure that stageOEM records are Identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from stageOEM where OprId = @OprId)
  begin
    delete stageOEM	-- delete the existing record and insert it again from OEM
    where OprId = @OprId
  end

  insert into stageOEM
  select * from OEM
  where OprId = @OprId

  fetch OEMUpdtd into @OprId

END
close OEMUpdtd
deallocate OEMUpdtd

/* -------------------------------------------------------------------------------------- 
     Each stageOEM record must exist in OEM - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open stageOEMUpdtd
fetch stageOEMUpdtd into @OprId
while @@fetch_status = 0
begin

  if NOT exists (select 1 from OEM where OprId = @OprId)
  begin
    delete stageOEM	-- delete the stage record with no match to the operational table
    where OprId = @OprId
  end

  fetch stageOEMUpdtd into @OprId

END
close stageOEMUpdtd
deallocate stageOEMUpdtd

/* --------------------------------------------------------------------------------- 
    OEMmit, or Rollback the Transaction, based on the success or failure of the
    processing to this point.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPOEMMaint: Cannot update the stageOEM table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off

Exec ppSPLastMaintDate



 --identifies the last time that Admin maintenance was applied
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPOEMSync]'
GO
ALTER procedure [dbo].[ppSPOEMSync]
(
@LogHdrId int
)
as

declare @OprId varchar(30), @Typ varchar(30)

declare stageOEMSynOprId cursor for
select OprId, Typ FROM stageOEM

declare OEMSynOprId cursor for
select OprId, Typ FROM OEM

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageOEMSynOprId
fetch stageOEMSynOprId into @OprId, @Typ
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageOEM record and make sure that OEM records are OprIdentiOEM
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from OEM where OprId = @OprId and Typ = @Typ)
  begin
    delete OEM	-- delete the existing record and insert it again from stageOEM
    where OprId = @OprId and Typ = @Typ
  end

  insert into OEM
  select * from stageOEM 
  where OprId = @OprId and Typ = @Typ
  
  fetch stageOEMSynOprId into @OprId, @Typ

end
close stageOEMSynOprId
deallocate stageOEMSynOprId

/* -------------------------------------------------------------------------------------- 
     Each OEM record must exist in stageOEM - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open OEMSynOprId
fetch OEMSynOprId into @OprId, @Typ
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageOEM where OprId = @OprId and Typ = @Typ)
  begin
    delete OEM	-- delete the operational record with no match to the stage table
    where OprId = @OprId and Typ = @Typ
  end

  fetch OEMSynOprId into @OprId, @Typ

END
close OEMSynOprId
deallocate OEMSynOprId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransOEMion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPOEMSync: Unable to sync the OEM table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the OEMling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPOFPSync]'
GO
ALTER procedure [dbo].[ppSPOFPSync]
(
@LogHdrId int
)
as

declare @RecordId int

declare stageOFPSynRecordId cursor for
select RecordId FROM stageOFP

declare OFPSynRecordId cursor for
select RecordId FROM OFP

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageOFPSynRecordId
fetch stageOFPSynRecordId into @RecordId
while @@fetch_status = 0
begin

/* -------------------------------------------------------------------------------------- 
     Read through each stageOFP record and make sure that OFP records are RecordIdentiOFP
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from OFP where RecordId = @RecordId)
  begin
    delete OFP	-- delete the existing record and insert it again from stageOFP
    where RecordId = @RecordId
  end

  set identity_insert OFP on
  
  insert into OFP (
    RecordId,	
    Nam,
	Adr1,
	Adr2,
	Adr3,
	Adr4,
	Adr5,
	XCd1,
	XCd2,
	XCd3,
	XCd4,
	XCd5,
	XNum1,
	XNum2,
	XNum3,
	LastChgId,
	LastChgDt,
	LastChgTm,
	AllAdr,
	PolId
    )
  select 
    RecordId,	
    Nam,
	Adr1,
	Adr2,
	Adr3,
	Adr4,
	Adr5,
	XCd1,
	XCd2,
	XCd3,
	XCd4,
	XCd5,
	XNum1,
	XNum2,
	XNum3,
	LastChgId,
	LastChgDt,
	LastChgTm,
	AllAdr,
	PolId
 from stageOFP 
  where RecordId = @RecordId

  set identity_insert OFP off
  
  fetch stageOFPSynRecordId into @RecordId

end
close stageOFPSynRecordId
deallocate stageOFPSynRecordId

/* -------------------------------------------------------------------------------------- 
     Each OFP record must exist in stageOFP - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open OFPSynRecordId
fetch OFPSynRecordId into @RecordId
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageOFP where RecordId = @RecordId)
  begin
    delete OFP	-- delete the operational record with no match to the stage table
    where RecordId = @RecordId
  end

  fetch OFPSynRecordId into @RecordId

END
close OFPSynRecordId
deallocate OFPSynRecordId

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransOFPion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPOFPSync: Unable to sync the OFP table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the OFPling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPOutMaint]'
GO
ALTER procedure [dbo].[ppSPOutMaint]
as

declare @SeqNum int

set IDENTITY_INSERT Out on

declare OutUpdtd cursor for
select SeqNum FROM Out

declare stageOutUpdtd cursor for
select SeqNum FROM stageOut

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open OutUpdtd
fetch OutUpdtd into @SeqNum
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each Out record and make sure that stageOut records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from stageOut where SeqNum = @SeqNum)
  begin
    delete stageOut	-- delete the existing record and insert it again from Out
    where SeqNum = @SeqNum
  end

  insert into stageOut
  select * from Out
  where SeqNum = @SeqNum

  fetch OutUpdtd into @SeqNum

END
close OutUpdtd
deallocate OutUpdtd

/* -------------------------------------------------------------------------------------- 
     Each stageOut record must exist in Out - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open stageOutUpdtd
fetch stageOutUpdtd into @SeqNum
while @@fetch_status = 0
begin

  if NOT exists (select 1 from Out where SeqNum = @SeqNum)
  begin
    delete stageOut	-- delete the stage record with no match to the operational table
    where SeqNum = @SeqNum
  end

  fetch stageOutUpdtd into @SeqNum

END
close stageOutUpdtd
deallocate stageOutUpdtd

set IDENTITY_INSERT Out off

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing to this point.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPOutMaint: Cannot update the stageOut table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off

Exec ppSPLastMaintDate




 --identifies the last time that Admin maintenance was applied
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPOutSync]'
GO
ALTER procedure [dbo].[ppSPOutSync]
(
@LogHdrId int
)
as

declare @SeqNum int, @LastChgId varchar(15), @Msg varchar(100)
declare @status tinyint, @RngId int, @LowChkId decimal(11,0), @HichkId decimal(11,0), @ChkCnt smallint

set @LastChgId = 'ppSPOutSync'

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

/* --------------------------------------------------------------------------------------
     Modification: applied on 11/3/2010 to update the "current" Out row
   -------------------------------------------------------------------------------------- */

  update o
  set o.status    = s.status,
      o.RngId     = s.RngId,
      o.LowChkId  = s.LowChkId,
      o.HichkId   = s.HichkId,
      o.ChkCnt    = s.ChkCnt,
      o.LastChgId = s.LastChgId,
      o.LastChgDt = s.LastChgDt,
      o.LastChkId = s.LastChkId
    from Out o
    inner join stageOut s on s.SeqNum = o.SeqNum
    where o.LastChkId < s.LastChkId

/* --------------------------------------------------------------------------------------
     Modification: applied on 6/22/2011 to update the Out row if the 
     status on the Host has been changed to a 2
   -------------------------------------------------------------------------------------- */

  update o
  set o.status = s.status
  from Out o
  inner join stageOut s on s.SeqNum = o.SeqNum
  where o.status <> 2
      and s.status = 2

  set IDENTITY_INSERT Out on
  
  insert into Out
   (
    SeqNum,
    OprId,
    CTpId,
    RngId,
    LowChkId,
    HiChkId,
    IssDt,
    ChkCnt,
    LastChgDt,
    LastChgId,
    Status,
    XCd1,
    XCd2,
    XCd3,
    XCd4,
    XCd5,
    XNum1,
    XNum2,
    XNum3,
    LastChkId,
    LastChgTm
    )
  select *  from stageOut
  where SeqNum not in (select SeqNum from Out)

  set IDENTITY_INSERT Out off

  delete Out  -- delete the operational record with no match to the stage table
  where SeqNum not in (select SeqNum from stageOut)

/* ---------------------------------------------------------------------------------
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */

  IF (@@error!=0)
  BEGIN
    --RAISERROR  20000 'ppSPOutSync: Unable to sync the Out table'
    ROLLBACK TRAN

    RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPPayMaint]'
GO
ALTER procedure [dbo].[ppSPPayMaint]
as

declare @Cd varchar(11)

declare PayUpdtd cursor for
select Cd FROM Pay

declare stagePayUpdtd cursor for
select Cd FROM stagePay

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open PayUpdtd
fetch PayUpdtd into @Cd
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each Pay record and make sure that stagePay records are Identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from stagePay where Cd = @Cd)
  begin
    delete stagePay	-- delete the existing record and insert it again from Pay
    where Cd = @Cd
  end

  insert into stagePay
  select * from Pay
  where Cd = @Cd

  fetch PayUpdtd into @Cd

END
close PayUpdtd
deallocate PayUpdtd

/* -------------------------------------------------------------------------------------- 
     Each stagePay record must exist in Pay - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open stagePayUpdtd
fetch stagePayUpdtd into @Cd
while @@fetch_status = 0
begin

  if NOT exists (select 1 from Pay where Cd = @Cd)
  begin
    delete stagePay	-- delete the stage record with no match to the operational table
    where Cd = @Cd
  end

  fetch stagePayUpdtd into @Cd

END
close stagePayUpdtd
deallocate stagePayUpdtd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing to this point.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPPayMaint: Cannot update the stagePay table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off

Exec ppSPLastMaintDate




 --identifies the last time that Admin maintenance was applied
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPPaySync]'
GO
ALTER procedure [dbo].[ppSPPaySync]
(
@LogHdrId int
)
as

declare @Cd varchar(11)

declare stagePaySyncd cursor for
select Cd FROM stagePay

declare PaySyncd cursor for
select Cd FROM Pay

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

update stagePay
set Typ = ''
where Typ is NULL

open stagePaySyncd
fetch stagePaySyncd into @Cd
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stagePay record and make sure that Pay records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Pay where Cd = @Cd)
  begin
    delete Pay	-- delete the existing record and insert it again from stagePay
    where Cd = @Cd
  end

  insert into Pay
  select *  from stagePay 
  where Cd = @Cd
  
  fetch stagePaySyncd into @Cd

END
close stagePaySyncd
deallocate stagePaySyncd

/* -------------------------------------------------------------------------------------- 
     Each Pay record must exist in stagePay - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open PaySyncd
fetch PaySyncd into @Cd
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stagePay where Cd = @Cd)
  begin
    delete Pay	-- delete the operational record with no match to the stage table
    where Cd = @Cd
  end

  fetch PaySyncd into @Cd

END
close PaySyncd
deallocate PaySyncd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPPaySync: Unable to sync the Pay table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPPayTypMaint]'
GO
ALTER procedure [dbo].[ppSPPayTypMaint]
as

declare @id int

set IDENTITY_INSERT PayTyp on

declare PayTypUpdtd cursor for
select Id FROM PayTyp

declare stagePayTypUpdtd cursor for
select Id FROM stagePayTyp

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open PayTypUpdtd
fetch PayTypUpdtd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each PayTyp record and make sure that stagePayTyp records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from stagePayTyp where Id = @Id)
  begin
    delete stagePayTyp	-- delete the existing record and insert it again from PayTyp
    where Id = @Id
  end

  insert into stagePayTyp
  select * from PayTyp
  where Id = @Id

  fetch PayTypUpdtd into @Id

END
close PayTypUpdtd
deallocate PayTypUpdtd

/* -------------------------------------------------------------------------------------- 
     Each stagePayTyp record must exist in PayTyp - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open stagePayTypUpdtd
fetch stagePayTypUpdtd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from PayTyp where Id = @Id)
  begin
    delete stagePayTyp	-- delete the stage record with no match to the operational table
    where Id = @Id
  end

  fetch stagePayTypUpdtd into @Id

END
close stagePayTypUpdtd
deallocate stagePayTypUpdtd

set IDENTITY_INSERT PayTyp off

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing to this point.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPPayTypMaint: Cannot update the stagePayTyp table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off

Exec ppSPLastMaintDate


 --identifies the last time that Admin maintenance was applied
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPPayTypSync]'
GO
ALTER  procedure [dbo].[ppSPPayTypSync]
(
@LogHdrId int
)
as

declare @id int

set IDENTITY_INSERT PayTyp on

declare stagePayTypSyncd cursor for
select Id FROM stagePayTyp

declare PayTypSyncd cursor for
select Id FROM PayTyp

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stagePayTypSyncd
fetch stagePayTypSyncd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stagePayTyp record and make sure that PayTyp records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from PayTyp where Id = @Id)
  begin
    delete PayTyp	-- delete the existing record and insert it again from stagePayTyp
    where Id = @Id
  end

  insert into PayTyp(
        RcdId,
        Id,
        ChkNam,
        ShrtNam,
        Abbrev,
        CmpNam,
        DfltCmpId,
        ActCd,
        GrpCd,
        GrpId,
        RngId,
        BIHId,
        MultRng,
        DfltPrtDt,
        ImpVnd,
        FastEntry,
        FastEntryCnfrmCd,
        FastEntryExA,
        FastEntryVch,
        FastEntryTxt,
        AutoDt,
        AutoNum,
        AlphaChkId,
        ClrChk,
        ClrChkExcp,
        AddSigCut,
        ManSigCut,
        MaxPay,
        MaxMan,
        MultPrtCd,
        SigMsg1,
        SigMsg2,
        ChkMsg,
        ChkMsg2,
        ChkMsg3,
        ChkMsg4,
        ChkMsg5,
        ImpFil,
        ImpFilExt,
        ImpSuppFilExt,
        ImpFilPath,
        ImpBak,
        ImpBakCd,
        ImpBakDays,
        ImpBakPath,
        FTPFil,
        EftFil,
        DebitFil,
        AckFil,
        MsgMrgId,
        SubjectMrgId,
        ChkPrtCnt,
        BchSize,
        ChkPrtDevice,
        ChkPrt2Device,
        ChkPrt3Device,
        ChkPrt4Device,
        ChkTray,
        ChkTray2,
        ChkTray3,
        ChkTray4,
        SuppTray,
        SuppTray2,
        SuppTray3,
        SuppTray4,
        CpyTray,
        RptTray,
        ChkPrtTyp,
        CpyPrtTyp,
        RegCopies,
        FilCpyCopies,
        AutoCpy,
        TwoSigOver,
        TwoSigAlways,
        MissVndCopies,
        ImpSumCopies,
        ImpErrCopies,
        ImpSumPreview,
        MicrTyp,
        MicrVert,
        MicrHorz,
        CrMicrVert,
        CrMicrHorz,
        ScanLineVert,
        ScanLineHorz,
        FntTyp,
        ChkSrt1,
        ChkSrt2,
        ChkSrt3,
        RegSrt1,
        RegSrt2,
        RegSrt3,
        PrtPgm,
        SpoilLbl,
        SpoilTxt1,
        SpoilTxt2,
        SpoilTxt3,
        RcnDflt,
        AgentClmDflt,
        BldRcn,
        DelImp,
        AutoClr,
        BnkId,
        VfyImp,
        VfyChk,
        PrtPasswd,
        VndTyp,
        VndTyp1099,
        AgentTyp,
        TaxVndTyp,
        EmployerTyp,
        ProviderTyp,
        CarrierTyp,
        ExaminerTyp,
        ApprovCd,
        ApprovAmt,
        ApprovFromEmailAdr,
        ApprovSubjectMrgId,
        ApprovMsgMrgId,
        ApprovAmt1,
        ApprovAmt2,
        ApprovAmt3,
        ApprovAmt4,
        ApprovAmt5,
        ApprovAmt6,
        ApprovAmt7,
        ApprovAmt8,
        ApprovAmt9,
        ApprovNotify1,
        ApprovNotify2,
        ApprovNotify3,
        ApprovNotify4,
        ApprovNotify5,
        ApprovNotify6,
        ApprovNotify7,
        ApprovNotify8,
        ApprovNotify9,
        ManSigRptCd,
        ForRsnFwd,
        MailToVnd,
        PayToVnd,
        MailToDflt,
        PayToIns,
        AltChkKey,
        AltChk1Key,
        UprCase,
        QCPayAmtAdd,
        QCPayAmtUpd,
        PrtChk,
        ImpChk,
        Dflt1099,
        Bld1099,
        TaxForm,
        AllPayHst,
        ManEntryHst,
        ImpHst,
        PrtHst,
        ReprintHst,
        VoidHst,
        PosPayHst,
        WriteOffHst,
        PaidHst,
        EftHst,
        OtherHst,
        VoidRsnReq,
        StopRsnReq,
        WriteOffRsnReq,
        PayFromEmailAdr,
        PaySubjectMrgId,
        PayMsgMrgId,
        ImpErrFromEmailAdr,
        ImpErrSubjectMrgId,
        ImpErrMsgMrgId,
        XFromEmailAdr1,
        XSubjectMrgId1,
        XMsgMrgId1,
        XFromEmailAdr2,
        XSubjectMrgId2,
        XMsgMrgId2,
        FaxCoverSheet,
        FaxFromNam,
        FaxFromCmp,
        FaxFromVoiceNum,
        FaxFromFaxNum,
        FaxFromAdr1,
        FaxFromAdr2,
        FaxFromAdr3,
        FaxFromAdr4,
        FaxSubjectMrgId,
        FaxMsgMrgId,
        XHst1,
        XHst2,
        XHst3,
        XHst4,
        XHst5,
        XHst6,
        XHst7,
        XHst8,
        XHst9,
        ImpExcp,
        OutOprId,
        EFT,
        EftEntryTyp,
        EftCd,
        EftSel,
        EftCmp,
        EftTxt,
        EftNum,
        EftCls,
        EftDesc,
        EftDt,
        DepositCd,
        IPAdr,
        AutoFilCpyPrt,
        FilCpySrt1,
        FilCpySrt2,
        FilCpySrt3,
        ChkImg,
        ChkImgCpyTyp,
        ChkImgFolder,
        ChkImgFileName,
        ChkImgNdxFileName,
        ApprovedNotify,
        ApprovedNotifyTyp,
        ApprovedNotifyId,
        ApprovedFromEmailAdr,
        ApprovedSubjectMrgId,
        ApprovedMsgMrgId,
        QueryFld,
        QueryLimit,
        AutoImpPayTypCd,
        AutoImpPayTypValue,
        UnivPrtMagic,
        ACHZeroRcd,
        RcpId,
        PayFlagNotifyFromEmailAdr,
        PayFlagNotifySubjectMrgId,
        PayFlagNotifyMsgMrgId,
        PayFlagImpRptTyp,
        PayFlagEmailNoMatch,
        PayFlagRptFreq,
        PayFlagLastMatchDt,
        PrtZeroPayAmt,
        SubCTpId,
        CollationPrt,
        ApprovByOpr,
        ReissueTyp,
        HidePrtAll,
        StartChk,
        StartChkMax,
        StartChkDflt,
        PayTrm,
        LastChgId,
        LastChgDt,
        LastChgTm,
        XAmt1,
        XAmt2,
        XCd1,
        XCd2,
        XCd3,
        XCd4,
        XCd5,
        XCd6,
        XCd7,
        XCd8,
        XCd9,
        XCd10,
        XCd11,
        XCd12,
        XCd13,
        XCd14,
        XCd15,
        XCd16,
        XCd17,
        XCd18,
        XCd19,
        XCd20,
        XCd21,
        XCd22,
        XCd23,
        XCd24,
        XCd25,
        XCd26,
        XCd27,
        XCd28,
        XCd29,
        XCd30,
        XNum1,
        XNum2,
        XNum3,
        XNum4,
        XNum5)
  select *  from stagePayTyp 
  where Id = @Id
  
  fetch stagePayTypSyncd into @Id

END
close stagePayTypSyncd
deallocate stagePayTypSyncd

/* -------------------------------------------------------------------------------------- 
     Each PayTyp record must exist in stagePayTyp - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open PayTypSyncd
fetch PayTypSyncd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stagePayTyp where Id = @Id)
  begin
    delete PayTyp	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch PayTypSyncd into @Id

END
close PayTypSyncd
deallocate PayTypSyncd

set IDENTITY_INSERT PayTyp off

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPPayTypSync: Unable to sync the PayTyp table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPPrintChk]'
GO
ALTER Procedure [dbo].[ppSPPrintChk] (
            @ParmBchNum int,
			@ParmRecordId int,
			@ParmOprId varchar(30), 
			@ParmRunId varchar(30), 
			@ParmRepRsn varchar(25), 
			@ParmCTpBnkId smallint, 
			@ParmCTpPrtChk tinyint
				)
AS

declare @BchDt int, @BchTime int, @PayAmt decimal(11,2), @PrtCnt tinyint
declare @TranTyp smallint, @eTranPrePrint smallint, @eTranPrt smallint, @eTranReprint smallint
declare @Today int

set @Today = convert(int,datediff(dd, '12/28/1800',getdate()))

begin tran

set @eTranPrePrint = 75
set @eTranPrt = 80
set @eTranReprint = 100
set @BchDt = 0
set @BchTime = 0

select @BchDt = Dt,
       @BchTime = Time
from Bch
where Num = @ParmBchNum

select @PayAmt = PayAmt,
       @PrtCnt = PrtCnt
from Chk
where RecordId = @ParmRecordId

if @ParmBchNum = 0 begin
  if @PayAmt = 0 begin
    set @TranTyp = @eTranPrePrint 
  end
  else begin
    set @TranTyp = @eTranPrt
  end
end
else begin
  if @PrtCnt = 0 begin
    set @TranTyp = @eTranPrt 
  end
  else begin
    set @TranTyp = @eTranReprint 
  end
end

if @PayAmt > 0 begin
  set @PrtCnt = @PrtCnt + 1
end
if @PayAmt = 0 begin
  if @ParmCTpPrtChk = 2 begin
    set @PrtCnt = @PrtCnt + 1
  end
end

update Chk
set TranDt   = @BchDt,
    TranTime = @BchTime,
    Tranid   = @ParmOprId,
    TranTyp  = @TranTyp,
    PrtDt    = @Today,
    PrtId    = @ParmOprId,
    PrtCnt   = @PrtCnt,
    PrtBch   = @ParmBchNum,
    ModVer   = ModVer + 1,
    RepRsn   = @ParmRepRsn
  /* BnkId    = @ParmCTpBnkId */
where RecordId = @ParmRecordId

if @@error <> 0
begin
  --RAISERROR ('Update Chk failure in stored proc spPrintChk; rolling back changes', 16,1)
  rollback transaction
  return
end

/*-----------------------------------------------------------------------------------------------
    Note: the Version 7 implementation of this stored procedure does NOT insert a row into the Hst
    table - the update to the Chk record causes the ChkUpdate trigger to fire - the trigger has
    the responsibility for inserting the new Hst row.
    
    PayPilot Version 6 does not use the ChkUpdate trigger. Therefore, any Version 6 implementation
    of this stored procedure must insert the Hst row.
  -----------------------------------------------------------------------------------------------*/  

commit tran

return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPPrintChks]'
GO
ALTER   Procedure [dbo].[ppSPPrintChks] (
@ParmBchNum int
 )
AS

declare @BchDt int, @BchTime int, @BchRunId varchar(30), @BchOprId varchar(30), @BchRepRsn varchar(25)
declare @TranTyp smallint, @eTranPrePrint smallint, @eTranPrt smallint, @eTranReprint smallint
declare @PrtBch int, @PayAmt decimal(11,2), @PrtCnt tinyint, @ClaDate int
declare @BnkId int, @ChkRecordId int, @eTranVoid smallint, @eAutoVoidCd tinyint

declare @CTpBnkId smallint, @CTpPrtChk tinyint, @CTpId smallint, @CTpXCd25 tinyint

/*-----------------------------------------------------------------------------------------------
    First, clear the tProcess table with all rows that are more then 5 days old (based on RunDt)
  -----------------------------------------------------------------------------------------------*/  

set @ClaDate = convert(int,datediff(dd, '12/28/1800',getdate())) - 4    -- 4 days prior to today's date

set nocount on

delete tProcess
where RunDt < @ClaDate
  and RunDt > 0

set @eTranPrt      = 80
set @eTranVoid     = 190
set @eAutoVoidCd   = 1
set @eTranPrePrint = 75
set @eTranReprint  = 100

select @BchDt     = Dt,
       @BchTime   = Time,
       @BchOprId  = OperId,
       @BchRunId  = RunId,
       @BchRepRsn = RepRsn
from Bch
where Num = @ParmBchNum

declare ChksToProcess cursor for
select RecordId
from tProcess
where RunId = @BchRunId
  and OprId = @BchOprId

open ChksToProcess
fetch ChksToProcess into @ChkRecordId
while @@fetch_status = 0 begin

  begin tran

  select @PrtBch    = c.PrtBch,
         @PayAmt    = c.PayAmt,
         @PrtCnt    = c.PrtCnt,
         @BnkId     = c.BnkId,
         @CTpId     = c.CTpId,
         @CTpXCd25  = p.XCd25,
         @CTpBnkId  = p.BnkId,
         @CTpPrtChk = p.PrtChk
  from Chk c
  inner join PayTyp p on p.Id = c.CTpId
  where c.RecordId = @ChkRecordId

  if @PrtBch = 0 begin
    if @PayAmt = 0 begin
      set @TranTyp = @eTranPrePrint 
    end
    else begin
      set @TranTyp = @eTranPrt
    end /* if @PayAmt = 0 */
  end
  else begin
    set @TranTyp = @eTranReprint 
  end /* if @PrtBch = 0 */

  if @PayAmt > 0 begin
    set @PrtCnt = @PrtCnt + 1
  end
  if @PayAmt = 0 begin
    if @CTpPrtChk = 2 begin
      set @PrtCnt = @PrtCnt + 1
    end
  end /* if @PayAmt > 0 */

  if not (@PayAmt = 0 and @CTpXCd25 = 1)
  begin
/*-----------------------------------------------------------------------------------------------
    6/18/2007: Updated the NOT Void (most common), and Void payment Logic (less common) as follows:
  -----------------------------------------------------------------------------------------------*/  
    update Chk
    set TranDt   = @BchDt,
        TranTime = @BchTime,
        Tranid   = @BchOprId,
        TranTyp  = @TranTyp,
        PrtDt    = @BchDt,
        PrtId    = @BchOprId,
        PrtCnt   = PrtCnt + 1,
        PrtBch   = @ParmBchNum,
        ModVer   = ModVer + 1,
        RepRsn   = @BchRepRsn
    where RecordId = @ChkRecordId

    if @@error <> 0
    begin
      --RAISERROR ('Update Chk failure for Print status in stored proc spPrintChks; rolling back changes', 16,1)
      rollback transaction
      return
    end
  end
  else begin
    update Chk
    set TranDt   = @BchDt,
        TranTime = @BchTime,
        TranId   = @BchOprId,
        TranTyp  = @eTranVoid,
        PrtDt    = @BchDt,
        PrtId    = @BchOprId,
        PrtBch   = @ParmBchNum,
        RepRsn   = @BchRepRsn,
        VoidCd   = @eAutoVoidCd,
        VoidDt   = @BchDt,
        VoidId   = @BchOprId,
        ModVer   = ModVer + 1,
        RsnCd    = 'ZERO'
    where RecordId = @ChkRecordId

    if @@error <> 0
    begin
      --RAISERROR ('Update Chk failure for Void status in stored proc spPrintChks; rolling back changes', 16,1)
      rollback transaction
      return
    end
  end /* if not @CTpXCd25 = 1 and not a zero PayAmt */
  
/*-----------------------------------------------------------------------------------------------
    Note: the Version 7 implementation of this stored procedure does NOT insert a row into the Hst
    table - the update to each Chk record causes the ChkUpdate trigger to fire - the trigger has
    the responsibility for inserting the new Hst row.
    
    PayPilot Version 6 does not use the ChkUpdate trigger. Therefore, the Version 6 implementation
    of this stored procedure inserts the Hst row.
  -----------------------------------------------------------------------------------------------*/  

  commit tran

  fetch ChksToProcess into @ChkRecordId

end

close ChksToProcess
deallocate ChksToProcess

set nocount on

return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPRcnBchUpdate]'
GO
ALTER procedure [dbo].[ppSPRcnBchUpdate]
(
@ParmBchnum int,
@WhereString varchar(1000),
@ParmCTpId varchar(100),
@StatString varchar(1000)
)
as

declare @Id int, @BchDt int, @BchTime int, @OperId varchar(30), @BnkId int, @ChkRecordId int, @TotUpdated smallint
declare @TranTyp smallint, @eStopCd smallint, @eStopReqCd smallint, @eTranBldIss smallint
declare @eAutoVoidCd tinyint, @eManVoidCd tinyint, @eStaleDtVoidCd tinyint, @eWriteOffCd tinyint, @eQutoVoidCd tinyint
declare @Cmd nvarchar(2000), @SubQueryCmd nvarchar(2000), @UpdateClause nvarchar(2000)
declare @StoreCmd varchar(4000)

set @eStopCd = 3
set @eStopReqCd = 7
set @eTranBldIss = 220
set @eAutoVoidCd = 1
set @eManVoidCd  = 2
set @eWriteOffCd = 4
set @eStaleDtVoidCd = 9
set @TotUpdated = 0

select @BchDt = Dt,
       @BchTime = Time,
       @OperId = OperId
from Bch
where Num = @ParmBchNum

set @SubQueryCmd = 'select c.RecordId from Chk c' 
set @SubQueryCmd = @SubQueryCmd + ' inner join Bnk b on b.Id = c.BnkId inner join BkH h on h.Id = b.BkHId inner join BEH e on e.Id = h.BEHId'
set @SubQueryCmd = @SubQueryCmd + @WhereString + @ParmCTpId + @StatString

set @Cmd = 
'while exists ('
 + @SubQueryCmd
 + ') begin set rowcount 100'
set @UpdateClause = ' update Chk set TranDt = ' + convert(varchar(5),@BchDt)
 + ', TranTime = ' + convert(varchar(12),@BchTime)
 + ', Tranid   = ' + '"' + @OperId + '"'
 + ', TranTyp  = ' + convert(varchar(5),@eTranBldIss)
 + ', ModVer   = ModVer + 1'
 + ', ChgDt    = ' + convert(varchar(12),@BchDt)
 + ', ChgTime  = ' + convert(varchar(12),@BchTime)
 + ', ChgId    = ' + '"' + @OperId + '"'
 + ', RcnBch   = ' + convert(varchar(12),@ParmBchnum)
 + ' where RecordId in (' + @SubQueryCmd + ')'
 + '  set rowcount 0'
 + ' end'

set @Cmd = @Cmd + @UpdateClause
set @StoreCmd = @Cmd

/*
insert into RcnBchUpdate
values (@ParmBchnum, @StoreCmd)
*/

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

begin tran

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'spArchivePayments: Archive process failed (1)'
        ROLLBACK TRAN
        UPDATE Bch
        SET XCd1  = 'Failed Rcn Update', 
            XNum1 = @@error
        WHERE Num = @ParmBchnum
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    ELSE BEGIN
        UPDATE Bch
        SET XCd1  = 'Rcn Update Succeeded', 
            XNum1 = @@error
        WHERE Num = @ParmBchnum
    END

commit tran
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPRefSync]'
GO
ALTER procedure [dbo].[ppSPRefSync]
(
@LogHdrId int
)
as

declare @Cd varchar(50)

declare stageRefSynCd cursor for
select Cd FROM stageRef

declare RefSynCd cursor for
select Cd FROM Ref

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageRefSynCd
fetch stageRefSynCd into @Cd
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageRef record and make sure that Ref records are CdentiRef
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Ref where Cd = @Cd)
  begin
    delete Ref	-- delete the existing record and insert it again from stageRef
    where Cd = @Cd
  end

  insert into Ref
  select * from stageRef 
  where Cd = @Cd
  
  fetch stageRefSynCd into @Cd

end
close stageRefSynCd
deallocate stageRefSynCd

/* -------------------------------------------------------------------------------------- 
     Each Ref record must exist in stageRef - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open RefSynCd
fetch RefSynCd into @Cd
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageRef where Cd = @Cd)
  begin
    delete Ref	-- delete the operational record with no match to the stage table
    where Cd = @Cd
  end

  fetch RefSynCd into @Cd

END
close RefSynCd
deallocate RefSynCd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransRefion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPRefSync: Unable to sync the Ref table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the Refling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPReportRequestCancel]'
GO
ALTER PROCEDURE [dbo].[ppSPReportRequestCancel]
(
	@RunId                              varchar(18),
	@CancelDt                            int,
	@CancelTime                          int,
	@CancelOprId                          varchar(30)
)
AS
BEGIN
	BEGIN TRAN
	update dbo.ReportRequest
	   set CancelDt   = @CancelDt,
		   CancelTime = @CancelTime,
           CancelOprId = @CancelOprId,
           Status = 'Cancelled'
	 where RunId = @RunId

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPCancelReportRequest: Cannot update Cancel date and time'
        ROLLBACK TRAN
        RETURN(1)
    END

    COMMIT TRAN
END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPReportRequestEnd]'
GO

ALTER PROCEDURE [dbo].[ppSPReportRequestEnd]
(
	@RunId                              varchar(18),
	@EndDt                            int,
	@EndTime                          int,
	@Status							  varchar(20)
)
AS
BEGIN
	BEGIN TRAN
	update dbo.ReportRequest
	   set EndDt   = @EndDt,
		   EndTime = @EndTime,
           Status  = @Status
      where RunId = @RunId

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPEndReportRequest: Cannot update End date and time'
        ROLLBACK TRAN
        RETURN(1)
    END

    COMMIT TRAN
END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPReportRequestStart]'
GO
ALTER PROCEDURE [dbo].[ppSPReportRequestStart]
(
	@RunId                              varchar(18),
	@StartDt                            int,
	@StartTime                          int
)
AS
BEGIN
	BEGIN TRAN
	update dbo.ReportRequest
	   set StartDt   = @StartDt,
		   StartTime = @StartTime,
           Status = 'Processing'
      where RunId = @RunId

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPStartReportRequest: Cannot update Start date and time'
        ROLLBACK TRAN
        RETURN(1)
    END

    COMMIT TRAN
END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPRngMaint]'
GO
ALTER procedure [dbo].[ppSPRngMaint]
as

declare @Id int

declare RngUpdtd cursor for
select Id FROM Rng

declare stageRngUpdtd cursor for
select Id FROM stageRng

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open RngUpdtd
fetch RngUpdtd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each Rng record and make sure that stageRng records are Identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from stageRng where Id = @Id)
  begin
    delete stageRng	-- delete the existing record and insert it again from Rng
    where Id = @Id
  end

  insert into stageRng
  select * from Rng
  where Id = @Id

  fetch RngUpdtd into @Id

END
close RngUpdtd
deallocate RngUpdtd

/* -------------------------------------------------------------------------------------- 
     Each stageRng record must exist in Rng - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open stageRngUpdtd
fetch stageRngUpdtd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from Rng where Id = @Id)
  begin
    delete stageRng	-- delete the stage record with no match to the operational table
    where Id = @Id
  end

  fetch stageRngUpdtd into @Id

END
close stageRngUpdtd
deallocate stageRngUpdtd

/* --------------------------------------------------------------------------------- 
    Rngmit, or Rollback the Transaction, based on the success or failure of the
    Rngcessing to this point.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPRngMaint: Cannot update the stageRng table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling Rngcess to indicate failure */
END

COMMIT TRAN
set nocount off

Exec ppSPLastMaintDate


 --identifies the last time that Admin maintenance was applied
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPRngSync]'
GO
ALTER Procedure [dbo].[ppSPRngSync]
(
@LogHdrId int
)
as

declare @id int

declare stageRngSyncd cursor for
select Id FROM stageRng

declare RngSyncd cursor for
select Id FROM Rng

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageRngSyncd
fetch stageRngSyncd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageRng record and make sure that Rng records are identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Rng where Id = @Id)
  begin
    delete Rng	-- delete the existing record and insert it again from stageRng
    where Id = @Id
  end

  insert into Rng
  select *  from stageRng 
  where Id = @Id
  
  fetch stageRngSyncd into @Id

END
close stageRngSyncd
deallocate stageRngSyncd

/* -------------------------------------------------------------------------------------- 
     Each Rng record must exist in stageRng - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open RngSyncd
fetch RngSyncd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageRng where Id = @Id)
  begin
    delete Rng	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch RngSyncd into @Id

END
close RngSyncd
deallocate RngSyncd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    Rngcessing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPRngSync: Unable to sync the Rng table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling Rngcess to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPRPVSync]'
GO
ALTER procedure [dbo].[ppSPRPVSync]
(
@LogHdrId int
)
as

declare @Passwd varchar(30)

declare stageRPVSynCd cursor for
select Passwd FROM stageRPV

declare RPVSynCd cursor for
select Passwd FROM RPV

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageRPVSynCd
fetch stageRPVSynCd into @Passwd
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageRPV record and make sure that RPV records arePasswdentiRPV
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from RPV where Passwd = @Passwd)
  begin
    delete RPV	-- delete the existing record and insert it again from stageRPV
    where Passwd = @Passwd
  end

  insert into RPV
  select * from stageRPV 
  where Passwd = @Passwd
  
  fetch stageRPVSynCd into @Passwd

end
close stageRPVSynCd
deallocate stageRPVSynCd

/* -------------------------------------------------------------------------------------- 
     Each RPV record must exist in stageRPV - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open RPVSynCd
fetch RPVSynCd into @Passwd
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageRPV where Passwd = @Passwd)
  begin
    delete RPV	-- delete the operational record with no match to the stage table
    where Passwd = @Passwd
  end

  fetch RPVSynCd into @Passwd

END
close RPVSynCd
deallocate RPVSynCd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransRPVion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPRPVSync: Unable to sync the RPV table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the RPVling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPRsnSync]'
GO
ALTER procedure [dbo].[ppSPRsnSync]
(
@LogHdrId int
)
as

declare @Cd  varchar(15), @Typ  varchar(20)

declare stageRsnSynCd cursor for
select Cd, Typ FROM stageRsn

declare RsnSynCd cursor for
select Cd, Typ FROM Rsn

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageRsnSynCd
fetch stageRsnSynCd into @Cd, @Typ
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageRsn record and make sure that Rsn records arePasswdentiRsn
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Rsn where Cd = @Cd and Typ = @Typ)
  begin
    delete Rsn	-- delete the existing record and insert it again from stageRsn
    where Cd = @Cd and Typ = @Typ
  end

  insert into Rsn
  select * from stageRsn 
  where Cd = @Cd and Typ = @Typ
  
  fetch stageRsnSynCd into @Cd, @Typ

end
close stageRsnSynCd
deallocate stageRsnSynCd

/* -------------------------------------------------------------------------------------- 
     Each Rsn record must exist in stageRsn - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open RsnSynCd
fetch RsnSynCd into @Cd, @Typ
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageRsn where Cd = @Cd and Typ = @Typ)
  begin
    delete Rsn	-- delete the operational record with no match to the stage table
    where Cd = @Cd and Typ = @Typ
  end

  fetch RsnSynCd into @Cd, @Typ

END
close RsnSynCd
deallocate RsnSynCd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransRsnion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPRsnSync: Unable to sync the Rsn table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the Rsnling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPSDASync]'
GO
ALTER procedure [dbo].[ppSPSDASync]
(
@LogHdrId int
)
as

declare @Id int

declare stageSDASynCd cursor for
select Id FROM stageSDA

declare SDASynCd cursor for
select Id FROM SDA

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageSDASynCd
fetch stageSDASynCd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageSDA record and make sure that SDA records arePasswdentiSDA
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from SDA where Id = @Id)
  begin
    delete SDA	-- delete the existing record and insert it again from stageSDA
    where Id = @Id
  end

  insert into SDA
  select * from stageSDA 
  where Id = @Id
  
  fetch stageSDASynCd into @Id

end
close stageSDASynCd
deallocate stageSDASynCd

/* -------------------------------------------------------------------------------------- 
     Each SDA record must exist in stageSDA - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open SDASynCd
fetch SDASynCd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageSDA where Id = @Id)
  begin
    delete SDA	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch SDASynCd into @Id

END
close SDASynCd
deallocate SDASynCd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransSDAion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPSDASync: Unable to sync the SDA table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the SDAling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPSDISync]'
GO
ALTER procedure [dbo].[ppSPSDISync]
(
@LogHdrId int
)
as

declare @Id int

declare stageSDISynCd cursor for
select Id FROM stageSDI

declare SDISynCd cursor for
select Id FROM SDI

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageSDISynCd
fetch stageSDISynCd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageSDI record and make sure that SDI records arePasswdentiSDI
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from SDI where Id = @Id)
  begin
    delete SDI	-- delete the existing record and insert it again from stageSDI
    where Id = @Id
  end

  insert into SDI
  select * from stageSDI 
  where Id = @Id
  
  fetch stageSDISynCd into @Id

end
close stageSDISynCd
deallocate stageSDISynCd

/* -------------------------------------------------------------------------------------- 
     Each SDI record must exist in stageSDI - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open SDISynCd
fetch SDISynCd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageSDI where Id = @Id)
  begin
    delete SDI	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch SDISynCd into @Id

END
close SDISynCd
deallocate SDISynCd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransSDIion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPSDISync: Unable to sync the SDI table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the SDIling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPSDNSync]'
GO
ALTER procedure [dbo].[ppSPSDNSync]
(
@LogHdrId int
)
as

declare @Id int

declare stageSDNSynCd cursor for
select Id FROM stageSDN

declare SDNSynCd cursor for
select Id FROM SDN

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageSDNSynCd
fetch stageSDNSynCd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageSDN record and make sure that SDN records arePasswdentiSDN
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from SDN where Id = @Id)
  begin
    delete SDN	-- delete the existing record and insert it again from stageSDN
    where Id = @Id
  end

  insert into SDN
  select * from stageSDN 
  where Id = @Id
  
  fetch stageSDNSynCd into @Id

end
close stageSDNSynCd
deallocate stageSDNSynCd

/* -------------------------------------------------------------------------------------- 
     Each SDN record must exist in stageSDN - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open SDNSynCd
fetch SDNSynCd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageSDN where Id = @Id)
  begin
    delete SDN	-- delete the operational record with no match to the stage table
    where Id = @Id
  end

  fetch SDNSynCd into @Id

END
close SDNSynCd
deallocate SDNSynCd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransSDNion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPSDNSync: Unable to sync the SDN table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the SDNling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPSeqTProcess]'
GO
ALTER Procedure [dbo].[ppSPSeqTProcess] (
@RunId varchar(18)
 )
AS

/*-----------------------------------------------------------------------------------------------
    The ppSPSeqTProcess stored procedure prepares the rowsin the TProcess table for printing
    in the appropriate sequence, in support of the PayPilot Print Service Load Balancing feature.
  -----------------------------------------------------------------------------------------------*/  

declare @SeqNum int, @ChkRecordId int

set @SeqNum = 0

set nocount on

begin tran

declare ChksToProcess cursor for
select RecordId
  from tProcess
 where RunId = @RunId
 order by Priority desc, SortBy

open ChksToProcess
fetch ChksToProcess into @ChkRecordId
while @@fetch_status = 0 begin

  set @SeqNum = @SeqNum + 1

  update TProcess
  set SortSeqNum = @SeqNum
  where RecordId = @ChkRecordId
    and RunId    = @RunId

  if @@error <> 0
  begin
    --RAISERROR ('Update TProcess failure in stored proc ppSPSeqTProcess; rolling back changes', 16,1)
    rollback transaction
    return
  end

  fetch ChksToProcess into @ChkRecordId

end

commit tran

close ChksToProcess
deallocate ChksToProcess

return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPStaSync]'
GO
ALTER procedure [dbo].[ppSPStaSync]
(
@LogHdrId int
)
as

declare @Cd varchar(2)

declare stageStaSynCd cursor for
select Cd FROM stageSta

declare StaSynCd cursor for
select Cd FROM Sta

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open stageStaSynCd
fetch stageStaSynCd into @Cd
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each stageSta record and make sure that Sta records arePasswdentiSta
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Sta where Cd = @Cd)
  begin
    delete Sta	-- delete the existing record and insert it again from stageSta
    where Cd = @Cd
  end

  insert into Sta
  select * from stageSta 
  where Cd = @Cd
  
  fetch stageStaSynCd into @Cd

end
close stageStaSynCd
deallocate stageStaSynCd

/* -------------------------------------------------------------------------------------- 
     Each Sta record must exist in stageSta - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open StaSynCd
fetch StaSynCd into @Cd
while @@fetch_status = 0
begin

  if NOT exists (select 1 from stageSta where Cd = @Cd)
  begin
    delete Sta	-- delete the operational record with no match to the stage table
    where Cd = @Cd
  end

  fetch StaSynCd into @Cd

END
close StaSynCd
deallocate StaSynCd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransStaion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPStaSync: Unable to sync the Sta table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the Staling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPStsSync]'
GO
ALTER procedure [dbo].[ppSPStsSync]
(
@LogHdrId int
)
as

declare @Typ varchar(4), @Cd varchar(5)

declare StageStsSynCd cursor for
select Typ, Cd FROM StageSts

declare StsSynCd cursor for
select Typ, Cd FROM Sts

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open StageStsSynCd
fetch StageStsSynCd into @Typ, @Cd
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each StageSts record and make sure that Sts records arePasswdentiSts
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Sts where Typ = @Typ and Cd = @Cd)
  begin
    delete Sts	-- delete the existing record and insert it again from StageSts
    where Typ = @Typ and Cd = @Cd
  end

  insert into Sts
  select * from StageSts 
  where Typ = @Typ and Cd = @Cd
  
  fetch StageStsSynCd into @Typ, @Cd

end
close StageStsSynCd
deallocate StageStsSynCd

/* -------------------------------------------------------------------------------------- 
     Each Sts record must exist in StageSts - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open StsSynCd
fetch StsSynCd into @Typ, @Cd
while @@fetch_status = 0
begin

  if NOT exists (select 1 from StageSts where Typ = @Typ and Cd = @Cd)
  begin
    delete Sts	-- delete the operational record with no match to the Stage table
    where Typ = @Typ and Cd = @Cd
  end

  fetch StsSynCd into @Typ, @Cd

END
close StsSynCd
deallocate StsSynCd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransStsion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPStsSync: Unable to sync the Sts table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero Ststus to the Stsling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPTrmSync]'
GO
ALTER procedure [dbo].[ppSPTrmSync]
(
@LogHdrId int
)
as

declare @Id varchar(31)

declare StageTrmSynCd cursor for
select Id FROM StageTrm

declare TrmSynCd cursor for
select Id FROM Trm

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open StageTrmSynCd
fetch StageTrmSynCd into @Id
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each StageTrm record and make sure that Trm records arePasswdentiTrm
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from Trm where Id = @Id)
  begin
    delete Trm	-- delete the existing record and insert it again from StageTrm
    where Id = @Id
  end

  insert into Trm
  select * from StageTrm 
  where Id = @Id
  
  fetch StageTrmSynCd into @Id

end
close StageTrmSynCd
deallocate StageTrmSynCd

/* -------------------------------------------------------------------------------------- 
     Each Trm record must exist in StageTrm - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open TrmSynCd
fetch TrmSynCd into @Id
while @@fetch_status = 0
begin

  if NOT exists (select 1 from StageTrm where Id = @Id)
  begin
    delete Trm	-- delete the operational record with no match to the Trmge table
    where Id = @Id
  end

  fetch TrmSynCd into @Id

END
close TrmSynCd
deallocate TrmSynCd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the TransTrmion, based on the success or failure of the
    processing.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPTrmSync: Unable to sync the Trm table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero Trmtus to the Trmling process to indicate failure */
END

COMMIT TRAN
set nocount off
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPTrnMaint]'
GO
ALTER procedure [dbo].[ppSPTrnMaint]
as

declare @Cd varchar(31)

declare TrnUpdtd cursor for
select Cd FROM Trn

declare stageTrnUpdtd cursor for
select Cd FROM stageTrn

set nocount on
set transaction isolation level serializable /* the highest level of isolation */

BEGIN TRAN

open TrnUpdtd
fetch TrnUpdtd into @Cd
while @@fetch_status = 0
begin
/* -------------------------------------------------------------------------------------- 
     Read through each Trn record and make sure that stageTrn records are Identical
   -------------------------------------------------------------------------------------- */       
  if exists (select 1 from stageTrn where Cd = @Cd)
  begin
    delete stageTrn	-- delete the existing record and insert it again from Trn
    where Cd = @Cd
  end

  insert into stageTrn
  select * from Trn
  where Cd = @Cd

  fetch TrnUpdtd into @Cd

END
close TrnUpdtd
deallocate TrnUpdtd

/* -------------------------------------------------------------------------------------- 
     Each stageTrn record must exist in Trn - otherwise, delete it.
   -------------------------------------------------------------------------------------- */       
open stageTrnUpdtd
fetch stageTrnUpdtd into @Cd
while @@fetch_status = 0
begin

  if NOT exists (select 1 from Trn where Cd = @Cd)
  begin
    delete stageTrn	-- delete the stage record with no match to the operational table
    where Cd = @Cd
  end

  fetch stageTrnUpdtd into @Cd

END
close stageTrnUpdtd
deallocate stageTrnUpdtd

/* --------------------------------------------------------------------------------- 
    Commit, or Rollback the Transaction, based on the success or failure of the
    processing to this point.
   --------------------------------------------------------------------------------- */       
IF (@@error!=0)
BEGIN
  --RAISERROR  20000 'ppSPTrnMaint: Cannot update the stageTrn table'
  ROLLBACK TRAN

  RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
END

COMMIT TRAN
set nocount off

Exec ppSPLastMaintDate




 --identifies the last time that Admin maintenance was applied
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[BCPImport]'
GO
ALTER  procedure [dbo].[BCPImport]
(
@TableName varchar(100), 
@Directory varchar(300)
)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible to import data, using BCP, into the PROD D/B
   ---------------------------------------------------------------------------------
*/       
AS
BEGIN
/* 
   --------------------------------------------------------------------------------- 
    Declare, and initialize, all variables that will be used by this procedure.
   ---------------------------------------------------------------------------------
*/       
 
    declare @cmd varchar(1000), @truncate_cmd nvarchar(1000)
    declare @FileName varchar(500), @FunctionType varchar(20)
    declare @CommentText varchar(255), @Typ varchar(2), @DateTime datetime, @Status varchar(30)
    declare @SuccessStatus varchar(30), @FailureStatus varchar(30), @rc int
 
    set @CommentText     = 'ConEd BCP import to the PROD database from *.txt files'
    set @FunctionType    = 'BCP_TO_PROD'
    set @DateTime        = GetDate()
    set @Status          = ''
    set @SuccessStatus   = 'Process succeeded'
    set @FailureStatus   = 'Process failed'

    set nocount on
    
/* 
   --------------------------------------------------------------------------------- 
    Set the TableName to the table that we want to BCP from.

    Truncate the target table which will allow this procedure to be re-run.

    Format the BCP command that will be executed, storing the command in 
    the @cmd variable.

    Execute the BCP command through the xp_cmdshell extended stored procedure.
   ---------------------------------------------------------------------------------
*/       
 
    set @truncate_cmd = 'truncate table ' + db_name() + '.dbo.' + @TableName
    print @truncate_cmd
    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ConEdProdBCPImport: Import process failed (1)'
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
    
    set @FileName = @Directory + '\' + @TableName
    set @cmd = 'bcp ' + db_name() + '.dbo.' + @TableName + ' in ' + @FileName + '.txt -Utest -Ptest -S' + @@servername + ' -n -e ' + @FileName + '.err -o ' + @FileName + '.log'
    print @cmd

    exec @rc = master..xp_cmdshell @cmd
    if @rc = 0 
    begin
      print 'Imported to table: ' + @TableName + ' successfully...'
    end
    else begin
      print 'Failed to import to table: ' + @TableName + ' review the *.err file for this table'
    end

    set nocount off

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[InsuranceHdr_UPD]'
GO
/*
* File Name: 
* Description: Update Procedure for the table "dbo.InsuranceHdr"
*/

ALTER PROCEDURE [dbo].[InsuranceHdr_UPD]
(
	@Id                       numeric(18,0),
	@Note                     varchar(100),
	@ChgId                    varchar(30),
	@ChgMethod                varchar(50)
)
AS
BEGIN

    Declare @OrigNote varchar(100)
/*
* store the original table values before any updates are applied
*/
    
    Select 
        @OrigNote = Note
    From 
        dbo.InsuranceHdr 
    Where 
        Id = @Id
        
    If @Note is NULL
    begin
      set @Note = @OrigNote
    end
        
    BEGIN TRAN

    UPDATE dbo.InsuranceHdr
       SET 
		Note                      = @Note,
		ChgId                     = @ChgId,
		ChgMethod                 = @ChgMethod,
		ChgDt                     = GetDate()
     WHERE 
		Id = @Id

    IF (@@error!=0)
    BEGIN
        --RAISERROR  20001 'InsuranceHdr_UPD: Cannot update InsuranceHdr_UPD'
        ROLLBACK TRAN
        RETURN(1)
    END

    COMMIT TRAN
END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPArchivePayments]'
GO
ALTER PROCEDURE [dbo].[ppSPArchivePayments]
(
@archivebchnum int,
@whereclause varchar(500)
)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure is responsible for archiving payments. The following tables
    are included in the archiving process: Chk, Hst, ExA, TxT and Vch. The calling
    application has the responsibility of passing a "where clause" parameter to this
    stored procedure. Records are selected for archive based on the selection criteria
    that is passed in the form of the "where clause". Also, the calling application has
    the responsibility of creating the batch history (Bch) record and it must pass the
    Bch:Num to this procedure as the first parameter.
   ---------------------------------------------------------------------------------
*/
AS
BEGIN

  declare @Cmd nvarchar(4000)
  
  set nocount on

  BEGIN TRAN
/* 
   --------------------------------------------------------------------------------- 
    First, insert each Vch record into the ArV table.
   ---------------------------------------------------------------------------------
*/       
    set @Cmd = 'INSERT INTO ArV SELECT * FROM vVchForArchive' + ' ' + @whereclause

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (1)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
/* 
   --------------------------------------------------------------------------------- 
    Next, nsert each TxT record into the ArT table.
   ---------------------------------------------------------------------------------
*/       
    set @Cmd = 'INSERT INTO ArT SELECT * FROM vTxTForArchive' + ' ' + @whereclause

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (2)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
/* 
   --------------------------------------------------------------------------------- 
    Insert each ExA record into the ArE table.
   ---------------------------------------------------------------------------------
*/       
    set @Cmd = 'INSERT INTO ArE SELECT * FROM vExAForArchive' + ' ' + @whereclause

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (3)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END
/* 
   --------------------------------------------------------------------------------- 
    Insert each Hst record into the ArH table.
   ---------------------------------------------------------------------------------
*/       
    set @Cmd = 'INSERT INTO ArH (
	CTpId,Id,OrigId,IdPre,ModVer,ModCd,CmpId,PayToNam1,PayToNam2,
	PayToNam3,IssDt,PayAmt,OrigPayAmt,ResrvAmt,BnkId,BnkNum,LosDt,Dt1,Dt2,
	Dt3,Dt4,Dt5,Time1,Time2,TranCd,TaxId,TaxTyp,Tax1099,RptAmt1099,
	SpltPay1099,VndTyp,VndId,AgentTyp,AgentId,MailToNam,MailToAdr1,
	MailToAdr2,MailToAdr3,MailToAdr4,MailToAdr5,City,State,CntyCd,
	CountryId,ZipCd,BillState,BillDt,PhNum1,PhNum2,FaxNum,FaxNumTyp,
	FaxToNam,EmailAdr,MrgId,MrgId2,PayCd,PayToCd,ReqId,ExamId,ExamNam,
	AdjId,CurId,Office,DeptCd,MailStop,ReissCd,AtchCd,ReqNum,ImpBch,
	ImpBnkBch,PrtBch,RcnBch,SavRcnBch,ExpBch,PdBch,VoidExpCd,PrevVoidExpCd,
	WriteOffExpCd,SrchLtrCd,PrtCnt,RcnCd,VoidCd,VoidId,VoidDt,UnVoidCd,
	UnVoidId,UnVoidDt,SigCd,SigCd1,SigCd2,DrftCd,DscCd,RestCd,XCd1,XCd2,
	XCd3,XCd4,XCd5,XCd6,XCd7,XCd8,XCd9,XCd10,PayRate,XRate1,XRate2,XRate3,
	XAmt1,XAmt2,XAmt3,XAmt4,XAmt5,XAmt6,XAmt7,XAmt8,XAmt9,XAmt10,SalaryAmt,
	MaritalStat,FedExempt,StateExempt,Day30Cd,PstCd,RsnCd,PdCd,PdDt,
	ApprovCd,ApprovDt,ApprovId,ApprovCd2,ApprovDt2,ApprovId2,ApprovCd3,
	ApprovDt3,ApprovId3,ApprovCd4,ApprovDt4,ApprovId4,ApprovCd5,ApprovDt5,
	ApprovId5,ApprovCd6,ApprovDt6,ApprovId6,ApprovCd7,ApprovDt7,ApprovId7,
	ApprovCd8,ApprovDt8,ApprovId8,ApprovCd9,ApprovDt9,ApprovId9,AddDt,
	AddTime,AddId,ChgDt,ChgTime,ChgId,SrceCd,FrmCd,RefNum,NamTyp,LstNam,
	FstNam,MidInit,Salutation,AcctNum,ExpAcct,DebitAcct,BnkAcct,BnkRout,
	AcctNam,EftTypCd,BnkAcct2,BnkRout2,AcctNam2,EftTypCd2,BnkAcct3,BnkRout3,
	AcctNam3,EftTypCd3,AllocPct1,AllocPct2,AllocPct3,OptCd,EftTranCd,
	AdviceTyp,RepRsn,EmployerTyp,EmployerId,EmployerNam,EmployerAdr1,
	EmployerAdr2,EmployerAdr3,ProviderTyp,ProviderId,ProviderNam,CarrierTyp,
	CarrierId,PolId,InsNam,InsAdr1,InsAdr2,InsAdr3,ClaimNum,ClmntNum,
	ClmntNam,ClmntAdr1,ClmntAdr2,ClmntAdr3,LosCause,DiagCd1,DiagCd2,DiagCd3,
	DiagCd4,ForRsn1,ForRsn2,ForRsn3,CommentTxt,XNum1,XNum2,XNum3,XNum4,
	VchCnt,TransferOutBch,TransferInBch,PrtDt,PrtId,TranDt,TranTime,TranTyp,
	TranId,BTpId,ExamTyp,Priority,DeliveryDt,CardNum,CardTyp,ExportStat,
	PrevExportStat,NoBulk,Typ1099,TrmId,AltId,AltTyp,AthOver,AthId,AthCd,
	MicrofilmID,BlockSeqNum,PrtBchOFAC,ExpBch2,ExpBch3,PrenoteCd,SavPdBch,
	ACHTraceNum,EscheatExportStat,PrevEscheatExportStat,RcdLock,Tax1099Cd,
	ClmntTaxId,WorkstationId,UploadBchNum,ManSigCd,ChkRecordId,InsAdr4
                )
    SELECT * FROM vHstForArchive' + ' ' + @whereclause

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (4)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

    set @Cmd = 'UPDATE ArH set ArcBch = ' + convert(varchar(30),@archivebchnum) + ' ' + @whereclause
    Exec sp_executesql @cmd  
  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (5)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

    set @Cmd = 'INSERT INTO ArC (
	CTpId,Id,OrigId,IdPre,ModVer,ModCd,CmpId,PayToNam1,PayToNam2,PayToNam3,IssDt,PayAmt,
	OrigPayAmt,ResrvAmt,BnkId,BnkNum,LosDt,Dt1,Dt2,Dt3,Dt4,Dt5,Time1,Time2,TranCd,TaxId,TaxTyp,
	Tax1099,RptAmt1099,SpltPay1099,VndTyp,VndId,AgentTyp,AgentId,MailToNam,MailToAdr1,
	MailToAdr2,MailToAdr3,MailToAdr4,MailToAdr5,City,State,CntyCd,CountryId,ZipCd,BillState,
	BillDt,PhNum1,PhNum2,FaxNum,FaxNumTyp,FaxToNam,EmailAdr,MrgId,MrgId2,PayCd,PayToCd,ReqId,
	ExamId,ExamNam,AdjId,CurId,Office,DeptCd,MailStop,ReissCd,AtchCd,ReqNum,ImpBch,ImpBnkBch,
	PrtBch,RcnBch,SavRcnBch,ExpBch,PdBch,VoidExpCd,PrevVoidExpCd,WriteOffExpCd,SrchLtrCd,PrtCnt,
	RcnCd,VoidCd,VoidId,VoidDt,UnVoidCd,UnVoidId,UnVoidDt,SigCd,SigCd1,SigCd2,DrftCd,DscCd,
	RestCd,XCd1,XCd2,XCd3,XCd4,XCd5,XCd6,XCd7,XCd8,XCd9,XCd10,PayRate,XRate1,XRate2,XRate3,
	XAmt1,XAmt2,XAmt3,XAmt4,XAmt5,XAmt6,XAmt7,XAmt8,XAmt9,XAmt10,SalaryAmt,MaritalStat,
	FedExempt,StateExempt,Day30Cd,PstCd,RsnCd,PdCd,PdDt,ApprovCd,ApprovDt,ApprovId,ApprovCd2,
	ApprovDt2,ApprovId2,ApprovCd3,ApprovDt3,ApprovId3,ApprovCd4,ApprovDt4,ApprovId4,ApprovCd5,
	ApprovDt5,ApprovId5,ApprovCd6,ApprovDt6,ApprovId6,ApprovCd7,ApprovDt7,ApprovId7,ApprovCd8,
	ApprovDt8,ApprovId8,ApprovCd9,ApprovDt9,ApprovId9,AddDt,AddTime,AddId,ChgDt,ChgTime,ChgId,
	SrceCd,FrmCd,RefNum,NamTyp,LstNam,FstNam,MidInit,Salutation,AcctNum,ExpAcct,DebitAcct,
	BnkAcct,BnkRout,AcctNam,EftTypCd,BnkAcct2,BnkRout2,AcctNam2,EftTypCd2,BnkAcct3,BnkRout3,
	AcctNam3,EftTypCd3,AllocPct1,AllocPct2,AllocPct3,OptCd,EftTranCd,AdviceTyp,RepRsn,
	EmployerTyp,EmployerId,EmployerNam,EmployerAdr1,EmployerAdr2,EmployerAdr3,ProviderTyp,
	ProviderId,ProviderNam,CarrierTyp,CarrierId,PolId,InsNam,InsAdr1,InsAdr2,InsAdr3,ClaimNum,
	ClmntNum,ClmntNam,ClmntAdr1,ClmntAdr2,ClmntAdr3,LosCause,DiagCd1,DiagCd2,DiagCd3,DiagCd4,
	ForRsn1,ForRsn2,ForRsn3,CommentTxt,XNum1,XNum2,XNum3,XNum4,TransferOutBch,TransferInBch,VchCnt,
	PrtDt,PrtId,TranDt,TranTime,TranTyp,TranId,BTpId,ExamTyp,Priority,DeliveryDt,
	CardNum,CardTyp,ExportStat,PrevExportStat,NoBulk,Typ1099,TrmId,AltId,AltTyp,AthOver,AthId,
	AthCd,MicrofilmID,BlockSeqNum,PrtBchOFAC,ExpBch2,ExpBch3,PrenoteCd,SavPdBch,ACHTraceNum,
	EscheatExportStat,PrevEscheatExportStat,RcdLock,Tax1099Cd,ClmntTaxId,WorkstationId,
	UploadBchNum,ManSigCd,InsAdr4
                )
    SELECT * FROM vChkForArchive' + ' ' + @whereclause

    Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (6)'
        ROLLBACK TRAN
   RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

    set @Cmd = 'UPDATE ArC set ArcBch = ' + convert(varchar(30),@archivebchnum) + ' ' + @whereclause
    Exec sp_executesql @cmd  
  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (7)'
        ROLLBACK TRAN
        RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
    END

/* 
   --------------------------------------------------------------------------------- 
    delete archived payments (Chk), history (Hst) and related child records.
   ---------------------------------------------------------------------------------
*/       
  set @Cmd = 'DELETE Vch' + ' ' + @whereclause
  Exec sp_executesql @cmd  
  
  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (8)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  set @Cmd = 'DELETE Txt' + ' ' + @whereclause
  Exec sp_executesql @cmd  
  
  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (9)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  set @Cmd = 'DELETE ExA' + ' ' + @whereclause
  Exec sp_executesql @cmd  
  
  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (10)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END
  set @Cmd = 'DELETE Hst' + ' ' + @whereclause
  Exec sp_executesql @cmd  
  
  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (11)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END

  set @Cmd = 'DELETE Chk' + ' ' + @whereclause
  Exec sp_executesql @cmd  
  
  IF (@@error!=0)
  BEGIN
      --RAISERROR  20000 'ppSPArchivePayments: Archive process failed (12)'
      ROLLBACK TRAN
      RETURN(1) /* Return a non-zero status to the calling process to indicate failure */
  END
  
  COMMIT TRAN

  set nocount off
    
  RETURN /* Return with a zero status to indicate a successful process */

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [dbo].[ppSPDupCheck]'
GO
ALTER  PROCEDURE [dbo].[ppSPDupCheck]
(
@ParmRunId varchar(18),
@ParmTable varchar(50)
)
/* 
   --------------------------------------------------------------------------------- 
    This stored procedure uses the rows that have been loaded into the stageChkDIV
    table to determine if the specific row already exists in the Chk table
   ---------------------------------------------------------------------------------
*/
as
begin 
    
    declare @Cmd nvarchar(1000)
    
    set @Cmd = 'update s ' +
			   'set s.DeleteCd = 1 ' +
			   'from ' + @ParmTable + ' s ' +
			   'inner join Chk c on c.CTpId = s.CTpId and c.Id = s.Id ' +
			   'where s.RunId = "' + @ParmRunId + '"'
					    
    set nocount off    
			
	Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'stored procedure failed, when checking duplicates (1)'
        RETURN
    END
    
    set @cmd = 'select c.RecordId, c.Id, c.CTpId, c.AddDt, c.AddTime, c.AddId, c.SrceCd, s.PayAmt, s.RecordId StageChkRecordId ' +
			   'from ' + @ParmTable + ' s ' +
			   'inner join Chk c on c.CTpId = s.CTpId and c.Id = s.Id ' +
			   'where s.RunId = "' + @ParmRunId + '"' + ' ' +
               'and s.DeleteCd = 1'

    
				
	Exec sp_executesql @cmd  
    IF (@@error!=0)
    BEGIN
        --RAISERROR  20000 'stored procedure failed when checking duplicates (2)'
        RETURN
    END
          
    set nocount on
    
end

return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[TRDeleteBSP] on [dbo].[BRS]'
GO
ALTER TRIGGER [dbo].[TRDeleteBSP] ON [dbo].[BRS] 
FOR DELETE 
AS
if @@rowcount = 0 return

if OBJECT_ID('dbo.TRDeleteBSP') is NOT NULL
begin

  delete BSP where BRSId = (SELECT Id FROM deleted)

end
    
if @@error <> 0
begin
  --RAISERROR ('Deleting BSP failure in BRS trigger TRDeleteBSP; rolling back changes', 16,1)
  rollback transaction
  return
end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[BchTranInsert] on [dbo].[BchTran]'
GO
ALTER TRIGGER [dbo].[BchTranInsert] ON [dbo].[BchTran]
AFTER insert AS 
begin

    SET NOCOUNT ON
    
    declare @HstRecordId int, @ModVer tinyint, @BchTranRecordId int
    
    select @BchTranRecordId = RecordId
    from Inserted
    
    select @HstRecordId = max(h.RecordId),
           @ModVer      = max(h.ModVer)
    from Hst h with (nolock)
    inner join Inserted i on i.ChkRecordId = h.ChkRecordId and i.TranTyp = h.TranTyp
    
    update BchTran
    set HstRecordId = @HstRecordId,
        ModVer      = @ModVer
    where RecordId = @BchTranRecordId 

    if @@error <> 0
    begin
      --RAISERROR ('Updating BchTran failure in BchTran trigger BchTranInsert; rolling back changes', 16,1)
      rollback transaction
      return
    end

end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[BchBckCdChg] on [dbo].[Bch]'
GO
ALTER TRIGGER [dbo].[BchBckCdChg] ON [dbo].[Bch] 
FOR UPDATE 
AS
if @@rowcount = 0 return

if UPDATE(BckCd)
begin
  if OBJECT_ID('dbo.BchBckCdChg') is NOT NULL
  begin
    delete ImpTrn
    where ImpBch = (
		select i.Num
		from inserted i
		inner join deleted d on d.Num = i.Num
		where i.BckCd = 1
		and d.BckCd <> 1
		and i.Typ = 'I'
			)
    if @@error <> 0
    begin
      --RAISERROR ('Updating BckCd failure in Bch trigger BchBckCdChg; rolling back changes', 16,1)
      rollback transaction
      return
    end
  end
end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[ChkDeducted] on [dbo].[Chk]'
GO
ALTER TRIGGER [dbo].[ChkDeducted] ON [dbo].[Chk] 
FOR DELETE 
AS
if @@rowcount = 0 return

declare @RecordId int

select @RecordId = RecordId from Deleted

DELETE Deducted
WHERE ChkRecordId = @RecordId

if @@error <> 0
begin
  --RAISERROR ('Deleting ChkDeducted failure in ChK trigger ChkDeducted; rolling back changes', 16,1)
  rollback transaction
  return
end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[ChkInsert] on [dbo].[Chk]'
GO
ALTER  TRIGGER [dbo].[ChkInsert] ON [dbo].[Chk] 
FOR INSERT 
AS
if @@rowcount = 0 return

declare @ModVer smallint, @ArHModVer smallint, @TranTyp smallint
declare @ChkRecordId int, @ArHRecordId int, @Id decimal(11,0), @CTpId smallint, @XNum1 int, @eTranReissue int
declare @BlockSeqNum varchar(31)

/* on a Reissued Check use the following values */
set @eTranReissue = 11
set @BlockSeqNum = ''
set @XNum1 = 0

set @TranTyp = (
  select top 1 TranTyp
  from inserted
	)

if @TranTyp <> @eTranReissue begin
  select @BlockSeqNum = (
	select top 1 BlockSeqNum
	from inserted
		),
       @XNum1 = (
	select top 1 XNum1
	from inserted
		)
end

select @ChkRecordId = (
	select top 1 RecordId
	from inserted
		),
       @Id = (
	select top 1 Id
	from inserted
		),
       @CTpId = (
	select top 1 CTpId
	from inserted
		)
if @ChkRecordId is NULL
begin
  set @ChkRecordId = 0
end

if @TranTyp = 252 /* restore from archive, 07/NC/025 no history and update Chk:TranTyp to ArC:TranTyp */
begin
  update c
  set TranTyp = (
	select a.TranTyp
	from ArC a
    inner join inserted i on i.CTpId = a.CTpId and i.id = a.Id
		) 
  from Chk c
  inner join inserted i on i.CTpId = c.CTpId and i.id = c.Id
  where c.RecordId = @ChkRecordId
  return
end

if EXISTS (
	select 1 from stageChk
         where CTpId = @CTpId
	   and Id = @Id
		)
begin
  Return /* if this Chk is being imported from PointPay, then do NOT write Hst */
end

/*  07/NC/025.  Do not create history for an archive restore.
if @TranTyp = 252 /* restore from archive */
begin
  set @ModVer = (
	select max(h.ModVer) + 1 
	from ArH h
    inner join inserted i on i.CTpId = h.CTpId and h.id = i.Id
		)
end
else begin
  set @ModVer = (
    select top 1 ModVer
    from inserted
	)
end
*/

if @ModVer is NULL
begin
  set @ModVer = 0
end

insert Trans
select @ChkRecordId, @ModVer 

insert Hst (
    CTpId,
    Id,
    OrigId,
    IdPre,
    ModVer,
    ModCd,
    CmpId,
    PayToNam1,
    PayToNam2,
    PayToNam3,
    IssDt,
    PayAmt,
    OrigPayAmt,
    ResrvAmt,
    BnkId,
    BnkNum,
    LosDt,
    Dt1,
    Dt2,
    Dt3,
    Dt4,
    Dt5,
    Time1,
    Time2,
    TranCd,
    TaxId,
    TaxTyp,
    Tax1099,
    RptAmt1099,
    SpltPay1099,
    VndTyp,
    VndId,
    AgentTyp,
    AgentId,
    MailToNam,
    MailToAdr1,
    MailToAdr2,
    MailToAdr3,
    MailToAdr4,
    MailToAdr5,
    City,
    State,
    CntyCd,
    CountryId,
    ZipCd,
    BillState,
    BillDt,
    PhNum1,
    PhNum2,
    FaxNum,
    FaxNumTyp,
    FaxToNam,
    EmailAdr,
    MrgId,
    MrgId2,
    PayCd,
    PayToCd,
    ReqId,
    ExamId,
    ExamNam,
    AdjId,
    CurId,
    Office,
    DeptCd,
    MailStop,
    ReissCd,
    AtchCd,
    ReqNum,
    ImpBch,
    ImpBnkBch,
    PrtBch,
    RcnBch,
    SavRcnBch,
    ExpBch,
    PdBch,
    VoidExpCd,
    PrevVoidExpCd,
    WriteOffExpCd,
    SrchLtrCd,
    PrtCnt,
    RcnCd,
    VoidCd,
    VoidId,
    VoidDt,
    UnVoidCd,
    UnVoidId,
    UnVoidDt,
    SigCd,
    SigCd1,
    SigCd2,
    DrftCd,
    DscCd,
    RestCd,
    XCd1,
    XCd2,
    XCd3,
    XCd4,
    XCd5,
    XCd6,
    XCd7,
    XCd8,
    XCd9,
    XCd10,
    PayRate,
    XRate1,
    XRate2,
    XRate3,
    XAmt1,
    XAmt2,
    XAmt3,
    XAmt4,
    XAmt5,
    XAmt6,
    XAmt7,
    XAmt8,
    XAmt9,
    XAmt10,
    SalaryAmt,
    MaritalStat,
    FedExempt,
    StateExempt,
    Day30Cd,
    PstCd,
    RsnCd,
    PdCd,
    PdDt,
    ApprovCd,
    ApprovDt,
    ApprovId,
    ApprovCd2,
    ApprovDt2,
    ApprovId2,
    ApprovCd3,
    ApprovDt3,
    ApprovId3,
    ApprovCd4,
    ApprovDt4,
    ApprovId4,
    ApprovCd5,
    ApprovDt5,
    ApprovId5,
    ApprovCd6,
    ApprovDt6,
    ApprovId6,
    ApprovCd7,
    ApprovDt7,
    ApprovId7,
    ApprovCd8,
    ApprovDt8,
    ApprovId8,
    ApprovCd9,
    ApprovDt9,
    ApprovId9,
    AddDt,
    AddTime,
    AddId,
    ChgDt,
    ChgTime,
    ChgId,
    SrceCd,
    FrmCd,
    RefNum,
    NamTyp,
    LstNam,
    FstNam,
    MidInit,
    Salutation,
    AcctNum,
    ExpAcct,
    DebitAcct,
    BnkAcct,
    BnkRout,
    AcctNam,
    EftTypCd,
    BnkAcct2,
    BnkRout2,
    AcctNam2,
    EftTypCd2,
    BnkAcct3,
    BnkRout3,
    AcctNam3,
    EftTypCd3,
    AllocPct1,
    AllocPct2,
    AllocPct3,
    OptCd,
    EftTranCd,
    AdviceTyp,
    RepRsn,
    EmployerTyp,
    EmployerId,
    EmployerNam,
    EmployerAdr1,
    EmployerAdr2,
    EmployerAdr3,
    ProviderTyp,
    ProviderId,
    ProviderNam,
    CarrierTyp,
    CarrierId,
   PolId,
    InsNam,
    InsAdr1,
    InsAdr2,
    InsAdr3,
    ClaimNum,
    ClmntNum,
    ClmntNam,
    ClmntAdr1,
    ClmntAdr2,
    ClmntAdr3,
    LosCause,
    DiagCd1,
    DiagCd2,
    DiagCd3,
    DiagCd4,
    ForRsn1,
    ForRsn2,
    ForRsn3,
    CommentTxt,
    XNum1,
    XNum2,
    XNum3,
    XNum4,
    TransferOutBch,
    TransferInBch,
    VchCnt,
    PrtDt,
    PrtId,
    TranDt,
    TranTime,
    TranTyp,
    TranId,
    BTpId,
    ExamTyp,
    Priority,
    DeliveryDt,
    CardNum,
    CardTyp,
    ExportStat,
    PrevExportStat,
    NoBulk,
    Typ1099,
    TrmId,
    AltId,
    AltTyp,
    AthOver,
    AthId,
    AthCd,
    MicrofilmID,
    BlockSeqNum,
    PrtBchOFAC,
    ExpBch2,
    ExpBch3,
    PrenoteCd,
    SavPdBch,
    ACHTraceNum,
    EscheatExportStat,
    PrevEscheatExportStat,
    RcdLock,
    Tax1099Cd,
    ClmntTaxId,
    WorkstationId,
    UploadBchNum,
    ManSigCd,
    InsAdr4,
    ChkRecordId )
select
     i.CTpId,
     i.Id,
     i.OrigId,
     i.IdPre,
     i.ModVer, --@ModVer,   --i.ModVer,
     i.ModCd,
     i.CmpId,
     i.PayToNam1,
     i.PayToNam2,
     i.PayToNam3,
     i.IssDt,
     i.PayAmt,
     i.OrigPayAmt,
     i.ResrvAmt,
     i.BnkId,
     i.BnkNum,
     i.LosDt,
     i.Dt1,
     i.Dt2,
     i.Dt3,
     i.Dt4,
     i.Dt5,
     i.Time1,
     i.Time2,
     i.TranCd,
     i.TaxId,
     i.TaxTyp,
     i.Tax1099,
     i.RptAmt1099,
     i.SpltPay1099,
     i.VndTyp,
     i.VndId,
     i.AgentTyp,
     i.AgentId,
     i.MailToNam,
     i.MailToAdr1,
     i.MailToAdr2,
     i.MailToAdr3,
     i.MailToAdr4,
     i.MailToAdr5,
     i.City,
     i.State,
     i.CntyCd,
     i.CountryId,
     i.ZipCd,
     i.BillState,
     i.BillDt,
     i.PhNum1,
     i.PhNum2,
     i.FaxNum,
     i.FaxNumTyp,
     i.FaxToNam,
     i.EmailAdr,
     i.MrgId,
     i.MrgId2,
     i.PayCd,
     i.PayToCd,
     i.ReqId,
     i.ExamId,
     i.ExamNam,
     i.AdjId,
     i.CurId,
     i.Office,
     i.DeptCd,
     i.MailStop,
     i.ReissCd, 
     i.AtchCd, 
     i.ReqNum,
     i.ImpBch,
     i.ImpBnkBch,
     i.PrtBch,
     i.RcnBch,
     i.SavRcnBch,
     i.ExpBch,
     i.PdBch,
     i.VoidExpCd,
     i.PrevVoidExpCd,
     i.WriteOffExpCd, 
     i.SrchLtrCd, 
     i.PrtCnt, 
     i.RcnCd,
     i.VoidCd, 
     i.VoidId, 
     i.VoidDt, 
     i.UnVoidCd, 
     i.UnVoidId, 
     i.UnVoidDt, 
     i.SigCd, 
     i.SigCd1, 
     i.SigCd2, 
     i.DrftCd,
     i.DscCd, 
     i.RestCd, 
     i.XCd1, 
     i.XCd2, 
     i.XCd3, 
     i.XCd4, 
     i.XCd5, 
     i.XCd6, 
     i.XCd7, 
     i.XCd8, 
     i.XCd9, 
     i.XCd10, 
     i.PayRate,
     i.XRate1, 
     i.XRate2, 
     i.XRate3, 
     i.XAmt1, 
     i.XAmt2, 
     i.XAmt3, 
     i.XAmt4, 
     i.XAmt5, 
     i.XAmt6, 
     i.XAmt7, 
     i.XAmt8,
     i.XAmt9,
     i.XAmt10, 
     i.SalaryAmt, 
     i.MaritalStat, 
     i.FedExempt, 
     i.StateExempt, 
     i.Day30Cd, 
     i.PstCd,
     i.RsnCd, 
     i.PdCd, 
     i.PdDt, 
     i.ApprovCd, 
     i.ApprovDt, 
     i.ApprovId, 
     i.ApprovCd2, 
     i.ApprovDt2, 
     i.ApprovId2,
     i.ApprovCd3, 
     i.ApprovDt3, 
     i.ApprovId3,
     i.ApprovCd4,
     i.ApprovDt4, 
     i.ApprovId4, 
     i.ApprovCd5,
     i.ApprovDt5, 
     i.ApprovId5, 
     i.ApprovCd6, 
     i.ApprovDt6, 
     i.ApprovId6,
     i.ApprovCd7, 
     i.ApprovDt7,
     i.ApprovId7, 
     i.ApprovCd8,
     i.ApprovDt8, 
     i.ApprovId8, 
     i.ApprovCd9, 
     i.ApprovDt9, 
     i.ApprovId9,
     i.AddDt, 
     i.AddTime, 
     i.AddId, 
     i.ChgDt, 
     i.ChgTime, 
     i.ChgId, 
     i.SrceCd, 
     i.FrmCd, 
     i.RefNum, 
     i.NamTyp,
     i.LstNam, 
     i.FstNam, 
     i.MidInit, 
     i.Salutation, 
     i.AcctNum, 
     i.ExpAcct, 
     i.DebitAcct, 
     i.BnkAcct,
     i.BnkRout, 
     i.AcctNam, 
     i.EftTypCd, 
     i.BnkAcct2, 
     i.BnkRout2, 
     i.AcctNam2, 
     i.EftTypCd2, 
     i.BnkAcct3,
     i.BnkRout3, 
     i.AcctNam3, 
     i.EftTypCd3,
     i.AllocPct1,
     i.AllocPct2,
     i.AllocPct3,
     i.OptCd,
     i.EftTranCd,
     i.AdviceTyp,
     i.RepRsn,
     i.EmployerTyp,
     i.EmployerId,
     i.EmployerNam,
     i.EmployerAdr1,
     i.EmployerAdr2,
     i.EmployerAdr3,
     i.ProviderTyp,
     i.ProviderId,
     i.ProviderNam,
     i.CarrierTyp,
     i.CarrierId,
     i.PolId,
     i.InsNam,
     i.InsAdr1,
     i.InsAdr2, 
     i.InsAdr3, 
     i.ClaimNum, 
     i.ClmntNum, 
     i.ClmntNam, 
     i.ClmntAdr1,
     i.ClmntAdr2, 
     i.ClmntAdr3, 
     i.LosCause, 
     i.DiagCd1, 
     i.DiagCd2, 
     i.DiagCd3, 
     i.DiagCd4, 
     i.ForRsn1,
     i.ForRsn2, 
     i.ForRsn3, 
     i.CommentTxt, 
     @XNum1, 
     i.XNum2, 
     i.XNum3, 
     i.XNum4,
     i.TransferOutBch, 
     i.TransferInBch, 
     i.VchCnt, 
     i.PrtDt, 
     i.PrtId, 
     i.TranDt, 
     i.TranTime, 
     i.TranTyp,
     i.TranId, 
     i.BTpId, 
     i.ExamTyp, 
     i.Priority, 
     i.DeliveryDt, 
     i.CardNum, 
     i.CardTyp, 
     i.ExportStat,
     i.PrevExportStat, 
     i.NoBulk, 
     i.Typ1099, 
     i.TrmId, 
     i.AltId, 
     i.AltTyp, 
     i.AthOver, 
     i.AthId, 
     i.AthCd,
     i.MicrofilmID, 
     @BlockSeqNum, 
     i.PrtBchOFAC, 
     i.ExpBch2, 
     i.ExpBch3, 
     i.PrenoteCd, 
     i.SavPdBch,
     i.ACHTraceNum,
     i.EscheatExportStat, 
     i.PrevEscheatExportStat,
     i.RcdLock,
     i.Tax1099Cd,
     i.ClmntTaxId, 
     i.WorkstationId,
     i.UploadBchNum,
     i.ManSigCd,
     i.InsAdr4,
     i.RecordId
from inserted i

if @@error <> 0
begin
  --RAISERROR ('Inserting Chk History failure in ChK trigger ChkInsert; rolling back changes', 16,1)
  rollback transaction
  return
end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[ChkStopDelete] on [dbo].[Chk]'
GO
ALTER TRIGGER [dbo].[ChkStopDelete] ON [dbo].[Chk] 
FOR DELETE 
AS
if @@rowcount = 0 return

declare @RecordId int

select @RecordId = RecordId from Deleted

DELETE ChkStop
WHERE RecordId = @RecordId

if @@error <> 0
begin
  --RAISERROR ('Deleting ChkStop failure in ChK trigger ChkStopDelete; rolling back changes', 16,1)
  rollback transaction
  return
end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[CompletedPayment] on [dbo].[Chk]'
GO


ALTER TRIGGER [dbo].[CompletedPayment] ON [dbo].[Chk] 
FOR UPDATE 
AS
if @@rowcount = 0 return

declare @Inserted_RecordId int

select @Inserted_RecordId = RecordId 
  from inserted
  
if @Inserted_RecordId is NULL
begin
  set @Inserted_RecordId = 0
end

if UPDATE(PrtBch)
begin
  IF OBJECT_ID('dbo.CompletedPayment') IS NOT NULL
  BEGIN
    if not exists (
      select 1 from CompletedPayments
      where RecordId = @Inserted_RecordId
                  )
    begin
      insert CompletedPayments (RecordId)
      select i.RecordId
      from inserted i
      inner join deleted d on i.RecordId = d.RecordId
      where i.PrtBch <> 0
        and d.PrtBch = 0  -- the payment/check record has been Printed

      if @@error <> 0
      begin
        --RAISERROR ('Updating PrtBch failure in ChK trigger CompletedPayment; rolling back changes', 16,1)
        rollback transaction
        return
      end
    end
  end
end

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[DeleteImpTrn] on [dbo].[Chk]'
GO
ALTER TRIGGER [dbo].[DeleteImpTrn] ON [dbo].[Chk] 
FOR DELETE 
AS
if @@rowcount = 0 return

if OBJECT_ID('dbo.DeleteImpTrn') is NOT NULL
begin

  declare chk_deleted cursor for
  select CTpId, Id
  from deleted

  open chk_deleted

  declare @CTpId smallint, @Id decimal

  fetch chk_deleted into @CTpId, @Id
  while @@fetch_status = 0
  begin

    delete ImpTrn
    from ImpTrn i,
    Vch v
    where i.TrnAmt = (select sum(NetAmt) from vch v2 where v2.InvDt = v.InvDt and v2.InvId = v.InvId)
      and i.InvDt = v.InvDt
      and i.InvId = v.InvId
      and v.CTpId = @CTpId
      and v.ChkId = @Id
    
    fetch chk_deleted into @CTpId, @Id

  end

  close chk_deleted
  deallocate chk_deleted
end
    
if @@error <> 0
begin
  --RAISERROR ('Deleting ImpTrn failure in Chk trigger DeleteImpTrn; rolling back changes', 16,1)
  rollback transaction
  return
end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[IssuedChk] on [dbo].[Chk]'
GO
ALTER TRIGGER [dbo].[IssuedChk] ON [dbo].[Chk] 
FOR UPDATE 
AS
if @@rowcount = 0 return

if UPDATE(IssDt)
begin
  IF OBJECT_ID('dbo.ChkIssued') IS NOT NULL
  BEGIN
    insert ChkIssued (RecordId)
    select i.RecordId
    from inserted i
    inner join deleted d on i.RecordId = d.RecordId
    where i.IssDt <> 0
      and d.IssDt = 0  -- the payment/check record has been Issued

    if @@error <> 0
    begin
      --RAISERROR ('Updating IssDt failure in ChK trigger IssuedChk; rolling back changes', 16,1)
      rollback transaction
      return
    end
  end
end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[UnVoidChk] on [dbo].[Chk]'
GO
ALTER  TRIGGER [dbo].[UnVoidChk] ON [dbo].[Chk]
FOR UPDATE 
AS
if @@rowcount = 0 return

/*
 the payment/check record has been UnVoided BEFORE an Export, so delete
 the CkV record
*/
if UPDATE(VoidCd) 
begin
  if exists
  (
    select 1
    from CkV c
    inner join inserted i on i.RecordId = c.RecordId
    inner join deleted d on d.RecordId = i.RecordId
    where d.VoidCd in (1,2,9)  -- the payment/check record has been "UnVoided"
      and i.VoidCd = 0
      and c.ExpBch is NULL
      and c.Deleted is NULL
  )
  begin
    UPDATE CkV 
    set Deleted = 'Y'
    where RecordId in (
        select i.RecordId
        from inserted  i
        inner join deleted d on d.RecordId = i.RecordId
        where d.VoidCd in (1,2,9)  -- the payment/check record has been "UnVoided"
          and i.VoidCd = 0
            )
      and ExpBch is NULL
      and Deleted is NULL
    if @@error <> 0
    begin
        --RAISERROR ('Delete CkV failure in ChK trigger UnVoidChk; rolling back changes', 16,1)
        rollback transaction
        return
    end
  end
  if exists
        (
    select 1
    from CompletedPayments p
    inner join inserted i on i.RecordId = p.RecordId
    inner join deleted d on d.RecordId = i.RecordId
    where d.VoidCd in (1,2,9)  -- the payment/check record has been "UnVoided"
      and i.VoidCd = 0
      and p.UploadDt is NULL
        )
  begin
    delete CompletedPayments
    where RecordId in (
        select i.RecordId 
        from inserted i
        inner join deleted d on d.RecordId = i.RecordId
        where d.VoidCd in (1,2,9)  -- the payment/check record has been "UnVoided"
          and i.VoidCd = 0
                )
      and UploadDt is NULL
    if @@error <> 0
    begin
        --RAISERROR ('Delete failure for CompletedPayments, trigger UnVoidChk; rolling back changes', 16,1)
        rollback transaction
        return
    end
  end
end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[VoidChk] on [dbo].[Chk]'
GO
ALTER TRIGGER [dbo].[VoidChk] ON [dbo].[Chk] 
FOR UPDATE 
AS
if @@rowcount = 0 return

if UPDATE(VoidCd)
begin
  if not exists (
    select 1 from CompletedPayments
    where RecordId in (select RecordId from inserted)
                  )
  begin
    insert CompletedPayments (RecordId)
    select i.RecordId
    from inserted i
    inner join deleted d on d.RecordId = i.RecordId
    where i.VoidCd in (1,2,3)
      and d.VoidCd = 0  -- the payment/check record has been Voided,
                        -- or Stopped

    if @@error <> 0
    begin
      --RAISERROR ('Updating VoidCd failure in ChK trigger VoidChk; rolling back changes', 16,1)
      rollback transaction
      return
    end
  end

  insert CkV (RecordId, VoidCd, VoidDt, AddDt)
  select i.RecordId, i.VoidCd, i.VoidDt, GetDate()
    from inserted i
    inner join deleted d on d.RecordId = i.RecordId
    where i.VoidCd in (1,2,9)
      and d.VoidCd = 0  -- the payment/check record has been Voided

  if @@error <> 0
  begin
    --RAISERROR ('Updating VoidCd failure in ChK trigger VoidChk; rolling back changes', 16,1)
    rollback transaction
    return
  end

  IF OBJECT_ID('dbo.ChkIssued') IS NOT NULL
  BEGIN
    insert ChkIssued (RecordId, VoidInd)
    select i.RecordId, 'V'
    from inserted i
    inner join deleted d on d.RecordId = i.RecordId
    where i.VoidCd in (1,2,9)
      and d.VoidCd = 0  -- the payment/check record has been Voided

    if @@error <> 0
    begin
      --RAISERROR ('Updating VoidCd failure in ChK trigger VoidChk; rolling back changes', 16,1)
      rollback transaction
      return
    end
  end
end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[TRLogInsert] on [dbo].[Log]'
GO
ALTER   TRIGGER [dbo].[TRLogInsert] ON [dbo].[Log]
AFTER insert AS 
begin

    SET NOCOUNT ON

    declare @CTpId smallint, @ChkId decimal(11,0), @SeqNum int, @RecordId int
    declare @ChkStat varchar(20), @ChkStatDt int
    declare @VoidDt int, @PrtDt int, @AddDt int

/* ----------------------------------------------------------------------------------------- */
/*                   Initialize all variables used by this trigger                           */
/* ----------------------------------------------------------------------------------------- */
    set @CTpId     = 0 
    set @ChkId     = 0
    set @SeqNum    = 0 
    set @RecordId  = 0
    set @ChkStat   = ''
    set @ChkStatDt = 0
    set @VoidDt    = 0
    set @PrtDt     = 0
    set @AddDt     = 0
  
/* ----------------------------------------------------------------------------------------- */
/*          Retrieve the SeqNum, CTpId and ChkId from the Inserted Log row                   */
/* ----------------------------------------------------------------------------------------- */
    select @SeqNum = SeqNum,
	   @CTpId = CTpId,
           @ChkId = ChkId
    from inserted

/* ----------------------------------------------------------------------------------------- */
/*    Not all Log records have Chk information...only proceed when the Log represents a      */
/*    payment (Chk) record.                                                                  */
/* ----------------------------------------------------------------------------------------- */
    if @SeqNum <> 0 and @CTpId <> 0 and @ChkId <> 0
    begin

      select @RecordId = RecordId,
             @VoidDt = VoidDt,
             @PrtDt = PrtDt,
             @AddDt = AddDt
      from Chk
      where CTpId = @CTpId
        and Id = @ChkId

/* ----------------------------------------------------------------------------------------- */
/* Determine the Chk Status and the Chk StatusDate at the time that the Log row is inserted  */
/* The Chk StatusDate is dependent upon the Chk Status (Void, Printed, Imported, etc).       */
/* ----------------------------------------------------------------------------------------- */
      select @ChkStat = Status
      from vPaymentStatus
      where RecordId = @RecordId

      if @ChkStat = 'Voided'
      begin
        set @ChkStatDt = @VoidDt
      end
      else begin
        if @ChkStat = 'Printed'
        begin
          set @ChkStatDt = @PrtDt
        end
        else begin
          set @ChkStatDt = @AddDt	-- the Import or Manual add date
        end
      end

      update [Log]
      set ChkStat = @ChkStat,
          ChkStatDt = @ChkStatDt
      where SeqNum = @SeqNum

      if @@error <> 0
      begin
        --RAISERROR ('Inserting LogInsert failure in Log trigger LogInsert; rolling back changes', 16,1)
        rollback transaction
        return
      end

    end

end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[VchDelete] on [dbo].[Vch]'
GO
ALTER TRIGGER [dbo].[VchDelete] ON [dbo].[Vch] 
FOR DELETE 
AS
if @@rowcount = 0 return

declare @VchId int

select @VchId = Id from Deleted

DELETE Vch1
WHERE VchId = @VchId

if @@error <> 0
begin
  --RAISERROR ('Deleting Vch1 failure in Vch trigger VchDelete; rolling back changes', 16,1)
  rollback transaction
  return
end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[Default_EftTypCd] on [dbo].[Vnd]'
GO
ALTER TRIGGER [dbo].[Default_EftTypCd] ON [dbo].[Vnd] 
FOR INSERT
AS

if @@rowcount = 0 return

update Vnd
set Vnd.EftTypCd = 'C'	/* the default value is 'C' for Check */
from inserted
inner join vnd on vnd.Typ = inserted.Typ and vnd.Id = inserted.Id
where vnd.EftTypCd = ''	/* if the EftTypCd is blank */

if @@error <> 0
begin
  --RAISERROR ('EftTypCd set default failure for Vnd: rolling back changes', 16,1)
  rollback transaction
  return
end
return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[DeleteEMN] on [dbo].[Vnd]'
GO

ALTER TRIGGER [dbo].[DeleteEMN] ON [dbo].[Vnd]
FOR UPDATE
AS

if @@rowcount = 0 return

begin tran

	delete EMN
	where VndRecordId in (
				select RecordId from Inserted where EmailAdr is NULL or EmailAdr = ''
						)
    
    if @@error <> 0
    begin
		--RAISERROR ('Trigger DeleteEMN failed when clearing Vnd EmailAdr - rolling back changes', 16,1)
        rollback transaction
	end

commit tran
	

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[PayMthChg] on [dbo].[Vnd]'
GO
ALTER   TRIGGER [dbo].[PayMthChg] ON [dbo].[Vnd] 
FOR UPDATE 
AS
if @@rowcount = 0 return
if UPDATE(EftCd)
begin
  insert VPC (Id, TaxId, Nam, PayMethod, Dt)
  select i.Id, i.TaxId, i.Nam, 'CHK', getdate()
  from inserted i
  inner join deleted d on d.Typ = i.Typ and d.Id = i.Id and i.EftApprov <> d.EftApprov
  where i.Typ = 'MTV'    -- this applies to MTV vendors only
    and d.EftApprov = 1  -- this means that the EFT was previously setup ("accepted" or "pre-noted")
  if @@error <> 0
  begin
    --RAISERROR ('Outgoing Payment Type Changes failure for CHK: rolling back changes', 16,1)
    rollback transaction
    return
  end
end
if UPDATE(EftApprov)
begin
  insert VPC (Id, TaxId, Nam, PayMethod, Dt)
  select i.Id, i.TaxId, i.Nam, 'ACH', getdate()
  from inserted i
  inner join deleted d on  d.Typ = i.Typ and d.Id = i.Id and i.EftApprov <> d.EftApprov
  where i.Typ = d.Typ
    and i.Typ = 'MTV'  -- this applies to MTV vendors only
    and i.Id  = d.Id
    and ( i.EftApprov <> d.EftApprov OR d.EftApprov is NULL )
    and i.EftApprov = 1
  if @@error <> 0
  begin
    --RAISERROR ('Outgoing Payment Type Changes failure for ACH: rolling back changes', 16,2)
    rollback transaction
    return
  end
end
return
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[trWHApplied] on [dbo].[WHVch]'
GO
ALTER TRIGGER [dbo].[trWHApplied] ON [dbo].[WHVch] 
FOR INSERT
AS
if @@rowcount = 0 return

declare @RecordId int, @WHAppliedId int

IF OBJECT_ID('dbo.WHApplied') IS NOT NULL
BEGIN
  
/* get the RecordId, from the most recent Hst record - insert the result in the WHApplied row */  
  set @RecordId = (
                 select top 1 h.RecordId 
                 from Hst h
                 inner join Vch v on v.CTpId = h.CTpId and v.ChkId = h.Id
                 inner join Inserted i on i.VchId = v.Id
                 inner join WHTyp w on w.Id = i.WHTypId
                  order by h.ModVer desc
                    )
                    
  if @RecordId is NULL or @RecordId = 0
  begin
    return
  end
  
/* many Vch records could cause this trigger to fire - just return if the WHApplied record is found */  
  if exists (select * from WHApplied where HstRecordId = @RecordId)
  begin
    return
  end
  
/* 
   check to see if a WHApplied record exists (inserted from a previous print,
   assuming this is a  reprint) 
*/
  set @WHAppliedId = (
		select TOP 1 Id from WHApplied 
	         where HstRecordId IN (
        	       select h.RecordId
                     from Hst h
                     inner join Vch v on v.CTpId = h.CTpId and v.ChkId = h.Id
                     inner join Inserted i on i.VchId = v.Id
                     inner join WHTyp w on w.Id = i.WHTypId
        	         where h.TranTyp IN (80,100,210) -- print, reprint or EFT Build
                       )
               and ExportBch1 is NULL   -- the WHApplied record has NOT been exported yet...
               and ExportBch2 is NULL   -- the WHApplied record has NOT been exported yet...
		)
  if @WHAppliedId is NULL
  begin
    set @WHAppliedId = 0
  end
  
  if @WHAppliedId <> 0 -- we have found the previous WHApplied row!
  begin             -- change the HstRecordId to match the new Hst record
    update WHApplied
    set HstRecordId = @RecordId
    where Id = @WHAppliedId
  end
  else begin
    insert WHApplied (HstRecordId)
    select @RecordId  /* this value was derived earlier - it is the Hst.RecordId */
  end

  if @@error <> 0
  begin
    --RAISERROR ('Inserting RecordId failure in WHVch trigger trWHApplied; rolling back changes', 16,1)
    rollback transaction
    return
  end

END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[ppTRImportFromStaging] on [dbo].[stageBch]'
GO
-- =============================================
-- Author:	<Ed Connors, Prelude Software, Inc.>
-- ALTER  date: <March, 2006>
-- Description:	<When the UploadOprId is populated, execute the stored
--               procedure, ppSPImportFromStaging @wksid, @datetime>
-- =============================================
ALTER   TRIGGER [dbo].[ppTRImportFromStaging] ON [dbo].[stageBch] 
FOR UPDATE 
AS
if @@rowcount = 0 return

declare @WorkstationId varchar(30), @DateTime varchar(30), @UploadBchNum int

set @WorkstationId = NULL
set @DateTime = NULL
set @UploadBchNum = 0

if UPDATE(UploadOprId)
begin

  if OBJECT_ID('dbo.ppTRImportFromStaging') IS NOT NULL
  begin
    select @WorkstationId = i.WorkstationId,
           @DateTime = i.DateTime,
           @UploadBchNum = i.Num
      from inserted i,
           deleted d
      where i.Num = d.Num
        and (i.UploadOprId <> '' AND i.UploadOprId is not NULL)
        and (d.UploadOprId = '' or d.UploadOprId is NULL)

    if @WorkstationId IS NOT NULL and @DateTime IS NOT NULL and @UploadBchNum <> 0
    begin
      Exec ppSPImportFromStaging @WorkstationId, @DateTime, @UploadBchNum
    end
  end /* end IF checking for the existence of the ppSPImportFromStaging stored procedure */

  if @@error <> 0
  begin
    --RAISERROR ('Updating UploadOprId failure in Bch trigger ppTRImportFromStaging; rolling back changes', 16,1)
    rollback transaction
    return
  end

end
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [dbo].[ppTRStageBchDelete] on [dbo].[stageBch]'
GO
-- =============================================
-- Author:		<Ed Connors, Prelude Software, Inc.>
-- ALTER  date: <April, 2006>
-- Description:	<When a stageBch record is deleted, due to an incomplete
--               upload and import process, delete the stageChk and
--               stageHst child records>
-- =============================================
ALTER   TRIGGER [dbo].[ppTRStageBchDelete]
ON [dbo].[stageBch]
for Delete 
AS
BEGIN

  if @@rowcount = 0 return

  set nocount on
    
  declare @UploadBchNum int
  
  select @UploadBchNum = d.UploadBchNum
  from Deleted d

  BEGIN TRAN

    Delete stageHst
    where UploadBchNum = @UploadBchNum
  
    IF (@@error!=0)
    BEGIN
       --RAISERROR  20000 'ppTRStageBchDelete: unable to delete stageHst records after deleting stageBch'
       ROLLBACK TRAN
    END

    Delete stageChk
    where UploadBchNum = @UploadBchNum

    IF (@@error!=0)
    BEGIN
       --RAISERROR  20000 'ppTRStageBchDelete: unable to delete stageChk records after deleting stageBch'
       ROLLBACK TRAN
    END

    COMMIT TRAN

    set nocount off
    
    RETURN /* Return with a zero status to indicate a successful process */

END

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
COMMIT TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
DECLARE @Success AS BIT
SET @Success = 1
SET NOEXEC OFF
IF (@Success = 1) PRINT 'The database update succeeded'
ELSE BEGIN
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
	PRINT 'The database update failed'
END
GO
