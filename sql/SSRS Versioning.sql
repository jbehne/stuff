
-- Type 2 = Reports
SELECT * FROM catalog WHERE Type = 2

/*
-- Convert content to the XML report definition
SELECT CONVERT(XML,CONVERT(VARBINARY(MAX), Content))
FROM catalog
WHERE ItemID = '9D73F357-DCEC-4B32-A4A1-F1D3F3427CB5'
*/

-- Table holds the version #, item ID, modified date, path, and content (as varbinary)
-- Clustered key will be version and itemid 
CREATE TABLE Version (VersionID int, ItemID UNIQUEIDENTIFIER, ModifiedDate datetime, Path varchar(max), Content varbinary(max));
CREATE CLUSTERED INDEX CIX_Version ON Version (ItemID, VersionID) WITH (DATA_COMPRESSION=PAGE);

-- Initial insert of existing reports (just calling them V1)
INSERT Version
SELECT 1, ItemID, ModifiedDate, Path, Content FROM catalog WHERE Type = 2

-- Verify
SELECT * FROM Version



-- UPDATE trigger
IF OBJECT_ID('dbo.utr_UpdateVersion', 'TR') IS NOT NULL
    DROP TRIGGER dbo.utr_UpdateVersion;
GO

CREATE TRIGGER dbo.utr_UpdateVersion ON dbo.Catalog
FOR UPDATE
AS
BEGIN
	-- Create a version, content, and compare variable
	DECLARE @version int, @content varbinary(max), @compare bit;
	-- Get the last version from the version table 
	SELECT @version = MAX(VersionID) FROM Version WHERE ItemID = 
		(SELECT ItemID FROM INSERTED);
	-- Get the content of the last version to compare
	SELECT @content = Content FROM Version WHERE VersionID = @version
		AND ItemID = (SELECT ItemID FROM INSERTED);
	-- Compare content for changes
	SELECT @compare = CASE WHEN @content = Content THEN 0 ELSE 1 END
	FROM INSERTED

	-- If the data did not change, the trigger is complete
	IF @compare = 0 RETURN;

	-- Increment version
	SET @version = @version + 1

	-- Insert the new report into the version table (Where type = 2 - report)
	INSERT Version (VersionID, ItemID, ModifiedDate, Path, Content)
	SELECT @version, ItemID, ModifiedDate, Path, Content
	FROM INSERTED
	WHERE Type = 2;
END;
GO



-- INSERT trigger
IF OBJECT_ID('dbo.utr_InsertVersion', 'TR') IS NOT NULL
    DROP TRIGGER dbo.utr_InsertVersion;
GO

CREATE TRIGGER dbo.utr_InsertVersion ON dbo.Catalog
FOR INSERT
AS
BEGIN
	-- Insert the new report into the version table (Where type = 2 - report)
	INSERT Version (VersionID, ItemID, ModifiedDate, Path, Content)
	SELECT 1, ItemID, ModifiedDate, Path, Content
	FROM INSERTED
	WHERE Type = 2;
END;
GO
