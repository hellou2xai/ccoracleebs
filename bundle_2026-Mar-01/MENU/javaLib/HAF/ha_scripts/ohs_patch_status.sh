echo "OHS Webgate Patch Status" > ohs_patch_stat.txt
echo "=============" >> ohs_patch_stat.txt
WG_OHOME_NAME=`find ${FMW_HOME} -path '*/webgate/ohs/config/oblog_config_wg.xml' | awk -F / '{print $(NF-4)}'`
WG_OHOME=`find ${FMW_HOME} -name $WG_OHOME_NAME`

ORACLE_HOME=$WG_OHOME
$ORACLE_HOME/OPatch/opatch lsinventory >> ohs_patch_stat.txt

