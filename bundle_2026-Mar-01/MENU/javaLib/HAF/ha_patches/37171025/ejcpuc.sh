#! /bin/bash
################################################################################
# PURPOSE
#   This script will check for java versions and report differences from the 
#   latests CPU version of Java 7 for apptiers (or 7,8,11 for DB tiers)
#
# HOW TO RUN
#    Must be run from an EBS host (App tier or DB tier) as the software owner (applmgr or oracle)
#    with the proper environment for the tier sourced
#
# COPYRIGHT
#   Copyright (c) 2025, Oracle and/or its affiliates

pgm="ejcpuc"
rcs="$Header: ejcpuc.sh,v 1.3 2025/10/21 10:30:00 egravers Exp egravers $"
rcsver="$( echo "$rcs" | awk '{print $3 "\t" $4; }' )"

    thisCPU="2025.10"    # The short YYYY.MM name of this CPU

    thisJava7="1.7.0_481"    #    Java 7 used by apptier, DBs 11,12
    thisJava8="1.8.0_471"    #    Java 8 used by DB 19
    thisJava11="11.0.29"     #    Java 11 used by DB 23
    thisoJava11="11.0.29"    #    OJVM DB 23
    thisoJava8="1.8.0_471"   #    OJVM  DB 19
    thisoJava7="1.7.0_481"    #    OJVM DB 12

appjavamsg="Follow 1530033.1 to update the JDK(s). Your application tier JDK 7 is lower than the $thisJava7 update released in CPU $thisCPU."

    ojvmmsg="o) Apply the Database Release Update (DBRU) recommended by the latest EBS CPU MOS Note referenced in Document 2484000.1"
  dbjavamsg="j) Apply the Database Release Update (DBRU) recommended by the latest EBS CPU MOS Note referenced in Document 2484000.1 and the JDK patch listed in 2584628.1"  
  dbutilmsg="u) When the DB JDK version is updated to the latest - then follow section 3 of 1530033.1 to update this JRE"
        # Java 11 (in DB23) does not have a jre directory under jdk, so link to jdk
dbutilmsg23="u) When the DB JDK version is updated to the latest - then link OH/appsutil/jre to OH/jdk"

    deaddb="Upgrade to Oracle Database 19c.  Oracle Database 12.1.0.2/11.2.0.4 is in Upgrade Support (restricted/custom) through December 31, 2024, see Document 2997711.1"


# Print usage message and exit
#---------------------------------
function usage()
{
     echo >&2 "Usage: $pgm [-V | -h | --help] " ; exit 1
}

# Print error message and exit
#---------------------------------
function errexit()
{
     echo >&2 "ERROR: $1" ; exit 1 
}

# Print header message
#---------------------------------
function header()
{
     echo "##################################################################################" 
     echo "## $1" 
     echo "## $( date '+%Y-%m-%d %T %Z' )  on  $(hostname)" 
     echo "##################################################################################" 
}

# Print less-prominent header message
#---------------------------------
function header2()
{
     echo ""
     echo "## $1" 
     echo "##################################################################################" 
}

# Compare Java versions, return SUCCESS (0) if arg1 is lower than arg2
#---------------------------------
function isLower()
{
    ### Fix Platforms : to handle java version using "awk"
    cpu=$1
    my=$2

    if [ "${PLATFORM}" = "Solaris" ] ; then
        dbver=$(   getdbver   | ${TR_CMD} -dc '[0-9]._' )
    else
        dbver=$(   getdbver   | ${TR_CMD} -dc '[0-9._]' )
    fi

    case "$dbver" in            # what Java version does this DB  use?
        23* )
            my=$(echo $my|${AWK} -F'[._]' '{print $1".0."$3}');
            cpu=$(echo $cpu|${AWK} -F'[._]' '{print $1".0."$3}');
            ;;
         *  )  
            my=$(echo $my|${AWK} -F'[._]' '{print $2".0."$4}');
            cpu=$(echo $cpu|${AWK} -F'[._]' '{print $2".0."$4}');
    esac


    res=$( ${AWK} -v cpu=$cpu -v my=$my 'BEGIN {

        #my =gensub("1.([0-9]*).0[._]([0-9]*)","\\1.0.\\2", "g", my);   # 1.7.0_421 -> 7.0.421
        #cpu=gensub("1.([0-9]*).0[._]([0-9]*)","\\1.0.\\2", "g",cpu);   # 11.0.23 is unchanged

        m=split( my,mA,".");
        c=split(cpu,cA,".");

         if ( m != 3 || c != 3 ) { print "isLower: Panic! What ? not 3 ?  I see: " m " " c ; exit 1   }

        my = sprintf( "%03d%03d%03d", mA[1], mA[2], mA[3] );   # 7.0.421 -> 007000421
        cpu= sprintf( "%03d%03d%03d", cA[1], cA[2], cA[3] );

        if( my < cpu ) 
            print "lower"; # my version is lower than the cpu/latest version
        else
            print "not" ;  # my version is NOT lower than the cpu/latest version
        exit 1
    }' )
    if [ "$res" = "lower" ] ;then
        return 0  # SUCCESS
    else
        return 1  # NOT
    fi
}

# Get the database version - on DB tier just ask sqlplus
#----------------------------------------------------------
function getdbver()
{
    true |  sqlplus  | ${AWK} '/^SQL\*Plus: Release / {ver=$3} /^Version / {ver=$2}  END {print ver}'
}

# Get the version of OJVM - the Java IN the database
#-------------------------------------------------------------
function getojvmver()
{
    sql="select DBMS_JAVA.GET_OJVM_PROPERTY(PROPSTRING=>'java.version') from DUAL ;"

    # Need to connect as SYS
    # on 19c (Container+pluggable) ORACLE_SID is set incorrectly
    if [ ! -z $ORACLE_UNQNAME ] ;then
        export ORACLE_SID=$ORACLE_UNQNAME
    fi
    sqlplus -s -l / as sysdba <<EOF
set heading off
set feedback off
$sql
EOF
}

# Get the version of a java executable  1:path-to-java
#-------------------------------------------------------------
function getjver()
{
    ### Fix AIX : code to fetch minor java version
    if test "${PLATFORM}" = "IBM_AIX"; then
        ver=$($1 -version 2>&1 | ${AWK} -F"\"" '/java version/ {print $2}'| ${TR_CMD} -d '\n') 
        if [ "$ver" = "1.5.0" ] ; then
            $1 -version 2>&1 | ${AWK} -F"\"" '/java version/ {print $2}'| ${TR_CMD} -d '\n'
        else
            ver=$($1 -version 2>&1 | ${AWK} -F"\"" '/java version/ {print $2}'| ${AWK} -F'_' '{print $1}'|${TR_CMD} -d '\n') 
            $1 -version 2>&1 | ${AWK} '/based on Oracle/ {print $7}'|${AWK} -F'u' '{print $2}'|${AWK} -F'-' -v ver=$ver '{print ver "_"  $1}'
        fi
    else
        $1 -version 2>&1 | ${AWK} -F"\"" '/java version/ {print $2}'| ${TR_CMD} -d '\n'
    fi
}

# Get the bitness (32 or 64) of a java executable  1:path-to-java
#-------------------------------------------------------------
function getjbit()
{

    ### Fix Solaris : Java8 or higher can only be 64-bit but Java7 or lower is hybrid
    if [ "${PLATFORM}" = "Solaris" ] ; then
        jdkver=$(  getjver $1)
        my_str=($(echo ${jdkver} | ${TR_CMD} "." "\n"))

        if [ ${my_str[0]} -gt 1 ] ; then
            $1 -version 2>&1 |  ${AWK} 'BEGIN {bit64=0} /64-Bit/ {bit64=1} END { print (bit64==1) ? "64-bit" : "Undefined" }'
        else
            if [ ${my_str[0]} -eq 1 -a ${my_str[1]} -gt 7 ] ; then
                $1 -version 2>&1 |  ${AWK} 'BEGIN {bit64=0} /64-Bit/ {bit64=1} END { print (bit64==1) ? "64-bit" : "Undefined" }'
            else
                $1 -d32 -version 2>&1 | ${AWK} 'BEGIN {mixed=0} /mixed/ {mixed=1} END { print (mixed==1) ? "Hybrid" : "Non-Hybrid" }'
            fi
        fi

    else ### non-Solaris platforms

        if  test "${PLATFORM}" = "HP_IA"; then $1 -d32 -version 2>&1 | ${AWK} 'BEGIN {mixed=0} /mixed/ {mixed=1} END { print (mixed==1) ? "Hybrid" : "Non-Hybrid" }';
  
        elif test "${PLATFORM}" = "IBM_AIX"; then $1 -version 2>&1 | ${AWK} 'BEGIN {bit64=0} /ppc64-64/ {bit64=1} END { print (bit64==1) ? "64-bit" : "32-bit" }';
  
        else
  $1 -version 2>&1 | ${AWK} 'BEGIN {bit64=0} /64-Bit/ {bit64=1} END { print (bit64==1) ? "64-bit" : "32-bit" }'
        fi

    fi
}


# Check dbtier Java locations - OJVM and filesystem 
#-------------------------------------------------------------
function checkdbjava()
{

    header "Checking DB tier Java for CPU $thisCPU on Platform $PLATFORM"

    header2 "Check Database Version"

    ### Fix Solaris : Format of character string to tr command is different on Solaris
    if [ "${PLATFORM}" = "Solaris" ] ; then
        dbver=$(   getdbver   | ${TR_CMD} -dc '[0-9]._' )
    else
        dbver=$(   getdbver   | ${TR_CMD} -dc '[0-9._]' )
    fi
    echo "Your database version is $dbver "
    echo "         ORACLE_HOME     $ORACLE_HOME"
    echo "         ORACLE_SID      $ORACLE_SID"
    echo "         ORACLE_UNQNAME  $ORACLE_UNQNAME"

    case "$dbver" in            # what Java version does this DB  use?
        11* )   thisJava="$thisJava7" 
                thisoJava="$thisoJava7"
                ojvmmsg="o) $deaddb"
                dbjavamsg="j) $deaddb"
                dbutilmsg="u) $deaddb"
                ;;
        12* )   thisJava="$thisJava7" 
                ojvmmsg="o) $deaddb"
                thisoJava="$thisoJava7"
                dbjavamsg="j) $deaddb"
                dbutilmsg="u) $deaddb"
                ;;
        19* )   thisJava="$thisJava8" 
                thisoJava="$thisoJava8"
                ;;
        23* )   thisJava="$thisJava11" ;   
		thisoJava="$thisoJava11" ;
                # Java 11 does not have a jre directory under jdk, so link to jdk
                dbutilmsg="$dbutilmsg23"
                ;;
         *  )   errexit "Unknown database version (expected 11 12 19 or 23)"
    esac

    #
    ### Fix Platforms : OJVM version is different than Java version so do not display target Java version
    if test "${PLATFORM}" = "Linux" -o "${PLATFORM}" = "Linux_x64"; then
        header2 "Check Java Version of OJVM, Database JDK and EBS's appsutil JRE, need $thisJava"
    else
        header2 "Check Java Version of OJVM, Database JDK and EBS's appsutil JRE"
    fi


    ### Fix Solaris : Format of character string to tr command
    if [ "${PLATFORM}" = "Solaris" ] ; then
      ojvmver=$( getojvmver | ${TR_CMD} -dc '[0-9]._')
    else
      ojvmver=$( getojvmver | ${TR_CMD} -dc '[0-9._]')
    fi

    jdkloc=$ORACLE_HOME/jdk/bin/java
    if [ -x "$jdkloc" ] ;then
        jdkver=$(  getjver $jdkloc )
        if test "${PLATFORM}" = "HP_IA" ; then jdkver=$(echo $jdkver|sed 's/-[a-zA-Z]*//g') ; fi
        jdkbits="64-bit" 
        jdkbits=$( getjbit $jdkloc )
    else
        jdkver="Not Found"
        jdkbits=""
    fi

    utilloc=$ORACLE_HOME/appsutil/jre/bin/java
    if [ -x "$utilloc" ] ;then
        utilver=$(  getjver $utilloc )
        if test "${PLATFORM}" = "HP_IA" ; then utilver=$(echo $utilver|sed 's/-[a-zA-Z]*//g') ; fi
        utilbits=$( getjbit $utilloc )
    else 
        utilver="Not Found"
        utilbits=""
    fi

    fmt=" %-14s %-8s %-12s %8s %s\n"
    printf "$fmt" "$thisCPU    " " action "  "Your Version" "bitness"        "Java Location"
    printf "$fmt" "--------------" "--------"  "------------" "-------"        "---------------"

    ojvmaction=""     # these are set with proper message if version too low for the CPU
    jdkaction=""
    utilaction=""

    if [ "$ojvmver" != "Not Found" ] && isLower "$thisoJava"  "$ojvmver"  ;then  ojvmaction="   o)" ;fi  
    if [  "$jdkver" != "Not Found" ] && isLower "$thisJava"   "$jdkver"  ;then   jdkaction="   j)" ;fi  
    if [ "$utilver" != "Not Found" ] && isLower "$thisJava"  "$utilver"  ;then  utilaction="   u)" ;fi  

    printf "$fmt" "$thisoJava" "$ojvmaction" "$ojvmver"   "64-bit"  "OJVM In database"
    printf "$fmt" "$thisJava"  "$jdkaction"  "$jdkver"  "$jdkbits" "$jdkloc"
     if  [[ "$dbver" != 23* ]] ; then
        printf "$fmt" "$thisJava" "$utilaction" "$utilver" "$utilbits" "$utilloc" ;
    fi
    echo ""
    if [ ! -z "$ojvmaction" ] ;then echo   "$ojvmmsg"  ;fi
    if [ ! -z  "$jdkaction" ] ;then echo "$dbjavamsg"  ;fi
    if [ ! -z "$utilaction" ] ;then echo "$dbutilmsg"  ;fi

}

# Check apptier Java locations
#--------------------------------------------
function checkappjava()
{
    if test "${PLATFORM}" = "HP_IA" -o "${PLATFORM}" = "Solaris" -o "${PLATFORM}" = "Solaris_x86-64"; then
        javalocations="
        $ORACLE_HOME/jdk/bin/java
        $COMMON_TOP/util/jdk/bin/java
        $FMW_HOME/webtier/jdk/bin/java "
    else
        javalocations="
        $ORACLE_HOME/jdk/bin/java
        $COMMON_TOP/util/jdk32/bin/java
        $COMMON_TOP/util/jdk64/bin/java
        $FMW_HOME/webtier/jdk/bin/java "
    fi

    header "Checking Apptier Java 7 for CPU $thisCPU on Platform $PLATFORM - need $thisJava7 "

    for java in $javalocations ;do
        : # ls -l $java
    done

    updates=0
    printf " %s\t%s\t%s\t%s\t%s\n" "  $thisCPU"   "action"	"Your Version" "bitness"	"Java Location"
    printf " %s\t%s\t%s\t%s\t%s\n" "------------" "------"	"------------" "-------"	"---------------"
    for java in $javalocations ;do
        if [ -x "$java" ] ;then
            ver=$( $java -version 2>&1 | ${AWK} -F"\"" '/java version/ {print $2}' | ${TR_CMD} -d '\n' )
            bits=$(  $java -version 2>&1 | ${AWK} 'BEGIN {bit64=0} /64-Bit/ {bit64=1} END { print (bit64==1) ? "64-bit" : "32-bit" }' )
            if test "${PLATFORM}" = "IBM_AIX"; then ver=$( $java -version 2>&1 | ${AWK} '/based on Oracle/ {print $7}'|${AWK} -F'u' '{print $2}'|${AWK} -F'-' -v ver=$ver '{print ver "_"  $1}');fi
            if test "${PLATFORM}" = "IBM_AIX"; then bits=$(  $java -version 2>&1 | ${AWK} 'BEGIN {bit64=0} /ppc64-64/ {bit64=1} END { print (bit64==1) ? "64-bit" : "32-bit" }');fi 
            if test "${PLATFORM}" = "HP_IA"; then bits=$(  $java -d32 -version 2>&1 | ${AWK} 'BEGIN {mixed=0} /mixed/ {mixed=1} END { print (mixed==1) ? "Hybrid" : "Non-Hybrid" }' );fi

            ### Fix Solaris : Java8 or higher can only be 64-bit but Java7 or lower is hybrid
            if [ "${PLATFORM}" = "Solaris" ] ; then
                jdkver=$(  getjver $java)
                my_str=($(echo ${jdkver} | ${TR_CMD} "." "\n"))

                if [ ${my_str[0]} -gt 1 ] ; then
                    bits=$(  $java -version 2>&1 | ${AWK} 'BEGIN {bit64=0} /64-Bit/ {bit64=1} END { print (bit64==1) ? "64-bit" : "Undefined" }' )
                else
                    if [ ${my_str[0]} -eq 1 -a ${my_str[1]} -gt 7 ] ; then
                        bits=$(  $java -version 2>&1 | ${AWK} 'BEGIN {bit64=0} /64-Bit/ {bit64=1} END { print (bit64==1) ? "64-bit" : "Undefined" }' )
                    else
                        bits=$(  $java -d32 -version 2>&1 | ${AWK} 'BEGIN {mixed=0} /mixed/ {mixed=1} END { print (mixed==1) ? "Hybrid" : "Non-Hybrid" }' )
                    fi
                fi
            fi ### Solaris

            if isLower "$thisJava7" "$ver" ;then action="UPDATE"; updates=$((updates+1)) ;else action="OK" ;fi 
        else 
            ver="Not Found"
            bits=""
            action=""
        fi

        printf " %s\t%s\t%s\t%s\t%s\n" "$thisJava7" "$action" "$ver" "$bits" "$java"
    done

    #echo "updates is $updates"
    if [ "$updates" -gt 0 ] ;then
        echo ""
        echo "$appjavamsg"
    fi
}

#
# MAIN
################################################################################ 


case $1 in
  -V  ) echo "$pgm $rcsver - checking Java for CPU $thisCPU" ; exit 0;
        ;;
  -h  ) usage 
        ;;
 --help ) usage 
        ;;
esac

UNAME=`uname -s`
case $UNAME in
  "HP-UX")  OSTYPE=`uname -m`
            if [ $OSTYPE = "ia64" ] ; then
                PLATFORM=HP_IA
            else
                PLATFORM=HP_UX
            fi
            ;;
  "AIX")    PLATFORM=IBM_AIX
            PLATFORM_LOWER=aix
            ;;
  "OSF1")   PLATFORM=UNIX_Alpha
            PLATFORM_LOWER=decunix
            ;;
  "SunOS")  OSTYPE=`uname -m`
            if [ $OSTYPE = "sun4u" ] ; then
                PLATFORM=Solaris
                PLATFORM_LOWER=solaris
            elif [ $OSTYPE = "sun4us" ] ; then
                PLATFORM=Solaris
                PLATFORM_LOWER=solaris
            elif [ $OSTYPE = "i86pc" ] ; then
                PLATFORM=Solaris_x86-64
                PLATFORM_LOWER=solaris_x86-64
            fi
            PTYPE=`uname -p`
            if [ $PTYPE = "sparc" ] ; then
                PLATFORM=Solaris
                PLATFORM_LOWER=solaris
            fi
            unset PTYPE
            unset OSTYPE
            ;;
  "Linux")  OSTYPE=`uname -m`
            if [ $OSTYPE = "x86_64" ] ; then
                PLATFORM=Linux_x64
                PLATFORM_LOWER=linux_x64
            elif [ $OSTYPE = "s390x" ] ; then
                PLATFORM=LINUX_ZSER
                PLATFORM_LOWER=linux_zser
            else
                PLATFORM=Linux
                PLATFORM_LOWER=linux
            fi
            unset OSTYPE
esac
unset UNAME

case $PLATFORM in

  "HP_IA") 
                    thisJava7="1.7.0.33"    #      Java 7 used by apptier, DBs 11,22
                    thisJava8="1.8.0.29"    #      Java 8 used by DB 19
                    thisoJava8="1.8.0_471"  #      OJVM  DB 19
                    thisoJava7="1.7.0_481"   #      OJVM DB 12 
                    thisJava11="11.0.29"    #      Java 11 used by DB 23
 		    thisoJava11="11.0.29"   #      OJVM DB 23	
                    AWK="awk"
                    TR_CMD="tr"
                    appjavamsg="Follow 1530033.1 to update the JDK(s). Your application tier JDK 7 is lower than the $thisJava7 update released in CPU $thisCPU."
                   ;;
  "IBM_AIX")       
                    thisJava7="1.7.0_481"   #      Java 7 used by apptier, DBs 11,22
                    thisJava8="1.8.0_471"   #      Java 8 used by DB 19
                    thisoJava8="1.8.0_471"  #      OJVM  DB 19
                    thisoJava7="1.7.0_481"   #      OJVM DB 12
                    thisJava11="11.0.29"    #      Java 11 used by DB 23
		    thisoJava11="11.0.29"   #      OJVM DB 23  
                    AWK="awk"
                    TR_CMD="tr"
                   ;;
  "Solaris")       
                    thisJava7="1.7.0_481"   #      Java 7 used by apptier, DBs 11,22
                    thisJava8="1.8.0_471"   #      Java 8 used by DB 19
                    thisoJava8="1.8.0_471"  #      OJVM  DB 19
                    thisoJava7="1.7.0_481"   #      OJVM DB 12
                    thisJava11="11.0.29"    #      Java 11 used by DB 23
		    thisoJava11="11.0.29"   #      OJVM DB 23  
                    AWK="nawk"
                    TR_CMD="/usr/xpg6/bin/tr"
                   ;;
  "Solaris_x86-64")
                    thisJava7="1.7.0_481"   #      Java 7 used by apptier, DBs 11,22
                    thisJava8="1.8.0_471"   #      Java 8 used by DB 19
                    thisoJava8="1.8.0_471"  #      OJVM  DB 19
                    thisoJava7="1.7.0_481"   #      OJVM DB 12
                    thisJava11="11.0.29"    #      Java 11 used by DB 23
  		    thisoJava11="11.0.29"   #      OJVM DB 23  
                    AWK="awk"
                    TR_CMD="tr"
                   ;;

  "Linux")         
                   AWK="awk"
                   TR_CMD="tr"
                   ;;
  "Linux_x64")    
                   AWK="awk"
                   TR_CMD="tr"
                   ;;
  "LINUX_ZSER")   
                    AWK="awk"
                    TR_CMD="tr"
esac

# Need the proper env to run check, if no ORACLE_HOME we don't have a proper environment
if [ -z  "$ORACLE_HOME" ] ;then
    errexit  "Environment variables not found, you must source the proper (app or db) environment"
fi

if [ "$(basename "$ORACLE_HOME")" = "10.1.2" ] ;then  # must be 12.2.x APP tier, validate other variables

    if [ -z "$APPL_TOP" -o -z "$COMMON_TOP" ] ;then
        errexit "APPL_TOP and or COMMON_TOP Environment variable not found, you must source the proper environment"
    fi

    checkappjava

else

    if [ -z "$ORACLE_SID" ] ;then
        errexit "ORACLE_SID Environment variable not found, you must source the proper database environment"
    fi

    unset TWO_TASK  # 23ai FREE  has both ORACLE_SID and TWO_TASK set on db server ?
                    # probably to run client tools that depend on TWO_TASK

    if ! command -v sqlplus >/dev/null 2>&1 ;then
        errexit "Cannot locate sqlplus command, sqlplus must be on the PATH"
    fi

    checkdbjava

fi

################################################################################ 
unset PLATFORM
unset PLATFORM_LOWER
