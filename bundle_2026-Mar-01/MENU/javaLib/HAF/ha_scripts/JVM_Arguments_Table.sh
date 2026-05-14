#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 3 ]; then
  echo "Usage: $0  "
  exit 1
fi

managed_server_name=$1
argument_usesun=$2
argument_protocol=$3

# Get the process details of the managed server
output=$(ps -ef | grep "$managed_server_name")

      echo "<!DOCTYPE html>
<html>
<head>
<title>JVM Arguments Table</title>
<style>
  table, th, td {
    border: 1px solid black;
    border-collapse: collapse;
    padding: 6px;
    text-align: center;
  }
</style>
</head>
<body>" >> JVM_Arguments.html

  instance=$(echo $TWO_TASK);
  release=$(echo "##%%g_apps_release%%##")
  date=$(date)
  hostname=$(echo $HOSTNAME);
  autoconfig=$(echo "::VAR::g_latest_autoconfig::")
  configxml=$(echo "::VAR::g_latest_config_xml::")
  memory=$(echo "::VAR::g_instance::")
  
 
echo " 
<table>
  <thead>
    <tr bgcolor="#e7ecf0"> 
    <th height="20" colspan="5"><div align="center"><strong>$instance | $date | $hostname</strong></div></th>
    </tr>  
    <tr bgcolor="#e7ecf0"> 
    <th height="20" colspan="5"><div align="center"><strong>JVM Running Process Arguments</strong></div></th>
    </tr>
    <tr>
      <th>MANAGED_SERVER</th>
	  <th>Memory Xms</th>
	  <th>Memory Xmx</th>
      <th>UseSunHttpHandler</th>
	  <th>https.protocols
</th>
    </tr>
  </thead>
<tbody>" >> JVM_Arguments.html

# Split the output into individual lines
while IFS= read -r line; do
  # Extract the server name
  name=$(echo "$line" | sed -n "s/.*-Dweblogic.Name=\([^ ]*\).*/\1/p")

  # Check if the server name is found
  if [ -n "$name" ]; then

	xms_run=$(echo "$line" | grep -Eo '(-Xms[0-9]+m)');
	xmx_run=$(echo "$line" | grep -Eo '(-Xmx[0-9]+m)');
	protocol=$(echo "$line" | grep -Eo '( |>)-Dhttps\.protocols=(TLSv1,TLSv1\.1,TLSv1\.2|TLSv1\.2)( |<)');
	
    # Check if the specified argument is present
    if echo "$line" | grep -q " $xms_run "; then
      echo "<tr><td>$name</td><td>$xms_run</td>" >> JVM_Arguments.html
    else
      echo "<tr><td>$name</td><td>not found</td>" >> JVM_Arguments.html
    fi
	if echo "$line" | grep -q " $xmx_run "; then
      echo "<td>$xmx_run</td>" >> JVM_Arguments.html
    else
      echo "<td>not found</td>" >> JVM_Arguments.html
    fi
	if echo "$line" | grep -q " $argument_usesun "; then
      echo "<td>$argument_usesun</td>" >> JVM_Arguments.html
    else
      echo "<td>not found</td>" >> JVM_Arguments.html
    fi
	if echo "$line" | grep -q "$protocol"; then
      echo "<td>$protocol</td></tr>" >> JVM_Arguments.html
    else
      echo "<td>not found</td></tr>" >> JVM_Arguments.html
    fi
  fi

done <<< "$output"

  	echo "  </tbody></table>" >> JVM_Arguments.html

# Get the process details of the managed servers running
output2=$(cat $EBS_DOMAIN_HOME/config/config.xml | grep "$managed_server_name")

      echo " <table>
  <thead>
    <tr bgcolor="#e7ecf0"> 
    <th height="20" colspan="5"><div align="center"><strong>config.xml Argument Settings</strong></div></th>
	</tr>
    <tr bgcolor="#e7ecf0">
      <th>MANAGED_SERVER</th>
	  <th>Memory Xms</th>
	  <th>Memory Xmx</th>
      <th>UseSunHttpHandler</th>
	  <th>https.protocols
</th>
    </tr>
  </thead>
<tbody>" >> JVM_Arguments.html

# Split the output into individual lines
while IFS= read -r line; do
  # Extract the server name
  name=$(echo "$line" | sed -n "s/.*-Dweblogic.Name=\([^ ]*\).*/\1/p")

  # Check if the server name is found
  if [ -n "$name" ]; then

	xms=$(echo "$line" | grep -Eo '(-Xms[0-9]+m)');
	xmx=$(echo "$line" | grep -Eo '(-Xmx[0-9]+m)');
	protocol=$(echo "$line" | grep -Eo '(>| )-Dhttps\.protocols=(TLSv1,TLSv1\.1,TLSv1\.2|TLSv1\.2)( |<)');	
	
	# Check if the specified argument is present
    if echo "$line" | grep -q " $xms "; then
      echo "<tr><td>$name</td><td>$xms</td>" >> JVM_Arguments.html
    else
      echo "<tr><td>$name</td><td>not found</td>" >> JVM_Arguments.html
    fi
	if echo "$line" | grep -q " $xmx "; then
      echo "<td>$xmx</td>" >> JVM_Arguments.html
    else
      echo "<td>not found</td>" >> JVM_Arguments.html
    fi
	if echo "$line" | grep -q " $argument_usesun "; then
      echo "<td>$argument_usesun</td>" >> JVM_Arguments.html
    else
      echo "<td>not found</td>" >> JVM_Arguments.html
    fi
	if echo "$line" | grep -q "$protocol"; then
      echo "<td>$protocol</td></tr>" >> JVM_Arguments.html
    else
      echo "<td>not found</td></tr>" >> JVM_Arguments.html
    fi
  fi

done <<< "$output2"

  	echo "  </tbody></table>
</body>
</html>" >> JVM_Arguments.html


