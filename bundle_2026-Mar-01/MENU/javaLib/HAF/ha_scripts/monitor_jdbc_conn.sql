Rem
Rem monitor_jdbc_conn.sql
Rem
Rem    NAME
Rem      monitor_jdbc_conn.sql version 1.0 from doc id 557194.1:
Rem      monitor_jdbc_conn.sql - Script To Monitor JDBC Connections In Apps E-Business Suite
Rem
Rem    DESCRIPTION
Rem      This shows JDBC connection utilization on database by machine, process
Rem      and module.
Rem
Rem    NOTES
Rem      Runs as apps or apps read only user
Rem
 

-- 
-- Set header information for all columns used
-- 
 
set lines 200
set pages 500
column module  heading "Module Name"  format a48;
column machine heading "Machine Name" format a30;
column process heading "Process ID"   format a10;
column inst_id heading "Instance ID"   format 99;

column username for a10
column sid for 9999
column sql_text for a50
  
spool monitor_jdbc_conn.lst

prompt =======================================================
prompt JDBC Connections
 
select to_char(sysdate, 'dd-mon-yyyy hh24:mi') Time from dual
/
prompt =======================================================
 
prompt =======================================================
prompt Number of connections on each database instance
 
select inst_id instance_id, count(*) from gv$session group by rollup (inst_id)
/
prompt =======================================================

prompt
prompt JDBC Connection Usage Per JVM Process
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

select process ||'@'|| machine , count(*) from gv$session
where program like '%JDBC%'
group by rollup (process ||'@'|| machine)
order by 1 asc
/
 

prompt
prompt Connection Usage Per Module
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 
select count(*), module
from gv$session
where program like '%JDBC%'
group by module
order by 1 asc
/
 
prompt
prompt Connection Usage Per process and module 
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 
select count(*), machine, process, module
from gv$session
where program like '%JDBC%'
group by  machine, process, module 
order by 1 asc
/
 
prompt
prompt Idle connections for more than 3 hours 
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 
select count(*),machine, program 
from gv$session
where program like '%JDBC%'
and  last_call_et > 3600 *3
group by machine, program
/
 

prompt
prompt Active connections which are taking more than 10 min to run
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 
select *
from gv$session
where program like '%JDBC%'
and last_call_et > 600
and status = 'ACTIVE'
order by last_call_et asc
/
 

prompt
prompt Statements from JDBC connections taking more than 10 min to run
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 
select s.process, s.sid,  t.sql_text
from gv$session s, gv$sql t
where s.sql_address =t.address 
and s.sql_hash_value =t.hash_value
and s.program like '%JDBC%'
and s.last_call_et > 600
and s.status = 'ACTIVE'
/
 

prompt
prompt Active connections which are taking more than 20 min to run
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 
select *
from gv$session
where program like '%JDBC%'
and last_call_et > 1200
and status = 'ACTIVE'
order by last_call_et asc
/
 
prompt
prompt Statements from JDBC connections taking more than 20 min to run
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 
select s.process, s.sid,  t.sql_text
from gv$session s, gv$sql t
where s.sql_address =t.address 
and s.sql_hash_value =t.hash_value
and s.program like '%JDBC%'
and s.last_call_et > 1200
and s.status = 'ACTIVE'
/
 

prompt
prompt Active connections which are taking more than 30 min to run
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 
select *
from gv$session
where program like '%JDBC%'
and last_call_et > 1800
and status = 'ACTIVE'
order by last_call_et asc
/
 
prompt
prompt Statements from JDBC connections taking more than 30 min to run
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 
select s.process, s.sid,  t.sql_text
from gv$session s, gv$sql t
where s.sql_address =t.address 
and s.sql_hash_value =t.hash_value
and s.program like '%JDBC%'
and s.last_call_et > 1800
and s.status = 'ACTIVE'
/
 
prompt
prompt Inactive connections which last ran fnd_security_pkg.fnd_encrypted_pwd
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 
select s.sql_hash_value, t.sql_text, s.last_call_et
from gv$session s , gv$sqltext t
where s.username = 'APPLSYSPUB'
and s.sql_hash_value= t.hash_value 
and t.sql_text like  '%fnd_security_pkg.fnd_encrypted_pwd(:1,:2,:3%';
 
prompt =======================================================

spool off
exit
