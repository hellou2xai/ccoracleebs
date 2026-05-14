#!/bin/sh
# $Header: ATGSuppJavaMailerSetup12.sh v16.0 2023/12/17 amlepe bburbage noship $ 
#
# +==========================================================================+
# |  Copyright (c) 2004 Oracle Corporation Redwood Shores, California, USA   |
# |   Oracle Support Services.  All rights reserved.                         |
# +==========================================================================+
#
##############################################################################
## PURPOSE:   Display, Collect and Validate Java Mailer Setup Information
##
## FILE NAME: ATGSuppJavaMailerSetup12.sh
##
## NOTE:      748421.1, Oracle Workflow ATG Support: Java Mailer Setup Diagnostic Test
##
## PRODUCT:   Oracle Workflow
##
## PRODUCT 
## VERSION:   R12
##
## PARAMS:    APPS Username
##            APPS Password
# parm1: Inbound Mail Account Username (e.g. First.Last)
# parm2: Inbound Mail Account Password
# parm3: Inbound Mail Server (e.g. myhost.mydomain)
# parm4: Outbound Mail Server (e.g. myhost2.mydomain)
# parm5: Reply Address for the Outbound Notifications
##
## NODE:      Concurrent Manager Node
##
##############################################################################
## CHANGE HISTORY:
##############################################################################
##	gggrant 2008/11/09 
## 	Made compatible with 11i4 and above.
##  	Added count of processed and discard so long as feature available in 
##	Mailer.class
##
##	gggrant 2009/06/01
##	Added APPS_FRAMEWORK_AGENT and removed APPS_WEB_AGENT
##	Add a call to wfmlrdbg.sql for a FWK=Y NID.
##	Created a script to get supplemental information about meta data
##	that can affect mailer processsing.
##	Added HTTP test for FWK=Y NID.
##
##	gggrant 2009/07/07
##	Split IMAP test into its separate steps INBOX, DISCARD and PROCESS
##	so customers can see its progress.
##
##	gggrant 2009/0/10
##	Modified FWK=Y query to find most recent NID based on NID value
##	Added IMAPSSL test for generic seeded mailer. Test not designed for 
##	dedicated mailer at this point.
##
##	gggrant 2010/03/10
##	Added same Sun OS sed syntax that is in wfver.sql section in an effort
##	to fix Sun OS hang in HTTP section.
##
##	gggrant	2010/05/03
##	Added SUN OS LD_LIBRARY_PATH HTTP section fix.
##
##  bburbage 2021/10/02
##  Added JDK 1.7 compatibility check
##
##	amlepe 2021/10/29
##	Added SQL to obtain JAVA_MAIL_API_VERSION value.
##
##	amlepe 2023/08/25
##	Changed SQL to obtain WF Mailer log file (use trimmed file now)
##
##  bburbage 2023/12/07
##  Added logging to the script to track what happens during runtime
##
##############################################################################

# Sourcing the API
. ./sdf_core2.txt

#################################################
#########  BEGIN:  Overruled core APIs  #########
#################################################

#################################################
##########  END:  Overruled core APIs  ##########
#################################################

#################################################
##########  BEGIN:  User-Defined APIs  ##########
#################################################


Cleanup ()
{
##
## Procedure Name: Cleanup
##
## Usage:
##   Cleanup
##
## Parameters:
##   None.
##
## Description:
##   Internal Procedure to cleanup temp files upon exiting this script
##
## Examples:
##   Cleanup
##
## Returns:
##   None.
##
## Notes:
##   None.
##
## Version History:
##
##

  Log "Cleaning up ..."

  # in case the test was asking for password the local echo
  # was set off. Now turn it on again.
  stty echo 1>/dev/null 2>/dev/null

  if [ -r $OUT_DIR/$OUT_FILE ] ; then
    rm $OUT_DIR/$OUT_FILE
  fi

  if [ -r $OUT_DIR/$OUT_FILE.txt ] ; then
    rm $OUT_DIR/$OUT_FILE.txt
  fi

  # Remove Internal manager logfile
  
  # svarga: needed to change the condition because it failed on some Linux instances
  #if [ ! -z ${ICM_FILENAME} -a -r ${OUT_DIR}/${PRD}_${ICM_FILENAME} ] ; then
  if [ "${ICM_FILENAME}" != "" -a -r ${OUT_DIR}/${PRD}_${ICM_FILENAME} ] ; then
    rm ${OUT_DIR}/${PRD}_${ICM_FILENAME}
  fi

  # Remove FNDSM files
  if [ -r ${OUT_DIR}/${PRD}_FNDSMFILES.txt ]; then
    rm ${OUT_DIR}/${PRD}_FNDSMFILES.txt
  fi
  if [ "${FNDSM_FILE1}" != "" -a -r ${OUT_DIR}/${PRD}_${FNDSM_FILE1} ]; then
    rm ${OUT_DIR}/${PRD}_${FNDSM_FILE1}
  fi
  if [ "${FNDSM_FILE2}" != "" -a -r ${OUT_DIR}/${PRD}_${FNDSM_FILE2} ]; then
    rm ${OUT_DIR}/${PRD}_${FNDSM_FILE2}
  fi

  # Remove WFSERV files
  if [ -r ${OUT_DIR}/${PRD}_WFSERVFILES.txt ]; then
    rm ${OUT_DIR}/${PRD}_WFSERVFILES.txt
  fi
  if [ "${WFSERV_FILE1}" != "" -a -r ${OUT_DIR}/${PRD}_${WFSERV_FILE1} ]; then
    rm ${OUT_DIR}/${PRD}_${WFSERV_FILE1}
  fi
  if [ "${WFSERV_FILE2}" != "" -a -r ${OUT_DIR}/${PRD}_${WFSERV_FILE2} ]; then
    rm ${OUT_DIR}/${PRD}_${WFSERV_FILE2}
  fi

  # Remove DebugSvc files
  if [ -r ${OUT_DIR}/${PRD}_DEBUGSVCFILES.txt ] ; then
    rm ${OUT_DIR}/${PRD}_DEBUGSVCFILES.txt
  fi
  if [ "${DEBUGSVC_FILE1}" != "" -a -r ${OUT_DIR}/${PRD}_${DEBUGSVC_FILE1} ]; then
    rm ${OUT_DIR}/${PRD}_${DEBUGSVC_FILE1}
  fi
  if [ "${DEBUGSVC_FILE2}" != "" -a -r ${OUT_DIR}/${PRD}_${DEBUGSVC_FILE2} ]; then
    rm ${OUT_DIR}/${PRD}_${DEBUGSVC_FILE2}
  fi
  
  # Remove wfver log file
  if [ -r ${OUT_DIR}/${PRD}_wfver_sql.txt ]; then
    rm ${OUT_DIR}/${PRD}_wfver_sql.txt
  fi
  
  # Remove folder list log file
  if [ -r ${OUT_DIR}/${PRD}_folderlist.txt ]; then
    rm ${OUT_DIR}/${PRD}_folderlist.txt
  fi

  # Remove smtp connectivity output file
  if [ -r ${OUT_DIR}/${PRD}_smtpout.txt ]; then
    rm ${OUT_DIR}/${PRD}_smtpout.txt
  fi

} ### End Procedure Cleanup ###
now=$(date)
LOGFILE=/tmp/ATGSuppJavaMailerSetupLog.txt
echo "=========================================================================" > $LOGFILE
echo "Starting Log for ATGSuppJavaMailerSetup12.sh $now" >> $LOGFILE

#################################################
###########  END:  User-Defined APIs  ###########
#################################################


#D #############################################################
#D Oracle Workflow ATG Support: Java Mailer Setup Diagnostic Test
#D
#D This diagnostic test will validate the Java Mailer Setup. It will also
#D collect information on the setup and environment and display that.
#D 
#D NOTE:
#D      IF RDBMS OR RDBMS LISTENER IS DOWN THEN DIAGNOSTIC EXITS AND INFORMS USER TO
#D      START BOTH THE DATABASE AND DATABASE LISTENER BEFORE RUNNING THIS DIAGNOSTIC
#D
#D #############################################################

#D #############################################################
#D The following tests are performed:
#D
#D #############################################################

############
### Main ###
############

Args="$*"
ArgCount="$#"
SECTION_BOLD_OVERIDE="ON";   export SECTION_BOLD_OVERIDE
BEGIN_DELIM="\"";            export BEGIN_DELIM
END_DELIM="\"";              export END_DELIM
NUMBERING=OFF;               export NUMBERING
PRD="ATGSuppJavaMailerSetup12";  export PRD
QLINKS="ON";                 export QLINKS

PARAMETER_NOTE1="Parameters with asterisk (*) are required. \
For the optional parameters, default values will be retrieved from the database."
PARAMETER_NOTE2="For IMAP test to be performed, the \
\"Inbound Mail Account Password\" is required because the database value contains \
an encrypted value making it unusable for this diagnostic test."
PARAMETER_ASTERISK="*"

# Make sure cleanup is done
trap 'Cleanup; printf "\nTerminated by a signal...\n\n"; exit 1' 1 2 3 6 14 15

# Calling the Setup_Env API to set the script environment

Setup_Env

# Setting general variables after calling Setup_Env

Title="Oracle Workflow ATG Support: R12 Java Mailer Setup Diagnostic Test"
Core_Version="$API_Version"
Script="`head -5 $0 | grep Header | sed 's/#//g' `"

# This checks for command line or web options like webdoc=y

Process_Options

# sciobanu: Get rid of HTML translated characters when running via CGI
if [ "${internal_output}" = "html" ];then
  Escape "$aparm1"; aparm1="$parm1"
  Escape "$aparm5"; aparm5="$parm1"


  aparm1=`$ECHO "${aparm1}" | sed 's/%40/@/g'`
  aparm5=`$ECHO "${aparm5}" | sed 's/%40/@/g'`
fi 

# #############################################################
# Showing the header table on the output
# #############################################################

# It is needed to show Applications version in the header
Check_Apps_Version "" "-gt" 11.5.0
Show_Header

Empty_Line

##################################################################
# Show relevant products status
#   FND SYSADMIN AD
##################################################################

Display_Product_Status 0 1 50

Check_Node CON SILENT

##############################
### End Typical Header Part ##
##############################

#################################################
##########  BEGIN:  Main Processing Block  ######
#################################################

#D #############################################################
#D ** Technology Stack Requirements
#D 
#D #############################################################

SectionHeader "Technology Stack Requirements"

#D #############################################################
#D    Oracle Applications Version
#D 
#D #############################################################

OK=`${ECHO} "$APPS_VERSION" | egrep "11.5.3|11.5.4|11.5.5|11.5.6|11.5.7|11.5.8|11.5.9|11.5.10|12.0|12.1|12.2"`
if [ "${OK}" = "" ];then
  Compare_Values "$APPS_VERSION" -lt "11.5.3"
  if [ "$ANSWER" = "True" ]; then
    ErrorPrint "Incorrect version of Oracle Applications ($APPS_VERSION) detected"
    ActionErrorPrint "Please run this diagnostic test on 11.5.3 or higher"

    Show_Footer

    Cleanup

    exit 1
  else
    WarningPrint "Version $APPS_VERSION of Oracle Applications detected"
    ActionWarningPrint "This diagnostic test was tested with 11.5.3 - 12.1, not version $APPS_VERSION"
  fi
fi


#D #############################################################
#D    Node verification
#D 
#D #############################################################

if [ "${CON}" != "${CURRENT_NODE}" ]; then
    ErrorPrint "The current node \"${CURRENT_NODE}\" is not a concurrent manager (CON) tier"
    ActionErrorPrint "Please run this test on concurrent manager node \"${CON}\""

    Show_Footer

    Cleanup

    exit 1
fi


# Set the character which seperates paths from each other in CLASSPATH, PATH, etc.
# Make sure the correct adjborg file for checking is used. For NT the newest MKS
# versions also contains unzip but for now we will use 'strings'. For UNIX it is
# assumed that unzip is contained in the path.
if [ "${OS_NAME}" = "Windows_NT" ]; then
  ENVPATHSEP=";"
  # Set MKSROOT dir (including trailing slash)
#  MKSROOTDIR="`which sh.exe | sed 's#\\\\#/#g' | awk -F"/" '{ for(i=1;i<=NF-2;i++) { printf("%s/",$i); } }'`"
#  UNZIP_CMD="${MKSROOTDIR}bin/unzip"
  ADJBORG2_FILENAME="adjborg2_nt.txt"
else
  ENVPATHSEP=":"
  UNZIP_CMD="unzip"
  ADJBORG2_FILENAME="adjborg2.txt"
fi
export ENVPATHSEP UNZIP_CMD ADJBORG2_FILENAME



#D #############################################################
#D    Oracle Database
#D 
#D #############################################################

#Begin_Pre
#SectionPrint "Oracle Database"

Get_RDBMS_Header
# BUG in core, the api changes the SetOption
# Removed compare so compatible with 11i4 and above, and eliminate hard coding of versions.
SetOption="set head on" 

Begin_Pre
	
	Tab1Print "Database version is ${RDBMS_VERSION}."

  End_Pre
    Cleanup


#D #############################################################
#D    XML Parser in APPS Account
#D 
#D #############################################################

# Removed compare so compatible with 11i4 and above, and eliminate hard coding of versions.

Begin_Pre
SectionPrint "XML Parser in APPS Account"

SQL="set serverout on;
set feedback off;
set pagesize 3000;
declare
  xmlVersion varchar2(50);
begin
  xmlVersion := ECX_UTILS.XMLVersion();
  dbms_output.put_line('XMLVERSION='||xmlVersion); 
end;
/" # This slash has to be at the far left

Run_PLSQL

XMLVERSION=`grep XMLVERSION ${OUT_DIR}/${OUT_FILE}.txt | awk -F"=" '{print $2}'`


  Tab1Print "XMLVERSION = ${XMLVERSION}"
  End_Pre

  Cleanup


#D #############################################################
#D    XML Parser in SYS Account
#D 
#D #############################################################


#D #############################################################
#D ** JDK Requirements
#D 
#D #############################################################

SectionHeader "JDK Requirements"

# using message variables to have continuous text in the output
if [ "${OS_NAME}" = "Windows_NT" ]; then
  REGISTRY_ADOVARS="This test will verify the entries for AFJVAPRG, AF_JRE_TOP \
and AFCLASSPATH in the NT registry"
else
  REGISTRY_ADOVARS="This test will verify the settings AFJVAPRG, AF_JRE_TOP and \
AFCLASSPATH coming from the file adovars.env"
fi

# First check if JDK 1.3, 1.4 or 1.5/5.0 is installed. Depending on the environment variables and 
# version returned by the java program there will be no further checks on the 
# JDK required settings.

# Handle NT seperately since this gets the settings from the registry
# Check and display settings from registry instead of environment
if [ "${OS_NAME}" = "Windows_NT" ]; then
  # Start the search here
  KEY_APPS="HKEY_LOCAL_MACHINE\SOFTWARE\ORACLE\APPLICATIONS\11.5.0"

  # Get the key in which the settings are stored (newer versions have hostname included)
  KEY_APPS_SETTINGS=${KEY_APPS}"\\${ORACLE_SID}_`hostname`"
  # Check for FND_TOP, if not found remove hostname from the registry key
  if [ "`registry  -p -k "${KEY_APPS_SETTINGS}" -n FND_TOP 2>/dev/null`" = "" ]; then
    KEY_APPS_SETTINGS=${KEY_APPS}"\\${ORACLE_SID}"
  fi
  export KEY_APPS_SETTINGS

  V2C_AFJVAPRG=`GetRegistrySetting "${KEY_APPS_SETTINGS}" "AFJVAPRG"`
  if [ "`echo ${V2C_AFJVAPRG} | grep '%'`" != "" ]; then
    WarningPrint "AFJVAPRG contains '%'"
    ActionWarningPrint "Make sure there are only direct pathnames (no variables) in this setting"
  fi
else
  V2C_AFJVAPRG=${AFJVAPRG}
fi

# Now check if is useful to continue the JDK checks
# Find the installed version of JDK and set variable for the directory, metalink note


if [ "${V2C_AFJVAPRG}" = "" ]; then
  JDK_INSTALLED="NO"
else
  JDK_VERSION=`eval ${V2C_AFJVAPRG} -version 2>&1 | awk '{print $3}' | sed 's/"//g' | sed 's/_/./g' | head -1`

  # take just the first 4 characters of the JDK version
  JDK_TWO_DIGITS="`${ECHO} ${JDK_VERSION} | awk '{printf("%s",substr($0,1,4))}' `"

  if [ "`${ECHO} ${JDK_TWO_DIGITS} | grep '1.3'`" != "" ]; then
    JDK_INSTALLED="YES"
    JDK_INST_TOP="JDK13_TOP"
    JDK_INST_VERS="1.3"
    JDK_METALINK_NOTE="130091.1"
  elif [ "`${ECHO} ${JDK_TWO_DIGITS} | grep '1.4'`" != "" ]; then
    JDK_INSTALLED="YES"
    JDK_INST_TOP="JDK14_TOP"
    JDK_INST_VERS="1.4"
    JDK_METALINK_NOTE="246105.1"
  elif [ "`${ECHO} ${JDK_TWO_DIGITS} | grep '1.5'`" != "" ]; then
    JDK_INSTALLED="YES"
    JDK_INST_TOP="JDK15_TOP"
    JDK_INST_VERS="1.5"
    JDK_METALINK_NOTE="304099.1"
  elif [ "`${ECHO} ${JDK_TWO_DIGITS} | grep '1.6'`" != "" ]; then
    JDK_INSTALLED="YES"
    JDK_INST_TOP="JDK16_TOP"
    JDK_INST_VERS="1.6"
    JDK_METALINK_NOTE="455492.1"
  elif [ "`${ECHO} ${JDK_TWO_DIGITS} | grep '1.7'`" != "" ]; then
    JDK_INSTALLED="YES"
    JDK_INST_TOP="JDK17_TOP"
    JDK_INST_VERS="1.7"
    JDK_METALINK_NOTE="1467892.1"	
  else
    JDK_INSTALLED="NO"
  fi

fi



#D #############################################################
#D    JDK Version
#D 
#D #############################################################

  # JDK_VERSION is already determined earlier, display it now
  Begin_Pre
  SectionPrint "JDK Version"
  Tab1Print "${JDK_INST_TOP} = ${AF_JRE_TOP}"
  Tab1Print "JDK_VERSION = ${JDK_VERSION}"
  End_Pre

  echo "JDK Version" >> $LOGFILE
  echo "${JDK_INST_TOP} = ${AF_JRE_TOP}" >> $LOGFILE
  echo "JDK_VERSION = ${JDK_VERSION}" >> $LOGFILE


#D #############################################################
#D    AF_JRE_TOP
#D 
#D #############################################################

  Begin_Pre
  SectionPrint "AF_JRE_TOP"
  if [ "${OS_NAME}" = "Windows_NT" ]; then
    V2C_AF_JRE_TOP=`GetRegistrySetting "${KEY_APPS_SETTINGS}" "AF_JRE_TOP"`
    if [ "`echo ${V2C_AF_JRE_TOP} | grep '%'`" != "" ]; then
      WarningPrint "AF_JRE_TOP contains '%'"
      ActionWarningPrint "Make sure there are only direct pathnames (no variables) in this setting"
    fi
  else
    V2C_AF_JRE_TOP=${AF_JRE_TOP}
  fi
  if [ "${V2C_AF_JRE_TOP}" != "" ];then
    Tab1Print "AF_JRE_TOP = ${V2C_AF_JRE_TOP}"
    if [ -d "${V2C_AF_JRE_TOP}" ]; then
      Tab1Print "The directory exists on the filesystem"
      End_Pre
    else
      End_Pre
      WarningPrint "Cannot find the directory ${V2C_AF_JRE_TOP} (JDK ${JDK_INST_VERS} TOP directory)"
      ActionWarningPrint "Verify the configuration on the concurrent processing node using `Show_Metalink ${JDK_METALINK_NOTE}`. "
    fi
  else
    End_Pre
    ErrorPrint "The \"AF_JRE_TOP\" setting is missing"
    ActionErrorPrint "Verify the JDK environment using `Show_Metalink 242941.1 NOHEADER`"
  fi


#D #############################################################
#D    AFJVAPRG
#D 
#D #############################################################

  Begin_Pre
  SectionPrint "AFJVAPRG"
  # V2C_AFJVAPRG is already set when checking for JDK 
  if [ "${V2C_AFJVAPRG}" != "" ];then
    Tab1Print "AFJVAPRG = ${V2C_AFJVAPRG}"
    if [ -f ${V2C_AFJVAPRG} ]; then
      Tab1Print "The file exists on the filesystem"
      End_Pre
    else
      End_Pre
      WarningPrint "Cannot find the file ${V2C_AFJVAPRG}"
      ActionWarningPrint "Verify the configuration on the concurrent processing node using `Show_Metalink ${JDK_METALINK_NOTE}`. "
    fi
  else
    End_Pre
    ErrorPrint "The \"AFJVAPRG\" setting is missing"
    ActionErrorPrint "Verify the JDK environment using `Show_Metalink 242941.1 NOHEADER`"
  fi


#D #############################################################
#D    AF_CLASSPATH
#D 
#D #############################################################

  Begin_Pre
  SectionPrint "AF_CLASSPATH"
  if [ "${OS_NAME}" = "Windows_NT" ]; then
    V2C_AF_CLASSPATH=`GetRegistrySetting "${KEY_APPS_SETTINGS}" "AF_CLASSPATH"`
    if [ "`echo ${V2C_AFCLASSPATH} | grep '%'`" != "" ]; then
      WarningPrint "AF_CLASSPATH contains '%'"
      ActionWarningPrint "Make sure there are only direct pathnames (no variables) in this setting"
    fi
  else
    V2C_AF_CLASSPATH="${AF_CLASSPATH}"
  fi

  if [ "${V2C_AF_CLASSPATH}" = "" ]; then
    End_Pre
    WarningPrint "The \"AF_CLASSPATH\" setting is missing"
    ActionWarningPrint "Verify the configuration on the concurrent processing node using `Show_Metalink ${JDK_METALINK_NOTE}`. "

  else
    Tab0Print "Current values in AF_CLASSPATH"
    for ONE_ENTRY in `${ECHO} ${V2C_AF_CLASSPATH} | ${AWK} -F${ENVPATHSEP} '{ for (i = 1;i <= NF;i++) { printf("%s\n",$i); } }'`
    do
      Tab1Print "${ONE_ENTRY}"
    done
    Empty_Line

    # Display the order here in advance so we do not need to show everytime in every error message
    Tab0Print "The following entries must be present:"
    Tab1Print "[${JDK_INST_TOP}]/lib/dt.jar"
    Tab1Print "[${JDK_INST_TOP}]/lib/tools.jar"
    #Tab1Print "[${JDK_INST_TOP}]/jre/lib/rt.jar"
    #Tab1Print "[${JDK_INST_TOP}]/jre/lib/charsets.jar"
    Tab1Print "[JAVA_TOP]/appsborg2.zip"
    Tab1Print "[JAVA_TOP]"
    Empty_Line

    # First check for the presence of the entry and if the file really exists
    Tab0Print "Validate required entries"
    CheckExistenceEnv  "${V2C_AF_CLASSPATH}" "dt.jar" FILE JDK_TOP_LIB_DTJAR_POS NOEXACT ERROR
    JDK_TOP_LIB_DTJAR=${ENTRY}
    CheckExistenceEnv  "${V2C_AF_CLASSPATH}" "tools.jar" FILE JDK_TOP_LIB_TOOLSJAR_POS NOEXACT ERROR
    JDK_TOP_LIB_TOOLSJAR=${ENTRY}
    CheckExistenceEnv  "${V2C_AF_CLASSPATH}" "appsborg2.zip" FILE JAVA_TOP_APPSBORG2ZIP_POS NOEXACT ERROR
    JAVA_TOP_APPSBORG2ZIP=${ENTRY}
    CheckExistenceEnv  "${V2C_AF_CLASSPATH}" "$OA_JAVA" DIR JAVA_TOPDIR_POS EXACT ERROR
    Empty_Line

    # svarga: discussed with cbarron, reference note: 130091.1
    # Next two are tested but no error will be returned
    Tab0Print "Validate other possible entries"
    CheckExistenceEnv  "${V2C_AF_CLASSPATH}" "rt.jar" FILE JDK_TOP_JRE_LIB_RTJAR_POS NOEXACT NOERROR
    JDK_TOP_JRE_LIB_RTJAR=${ENTRY}
    CheckExistenceEnv  "${V2C_AF_CLASSPATH}" "charsets.jar" FILE JDK_TOP_JRE_LIB_CSETJAR_POS NOEXACT NOERROR
    JDK_TOP_JRE_LIB_CSETJAR=${ENTRY}
    Empty_Line

    End_Pre
  fi


#D #############################################################
#D ** Generic Service Manager (GSM)
#D
#D #############################################################

SectionHeader "Generic Service Manager (GSM)"



#D #############################################################
#D    FNDSM Status
#D 
#D #############################################################

Begin_Pre
SectionPrint "FNDSM Status"
SQL="set feedback off
col USER_CONCURRENT_QUEUE_NAME format a50
col RUNNING format a3
col ENABLED format a3
col #PROCS format 9999
col #MAXPROCS format 9999
select fcq.USER_CONCURRENT_QUEUE_NAME,
       fcq.RUNNING_PROCESSES \"#PROCS\",
       fcq.MAX_PROCESSES \"#MAXPROCS\",
       fcq.ENABLED_FLAG ENABLED,
       DECODE(fcp.OS_PROCESS_ID,NULL,'No','Yes') RUNNING
  from FND_CONCURRENT_QUEUES_VL fcq, FND_CP_SERVICES fcs,
       FND_CONCURRENT_PROCESSES fcp
 where fcq.MANAGER_TYPE = fcs.SERVICE_ID
   and fcs.SERVICE_HANDLE = 'FNDSM'
   and fcq.concurrent_queue_id = fcp.concurrent_queue_id(+)
   and fcq.application_id = fcp.queue_application_id(+)
   and fcp.process_status_code(+) = 'A'"
Run_SQL ADVCOUNT

# First check if any records were retrieved
if [ "${RECORDS_RETURNED_COUNT}" != "0" ]; then
  End_Pre
  # Print the result in table
  Show_SQL_Output "${OUT_DIR}/${OUT_FILE}.txt" "" 1 52 59 69 73

  # If one is not running then print warning
  if [ `cat ${OUT_DIR}/${OUT_FILE}.txt | cut -c70- | grep No | wc -l` -gt 0 ]; then
    WarningPrint "One or more of the FNDSM processes is not running"
    ActionWarningPrint "Please start up all processes / queues. `Show_Metalink 204090.1` \
and `Show_Metalink 177250.1 NOHEADER` for more information."
  fi

else
  Tab0Print "No records found for service handle 'FNDSM' in table and FND_CP_SERVICES"
  End_Pre
fi


#D #############################################################
#D    GSM Debug Service Status
#D 
#D #############################################################

Begin_Pre
SectionPrint "GSM Debug Service Status"
SQL="set feedback off
col USER_CONCURRENT_QUEUE_NAME format a50
col RUNNING format a3
col ENABLED format a3
col #PROCS format 9999
col #MAXPROCS format 9999
select USER_CONCURRENT_QUEUE_NAME,
       RUNNING_PROCESSES \"#PROCS\",
       MAX_PROCESSES \"#MAXPROCS\",
       ENABLED_FLAG ENABLED,
       DECODE(OS_PROCESS_ID,NULL,'No','Yes') RUNNING
  from FND_CONCURRENT_QUEUES_VL fcq,
       FND_CP_SERVICES fcs,
       FND_CONCURRENT_PROCESSES fcp
 where fcq.MANAGER_TYPE = fcs.SERVICE_ID
   and fcs.SERVICE_HANDLE = 'DebugSvc'
   and fcq.concurrent_queue_id = fcp.concurrent_queue_id(+)
   and fcq.application_id = fcp.queue_application_id(+)
   and fcp.process_status_code(+) = 'A'"
Run_SQL ADVCOUNT

# First check if any records were retrieved
if [ "${RECORDS_RETURNED_COUNT}" != "0" ]; then
  End_Pre
  # Print the result in table
  Show_SQL_Output "${OUT_DIR}/${OUT_FILE}.txt" "" 1 52 59 69 73

  # If one is not running then print warning
    if [ `cat ${OUT_DIR}/${OUT_FILE}.txt | cut -c70- | grep No | wc -l` -gt 0 ]; then
    WarningPrint "The GSM Debug Service is not running"
  fi
else
  Tab0Print "No records found for service handle 'DebugSvc' in table and FND_CP_SERVICES"
  End_Pre
fi


#D #############################################################
#D    Service Instance Status
#D 
#D #############################################################

Begin_Pre
SectionPrint "Service Instance Status"
SQL="set feedback off
col USER_CONCURRENT_QUEUE_NAME format a50
col RUNNING format a3
col ENABLED format a3
col #PROCS format 9999
col #MAXPROCS format 9999
select fcq.USER_CONCURRENT_QUEUE_NAME,
       fcq.RUNNING_PROCESSES \"#PROCS\",
       fcq.MAX_PROCESSES \"#MAXPROCS\",
       fcq.ENABLED_FLAG ENABLED,
       DECODE(fcp.OS_PROCESS_ID,NULL,'No','Yes') RUNNING
  from FND_CONCURRENT_QUEUES_VL fcq, FND_CP_SERVICES fcs,
       FND_CONCURRENT_PROCESSES fcp
 where fcq.MANAGER_TYPE = fcs.SERVICE_ID
   and fcs.SERVICE_HANDLE = 'FNDCPGSC'
   and fcq.concurrent_queue_id = fcp.concurrent_queue_id(+)
   and fcq.application_id = fcp.queue_application_id(+)
   and fcp.process_status_code(+) = 'A'"
Run_SQL ADVCOUNT

# First check if any records were retrieved
if [ "${RECORDS_RETURNED_COUNT}" != "0" ]; then
  End_Pre
  # Print the result in table
  Show_SQL_Output "${OUT_DIR}/${OUT_FILE}.txt" "" 1 52 59 69 73

  # If one is not running then print warning
  if [ `cat ${OUT_DIR}/${OUT_FILE}.txt | cut -c70- | grep No | wc -l` -gt 0 ]; then
    WarningPrint "One or more of the Workflow Container Service instance processes is not running"
  fi

else
  Tab0Print "No records found for service handle 'FNDCPGSC' in table FND_CP_SERVICES"
  End_Pre
fi


#D #############################################################
#D ** Email setup
#D
#D #############################################################

SectionHeader "Email Setup"

NoticePrint "Please note that autoconfig takes the IMAP parameters from its XML context file (located under \$APPL_TOP/admin) \
and replaces the ones set by OAM in the database. Please update the parameters with OAM using `Show_Metalink 231286.1 NOHEADER` \
(it updates context file as well) but verify the parameters also in the context file (section \"oa_workflow_server\")."

#D #############################################################
#D    Parameters
#D
#D #############################################################

## Table FND_SVC_COMPONENTS
Begin_Pre
SectionPrint "Parameters in Table FND_SVC_COMPONENTS"

SQL="select component_id
from fnd_svc_components
where component_name = 'Workflow Notification Mailer';"
Get_DB_Value
WFMAILER_COMP_ID=`echo ${Value} | sed 's/ //g'`
Tab1Print "Workflow Notification Mailer component id = '${WFMAILER_COMP_ID}'"

echo "Workflow Notification Mailer component id = '${WFMAILER_COMP_ID}'" >> $LOGFILE

SQL="select component_status
from fnd_svc_components
where component_id = ${WFMAILER_COMP_ID};"
Get_DB_Value
Tab1Print "Workflow Notification Mailer status = '${Value}'"

End_Pre

## Table FND_SVC_COMP_PARAM_VALS
Begin_Pre
SectionPrint "Templates in Table FND_SVC_COMP_PARAM_VALS"

SQL="select parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'OPEN_INVALID'
AND    component_id = ${WFMAILER_COMP_ID};"
Get_DB_Value
Tab1Print "Invalid Response Notification (OPEN_INVALID) = '${Value}'"

SQL="select parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'SUMMARY'
AND    component_id = ${WFMAILER_COMP_ID};"
Get_DB_Value
Tab1Print "Outbound Summary Notification (SUMMARY) = '${Value}'"

SQL="select parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'WARNING'
AND    component_id = ${WFMAILER_COMP_ID};"
Get_DB_Value
Tab1Print "Outbound Warning Notification (WARNING) = '${Value}'"

End_Pre


Begin_Pre
SectionPrint "Parameters in Table FND_SVC_COMP_PARAM_VALS"

SQL="set linesize 255
select 'ACCOUNT=' || parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'ACCOUNT'
AND    component_id = ${WFMAILER_COMP_ID}
"
Run_SQL
JAVA_MAILER_ACCOUNT=`cat $OUT_DIR/$OUT_FILE.txt | grep ACCOUNT | tail -1 | \
       awk -F"=" '{print $2}' |sed 's/ //g'`

SQL="set linesize 255
select 'INBOUND_SERVER=' || parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'INBOUND_SERVER'
AND    component_id = ${WFMAILER_COMP_ID}
"
Run_SQL
JAVA_MAILER_INBOUND_SERVER=`cat $OUT_DIR/$OUT_FILE.txt | grep INBOUND_SERVER | tail -1 | \
       awk -F"=" '{print $2}' |sed 's/ //g'`

SQL="set linesize 255
select 'INBOX=' || parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'INBOX'
AND    component_id = ${WFMAILER_COMP_ID}
"
Run_SQL
JAVA_MAILER_INBOX=`cat $OUT_DIR/$OUT_FILE.txt | grep INBOX | tail -1 | \
       awk -F"=" '{print $2}' |sed 's/ //g'`

SQL="set linesize 255
select 'DISCARD=' || parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'DISCARD'
AND    component_id = ${WFMAILER_COMP_ID}
"
Run_SQL
JAVA_MAILER_DISCARD=`cat $OUT_DIR/$OUT_FILE.txt | grep DISCARD | tail -1 | \
       awk -F"=" '{print $2}' |sed 's/ //g'`

SQL="set linesize 255
select 'PROCESS=' || parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'PROCESS'
AND    component_id = ${WFMAILER_COMP_ID}
"
Run_SQL
JAVA_MAILER_PROCESS=`cat $OUT_DIR/$OUT_FILE.txt | grep PROCESS | tail -1 | \
       awk -F"=" '{print $2}' |sed 's/ //g'`

# Mailer test program ONLY accepting lowercase imap or smtp
SQL="set linesize 255
select 'INBOUND_PROTOCOL=' || parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'INBOUND_PROTOCOL'
AND    component_id = ${WFMAILER_COMP_ID}
"
Run_SQL
JAVA_MAILER_INBOUND_PROTOCOL=`cat $OUT_DIR/$OUT_FILE.txt | grep INBOUND_PROTOCOL | tail -1 | \
       awk -F"=" '{print $2}' |sed 's/ //g' | tr [:upper:] [:lower:]`

SQL="set linesize 255
select 'INBOUND_PASSWORD=' || parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'INBOUND_PASSWORD'
AND    component_id = ${WFMAILER_COMP_ID}
"
Run_SQL
JAVA_MAILER_INBOUND_PASSWORD=`cat $OUT_DIR/$OUT_FILE.txt | grep INBOUND_PASSWORD | tail -1 | \
       awk -F"=" '{print $2}' |sed 's/ //g'`

SQL="set linesize 255
select 'REPLYTO=' || parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'REPLYTO'
AND    component_id = ${WFMAILER_COMP_ID}
"
Run_SQL
JAVA_MAILER_REPLYTO=`cat $OUT_DIR/$OUT_FILE.txt | grep REPLYTO | tail -1 | \
       awk -F"=" '{print $2}' |sed 's/ //g'`

SQL="set linesize 255
select 'OUTBOUND_SERVER=' || parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'OUTBOUND_SERVER'
AND    component_id = ${WFMAILER_COMP_ID}
"
Run_SQL
JAVA_MAILER_OUTBOUND_SERVER=`cat $OUT_DIR/$OUT_FILE.txt | grep OUTBOUND_SERVER | tail -1 | \
       awk -F"=" '{print $2}' |sed 's/ //g'`

# Mailer test program ONLY accepting lowercase imap or smtp
SQL="set linesize 255
select 'OUTBOUND_PROTOCOL=' || parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'OUTBOUND_PROTOCOL'
AND    component_id = ${WFMAILER_COMP_ID}
"
Run_SQL
JAVA_MAILER_OUTBOUND_PROTOCOL=`cat $OUT_DIR/$OUT_FILE.txt | grep OUTBOUND_PROTOCOL | tail -1 | \
       awk -F"=" '{print $2}' |sed 's/ //g' | tr [:upper:] [:lower:]`

Tab1Print "Inbound mail server (INBOUND_SERVER) = '$JAVA_MAILER_INBOUND_SERVER'"
Tab1Print "Protocol to be used for inbound response emails (INBOUND_PROTOCOL) = '$JAVA_MAILER_INBOUND_PROTOCOL'"

echo "Inbound mail server (INBOUND_SERVER) = '$JAVA_MAILER_INBOUND_SERVER'" >> $LOGFILE
echo "Protocol to be used for inbound response emails (INBOUND_PROTOCOL) = '$JAVA_MAILER_INBOUND_PROTOCOL'" >> $LOGFILE

SQL="select parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'PROCESSOR_IN_THREAD_COUNT'
AND    component_id = ${WFMAILER_COMP_ID};"
Get_DB_Value
Tab1Print "Inbound thread count (PROCESSOR_IN_THREAD_COUNT) = '${Value}'"

Tab1Print "Inbound mail account username (ACCOUNT) = '$JAVA_MAILER_ACCOUNT'"
if [ "${JAVA_MAILER_INBOUND_PASSWORD}" != "" ]; then
  Tab1Print "Password of mail account (INBOUND_PASSWORD) = '********'"
else
  Tab1Print "Password of mail account (INBOUND_PASSWORD) = '$JAVA_MAILER_INBOUND_PASSWORD'"
fi
Tab1Print "Inbox folder on the inbound server (INBOX) = '$JAVA_MAILER_INBOX'"
Tab1Print "Discard folder on the inbound server (DISCARD) = '$JAVA_MAILER_DISCARD'"
Tab1Print "Process folder on the inbound server (PROCESS) = '$JAVA_MAILER_PROCESS'"
Tab1Print "Outbound mail server (OUTBOUND_SERVER) = '$JAVA_MAILER_OUTBOUND_SERVER'"
Tab1Print "Protocol to be used for outbound notifications (OUTBOUND_PROTOCOL) = '$JAVA_MAILER_OUTBOUND_PROTOCOL'"

SQL="select parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'PROCESSOR_OUT_THREAD_COUNT'
AND    component_id = ${WFMAILER_COMP_ID};"
Get_DB_Value
Tab1Print "Outbound thread count (PROCESSOR_OUT_THREAD_COUNT) = '${Value}'"

SQL="select v.parameter_value
from fnd_svc_comp_param_vals_v v,
     fnd_svc_comp_params_b p
where v.parameter_id = p.parameter_id
AND    component_id = ${WFMAILER_COMP_ID}
and p.parameter_name ='JAVA_MAIL_API_VERSION';"
Get_DB_Value
Tab1Print "The Java Mail (API) version being used by Workflow Mailer (JAVA_MAIL_API_VERSION) = '${Value}'"

Tab1Print "Reply to address for the outbound notifications (REPLYTO) = '$JAVA_MAILER_REPLYTO'"

if [ "${JAVA_MAILER_ACCOUNT}" = "" -o "${JAVA_MAILER_INBOUND_PASSWORD}" = "" -o "${JAVA_MAILER_INBOUND_SERVER}" = "" -o "${JAVA_MAILER_INBOUND_PROTOCOL}" = "" ]; then
  INCOMPLETE_INBOUND=Yes
fi

if [ "${JAVA_MAILER_DISCARD}" = "" -o "${JAVA_MAILER_PROCESS}" = "" -o "${JAVA_MAILER_INBOX}" = "" ]; then
  INCOMPLETE_FOLDER=Yes
fi

if [ "${JAVA_MAILER_OUTBOUND_SERVER}" = "" -o "${JAVA_MAILER_REPLYTO}" = ""  -o "${JAVA_MAILER_OUTBOUND_PROTOCOL}" = "" ]; then
  INCOMPLETE_OUTBOUND=Yes
fi

if [ "${INCOMPLETE_INBOUND}" = "Yes" -o "${INCOMPLETE_OUTBOUND}" = "Yes" -o "${INCOMPLETE_FOLDER}" = "Yes" ]; then
  End_Pre
  ErrorPrint "All of the above parameters must be set in table FND_SVC_COMP_PARAM_VALS. These are needed for IMAP/SMTP connection."
  ActionErrorPrint "Verify that Mailer has been configured using `Show_Metalink 231286.1 NOHEADER`"
  Begin_Pre
fi

End_Pre


Begin_Pre
SectionPrint "Test Input Parameters"

JAVA_MAILER_ACCOUNT_P=$aparm1
JAVA_MAILER_INBOUND_PASSWORD_P=$aparm2
JAVA_MAILER_INBOUND_SERVER_P=$aparm3
JAVA_MAILER_OUTBOUND_SERVER_P=$aparm4
JAVA_MAILER_REPLYTO_P=$aparm5

Tab1Print "Inbound mail server (INBOUND_SERVER) = '$JAVA_MAILER_INBOUND_SERVER_P'"
Tab1Print "Inbound mail account username (ACCOUNT) = '$JAVA_MAILER_ACCOUNT_P'"
if [ "${JAVA_MAILER_INBOUND_PASSWORD_P}" != "" ]; then
  Tab1Print "Password of mail account (INBOUND_PASSWORD) = '********'"
else
  Tab1Print "Password of mail account (INBOUND_PASSWORD) = '$JAVA_MAILER_INBOUND_PASSWORD_P'"
fi
Tab1Print "Outbound mail server (OUTBOUND_SERVER) = '$JAVA_MAILER_OUTBOUND_SERVER_P'"
Tab1Print "Reply to address for the outbound notifications (REPLYTO) = '$JAVA_MAILER_REPLYTO_P'"

End_Pre

JAVA_MAILER_ACCOUNT_P=${JAVA_MAILER_ACCOUNT_P:="${JAVA_MAILER_ACCOUNT}"}
JAVA_MAILER_INBOUND_SERVER_P=${JAVA_MAILER_INBOUND_SERVER_P:="${JAVA_MAILER_INBOUND_SERVER}"}
JAVA_MAILER_OUTBOUND_SERVER_P=${JAVA_MAILER_OUTBOUND_SERVER_P:="${JAVA_MAILER_OUTBOUND_SERVER}"}
JAVA_MAILER_REPLYTO_P=${JAVA_MAILER_REPLYTO_P:="${JAVA_MAILER_REPLYTO}"}

# svarga: not asking for these parameters (imap and smtp are always the same, folders are not relevant for the mail tester
JAVA_MAILER_INBOX_P=${JAVA_MAILER_INBOX_P:="${JAVA_MAILER_INBOX}"}
JAVA_MAILER_DISCARD_P=${JAVA_MAILER_DISCARD_P:="${JAVA_MAILER_DISCARD}"}
JAVA_MAILER_PROCESS_P=${JAVA_MAILER_PROCESS_P:="${JAVA_MAILER_PROCESS}"}
JAVA_MAILER_INBOUND_PROTOCOL_P=${JAVA_MAILER_INBOUND_PROTOCOL_P:="${JAVA_MAILER_INBOUND_PROTOCOL}"}
JAVA_MAILER_OUTBOUND_PROTOCOL_P=${JAVA_MAILER_OUTBOUND_PROTOCOL_P:="${JAVA_MAILER_OUTBOUND_PROTOCOL}"}


#D #############################################################
#D    Accounts
#D
#D #############################################################

Begin_Pre
SectionPrint "Accounts"
APPLMGR_OWNER=`ls -l $APPL_TOP | tail -1 | awk '{print $3}'`
if [ "${JAVA_MAILER_ACCOUNT}" = "${APPLMGR_OWNER}" ]; then
  End_Pre
  WarningPrint "The owner of the concurrent managers ('${APPLMGR_OWNER}') and the java mailer account ('${JAVA_MAILER_ACCOUNT}') are the same. There are known problems with using the same account."
  ActionWarningPrint "Either use another account for the java mailer or use a different account for any shutdown messages that are fired off by the concurrent manager and also when applying any patches to the environment, ensure to specify an email account other than APPLMGR account."
else
  SuccessPrint "The owner of the concurrent managers ('${APPLMGR_OWNER}') and the java mailer account ('${JAVA_MAILER_ACCOUNT}') are different which is fine"
  End_Pre
fi

echo "Testing IMAP/SMTP/HTTP Connectivity" >> $LOGFILE

#D #############################################################
#D ** IMAP/SMTP/HTTP Connectivity 
#D
#D #############################################################

SectionHeader "IMAP/SMTP/HTTP Connectivity"
Begin_Pre

TIMEOUT_DEFAULT=30

# Use APPS_DATABASE_ID value to build dbc file name accurately

SQL="select distinct v.PROFILE_OPTION_VALUE
from fnd_profile_options t, fnd_profile_option_values v, fnd_profile_options_tl z
where (v.PROFILE_OPTION_ID (+) = t.PROFILE_OPTION_ID) 
and (z.PROFILE_OPTION_NAME = t.PROFILE_OPTION_NAME)
and (t.PROFILE_OPTION_NAME ='APPS_DATABASE_ID')
and (v.level_id = 10001);"
Get_DB_Value
APPS_DATABASE_ID=`echo ${Value} | sed 's/ //g'`


# Check to see if IMAPSSL is being used

#SQL="select  v.parameter_value
#from   fnd_svc_comp_param_vals_v v, fnd_svc_comp_params_b p, fnd_svc_components c
#where  	c.component_type = 'WF_MAILER'
#and    	v.component_id = c.component_id
#and    	v.parameter_id = p.parameter_id
#and    	p.parameter_name in ('INBOUND_SSL_ENABLED')
#and   	v.parameter_value = 'Y';"

SQL="select parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'INBOUND_SSL_ENABLED'
AND    component_id = ${WFMAILER_COMP_ID};"

Get_DB_Value
INBOUND_SSL_ENABLED=`echo ${Value} | sed 's/ //g'`


#SQL="select  v.parameter_value
#from   fnd_svc_comp_param_vals_v v, fnd_svc_comp_params_b p, fnd_svc_components c
#where  	c.component_type = 'WF_MAILER'
#and    	v.component_id = c.component_id
#and    	v.parameter_id = p.parameter_id
#and    	p.parameter_name in ('MAILER_SSL_TRUSTSTORE')
#and   	v.parameter_value <> 'NONE';"

SQL="select parameter_value
FROM   fnd_svc_comp_param_vals_v
WHERE  parameter_name = 'MAILER_SSL_TRUSTSTORE'
AND    component_id = ${WFMAILER_COMP_ID};"

Get_DB_Value
MAILER_SSL_TRUSTSTORE=`echo ${Value} | sed 's/ //g'`


Plain_SectionPrint "The following steps use the input parameters of the test and are based on the Mailer java program from patch 3265133 (`Show_Metalink 225947.1`)" NO_LIST_TAG
Empty_Line

# reminder: the Mailer attached to this test requires OWF.G to be installed (because it extends SvcComponent)
#                   OWF.G (included in 11.5.9) is installed if the test did not quit at the beginning


if [ "${JDK_INSTALLED}" = "NO" ]; then
  End_Pre
  WarningPrint "Required JDK (J2SE) version ${JDK_INST_VERS_REQ} not detected in the current environment. Mailer IMAP/SMTP connectivity test requires it."
  ActionWarningPrint "Please check JDK (J2SE) requirements section above"
else
  if [ "${V2C_AFJVAPRG}" != "" ];then
    if [ -f ${V2C_AFJVAPRG} ]; then
      if [ "${V2C_AF_CLASSPATH}" = "" ]; then
        End_Pre
        WarningPrint "The \"AF_CLASSPATH\" setting is missing. Mailer IMAP/SMTP connectivity test requires it."
        ActionWarningPrint "Please check JDK Requirements section above"
      else
        # If test is running from patch directory, include the j??????.zip in the classpath
        CLASSPATCH_ZIP=`ls ../../j*.zip 2>&1`
        if [ "$?" = "0" ]; then
          if [ "${OS_NAME}" = "Windows_NT" ]; then
            V2C_AF_CLASSPATH_EXTENDED="$CLASSPATCH_ZIP;$V2C_AF_CLASSPATH"
          else
            V2C_AF_CLASSPATH_EXTENDED="$CLASSPATCH_ZIP:$V2C_AF_CLASSPATH"
          fi
        else
          # Apparently not running from patch, expect classes to be in OA_JAVA
          V2C_AF_CLASSPATH_EXTENDED="$V2C_AF_CLASSPATH"
        fi


        #D #############################################################
        #D    IMAP Connectivity
        #D
        #D #############################################################

        SectionPrint "IMAP Connectivity (Inbound Email Processing)"

        if [ "${JAVA_MAILER_INBOUND_PASSWORD_P}" = "" ]; then
          End_Pre
          WarningPrint "Inbound password input parameter is required (because encrypted password is stored in the database)"
          ActionWarningPrint "Restart the test and enter parameter"
        else
          if [ "${JAVA_MAILER_ACCOUNT_P}" = "" -o "${JAVA_MAILER_INBOUND_SERVER_P}" = "" ]; then
            End_Pre
            WarningPrint "Inbound parameters (inbound server, account and inbound password) must be set. These are needed for IMAP connection."
            ActionWarningPrint "Verify configuration in Email Setup section above. Restart the diagnostic test and enter parameters for testing purposes."
          else
            Plain_SectionPrint "Starting $JAVA_MAILER_INBOX_P test. Result of (it can take ${TIMEOUT_DEFAULT} seconds to finish because of the timeout parameter):${LINE_FEED}\
$V2C_AFJVAPRG -classpath \"${V2C_AF_CLASSPATH_EXTENDED}\" -Dprotocol=$JAVA_MAILER_INBOUND_PROTOCOL_P \
-Dserver=$JAVA_MAILER_INBOUND_SERVER_P -Daccount=$JAVA_MAILER_ACCOUNT_P -Dssl=$INBOUND_SSL_ENABLED -Dtruststore=$MAILER_SSL_TRUSTSTORE \
-Ddbcfile=$FND_SECURE/$APPS_DATABASE_ID.dbc \
-Dconnect_timeout=${TIMEOUT_DEFAULT} -Dfolder=$JAVA_MAILER_INBOX_P oracle.apps.fnd.wf.mailer.Mailer" NO_LIST_TAG
            Empty_Line

            # Execute java program to get a list of folders in the account. The list of folders is
            # spooled to the logfile for including in the zip file. The account password is read on
            # command line by the java program.
            echo $JAVA_MAILER_INBOUND_PASSWORD_P | $V2C_AFJVAPRG -classpath "${V2C_AF_CLASSPATH_EXTENDED}" \
              -Dprotocol=$JAVA_MAILER_INBOUND_PROTOCOL_P -Dserver=$JAVA_MAILER_INBOUND_SERVER_P \
              -Ddebug=Y -Dfolder_usage=count -Daccount=$JAVA_MAILER_ACCOUNT_P -Dssl=$INBOUND_SSL_ENABLED -Dtruststore=$MAILER_SSL_TRUSTSTORE \
              -Dpassword=$JAVA_MAILER_INBOUND_PASSWORD_P -Ddbcfile=$FND_SECURE/$APPS_DATABASE_ID.dbc \
              -Dconnect_timeout=${TIMEOUT_DEFAULT} -Dfolder=$JAVA_MAILER_INBOX_P \
              -Dlogfile=${OUT_DIR}/${PRD}_folderlist.txt \
               oracle.apps.fnd.wf.mailer.Mailer 1>/dev/null 2>&1


            Plain_SectionPrint "Starting ${JAVA_MAILER_DISCARD_P} test. Result of (it can take ${TIMEOUT_DEFAULT} seconds to finish because of the timeout parameter):${LINE_FEED}\
$V2C_AFJVAPRG -classpath \"${V2C_AF_CLASSPATH_EXTENDED}\" -Dprotocol=$JAVA_MAILER_INBOUND_PROTOCOL_P \
-Dserver=$JAVA_MAILER_INBOUND_SERVER_P -Daccount=$JAVA_MAILER_ACCOUNT_P -Dssl=$INBOUND_SSL_ENABLED -Dtruststore=$MAILER_SSL_TRUSTSTORE \
-Ddbcfile=$FND_SECURE/$APPS_DATABASE_ID.dbc \
-Dconnect_timeout=${TIMEOUT_DEFAULT} -Dfolder=${JAVA_MAILER_DISCARD_P} oracle.apps.fnd.wf.mailer.Mailer" NO_LIST_TAG
            Empty_Line
 
            echo $JAVA_MAILER_INBOUND_PASSWORD_P | $V2C_AFJVAPRG -classpath "${V2C_AF_CLASSPATH_EXTENDED}" \
              -Dprotocol=$JAVA_MAILER_INBOUND_PROTOCOL_P -Dserver=$JAVA_MAILER_INBOUND_SERVER_P \
              -Ddebug=Y -Dfolder_usage=count -Daccount=$JAVA_MAILER_ACCOUNT_P -Dssl=$INBOUND_SSL_ENABLED -Dtruststore=$MAILER_SSL_TRUSTSTORE \
              -Dpassword=$JAVA_MAILER_INBOUND_PASSWORD_P -Ddbcfile=$FND_SECURE/$APPS_DATABASE_ID.dbc \
              -Dconnect_timeout=${TIMEOUT_DEFAULT} -Dfolder=${JAVA_MAILER_DISCARD_P} \
              -Dlogfile=${OUT_DIR}/${PRD}_folderlist.txt \
               oracle.apps.fnd.wf.mailer.Mailer 1>/dev/null 2>&1 
               
            Plain_SectionPrint "Starting ${JAVA_MAILER_PROCESS} test. Result of (it can take ${TIMEOUT_DEFAULT} seconds to finish because of the timeout parameter):${LINE_FEED}\
$V2C_AFJVAPRG -classpath \"${V2C_AF_CLASSPATH_EXTENDED}\" -Dprotocol=$JAVA_MAILER_INBOUND_PROTOCOL_P \
-Dserver=$JAVA_MAILER_INBOUND_SERVER_P -Daccount=$JAVA_MAILER_ACCOUNT_P -Dssl=$INBOUND_SSL_ENABLED -Dtruststore=$MAILER_SSL_TRUSTSTORE \
-Ddbcfile=$FND_SECURE/$APPS_DATABASE_ID.dbc \
-Dconnect_timeout=${TIMEOUT_DEFAULT} -Dfolder=${JAVA_MAILER_PROCESS} oracle.apps.fnd.wf.mailer.Mailer" NO_LIST_TAG
            Empty_Line
               
               
            echo $JAVA_MAILER_INBOUND_PASSWORD_P | $V2C_AFJVAPRG -classpath "${V2C_AF_CLASSPATH_EXTENDED}" \
              -Dprotocol=$JAVA_MAILER_INBOUND_PROTOCOL_P -Dserver=$JAVA_MAILER_INBOUND_SERVER_P \
              -Ddebug=Y -Dfolder_usage=count -Daccount=$JAVA_MAILER_ACCOUNT_P -Dssl=$INBOUND_SSL_ENABLED -Dtruststore=$MAILER_SSL_TRUSTSTORE \
              -Dpassword=$JAVA_MAILER_INBOUND_PASSWORD_P -Ddbcfile=$FND_SECURE/$APPS_DATABASE_ID.dbc \
              -Dconnect_timeout=${TIMEOUT_DEFAULT} -Dfolder=${JAVA_MAILER_PROCESS} \
              -Dlogfile=${OUT_DIR}/${PRD}_folderlist.txt \
               oracle.apps.fnd.wf.mailer.Mailer 1>/dev/null 2>&1               

            if [ -r ${OUT_DIR}/${PRD}_folderlist.txt ]; then

              MAILER_IMAP_OUTPUT=`cat ${OUT_DIR}/${PRD}_folderlist.txt`

              End_Pre
              Begin_Pre NO_LIST_TAG
              Tab0Print "$MAILER_IMAP_OUTPUT" NO_LIST_TAG
              End_Pre NO_LIST_TAG

              # added -i to grep to remove the case sensitivity
              FOLDERS_LISTED=`grep -i "folders defined" ${OUT_DIR}/${PRD}_folderlist.txt`
              if [ "${FOLDERS_LISTED}" != "" ]; then
                INBOX_FOLDER_LISTED=`grep "^${JAVA_MAILER_INBOX_P}$" ${OUT_DIR}/${PRD}_folderlist.txt`
                  if [ "${INBOX_FOLDER_LISTED}" = "" ]; then
                  ErrorPrint "The inbound mail account ('$JAVA_MAILER_ACCOUNT_P') does not have the inbox folder ('$JAVA_MAILER_INBOX_P') defined"
                  ActionErrorPrint "Create such folder for the account or modify Mailer configuration using `Show_Metalink 231286.1 NOHEADER`"
                else
                  SuccessPrint "Folder '${JAVA_MAILER_INBOX_P}' exists"
                fi

                # After rollup patch 4 exactly patch 2982342 remove the case sensitivity
                Check_Patch 2982342 "JAVA MAILER FOLDERS OF DISCARD AND PROCESSED ARE CASE SENSITIVE" "" SILENT
                if [ "${PATCH_FNDA}" = "" ]; then
                  DISCARD_FOLDER_LISTED=`grep "${JAVA_MAILER_DISCARD_P}" ${OUT_DIR}/${PRD}_folderlist.txt`
                else
                  DISCARD_FOLDER_LISTED=`grep -i "${JAVA_MAILER_DISCARD_P}" ${OUT_DIR}/${PRD}_folderlist.txt`
                fi

                if [ "${DISCARD_FOLDER_LISTED}" = "" ]; then
                  ErrorPrint "The inbound mail account ('$JAVA_MAILER_ACCOUNT_P') does not have the discard folder ('$JAVA_MAILER_DISCARD_P') defined"
                  ActionErrorPrint "Create such folder for the account or modify Mailer configuration using `Show_Metalink 231286.1 NOHEADER`"
                else
                  SuccessPrint "Folder '${JAVA_MAILER_DISCARD_P}' exists"
                fi
 
                # After rollup patch 4 exactly patch 2982342 remove the case sensitivity
                if [ "${PATCH_FNDA}" = "" ]; then
                  PROCESS_FOLDER_LISTED=`grep "${JAVA_MAILER_PROCESS_P}" ${OUT_DIR}/${PRD}_folderlist.txt`
                else
                  PROCESS_FOLDER_LISTED=`grep -i "${JAVA_MAILER_PROCESS_P}" ${OUT_DIR}/${PRD}_folderlist.txt`
                fi

                if [ "${PROCESS_FOLDER_LISTED}" = "" ]; then
                  ErrorPrint "The inbound mail account ('$JAVA_MAILER_ACCOUNT_P') does not have the process folder ('$JAVA_MAILER_PROCESS_P') defined"
                  ActionErrorPrint "Create such folder for the account or modify Mailer configuration using `Show_Metalink 231286.1 NOHEADER`"
                else
                  SuccessPrint "Folder '${JAVA_MAILER_PROCESS_P}' exists"
                fi
              else
                # Treat the Exceptions in the output
                EXCEPTIONS_FOUND=`grep -i "Exception in thread" ${OUT_DIR}/${PRD}_folderlist.txt`
                if [ "${EXCEPTIONS_FOUND}" != "" ]; then
                  ErrorPrint "Exceptions found in the output"
                  ActionErrorPrint "Please apply the latest Workflow rollup patch. \
See section \"Patches\" for currently installed patches and references to latest available ones."
                else
                  WarningPrint "Expected string \"folders defined\" not found in output"
                  ActionWarningPrint "Review ${PRD}_folderlist.txt to see if folders are listed."
                fi
              fi
            else
              Tab1Print "Unable to read the output file from IMAP connection containing the folder list"
            fi
          fi
        fi

        #D #############################################################
        #D    SMTP Connectivity
        #D
        #D #############################################################
        
        Begin_Pre
        SectionPrint "SMTP Connectivity (Outbound Email Processing)"
        
        TIMEOUT_DEFAULT=30
        
        if [ "${JAVA_MAILER_OUTBOUND_SERVER_P}" = "" -o "${JAVA_MAILER_REPLYTO_P}" = "" ]; then
          End_Pre
          WarningPrint "Outbound parameters (outbound server and reply to) must be set. These are needed for SMTP connection."
          ActionWarningPrint "Verify configuration in Email Setup section above. Restart the diagnostic test and enter parameters for testing purposes."
        else

          Empty_Line
          Plain_SectionPrint "Result of (it can take ${TIMEOUT_DEFAULT}s to finish because of the timeout parameter):${LINE_FEED}\
$V2C_AFJVAPRG -classpath \"${V2C_AF_CLASSPATH_EXTENDED}\" \
-Dprotocol=$JAVA_MAILER_OUTBOUND_PROTOCOL_P -Dserver=$JAVA_MAILER_OUTBOUND_SERVER_P \
-Daccount=$JAVA_MAILER_REPLYTO_P -Ddbcfile=$FND_SECURE/$APPS_DATABASE_ID.dbc\
-Dconnect_timeout=${TIMEOUT_DEFAULT} oracle.apps.fnd.wf.mailer.Mailer" NO_LIST_TAG
          Empty_Line

          # spool the output to a file to check for exceptions
          # No need for a password with SMTP
          $V2C_AFJVAPRG -classpath "${V2C_AF_CLASSPATH_EXTENDED}" \
            -Dprotocol=$JAVA_MAILER_OUTBOUND_PROTOCOL_P -Dserver=$JAVA_MAILER_OUTBOUND_SERVER_P \
            -Daccount=$JAVA_MAILER_REPLYTO_P -Dlogfile=${OUT_DIR}/${PRD}_smtpout.txt \
            -Ddebug=Y -Ddbcfile=$FND_SECURE/$APPS_DATABASE_ID.dbc -Dpassword=$JAVA_MAILER_INBOUND_PASSWORD_P \
            -Dconnect_timeout=${TIMEOUT_DEFAULT} oracle.apps.fnd.wf.mailer.Mailer 1>/dev/null 2>&1

          if [ -r ${OUT_DIR}/${PRD}_smtpout.txt ]; then
            MAILER_SMTP_OUTPUT=`cat ${OUT_DIR}/${PRD}_smtpout.txt`

            End_Pre  
            Begin_Pre NO_LIST_TAG
            Tab0Print "$MAILER_SMTP_OUTPUT" NO_LIST_TAG
            End_Pre NO_LIST_TAG

            # sciobanu: Treat the Exceptions in the output
            EXCEPTIONS_FOUND=`grep -i "Exception in thread" ${OUT_DIR}/${PRD}_smtpout.txt`
            if [ "${EXCEPTIONS_FOUND}" != "" ]; then
              ErrorPrint "Exceptions found in the output"
              ActionErrorPrint "Please apply the latest Workflow rollup patch. \
See section \"Patches\" for currently installed patches and references to latest available ones."
            fi

            # sciobanu: added a notice message to warn for invalid replyto addresses
            if [ "${JAVA_MAILER_REPLYTO_P}" != "" ]; then
              NoticePrint "If using outbound notifications please ensure that reply to address (REPLYTO) '$JAVA_MAILER_REPLYTO_P' \
is valid. The SMTP connectivity test does not guarantee that this address is valid."
            fi
          else
            Tab1Print "Unable to read the output file from the SMTP connection"
          fi
        fi
      fi
    else
      End_Pre
      WarningPrint "Cannot find the file '${V2C_AFJVAPRG}'. Mailer IMAP/SMTP connectivity test requires it."
      ActionWarningPrint "Please check JDK Requirements section above"
    fi
  else
    End_Pre
    ErrorPrint "The \"AFJVAPRG\" setting is missing. Mailer IMAP/SMTP connectivity test requires it."
    ActionErrorPrint "Please check JDK Requirements section above"
  fi
fi



        #D #############################################################
        #D    HTTP(S) Connectivity
        #D
        #D #############################################################
        
        Begin_Pre
        SectionPrint "HTTP(S) Connectivity (Outbound Email Processing)"
        
                # gggrant: fixing Sun issue
	        if [ "${OS_NAME}" = "SunOS" ]; then
	         LD_LIBRARY_PATH=${AF_LD_LIBRARY_PATH}:
	         export LD_LIBRARY_PATH
	        else
	         export LD_LIBRARY_PATH=${AF_LD_LIBRARY_PATH}
        	fi

# Get a FWK=Y notification_id

	SQL="select wfn.notification_id from wf_notifications wfn
	where wf_notification.isFwkBody(notification_id)='Y'
	and status = 'OPEN'
	and rownum=1
	and notification_id = (select max(notification_id) from wf_notifications wfn2
	where wfn.notification_id = wfn2.notification_id)
	order by notification_id desc;"
	
Get_DB_Value
MAILER_NID=`echo ${Value} | sed 's/ //g'`

          Empty_Line
          Plain_SectionPrint "Result of (it can take ${TIMEOUT_DEFAULT}s to finish because of the timeout parameter):${LINE_FEED}\
$V2C_AFJVAPRG -classpath \"${V2C_AF_CLASSPATH_EXTENDED}\" \
-Dnid=$MAILER_NID -Dhtp=https \
-DAFLOG_LEVEL=STATEMENT -DAFLOG_ENABLED=true \
-Dappuser=0 -Dappresp=20420 \
-Dappid=1 -Ddbcfile=$FND_SECURE/$APPS_DATABASE_ID.dbc \
-Durltimeout=${TIMEOUT_DEFAULT} oracle.apps.fnd.wf.mailer.Mailer" NO_LIST_TAG
          Empty_Line

          # spool the output to a file to check for exceptions
          # No need for a password with HTTP
          $V2C_AFJVAPRG -classpath "${V2C_AF_CLASSPATH_EXTENDED}" \
            -Dnid=$MAILER_NID -Dhtp=https \
            -DAFLOG_LEVEL=STATEMENT -DAFLOG_ENABLED=true \
            -Dappuser=0 -Dappresp=20420 \
            -Dappid=1 -Dlogfile=${OUT_DIR}/${PRD}_httpsout.txt \
            -Ddbcfile=$FND_SECURE/$APPS_DATABASE_ID.dbc \
            -Durltimeout=${TIMEOUT_DEFAULT} oracle.apps.fnd.wf.mailer.Mailer 1>/dev/null 2>&1

          if [ -r ${OUT_DIR}/${PRD}_httpout.txt ]; then
            MAILER_HTTPS_OUTPUT=`cat ${OUT_DIR}/${PRD}_httpsout.txt`

            End_Pre  
            Begin_Pre NO_LIST_TAG
            #Tab0Print "$MAILER_HTTPS_OUTPUT" NO_LIST_TAG
            End_Pre NO_LIST_TAG
          fi



#D #############################################################
#D    Profile Options
#D 
#D #############################################################

Begin_Pre
SectionPrint "Profile Options"


Show_Profile_Option Name "CONC_GSM_ENABLED" SILENT "" SITE
CONC_GSM_ENABLED=`${ECHO} ${Value} | tr [:lower:] [:upper:]`
Tab1Print "Concurrent:GSM Enabled = \"${CONC_GSM_ENABLED}\""
if [ "${CONC_GSM_ENABLED}" != "Y" ]; then
  End_Pre
  ErrorPrint "GSM is not enabled"
  ActionErrorPrint "Please set \"Concurrent:GSM Enabled\" profile option to 'Y'"
  Begin_Pre
fi


Show_Profile_Option Name "APPS_FRAMEWORK_AGENT" SILENT "" SITE
Tab1Print "Application Framework Agent profile (APPS_FRAMEWORK_AGENT) = \"${Value}\""


Show_Profile_Option Name "WF_MAIL_WEB_AGENT" SILENT "" SITE
Tab1Print "WF: Workflow Mailer Framework Web Agent (WF_MAIL_WEB_AGENT) = \"${Value}\""

End_Pre



#D #############################################################
#D ** Logfiles
#D 
#D #############################################################

SectionHeader "Logfiles"

# svarga: default values of APPLCSF and APPLLOG
if [ "${APPLCSF}" = "" ]; then
  APPLCSF=$FND_TOP
  if [ "${APPLLOG}" = "" ]; then
    APPLLOG_MESSAGE="APPLLOG is not set, it will be defaulted to log."
    APPLLOG=log
  else
    APPLLOG_MESSAGE=""
  fi
  Tab0Print "APPLCSF environment variable is not set, the test uses \$FND_TOP for APPLCSF. ${APPLLOG_MESSAGE}" NO_LIST_TAG
fi

#D #############################################################
#D    Run wfver.sql
#D 
#D #############################################################

# sciobanu: added a message for long running wfver.sql


Begin_Pre
Plain_SectionPrint "Running wfver.sql (it can take few minutes to finish)"


if [ -r ${FND_TOP}/sql/wfver.sql ]; then
  End_Pre
  Run_SQL_File ${FND_TOP}/sql/wfver.sql "" SAVE ${PRD}_wfver_sql.txt
  
  # svarga: to show the first 300 line of the wfver.sql output
  if [ "${internal_output}" = "html" ]; then
    if [ -r ${PRD}_wfver_sql.txt ]; then
      if [ "${OS_NAME}" = "Windows_NT" ]; then
        wfver_tmp=`head -300 ${PRD}_wfver_sql.txt | tr "\n" "" | sed -e 's//<BR>/g' | tr -d "\r"`
      else
        # svarga: fixing Sun issue
        if [ "${OS_NAME}" = "SunOS" ]; then
          SED="/usr/xpg4/bin/sed"
        else
          SED="sed"
        fi
        # svarga: usually the following works on Linux & NT and on Solaris with GNU sed but not on HP
        # wfver_tmp=`head -300 ${PRD}_wfver_sql.txt | tr "\n" "" | $SED -e 's//<BR>/g'`
        wfver_tmp0=`head -300 ${PRD}_wfver_sql.txt | tr "\n" ""`
        wfver_tmp=`$ECHO $wfver_tmp0 | $SED -e 's//<BR>/g'`
      fi
      cat << EOJS!
<script LANGUAGE="javascript">
wfver="${wfver_tmp}"
</script>
<A HREF="javascript:document.write('<A HREF=javascript:window.history.go(-1);>Back</A><BR>'+wfver+'<BR>');">First 300 lines of wfver.sql output</A><BR>
EOJS!
    fi
  fi
  
else
  Tab1Print "Unable to find the file \$FND_TOP/sql/wfver.sql"
  End_Pre
fi

#D #############################################################
#D    Run wfmlrdbg.sql
#D 
#D #############################################################

# gggrant: added wfmlrdbg.sql

Empty_Line

Begin_Pre
Plain_SectionPrint "Running wfmlrdbg.sql for a test notification_id"

# Get a FWK=Y notification_id

	SQL="select wfn.notification_id from wf_notifications wfn
	where wf_notification.isFwkBody(notification_id)='Y'
	and status = 'OPEN'
	and rownum=1
	and notification_id = (select max(notification_id) from wf_notifications wfn2
	where wfn.notification_id = wfn2.notification_id)
	order by notification_id desc;"
	
Get_DB_Value
MAILER_NID=`echo ${Value} | sed 's/ //g'`

if [ -r ${FND_TOP}/sql/wfmlrdbg.sql ]; then
  End_Pre
  Run_SQL_File ${FND_TOP}/sql/wfmlrdbg.sql $MAILER_NID""
  
  NRLINES=1000000
      WFMLRDBG_FILENAME=`${ECHO} wfmlrdbg${MAILER_NID}.html | awk -F"/" '{ print $NF }'`
      tail -${NRLINES} wfmlrdbg${MAILER_NID}.html > ${OUT_DIR}/${PRD}_${WFMLRDBG_FILENAME}
    SuccessPrint "Copied the last ${NRLINES} lines of the file to ${PRD}_${WFMLRDBG_FILENAME}"
  
else
  Tab1Print "Unable to find the file \$FND_TOP/sql/wfmlrdbg.sql"
  End_Pre
fi


#D #############################################################
#D    Run atg_supp_wf_email_notifications.sql
#D 
#D #############################################################

# gggrant: added atg_supp_wf_email_notifications.sql catchall expansion script.

Begin_Pre
Plain_SectionPrint "Running atg_supp_wf_email_notifications.sql to list all email notification events"


if [ -r atg_supp_wf_email_notifications.sql ]; then
  End_Pre
  Run_SQL_File atg_supp_wf_email_notifications.sql""
  
  NRLINES=1000000
      ATGSUPPWFEN_FILENAME=`${ECHO} wf_email_notifications.html | awk -F"/" '{ print $NF }'`
      tail -${NRLINES} wf_email_notifications.html > ${OUT_DIR}/${PRD}_${ATGSUPPWFEN_FILENAME}
    SuccessPrint "Copied the last ${NRLINES} lines of the file to ${PRD}_${ATGSUPPWFEN_FILENAME}"
  
else
  Tab1Print "Unable to find the file \atg_supp_wf_email_notifications.sql"
  End_Pre
fi


#D #############################################################
#D    Internal Manager
#D 
#D #############################################################

Begin_Pre
SectionPrint "Internal Manager"
# For NT: Convert backslash to slash
SQL="select replace(fcp.logfile_name,'\\','/')
  from fnd_concurrent_processes fcp, fnd_concurrent_queues fcq
 where fcp.concurrent_queue_id = fcq.concurrent_queue_id
   and fcp.queue_application_id = fcq.application_id
   and fcq.manager_type = '0'
   and fcp.process_status_code = 'A'
/
"
Get_DB_Value
ICM_LOGFILENAME=$Value

SQL="select MAX_PROCESSES from FND_CONCURRENT_QUEUES where CONCURRENT_QUEUE_NAME='FNDICM';"
Get_DB_Value
ICM_MAXPROCESSES=$Value
SQL="select RUNNING_PROCESSES from FND_CONCURRENT_QUEUES where CONCURRENT_QUEUE_NAME='FNDICM';"
Get_DB_Value
ICM_RUNPROCESSES=$Value

# Print status of Concurrent Manager (running or not)
if [ "${ICM_MAXPROCESSES}" = "" -o "${ICM_RUNPROCESSES}" = "" ]; then
  Tab1Print "Internal Manager is not active"
  FNDICM_UP=n
else
  Tab1Print "Internal Manager is active"
  FNDICM_UP=y
fi

# If not known, not existing or not readable ...
if [ "${ICM_LOGFILENAME}" = "" ]; then
  Tab1Print "No value found for the logfile name in table FND_CONCURRENT_QUEUES"
  End_Pre
else
  SuccessPrint "Logfile name = \"${ICM_LOGFILENAME}\""
  if [ ! -r ${ICM_LOGFILENAME} ]; then
    End_Pre
    ErrorPrint "Unable to read the file"
    ActionErrorPrint "The file may be deleted, this test is not running on the Concurrent Manager node or \
the current user (${USER}) does not have privileges to access the file"
  else
    NRLINES=200
    ICM_FILENAME=`${ECHO} ${ICM_LOGFILENAME} | awk -F"/" '{ print $NF }'`
    tail -${NRLINES} ${ICM_LOGFILENAME} > ${OUT_DIR}/${PRD}_${ICM_FILENAME}
    SuccessPrint "Copied the last ${NRLINES} lines of the file to ${PRD}_${ICM_FILENAME}"
    End_Pre
  fi
fi


#D #############################################################
#D    Service Manager
#D 
#D #############################################################

Begin_Pre
SectionPrint "Service Manager"

# svarga: future enhancment can be to get the log file name from fnd_concurrent_processes.logfile_name

ls -rt ${APPLCSF}/${APPLLOG}/FNDSM* >${OUT_DIR}/${PRD}_FNDSMFILES.txt 2>&1
ERROR_CODE=$?

# Check if any files were found (ls will have returned errorcode for this)
if [ ${ERROR_CODE} -eq 0 ]; then
  FNDSM_FILE1=`tail -1 ${OUT_DIR}/${PRD}_FNDSMFILES.txt 2>/dev/null | awk -F"/" '{ print $NF }'`
  Get_File "${APPLCSF}/${APPLLOG}/${FNDSM_FILE1}" "${PRD}_${FNDSM_FILE1}" SILENT
  Tab1Print "File \"${FNDSM_FILE1}\" copied to \"${PRD}_${FNDSM_FILE1}\""

  if [ `wc -l ${OUT_DIR}/${PRD}_FNDSMFILES.txt | awk '{print $1}'` -gt 1 ]; then
    FNDSM_FILE2=`tail -2 ${OUT_DIR}/${PRD}_FNDSMFILES.txt 2>/dev/null | head -1 | awk -F"/" '{ print $NF }'`
    Get_File "${APPLCSF}/${APPLLOG}/${FNDSM_FILE2}" "${PRD}_${FNDSM_FILE2}" SILENT
    Tab1Print "File \"${FNDSM_FILE2}\" copied to \"${PRD}_${FNDSM_FILE2}\""
  fi
else
  Tab1Print "No files found starting with \"FNDSM\" in directory \"\$APPLCSF/\$APPLLOG\" ($APPLCSF/$APPLLOG)"
fi
rm -f ${OUT_DIR}/${PRD}_FNDSMFILES.txt
End_Pre


#D #############################################################
#D    Workflow Mailer and Agent Listener Services
#D 
#D #############################################################

Begin_Pre
SectionPrint "Workflow Mailer and Agent Listener Services"
End_Pre

Empty_Line

Begin_Pre

	SQL="select fcp.logfile_name
		 FROM fnd_concurrent_queues fcq, fnd_concurrent_processes fcp, fnd_lookups flkup
		 WHERE concurrent_queue_name in ('WFALSNRSVC')
		 AND fcq.concurrent_queue_id = fcp.concurrent_queue_id
		 AND fcq.application_id = fcp.queue_application_id
		 AND flkup.lookup_code=fcp.process_status_code
		 AND lookup_type ='CP_PROCESS_STATUS_CODE'
		 AND flkup.meaning='Active'
		/
		"
	Get_DB_Value
	WFALSNRSVC=`echo ${Value} | sed 's/ //g'`

	SQL="select fcp.logfile_name
		 FROM fnd_concurrent_queues fcq, fnd_concurrent_processes fcp, fnd_lookups flkup
		 WHERE concurrent_queue_name in ('WFMLRSVC')
		 AND fcq.concurrent_queue_id = fcp.concurrent_queue_id
		 AND fcq.application_id = fcp.queue_application_id
		 AND flkup.lookup_code=fcp.process_status_code
		 AND lookup_type ='CP_PROCESS_STATUS_CODE'
		 AND flkup.meaning='Active'
		/
		"
	Get_DB_Value
	WFMLRSVC2=`echo ${Value} | sed 's/ //g'`
	
	SQL="select '../ATGSuppJavaMailerSetup12/' || replace(substr(fcp.logfile_name, instr(fcp.logfile_name,'/',-1)+1),'.txt','.log')
		 FROM fnd_concurrent_queues fcq, fnd_concurrent_processes fcp, fnd_lookups flkup
		 WHERE concurrent_queue_name in ('WFMLRSVC')
		 AND fcq.concurrent_queue_id = fcp.concurrent_queue_id
		 AND fcq.application_id = fcp.queue_application_id
		 AND flkup.lookup_code=fcp.process_status_code
		 AND lookup_type ='CP_PROCESS_STATUS_CODE'
		 AND flkup.meaning='Active'
		/
		"
	Get_DB_Value
	WFMLRSVC=`echo ${Value} | sed 's/ //g'`
	
	Tab1Print "Workflow Mailer Log file is \"${WFMLRSVC2}\""
	Tab1Print "Workflow Mailer Log file is renamed to \"${WFMLRSVC}\""
	Tab1Print "Workflow	Agent Listener Log file is \"${WFALSNRSVC}\""


echo "Workflow Mailer Log file is \"${WFMLRSVC2}\"" >> $LOGFILE
echo "Workflow Mailer Log file is renamed to \"${WFMLRSVC}\"" >> $LOGFILE
echo "Workflow Agent Listener Log file is \"${WFALSNRSVC}\"" >> $LOGFILE


	echo ${WFALSNRSVC} >${OUT_DIR}/${PRD}_WFSERVFILES.txt 2>&1
	ERROR_CODE=$?
	echo ${WFMLRSVC2} >>${OUT_DIR}/${PRD}_WFSERVFILES.txt 2>&1
	ERROR_CODE=$?
	echo ${WFMLRSVC} >>${OUT_DIR}/${PRD}_WFSERVFILES.txt 2>&1
	ERROR_CODE=$?

#  ls -rt ${APPLCSF}/${APPLLOG}/FNDCPGSC* >${OUT_DIR}/${PRD}_WFSERVFILES.txt 2>&1
#  ERROR_CODE=$?

# Check if any files were found (ls will have returned errorcode for this)
if [ ${ERROR_CODE} -eq 0 ]; then
  WFSERV_FILE1=`tail -1 ${OUT_DIR}/${PRD}_WFSERVFILES.txt 2>/dev/null | awk -F"/" '{ print $NF }'`
  Get_File "${APPLCSF}/${APPLLOG}/${WFSERV_FILE1}" "${PRD}_${WFSERV_FILE1}" SILENT
  Tab1Print "File \"${WFSERV_FILE1}\" copied to \"${PRD}_${WFSERV_FILE1}\""
  echo "File \"${WFSERV_FILE1}\" copied to \"${PRD}_${WFSERV_FILE1}\"" >> $LOGFILE

  if [ `wc -l ${OUT_DIR}/${PRD}_WFSERVFILES.txt 2>/dev/null | awk '{print $1}'` -gt 1 ]; then
    WFSERV_FILE2=`tail -2 ${OUT_DIR}/${PRD}_WFSERVFILES.txt | head -1 | awk -F"/" '{ print $NF }'`
    Get_File "${APPLCSF}/${APPLLOG}/${WFSERV_FILE2}" "${PRD}_${WFSERV_FILE2}" SILENT
    Tab1Print "File \"${WFSERV_FILE2}\" copied to \"${PRD}_${WFSERV_FILE2}\""
	echo "File \"${WFSERV_FILE2}\" copied to \"${PRD}_${WFSERV_FILE2}\"" >> $LOGFILE
  fi
else
  Tab1Print "No files found starting with \"FNDCPGSC\" in directory \"\$APPLCSF/\$APPLLOG\" ($APPLCSF/$APPLLOG)"
  echo "No files found starting with \"FNDCPGSC\" in directory \"\$APPLCSF/\$APPLLOG\" ($APPLCSF/$APPLLOG)" >> $LOGFILE
fi
rm -f ${OUT_DIR}/${PRD}_WFSERVFILES.txt
End_Pre


#D #############################################################
#D    Debug Service
#D 
#D #############################################################

Begin_Pre
SectionPrint "Debug Service"

# Check for DEBUGSVC* files (not case sensitive)
ls -rt ${APPLCSF}/${APPLLOG}/[Dd][Ee][Bb][Uu][Gg][Ss][Vv][Cc]* >${OUT_DIR}/${PRD}_DEBUGSVCFILES.txt 2>&1
ERROR_CODE=$?

# Check if any files were found (ls will have returned errorcode for this)
if [ ${ERROR_CODE} -eq 0 ]; then
  DEBUGSVC_FILE1=`tail -1 ${OUT_DIR}/${PRD}_DEBUGSVCFILES.txt 2>/dev/null | awk -F"/" '{ print $NF }'`
  Get_File "${APPLCSF}/${APPLLOG}/${DEBUGSVC_FILE1}" "${PRD}_${DEBUGSVC_FILE1}" SILENT
  Tab1Print "File \"${DEBUGSVC_FILE1}\" copied to \"${PRD}_${DEBUGSVC_FILE1}\""
  echo "File \"${DEBUGSVC_FILE1}\" copied to \"${PRD}_${DEBUGSVC_FILE1}\"" >> $LOGFILE

  if [ `wc -l ${OUT_DIR}/${PRD}_DEBUGSVCFILES.txt | awk '{print $1}'` -gt 1 ]; then
    DEBUGSVC_FILE2=`tail -2 ${OUT_DIR}/${PRD}_DEBUGSVCFILES.txt 2>/dev/null | head -1 | awk -F"/" '{ print $NF }'`
    Get_File "${APPLCSF}/${APPLLOG}/${DEBUGSVC_FILE2}" "${PRD}_${DEBUGSVC_FILE2}" SILENT
    Tab1Print "File \"${DEBUGSVC_FILE2}\" copied to \"${PRD}_${DEBUGSVC_FILE2}\""
	echo "File \"${DEBUGSVC_FILE2}\" copied to \"${PRD}_${DEBUGSVC_FILE2}\"" >> $LOGFILE
  fi
  End_Pre
else
  End_Pre
  WarningPrint "No files found starting with \"DebugSvc\" in directory \"\$APPLCSF/\$APPLLOG\" ($APPLCSF/$APPLLOG)"
  ActionWarningPrint "Ensure the debug service is enabled and this test is running on the concurrent manager node \
if this file is required"
fi
rm -f ${OUT_DIR}/${PRD}_DEBUGSVCFILES.txt


# svarga: workaround for sdf_core2.txt Linux BUG
if [ "${OS_NAME}" = "Linux" ]; then
  if [ -f "/usr/bin/zip" ]; then
    ZIP="zip -q "
    UNZIP="unzip "
  else
    ZIP="NO"
    COMPRESS="gzip "
    UNCOMPRESS="gzip -d "
  fi
fi

#D #############################################################
#D    All Mailers Parameters
#D
#D #############################################################

SQL="set linesize 150
set heading off
set feed off
select component_id
from fnd_svc_components where component_type='WF_MAILER'"
Run_SQL
MAILER_IDS=`cat $OUT_DIR/$OUT_FILE.txt`
Tab1Print "Mailer component IDs: $MAILER_IDS"


SectionHeader "Mailer(s) Data"

for mlr_id in $MAILER_IDS
do 

SectionPrint "Component_id $mlr_id"

  ## Table FND_SVC_COMPONENTS
  Begin_Pre

SQL="set linesize 150
set feed off
col COMP_ID format 999999
col component_name format A50
col status format a18
col account format a50
select c.component_id COMP_ID, c.component_name, c.component_status status, acc.parameter_value account
from fnd_svc_components c
   , fnd_svc_comp_param_vals_v acc
where  c.component_type='WF_MAILER'
and acc.parameter_name (+) = 'ACCOUNT'
and c.component_id = acc.component_id
and c.component_id = ${mlr_id}"
Run_SQL
Show_SQL_Output "${OUT_DIR}/${OUT_FILE}.txt" "" 1 8 60 80

SQL="set linesize 150
set feedback off
col COMP_ID format 999999
col OPEN_INVALID format A20
col SUMMARY format A15
col WARNING format A15
select c.component_id COMP_ID
  , open_inv.parameter_value open_invalid
      , summ.parameter_value summary
      , warn.parameter_value Warning
from fnd_svc_components c
 , fnd_svc_comp_param_vals_v open_inv
 , fnd_svc_comp_param_vals_v summ
 , fnd_svc_comp_param_vals_v warn
where  c.component_type='WF_MAILER'
and  c.component_id = open_inv.component_id
and open_inv.parameter_name (+) = 'OPEN_INVALID'
and  c.component_id = summ.component_id
and summ.parameter_name (+) = 'SUMMARY'
and  c.component_id = warn.component_id
and warn.parameter_name (+) = 'WARNING'
and c.component_id = ${mlr_id}"
Run_SQL
Show_SQL_Output "${OUT_DIR}/${OUT_FILE}.txt" "" 1 22 39 56

SQL="
set linesize 150
set feedback off
col COMP_ID format 999999
col INBOUND_SERVER  format A30
col IN_PROTO format A8
col INBOX format A12
col DISCARD format A12
col process format A12
select c.component_id COMP_ID
  , ib.parameter_value INBOUND_SERVER
  , ipro.parameter_value IN_PROTO
  , ibox.parameter_value INBOX
  , dcard.parameter_value discard
  , prc.parameter_value  process    
from fnd_svc_components c
 , fnd_svc_comp_param_vals_v ib
 , fnd_svc_comp_param_vals_v ibox
 , fnd_svc_comp_param_vals_v dcard
 , fnd_svc_comp_param_vals_v prc
 , fnd_svc_comp_param_vals_v ipro
where  component_type='WF_MAILER'
and  c.component_id = ib.component_id
and ib.parameter_name (+) = 'INBOUND_SERVER'
and  c.component_id = ibox.component_id
and ibox.parameter_name (+) = 'INBOX'
and  c.component_id = dcard.component_id
and dcard.parameter_name (+) = 'DISCARD'
and  c.component_id = prc.component_id
and prc.parameter_name (+) = 'PROCESS'
and  c.component_id = ipro.component_id
and ipro.parameter_name (+) = 'INBOUND_PROTOCOL'
and c.component_id = ${mlr_id}"
Run_SQL
Show_SQL_Output "${OUT_DIR}/${OUT_FILE}.txt" "" 1 8 39 48 61 74

SQL="set linesize 150
set feedback off
col COMP_ID format 999999
col OUTBOUND_SERVER  format A35
col OUT_PROTO format A8
col REPLY_TO format A30
select c.component_id COMP_ID
  , ob.parameter_value OUTBOUND_SERVER
  , opro.parameter_value OUT_PROTO
  , rpl.parameter_value REPLY_TO
from fnd_svc_components c
 , fnd_svc_comp_param_vals_v ob
 , fnd_svc_comp_param_vals_v rpl
 , fnd_svc_comp_param_vals_v opro
where  component_type='WF_MAILER'
and  c.component_id = ob.component_id (+)
and ob.parameter_name (+) = 'OUTBOUND_SERVER'
and  c.component_id = rpl.component_id (+)
and rpl.parameter_name (+) = 'REPLY_TO'
and  c.component_id = opro.component_id (+)
and opro.parameter_name (+) = 'OUTBOUND_PROTOCOL'
and c.component_id = ${mlr_id}"
Run_SQL
Show_SQL_Output "${OUT_DIR}/${OUT_FILE}.txt" "" 1 8 44 53

SQL="
set linesize 150
set feedback off
col COMP_ID format 999999
col PROCESSOR_IN_THREAD_COUNT format A26
col PROCESSOR_OUT_THREAD_COUNT format A26
select c.component_id COMP_ID, it.parameter_value PROCESSOR_IN_THREAD_COUNT, ot.parameter_value PROCESSOR_OUT_THREAD_COUNT
FROM   fnd_svc_components c
 , fnd_svc_comp_param_vals_v it
 , fnd_svc_comp_param_vals_v ot
WHERE it.parameter_name (+) = 'PROCESSOR_IN_THREAD_COUNT'
and ot.parameter_name (+) = 'PROCESSOR_OUT_THREAD_COUNT'
and c.component_id = it.component_id (+)
and c.component_id = ot.component_id (+)
and c.component_id = ${mlr_id}"
Run_SQL
Show_SQL_Output "${OUT_DIR}/${OUT_FILE}.txt" "" 1 8 35

  End_Pre

done

#################################################
##########    END:  Main Processing Block  ######
#################################################

#DEV #############################################################
#DEV Package up all the files into a tar file 
#DEV #############################################################

Package_Files 

#DEV #############################################################
#DEV Begin Cleanup any files created or retrieved
#DEV (also needs to come after Package_files)
#DEV #############################################################

Cleanup

echo "Exiting the ATGSuppJavaMailer12.sh script...."  >> $LOGFILE

exit

