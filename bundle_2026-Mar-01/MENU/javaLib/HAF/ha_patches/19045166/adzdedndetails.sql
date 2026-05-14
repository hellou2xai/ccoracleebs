REM $Header: SessionUtil.pm 120.0 2014/08/12 09:05:52 rahulshr noship $
REM +==============================================================================+
REM | Copyright (c) 2012, 2014 Oracle Corporation, Redwood Shores, California, USA
REM |                             All Rights Reserved
REM |                            Applications Division
REM +==============================================================================+
REM
REM Script to collect information which might point the developers to
REM probable causes in the instance. 
REM        This script contains all edition specific information that 
REM        is necessary from every edition

set linesize 120;
set pagesize 50000;
set echo off;
spool adzdsqlcodelevel.out APPEND;
prompt =====================================================================
prompt Listing the run edition, current edition and the patch edition values
prompt =====================================================================
Column "Run Edition" format a20
Column "Current Edition" format a20
Column "Patch Edition" format a20
select ad_zd.get_edition('RUN') "Run Edition",
       ad_zd.get_edition "Current Edition",
       nvl(ad_zd.get_edition('PATCH'),'NULL') "Patch Edition"
from dual;

prompt =======================================================
prompt Getting AD_ZD packages header versions from the edition
prompt =======================================================
col text format a120;

select text 
       from dba_source 
       where text like '%Header%' and name like 'AD_ZD%' 
       order by 1;

spool off;
col owner format a20;
col table_name format a30;
spool prepared_seed_tables.out APPEND
prompt ==================================================
prompt The seed tables prepared in the edition
prompt ==================================================

 select col.owner, col.table_name
     from   
         dba_tab_columns col
       , user_objects obj
     where  col.owner in 
              ( select oracle_username from system.fnd_oracle_userid
                where  read_only_flag in ('A','E') )
       and  col.table_name not like '%#'
       and  col.column_name = 'ZD_EDITION_NAME'
       and  obj.object_name =  ad_zd_seed.eds_function(col.table_name)
       and  obj.object_type = 'FUNCTION'
       and  obj.edition_name = sys_context('userenv', 'current_edition_name')
       and  obj.edition_name <> 'ORA$BASE'
       and  exists
              ( select src.line from user_source src
                where  src.name  = obj.object_name
                and  src.type  = obj.object_type
                and  src.text  like '%'||obj.edition_name||'%' );

spool off;
exit;
