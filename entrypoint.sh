#!/bin/bash

# If ORACLE_HOST_IP is set, add a hosts file entry so ORACLE_HOST resolves correctly
if [ -n "$ORACLE_HOST_IP" ] && [ -n "$ORACLE_HOST" ]; then
    echo "$ORACLE_HOST_IP  $ORACLE_HOST" >> /etc/hosts
    echo "Added hosts entry: $ORACLE_HOST_IP -> $ORACLE_HOST"
fi

exec gunicorn --config gunicorn.conf.py app:app
