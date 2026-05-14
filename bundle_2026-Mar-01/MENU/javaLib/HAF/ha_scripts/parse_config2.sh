#!/bin/bash

hostname=$(echo $HOSTNAME);

# Usage: ./parse_config2.sh
#CONFIG_FILE="$1"
CONFIG_FILE="${EBS_DOMAIN_HOME}/config/config.xml"
OUTPUT_FILE="servers_$hostname.html"

if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
  echo "Usage: $0 /path/to/EBS_DOMAIN_HOME/config/config.xml"
  exit 1
fi

echo "<html><head><title>Managed Servers</title></head><body>" > "$OUTPUT_FILE"
echo "<table border='1'>" >> "$OUTPUT_FILE"
echo "<tr bgcolor=\"#e7ecf0\"><th height=\"20\" colspan=\"4\"><div align=\"center\"><strong>Config.xml Settings on $hostname</strong></div></th></tr>" >> "$OUTPUT_FILE"
echo "<tr bgcolor=\"#e7ecf0\"><th>SERVER TYPE</th><th>Name</th><th>Machine</th><th>Listen Port</th></tr>" >> "$OUTPUT_FILE"

awk '
  /<server>/,/<\/server>/ {
    if ($0 ~ /<server>/) {
      name = ""; machine = ""; port = ""; server_type = "";
      inServer = 1;
    }
    if (inServer && match($0, /<name>([^<]*)<\/name>/, arr)) {
      name = arr[1];
      lname = tolower(name);
      if (index(lname, "oacore")) server_type = "OACORE";
      else if (index(lname, "forms")) server_type = "FORMS";
      else if (index(lname, "oafm")) server_type = "OAFM";
      else server_type = "";
    }
    if (inServer && match($0, /<machine>([^<]*)<\/machine>/, arr)) {
      machine = arr[1];
    }
    if (inServer && match($0, /<listen-port>([^<]*)<\/listen-port>/, arr)) {
      port = arr[1];
    }
    if ($0 ~ /<\/server>/ && inServer) {
      if (name && machine && port) {
        printf "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", server_type, name, machine, port
      }
      inServer = 0;
    }
  }
' "$CONFIG_FILE" >> "$OUTPUT_FILE"

echo "</table></body></html>" >> "$OUTPUT_FILE"
echo "HTML table has been generated at $OUTPUT_FILE"