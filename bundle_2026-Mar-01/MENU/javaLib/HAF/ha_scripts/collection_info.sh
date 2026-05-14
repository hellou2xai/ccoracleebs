#! /bin/bash
 
 
 
if [ -z "$ECC_BASE" ]
then
    echo "\$ECC_BASE is not defined. Please source the ecc.env file" | tee -a $LOG
        exit 1
else
    echo "\$ECC_BASE is $ECC_BASE. Proceeding with dataset record collection.." | tee -a $LOG
fi
 
source  $ECC_BASE/Oracle/quickInstall/EccConfig.properties
ECC_HOST_NAME=$ECC_HOST_NAME
ECC_MANAGED_PORT=$ECC_MANAGED_PORT
ECC_HOST_PROTOCOL=$ECC_HOST_PROTOCOL
ECC_MANAGED_SSL_PORT=$ECC_MANAGED_SSL_PORT
 
 
ECC_BASE=`readlink -f $ECC_BASE`
#Check if the ECC_BASE is correct and if eccManaged service is running
ECC_CURRENT_VALID_BASE=`ps -ef | grep eccManaged | grep "\-Dwls.home=$ECC_BASE/Oracle/Middleware/wlserver/server" | wc -l`
ECC_ADMIN_SERVER_UP=`ps -ef | grep AdminServer | grep "\-Dwls.home=$ECC_BASE/Oracle/Middleware/wlserver/server" | wc -l`
 
if [ "$ECC_CURRENT_VALID_BASE" -ne 1 ] || [ "$ECC_ADMIN_SERVER_UP" -ne 1 ] ; then
        echo -e "\nECC Admin Server and managed server are not reacheable!\n" | tee -a $LOG
        echo -e "\nExiting the dataset backup...." | tee -a $LOG
        exit 1;
else
        echo -e "Servers are up, continuing with the datasets backup.." | tee -a $LOG
        echo -e ""
fi
 
 
if [ "$ECC_HOST_PROTOCOL" == "https" ]; then
        if test -f "$QI_BASE/cacert.pem"; then
            echo -e "\nUsing the existing certificate $QI_BASE/cacert.pem to backup\n" | tee -a $LOG
        else
            echo quit | openssl s_client -showcerts -servername $ECC_HOST_NAME  -connect $ECC_HOST_NAME:$ECC_MANAGED_SSL_PORT > $QI_BASE/cacert.pem
        fi
        SELF_SIGNED_CHECK=`cat $QI_BASE/cacert.pem | grep "Verify return code" | sed -n "s|.*\((.*)\)|\1|p"`
        if [ "$SELF_SIGNED_CHECK" == "(self signed certificate)" ]; then
                SELF_SIGNED="Y"
        else
                SELF_SIGNED="N"
        fi
fi
null=\"NULL\"
#Variables to be used for the dataset backup
if [[ "$ECC_HOST_PROTOCOL" == "https" ]] && [[ "$SELF_SIGNED" == "Y" ]]; then
        port=$ECC_MANAGED_SSL_PORT
        url="https://$ECC_HOST_NAME:$ECC_MANAGED_SSL_PORT/"
        OUTPUT_JSON=$(curl --cacert $QI_BASE/cacert.pem -v  "$url/core_ecc/admin/collections?action=LIST")
        collection=$(echo $OUTPUT_JSON|grep -o '"collections":\[.*\]'|sed 's/"collections"://'|sed  "s/\[//g"|sed  "s/\]//g"|sed "s/, / /g")
 
json=$(echo "{\"collections\":["
for i in ${collection[@]};
do
collection_var=$(echo $i|sed "s/\"//g")
collection_name=$(echo $i)
response_input=$(curl -Ss  -o /dev/null -s -k -w "%{http_code}\n" $url/core_ecc/$collection_var/select?q=*%3A*"&"rows=0)
if test $response_input -eq 200
then 
records=$(curl -s --cacert $QI_BASE/cacert.pem -v  $url/core_ecc/$collection_var/select?q=*%3A*"&"rows=0)
record_no=$(echo $records|grep -o '"response":{.*}'|sed 's/"response"://'|awk -F ":" '{print $2}'|awk -F "," '{print $1}')
Size_IN_GB=$(curl -s  --cacert $QI_BASE/cacert.pem -v $url/core_ecc/admin/collections?action=COLSTATUS"&"collection=$collection_var"&"coreInfo=true"&"segments=true"&"fieldInfo=true"&"sizeInfo=true|grep  "sizeInGB"|awk -F "," '{print $1}'|awk -F ":" '{print $2}')
KB=$(awk '{ printf "%.2f", $1 * 1024 * 1024 }' <<< "$Size_IN_GB")
size_in_kb=\"$KB\"
Number_of_records=\"$record_no\"
echo "{\"name\": $collection_name", "\"record_count\": $Number_of_records", "\"size_in_kb\": $size_in_kb" },
else 
echo "{\"name\": $collection_name", "\"record_count\": $null", "\"size_in_kb\": $null" },
 
fi
done
echo "]}" ) 
 
echo "$json"|sed 'x;${s/,$//;p;x;};1d' > /tmp/collection_info.json 
 
else 
port=$ECC_MANAGED_PORT
url="http://$ECC_HOST_NAME:$ECC_MANAGED_PORT/"
OUTPUT_JSON=$(curl -Ss -k -X  GET --url "$url/core_ecc/admin/collections?action=LIST")
collection=$(echo $OUTPUT_JSON|grep -o '"collections":\[.*\]'|sed 's/"collections"://'|sed  "s/\[//g"|sed  "s/\]//g"|sed "s/, / /g")
json=$(echo "{\"collections\":["
for i in ${collection[@]};
do 
collection_var=$(echo $i|sed "s/\"//g")
collection_name=$(echo $i)
response_input=$(curl -Ss  -o /dev/null -s -k -w "%{http_code}\n" $url/core_ecc/$collection_var/select?q=*%3A*"&"rows=0)
if test $response_input -eq 200
then
records=$(curl -Ss -k -X  GET   $url/core_ecc/$collection_var/select?q=*%3A*"&"rows=0)
record_no=$(echo $records|grep -o '"response":{.*}'|sed 's/"response"://'|awk -F ":" '{print $2}'|awk -F "," '{print $1}')
Number_of_records=\"$record_no\"
Size_IN_GB=$(curl  -Ss -k -X  GET  $url/core_ecc/admin/collections?action=COLSTATUS"&"collection=$collection_var"&"coreInfo=true"&"segments=true"&"fieldInfo=true"&"sizeInfo=true|grep  "sizeInGB"|awk -F "," '{print $1}'|awk -F ":" '{print $2}')

KB=$(awk '{ printf "%.2f", $1 * 1024 * 1024 }' <<< "$Size_IN_GB")
size_in_kb=\"$KB\"
echo "{\"name\": $collection_name", "\"record_count\": "$Number_of_records"", "\"size_in_kb\": $size_in_kb" },
else 
echo "{\"name\": $collection_name", "\"record_count\": $null", "\"size_in_kb\": $null" }, 
fi
done
echo "]}" )
 
echo "$json"|sed 'x;${s/,$//;p;x;};1d' > /tmp/collection_info_new.json
 
fi