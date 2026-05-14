
#!/bin/bash

TNSSTR=$1;
SQLPAR="${APPSUSER}/${APPSPASS}@'$TNSSTR'"

if [[ $TNSSTR != "" ]]
then
  echo "set heading off 
select 'Yes, can connect to DB using OAEA TNS entry' from dual; " | sqlplus -s $SQLPAR | awk 'NF' > chkOAEAtns.out
else
  echo "database connection string for OAEA not available" > chkOAEAtns.out
fi
