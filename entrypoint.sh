#!/bin/bash

# If ORACLE_HOST_IP is set, add a hosts file entry so ORACLE_HOST resolves correctly.
# Write both the FQDN and its short label (e.g. apps.example.com -> apps) so the
# container's /etc/hosts matches the on-prem entry exactly.
if [ -n "$ORACLE_HOST_IP" ] && [ -n "$ORACLE_HOST" ]; then
    ORACLE_HOST_SHORT="${ORACLE_HOST%%.*}"
    echo "$ORACLE_HOST_IP  $ORACLE_HOST $ORACLE_HOST_SHORT" >> /etc/hosts
    echo "Added hosts entry: $ORACLE_HOST_IP -> $ORACLE_HOST $ORACLE_HOST_SHORT"
fi

exec gunicorn --config gunicorn.conf.py app:app
