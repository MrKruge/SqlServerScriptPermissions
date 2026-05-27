#!/usr/bin/env bash
# ============================================================
# SqlServerScriptPermissions — run_all.sh
#
# Runs all scripts in order against the local Docker instance.
# Requires sqlcmd to be accessible (either installed locally
# or executed inside the container via docker exec).
#
# Usage:
#   ./run_all.sh                          # prompts for password
#   SA_PASSWORD=YourPw ./run_all.sh       # non-interactive
#   QUIET=1 ./run_all.sh                  # suppress SQL output, show step headers only
#   VERBOSE=1 ./run_all.sh               # show shell debug trace (set -x)
# ============================================================

set -euo pipefail

# ── Output modes ─────────────────────────────────────────────
# QUIET=1   — suppress all sqlcmd output; only shell step headers are printed
# VERBOSE=1 — enable bash set -x trace for full shell debug output
QUIET="${QUIET:-0}"
VERBOSE="${VERBOSE:-0}"

[[ "$VERBOSE" == "1" ]] && set -x

SERVER="${SQL_SERVER:-localhost,1433}"
USER="${SQL_USER:-sa}"

if [[ -z "${SA_PASSWORD:-}" ]]; then
    read -rsp "SQL Server password for ${USER}@${SERVER}: " SA_PASSWORD
    echo
fi

SQLCMD_ARGS=(-S "$SERVER" -U "$USER" -P "$SA_PASSWORD" -C -b)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_script() {
    local label="$1"
    local path="$2"
    echo ""
    echo ">>> ${label}"
    echo "    ${path}"
    if [[ "$QUIET" == "1" ]]; then
        sqlcmd "${SQLCMD_ARGS[@]}" -i "${path}" > /dev/null
    else
        sqlcmd "${SQLCMD_ARGS[@]}" -i "${path}"
    fi
    echo "    Done."
}

echo "============================================================"
echo " SqlServerScriptPermissions — full stack deployment"
echo " Server : ${SERVER}"
echo " User   : ${USER}"
echo "============================================================"

run_script "STEP 1/4  Create database, schemas, tables, data" \
    "${SCRIPT_DIR}/setup/01_create_database.sql"

run_script "STEP 2/4  Deploy permission scripting framework" \
    "${SCRIPT_DIR}/Deployment_of_SQL_Scripting_Permissions.sql"

run_script "STEP 3/4  Create demo logins" \
    "${SCRIPT_DIR}/demo/01_demo_logins.sql"

run_script "STEP 4/4  Run full-cycle automation" \
    "${SCRIPT_DIR}/demo/02_demo_automation.sql"

echo ""
echo "============================================================"
echo " All steps completed."
echo "============================================================"
