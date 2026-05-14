 #!/bin/sh
 # $Header: EBSCheckModSecurity.sh 120.0.12020000.4 2016/07/15 12:19:36 ishrivas noship $
 # *===========================================================================+
 # |  Copyright (c) 2016 Oracle Corporation, Redwood Shores, California, USA   |
 # |                        All rights reserved                                |
 # |                       Applications  Division                              |
 # +===========================================================================+
 # |
 # | FILENAME
 # |   EBSCheckModSecurity.sh
 # |
 # | DESCRIPTION
 # |   Check if ModSecurity is active on the EBS webserver
 # |
 # | USAGE
 # |   sh EBSCheckModSecurity.sh <host:port>
 # |
 # | PLATFORM
 # |   Unix Generic
 # |
 # | NOTES
 # |
 # | HISTORY
 # |
 # +===========================================================================+
 #
 #
 # dbdrv: none 
 
# Check if ModSecurity is active on the EBS webserver
# we do this by passing "../" in the URL and seeing that it gets blocked with a '400 Bad Request' response
# Copyright (c) 2015 Oracle Corporation  - All rights reserved.
# 2013-07-17 Updated to report missing curl
# 2015-04-14 Updated to check UP status via /robots.txt

if ! command -v curl >/dev/null 2>&1
then
  echo  "ERROR: Cannot locate curl command, ModSecurity test not run!"
  exit 1
fi

prg=$(basename $0)

function usage {
  echo >&2 "usage: $prg url-to-check"
  echo >&2 " example: $prg http://ebs.example.com:8000"
  echo >&2 " example: $prg https://ebs.example.com:4443"
  exit 1
}

case $# in
   1 ) baseurl="$1" ;;
   * ) usage ;;
esac

resp=$( curl -D - --insecure "${baseurl}/robots.txt" 2>/dev/null )

if  echo "$resp" | grep "wellbehaved webcrawlers" > /dev/null
then
        :
else
        echo "Error: Cannot connect to  $baseurl"
        exit 1
fi

resp=$( curl -D - --insecure ${baseurl}/z?p=%00 2>/dev/null  | awk '/^HTTP/ {print $2}' )

if  [ "$resp" = "400" ]
then
        echo "Passed. ModSecurity is enabled."
        exit 0
else
        echo "Failed. WARNING:  ModSecurity is not enabled.  You should enable ModSecurity.   Refer to the detailed information link for more information."
        exit 1
fi
