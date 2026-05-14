#!/bin/bash

read -sp "Enter APPS user password: " APPSPWD
echo

HTML_FILE="managed_servers.html"
HOSTNAME=$(hostname)

# Prepare a list of managed servers with DMZ and OHS info
MANAGED_LIST="managed_servers_list.tmp"
# Is HOST an external DMZ instance or internal instance
HOST_IS_DMZ="host_is_dmz.txt"

sqlplus -s "$APPSUSER"/"$APPSPASS" <<EOF > $HOST_IS_DMZ
set pages 0 feedback off heading off echo off

-- Define a bind variable
VARIABLE hostname VARCHAR2(100)
BEGIN
  :hostname := UPPER('$HOSTNAME');
END;
/
SELECT
    --extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') AS "MANAGED_SERVER",
    CASE
      WHEN 'Server:' || upper(extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]')) IN (
        SELECT "External Nodes"
        FROM (
          SELECT
            p.user_profile_option_name,
            decode(v.profile_option_value, 1, 'Admin', 2, 'Normal', 3, 'External', 'Unknown') Value,
            decode(v.level_id,
              10001, 'SITE',
              10002, (SELECT 'App:' || a.application_short_name FROM fnd_application a WHERE a.application_id = v.level_value),
              10003, (SELECT 'Resp:' || f.RESPONSIBILITY_name || ' (' || responsibility_key || ')'
                      FROM fnd_responsibility_vl f WHERE f.responsibility_id = v.level_value),
              10004, (SELECT 'User:' || u.user_name FROM fnd_user u WHERE u.user_id = v.level_value),
              10005, (SELECT 'Server:' || n.node_name FROM fnd_nodes n WHERE n.node_id = v.level_value),
              10006, (SELECT 'Org:' || org.name FROM hr_operating_units org WHERE org.name = v.level_value),
              'NOT SET') "External Nodes"
          FROM fnd_profile_options_vl p, fnd_profile_option_values v
          WHERE
            p.profile_option_id = v.profile_option_id (+)
            AND p.application_id = v.application_id (+)
            AND p.profile_option_name LIKE UPPER('%NODE%TRUST%')
            AND v.profile_option_value = '3'
        )
        WHERE "External Nodes" LIKE 'Server%'
      )
      THEN 'Yes'
      ELSE 'No'
    END AS "DMZ"
  FROM fnd_oam_context_files
  WHERE name NOT IN ('TEMPLATE','METADATA')
    AND (status IS NULL OR status != 'H')
    AND extractValue(XMLType(TEXT),'//file_edition_type') = 'run'
   and upper(extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]')) = :hostname
/
EOF

# Clean up output (remove empty lines, trim)
grep -v '^$' $HOST_IS_DMZ > host_is_dmz.clean
mv host_is_dmz.clean $HOST_IS_DMZ

HOST_IS_DMZ=$(cat host_is_dmz.txt)

# Check if current host is in the managed list
if [ -z "$HOST_IS_DMZ" ]; then
  echo "<p><b>WARNING: Host $HOSTNAME is not listed as a managed server in EBS context files.</b></p>" >> $HTML_FILE
else
  if [ "$HOST_IS_DMZ" == "Yes" ]; then
    echo "<p><b>Analyzer was run on Host $HOSTNAME which is an <span style='color:red;'>EXTERNAL (DMZ)</span> managed server.</b></p>" >> $HTML_FILE
  else
    echo "<p><b>Analyzer was run on Host $HOSTNAME which is an <span style='color:green;'>INTERNAL</span> managed server.</b></p>" >> $HTML_FILE
  fi
fi

sqlplus -s "$APPSUSER"/"$APPSPASS" <<EOF > $MANAGED_LIST
set pages 0 feedback off heading off echo off
SELECT
  extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') || '|' ||
  CASE
      WHEN 'Server:'||upper(extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]')) IN (
        SELECT "External Nodes"
        FROM (
          SELECT
            p.user_profile_option_name,
            decode(v.profile_option_value, 1, 'Admin', 2, 'Normal', 3, 'External', 'Unknown') Value,
            decode(v.level_id,
              10001, 'SITE',
              10002, (SELECT 'App:'||a.application_short_name FROM fnd_application a WHERE a.application_id = v.level_value),
              10003, (SELECT 'Resp:'||f.RESPONSIBILITY_name||' ('||responsibility_key||')' FROM fnd_responsibility_vl f WHERE f.responsibility_id = v.level_value),
              10004, (SELECT 'User:'||u.user_name FROM fnd_user u WHERE u.user_id = v.level_value),
              10005, (SELECT 'Server:'||n.node_name FROM fnd_nodes n WHERE n.node_id = v.level_value),
              10006, (SELECT 'Org:'||org.name FROM hr_operating_units org WHERE org.name = v.level_value),
              'NOT SET') "External Nodes"
          FROM fnd_profile_options_vl p, fnd_profile_option_values v
          WHERE
            p.profile_option_id = v.profile_option_id (+)
            AND p.application_id = v.application_id (+)
            AND p.profile_option_name LIKE UPPER('%NODE%TRUST%')
            AND v.profile_option_value = '3'
        )
        WHERE "External Nodes" LIKE 'Server%'
      )
      THEN 'Yes'
      ELSE 'No'
  END || '|' ||
  extractValue(XMLType(TEXT),'//ohs_instance')
FROM fnd_oam_context_files
WHERE name NOT IN ('TEMPLATE','METADATA')
  AND (status IS NULL OR status !='H')
  AND EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')='run'
  order by extractValue(XMLType(TEXT),'//ohs_instance')
/
EOF

# Clean up output (remove empty lines, trim)
grep -v '^$' $MANAGED_LIST > managed_servers_list.clean
mv managed_servers_list.clean $MANAGED_LIST

echo "<table border='1'>" >> $HTML_FILE
echo "<tr bgcolor=\"#e7ecf0\"><th height=\"20\" colspan=\"3\"><div align=\"center\"><strong>Managed Servers on $hostname</strong></div></th><th height=\"20\" colspan=\"3\"><div align=\"center\"><strong>mod_wl_ohs.conf Settings</strong></div></th><th height=\"20\" colspan=\"3\"><div align=\"center\"><strong>apps.conf Settings</strong></div></th></tr>" >> $HTML_FILE
echo "<tr bgcolor=\"#e7ecf0\"><th>MANAGED_SERVER</th><th>DMZ</th><th>OHS_INSTANCE</th><th>SERVER TYPE</th><th>Location Path</th><th>WebLogic Clusters</th><th>SERVER TYPE</th><th>Location Path</th><th>BalancerMember</th></tr>" >> $HTML_FILE

# Now loop through each managed server and run the scripts
while IFS='|' read -r MANAGED_SERVER DMZ OHS_INSTANCE; do
  MANAGED_SERVER=$(echo "$MANAGED_SERVER" | xargs)
  DMZ=$(echo "$DMZ" | xargs)
  OHS_INSTANCE=$(echo "$OHS_INSTANCE" | xargs)
  [ -z "$MANAGED_SERVER" ] && continue

  if [ -z "$OHS_INSTANCE" ]; then
    echo "<tr><td colspan='9'>OHS_INSTANCE is not set for $MANAGED_SERVER</td></tr>" >> $HTML_FILE
    continue
  fi

  OHS_DIR="$FMW_HOME/webtier/instances/$OHS_INSTANCE/config/OHS/EBS_web"
  if [ ! -d "$OHS_DIR" ]; then
    echo "<tr><td colspan='9'>The OHS_DIR ($OHS_DIR) is missing.  (internal vs external)</td></tr>" >> $HTML_FILE
    continue
  fi

	MOD_FILE="$OHS_DIR/mod_wl_ohs.conf"
	APPS_FILE="$OHS_DIR/apps.conf"
	
	MOD_WL_OHS_OUTPUT=$(
	awk '
	/<IfModule[[:space:]]+mod_weblogic.c>/,/<\/IfModule>/ {
	  if ($0 ~ /<Location[[:space:]]+\//) {
		match($0, /<Location[[:space:]]+\/([^>]*)>/, loc)
		locpath = loc[1]
		wlcluster = ""
		server_type = ""

		loclower = tolower(locpath)
		if (loclower ~ /oacore/ || loclower == "oa_html") {
		  server_type = "OACORE"
		} else if (loclower ~ /forms/) {
		  server_type = "FORMS"
		} else if (loclower ~ /oafm/ || loclower == "webservices") {
		  server_type = "OAFM"
		} else {
		  server_type = ""
		}

		# Search next 8 lines for WebLogicCluster
		for (i=1; i<=8; i++) {
		  getline nextline
		  if (nextline ~ /WebLogicCluster[[:space:]]+/) {
			match(nextline, /WebLogicCluster[[:space:]]+([^ ]+)/, wl)
			wlcluster = wl[1]
			break
		  }
		}

		printf "%s|%s|%s\n", server_type, locpath, wlcluster
	  }
	}
	' "$MOD_FILE"
	)
  
	APPS_CONF_OUTPUT=$(
	awk '
	/<Location[[:space:]]+\// {
	  match($0, /<Location[[:space:]]+\/([^>]*)>/, loc)
	  locpath = loc[1]
	  balancer = ""
	  member = ""
	  stype = ""

	  # Look ahead for ProxyPass to a balancer
	  for (i=1; i<=3; i++) {
		getline nextline
		if (nextline ~ /ProxyPass[[:space:]]+balancer:\/\/([^\s]+)/) {
		  match(nextline, /ProxyPass[[:space:]]+balancer:\/\/([^ ]+)/, pb)
		  balancer = pb[1]
		  break
		}
	  }

	  # Now find the actual BalancerMember using the balancer name
	  if (balancer != "") {
		seek = 0
		while ((getline pline) > 0 && seek < 30) {
		  seek++
		  if (pline ~ "<Proxy[[:space:]]+balancer://" balancer ">") {
			# Now inside proxy block
			while ((getline mline) > 0) {
			  if (mline ~ /BalancerMember[[:space:]]+/) {
				match(mline, /BalancerMember[[:space:]]+([^ ]+)/, mb)
				member = mb[1]
				break
			  }
			  if (mline ~ /<\/Proxy>/) break
			}
			break
		  }
		}
	  }

	  if (tolower(balancer) ~ /oacore/) {
		stype = "OACORE"
	  } else if (tolower(balancer) ~ /forms/) {
		stype = "FORMS"
	  } else if (tolower(balancer) ~ /oafm/) {
		stype = "OAFM"
	  }
	  if (member != "") {
		printf "%s|%s|%s\n", stype, locpath, member
	  }
	}
	' "$APPS_FILE"
	)

  #echo "<tr bgcolor=\"#e7ecf0\"><th colspan=\"2\">$OHS_INSTANCE | $OHS_DIR </th></tr>" >> $HTML_FILE
	
	# Split MOD_WL_OHS_OUTPUT and APPS_CONF_OUTPUT into arrays
	IFS=$'\n' read -rd '' -a mod_rows <<<"$MOD_WL_OHS_OUTPUT"
	IFS=$'\n' read -rd '' -a apps_rows <<<"$APPS_CONF_OUTPUT"

	num_mod_rows=${#mod_rows[@]}
	num_apps_rows=${#apps_rows[@]}
	max_rows=$(( num_mod_rows > num_apps_rows ? num_mod_rows : num_apps_rows ))
	[ "$max_rows" -eq 0 ] && max_rows=1  # At least one row if both are empty

	for ((i=0; i<max_rows; i++)); do
	  if (( i == 0 )); then
		echo "<tr>" >> $HTML_FILE
		echo "<td rowspan=\"$max_rows\">$MANAGED_SERVER</td>" >> $HTML_FILE
		echo "<td rowspan=\"$max_rows\">$DMZ</td>" >> $HTML_FILE
		echo "<td rowspan=\"$max_rows\">$OHS_INSTANCE</td>" >> $HTML_FILE
	  else
		echo "<tr>" >> $HTML_FILE
	  fi

	  # mod_wl_ohs.conf columns
	  if [[ -n "${mod_rows[i]}" ]]; then
		IFS='|' read -r server_type locpath wlcluster <<<"${mod_rows[i]}"
		echo "<td>$server_type</td><td>$locpath</td><td>$wlcluster</td>" >> $HTML_FILE
	  else
		echo "<td></td><td></td><td></td>" >> $HTML_FILE
	  fi

	  # apps.conf columns
	  if [[ -n "${apps_rows[i]}" ]]; then
		IFS='|' read -r stype locpath member <<<"${apps_rows[i]}"
		echo "<td>$stype</td><td>$locpath</td><td>$member</td>" >> $HTML_FILE
	  else
		echo "<td></td><td></td><td></td>" >> $HTML_FILE
	  fi
	  echo "</tr>" >> $HTML_FILE
	done
done < "$MANAGED_LIST"

echo "</table>" >> $HTML_FILE

echo "<p><b>This Analyzer was run on $HOSTNAME</b></p>" >> $HTML_FILE
echo "</body></html>" >> $HTML_FILE
echo "Report generated: $HTML_FILE"