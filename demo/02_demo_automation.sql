-- ============================================================
-- Permission Scripting Full-Cycle Automation
--
-- Demonstrates the complete workflow end to end:
--
--   PHASE 1 — CREATE   : Create demo_dba and demo_report
--                        with their full permission sets
--   PHASE 2 — COLLECT  : Snapshot current permissions into
--                        the DBA collection tables
--   PHASE 3 — INSPECT  : Show what was captured for both logins
--   PHASE 4 — DROP     : Remove both users and logins entirely
--   PHASE 5 — VERIFY   : Assert they are gone
--   PHASE 6 — RESTORE  : Re-apply everything from the snapshot
--                        using the stored T-SQL scripts
--   PHASE 7 — VERIFY   : Assert users, roles, and permissions
--                        are all back exactly as before
--   PHASE 8 — SUMMARY  : Print pass/fail counts
--
-- Prerequisites:
--   setup/01_create_database.sql must have been run
--   Deployment_of_SQL_Scripting_Permissions.sql must have been run
--   (sp_DBA_Get_All_Permissions, tbl_DBA_* tables must exist)
--
-- Run as: sysadmin or securityadmin + db_owner on DBA
-- ============================================================

SET NOCOUNT ON;

DECLARE @Errors       int      = 0;
DECLARE @RowCount     int;
DECLARE @SnapshotTime datetime;
DECLARE @sql          nvarchar(max);

PRINT '============================================================';
PRINT 'Permission Scripting Full-Cycle Automation';
PRINT '============================================================';


-- ============================================================
-- PHASE 1: CREATE demo_dba and demo_report
-- ============================================================
PRINT '';
PRINT '>>> PHASE 1: Creating demo logins and permissions...';

USE master;

-- NOTE: Passwords below are for demo purposes only.
-- Do not reuse these credentials in any real environment.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'demo_dba')
    EXEC('CREATE LOGIN demo_dba
              WITH PASSWORD       = ''P@ssw0rd!DBA2026'',
                   CHECK_POLICY   = ON,
                   CHECK_EXPIRATION = OFF');

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'demo_report')
    EXEC('CREATE LOGIN demo_report
              WITH PASSWORD       = ''P@ssw0rd!Rprt2026'',
                   CHECK_POLICY   = ON,
                   CHECK_EXPIRATION = OFF');

GRANT VIEW SERVER STATE   TO demo_dba;
GRANT VIEW ANY DEFINITION TO demo_dba;

USE DBA;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'demo_dba')
    CREATE USER demo_dba    FOR LOGIN demo_dba;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'demo_report')
    CREATE USER demo_report FOR LOGIN demo_report;

ALTER ROLE db_owner      ADD MEMBER demo_dba;
ALTER ROLE db_datareader ADD MEMBER demo_report;

GRANT SELECT  ON SCHEMA::Sales          TO demo_report;
GRANT SELECT  ON SCHEMA::Production     TO demo_report;
GRANT EXECUTE ON SCHEMA::Sales          TO demo_report;
DENY  SELECT  ON SCHEMA::HumanResources TO demo_report;

GRANT SELECT ON HumanResources.Employees
    (EmployeeID, LoginName, FirstName, LastName, JobTitle, Department, HireDate)
    TO demo_report;
DENY  SELECT ON HumanResources.Employees (Salary) TO demo_report;

PRINT '   demo_dba:    login created, db_owner, VIEW SERVER STATE, VIEW ANY DEFINITION';
PRINT '   demo_report: login created, db_datareader, schema SELECT/EXECUTE grants, HR DENY';
PRINT '   PHASE 1 complete.';


-- ============================================================
-- PHASE 2: COLLECT — snapshot all permissions into tables
-- ============================================================
PRINT '';
PRINT '>>> PHASE 2: Collecting permissions snapshot...';

USE DBA;

SET @SnapshotTime = GETDATE();
EXEC dbo.sp_DBA_Get_All_Permissions;

PRINT '   Snapshot taken at: ' + CONVERT(varchar, @SnapshotTime, 120);
PRINT '   PHASE 2 complete.';


-- ============================================================
-- PHASE 3: INSPECT — show captured rows for demo logins
-- ============================================================
PRINT '';
PRINT '>>> PHASE 3: Captured permissions for demo_dba and demo_report';

PRINT '';
PRINT '-- Human-readable view (sp_DBA_Read_Permissions) --';
EXEC dbo.sp_DBA_Read_Permissions @returndays = -1, @Dbname = 'DBA';

PRINT '';
PRINT '-- T-SQL restore scripts (sp_DBA_Script_All_Permissions) --';
EXEC dbo.sp_DBA_Script_All_Permissions @returndays = -1, @Dbname = 'DBA';

PRINT '   PHASE 3 complete.';


-- ============================================================
-- PHASE 4: DROP — remove both users and logins entirely
-- ============================================================
PRINT '';
PRINT '>>> PHASE 4: Dropping demo_dba and demo_report...';

USE DBA;

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'demo_dba')
BEGIN
    ALTER ROLE db_owner DROP MEMBER demo_dba;
    DROP USER demo_dba;
    PRINT '   demo_dba: removed from db_owner, user dropped';
END

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'demo_report')
BEGIN
    ALTER ROLE db_datareader DROP MEMBER demo_report;
    IF EXISTS (SELECT 1 FROM sys.database_permissions p
               INNER JOIN sys.database_principals u ON u.principal_id = p.grantee_principal_id
               WHERE u.name = 'demo_report')
    BEGIN
        REVOKE SELECT  ON SCHEMA::Sales          FROM demo_report CASCADE;
        REVOKE SELECT  ON SCHEMA::Production     FROM demo_report CASCADE;
        REVOKE EXECUTE ON SCHEMA::Sales          FROM demo_report CASCADE;
        REVOKE SELECT  ON SCHEMA::HumanResources FROM demo_report CASCADE;
        REVOKE SELECT  ON HumanResources.Employees
            (EmployeeID, LoginName, FirstName, LastName, JobTitle, Department, HireDate)
            FROM demo_report CASCADE;
        REVOKE SELECT  ON HumanResources.Employees (Salary) FROM demo_report CASCADE;
    END
    DROP USER demo_report;
    PRINT '   demo_report: permissions revoked, user dropped';
END

USE master;

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'demo_dba')
BEGIN
    REVOKE VIEW SERVER STATE   FROM demo_dba;
    REVOKE VIEW ANY DEFINITION FROM demo_dba;
    DROP LOGIN demo_dba;
    PRINT '   demo_dba login dropped';
END

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'demo_report')
BEGIN
    DROP LOGIN demo_report;
    PRINT '   demo_report login dropped';
END

PRINT '   PHASE 4 complete.';


-- ============================================================
-- PHASE 5: VERIFY — assert both logins and users are gone
-- ============================================================
PRINT '';
PRINT '>>> PHASE 5: Verifying demo logins and users are gone...';

USE master;

SELECT @RowCount = COUNT(*) FROM sys.server_principals
WHERE name IN ('demo_dba','demo_report');
IF @RowCount > 0
BEGIN
    PRINT '   FAIL: ' + CAST(@RowCount AS varchar) + ' server login(s) still exist after drop';
    SET @Errors = @Errors + 1;
END
ELSE PRINT '   PASS: Server logins gone';

USE DBA;

SELECT @RowCount = COUNT(*) FROM sys.database_principals
WHERE name IN ('demo_dba','demo_report');
IF @RowCount > 0
BEGIN
    PRINT '   FAIL: ' + CAST(@RowCount AS varchar) + ' database user(s) still exist after drop';
    SET @Errors = @Errors + 1;
END
ELSE PRINT '   PASS: Database users gone';

PRINT '   PHASE 5 complete.';


-- ============================================================
-- PHASE 6: RESTORE — re-apply everything from the snapshot
-- Order: login -> user -> role -> db-level -> schema -> object
-- ============================================================
PRINT '';
PRINT '>>> PHASE 6: Restoring from snapshot (taken at ' + CONVERT(varchar,@SnapshotTime,120) + ')...';

USE master;

-- 6a. Re-create server logins (passwords are known for demo logins)
PRINT '   6a. Re-creating server logins...';

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'demo_dba')
    EXEC('CREATE LOGIN demo_dba
              WITH PASSWORD       = ''P@ssw0rd!DBA2026'',
                   CHECK_POLICY   = ON,
                   CHECK_EXPIRATION = OFF');

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'demo_report')
    EXEC('CREATE LOGIN demo_report
              WITH PASSWORD       = ''P@ssw0rd!Rprt2026'',
                   CHECK_POLICY   = ON,
                   CHECK_EXPIRATION = OFF');

GRANT VIEW SERVER STATE   TO demo_dba;
GRANT VIEW ANY DEFINITION TO demo_dba;
PRINT '   6a. Server logins and server-level grants restored.';

USE DBA;

-- 6b. Re-create database users
PRINT '   6b. Re-creating database users...';
DECLARE @stmt nvarchar(max);
DECLARE user_cur CURSOR FAST_FORWARD FOR
    SELECT [User_per_db]
    FROM dbo.tbl_DBA_Users_per_db
    WHERE DATE >= @SnapshotTime
      AND ([User_per_db] LIKE '%demo_dba%' OR [User_per_db] LIKE '%demo_report%');

OPEN user_cur;
FETCH NEXT FROM user_cur INTO @stmt;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '      Executing: ' + @stmt;
    EXEC (@stmt);
    FETCH NEXT FROM user_cur INTO @stmt;
END
CLOSE user_cur;
DEALLOCATE user_cur;
PRINT '   6b. Users restored.';

-- 6c. Re-apply role memberships
PRINT '   6c. Re-applying role memberships...';
DECLARE role_cur CURSOR FAST_FORWARD FOR
    SELECT [role_level_Permissions]
    FROM dbo.tbl_DBA_role_level_permissions
    WHERE DATE >= @SnapshotTime
      AND ([role_level_Permissions] LIKE '%demo_dba%' OR [role_level_Permissions] LIKE '%demo_report%');

OPEN role_cur;
FETCH NEXT FROM role_cur INTO @stmt;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '      Executing: ' + @stmt;
    EXEC (@stmt);
    FETCH NEXT FROM role_cur INTO @stmt;
END
CLOSE role_cur;
DEALLOCATE role_cur;
PRINT '   6c. Role memberships restored.';

-- 6d. Re-apply database-level permissions
PRINT '   6d. Re-applying database-level permissions...';
DECLARE dblvl_cur CURSOR FAST_FORWARD FOR
    SELECT [User_level_Permissions]
    FROM dbo.tbl_DBA_User_level_permissions
    WHERE DATE >= @SnapshotTime
      AND ([User_level_Permissions] LIKE '%demo_dba%' OR [User_level_Permissions] LIKE '%demo_report%');

OPEN dblvl_cur;
FETCH NEXT FROM dblvl_cur INTO @stmt;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '      Executing: ' + @stmt;
    EXEC (@stmt);
    FETCH NEXT FROM dblvl_cur INTO @stmt;
END
CLOSE dblvl_cur;
DEALLOCATE dblvl_cur;
PRINT '   6d. Database-level permissions restored.';

-- 6e. Re-apply object-level permissions
PRINT '   6e. Re-applying object-level permissions...';
DECLARE obj_cur CURSOR FAST_FORWARD FOR
    SELECT [Object_level_permission]
    FROM dbo.tbl_DBA_Object_level_permissions
    WHERE DATE >= @SnapshotTime
      AND ([Object_level_permission] LIKE '%demo_dba%' OR [Object_level_permission] LIKE '%demo_report%')
      AND [Object_level_permission] NOT LIKE '%ON [sys].%';   -- skip internal system-schema entries

OPEN obj_cur;
FETCH NEXT FROM obj_cur INTO @stmt;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '      Executing: ' + @stmt;
    BEGIN TRY
        EXEC (@stmt);
    END TRY
    BEGIN CATCH
        PRINT '      WARNING: skipped (error ' + CAST(ERROR_NUMBER() AS varchar) + '): ' + ERROR_MESSAGE();
    END CATCH
    FETCH NEXT FROM obj_cur INTO @stmt;
END
CLOSE obj_cur;
DEALLOCATE obj_cur;
PRINT '   6e. Object-level permissions restored.';

PRINT '   PHASE 6 complete.';


-- ============================================================
-- PHASE 7: VERIFY — assert users and permissions are restored
-- ============================================================
PRINT '';
PRINT '>>> PHASE 7: Verifying restoration...';

USE master;

SELECT @RowCount = COUNT(*) FROM sys.server_principals
WHERE name IN ('demo_dba','demo_report');
IF @RowCount <> 2
BEGIN
    PRINT '   FAIL: Expected 2 server logins, found ' + CAST(@RowCount AS varchar);
    SET @Errors = @Errors + 1;
END
ELSE PRINT '   PASS: Both server logins restored (' + CAST(@RowCount AS varchar) + ')';

USE DBA;

SELECT @RowCount = COUNT(*) FROM sys.database_principals
WHERE name IN ('demo_dba','demo_report');
IF @RowCount <> 2
BEGIN
    PRINT '   FAIL: Expected 2 database users, found ' + CAST(@RowCount AS varchar);
    SET @Errors = @Errors + 1;
END
ELSE PRINT '   PASS: Both database users restored (' + CAST(@RowCount AS varchar) + ')';

SELECT @RowCount = COUNT(*)
FROM sys.database_role_members m
INNER JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
INNER JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
WHERE u.name = 'demo_dba' AND r.name = 'db_owner';
IF @RowCount = 0
BEGIN
    PRINT '   FAIL: demo_dba not in db_owner role';
    SET @Errors = @Errors + 1;
END
ELSE PRINT '   PASS: demo_dba in db_owner';

SELECT @RowCount = COUNT(*)
FROM sys.database_role_members m
INNER JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
INNER JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
WHERE u.name = 'demo_report' AND r.name = 'db_datareader';
IF @RowCount = 0
BEGIN
    PRINT '   FAIL: demo_report not in db_datareader role';
    SET @Errors = @Errors + 1;
END
ELSE PRINT '   PASS: demo_report in db_datareader';

SELECT @RowCount = COUNT(*)
FROM sys.database_permissions p
INNER JOIN sys.schemas s ON s.schema_id = p.major_id
INNER JOIN sys.database_principals u ON u.principal_id = p.grantee_principal_id
WHERE u.name = 'demo_report'
  AND s.name = 'Sales'
  AND p.permission_name = 'SELECT'
  AND p.state_desc = 'GRANT';
IF @RowCount = 0
BEGIN
    PRINT '   FAIL: demo_report missing SELECT GRANT on Sales schema';
    SET @Errors = @Errors + 1;
END
ELSE PRINT '   PASS: demo_report has SELECT on Sales schema';

SELECT @RowCount = COUNT(*)
FROM sys.database_permissions p
INNER JOIN sys.schemas s ON s.schema_id = p.major_id
INNER JOIN sys.database_principals u ON u.principal_id = p.grantee_principal_id
WHERE u.name = 'demo_report'
  AND s.name = 'HumanResources'
  AND p.permission_name = 'SELECT'
  AND p.state_desc = 'DENY';
IF @RowCount = 0
BEGIN
    PRINT '   FAIL: demo_report missing DENY SELECT on HumanResources schema';
    SET @Errors = @Errors + 1;
END
ELSE PRINT '   PASS: demo_report has DENY SELECT on HumanResources schema';

SELECT @RowCount = COUNT(*)
FROM sys.database_permissions p
INNER JOIN sys.objects o ON o.object_id = p.major_id
INNER JOIN sys.columns c ON c.object_id = p.major_id AND c.column_id = p.minor_id
INNER JOIN sys.database_principals u ON u.principal_id = p.grantee_principal_id
WHERE u.name = 'demo_report'
  AND o.name = 'Employees'
  AND c.name = 'Salary'
  AND p.permission_name = 'SELECT'
  AND p.state_desc = 'DENY';
IF @RowCount = 0
BEGIN
    PRINT '   FAIL: demo_report missing column-level DENY on Employees.Salary';
    SET @Errors = @Errors + 1;
END
ELSE PRINT '   PASS: demo_report has column-level DENY on Employees.Salary';

PRINT '   PHASE 7 complete.';


-- ============================================================
-- PHASE 8: FINAL SUMMARY
-- ============================================================
PRINT '';
PRINT '>>> PHASE 8: Final state of restored users';

SELECT
    u.name                                              AS [User],
    STRING_AGG(r.name, ', ') WITHIN GROUP (ORDER BY r.name) AS [Roles]
FROM sys.database_principals u
LEFT JOIN sys.database_role_members m  ON m.member_principal_id = u.principal_id
LEFT JOIN sys.database_principals r    ON r.principal_id = m.role_principal_id
WHERE u.name IN ('demo_dba','demo_report')
GROUP BY u.name
ORDER BY u.name;

SELECT
    u.name                                          AS [User],
    CASE p.class
        WHEN 0 THEN 'DATABASE'
        WHEN 3 THEN 'SCHEMA: ' + SCHEMA_NAME(p.major_id)
        WHEN 1 THEN 'OBJECT: ' + SCHEMA_NAME(o.schema_id) + '.' + o.name
                     + ISNULL(' (' + c.name + ')','')
        ELSE 'OTHER'
    END                                             AS [Scope],
    p.permission_name                               AS [Permission],
    p.state_desc                                    AS [State]
FROM sys.database_permissions p
INNER JOIN sys.database_principals u ON u.principal_id = p.grantee_principal_id
LEFT  JOIN sys.objects o ON o.object_id = p.major_id
LEFT  JOIN sys.columns c ON c.object_id = p.major_id AND c.column_id = p.minor_id
WHERE u.name IN ('demo_dba','demo_report')
ORDER BY u.name, [Scope], p.permission_name;

PRINT '';
PRINT '============================================================';
IF @Errors = 0
    PRINT 'ALL PHASES PASSED — full cycle create / collect / drop / restore verified';
ELSE
    PRINT 'AUTOMATION FAILED: ' + CAST(@Errors AS varchar) + ' check(s) did not pass';
PRINT '============================================================';
