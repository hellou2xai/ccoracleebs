REM $Header: /source/addev/ad/12.0/diag/sql/RCS/adzddbdetails.sql,v 120.0.12020000.3 2015/03/27 11:46:00 rraam noship $
REM +==============================================================================+
REM | Copyright (c) 2012, 2015 Oracle Corporation, Redwood Shores, California, USA
REM |                             All Rights Reserved
REM |                            Applications Division
REM +==============================================================================+
REM
REM Script to collect information which might point the developers to
REM probable causes in the instance. 
REM        This script contains all information that is necessary from
REM        to be collected from the database for both AD and TXK

set linesize 130;
set pagesize 50000;
set echo off;
set feedback off;
set termout off;
spool ad_basic_information.out;

prompt
prompt ================================================================
prompt == Check AD TXK codelevel of instance from AD_TRACKABLE_ENTITIES
prompt ================================================================
column abbreviation format a15;
column codelevel format a10;

SELECT abbreviation, codelevel FROM AD_TRACKABLE_ENTITIES WHERE abbreviation in ('txk','ad','au')
/

prompt
prompt ===============================================
prompt List of nodes and appl tops in the instance
prompt ===============================================
column node_name format a30
column is_shared format a10

SELECT
    fn.host node_name ,
    aat.appl_top_id appl_top_id ,
    EXTRACTVALUE(XMLType(TEXT),'//shared_file_system') is_shared
  FROM
    fnd_nodes fn,
    FND_OAM_CONTEXT_FILES focf,
    fnd_product_groups fpg,
    ad_appl_tops aat,
    ad_releases ar
  WHERE     
    focf.NAME not in ('TEMPLATE','METADATA','config.txt') and focf.CTX_TYPE='A' and
    (focf.status is null or upper(focf.status) in ('S','F')) and
    EXTRACTVALUE(XMLType(focf.TEXT),'//file_edition_type') = 'run' and
    focf.node_name=fn.host and
    (fn.support_cp='Y' or fn.support_forms='Y' or
    fn.support_web='Y' or fn.support_admin='Y') and
    aat.appl_top_type='R' and aat.applications_system_name=fpg.applications_system_name and
    aat.active_flag='Y' and
    fpg.release_name=ar.major_version||'.'||ar.minor_version||'.'||ar.tape_version and
    fpg.aru_release_name=ar.aru_release_name and
    aat.name=EXTRACTVALUE(XMLType(focf.TEXT),'//APPL_TOP_NAME');

prompt
prompt ===============================================
prompt  List of nodes in FND_NODES
prompt ===============================================
column host format a30;
column domain format a40;

select node_name, support_CP "CP", support_forms "FORMS", 
       support_web "WEB",support_admin "ADMIN", support_db "DB", 
       status, host, domain  
from fnd_nodes order by node_name;

prompt
prompt ===============================================
prompt  List of database nodes ( >1 implies RAC)
prompt ===============================================

select instance_name, host_name, archiver, thread#, status
from gv$instance;

prompt
prompt ===============================================
prompt  List of nodes in ADOP_VALID_NODES
prompt ===============================================

column node_name format a30;
column context_name format a60;

select node_name, context_name
from adop_valid_nodes;

prompt
prompt ==============================================
prompt  List of APPL_TOPS registered in AD_APPL_TOPS
prompt ==============================================

column name format a30;
column applications_system_name format a30;

select appl_top_id, name, applications_system_name 
from ad_appl_tops where active_flag='Y' and appl_top_type='R'
order by 1;

prompt
prompt ==============================================
prompt  List of PRODUCT GROUPS in FND_PRODUCT_GROUPS
prompt ==============================================
column release_name format a30;
column aru_release_name format a20;

select product_group_id,RELEASE_NAME,applications_system_name,aru_release_name
from fnd_product_groups;

prompt
prompt ==============================================
prompt  List of installed languages in FND_LANGAGES
prompt ==============================================

column language_code format a5;
column nls_language format a30;
column nls_territory format a30;
column installed_flag format a14;

select language_code, language_id, nls_language, nls_territory , installed_flag
from fnd_languages where installed_flag in ('B','I') order by installed_flag, language_code;

REM =================================================
REM Start spooling output of tables to csv files
REM =================================================
set echo off;
set linesize 300;
set pagesize 50000;
set head off;
column node_type format a20;
column edition_name format a20;

REM ===========================================
REM Dump of AD_ADOP_SESSIONS table
REM ===========================================

spool ad_adop_sessions.csv;
prompt ADOP_SESSION_ID,PREPARE_STATUS,APPLY_STATUS,FINALIZE_STATUS,CUTOVER_STATUS,CLEANUP_STATUS,ABORT_STATUS,STATUS,NODE_NAME,NODE_TYPE,APPLTOP_ID,EDITION_NAME,PID,ABANDON_FLAG,PREPARE_START_DATE,PREPARE_END_DATE,APPLY_START_DATE,APPLY_END_DATE,FINALIZE_START_DATE,FINALIZE_END_DATE,CUTOVER_START_DATE,CUTOVER_END_DATE,CLEANUP_START_DATE,CLEANUP_END_DATE,ABORT_START_DATE,ABORT_END_DATE
select ADOP_SESSION_ID||','||
       PREPARE_STATUS||','||
       APPLY_STATUS||','||
       FINALIZE_STATUS||','||
       CUTOVER_STATUS||','||
       CLEANUP_STATUS||','||
       ABORT_STATUS||','||
       STATUS||','||
       NODE_NAME||','||
       NODE_TYPE||','||
       APPLTOP_ID||','||
       EDITION_NAME||','||
       PID||','||
       ABANDON_FLAG||','||
       PREPARE_START_DATE||','||
       PREPARE_END_DATE||','||
       APPLY_START_DATE||','||
       APPLY_END_DATE||','||
       FINALIZE_START_DATE||','||
       FINALIZE_END_DATE||','||
       CUTOVER_START_DATE||','||
       CUTOVER_END_DATE||','||
       CLEANUP_START_DATE||','||
       CLEANUP_END_DATE||','||
       ABORT_START_DATE||','||
       ABORT_END_DATE
from ad_adop_sessions
order by adop_session_id, node_type, node_name;

REM ===========================================
REM Dump of AD_ADOP_SESSION_PATCHES table
REM ===========================================

set linesize 1000;
spool ad_adop_session_patches.csv;
prompt ADOP_SESSION_ID,BUG_NUMBER,PATCHRUN_ID,STATUS,APPLIED_FILE_SYSTEM_BASE,PATCH_FILE_SYSTEM_BASE,APPLTOP_ID,NODE_NAME,ADPATCH_OPTIONS,AUTOCONFIG_STATUS,START_DATE,END_DATE,CLONE_STATUS,PATCH_TOP,DRIVER_FILE_NAME,SESSION_TYPE
select ADOP_SESSION_ID||','||
       BUG_NUMBER||','||
       PATCHRUN_ID||','||
       STATUS||','||
       APPLIED_FILE_SYSTEM_BASE||','||
       PATCH_FILE_SYSTEM_BASE||','||
       APPLTOP_ID||','||
       NODE_NAME||','||
       '"'||ADPATCH_OPTIONS||'",'||
       AUTOCONFIG_STATUS||','||
       START_DATE||','||
       END_DATE||','||
       CLONE_STATUS||','||
       PATCH_TOP||','||
       DRIVER_FILE_NAME||','||
       SESSION_TYPE
from ad_adop_session_patches
order by end_date, node_name, adop_session_id;

REM ===========================================
REM Dump of FND_APPLICATION table
REM ===========================================

set linesize 150;
spool fnd_application.csv
prompt APPLICATION_ID,APPLICATION_SHORT_NAME,LAST_UPDATE_DATE,LAST_UPDATED_BY,CREATION_DATE,CREATED_BY,LAST_UPDATE_LOGIN,BASEPATH,PRODUCT_CODE,ZD_EDITION_NAME
select APPLICATION_ID||','||
       APPLICATION_SHORT_NAME||','||
       LAST_UPDATE_DATE||','||
       LAST_UPDATED_BY||','||
       CREATION_DATE||','||
       CREATED_BY||','||
       LAST_UPDATE_LOGIN||','||
       BASEPATH||','||
       PRODUCT_CODE||','||
       ZD_EDITION_NAME
from fnd_application
order by application_short_name;

REM ===========================================
REM Dump of FND_ORACLE_USERID table
REM ===========================================

set linesize 300;
spool fnd_oracle_userid.csv
prompt ORACLE_ID,ORACLE_USERNAME,LAST_UPDATE_DATE,LAST_UPDATED_BY,CREATION_DATE,CREATED_BY,LAST_UPDATE_LOGIN,DESCRIPTION,ENABLED_FLAG,READ_ONLY_FLAG,ENCRYPTED_ORACLE_PASSWORD,CONCURRENT_BATCH_QUEUE_ID,INSTALL_GROUP_NUM
select ORACLE_ID||','||
       ORACLE_USERNAME||','||
       LAST_UPDATE_DATE||','||
       LAST_UPDATED_BY||','||
       CREATION_DATE||','||
       CREATED_BY||','||
       LAST_UPDATE_LOGIN||','||
       DESCRIPTION||','||
       ENABLED_FLAG||','||
       READ_ONLY_FLAG||','||
       ENCRYPTED_ORACLE_PASSWORD||','||
       CONCURRENT_BATCH_QUEUE_ID||','||
       INSTALL_GROUP_NUM
from fnd_oracle_userid
order by oracle_username;

REM ===========================================
REM Dump of FND_PRODUCT_INSTALLATIONS table
REM ===========================================

set linesize 150;
spool fnd_product_installations.csv;
prompt APPLICATION_ID,APPLICATION_SHORT_NAME,ORACLE_ID,ORACLE_USERNAME,LAST_UPDATE_DATE,LAST_UPDATED_BY,CREATION_DATE,CREATED_BY,LAST_UPDATE_LOGIN,PRODUCT_VERSION,STATUS,INDUSTRY,TABLESPACE,INDEX_TABLESPACE,TEMPORARY_TABLESPACE,SIZING_FACTOR,INSTALL_GROUP_NUM,DB_STATUS
select fpi.APPLICATION_ID||','||
       decode(fa.APPLICATION_SHORT_NAME, NULL,'NULL-MISMATCH',fa.APPLICATION_SHORT_NAME)||','||
       fpi.ORACLE_ID||','||
       decode(fou.ORACLE_USERNAME, NULL,'NULL-MISMATCH',fou.ORACLE_USERNAME)||','||
       fpi.LAST_UPDATE_DATE||','||
       fpi.LAST_UPDATED_BY||','||
       fpi.CREATION_DATE||','||
       fpi.CREATED_BY||','||
       fpi.LAST_UPDATE_LOGIN||','||
       fpi.PRODUCT_VERSION||','||
       fpi.STATUS||','||
       fpi.INDUSTRY||','||
       fpi.TABLESPACE||','||
       fpi.INDEX_TABLESPACE||','||
       fpi.TEMPORARY_TABLESPACE||','||
       fpi.SIZING_FACTOR||','||
       fpi.INSTALL_GROUP_NUM||','||
       fpi.DB_STATUS
from fnd_product_installations fpi,
     fnd_application fa,
     fnd_oracle_userid fou
where fpi.application_id=fa.application_id(+)
  and fpi.oracle_id=fou.oracle_id(+)
order by fa.application_short_name;

REM ===============================================
REM Dump of FND_OAM_CONTEXT_FILES
REM ===============================================

set linesize 1000;
spool fnd_oam_context_files.csv;
prompt NAME,VERSION,PATH,LAST_SYNCHRONIZED,LAST_UPDATED_DATE,LAST_UPDATED_BY,CREATION_DATE,CREATED_BY,LAST_UPDATE_LOGIN,NODE_NAME,APPL_TOP_NAME,FILE_EDITION_TYPE,STATUS,SERIAL_NUMBER,EDIT_COMMENTS,CTX_TYPE
select name||','||
       version||','||
       path||','||
       last_synchronized||','||
       last_update_date||','||
       last_updated_by||','||
       creation_date||','||
       created_by||','||
       last_update_login||','||
       node_name||','||
       EXTRACTVALUE(XMLType(TEXT),'//APPL_TOP_NAME')||','||
       EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')||','||
       status||','||
       serial_number||','||
       edit_comments||','||
       ctx_type
from fnd_oam_context_files order by 1;

REM ================================================
REM  Dump of AD_RELEASES
REM ================================================

set linesize 1000;
spool ad_releases.csv;
prompt RELEASE_ID,MAJOR_VERSION,MINOR_VERSION,TAPE_VERSION,BASE_RELEASE_NAME,ARU_RELEASE_NAME
select release_id||','||
       major_version||','||
       minor_version||','||
       tape_version||','||
       base_release_flag||','||
       aru_release_name
from ad_releases order by major_version,minor_version,tape_version;

spool off
spool ../database/db_checks_and_info.out;
set head on
set linesize 100
set feedback on

prompt
prompt ===============================================
prompt Key parameters of Database
prompt ===============================================

column name format a30
column value format a20
select name, value from v$parameter where name in ('_system_trig_enabled', 'job_queue_processes', 'local_listener');

prompt
prompt ===============================================
prompt Check for the existence of log on trigger
prompt ===============================================
select owner, trigger_name, status 
       from dba_triggers
       where trigger_name='EBS_LOGON';

prompt
prompt ================================================
prompt Checking the existence of the service ebs_patch
prompt ================================================
Column name format a20 Heading "Service Name"
Column network_name format a20 Heading "Network Name"
Column creation_date format a10 Heading "Creation Date"

select name, network_name, creation_date 
       from dba_services 
       where lower(name) LIKE 'ebs_patch%';

prompt
prompt ==============================================
prompt List all the active services
prompt ==============================================
select name, network_name, creation_date 
       from v$active_services 
       where name not like 'SYS%' order by name;

prompt
prompt ============================================
prompt All parameters in database
prompt ============================================
set linesize 100;
column value format a50;
show parameters;

spool off;
spool ad_misc_checks.out

prompt
prompt ===============================================
prompt Timestamp Mismatch query
prompt ===============================================

    SET NUMWIDTH 10
    SET TRIMSPOOL ON
    SET TAB OFF
    SET PAGESIZE 100
    SET LINESIZE 120
    column d_owner format a15
    column p_owner format a15
    column d_name format a30;
    column p_name format a30;
    column d_edition format a15;
    column p_edition format a15;
    column reason format a50;
    select du.name d_owner, d.name d_name, d.defining_edition d_edition,
        pu.name p_owner, p.name p_name, p.defining_edition p_edition,
    case
       when p.status not in (1, 2, 4) then 'P Status: ' || to_char(p.status)||','
    else 'TS mismatch: ' ||
       to_char(dep.p_timestamp, 'DD-MON-YY HH24:MI:SS') || ' ' ||
       to_char(p.stime, 'DD-MON-YY HH24:MI:SS')||','
    end reason
    from sys."_ACTUAL_EDITION_OBJ" d, sys.user$ du, sys.dependency$ dep,
         sys."_ACTUAL_EDITION_OBJ" p, sys.user$ pu
    where d.obj# = dep.d_obj# and p.obj# = dep.p_obj#
      and d.owner# = du.user# and p.owner# = pu.user#
      and d.status = 1                                    -- Valid dependent
      and bitand(dep.property, 1) = 1                     -- Hard dependency
      and d.subname is null                               -- !Old type version
      and not(p.type# = 32 and d.type# = 1)               -- Index to indextype
      and not(p.type# = 29 and d.type# = 5)               -- Synonym to Java
      and not(p.type# in(5, 13) and d.type# in (2, 55))   -- TABL/XDBS to TYPE
      and (p.status not in (1, 2, 4) or p.stime != dep.p_timestamp);


prompt
prompt ============================================
prompt == Check metadata information of ST packages
prompt ============================================
column object_name format a30;
column authid format a30;
column table_name  format a30;
column grantee format a20;
column privilege format a20;
column grantor format a20;

select object_name, authid
from dba_procedures
where object_name in ('DBMS_OBJECTS_UTILS',
                      'DBMS_OBJECTS_APPS_UTILS',
                      'XDB_MIGRATESCHEMA')
  and owner='SYS'
  and procedure_name is null
order by 1,2
/

prompt
prompt ============================================
prompt == Check APPS privilges on ST packages
prompt ============================================

break on table_name

select table_name, grantee, privilege, grantor
from dba_tab_privs
where table_name in ('DBMS_OBJECTS_UTILS',
                     'DBMS_OBJECTS_APPS_UTILS',
                     'XDB_MIGRATESCHEMA' ,
                     'XDB$MOVESCHEMATAB')
  and owner='SYS'
order by 1,2
/

prompt
prompt ==============================================
prompt == Check if stylesheets are loaded to database
prompt ==============================================

set serveroutput on;
declare
  l_grant_given int;
  l_stmt varchar2(1000);
  adlevel varchar2(10);
begin
  select count(*) into l_grant_given from
  (select grantee p1,
          null p2
   from dba_tab_privs
   where owner='SYS' and table_name='DBMS_METADATA_UTIL'
     and privilege='EXECUTE'
   union
   select grantee p1,
          granted_role p2
   from dba_role_privs)
   where p1=(select oracle_username 
             from fnd_oracle_userid
             where read_only_flag='U')
   start with p2 is null
   connect by p2 = prior p1;

  if(l_grant_given = 0)
  then
    select codelevel into adlevel from ad_trackable_entities
    where abbreviation='ad';
    if(adlevel<='C.5')
    then
      dbms_output.put_line('Grants to DBMS_METADATA_UTIL is not given to APPS user');
      dbms_output.put_line('This is expected in instances with AD code level less than Delta 6');
    else
      dbms_output.put_line('ERROR: AD Code level is '||adlevel||' and APPS user should');
      dbms_output.put_line('have grants on DBMS_METADATA_UTIL');
    end if;
  else
    l_stmt:='begin ';
    l_stmt:=l_stmt||'if(sys.dbms_metadata_util.are_stylesheets_loaded) then ';
    l_stmt:=l_stmt||'dbms_output.put_line(''SUCCESS: Stylesheets are loaded to database''); ';
    l_stmt:=l_stmt||'else ';
    l_stmt:=l_stmt||'dbms_output.put_line(''ERROR: Stylesheets not loaded to database''); ';
    l_stmt:=l_stmt||'end if; end;';
    execute immediate l_stmt;
  end if;
end;
/

prompt
prompt ==============================================
prompt == Check the AD CUP patch applied
prompt ==============================================

select bug_number, 
decode(bug_number,'18040523','AD CUP 5','17197279','AD CUP 4',
                  '16595190','AD CUP 3','16177533','AD CUP 2') cup_version 
from ad_bugs 
where bug_number in ('18040523','17197279','16595190','16177533') 
  and rownum=1
order by bug_number desc
/

prompt
prompt ==========================================================
prompt Check if EBS CUP patch applied
prompt ==========================================================
prompt NOTE: Since it is applied in preinstall mode even if patch
prompt       is applied it might not show anything

select bug_number, 
decode(bug_number,'18007406','EBS CUP 5','17197281','EBS CUP 4',
                  '16595191','EBS CUP 3','16177553','EBS CUP 2') cup_version 
from ad_bugs 
where bug_number in ('18007406','17197281','16595191','16177553') 
  and rownum=1
order by bug_number desc
/

prompt
prompt ==================================================
prompt == Check consolidated Seed Upgrade Patches applied
prompt ==================================================

select bug_number from ad_bugs
where bug_number in ('17204589')
/

spool ../config/managed_server_info.out
prompt
prompt =================================================================
prompt == Display the all managed server status and managed server ports
prompt == of Patch file system
prompt =================================================================
column HOSTNAME format a30;
column OACORE_PORT format a30;
column OACORE_STATUS format a10;
column FORMSPORTS format a30;
column FORMSSTATUS format a10;
column OAFMSERVERPORTS format a30;
column OAFMSTATUS format a10;
column FORMSC4WSPORTS format a30;
column FORMSC4WSSTATUS format a10;
column OAEASERVERPORTS format a30;
column OAEASTATUS format a10;
column NMPORT format a30;


SELECT extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') HOSTNAME,
extractValue(XMLType(TEXT),'//oacore_server_ports') "OACORE_PORT",
extractValue(XMLType(TEXT),'//oa_service_status[@oa_var="s_oacorestatus"]') "OACORE_STATUS"
from fnd_oam_context_files
where name not in ('TEMPLATE','METADATA')
and (status is null or status !='H')
and EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')='patch'
and CTX_TYPE = 'A'
/

SELECT extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') HOSTNAME,
extractValue(XMLType(TEXT),'//forms_server_ports') "FORMSPORTS",
extractValue(XMLType(TEXT),'//oa_service_status[@oa_var="s_formsstatus"]') "FORMSSTATUS"
from fnd_oam_context_files
where name not in ('TEMPLATE','METADATA')
and (status is null or status !='H')
and EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')='patch'
and CTX_TYPE = 'A'
/

SELECT extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') HOSTNAME,
extractValue(XMLType(TEXT),'//oafm_server_ports') "OAFMSERVERPORTS",
extractValue(XMLType(TEXT),'//oa_service_status[@oa_var="s_oafmstatus"]') "OAFMSTATUS"
from fnd_oam_context_files
where name not in ('TEMPLATE','METADATA')
and (status is null or status !='H')
and EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')='patch'
and CTX_TYPE = 'A'
/

SELECT extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') HOSTNAME,
extractValue(XMLType(TEXT),'//forms-c4ws_server_ports') "FORMSC4WSPORTS",
extractValue(XMLType(TEXT),'//oa_service_status[@oa_var="s_forms-c4wsstatus"]') "FORMSC4WSSTATUS"
from fnd_oam_context_files
where name not in ('TEMPLATE','METADATA')
and (status is null or status !='H')
and EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')='patch'
and CTX_TYPE = 'A'
/

SELECT extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') HOSTNAME,
extractValue(XMLType(TEXT),'//oaea_server_ports') "OAEASERVERPORTS",
extractValue(XMLType(TEXT),'//oa_service_status[@oa_var="s_oaeastatus"]') "OAEASTATUS",
extractValue(XMLType(TEXT),'//nm_port') "NMPORT"
from fnd_oam_context_files
where name not in ('TEMPLATE','METADATA')
and (status is null or status !='H')
and EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')='patch'
and CTX_TYPE = 'A'
/

prompt
prompt =================================================================
prompt == Display all managed server status and managed server ports
prompt == of Run file system
prompt =================================================================

SELECT extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') HOSTNAME,
extractValue(XMLType(TEXT),'//oacore_server_ports') "OACORE_PORT",
extractValue(XMLType(TEXT),'//oa_service_status[@oa_var="s_oacorestatus"]') "OACORE_STATUS"
from fnd_oam_context_files
where name not in ('TEMPLATE','METADATA')
and (status is null or status !='H')
and EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')='run'
and CTX_TYPE = 'A'
/

SELECT extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') HOSTNAME,
extractValue(XMLType(TEXT),'//forms_server_ports') "FORMSPORTS",
extractValue(XMLType(TEXT),'//oa_service_status[@oa_var="s_formsstatus"]') "FORMSSTATUS"
from fnd_oam_context_files
where name not in ('TEMPLATE','METADATA')
and (status is null or status !='H')
and EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')='run'
and CTX_TYPE = 'A'
/

SELECT extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') HOSTNAME,
extractValue(XMLType(TEXT),'//oafm_server_ports') "OAFMSERVERPORTS",
extractValue(XMLType(TEXT),'//oa_service_status[@oa_var="s_oafmstatus"]') "OAFMSTATUS"
from fnd_oam_context_files
where name not in ('TEMPLATE','METADATA')
and (status is null or status !='H')
and EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')='run'
and CTX_TYPE = 'A'
/

SELECT extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') HOSTNAME,
extractValue(XMLType(TEXT),'//forms-c4ws_server_ports') "FORMSC4WSPORTS",
extractValue(XMLType(TEXT),'//oa_service_status[@oa_var="s_forms-c4wsstatus"]') "FORMSC4WSSTATUS"
from fnd_oam_context_files
where name not in ('TEMPLATE','METADATA')
and (status is null or status !='H')
and EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')='run'
and CTX_TYPE = 'A'
/

SELECT extractValue(XMLType(TEXT),'//host[@oa_var="s_hostname"]') HOSTNAME,
extractValue(XMLType(TEXT),'//oaea_server_ports') "OAEASERVERPORTS",
extractValue(XMLType(TEXT),'//oa_service_status[@oa_var="s_oaeastatus"]') "OAEASTATUS",
extractValue(XMLType(TEXT),'//nm_port') "NMPORT"
from fnd_oam_context_files
where name not in ('TEMPLATE','METADATA')
and (status is null or status !='H')
and EXTRACTVALUE(XMLType(TEXT),'//file_edition_type')='run'
and CTX_TYPE = 'A'
/

exit;

