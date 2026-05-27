-- ============================================================
-- Demo Logins
-- Creates two demo logins with varied, realistic permission sets
-- designed to showcase the full range of the permission
-- scripting and reporting framework.
--
-- demo_dba    — Full database administrator profile
--              db_owner + server-level VIEW SERVER STATE
--              + VIEW ANY DEFINITION
--
-- demo_report — Read-only reporting analyst profile
--              db_datareader + schema-level SELECT on Sales
--              and Production, EXECUTE on Sales schema,
--              DENY on sensitive HR data,
--              column-level DENY on Employees.Salary
--
-- Run AFTER: setup/01_create_database.sql
--            Deployment_of_SQL_Scripting_Permissions.sql
-- Used by:   demo/02_demo_automation.sql
-- ============================================================


-- ============================================================
-- STEP 1: SERVER-LEVEL LOGINS
-- ============================================================

USE master;
GO

-- NOTE: Passwords below are for demo purposes only.
-- Do not reuse these credentials in any real environment.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'demo_dba')
    CREATE LOGIN demo_dba
        WITH PASSWORD     = 'P@ssw0rd!DBA2026',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = OFF;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'demo_report')
    CREATE LOGIN demo_report
        WITH PASSWORD     = 'P@ssw0rd!Rprt2026',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = OFF;
GO

-- Server-level permissions for demo_dba
GRANT VIEW SERVER STATE   TO demo_dba;
GRANT VIEW ANY DEFINITION TO demo_dba;
GO

PRINT 'Server logins created.';
GO


-- ============================================================
-- STEP 2: DATABASE USERS
-- ============================================================

USE DBA;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'demo_dba')
    CREATE USER demo_dba    FOR LOGIN demo_dba;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'demo_report')
    CREATE USER demo_report FOR LOGIN demo_report;
GO

PRINT 'Database users created.';
GO


-- ============================================================
-- STEP 3: ROLE MEMBERSHIPS
-- ============================================================

ALTER ROLE db_owner      ADD MEMBER demo_dba;
GO

ALTER ROLE db_datareader ADD MEMBER demo_report;
GO

PRINT 'Role memberships assigned.';
GO


-- ============================================================
-- STEP 4: SCHEMA-LEVEL PERMISSIONS FOR demo_report
-- ============================================================

GRANT SELECT  ON SCHEMA::Sales          TO demo_report;
GRANT SELECT  ON SCHEMA::Production     TO demo_report;
GRANT EXECUTE ON SCHEMA::Sales          TO demo_report;
DENY  SELECT  ON SCHEMA::HumanResources TO demo_report;

PRINT 'Schema-level permissions applied to demo_report.';
GO


-- ============================================================
-- STEP 5: OBJECT-LEVEL PERMISSIONS FOR demo_report
-- Grant non-sensitive columns on Employees; deny Salary column
-- ============================================================

GRANT SELECT ON HumanResources.Employees
    (EmployeeID, LoginName, FirstName, LastName, JobTitle, Department, HireDate)
    TO demo_report;

DENY  SELECT ON HumanResources.Employees (Salary) TO demo_report;

PRINT 'Object-level permissions applied to demo_report.';
GO


-- ============================================================
-- STEP 6: VERIFICATION
-- ============================================================

PRINT '';
PRINT '-- Role memberships --';
SELECT
    u.name  AS [User],
    r.name  AS [Role]
FROM sys.database_role_members m
INNER JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
INNER JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
WHERE u.name IN ('demo_dba','demo_report')
ORDER BY u.name, r.name;

PRINT '';
PRINT '-- Explicit permissions --';
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
GO
