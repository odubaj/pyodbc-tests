#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/pyodbc/Sanity/postgresql-odbc
#   Description: Simple test for the postgresql odbc interface in python
#   Author: Honza Horak <hhorak@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh

# note we keep fake $PACKAGE due to fact that beakerlib handles this variable specially
PACKAGE="python3-pyodbc"

PGDATA="/var/lib/pgsql/data"

rlJournalStart
    rlPhaseStartSetup "General Setup"
        rlRun "rlImport postgresql/basic"
        PACKAGES="$PACKAGE unixODBC postgresql-odbc ${postgresqlPackagePrefix}postgresql-server";
        for PACKAGE in $PACKAGES; do
            rlAssertRpm $PACKAGE;
        done
        PGDATA="$(postgresqlGetDataDir)";
    rlPhaseEnd

    rlPhaseStartSetup "Test setup"
        TestDir=$PWD
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
	rlRun "cp init.sql $TmpDir"
        rlRun "pushd $TmpDir"
        rlFileBackup /etc/odbc.ini
        rlRun "cp ${TestDir}/odbc.ini /etc/odbc.ini" 0 "Setting up odbc.ini"
        rlFileBackup /etc/odbcinst.ini
        rlRun "cp ${TestDir}/odbcinst.ini /etc/odbcinst.ini" 0 "Setting up odbcinst.ini"
        # prepare the database
        rlRun "postgresqlStop";
        rlFileBackup "$PGDATA"
        rlRun "rm -rf $PGDATA" 0 "Cleaning the database directory"
        rlRun "postgresqlStart";
        sleep 6;
        rlRun "service ${postgresqlServiceName} status"
    rlPhaseEnd

    rlPhaseStartTest
        # We must su to postgres to get past the default ident auth check
        rlRun 'su postgres -c "/usr/bin/isql PostgreSQL postgres -v" &> isql.out <<EOF
select 123 * 456;
quit
EOF' 0 "Run a trivial query using isql"

        # DEBUG
            cat isql.out
        # the output should look like:

        # +---------------------------------------+
        # | Connected!                            |
        # |                                       |
        # | sql-statement                         |
        # | help [tablename]                      |
        # | quit                                  |
        # |                                       |
        # +---------------------------------------+
        # SQL> +------------+
        # | ?column?   |
        # +------------+
        # | 56088      |
        # +------------+
        # SQLRowCount returns 1
        # 1 rows fetched
        # SQL>
        rlAssertGrep "Connected" "isql.out"
        rlAssertGrep "56088" "isql.out"
        rlAssertGrep "1 row" "isql.out"
        # when there's an error, it looks like, for example:

        # [ISQL]ERROR: Could not SQLConnect
        # [01000][unixODBC][Driver Manager]Can't open lib '$ORIGIN/psqlodbc.sol' : $ORIGIN/psqlodbc.sol: cannot open shared object file: No such file or directory
        rlAssertNotGrep "ERROR" "isql.out"
    rlPhaseEnd

    rlPhaseStartSetup "Setup test user"
	rlRun "postgresqlExec 'psql -f ${TestDir}/init.sql' postgres" 0 "Init the database table"
        rlRun "postgresqlStop"
        rlRun "grep testuser $dataDir/pg_hba.conf || echo 'local all testuser md5' >>$dataDir/pg_hba.conf" 0 "Configuring testuser authentication"
        rlRun "postgresqlStart"
    rlPhaseEnd

    # test bug pyodbc itself
    rlPhaseStartTest "pyodbc app"
	rlRun -s "postgresqlExec ${TestDir}/pyodbcsample postgres" 0 "Run a sample pyodbc application"
        # DEBUG
            cat $rlRun_LOG
        rlAssertGrep "245" $rlRun_LOG
        rlAssertGrep "876" $rlRun_LOG
        rm $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "postgresqlStop";
        rlRun "rm -rf $PGDATA" 0 "Cleaning database directory"
        rlRun "rm /etc/odbc.ini /etc/odbcinst.ini" 0 "Remove our configfiles"
        rlFileRestore
        rlServiceRestore ${postgresqlServiceName};
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
