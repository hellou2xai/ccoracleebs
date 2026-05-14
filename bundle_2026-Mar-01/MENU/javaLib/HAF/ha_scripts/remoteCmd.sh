#!/bin/sh
EBSVER=$1
LDAPSERVERTYPE=$2
OIDVER=$3
OSCLASS=`uname`
FULLOS=`uname -a`
CERTDB=$4
  OSFLAVOR="not certified!"
  VERSION="not certified!"
  CONCAT01="not certified!"
SEARCHCMD="grep $EBSVER $CERTDB | grep '$LDAPSERVERTYPE' | grep $OIDVER | grep $OSCLASS | grep '$CONCAT01' "
OSALIAS="not found"

if [ "$LDAPSERVERTYPE" = "OID" ]; then
  LDAPSERVERTYPE="Internet Directory"
elif [ "$LDAPSERVERTYPE" = "OUD" ]; then
  LDAPSERVERTYPE="Unified Directory"
else
  LDAPSERVERTYPE="Other LDAP"
fi

if [ "$OSCLASS" = "Linux" ]; then


  if test -f "/etc/oracle-release"; then
    OSFLAVOR="Oracle Linux"
    VERSION=`grep VERSION_ID /etc/os-release |sed -rn 's/^VERSION_ID="(([1-9][0-9]*)(\.[0-9]+)?)"/\2/p' | tr -d ' '`
    CONCAT01="$OSFLAVOR $VERSION"
    OSALIAS="Linux x86-64 Oracle Linux $VERSION"
  elif test -f "/etc/redhat-release"; then
    OSFLAVOR="Red Hat Enterprise Linux"
    VERSION=`grep VERSION_ID /etc/os-release |sed -rn 's/^VERSION_ID="(([1-9][0-9]*)(\.[0-9]+)?)"/\2/p' | tr -d ' '`
    CONCAT01="$OSFLAVOR $VERSION"
    OSALIAS="Linux x86-64 Red Hat Enterprise Linux $VERSION"
  elif test -f "/etc/SuSE-release"; then
    OSFLAVOR="SLES"
    VERSION=`grep VERSION /etc/SuSE-release|sed -rn 's/^.+\b([1-9][0-9]*)$/\1/p' | tr -d ' '`
    CONCAT01="$OSFLAVOR $VERSION"
    OSALIAS="Linux x86-64 SLES $VERSION"
  fi

  SEARCHCMD="grep $EBSVER $CERTDB | grep '$LDAPSERVERTYPE' | grep $OIDVER | grep $OSCLASS | grep '$CONCAT01' "

elif [ "$OSCLASS" = "HP-UX" ]; then
  
  OSCLASS="HP-UX"
  itanCnt=`uname -a | grep ia64 | wc -l`
  if [ $itanCnt -gt 0 ]; then
    OSFLAVOR="$OSCLASS Itanium"
  else
    OSFLAVOR="$OSCLASS PA-RISC"
  fi
  VERSION=`uname -a | sed -rn 's/^.+B\.([1-9][0-9]*(\.[0-9]+)?).+/\1/p' | tr -d ' '`
  CONCAT01="$OSFLAVOR $VERSION"
  OSALIAS="HP-UX $OSFLAVOR $VERSION"

  SEARCHCMD="grep $EBSVER $CERTDB | grep '$LDAPSERVERTYPE' | grep $OIDVER | grep $OSCLASS | grep '$CONCAT01' "

elif [ "$OSCLASS" = "SunOS" ]; then

  OSCLASS="Solaris"
  #sparc 64 bit
  VERSION2=`uname -v |awk -F\. '{print $1}'`

  cnt=`isainfo -v | grep sparc | grep "64-bit" | wc -l`
  if [ $cnt -gt 0 ]; then
    VERSION="on SPARC (64-bit)"

  else
    
    cnt=`isainfo -v | grep sparc | grep "32-bit" | wc -l`
    if [ $cnt -gt 0 ]; then
      VERSION="on SPARC (32-bit)"

    else
      cnt=`isainfo -v | egrep 'i386|amd64' | grep "64-bit" | wc -l`
      if [ $cnt -gt 0 ]; then
        VERSION="on x86-64 (64-bit)"

      else
        VERSION="on x86-32 (32-bit)"
      fi
    fi

  fi
  VERSION="$VERSION $VERSION2"
  CONCAT01="$OSCLASS $VERSION"
  SEARCHCMD="grep $EBSVER $CERTDB | grep '$LDAPSERVERTYPE' | grep $OIDVER | grep $OSCLASS | grep '$CONCAT01' "
  OSALIAS="Oracle Solaris $VERSION"

elif [ "$OSCLASS" = "AIX" ]; then
  VERSION=`oslevel -s | awk -F- '{printf "%.1f\n",$1/1000,$2,$3}'`
  CONCAT01="$VERSION|"
  SEARCHCMD="grep $EBSVER $CERTDB | grep '$LDAPSERVERTYPE' | grep $OIDVER | grep $OSCLASS | grep '$CONCAT01' "
  OSALIAS="IBM AIX $VERSION"
fi

#echo "$CONCAT01"
echo "[CERTCMD=$SEARCHCMD][OS=$FULLOS][OSALIAS=$OSALIAS]"
