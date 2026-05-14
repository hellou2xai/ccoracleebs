#!/bin/sh
#Run this shell script and redirect output to a new file file:
# sh rm_from_appltop.sh > rm_all.sh
#Review new file "rm_all.sh" and remove any line(s) that does not 
#correspond to an analyzer.
#Execute the script rm_all.sh to remove any analyzer sql file 
#from $APPL_TOP (run and patch filesystem, as applicable).

echo ""
echo "#to remove analyzer files from $APPL_TOP (APPL_TOP)"

find $APPL_TOP -type f -name '*analyze*.sql' -exec grep -l  "REM \$Id: " {} \; | awk '{print "rm " $0}'

if [ ! -z $PATCH_BASE ]
then
  tmp=${APPL_TOP#*$RUN_BASE}
  if [ ! -z $tmp ]
  then
    patch_appl_top=$PATCH_BASE$tmp
    echo ""
    echo "#to remove analyzer files from $APPL_TOP (PATCH fs)"
    find $patch_appl_top -type f -name '*analyze*.sql' -exec grep -l  "REM \$Id: " {} \; | awk '{print "rm " $0}'
  fi
fi

