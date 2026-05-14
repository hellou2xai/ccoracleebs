echo "OHS/WLS Setup" > ohs_info.txt
echo "=============" >> ohs_info.txt
echo "FMW home: ${FMW_HOME}" >> ohs_info.txt

#WG_OHOME_NAME=`find ${FMW_HOME} -path '*/webgate/ohs/config/oblog_config_wg.xml' | awk -F / '{print $(NF-4)}'`
#WG_OHOME=`find ${FMW_HOME} -name $WG_OHOME_NAME`
#echo "FMW home: $WG_OHOME" >> ohs_info.txt
if [[ -d "${FMW_HOME}/webtier" ]]
then
  echo "OHS home: ${FMW_HOME}/webtier" >> ohs_info.txt
else
  echo "OHS home: ${FMW_HOME}/webtier not available" >> ohs_info.txt
fi
if [[ -d "${FMW_HOME}/Oracle_OAMWebGate1" ]]
then
  echo "Webgate home: ${FMW_HOME}/Oracle_OAMWebGate1" >> ohs_info.txt
else
  echo "Webgate home: ${FMW_HOME}/Oracle_OAMWebGate1 not available" >> ohs_info.txt
fi
echo "EBS domain home: $EBS_DOMAIN_HOME" >> ohs_info.txt

DB_ID=`( echo "set heading off
select fnd_profile.value('APPS_DATABASE_ID') from dual;" | sqlplus -S ${APPSUSER}/${APPSPASS} ) | awk '{ if (NF!=0) print $0 }'`
echo "Database ID: $DB_ID" >> ohs_info.txt
DBC_FILE_LOC=`ls "$FND_SECURE"/"$DB_ID".dbc`
echo "DBC file location: $DBC_FILE_LOC" >> ohs_info.txt

