#!/bin/bash
# /u01/upg122/db/12.1.0/UPG122_celprovm022.env
srcFile=$1

. $srcFile
cd ${ORACLE_HOME}/OPatch
./opatch lsinventory
