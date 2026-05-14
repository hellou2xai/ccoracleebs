REM $Header: ADZDDTFIX.sql 120.0.12020000.8 2013/10/24 12:07:55 rputchak noship $
REM dbdrv: none
REM +=======================================================================+
REM | Copyright (c) 2013 Oracle Corporation Redwood Shores, California, USA |
REM | All rights reserved.                                                  |
REM +=======================================================================+
REM | FILENAME
REM |   ADZDDTFIX.sql
REM |
REM | DESCRIPTION
REM |   This script is used to spool the DDL to fix the TS mis-match
REM | 
REM |   1- It spools DDLs SYNONYMS,VIEWS,PACKAGE / BODY and
REM |      can be modified to spool other types. 
REM |   2- Spooled DDLs can only be run by "SYS as SYSDBA" 
REM |
REM | NOTE
REM |   The spooled file from the script adzddtfix.out needs to be 
REM |   copied to Database Tier and run using SYSDBA privileges.
REM | 
REM +=======================================================================+

WHENEVER OSERROR EXIT FAILURE ROLLBACK;
WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

set define off
spool adzddtfix.out 
set pagesize 5000
set linesize 160
set trimspool on
set echo off
set tab off
set feedback off;
set head off;
set verify off;

column sql_stmt format a120; 
SET SERVEROUTPUT ON;

declare 
data_present boolean;

cursor cur_d_obj is 
select distinct d.obj# as obj_id
from sys."_ACTUAL_EDITION_OBJ" d, 
     sys.user$ du, 
     sys.dependency$ dep,
     sys."_ACTUAL_EDITION_OBJ" p, 
     sys.user$ pu
where d.obj# = dep.d_obj# 
  and d.owner# = du.user#    
  and p.obj# = dep.p_obj#
  and p.owner# = pu.user#
  and d.status = 1                                    /* Valid dependent */
  and bitand(dep.property, 1) = 1                     /* Hard dependency */
  and d.subname is null                               /* !Old type version */
  and not(p.type# = 32 and d.type# = 1)               /* Index to indextype */
  and d.type# in(4, 5, 9, 11)                         /* Bug 17268684 : View, Synonyms, package and body  */
  and not(p.type# = 29 and d.type# = 5)               /* Synonym to Java */
  and not(p.type# in(5, 13) and d.type# in (2, 55))   /* TABL/XDBS to TYPE */
  and (p.status not in (1, 2, 4) or p.stime <> dep.p_timestamp);

begin
data_present := FALSE;

for dependent in cur_d_obj 
loop 
    if (data_present = FALSE ) then 
     data_present :=TRUE;
     dbms_output.put_line('begin');
    end if;     
    if (data_present) then 
     dbms_output.put_line('dbms_utility.invalidate(' || dependent.obj_id || ',NULL,0);');
    end if;
end loop;

if (data_present) then
dbms_output.put_line('end;');
dbms_output.put_line('/');
dbms_output.put_line('exec sys.utl_recomp.recomp_parallel;');
dbms_output.put_line('exit;');
end if;

end;
/
spool off;
exit;