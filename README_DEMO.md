# SqlServerScriptPermissions — Demo, Tests & Setup

This document covers the **demo environment**, **automated test suite**, and the **quick-start setup scripts** that ship alongside the main deployment script.

For the core framework (stored procedures, collection tables, Agent Job, query examples) see [README.md](README.md).

---

## Folder structure

```
SqlServerScriptPermissions/
├── 00_run_all.sql                       Master script — runs everything in order
├── Deployment_of_SQL_Scripting_Permissions.sql
├── setup/
│   └── 01_create_database.sql           Creates the DBA database, schemas, tables, and sample data
├── demo/
│   ├── 01_demo_logins.sql               Creates two demo logins with contrasting permission sets
│   └── 02_demo_automation.sql           Full-cycle automation (8 phases)
└── tests/
    └── test_permissions.sql             Automated test suite (7 tests)
```

---

## Quick start — run everything at once

Open `00_run_all.sql` in SSMS, enable **Query → SQLCMD Mode** (or press `Alt+Q, M`), then execute.

The script chains the four files below in order using `:r` directives:

| Order | File | What it does |
|---|---|---|
| 1 | `setup\01_create_database.sql` | Creates the `DBA` database from scratch |
| 2 | `Deployment_of_SQL_Scripting_Permissions.sql` | Deploys tables, procs, and Agent Job |
| 3 | `demo\01_demo_logins.sql` | Creates `demo_dba` and `demo_report` |
| 4 | `demo\02_demo_automation.sql` | Runs the 8-phase full-cycle test |

> **Note:** SQLCMD Mode is required because of the `:r` include directives. If SSMS shows a syntax error on the first `:r` line, SQLCMD Mode is not active.

---

## Quick start — command line / Docker (`run_all.sh`)

If you are running against a local Docker instance or prefer the terminal over SSMS, use `run_all.sh` instead. It runs the same four steps in order via `sqlcmd`.

**Requirements:** `sqlcmd` installed locally (e.g. via `brew install sqlcmd` on macOS).

```bash
# Interactive — prompts for password
./run_all.sh

# Non-interactive — password via environment variable
SA_PASSWORD='YourPassword' ./run_all.sh
```

You can override the server and user if needed:

```bash
SQL_SERVER='myserver,1433' SQL_USER='sa' SA_PASSWORD='YourPassword' ./run_all.sh
```

| Variable | Default | Description |
|---|---|---|
| `SQL_SERVER` | `localhost,1433` | Target server and port |
| `SQL_USER` | `sa` | Login name |
| `SA_PASSWORD` | *(prompted)* | Password — set via env var for non-interactive use |
| `QUIET` | `0` | Set to `1` to suppress all SQL output — only step headers are printed |
| `VERBOSE` | `0` | Set to `1` to enable `set -x` bash trace for full shell debug output |

The script exits immediately on any error (`set -euo pipefail`). If a step fails, fix the issue and re-run — the deployment script is safe to re-run as it drops and recreates all objects.

---

## Setup — `setup/01_create_database.sql`

Creates a fresh `DBA` database with an Adventure Works-style schema and sample data. Existing database is dropped and recreated.

### Schemas

| Schema | Purpose |
|---|---|
| `Sales` | Customers, orders, and order line items |
| `Production` | Product catalogue |
| `HumanResources` | Employees, including the sensitive `Salary` column |

### Tables

| Table | Rows |
|---|---|
| `Production.Products` | 10 products across Bikes, Accessories, Clothing, Components |
| `Sales.Customers` | 10 customers (USA, ZAF, NLD) |
| `Sales.Orders` | 8 orders at various statuses |
| `Sales.OrderItems` | 13 line items |
| `HumanResources.Employees` | 6 employees with salaries and manager hierarchy |

---

## Demo logins — `demo/01_demo_logins.sql`

Creates two logins with very different permission profiles so that the scripting framework has interesting data to capture and restore.

### `demo_dba`

| Layer | Permission |
|---|---|
| Server | `VIEW SERVER STATE`, `VIEW ANY DEFINITION` |
| Database role | `db_owner` |

### `demo_report`

| Layer | Permission |
|---|---|
| Database role | `db_datareader` |
| Schema `Sales` | `GRANT SELECT`, `GRANT EXECUTE` |
| Schema `Production` | `GRANT SELECT` |
| Schema `HumanResources` | `DENY SELECT` |
| Object `Employees` (columns) | `GRANT SELECT` on `EmployeeID`, `LoginName`, `FirstName`, `LastName`, `JobTitle`, `Department`, `HireDate` |
| Object `Employees` (column) | `DENY SELECT` on `Salary` |

This combination exercises every level the framework collects: server, role, schema, and column-level.

---

## Full-cycle automation — `demo/02_demo_automation.sql`

Runs the complete workflow as a single self-verifying script. Each phase prints `PASS` / `FAIL` and the final summary reports the total error count.

| Phase | Action |
|---|---|
| 1 — CREATE | Creates `demo_dba` and `demo_report` with all permissions from the table above |
| 2 — COLLECT | Calls `sp_DBA_Get_All_Permissions` to snapshot the current state into the collection tables |
| 3 — INSPECT | Queries the snapshot using both `sp_DBA_Read_Permissions` (human-readable) and `sp_DBA_Script_All_Permissions` (T-SQL scripts) |
| 4 — DROP | Removes both users and logins entirely |
| 5 — VERIFY | Asserts that server logins and database users no longer exist |
| 6 — RESTORE | Re-applies everything using the T-SQL scripts stored in the collection tables |
| 7 — VERIFY | Asserts that logins, users, role memberships, schema grants, and column-level DENY are all restored correctly |
| 8 — SUMMARY | Prints the final role memberships and explicit permissions for both users, then prints overall pass/fail |

### What Phase 6 restores — and from which table

| Step | Table used | What it restores |
|---|---|---|
| 6a | Direct re-create | Server logins (passwords are known for demo logins) |
| 6b | `tbl_DBA_Users_per_db` | `CREATE USER ... FOR LOGIN` |
| 6c | `tbl_DBA_role_level_permissions` | `ALTER ROLE ... ADD MEMBER` |
| 6d | `tbl_DBA_User_level_permissions` | Database-level `GRANT / DENY` |
| 6e | `tbl_DBA_Object_level_permissions` | Object and column-level `GRANT / DENY` |

---

## Automated tests — `tests/test_permissions.sql`

A standalone test script that validates the deployed framework without depending on the demo logins. Run it after deploying `Deployment_of_SQL_Scripting_Permissions.sql`.

| Test | What it checks |
|---|---|
| 1 | All 6 collection tables are populated after `sp_DBA_Get_All_Permissions` |
| 2 | `sp_DBA_Script_All_Permissions` output contains T-SQL syntax (`CREATE LOGIN`, `sp_addsrvrolemember`) |
| 3 | `sp_DBA_Read_Permissions` output follows the human-readable `LOGIN:` format and does **not** contain `CREATE LOGIN` |
| 4 | All `@PermissionLevel` values (`LOGINS`, `SERVER`, `DATABASE`, `OBJECT`) execute without error |
| 5 | `@Dbname = 'DBA'` filter returns fewer or equal rows compared to unfiltered |
| 6 | `@LoginName = 'sa'` filter executes without error |
| 7 | Positive `@returndays` raises an error; invalid `@PermissionLevel` raises an error |

Each test prints `PASS` or `FAIL` and the final line reports the total number of failures.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| SQL Server version | 2019+ recommended; 2016+ minimum (uses `STRING_AGG`) |
| Permissions | `sysadmin` or `securityadmin` + `db_owner` on `DBA` |
| SQL Server Agent | Must be running for the scheduled collection job to fire |
| SSMS SQLCMD Mode | Required only for `00_run_all.sql` |

---

## Running against the local Docker instance

The project was developed against a SQL Server 2022 Docker container named `sql_server_container`. To enable the SQL Server Agent on that container:

```bash
docker exec -u root sql_server_container \
    /opt/mssql/bin/mssql-conf set sqlagent.enabled true \
    && docker restart sql_server_container
```

Connect in SSMS using `localhost,1433` with SQL authentication.
