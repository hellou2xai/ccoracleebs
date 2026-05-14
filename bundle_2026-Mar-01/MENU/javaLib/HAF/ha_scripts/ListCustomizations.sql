set serveroutput on size 1000000
set linesize 200;
spool ListCustomizations.txt;
exec jdr_utils.listcustomizations('/oracle/apps/fnd/wf/worklist/webui/AdvancWorklistRG');
spool off;