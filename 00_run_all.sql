-- ============================================================
-- SqlServerScriptPermissions — Master Run-All Script
--
-- Runs the full stack in order:
--   1. Create the DBA database with schemas, tables, and data
--   2. Deploy the permission scripting framework
--      (tables, procs, SQL Agent job)
--   3. Create demo logins with varied permission sets
--   4. Run the full-cycle automation
--      (create → collect → inspect → drop → verify →
--       restore → verify → summary)
--
-- REQUIREMENTS
-- ─────────────────────────────────────────────────────────────
-- • The :r include directives below are SQLCMD syntax.
--   They are NOT supported by the VS Code mssql extension.
--
--   Run this file via one of:
--     a) SSMS with SQLCMD Mode enabled
--        (Query menu → SQLCMD Mode, or Alt+Q, M)
--     b) Terminal:  ./run_all.sh
--        (requires sqlcmd — install via: brew install sqlcmd)
--
--   Running in VS Code will report success but execute nothing.
--
-- • Run as sysadmin (creates the database and logins).
--
-- • Tested against SQL Server 2022 and 2025 (Docker).
--   Minimum supported version: 2016+ (requires STRING_AGG).
-- ============================================================

:r setup\01_create_database.sql
:r Deployment_of_SQL_Scripting_Permissions.sql
:r demo\01_demo_logins.sql
:r demo\02_demo_automation.sql
