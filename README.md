# SqlServerScriptPermissions

Automated scripting and auditing of SQL Server permissions for on-premises instances.

---

## What is it?

This solution automatically scripts out all SQL Server permissions across every database on an instance and stores them as re-runnable T-SQL statements. The results are held in a set of DBA tables and are captured daily by a SQL Server Agent Job.

The goal is full auditability and traceability — at any point you can query what permissions existed on a given day, for a given database, or for a specific login. You can also use the output to recreate permissions from scratch on another instance.

The script was built and tested against StackOverflow2010 from Brent Ozar as a reference, but runs on any standard on-premises SQL Server instance.

---

## What gets scripted?

| Level | Description |
|---|---|
| Logins | `CREATE LOGIN` statements for all SQL and Windows logins |
| Server Roles | `sp_addsrvrolemember` for all server role memberships |
| Server Permissions | `GRANT/DENY` at the server principal level |
| Role Level (per DB) | `sp_AddRoleMember` for all database role memberships |
| Users per DB | `CREATE USER ... FOR LOGIN` per database |
| User Level (per DB) | `GRANT/DENY` at the database user level |
| Object Level (per DB) | `GRANT/DENY` on specific objects (tables, views, procs, columns) |

---

## What gets installed?

### Tables (stored in your chosen database, default `DBA`)

| Table | Content |
|---|---|
| `tbl_DBA_logins` | Login creation scripts with date stamp |
| `tbl_DBA_server_roles` | Server role membership scripts |
| `tbl_DBA_Server_level_permissions` | Server-level grant/deny scripts |
| `tbl_DBA_role_level_permissions` | Database role membership scripts per DB |
| `tbl_DBA_Users_per_db` | User creation scripts per DB |
| `tbl_DBA_User_level_permissions` | Database user permission scripts per DB |
| `tbl_DBA_Object_level_permissions` | Object-level permission scripts per DB |

### Stored Procedures

| Procedure | Purpose |
|---|---|
| `sp_DBA_Get_All_Permissions` | **Collection** — scrapes all permissions across all DBs and inserts into the tables. Called by the Agent Job. |
| `sp_DBA_Script_All_Permissions` | **Read** — original read procedure. Supports `@returndays` and `@Dbname` filters. |
| `sp_DBA_Read_Permissions` | **Read (enhanced)** — full filtering by time window, database, login name, and permission level. See below. |

### SQL Server Agent Job

A daily job `DBA - ScriptOutPermissions` is created that executes `sp_DBA_Get_All_Permissions` and writes the output to `E:\SQLDATA\BACKUP\All_SQL_Permissions.sql`. Adjust the output path to match your environment before deploying.

---

## How to install?

Copy the entire script and paste it into SSMS. Hit **F5** or click **Execute**. That is it.

The script first cleans up any existing objects (tables, procs, job) so it is safe to re-run. All objects are recreated from scratch on each deployment.

If you do not have or want a `DBA` database, open the script in a text editor and find-replace all occurrences of `DBA` with your chosen database name before running.

> **Note:** The SQL Server Agent Job output path is hardcoded to `E:\SQLDATA\BACKUP\`. Update `@output_file_name` in the job step before running if your path differs.

---

## How to use it?

### Run the collection manually (outside of the Agent Job schedule)

```sql
USE [DBA]
GO

EXEC [dbo].[sp_DBA_Get_All_Permissions]
```

---

### `sp_DBA_Read_Permissions` — Enhanced read procedure

This is the main procedure for querying stored permissions. All parameters are optional and can be combined freely.

#### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `@returndays` | `int` | `NULL` | `NULL` = All Time, `-1` = Last Day, `-7` = Last Week. Must be negative or NULL. |
| `@Dbname` | `nvarchar(max)` | `NULL` | `NULL` = All Databases. Does not affect server-level results. |
| `@LoginName` | `nvarchar(256)` | `NULL` | `NULL` = All Logins/Users. Filters all selected levels for a specific login or user name. |
| `@PermissionLevel` | `nvarchar(50)` | `'ALL'` | `ALL`, `LOGINS`, `SERVER`, `DATABASE`, `OBJECT` |

#### Permission level options

| Value | What it returns |
|---|---|
| `ALL` | Everything — logins, server roles, server perms, role memberships, user perms, object perms |
| `LOGINS` | Login creation scripts only |
| `SERVER` | Server role memberships + server-level grant/deny scripts |
| `DATABASE` | Role memberships, user creation, and user-level grants per DB |
| `OBJECT` | Object-level grants per DB |

---

#### Examples

**All permissions, all time (full audit dump)**
```sql
USE [DBA]
GO

EXEC [dbo].[sp_DBA_Read_Permissions]
```

**Last day only, all permissions**
```sql
USE [DBA]
GO

EXEC [dbo].[sp_DBA_Read_Permissions]
    @returndays = -1
```

**Last week only, all permissions**
```sql
USE [DBA]
GO

EXEC [dbo].[sp_DBA_Read_Permissions]
    @returndays = -7
```

**All time, specific database only**
```sql
USE [DBA]
GO

EXEC [dbo].[sp_DBA_Read_Permissions]
    @Dbname = 'master'
```

**Last day, specific database**
```sql
USE [DBA]
GO

EXEC [dbo].[sp_DBA_Read_Permissions]
    @returndays = -1,
    @Dbname = 'master'
```

**All permissions for a specific login — full login-level audit across all levels**
```sql
USE [DBA]
GO

EXEC [dbo].[sp_DBA_Read_Permissions]
    @LoginName = 'mylogin'
```

**Server-level only for a specific login (login scripting)**
```sql
USE [DBA]
GO

EXEC [dbo].[sp_DBA_Read_Permissions]
    @LoginName = 'mylogin',
    @PermissionLevel = 'SERVER'
```

**Login creation scripts only — useful for DR or migration**
```sql
USE [DBA]
GO

EXEC [dbo].[sp_DBA_Read_Permissions]
    @PermissionLevel = 'LOGINS'
```

**Object-level permissions for a specific DB, last week**
```sql
USE [DBA]
GO

EXEC [dbo].[sp_DBA_Read_Permissions]
    @returndays = -7,
    @Dbname = 'AdventureWorks',
    @PermissionLevel = 'OBJECT'
```

**Check what a specific user had access to in a specific DB, all time**
```sql
USE [DBA]
GO

EXEC [dbo].[sp_DBA_Read_Permissions]
    @Dbname = 'AdventureWorks',
    @LoginName = 'mylogin',
    @PermissionLevel = 'DATABASE'
```

---

### `sp_DBA_Script_All_Permissions` — Original read procedure

The original read procedure is kept for backwards compatibility. It supports `@returndays` and `@Dbname` only.

```sql
USE [DBA]
GO

-- All history, all DBs
EXEC [dbo].[sp_DBA_Script_All_Permissions]

-- Last day, all DBs
EXEC [dbo].[sp_DBA_Script_All_Permissions]
    @returndays = -1

-- All history, master only
EXEC [dbo].[sp_DBA_Script_All_Permissions]
    @Dbname = 'master'

-- Last day, master only
EXEC [dbo].[sp_DBA_Script_All_Permissions]
    @returndays = -1,
    @Dbname = 'master'
```

---

## Notes

- All stored data is cumulative. The Agent Job appends on every run — it does not purge old rows. If you want to control growth, add a purge step to the Agent Job or a scheduled DELETE against the tables with a retention window of your choice.
- The `@LoginName` filter uses a `LIKE` match against the scripted SQL text in each table. It will match any occurrence of the name in the output, including role names that contain the string. Be specific with the name to avoid unintended matches.
- Server-level results (logins, server roles, server permissions) are instance-wide and are not affected by the `@Dbname` parameter.
- The output of each query is a re-runnable T-SQL statement that can be executed directly on another instance to recreate the permission.
