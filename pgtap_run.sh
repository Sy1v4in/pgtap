#!/usr/bin/env sh

# ANSI colors
COLOR_RESET="\033[0m"
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_BLUE="\033[1;34m"

# Default settings
export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
export PGDATABASE="${PGDATABASE:-postgres}"
TESTS='t/*.sql'

log_run() {
  log_message "${1}"
  shift

  QUIET="${QUIET:-0}"

  if test "${QUIET}" -eq 2
  then
    "$@" >/dev/null 2>&1
  elif test "${QUIET}" -eq 1
  then
    "$@" >/dev/null
  else
    "$@"
  fi
  RET=$?

  if test ${RET} -eq 0
  then
    log_success
  else
    log_failure
  fi

  return ${RET}
}

_print_msg() {
  if test "${QUIET:-0}" -ge 1
  then
    printf "%b%s%b ... " "${COLOR}" "$*" "${COLOR_RESET}"
  else
    printf "%b%s%b\n" "${COLOR}" "$*" "${COLOR_RESET}"
  fi
}

log_message() {
  COLOR=${COLOR_BLUE} _print_msg "$*"
}

log_warning() {
  COLOR=${COLOR_YELLOW} _print_msg "$*"
}

log_success() {
  QUIET=0 COLOR=${COLOR_GREEN} _print_msg "${*:-ok}"
}

log_failure() {
  QUIET=0 COLOR=${COLOR_RED} _print_msg "${*:-failed}"
}

usage() {
cat << EOM

Usage: test [-h HOSTNAME] [-p PORT] [-U USERNAME] [-d DBNAME] [-t TESTS]

Run pgTap tests against a running PostgreSQL server.

Installs and uninstalls pgTap functions on the target server using pgTap's bundled SQL scripts, therefore you must provide a database user with administrative privileges to run this script.

Set the PGPASSWORD environment variable to provide a password.

Options:
  -h    HOSTNAME    PostgreSQL host to connect to. Defaults to the PGHOST environment variable, or 'localhost' in the absence of it.
  -p    PORT        PostgreSQL port to connect to. Defaults to the PGPORT environment variable.
  -U    USERNAME    PostgreSQL user to connect as. Defaults to the PGUSER environment variable, or 'postgres' in the absence of it.
  -d    DBNAME      PostgreSQL database to connect to. Defaults to the PGDATABASE environment variable, or 'postgres' in the absence of it.
  -t    TESTS       Test(s) to run. May be a single filename or a glob pattern. Defaults to 't/*.sql/'.

EOM
exit 64  # EX_USAGE
}

while getopts h:p:U:d:t: OPT
do
  case "${OPT}" in
    h)
      export PGHOST="${OPTARG}"
      ;;
    p)
      export PGPORT="${OPTARG}"
      ;;
    U)
      export PGUSER="${OPTARG}"
      ;;
    d)
      export PGDATABASE="${OPTARG}"
      ;;
    t)
      TESTS="${OPTARG}"
      ;;
    \?)
      usage
      ;;
  esac
done

# uninstall pgTap on script exit
uninstall_pgtap() {
  QUIET=1 log_run "Uninstalling pgTap functions from ${PGHOST}:${PGPORT}" psql -f ./uninstall_pgtap.sql
}

trap uninstall_pgtap EXIT

# install pgTap
QUIET=1 log_run "Installing pgTap functions into the ${PGDATABASE} database on ${PGHOST}:${PGPORT}" psql -f ./install_pgtap.sql
# exit if pgTap failed to install
test $? -ne 0 && exit $?

# run the tests
for FILE in ${TESTS}
do
  log_run "Running test: ${FILE}" pg_prove "${FILE}"
  TEST_RET=$?
  test ${TEST_RET} -ne 0 && break
done

if test ${TEST_RET} -eq 0
then
  log_success 'Tests Passed'
else
  log_failure 'Tests Failed'
fi

# exit with return code of the tests
exit ${TEST_RET}
