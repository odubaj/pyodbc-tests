#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/mariadb-connector-odbc/Sanity/mariadb-simple
#   Description: Simple sanity test connecting to mariadb database
#   Author: Filip Januš <fjanus@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2018 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1
TestDir=$PWD
PACKAGE="python3-pyodbc"

rlJournalStart
    rlPhaseStartSetup
	rlAssertRpm $PACKAGE
        rlAssertRpm mariadb-server
        rlAssertRpm mariadb
        rlAssertRpm unixODBC
        rlAssertRpm mariadb-connector-odbc
        rlAssertRpm python3-pyodbc
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlFileBackup /etc/odbc.ini
        rlRun "cp -f ${TestDir}/odbc.ini /etc/odbc.ini"
        rlRun "systemctl start mariadb"
        rlRun "mysql < ${TestDir}/init.sql" 0 "Creating the testing database"
    rlPhaseEnd
    rlPhaseStartTest
        rlRun -s "${TestDir}/pyodbcsample " 0 "Running a trivial query using pyodbc"
        ## the output should look like
        # (5, '25')
        rlAssertGrep "(5, '25')" $rlRun_LOG
        rlAssertNotGrep "ERROR" $rlRun_LOG
    rlPhaseEnd
    rlPhaseStartCleanup
       # rlRun "mysql -e \"DROP DATABASE test;\"" 0 "Dropping the testing database"
       # mariadbRestore
       # rlFileRestore
        #rlRun "popd"
        #rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
