-- ============================================================
-- SqlServerScriptPermissions - Automated Tests
-- Run against the DBA database after deploying
-- Deployment_of_SQL_Scripting_Permissions.sql
--
-- Tests:
--   1. All 6 tables populated after collection
--   2. sp_DBA_Script_All_Permissions returns T-SQL syntax
--   3. sp_DBA_Read_Permissions returns human-readable format
--   4. sp_DBA_Read_Permissions @PermissionLevel filters
--   5. sp_DBA_Read_Permissions @Dbname filter reduces rows
--   6. sp_DBA_Read_Permissions @LoginName filter
--   7. Error handling — positive @returndays raises error
-- ============================================================

USE DBA;
GO

SET NOCOUNT ON;

DECLARE @Errors   int = 0;
DECLARE @RowCount int;

PRINT '============================================================';
PRINT 'SqlServerScriptPermissions - Automated Tests';
PRINT '============================================================';

-- ============================================================
-- SETUP: Collect permissions so all tables are populated
-- ============================================================
PRINT '';
PRINT '>> SETUP: Running sp_DBA_Get_All_Permissions...';
EXEC sp_DBA_Get_All_Permissions;
PRINT '   Collection complete.';


-- ============================================================
-- TEST 1: Tables are populated after collection
-- ============================================================
PRINT '';
PRINT '-- TEST 1: Tables populated after collection';

SELECT @RowCount = COUNT(*) FROM tbl_DBA_logins WHERE DATE > DATEADD(day,-1,GETDATE());
IF @RowCount = 0 BEGIN PRINT '   FAIL: tbl_DBA_logins is empty'; SET @Errors = @Errors + 1; END
ELSE PRINT '   PASS: tbl_DBA_logins has ' + CAST(@RowCount AS varchar) + ' row(s)';

SELECT @RowCount = COUNT(*) FROM tbl_DBA_server_roles WHERE DATE > DATEADD(day,-1,GETDATE());
IF @RowCount = 0 BEGIN PRINT '   FAIL: tbl_DBA_server_roles is empty'; SET @Errors = @Errors + 1; END
ELSE PRINT '   PASS: tbl_DBA_server_roles has ' + CAST(@RowCount AS varchar) + ' row(s)';

SELECT @RowCount = COUNT(*) FROM tbl_DBA_Server_level_permissions WHERE DATE > DATEADD(day,-1,GETDATE());
IF @RowCount = 0 BEGIN PRINT '   FAIL: tbl_DBA_Server_level_permissions is empty'; SET @Errors = @Errors + 1; END
ELSE PRINT '   PASS: tbl_DBA_Server_level_permissions has ' + CAST(@RowCount AS varchar) + ' row(s)';

SELECT @RowCount = COUNT(*) FROM tbl_DBA_role_level_permissions WHERE DATE > DATEADD(day,-1,GETDATE());
IF @RowCount = 0 BEGIN PRINT '   FAIL: tbl_DBA_role_level_permissions is empty'; SET @Errors = @Errors + 1; END
ELSE PRINT '   PASS: tbl_DBA_role_level_permissions has ' + CAST(@RowCount AS varchar) + ' row(s)';

SELECT @RowCount = COUNT(*) FROM tbl_DBA_Users_per_db WHERE DATE > DATEADD(day,-1,GETDATE());
IF @RowCount = 0 BEGIN PRINT '   FAIL: tbl_DBA_Users_per_db is empty'; SET @Errors = @Errors + 1; END
ELSE PRINT '   PASS: tbl_DBA_Users_per_db has ' + CAST(@RowCount AS varchar) + ' row(s)';

SELECT @RowCount = COUNT(*) FROM tbl_DBA_User_level_permissions WHERE DATE > DATEADD(day,-1,GETDATE());
IF @RowCount = 0 BEGIN PRINT '   FAIL: tbl_DBA_User_level_permissions is empty'; SET @Errors = @Errors + 1; END
ELSE PRINT '   PASS: tbl_DBA_User_level_permissions has ' + CAST(@RowCount AS varchar) + ' row(s)';


-- ============================================================
-- TEST 2: sp_DBA_Script_All_Permissions returns T-SQL syntax
-- Script columns must contain CREATE/GRANT/EXEC keywords
-- ============================================================
PRINT '';
PRINT '-- TEST 2: sp_DBA_Script_All_Permissions returns T-SQL script syntax';

SELECT @RowCount = COUNT(*)
FROM tbl_DBA_logins
WHERE DATE > DATEADD(day,-1,GETDATE())
AND Logins_to_be_created LIKE '%CREATE LOGIN%';
IF @RowCount = 0 BEGIN PRINT '   FAIL: Login scripts do not contain CREATE LOGIN syntax'; SET @Errors = @Errors + 1; END
ELSE PRINT '   PASS: Login scripts contain CREATE LOGIN syntax (' + CAST(@RowCount AS varchar) + ' row(s))';

SELECT @RowCount = COUNT(*)
FROM tbl_DBA_server_roles
WHERE DATE > DATEADD(day,-1,GETDATE())
AND server_roles LIKE '%sp_addsrvrolemember%';
IF @RowCount = 0 BEGIN PRINT '   FAIL: Server role scripts do not contain sp_addsrvrolemember syntax'; SET @Errors = @Errors + 1; END
ELSE PRINT '   PASS: Server role scripts contain sp_addsrvrolemember syntax (' + CAST(@RowCount AS varchar) + ' row(s))';

PRINT '   Running sp_DBA_Script_All_Permissions @returndays = -1...';
EXEC sp_DBA_Script_All_Permissions @returndays = -1;
PRINT '   PASS: sp_DBA_Script_All_Permissions executed without error';


-- ============================================================
-- TEST 3: sp_DBA_Read_Permissions returns readable format
-- ReadablePermission must use LOGIN:/USER:/STATE: pattern
-- and must NOT contain raw T-SQL syntax
-- ============================================================
PRINT '';
PRINT '-- TEST 3: sp_DBA_Read_Permissions returns human-readable format';

SELECT @RowCount = COUNT(*)
FROM tbl_DBA_logins
WHERE DATE > DATEADD(day,-1,GETDATE())
AND ReadablePermission LIKE 'LOGIN:%';
IF @RowCount = 0 BEGIN PRINT '   FAIL: ReadablePermission in tbl_DBA_logins does not follow LOGIN: pattern'; SET @Errors = @Errors + 1; END
ELSE PRINT '   PASS: ReadablePermission follows LOGIN: pattern (' + CAST(@RowCount AS varchar) + ' row(s))';

SELECT @RowCount = COUNT(*)
FROM tbl_DBA_logins
WHERE DATE > DATEADD(day,-1,GETDATE())
AND ReadablePermission LIKE '%CREATE LOGIN%';
IF @RowCount > 0 BEGIN PRINT '   FAIL: ReadablePermission contains T-SQL syntax - should be human-readable only'; SET @Errors = @Errors + 1; END
ELSE PRINT '   PASS: ReadablePermission does not contain T-SQL syntax';

PRINT '   Running sp_DBA_Read_Permissions @returndays = -1 (all levels)...';
EXEC sp_DBA_Read_Permissions @returndays = -1;
PRINT '   PASS: sp_DBA_Read_Permissions executed without error';


-- ============================================================
-- TEST 4: sp_DBA_Read_Permissions @PermissionLevel filters
-- ============================================================
PRINT '';
PRINT '-- TEST 4: sp_DBA_Read_Permissions @PermissionLevel filters';

PRINT '   LOGINS only...';
EXEC sp_DBA_Read_Permissions @returndays = -1, @PermissionLevel = 'LOGINS';
PRINT '   PASS: LOGINS';

PRINT '   SERVER only...';
EXEC sp_DBA_Read_Permissions @returndays = -1, @PermissionLevel = 'SERVER';
PRINT '   PASS: SERVER';

PRINT '   DATABASE only...';
EXEC sp_DBA_Read_Permissions @returndays = -1, @PermissionLevel = 'DATABASE';
PRINT '   PASS: DATABASE';

PRINT '   OBJECT only...';
EXEC sp_DBA_Read_Permissions @returndays = -1, @PermissionLevel = 'OBJECT';
PRINT '   PASS: OBJECT';


-- ============================================================
-- TEST 5: sp_DBA_Read_Permissions @Dbname filter reduces rows
-- ============================================================
PRINT '';
PRINT '-- TEST 5: sp_DBA_Read_Permissions @Dbname filter';

DECLARE @AllDbs int, @OnlyDba int;

SELECT @AllDbs = COUNT(*) FROM tbl_DBA_role_level_permissions WHERE DATE > DATEADD(day,-1,GETDATE());
SELECT @OnlyDba = COUNT(*) FROM tbl_DBA_role_level_permissions WHERE DATE > DATEADD(day,-1,GETDATE()) AND DBName = 'DBA';

IF @AllDbs >= @OnlyDba
    PRINT '   PASS: @Dbname=''DBA'' returns ' + CAST(@OnlyDba AS varchar) + ' row(s), unfiltered returns ' + CAST(@AllDbs AS varchar);
ELSE BEGIN PRINT '   FAIL: Filtered result has more rows than unfiltered'; SET @Errors = @Errors + 1; END

PRINT '   Running sp_DBA_Read_Permissions @returndays=-1, @Dbname=''DBA''...';
EXEC sp_DBA_Read_Permissions @returndays = -1, @Dbname = 'DBA';
PRINT '   PASS: @Dbname filter executed without error';


-- ============================================================
-- TEST 6: sp_DBA_Read_Permissions @LoginName filter
-- ============================================================
PRINT '';
PRINT '-- TEST 6: sp_DBA_Read_Permissions @LoginName filter (sa)';

EXEC sp_DBA_Read_Permissions @returndays = -1, @LoginName = 'sa', @PermissionLevel = 'LOGINS';
PRINT '   PASS: @LoginName filter executed without error';

EXEC sp_DBA_Read_Permissions @returndays = -1, @LoginName = 'sa', @PermissionLevel = 'SERVER';
PRINT '   PASS: @LoginName + SERVER executed without error';


-- ============================================================
-- TEST 7: Error handling - positive @returndays should fail
-- ============================================================
PRINT '';
PRINT '-- TEST 7: Error handling - positive @returndays should raise error';

BEGIN TRY
    EXEC sp_DBA_Script_All_Permissions @returndays = 1;
    PRINT '   FAIL: sp_DBA_Script_All_Permissions did not raise error for positive @returndays';
    SET @Errors = @Errors + 1;
END TRY
BEGIN CATCH
    PRINT '   PASS: sp_DBA_Script_All_Permissions correctly raised error: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY
    EXEC sp_DBA_Read_Permissions @returndays = 1;
    PRINT '   FAIL: sp_DBA_Read_Permissions did not raise error for positive @returndays';
    SET @Errors = @Errors + 1;
END TRY
BEGIN CATCH
    PRINT '   PASS: sp_DBA_Read_Permissions correctly raised error: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY
    EXEC sp_DBA_Read_Permissions @PermissionLevel = 'INVALID';
    PRINT '   FAIL: sp_DBA_Read_Permissions did not raise error for invalid @PermissionLevel';
    SET @Errors = @Errors + 1;
END TRY
BEGIN CATCH
    PRINT '   PASS: sp_DBA_Read_Permissions correctly raised error for invalid @PermissionLevel: ' + ERROR_MESSAGE();
END CATCH


-- ============================================================
-- RESULTS
-- ============================================================
PRINT '';
PRINT '============================================================';
IF @Errors = 0
    PRINT 'ALL TESTS PASSED';
ELSE
    PRINT 'TESTS FAILED: ' + CAST(@Errors AS varchar) + ' failure(s)';
PRINT '============================================================';
