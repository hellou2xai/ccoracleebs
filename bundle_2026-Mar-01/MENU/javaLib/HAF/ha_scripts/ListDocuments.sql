set serveroutput on size 1000000
set linesize 200;
spool ListDocuments.txt;
exec jdr_utils.listdocuments('&1',&2);
spool off;