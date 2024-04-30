
CREATE DATABASE Test_DB;
GO
USE Test_DB;
EXEC sys.sp_cdc_enable_db;ALTER DATABASE Test_DB
SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON)


CREATE TABLE prospects (
  id INTEGER IDENTITY(1001,1) NOT NULL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE
);

EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'prospects', @role_name = NULL, @supports_net_changes = 0;
GO

INSERT INTO prospects(first_name,last_name,email)
  VALUES ('Kayvan','Soleimani','kayvan3.sol@gmail.com');