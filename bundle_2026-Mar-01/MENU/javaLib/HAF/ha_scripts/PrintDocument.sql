set serveroutput on size 1000000
set linesize 200;
spool PrintDocument.txt;
exec JDR_UTILS.printDocument('&1/&2');
spool off;