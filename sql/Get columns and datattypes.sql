select COLUMN_NAME + ',', 
COLUMN_NAME + ' ' + DATA_TYPE + CASE WHEN CHARACTER_MAXIMUM_LENGTH IS NULL THEN ',' ELSE '(' + CAST(CHARACTER_MAXIMUM_LENGTH AS varchar(12)) + '),' END
from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME = 'Security_ServerPermissions'


