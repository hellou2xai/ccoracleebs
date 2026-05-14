REM $Header: ADZDDBCC.sql 120.24.12010000.72 2020/03/17 22:45:42 jwsmith ship $
REM dbdrv: none
REM +==============================================================================+
REM | Copyright (c) 2012, 2020 Oracle Corporation, Redwood Shores, California, USA
REM |                             All Rights Reserved
REM |                            Applications Division
REM +==============================================================================+
REM | FILENAME
REM | ADZDDBCC.sql
REM |
REM | DESCRIPTION
REM |    E-Business Suite: Online Patching Database Compliance Checker
REM |
REM |
REM | sqlplus apps/???@DB @$AD_TOP/sql/ADZDDBCC.sql
REM |
REM | Change Log: 3/28/2017  jwsmith Bug 26137712 enhance revoke grants on sys.dual section
REM |             6/20/2017  jwsmith Bug 26314055 Add manual call to sys.ad_grants.cleanup
REM |                        for pre-ebr or pre-12.1 levels.
REM |             4/24/2018  jwsmith Bug 27701216 Add check for _disable_actualization_for_grant
REM |             5/1/2018   jvalenti Bug 25452456 EBS_PATCH SERVICES CHANGES
REM |             12/11/2019 jwsmith Bug 30611142 - _DISABLE_ACTUALIZATION_FOR_GRANT FOR 19C 
REM |             3/16/2020  jwsmith Bug 30882224 - EXEMPTION REQUEST : INDEX KEY SIZE SHOULD BE LESS THAN 3215
REM |             3/16/2020  jwsmith Bug 29797364 - Add check for IMP_FULL_DATABASE role granted to APPS 
REM +==============================================================================+

SET FEEDBACK ON;
SET ECHO OFF;

column instance_name    format a16
column database_name    format a16

column "Product Code"   format a12
column "Product Name"   format a50
column "Code Level"     format a10

column owner            format A16
column name             format A30
column value            format A30
column object_name      format A30
column table_owner      format a16
column table_name       format A30
column data_type_owner  format A16
column data_type        format A30
column column_name      format A30
column trigger_name     format A30
column referenced_owner format A16
column referenced_name  format A30
column refs             format A8
column log_level        format a10
column log_module       format a42
column log_message      format a140
column synonym_name     format a30


column d_owner          format a15
column p_owner          format a15
column d_name           format a30;
column p_name           format a30;
column d_edition        format a25;
column p_edition        format a25;
column reason           format a50;
column mview_owner      format a15
column mview_name       format a30
column btable_owner     format a15
column btable_name      format a30

set pagesize 1000
set linesize 220
set trimspool on
set tab off
set numwidth 10
spool adzddbcc.lst

set feedback off
set head off
select 'Start Time: ' || to_char(sysdate,'DD-MM-YYYY HH24:MI:SS') from dual;
set head on
set feedback on

variable n_Elapsed_Time number;
exec :n_Elapsed_Time := dbms_utility.get_time
/*
** Note: fnd_oracle_userid.read_only_flag is
**  'A' = product account
**  'B' = custom account
**  'C' = APPLSYSPUB
**  'E' = APPLSYS
**  'D' = disabled
**  'U' = APPS
**  'X' = External (Non-Editioned)
**  'Z' = APPS_NE (Non-Editioned)
*/


/*
**    ---- Header ----
*/


DOC
  **********************************************************************
  EBS Online Patching Database Compliance Checker
  $Header: ADZDDBCC.sql 120.24.12010000.72 2020/03/17 22:45:42 jwsmith ship $
  **********************************************************************
#
select instance_name, sys_context('userenv', 'db_name') as database_name, version, sysdate
from   v$instance
/

select abbreviation "Product Code", name "Product Name", codelevel "Code Level"
from   ad_trackable_entities
where  abbreviation in ('ad', 'txk', 'atg_pf')
order by type, abbreviation
/

col "Online Patching Enabled?" for a24

select decode(editions_enabled,
              'Y','Yes',
                  'No') "Online Patching Enabled?"
from  fnd_oracle_userid au,
      dba_users du
where au.oracle_username = du.username
  and au.read_only_flag  = 'U'
/

set timing on
DOC
  **********************************************************************
  SECTION-1
  **********************************************************************
  Online Patching Error Log

  This section shows errors that occurred during Online Patching Enablement
  or the most recent Online Patching session.  Logged errors indicate that
  an action did not complete correctly on the initial attempt, but in some
  cases the problem is corrected later by automatic or manual retry.  Use
  the diagnostic log to determine whether logged errors were resolved.
#

-- Using ref cursor as this script also needs to be executed
-- as part of Readiness report where customer might NOT have
-- AD_ZD_LOGS table.
variable c_ad_zd_logs refcursor;

declare
  l_flag varchar2(1);
  l_sql varchar2(2000) :=
       'select substr(module, 1, 42) log_module,
               type log_level,
               message_text log_message
        from  ad_zd_logs azl, ad_zd_ddl_handler azdh
        where azl.type in (''ERROR'')
        and   azdh.ddl_id(+)=azl.ddl_id
        and   (azdh.status is NULL or azdh.status <>''SUCCESS'')
        order by azl.log_sequence';
begin
  select null into l_flag from dba_tables where table_name='AD_ZD_LOGS' ;
  open :c_ad_zd_logs for l_sql;
exception
  when no_data_found then
    open :c_ad_zd_logs for
    select '' log_module, ''  log_level, '' log_message from dual;
end;
/

print c_ad_zd_logs;


DOC
  **********************************************************************
  SECTION-2  [minimal]
  **********************************************************************
  Database data dictionary corruption

  - P1: If these checks return any rows, please follow the instructions in
        "Fix data dictionary corruption" section of My Oracle Support
        Knowledge Document 1531121.1.

  Note: Upgrade or Online Patching must not be attempted until all
  errors in this section are resolved.
#

select du.name d_owner, d.name d_name, d.defining_edition d_edition,
       pu.name p_owner, p.name p_name, p.defining_edition p_edition,
       decode(d.type#,
              1,'INDEX',
              2,'TABLE',
              3,'CLUSTER',
              4,'VIEW',
              5,'SYNONYM',
              6,'SEQUENCE',
              7,'PROCEDURE',
              8,'FUNCTION',
              9,'PACKAGE',
             10,'NON-EXISTENT',
             11,'PACKAGE BODY',
             12,'TRIGGER',
             13,'TYPE',
             14,'TYPE BODY',
             19,'TABLE PARTITION',
             20,'INDEX PARTITION',
             21,'LOB',
             22,'LIBRARY',
             23,'DIRECTORY',
             24,'QUEUE',
             28,'JAVA SOURCE',
             29,'JAVA CLASS',
             30,'JAVA RESOURCE',
             32,'INDEXTYPE',
             33,'OPERATOR',
             34,'TABLE SUBPARTITION',
             35,'INDEX SUBPARTITION',
             40,'LOB PARTITION',
             41,'LOB SUBPARTITION',
             42,'MATERIALIZED VIEW',
             43,'DIMENSION',
             44,'CONTEXT',
             46,'RULE SET',
             47,'RESOURCE PLAN',
             48,'CONSUMER GROUP',
             55,'XML SCHEMA',
             56,'JAVA DATA',
             57,'EDITION',
             59,'RULE',
             62,'EVALUATION CONTEXT',
             66,'JOB',
             67,'PROGRAM',
             68,'JOB CLASS',
             69,'WINDOW',
             72,'SCHEDULER GROUP',
             74,'SCHEDULE',
             77,'UNDEFINED',
             88,'STUB',
             '???') d_object_type,
      case
         when p.status not in (1, 2, 4) then 'P Status: ' || to_char(p.status)
      else 'TS mismatch: ' ||
           to_char(dep.p_timestamp, 'DD-MON-YY HH24:MI:SS') || ' ' ||
           to_char(p.stime, 'DD-MON-YY HH24:MI:SS')
      end reason
from sys."_ACTUAL_EDITION_OBJ" d,
     sys.user$ du,
     sys.dependency$ dep,
     sys."_ACTUAL_EDITION_OBJ" p,
     sys.user$ pu
where d.obj# = dep.d_obj#
  and d.owner# = du.user#
  and p.obj# = dep.p_obj#
  and p.owner# = pu.user#
  and d.status = 1                                    -- Valid dependent
  and bitand(dep.property, 1) = 1                     -- Hard dependency
  and d.subname is null                               -- !Old type version
  and not(p.type# = 32 and d.type# = 1)               -- Index to indextype
  and not(p.type# = 29 and d.type# = 5)               -- Synonym to Java
  and not(p.type# in(5, 13) and d.type# in (2, 55))   -- TABL/XDBS to TYPE
  and p.type# not in(10, 93)                          -- non-existent or non-CUBE parent
  and (p.status not in (1, 2, 4) or p.stime <> dep.p_timestamp)
/

select d_obj#, eusr.edition_name, eusr.user_name owner, o1.name object_name,
       decode(o1.type#,
              1,'INDEX',
              2,'TABLE',
              3,'CLUSTER',
              4,'VIEW',
              5,'SYNONYM',
              6,'SEQUENCE',
              7,'PROCEDURE',
              8,'FUNCTION',
              9,'PACKAGE',
             10,'NON-EXISTENT',
             11,'PACKAGE BODY',
             12,'TRIGGER',
             13,'TYPE',
             14,'TYPE BODY',
             19,'TABLE PARTITION',
             20,'INDEX PARTITION',
             21,'LOB',
             22,'LIBRARY',
             23,'DIRECTORY',
             24,'QUEUE',
             28,'JAVA SOURCE',
             29,'JAVA CLASS',
             30,'JAVA RESOURCE',
             32,'INDEXTYPE',
             33,'OPERATOR',
             34,'TABLE SUBPARTITION',
             35,'INDEX SUBPARTITION',
             40,'LOB PARTITION',
             41,'LOB SUBPARTITION',
             42,'MATERIALIZED VIEW',
             43,'DIMENSION',
             44,'CONTEXT',
             46,'RULE SET',
             47,'RESOURCE PLAN',
             48,'CONSUMER GROUP',
             55,'XML SCHEMA',
             56,'JAVA DATA',
             57,'EDITION',
             59,'RULE',
             62,'EVALUATION CONTEXT',
             66,'JOB',
             67,'PROGRAM',
             68,'JOB CLASS',
             69,'WINDOW',
             72,'SCHEDULER GROUP',
             74,'SCHEDULE',
             77,'UNDEFINED',
             88,'STUB',
             '???') OBJECT_TYPE
from sys.dependency$ d
   , sys.obj$ o1
   , ( select xusr.user#, xusr.ext_username user_name, ed.name edition_name
       from ( select * from sys.user$ where type# = 2 ) xusr
          , ( select * from sys.obj$ where owner# = 0 and type# = 57 ) ed
       where xusr.spare2 = ed.obj#
       union
       select busr.user#, busr.name user_name, ed.name edition_name
       from ( select * from sys.user$ where type# = 1 or user# = 1 ) busr
          , ( select * from sys.obj$ where owner# = 0 and type# = 57 ) ed
       where ed.name = 'ORA$BASE' ) eusr
where d_obj# = o1.obj#
  and o1.status =1
  and o1.owner# not in (0,1)
  and eusr.user# = o1.owner#
  and (o1.type# <> 13 or o1.subname is null)
  and not exists
        ( select 1
          from sys.obj$ o2
          where p_obj# = o2.obj#)
/


DOC
  **********************************************************************
  SECTION-3
  **********************************************************************
  Compiling invalid objects...
#

/* exec sys.utl_recomp.recomp_parallel */



/*
**    ---- General ----
*/

DOC
  =========================================================================
  Database Object Development Standards Violations

  Customers:
  Please do not attempt to correct violations in objects owned by Oracle.
  Violations vary in severity and impact, follow the guidance in each section
  to determine the impact and recommended action for each reported violation
  on your system.

  Each section reports violations for a particular Online Patching development
  standard.  Each section header shows the following information:

    *********************************************************
    SECTION-<number>  [compliance level]
    *********************************************************
    "Quote of the standard that was checked."

      - Priority and Impact
          P1 violations must be fixed before using the system or object
          P2 violations might not pose an immediate problem, but may
             cause later issues if the affected objects are changed in a
             future online patch.
          P3 violations are minor issues that can be deferred or ignored
      - Instructions to fix the violation
      - Notes and comments

  There are two levels of compliance that can be targeted:

      - Minimal Compliance [minimal]

          These checks represent the minimum requirement for correct operation
          of E-Business Suite Release 12.2.  Do not attempt to operate the 
          system if there are P1 minimal compliance violations.  Custom code
          should pass the minimal compliance checks before being used in a 
          Release 12.2 system.

      - Full Compliance [full]

          These checks indicate whether an object can be patched using 
          Online Patching.  Objects which do not meet full compliance
          may have limitations in how they can be patched, or may need to be 
          patched using downtime patching.  Full compliance also requires
          that all minimal compliance checks are passed.  Custom code that
          will only be patched using downtime patching does not need to meet
          the full compliance level.  

  This report also implements a number of internal checks which verify that
  the upgrade and Online Patching Enablement process executed correctly.  
  Violations of internal checks indicate upgrade failure and should be 
  reviewed with support if the cause is not understood.

  For further information about development standards, review the Online 
  Patching Development Standards chapter of the Oracle E-Business Suite R12.2
  Developer Guide R12.2, and My Oracle Support document 1577661.1.

  The report is designed to run at 3 different release levels.

    - On releases prior to Release 12.2.

        Customers should study violations for their custom objects and plan
        to fix at least the minimal compliance violations before using the
        custom code on Release 12.2.  Fixes for violations in custom code
        can be deployed on the prior release or can be deployed as part of
        the Release 12.2 upgrade project.  

        Note: When run prior to Release 12.2, the report will show many 
        violations in Oracle-owned objects.  These issues will be fixed by
        the Release 12.2 upgrade and should be ignored.

        Note: Some SQL statements in this report have a dependency on Release
        12.2.  If you are running the report in a prior release, any SQL 
        failures can be ignored.

    - On Release 12.2, prior to Online Patching Enablement.

        Investigate all P1 issues before proceeding with Online Patching 
        Enablement.

    - On Release 12.2, after Online Patching Enablement.

        Resolve all P1 issues before using the system.  Customers should fix 
        minimal compliance issues in their custom objects before using those
        objects in Release 12.2.

  =========================================================================
#
prompt
prompt


DOC
  **********************************************************************
  SECTION-4  [minimal]
  **********************************************************************
  "EBS_LOGON Trigger must be enabled."

   - P1: The SYSTEM.EBS_LOGON trigger must exist and must be enabled.
         If not, Online Patching tools will connect to the wrong edition
         in the database, causing system corruption.
   - Fix: Install the SYSTEM.EBS_LOGON trigger by running:
         sqlplus apps/apps $AD_TOP/patch/115/sql/ADZDLTRG <system_password>
#

select 'ERROR - SYSTEM.EBS_LOGON trigger is not enabled' "EBS Logon Trigger Check"
from dual
where not exists
        ( select trigger_name from dba_triggers
          where owner='SYSTEM'
            and trigger_name = 'EBS_LOGON'
            and status = 'ENABLED' )
  and exists
        ( select null
          from fnd_oracle_userid au, dba_users du
          where au.oracle_username = du.username
            and au.read_only_flag = 'U'
            and du.editions_enabled = 'Y' )
/


DOC
  **********************************************************************
  SECTION-5  [minimal]
  **********************************************************************
  "The database initialization parameter _system_trig_enabled must be
   set to TRUE."

   - P1: This violation will prevent Online Patching tools from
         operating correctly, resulting in system corruption.
   - Fix: Set _system_trig_enabled parameter to TRUE
#

select 'ERROR - _system_trig_enabled parameter must be set to TRUE' "_system_trig_enabled Parameter"
from dual
where exists
        ( select null
          from v$parameter
          where name = '_system_trig_enabled'
            and value = 'FALSE' )
/

DOC
  **********************************************************************
  SECTION-5.1  [minimal]
  **********************************************************************
  "The database initialization parameter _disable_actualization_for_grant must be
   set to TRUE."

   - P1: This violation may cause object invalidation if a grant command is
         executed on objects in the run edition. 
   - Fix: 1. Depending on your database version, apply a patch as follows:
             (a) If you are on Oracle Database Release 11gR2 or 12cR1, apply the associated
             database patch (Bug 26654363 - EBR GRANTING PRIVILEGES CAUSES INVALIDATION).
             For more information, refer to Oracle E-Business Suite Release 12.2:
             Consolidated List of Patches and Technology Bug Fixes (Doc ID 1594274.1).
             (b) If you are on Oracle Database Release 19c, no patch is needed.
          2. For all database versions, set the _disable_actualization_for_grant
             database initialization parameter to TRUE.  
#
col param  format a72 head "_disable_actualization_for_grant Parameter"

select 'WARNING - _disable_actualization_for_grant parameter must be set to TRUE' param 
from dual
where not exists
        ( select null
          from v$parameter
          where name = '_disable_actualization_for_grant'
            and value = 'TRUE' )
/


DOC
  **********************************************************************
  SECTION-6  [minimal]
  **********************************************************************
  "'ADMINISTER DATABASE TRIGGER' privilege must not be granted to APPS."

   - P1: This violation will prevent Online Patching tools from
         operating correctly, resulting in system corruption.
   - Fix: Revoke the privilege from APPS.
#

select 'ERROR - ADMINISTER DATABASE TRIGGER privilege must not be granted to '||grantee "ADMINISTER DB TRIGGER Priv"
from dba_sys_privs
where grantee in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag = 'U' )
  and privilege='ADMINISTER DATABASE TRIGGER'
/


DOC
  **********************************************************************
  SECTION-7  [minimal]
  **********************************************************************
  "'EXEMPT ACCESS POLICY' privilege must not be granted to APPS."

   - P1: This violation will cause applications to bypass VPD policies,
         resulting in system corruption.
   - Fix: Revoke the privilege from APPS.
#

select 'ERROR - EXEMPT ACCESS POLICY privilege must not be granted to '||grantee "EXEMPT ACCESS POLICY Priv"
from dba_sys_privs
where grantee in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag = 'U' )
  and privilege = 'EXEMPT ACCESS POLICY'
/


DOC
  **********************************************************************
  SECTION-8  [minimal]
  **********************************************************************
  "Object must be VALID."

   - P1: Invalid objects are non-functional.
   - Invalid Oracle-owned objects that affect application functionality
     must be corrected.  Contact Oracle Support to obtain a correction.
   - Invalid Oracle-owned objects that do not affect application
     functionality can be ignored.
   - Invalid custom or junk objects should be fixed or dropped.

   Note: Although unused invalid objects can be ignored, they should
   eventually be fixed or dropped, as large numbers of invalid objects
   will increase the time required for system compilation.
#

select obj.owner, obj.object_name, obj.object_type
from dba_invalid_objects obj
where obj.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'C', 'E', 'U', 'Z') )
order by 1, 2, 3
/


DOC
  **********************************************************************
  SECTION-9  [minimal]
  **********************************************************************
  "Database Recyclebin should be off."

   - P3: Objects in the recyclebin can prevent full cleanup of
         old database editions.
   - Fix: Set the 'recyclebin' database parameter to 'off'
#

select name, value
from   v$parameter
where  name = 'recyclebin'
and    value = 'on';


/*
prompt
prompt ================================================================================
prompt > "(Internal) APPS_DDL/APPS_ARRAY_DDL must be installed in each EBS schema"
prompt >
prompt >   - P2: Dynamic DDL via AD_DDL may not operate correctly in these schemas
prompt ================================================================================
select x.owner, x.object_name, x.object_type, x.status
from
    (
        select fou.oracle_username owner, 'APPS_DDL' object_name, 'PACKAGE' object_type, obj.status
        from   dba_objects obj, fnd_oracle_userid fou
        where  fou.read_only_flag in ('A', 'E', 'U')
          and  obj.owner(+) = fou.oracle_username
          and  obj.object_name(+) = 'APPS_DDL'
          and  obj.object_type(+) = 'PACKAGE'
      union
        select fou.oracle_username owner, 'APPS_DDL' object_name, 'PACKAGE BODY' object_type, obj.status
        from   dba_objects obj, fnd_oracle_userid fou
        where  fou.read_only_flag in ('A', 'E', 'U')
          and  obj.owner(+) = fou.oracle_username
          and  obj.object_name(+) = 'APPS_DDL'
          and  obj.object_type(+) = 'PACKAGE BODY'
      union
        select fou.oracle_username owner, 'APPS_ARRAY_DDL' object_name, 'PACKAGE' object_type, obj.status
        from   dba_objects obj, fnd_oracle_userid fou
        where  fou.read_only_flag in ('A', 'E', 'U')
          and  obj.owner(+) = fou.oracle_username
          and  obj.object_name(+) = 'APPS_ARRAY_DDL'
          and  obj.object_type(+) = 'PACKAGE'
      union
        select fou.oracle_username owner, 'APPS_ARRAY_DDL' object_name, 'PACKAGE BODY' object_type, obj.status
        from   dba_objects obj, fnd_oracle_userid fou
        where  fou.read_only_flag in ('A', 'E', 'U')
          and  obj.owner(+) = fou.oracle_username
          and  obj.object_name(+) = 'APPS_ARRAY_DDL'
          and  obj.object_type(+) = 'PACKAGE BODY'
    ) x
where x.status is null or x.status != 'VALID'
order by 1, 2, 3
/
*/



/*
**    ---- Editioned Objects ----
*/


DOC
  **********************************************************************
  SECTION-10  [full]
  **********************************************************************
  "APPS object names must end with alphanumeric character."

   - P2: May cause object name conflicts during online patching.
         Use of special characters as the last character of an
         object name is reserved for the Online Patching tool.
   - Fix: Change the object name to use an ordinary identifier character
         as the last character: A-Z a-z 0-9 _ # $
   - Unused objects can be ignored or dropped.
#

select obj.owner, obj.object_name, obj.object_type
from   dba_objects obj
where obj.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('U') )
  and obj.object_type in
        ( 'PACKAGE', 'VIEW', 'SYNONYM', 'TYPE')
  and not regexp_like(obj.object_name, '[A-Za-z0-9_#$]$', 'c')
  and object_name not like 'SYSTP%==' /* ignore junk types from collect */
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = obj.owner
            and aoo.object_name = obj.object_name
            and aoo.object_type in ('PACKAGE', 'VIEW', 'SYNONYM', 'TYPE') )
/


DOC
  **********************************************************************
  SECTION-11  [internal]
  **********************************************************************
  "APPS_NE Object must not also exist in APPS."

   - Check for related errors in the Online Patching Error Log.
#

select obj.owner, obj.object_name, obj.object_type
from   dba_objects neobj, dba_objects obj
where neobj.owner = 'APPS_NE'
  and neobj.object_name not in ('APPS_DDL', 'APPS_ARRAY_DDL')
  and obj.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag = 'U')
  and obj.object_name = neobj.object_name
  and obj.object_type = neobj.object_type
order by 1, 2
/


/*
**    ---- VIEW ----
*/

DOC
  **********************************************************************
  SECTION-12  [full]
  **********************************************************************
  "Editioning view must have table."

   - P3: Extraneous object.
   - Fix: Drop the view.
       SQL> drop view owner.view_name;

   Note: When dropping a table with an editioning view, you must also
         explicitly drop the editioning view to avoid this issue.
#

select owner, view_name
from   dba_editioning_views ev
where not exists
        ( select tab.table_name from dba_tables tab
          where  tab.owner = ev.owner and tab.table_name = ev.table_name )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = ev.owner
            and ((aoo.object_name = ev.view_name  and aoo.object_type = 'VIEW') or
                 (aoo.object_name = ev.table_name and aoo.object_type = 'TABLE')) )
order by 1, 2
/


/*
**    ---- TRIGGER ----
*/


DOC
  **********************************************************************
  SECTION-13  [minimal]
  **********************************************************************
  "Table Trigger must be on the editioning view, not the table, if the
   editioning view exists."

    - P2: These triggers may operate incorrectly once the table is
          patched with revised columns.
    - If the trigger is needed, move it to the editioning view
      by calling the table upgrade procedure.
        SQL> exec ad_zd_table.upgrade(table_owner, table_name)
    - If the trigger is not needed, then drop it
        SQL> drop trigger trigger_owner.trigger_name;

   Note: If the trigger table is a custom table that will not be patched
         using online patching, then this violation can be ignored.
#

select trg.owner, trg.trigger_name, trg.table_owner, trg.table_name
from  dba_triggers trg
where trg.base_object_type = 'TABLE'
  and trg.trigger_name not like 'DR$%'
  and trg.crossedition = 'NO'
  and exists
        ( select ev.view_name
          from   dba_editioning_views ev
          where ev.owner     = trg.table_owner
            and ev.view_name = substrb(trg.table_name, 1, 29)||'#' )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = trg.owner
            and aoo.object_name = trg.trigger_name
            and aoo.object_type = 'TRIGGER' )
  and exists
        ( select null
          from fnd_oracle_userid au, dba_users du
          where au.oracle_username = du.username
            and au.read_only_flag  = 'U'
            and du.editions_enabled = 'Y' )
order by 1, 2
/



/*
**    ---- SYNONYM ----
*/


DOC
  **********************************************************************
  SECTION-14  [minimal]
  **********************************************************************
  "Table Synonym must point to the editioning view, not the table,
   if the editioning view exists."

   - P2: Code that references these synonyms may operate incorrectly
         once the table is patched with revised columns.
   - Fix: Execute the table upgrade procedure.
       SQL> exec ad_zd_table.upgrade(table_owner, table_name)
   - Unused synonyms can be ignored or dropped.
#

select syn.owner, syn.synonym_name, syn.table_owner, syn.table_name
from
    dba_synonyms syn
  , dba_tables   tab
where syn.table_name not like '%#'
  and tab.owner      = syn.table_owner
  and tab.table_name = syn.table_name
  and exists
        ( select ev.view_name
          from   dba_editioning_views ev
          where ev.owner     = syn.table_owner
            and ev.view_name = substrb(syn.table_name, 1, 29)||'#'
        )
  and (syn.owner <> 'SYSTEM' or syn.synonym_name <> 'FND_ORACLE_USERID')
  /* for these table system synonym exist on table*/
  and tab.table_name not in
        ( 'AD_INVOKER_TASKS',
          'AD_PARALLEL_COMPILE',
          'AD_PARALLEL_COMPILE_ERRORS',
          'AD_TIMESTAMPS' )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = syn.owner
            and ((aoo.object_name = syn.synonym_name and aoo.object_type = 'SYNONYM') or
                 (aoo.object_name = syn.table_name   and aoo.object_type = 'TABLE')) )
  and exists
        ( select null
          from fnd_oracle_userid au, dba_users du
          where au.oracle_username = du.username
            and au.read_only_flag  = 'U'
            and du.editions_enabled = 'Y' )
order by 1, 2
/


DOC
  **********************************************************************
  SECTION-15  [minimal]
  **********************************************************************
  "Synonym must point to an object."

   - P3: broken synonyms cause clutter and confusion.
   - Fix: Correct or drop these synonyms.
#

select syn.owner, syn.synonym_name, syn.table_owner, syn.table_name
from  dba_synonyms syn
where syn.table_owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'C', 'E', 'U') )
  and not exists
        ( select obj.object_name
          from   dba_objects obj
          where  obj.owner       = syn.table_owner
            and  obj.object_name = syn.table_name )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = syn.owner
            and ((aoo.object_name = syn.synonym_name and aoo.object_type = 'SYNONYM') or
                 (aoo.object_name = syn.table_name   and aoo.object_type = 'TABLE')) )
order by 1, 2
/



/*
**    ---- VPD POLICY ----
*/


DOC
  **********************************************************************
  SECTION-16  [minimal]
  **********************************************************************
  "VPD Policy must be on the editioning view or table synonym, not the
   table, if the editioning view exists."

   - P2: These VPD policies may operate incorrectly once the table is
         patched with revised columns.
   - Fix: Execute the table upgrade procedure on the affected table.
       SQL> exec ad_zd_table.upgrade(table_owner, table_name)
   - VPD Policies on unused tables can be ignored.

   Note: If the VPD table is a custom table that will not be patched
         using online patching, then this violation can be ignored.
#

select pol.object_owner table_owner, pol.object_name table_name, pol.policy_name
from
    dba_policies pol
  , dba_tables tab
  , dba_editioning_views ev
where pol.object_owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and tab.owner      = pol.object_owner
  and tab.table_name = pol.object_name
  and ev.owner       = tab.owner
  and ev.view_name   = substrb(tab.table_name,1,29)||'#'
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = tab.owner
            and aoo.object_name = tab.table_name
            and aoo.object_type = 'TABLE' )
  and exists
        ( select null
          from fnd_oracle_userid au, dba_users du
          where au.oracle_username = du.username
            and au.read_only_flag  = 'U'
            and du.editions_enabled = 'Y' )
order by 1, 2, 3
/



/*
**    ---- TABLE ----
*/


DOC
  **********************************************************************
  SECTION-17  [full]
  **********************************************************************
  "Table name must not end with '#' character."

  - P2: The '#' character in table and view names is reserved for use by
        the Online Patching tools.  Online patching may not operate
        correctly on tables that violate this standard.
  - Fix: Rename the table and correct any code references to the new
         table name.
#

select tab.owner, tab.table_name
from dba_tables tab
where tab.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and tab.temporary = 'N'
  and tab.secondary = 'N'
  and tab.tablespace_name <> 'APPS_TS_NOLOGGING'
  and not regexp_like(tab.table_name, '[A-Za-z0-9_$]$', 'c')
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = tab.owner
            and aoo.object_name = tab.table_name
            and aoo.object_type = 'TABLE' )
order by 1, 2
/


DOC
  **********************************************************************
  SECTION-18  [full]
  **********************************************************************
  "Table name must be unique within the first 29 bytes."

   - P3: Duplicate table names may cause confusion as to which is the
         "real" table.  Tables that only differ in the 30th character
         may have a conflict in their editioning view names.
   - Fix:  Rename table or drop unwanted table.
#

select
    substrb(tab.table_name, 1, 29) table_name_to_29_chars
  , count(tab.table_name) matches
from dba_tables tab
where tab.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and tab.temporary = 'N'
  and tab.secondary = 'N'  
  and tab.iot_type is null
  and tab.tablespace_name not in ('APPS_TS_NOLOGGING', 'APPS_TS_QUEUES')
  and length(tab.table_name) > 29
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = tab.owner
            and aoo.object_name = tab.table_name
            and aoo.object_type = 'TABLE' )
group by substrb(tab.table_name, 1, 29)
having count(tab.table_name) > 1
/


DOC
  **********************************************************************
  SECTION-19  [full]
  **********************************************************************
  "Table must be owned by an EBS product schema, not APPS."

   - P2: Tables owned by APPS cannot be patched using online patching.
   - Fix: Move table to a product schema and then call the table
         upgrade procedure.
       SQL> ad_zd_table.upgrade(new_owner, table_name)
   - Note: An unused table can be ignored or dropped.  Tables that are
           managed dynamically by application runtime can be ignored.
#

select tab.table_name
from user_tables tab
where tab.temporary = 'N'
  and tab.secondary = 'N'
  and tab.iot_type is null
  and tab.tablespace_name not in ('APPS_TS_NOLOGGING', 'APPS_TS_QUEUES')
  and not regexp_like(tab.table_name, '^AQ\$', 'c')
  and not regexp_like(tab.table_name, '^AW\$', 'c')
  and not regexp_like(tab.table_name, '^OWB\$', 'c')
  and not regexp_like(tab.table_name, '^MLOG\$', 'c')
  and not regexp_like(tab.table_name, '^PROF\$', 'c')
  and not regexp_like(tab.table_name, '^RUPD\$_', 'c')
  and not regexp_like(tab.table_name, '^DR_', 'c')
  and not regexp_like(tab.table_name, '^AP_TEMP_DATA_DRIVER', 'c')
  and not regexp_like(tab.table_name, '^BSC_DI_[0-9_]+$', 'c')
  and not regexp_like(tab.table_name, '^BSC_D_.+$', 'c')
  and not regexp_like(tab.table_name, '^BIM_.*_TEMP$', 'c')
  and not regexp_like(tab.table_name, '^FA_ARCHIVE_ADJUSTMENT_.+$', 'c')
  and not regexp_like(tab.table_name, '^FA_ARCHIVE_DETAIL_.+$', 'c')
  and not regexp_like(tab.table_name, '^FA_ARCHIVE_SUMMARY_.+$', 'c')
  and not regexp_like(tab.table_name, '^GL_DAILY_POST_INT_.+$', 'c')
  and not regexp_like(tab.table_name, '^GL_INTERCO_BSV_INT_[0-9]+$', 'c')
  and not regexp_like(tab.table_name, '^GL_MOVEMERGE_BAL_[0-9]+$', 'c')
  and not regexp_like(tab.table_name, '^GL_MOVEMERGE_INTERIM_[0-9]+$', 'c')
  and not regexp_like(tab.table_name, '^XLA_GLT_[0-9]+$', 'c')
  and not regexp_like(tab.table_name, '^ICX_POR_C[0-9]+.*$', 'c')
  and not regexp_like(tab.table_name, '^ICX_POR_UPLOAD_[0-9]+.*$', 'c')
  and not regexp_like(tab.table_name, '^IGI_SLS_[0-9]+$', 'c')
  and not regexp_like(tab.table_name, '^JTF_TAE_[0-9]+.*$', 'c')
  and not regexp_like(tab.table_name, '^JTY_[0-9]+_.*$', 'c')
  and not regexp_like(tab.table_name, '^ZPBDATA[0-9]+_EXCPT_T$', 'c')
  and not regexp_like(tab.table_name, '^ZX_DATA_UPLOAD_.*$', 'c')
  and not regexp_like(tab.table_name, '_BACKUP', 'c')
  and not regexp_like(tab.table_name, '_TEMP$', 'c')
  and not regexp_like(tab.table_name, '^EUL.+$', 'c')
  and not regexp_like(tab.table_name, '^MISCN_TMP_.+$', 'c')
  and not regexp_like(tab.table_name, '^TEMP_.+$', 'c')
  /* EXCLUDE MVs */
  and not exists
        ( select mview_name from user_mviews dmv
          where  ( dmv.mview_name = tab.table_name or
                   dmv.container_name = tab.table_name or
                   dmv.update_log = tab.table_name ) )
  /* EXCLUDE normal AQ tables.*/
  and not exists
        ( select 1 from user_queue_tables qt
          where qt.queue_table=tab.table_name )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and aoo.object_name = tab.table_name
            and ((fou.oracle_username = user and aoo.object_type = 'TABLE') or
                 (aoo.object_type = 'MATERIALIZED VIEW')) )
group by tab.table_name
order by tab.table_name
/


DOC
  **********************************************************************
  SECTION-20  [full]
  **********************************************************************
  "Table must have an editioning view."

   - P2: These tables may not be patched using online patching.
   - Fix:  Execute the table upgrade procedure.
       SQL> exec ad_zd_table.upgrade(table_owner, new_table_name)
   Note: Tables that are dynamically created by application runtime
         can be ignored.
   Note: Tables that end with "_A" are typically audit tables
         by the Audit Trail feature, and can be ignored.
   Note: This check is only active after Online Patching Enablement.
#

select tab.owner owner, tab.table_name table_name
from dba_tables tab
where tab.owner in
        ( select oracle_username from system.fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and tab.temporary = 'N'
  and tab.secondary = 'N'
  and tab.iot_type is null
  and tab.tablespace_name not in ('APPS_TS_NOLOGGING', 'APPS_TS_QUEUES')
  and tab.table_name not like '%$'
  and not regexp_like(tab.table_name, '^AQ\$', 'c')
  and not regexp_like(tab.table_name, '^AW\$', 'c')
  and not regexp_like(tab.table_name, '^MLOG\$', 'c')
  and not regexp_like(tab.table_name, '^BSC_DI_[0-9_]+$', 'c')
  and not regexp_like(tab.table_name, '^BSC_D_.+$', 'c')
  and not regexp_like(tab.table_name, '^FA_ARCHIVE_ADJUSTMENT_.+$', 'c')
  and not regexp_like(tab.table_name, '^FA_ARCHIVE_DETAIL_.+$', 'c')
  and not regexp_like(tab.table_name, '^FA_ARCHIVE_SUMMARY_.+$', 'c')
  and not regexp_like(tab.table_name, '^GL_DAILY_POST_INT_.+$', 'c')
  and not regexp_like(tab.table_name, '^GL_INTERCO_BSV_INT_[0-9]+$', 'c')
  and not regexp_like(tab.table_name, '^GL_MOVEMERGE_BAL_[0-9]+$', 'c')
  and not regexp_like(tab.table_name, '^GL_MOVEMERGE_INTERIM_[0-9]+$', 'c')
  and not regexp_like(tab.table_name, '^XLA_GLT_[0-9]+$', 'c')
  and not regexp_like(tab.table_name, '^ICX_POR_C[0-9]+.*$', 'c')
  and not regexp_like(tab.table_name, '^ICX_POR_UPLOAD_[0-9]+.*$', 'c')
  and not regexp_like(tab.table_name, '^IGI_SLS_[0-9]+$', 'c')
  and not regexp_like(tab.table_name, '^JTF_TAE_[0-9]+.*$', 'c')
  and not regexp_like(tab.table_name, '^JTY_[0-9]+_.*$', 'c')
  and not regexp_like(tab.table_name, '^ZPBDATA[0-9]+_EXCPT_T$', 'c')
  and not regexp_like(tab.table_name, '^ZX_DATA_UPLOAD_.*$', 'c')
    /* Note: Exclusion list for AD varies by release */
  and ( ( tab.table_name not in
            ('TXK_TCC_RESULTS',
             'AD_DEFERRED_JOBS',
             'AD_TABLE_INDEX_INFO',
             'FND_INSTALL_PROCESSES',
             'AD_UTIL_PARAMS',
             'AD_PATCHED_TABLES',
             'AD_ZD_DDL_HANDLER',
             'AD_OBSOLETE_OBJECTS',
             'FND_PRODUCT_INSTALLATIONS')
          and
            ( select codelevel from ad_trackable_entities
              where upper(abbreviation)='AD' ) < 'C.1' )
        or
        ( tab.table_name not in
            ('TXK_TCC_RESULTS',
             'AD_DEFERRED_JOBS',
             'AD_TABLE_INDEX_INFO',
             'FND_INSTALL_PROCESSES',
             'AD_UTIL_PARAMS' )
          and
            ( select codelevel from ad_trackable_entities
              where upper(abbreviation)='AD' ) >= 'C.1' )
      )
  and (tab.owner, tab.table_name) not in
        ( select qt.owner, qt.queue_table
          from   dba_queue_tables qt )
  and (tab.owner, tab.table_name) not in
        ( select mv.owner, mv.container_name
          from   dba_mviews mv )
  and (tab.owner, tab.table_name) in
        ( select syn.table_owner, syn.table_name
          from   dba_synonyms syn
          where  syn.owner  in
                   ( select oracle_username from system.fnd_oracle_userid
                     where  read_only_flag ='U' ) )
  and not exists
        ( select ev.owner, ev.view_name
          from dba_editioning_views ev
          where ev.owner      = tab.owner
            and ev.table_name = tab.table_name
            and ev.view_name  = substrb(tab.table_name, 1, 29)||'#' )
  and exists
        ( select null
          from fnd_oracle_userid au, dba_users du
          where au.oracle_username = du.username
            and au.read_only_flag  = 'U'
            and du.editions_enabled = 'Y' )  
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = tab.owner
            and aoo.object_name = tab.table_name
            and aoo.object_type = 'TABLE' )
order by tab.owner, tab.table_name
/


DOC
  **********************************************************************
  SECTION-21  [full]
  **********************************************************************
  "Base column name can only use '#' as the last character."

   - P2: These columns will not show correctly in the editioning view.
   - Fix: Rename the column
       SQL> alter table table_owner.table_name
            rename column column_name to new_column_name;
   - Unused tables and columns can be ignored.
   Note: This check only works prior to Online Patching Enablement.
#

select col.owner, col.table_name, col.column_name
from
   dba_tab_columns col
where exists
     ( select null from dba_tables tab
       where tab.owner in
           ( select oracle_username from fnd_oracle_userid
             where  read_only_flag in ('A', 'B', 'E') )
         and tab.temporary = 'N'
         and tab.secondary = 'N'
         and tab.tablespace_name  <> 'APPS_TS_NOLOGGING'
         and tab.owner = col.owner
         and tab.table_name = col.table_name )
  and regexp_like(col.column_name, '^..*#..*$', 'c')
  and not exists
        ( select null from dba_editioning_views ev
          where ev.owner = col.owner
            and ev.table_name = col.table_name )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = col.owner
            and aoo.object_name = col.table_name
            and aoo.object_type = 'TABLE' )
order by 1, 2, 3
/


DOC
  **********************************************************************
  SECTION-22  [full]
  **********************************************************************
  "Base column name must be unique within 28 bytes."

   - P3: these columns cannot be revised using the same logical name
         during online patching.
   - Fix violations by renaming the column to a shorter base name.
       SQL> alter table table_owner.table_name
            rename column column_name to new_column_name;
       SQL> ad_zd_table.patch(table_owner, table_name)
   - Fixes can be deferred until there is a reason to patch the column.
     Unused columns can be ignored.
   Note: This check only works after Online Patching Enablement.
#

select
    col.owner owner
  , col.table_name table_name
  , substrb(col.column_name, 1, 28) column_name_to_28_chars
  , count(col.column_name) matches
from
    dba_editioning_views ev
  , dba_tab_columns col
where ev.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and col.owner = ev.owner
  and col.table_name = ev.table_name
  and length(col.column_name) > 28
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = ev.owner
            and ((aoo.object_name = ev.view_name and aoo.object_type = 'VIEW') or
                 (aoo.object_name = ev.table_name and aoo.object_type = 'TABLE')) )
group by col.owner, col.table_name, substrb(col.column_name, 1, 28)
having count(col.column_name) > 1
order by 1, 2, 3
/


DOC
  **********************************************************************
  SECTION-23  [internal]
  **********************************************************************
  "Column Type must be a built-in type or non-editioned User Defined Type."

   - Check for related errors in the Online Patching Enablement error log.
#

select col.owner, col.table_name, col.column_name, col.data_type_owner, col.data_type
from
    dba_tables tab
  , dba_tab_columns col
where tab.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E', 'U') )
  and col.owner = tab.owner
  and col.table_name = tab.table_name
  and col.data_type_owner not in ('APPS_NE', 'SYS', 'MDSYS', 'SYSTEM')
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = tab.owner
            and aoo.object_name = tab.table_name
            and aoo.object_type = 'TABLE' )
  and exists
        ( select null
          from fnd_oracle_userid au, dba_users du
          where au.oracle_username = du.username
            and au.read_only_flag  = 'U'
            and du.editions_enabled = 'Y' )
union
/* Below SQL checks for nested tables, mainly created for XML schemas */
select col.owner, col.table_name, col.column_name, col.data_type_owner, col.data_type
from
    dba_nested_tables tab
  , dba_nested_table_cols col
where tab.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and col.owner = tab.owner
  and col.table_name = tab.table_name
  and col.data_type_owner not in ('APPS_NE', 'SYS', 'MDSYS', 'SYSTEM', 'XDB')
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = tab.owner
            and aoo.object_name = tab.table_name
            and aoo.object_type = 'TABLE' )
  and exists
        ( select null
          from fnd_oracle_userid au, dba_users du
          where au.oracle_username = du.username
            and au.read_only_flag  = 'U'
            and du.editions_enabled = 'Y' )
order by 1, 2, 3
/


DOC
  **********************************************************************
  SECTION-24  [full]
  **********************************************************************
  "Column Type must not be LONG or LONG RAW."

   - P2: These columns cannot be patched using Online Patching.
   - Fix: Alter the column datatype to CLOB or BLOB.
       SQL> alter table owner.table_name modify column_name CLOB;
   - Note: The LONG-to-CLOB datatype change should be implemented before
           Online Patching Enablement.
   - Note: If you alter the column type via 'ALTER TABLE' DDL (instead of using
           using XDF/ODF) you will need to rebuild indexes on the affected
           table manually.
       SQL> alter index owner.index_name rebuild;
   - Note: Changing a LONG to CLOB will cause any trigger that references the
           CLOB column in the "UPDATE OF" clause of a trigger to go invalid.
           Fix this by referencing the table in the "ON" clause of the trigger
   - Unused LONG columns can be ignored, but should be dropped.
#

select col.owner, col.table_name, col.column_name, col.data_type
from
    dba_tables tab
  , dba_tab_columns col
where tab.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'E') )
  and tab.temporary = 'N'
  and tab.secondary = 'N'
  and tab.tablespace_name  <> 'APPS_TS_NOLOGGING'
  and col.owner      = tab.owner
  and col.table_name = tab.table_name
  and col.data_type  in ('LONG', 'LONG RAW')
  and not exists
        ( select /*+ push_subq no_unnest */ 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = tab.owner
            and aoo.object_name = tab.table_name
            and aoo.object_type = 'TABLE' )
order by 1, 2
/

DOC
  **********************************************************************
  SECTION-25  [minimal]
  **********************************************************************
  "Column Type should not be ROWID."

   - P2: Stored ROWID references may be broken when tables are patched.
   - Fix: Re-design table to reference the target table primary key.
   - Unused columns or columns that only store the ROWID temporarily
     can be ignored.
   Note: this check does not work prior to Online Patching Enablement.
#
select col.owner, col.table_name, col.column_name, col.data_type
from
    dba_editioning_views ev
  , dba_tab_columns col
where ev.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and col.table_name not in /* Exclusion list: tables with temporary data */
        (
          /* bug 14760688 */
          'AD_PARALLEL_WORKERS',
          /* bug 14771654 */
          'AMS_LIST_ENTRIES_PURGE',
          /* bug 14771817 */
          'AS_TAP_PURGE_WORKING',
          /* bug 15874106 */
          'BOM_ODI_WS_REVISIONS',
          /* bug 15876194 */
          'CN_NOT_TRX_ALL',
          /* bug 15843184 */
          'CST_BIS_MARGIN_SUMMARY',
          'CST_MARGIN_SUMMARY',
          'CST_MARGIN_TEMP',
          /* bug 17673256 */
          'CSI_EID_CUST_INST_PROCESS_TEMP',
           /* bug 16165233 */
          'DDR_I_RTL_SL_RTN_ITEM',
          'DDR_I_SLS_FRCST_ITEM',
           /* bug 17673261 */
          'EAM_EID_WO_PROCESS_TEMP',
          'EAM_EID_WR_PROCESS_TEMP',
          /* bug 14774307 */
          'FND_OAM_DSCRAM_ARG_VALUES',
          /* bug 15828807, 16190549 */
          'GL_BC_PACKETS',
          'GL_BC_PACKETS_HISTS',
          /* bug 14789658 */
          'HZ_IMP_ADDRESSES_SG',
          'HZ_IMP_ADDRESSUSES_SG',
          'HZ_IMP_CLASSIFICS_SG',
          'HZ_IMP_CONTACTPTS_SG',
          'HZ_IMP_CONTACTROLES_SG',
          'HZ_IMP_CONTACTS_SG',
          'HZ_IMP_CREDITRTNGS_SG',
          'HZ_IMP_FINNUMBERS_SG',
          'HZ_IMP_FINREPORTS_SG',
          'HZ_IMP_PARTIES_SG',
          'HZ_IMP_RELSHIPS_SG',
          'HZ_IMP_TMP_ERRORS',
          'HZ_IMP_TMP_REL_END_DATE',
          'HZ_SRCH_CONTACTS',
          'HZ_SRCH_CPTS',
          'HZ_SRCH_PARTIES',
          'HZ_SRCH_PSITES',
          'HZ_THIN_ST_CONTACTS',
          'HZ_THIN_ST_CPTS',
          'HZ_THIN_ST_PARTIES',
          'HZ_THIN_ST_PSITES',
           /* bug 16507311 */
          'IGI_MHC_DEPRN_DETAIL',
          'IGI_MHC_DEPRN_SUMMARY',
          'IGI_MHC_LEDGER',
          /* bug 18221984 */
          'JE_PT_INTERFACE_LINES_EXTS',
          /* bug 14762204 */
          'JL_BR_INTERFACE_LINES_EXTS',
          /* bug 15836849 */
          'MSC_PQ_RESULTS',
          /* bug 14770945 */
          'MTL_ONHAND_DISCREPANCIES',
          'MTL_ONHAND_QUANTITIES_BACKUP',
          'MTL_ONHAND_QUANTITIES_D_BKP',
          /* bug 14843267 */
          'OKC_KEXP_REPORT',
          /* bug 14812560 */
          'OKS_INT_ERROR_STG_TEMP',
          'OKS_INT_HEADER_STG_TEMP',
          'OKS_INT_LINE_STG_TEMP',
          'OKS_INT_SALES_CREDIT_STG_TEMP',
          'OKS_INT_USAGE_COUNTER_STG_TEMP',
          /* bug 16767837 */
          'PA_PJT_EVENTS',
          'PA_PJT_EVENTS_02',
          /* Bug 14811177 */
          'PA_TXN_ACCUM_DETAILS_AR',
          'PA_TXN_UPGRADE_TEMP',
          'PJI_AC_RMAP_ACR',
          'PJI_FM_AGGR_ACT2',
          'PJI_FM_AGGR_FIN2',
          'PJI_FM_DNGL_ACT',
          'PJI_FM_DNGL_FIN',
          'PJI_FM_EXTR_ARINV',
          'PJI_FM_EXTR_DINVC',
          'PJI_FM_EXTR_DREVN',
          'PJI_FM_EXTR_FUNDG',
          'PJI_FM_EXTR_PLNVER2',
          'PJI_FM_REXT_CDL',
          'PJI_FM_REXT_CRDL',
          'PJI_FM_REXT_ERDL',
          'PJI_FM_RMAP_ACT',
          'PJI_FM_RMAP_FIN',
          'PJI_FP_RMAP_FPR',
          'PJI_FM_RMAP_PSI',
          'PJI_MERGE_HELPER',
          'PJI_PA_PROJ_EVENTS_LOG',
          'PJI_PJP_RMAP_ACR',
          'PJI_PJP_RMAP_FPR',
          'PJI_RM_DNGL_RES',
          'PJI_RM_REXT_FCSTITEM',
          /* bug 14766363 */
          'QA_BUG1339720_TEMP',
          /* bug 14793655 */
          'WF_UR_VALIDATE_STG',
          /* bug 18816616 */
          'HR_COUNTRY_DELTA_SYNC',
          /* bug 15877660 */
          'XTR_JOURNALS_EFC'
        )
  and col.owner      = ev.owner
  and col.table_name = ev.table_name
  and col.data_type  = 'ROWID'
  and not exists
         ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = col.owner
            and (aoo.object_name = col.table_name
                 and aoo.object_type = 'TABLE') )
order by 1, 2, 3
/


DOC
  **********************************************************************
  SECTION-26  [minimal]
  **********************************************************************
  "Query/DML statements must access tables via the APPS table synonym."

   - P2: These objects may operate incorrectly after the referenced table
         has been patched.
   - Fix:  Change the object to reference tables via the APPS table synonym.
#

/*
** Selects objects that reference tables directly
** Excludes
**   - Synonyms (which are checked in section-14)
**   - Materialized views (which go direct to tables)
**   - Editioning views (which cover tables)
**   - Crossedition triggers (which transform revised data)
**   - various other special triggers
**   - references to temporary/secondary tables
**   - references to tables not visible in APPS
*/
select
    dep.owner              owner
  , dep.name               object_name
  , dep.type               object_type
  , dep.referenced_owner   referenced_owner
  , dep.referenced_name    referenced_name
from
    dba_dependencies dep
  , dba_tables tab
where dep.referenced_type = 'TABLE'
  and dep.referenced_owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and dep.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'C', 'E', 'U') )
    /* ignore reference to AQ objects */
  and not dep.referenced_name like 'AQ$%'
    /* ignore synonyms */
  and not dep.type in ('UNDEFINED', 'SYNONYM')
    /* ignore materialized view on editioned system */
  and not ( dep.type = 'MATERIALIZED VIEW' and
            exists
              ( select null from dba_users
                where username = user
                  and editions_enabled = 'Y' ) )
    /* ignore editioning view */
  and not ( dep.type = 'VIEW' and
            dep.owner = dep.referenced_owner and
            dep.name  = substrb(dep.referenced_name, 1, 29)||'#' )
    /* ignore trigger if no EV or special */
  and not ( dep.type = 'TRIGGER' and
            ( not exists
                ( select null from dba_editioning_views ev
                  where ev.owner     = dep.referenced_owner
                    and ev.view_name = substrb(dep.referenced_name, 1, 29)||'#' ) or
             (dep.owner, dep.name) in
                ( select owner, trigger_name from dba_triggers
                  where crossedition <> 'NO'
                    or  trigger_name like '%_WHO'
                    or  trigger_name like 'DR$%') ) )
    /* ignore queue tables */
  and not exists
        ( select null from dba_queue_tables qt
          where qt.owner = dep.referenced_owner
            and qt.queue_table = dep.referenced_name )
    /* only check ordinary tables */
  and tab.owner = dep.referenced_owner
  and tab.table_name = dep.referenced_name
  and tab.temporary = 'N'
  and tab.secondary = 'N'
  and tab.iot_type is null
    /* only check tables visible to APPS */
  and exists
        ( select null from user_synonyms
          where table_owner = dep.referenced_owner
            and table_name in (dep.referenced_name, substrb(dep.referenced_name, 1, 29)||'#' ) )
order by 1, 2, 3, 4, 5
/

DOC
  **********************************************************************
  SECTION-27  [internal]
  **********************************************************************
  "AQ table must NOT have an editioning view."
#

select 'exec ad_zd_table.downgrade('''||qt.owner||''', '''||qt.queue_table||''')'
from
    dba_queue_tables qt
  , dba_editioning_views ev
where  ev.owner      = qt.owner
  and  ev.table_name = qt.queue_table
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = ev.owner
            and ((aoo.object_name = ev.view_name and aoo.object_type = 'VIEW') or
                 (aoo.object_name = ev.table_name and aoo.object_type = 'TABLE')) )
order by 1
/

select 'exec ad_zd_table.downgrade('''||tab.owner||''', '''||tab.table_name||''')'
from
    dba_tables tab
  , dba_editioning_views ev
where ev.owner      = tab.owner
  and ev.table_name = tab.table_name
  and tab.table_name like 'AQ$%'
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = ev.owner
            and ((aoo.object_name = ev.view_name and aoo.object_type = 'VIEW') or
                 (aoo.object_name = ev.table_name and aoo.object_type = 'TABLE')) )
order by 1
/


/*
**    ---- SEED DATA TABLE ----
*/


DOC
  **********************************************************************
  SECTION-28  [internal]
  **********************************************************************
  "Seed data table must have standard ZD_EDITION_NAME column."

   - P2: failed upgrade of seed data table, do not use until corrected.
   - ZD_EDITION_NAME column must be VARCHAR2(30) NOT NULL
   - Check ad_zd_logs for related messages
#

select tab.owner, tab.table_name, col.column_name, col.data_type, col.data_length, col.nullable
from
    dba_tables tab
  , dba_tab_columns col
where tab.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and col.owner = tab.owner
  and col.table_name = tab.table_name
  and col.column_name = 'ZD_EDITION_NAME'
  and (col.data_type <> 'VARCHAR2' or
       col.data_length <> 30 or
       col.nullable = 'Y'
      )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = tab.owner
            and aoo.object_name = tab.table_name
            and aoo.object_type = 'TABLE' )
order by 1, 2
/


DOC
  **********************************************************************
  SECTION-29  [internal]
  **********************************************************************
  "Seed data table must have a maintenance trigger."

   - P1: failed upgrade of seed data table, do not use until corrected.
   - Check ad_zd_logs for related messages.
#

select tab.owner, tab.table_name, 'exec ad_zd_seed.upgrade('''||tab.table_name||''')'
from
    dba_tables tab
  , dba_tab_columns col
where tab.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and col.owner = tab.owner
  and col.table_name = tab.table_name
  and col.column_name = 'ZD_EDITION_NAME'
  and not exists
        ( select trg.trigger_name from dba_triggers trg
          where  trg.owner  in ( select oracle_username
                                 from   system.fnd_oracle_userid
                                 where  read_only_flag ='U'
                                )
            -- eds_trigger
            and  trg.trigger_name =  substr(upper(tab.table_name), 1, 29)||'+'
            and  trg.table_owner  = tab.owner
            -- EV
            and  trg.table_name   =  substrb(tab.table_name,1,29)||'#' )
  and not exists
        (select 1
        from system.fnd_oracle_userid fou
        , fnd_product_installations fpi
        , ad_obsolete_objects aoo
        where fpi.application_id = aoo.application_id
        and fou.oracle_id = fpi.oracle_id
        and fou.oracle_username = tab.owner
        and aoo.object_name = tab.table_name
        and aoo.object_type = 'TABLE'
        )
order by 1, 2
/


DOC
  **********************************************************************
  SECTION-30  [internal]
  **********************************************************************
  "Seed data table must have a VPD policy on the EV."

   - P1: failed upgrade of seed data table, do not use until corrected.
   - Check ad_zd_logs for related messages
#

select tab.owner, tab.table_name
from
    dba_tables tab
  , dba_tab_columns col
where tab.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and col.owner = tab.owner
  and col.table_name = tab.table_name
  and col.column_name = 'ZD_EDITION_NAME'
  and not exists
        ( select pol.policy_name  from dba_policies pol
          where  pol.object_owner = tab.owner
            and  pol.object_name  = substrb(tab.table_name,1,29)||'#' -- EV
            and  pol.policy_name  = 'ZD_SEED'
            and  pol.enable       = 'YES' ) /* bug-20984009 */
  and not exists
        (select 1
        from system.fnd_oracle_userid fou
        , fnd_product_installations fpi
        , ad_obsolete_objects aoo
        where fpi.application_id = aoo.application_id
        and fou.oracle_id = fpi.oracle_id
        and fou.oracle_username = tab.owner
        and aoo.object_name = tab.table_name
        and aoo.object_type = 'TABLE'
        )
order by 1, 2
/


DOC
  **********************************************************************
  SECTION-31  [internal]
  **********************************************************************
  "Seed data table must have a VPD policy function."

   - P1: failed upgrade of seed data table, do not use until corrected.
   - Check ad_zd_logs for related messages.
#

select tab.owner, tab.table_name
from
    dba_tables tab
  , dba_tab_columns col
where tab.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and col.owner = tab.owner
  and col.table_name = tab.table_name
  and col.column_name = 'ZD_EDITION_NAME'
  and not exists
        ( select fun.object_name from dba_objects fun
          where  fun.owner in
                   ( select oracle_username from system.fnd_oracle_userid
                     where  read_only_flag ='U' )
            -- eds_function
            and  fun.object_name = substr(upper(tab.table_name), 1, 29)||'='
            and  fun.object_type = 'FUNCTION' )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = tab.owner
            and aoo.object_name = tab.table_name
            and aoo.object_type = 'TABLE' )
order by 1, 2
/


DOC
  **********************************************************************
  SECTION-32  [full]
  **********************************************************************
  "Seed Data Table must have a unique index."

   - P2: Run Edition updates to these tables will not be synchronized to the
         Patch Edition if these tables are loaded during online patching.
   - This violation can be ignored if the table is "Read-Only" for the runtime
     application.  To remove read-only tables from this report, please log a
     bug with AD (166/OP).
   Note: This check only works after Online Patching Enablement.
#

select tab.owner, tab.table_name
from
    dba_tables tab
  , dba_tab_columns col
where tab.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and tab.table_name not in /*known read-only tables*/
        ( 'ADOP_VALID_NODES'
        , 'AHL_APPROVAL_RULES_TL'
        , 'AHL_STATUS_ORDER_RULES'
        , 'AP_PRODUCT_REGISTRATIONS'
        , 'CZ_LOOKUP_VALUES'
        , 'CZ_NODE_TYPE_CLASSES'
        /* bug-22614718 */
        , 'EGO_ODI_WS_XSL_ZD'
        , 'FND_IREP_FLEXFIELDS'
        /* bug-18590406 */
        , 'FND_IREP_FUNCTION_FLAVORS'
        , 'FND_OBJECT_DEFINITIONS'
        , 'FRM_XML_ADAPTORS'
        /* bug-18348505 */
        , 'ISG_ERROR_CODES_MAP'
        , 'ITG_ORG_INDICATOR'
        , 'JTF_DPF_LOGICAL_PAGES_TL'
        , 'JTF_DPF_PHYSICAL_PAGES_B'
        , 'JTF_DPF_PHYSICAL_PAGES_TL'
        /* bug-18717546 */
        , 'JTF_HEADER_DTD'
        , 'JTF_MESSAGE_OBJECTS'
        /* bug-18634726 */
        , 'JTY_TRANS_USG_PGM_DETAILS'
        , 'JTY_TRANS_USG_PGM_SQL'
        , 'PAY_AC_VENDOR_MAPPINGS'
        , 'PAY_CA_LEGISLATION_INFO'
        , 'PA_ACCUM_COLUMNS'
        , 'PA_EXCEPTION_REASONS'
        , 'PA_INVOICE_GROUP_TABLES'
        , 'PA_PROJECT_STATUS_CONTROLS'
        , 'PA_RESTYPE_MAP_TO_RESFORMAT'
        , 'PA_RP_TYPES_B'
        , 'WIP_MSC_OPEN_JOB_STATUSES'
        /* bug-16294347 */
        , 'XDO_CONFIG_PROPERTIES_B'
        , 'XDO_CONFIG_PROPERTIES_TL'
        , 'XTR_SOURCE_TYPES' )
  and col.owner = tab.owner
  and col.table_name = tab.table_name
  and col.column_name = 'ZD_EDITION_NAME'
  and not exists
        ( select idx.owner, idx.index_name
          from   dba_indexes idx
          where  idx.table_owner = tab.owner
            and  idx.table_name  = tab.table_name
            and  idx.uniqueness  = 'UNIQUE'
            and  idx.index_type  = 'NORMAL' )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = tab.owner
            and aoo.object_name = tab.table_name
            and aoo.object_type = 'TABLE' )
order by 1, 2
/


/*
**    ---- INDEX ----
*/

DOC
  **********************************************************************
  SECTION-33  [full]
  **********************************************************************
  "Index Name must contain an underscore ('_') character."

   - P2: These indexes cannot be revised during online patching.
   - Fix: Renaming index according to EBS naming standards:
       Unique:     TABLE_NAME_U1, TABLE_NAME_U2, ...
       Non-Unique: TABLE_NAME_N1, TABLE_NAME_N2, ...
   - Unused indexes should be dropped.
   Note: This check only works after Online Patching Enablement.
#

select idx.owner, idx.index_name, idx.table_name
from   dba_indexes idx, dba_editioning_views ev
where ev.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and idx.table_owner = ev.owner
  and idx.table_name  = ev.table_name
  and idx.temporary = 'N'
  and idx.secondary = 'N'
  and idx.generated = 'N'
  and not regexp_like(idx.index_name, '^.*_.*', 'c')
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = idx.owner
            and ((aoo.object_name = idx.index_name and aoo.object_type = 'INDEX') or
                 (aoo.object_name = ev.table_name and aoo.object_type = 'TABLE')) )
order by 1, 2, 3
/


DOC
  **********************************************************************
  SECTION-34  [minimal]
  **********************************************************************
  "Index Must be usable."

     - P1: Unusable indexes block DML access to the table
     - Fix: Rebuild the index.
         SQL> alter index owner.index_name rebuild;
     - Indexes on unused tables can be ignored
     - Note: Unusable indexes where ITYP_OWNER='CTXSYS' will not block
             DML and are not P1 issues.
#

select idx.owner, idx.index_name, idx.table_name, idx.ityp_owner
from   dba_indexes idx
where idx.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E', 'U') )
  and idx.status = 'UNUSABLE'
  and idx.index_name not in
        (/*bug-14746048, exclude unusable indexes of OE, OE is partially obsolete in 12.2 */
         'SO_ACTION_CLAUSES_U1',
         'SO_EXCEPTIONS_N1',
         'SO_EXCEPTIONS_U1',
         'SO_HOLD_RELEASES_N1',
         'SO_HOLD_RELEASES_N2',
         'SO_HOLD_RELEASES_U1',
         'SO_HOLD_SOURCES_N1',
         'SO_HOLD_SOURCES_N2',
         'SO_HOLD_SOURCES_U1',
         'SO_NOTES_N1',
         'SO_NOTES_N2',
         'SO_NOTES_U1',
         'SO_OBJECTS_U1',
         'SO_OBJECTS_U2',
         'SO_OBJECTS_U3',
         'SO_ORDER_APPROVALS_N1',
         'SO_ORDER_APPROVALS_U1',
         'SO_ORDER_APPROVALS_U2',
         'SO_ORDER_CANCELLATIONS_N1',
         'SO_ORDER_CANCELLATIONS_N2',
         'SO_ORDER_CANCELLATIONS_N3',
         'SO_ORDER_CANCELLATIONS_N4',
         'SO_ORDER_CANCELLATIONS_N5',
         'SO_ORDER_CANCELLATIONS_N6',
         'SO_PICKING_CANCELLATIONS_N1',
         'SO_STANDARD_VALUE_RULE_SETS_U1',
         'SO_STANDARD_VALUE_RULE_SETS_U2' )
  and not exists
       ( select 1
         from system.fnd_oracle_userid fou
            , fnd_product_installations fpi
            , ad_obsolete_objects aoo
         where fpi.application_id = aoo.application_id
           and fou.oracle_id = fpi.oracle_id
           and fou.oracle_username = idx.owner
           and ((aoo.object_name = idx.index_name and aoo.object_type = 'INDEX') or
                (aoo.object_name = idx.table_name and aoo.object_type = 'TABLE')) )
order by 1, 2, 3
/


DOC
  **********************************************************************
  SECTION-35  [full]
  **********************************************************************
  "Unique index on seed data table must include ZD_EDITION_NAME."

   - P2: Seed data table cannot be loaded during online patching.
   - Fix: Execute the seed data table upgrade procedure on the table.
       SQL> exec ad_zd_seed.upgrade(table_name)
   Note: This check only works after Online Patching Enablement.

#

select idx.owner, idx.index_name, idx.table_name
from   dba_indexes idx, dba_tab_columns col
where idx.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A','B', 'E', 'U') )
  and idx.temporary = 'N'
  and idx.secondary = 'N'
  and idx.generated = 'N'
  and idx.uniqueness  = 'UNIQUE'
  and idx.index_type  <> 'LOB'
  and col.owner       = idx.table_owner
  and col.table_name  = idx.table_name
  and col.column_name = 'ZD_EDITION_NAME'
  and not exists
        ( select idc.column_name
          from   dba_ind_columns idc
          where idc.index_owner = idx.owner
            and idc.index_name  = idx.index_name
            and idc.column_name = col.column_name )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = idx.owner
            and ((aoo.object_name = idx.index_name and aoo.object_type = 'INDEX') or
                 (aoo.object_name = idx.table_name and aoo.object_type = 'TABLE')) )
order by idx.owner, idx.index_name
/


/*
  **********************************************************************
  SECTION-36  [obsolete]
  **********************************************************************
  "Unique Index on Seed Data Table should have at least one not null column"
   - Removed this test as part of Bug 18381326.
*/


DOC
  **********************************************************************
  SECTION-37  [full]
  **********************************************************************
  "Index key size should be less than 3215."

   - P3: Possible runtime locking when patching this index.  Application
         users may see delayed response for transactions against these
         tables while the index is being patched.
   - Fix: Remove unnecessary columns from the index.
   - Unfixed violations can be ignored.
#

select idx.owner, idx.index_name, idx.table_name, sum(idc.column_length+1) index_key_length
from   dba_indexes idx, dba_ind_columns idc
where idx.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A','B', 'E', 'U') )
  and idx.temporary = 'N'
  and idx.secondary = 'N'
  and idx.generated = 'N'
  and idx.index_type <> 'DOMAIN'
  and idc.index_owner = idx.owner
  and idc.index_name  = idx.index_name
  and idc.index_name not in
       (/* bug-14790493, OTA's indexes for Performance */
        'HZ_STAGED_PARTIES_N1',
        /* bug-14789821 */
        'IBC_DIRECTORY_NODES_B_U2',
        /* bug-14797672 */
        'AME_STRING_VALUES_UK1',
        /* bug-14812354 */
        'XNP_MSGS_N6',
        /* bug-14839334 */
        'GMO_DISPENSE_CONFIG_INST_U1',
        /* bug-14848132 */
        'PER_ENTERPRISES_UK2',
        'PER_ENT_SECURITY_GROUPS_UK3',
        /* bug-15857082 */
        'CZ_PROPERTIES_N1',
        'CZ_RP_ENTRIES_N2',
        'CZ_RP_ENTRIES_N3',
        'CZ_RP_ENTRIES_NF1',
        'CZ_RP_ENTRIES_U1',
        /* bug-15855178 */
        'JDR_ATTRIBUTES_N2',
        'BISM_EXPORT_PK',
        /*bug-18088447 */
        'FND_EID_DDR_MGD_ATT_VALS_U1',
        /*bug-18502422 */
        'FND_EID_DDR_MGD_ATT_VALS_ZD_U1',
        /*bug-30882224*/
        'FND_WEB_RESOURCE_FORWARDS_U1',
        /*bug-18680711 */
        'CMI_GPA_RPD_TL_U1'
       )
  and not exists
       ( select 1
         from system.fnd_oracle_userid fou
            , fnd_product_installations fpi
            , ad_obsolete_objects aoo
         where fpi.application_id = aoo.application_id
           and fou.oracle_id = fpi.oracle_id
           and fou.oracle_username = idx.owner
           and ((aoo.object_name = idx.index_name and aoo.object_type = 'INDEX') or
                (aoo.object_name = idx.table_name and aoo.object_type = 'TABLE')) )
group by idx.owner, idx.index_name, idx.table_name
having   sum(idc.column_length+1) > 3215
order by idx.owner, idx.index_name
/


/*
**    ---- CONSTRAINT ----
*/

DOC
  **********************************************************************
  SECTION-38  [full]
  **********************************************************************
  "Constraint name must contain an underscore ('_') character."

   - P2: These constraints cannot be revised during online patching.
   - Fix:  Rename constraints according to EBS naming standards.
       Unique:     TABLE_NAME_U1, TABLE_NAME_U2, ...
       Non-Unique: TABLE_NAME_N1, TABLE_NAME_N2, ...
   - Unused constraints should be dropped.
   Note: This check only works after Online Patching Enablement.
#

select con.owner, con.constraint_name, con.table_name
from   dba_constraints con, dba_editioning_views ev
where ev.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E') )
  and con.owner = ev.owner
  and con.table_name = ev.table_name
  and con.generated = 'USER NAME'
  and not regexp_like(con.constraint_name, '^.*_.*$', 'c')
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = ev.owner
            and ((aoo.object_name = ev.view_name and aoo.object_type = 'VIEW') or
                 (aoo.object_name = ev.table_name and aoo.object_type = 'TABLE')) )
order by 1, 2, 3
/


DOC
  **********************************************************************
  SECTION-39  [minimal]
  **********************************************************************
  "Foreign Key constraint cannot reference seed data table."

   - P2: These constraints become invalid when the seed
         data table is upgraded for editioning.
   - Fix: Drop the constraint and ensure that runtime application
         logic validates data integrity rules as needed.
   Note: This check only works after Online Patching Enablement.
#

select confk.owner owner
     , confk.constraint_name constraint_name
     , confk.table_name
     , confk.DELETE_RULE
     , confk.VALIDATED
     , conpk.table_name
from   dba_constraints confk
     , dba_constraints conpk
     , dba_tables tabpk
     , dba_tab_columns col
where confk.constraint_type = 'R'
  and conpk.owner = confk.r_owner
  and conpk.constraint_name = confk.r_constraint_name
  and conpk.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E', 'U') )
  and tabpk.owner = conpk.owner
  and tabpk.table_name = conpk.table_name
  and col.owner = tabpk.owner
  and col.table_name = tabpk.table_name
  and col.column_name = 'ZD_EDITION_NAME'
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = tabpk.owner
            and aoo.object_name = tabpk.table_name
            and aoo.object_type = 'TABLE' )
order by 1, 2, 3
/



/*
**    ---- MATERIALIZED VIEW ----
*/


DOC
  **********************************************************************
  SECTION-40  [minimal]
  **********************************************************************
  "Materialized View name must be unique within the first 29 bytes."

   - P1: Matching materialized views will not upgrade correctly
         and will be non-functional.
   - Fix: Rename materialized views so that names are unique
         within the first 29 bytes.
#

select mv.owner, substrb(mv.mview_name, 1, 29), count(mv.mview_name)
from dba_mviews mv
where mv.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E', 'U') )
  and length(mv.mview_name) > 29
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = mv.owner
            and aoo.object_name = mv.mview_name
            and aoo.object_type = 'MATERIALIZED VIEW' )
group by mv.owner, substrb(mv.mview_name, 1, 29)
having count(mv.mview_name) > 1
/


DOC
  **********************************************************************
  SECTION-41  [minimal]
  **********************************************************************
  "Materialized View (MV) must have a corresponding Logical View (MV#)."

   - P1: These MVs did not upgrade correctly and are non-functional.
         This can happen if the MV query is not a legal ordinary view query.
   - Fix: Recreate the MV using the AD_MV.CREATE_MV procedure.
   - Unneeded MVs can be ignored but should be dropped.
   Note: This check is only active after Online Patching Enablement.
#

select mv.owner, mv.mview_name
from dba_mviews mv
where mv.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E', 'U') )
  and mv.mview_name not like '%$'
  and not exists
        ( select view_name from dba_views
          where owner = mv.owner
            and view_name = substr(mv.mview_name, 1, 29)||'#' )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = mv.owner
            and aoo.object_name = mv.mview_name
            and aoo.object_type = 'MATERIALIZED VIEW' )
  and exists
        ( select null
          from fnd_oracle_userid au, dba_users du
          where au.oracle_username = du.username
            and au.read_only_flag  = 'U'
            and du.editions_enabled = 'Y' )
order by 1, 2
/


DOC
  **********************************************************************
  SECTION-42  [minimal]
  **********************************************************************
  "Logical View (MV#) must have a corresponding Materialized View (MV)."

   - P1: These MVs did not upgrade correctly and are non-functional.
         This is likely because the MV query references an editioned
         PL/SQL function.
   - Fix: create the MV according to development standards using the
         AD_MV.CREATE_MV procedure.
   - Unneeded MVs can be ignored but should be dropped.
#

select vw.owner, vw.view_name
from dba_views vw
where vw.owner in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag in ('A', 'B', 'E', 'U') )
  and vw.view_name like '%#'
  and vw.editioning_view = 'N'
  and not exists
        ( select mview_name from dba_mviews mv
          where mv.owner = vw.owner
            and substr(mv.mview_name, 1, 29) = substr(vw.view_name, 1, length(vw.view_name)-1) )
  and not exists
        ( select 1
          from system.fnd_oracle_userid fou
             , fnd_product_installations fpi
             , ad_obsolete_objects aoo
          where fpi.application_id = aoo.application_id
            and fou.oracle_id = fpi.oracle_id
            and fou.oracle_username = vw.owner
            and aoo.object_name = vw.view_name
            and aoo.object_type = 'VIEW' )
order by 1, 2
/

DOC
  **********************************************************************
  SECTION-43  [minimal]
  **********************************************************************
  "Object name must not match any E-Business Suite schema name."

   - P1: These object names conflict with schema names and may cause
         errors during upgrade or online patching.
   - Fix: Drop or rename the object.
#

select obj.owner, obj.object_name
from dba_objects obj
where obj.owner in
       (select oracle_username
        from system.fnd_oracle_userid
        where  read_only_flag in ('A', 'B', 'E', 'U')
        )
and exists
       (select null
        from system.fnd_oracle_userid
        where oracle_username = obj.object_name
          and read_only_flag in ('A', 'B', 'E', 'U') )
/


DOC
  **********************************************************************
  SECTION-44  [minimal]
  **********************************************************************
  "Object name must not conflict with data dictionary view names."

   - P1: These objects may return wrong data, causing incorrect operation.
   - Fix: Drop or rename the object.
#

select obj.owner, obj.object_name
from sys.dba_objects obj
where obj.owner in
       (select oracle_username
        from system.fnd_oracle_userid
        where  read_only_flag in ('A', 'B', 'E', 'U'))
and exists
     (select null
      from sys.dba_objects obj2
      where obj2.object_name = obj.object_name
        and obj2.object_name like 'DBA\_%' ESCAPE '\'
        and obj2.object_type = 'VIEW'
        and obj2.owner = 'SYS')
/


DOC
  **********************************************************************
  SECTION-45  [minimal]
  **********************************************************************
  "E-Business Suite DB Technology Codelevel Checker must be run on all
   database nodes."

  - P1: Online Patching will not allow execution until this manual 
        step is completed.  See My Oracle Support Knowledge
        Document 1594274.1 for further information.

#

column node_name format a30;
column patch_checker_message format a80;

variable c_db_patch_checker refcursor;
variable g_applsys_user varchar2(30);

begin
  select oracle_username into :g_applsys_user
  from fnd_oracle_userid
  where read_only_flag = 'E';
end;
/


declare
  l_count     pls_integer ;

  l_db_patch_check_sql varchar2(4000) :=
     'select host as node_name, (select decode(check_result, ''OK'', ''All required database bug fixes have been applied to this node'' ,
     ''MISSING'', ''WARNING - The following required database bugfixes <''||check_message||''> are missing from this node. Refer to My Oracle Support Knowledge Document 1594274.1 to identify the patch that delivers this bug fix.'' ,
     ''ROLLBACK'', ''Bug fixes <''||check_message||''> need to be rolled back on this node. Refer to My Oracle Support Knowledge Document 1594274.1 for instructions.''' ||
     ')  from ' || :g_applsys_user ||'.TXK_TCC_RESULTS where node_name =host) patch_checker_message from fnd_nodes where support_db=''Y''';


begin

   select count(1) into l_count
   from dba_tables
   where table_name='TXK_TCC_RESULTS'
     and owner=:g_applsys_user;

   if(l_count > 0 ) then
     open :c_db_patch_checker for l_db_patch_check_sql;
   else
       open :c_db_patch_checker for
         select host as node_name,  'ERROR - Table TXK_TCC_RESULTS needs to be installed by running the EBS Technology Codelevel Checker (available as patch 17537119).' as patch_checker_message
         from fnd_nodes
         where support_db='Y' ;
   END IF;

exception
  when no_data_found then
    null;
end;
/

print c_db_patch_checker;

DOC
  **********************************************************************
  SECTION-46  [minimal]
  **********************************************************************
  "If Online Patching has been enabled, the EBS_PATCH service must be
   running."

   - P1: If the patch service is not running then connections to patch
         edition might fail.
   - Fix: Create and start the service by running
         SQL> exec ad_zd_prep.create_patch_service;
#
select 'ERROR - EBS Patch service EBS_PATCH is not running' "EBS Patch service check"
from dual
where not exists
       ( select null
         from v$active_services,
         (select ad_zd_prep.get_ebs_patch_service "SERVICE_NAME"
              from v$parameter
              where name='db_domain') patch
         where lower(name) in (lower(patch.service_name),
                           lower(nvl(sys_context('userenv', 'db_unique_name'),
           sys_context ('userenv', 'db_name')) ||'_ebs_patch')))
  and exists
         ( select null
           from fnd_oracle_userid au, dba_users du
           where au.oracle_username = du.username
             and au.read_only_flag = 'U'
             and du.editions_enabled = 'Y' )
/

DOC
  **********************************************************************
  SECTION-47  [minimal]
  **********************************************************************
  "Latest version of the package APPS_DDL must be installed in each
   EBS schema."

   - P2: If the latest package version is not installed then dynamic SQL
         executed in the schema might fail.
   - Fix: Create the APPS_DDL spec and body in the listed schemas by
        running the installation scripts.
         sqlplus <username>/<password> @$AD_TOP/patch/115/sql/adaddls.pls
         sqlplus <username>/<password> @$AD_TOP/patch/115/sql/adaddlb.pls
#
break on owner;
column owner format a20;
column object_name format a15;
column object_type format a15;
column schema_version format a20;
column apps_version format a20;
column status format a10;

select schema_list.owner, schema_list.object_name,
       schema_list.object_type,
       nvl(schema_list.version,'NOT CREATED') schema_version,
       schema_list.apps_version,status
from dba_objects obj,
     (
      select ebs_schema.owner, apps.name object_name,
             apps.type object_type, ebs_schema.version,
             apps.version apps_version
      from  (
            select fou.oracle_username owner,
                    substr(trim(substr(substr(src.text, instr(src.text, '$Header')+9),
                    instr(substr(src.text, instr(src.text, '$Header')+9), ' '))),  1,
                    instr(trim(substr(substr(src.text, instr(src.text, '$Header')+9),
                    instr(substr(src.text, instr(src.text, '$Header')+9), ' '))), ' ')-1) version,
                    src.name name, 
                    src.type type
             from    (select oracle_username
                      from system.fnd_oracle_userid 
                      where read_only_flag ='U') 
                    fou,
                    dba_source src
             where  src.owner = fou.oracle_username
             and    src.name  = 'APPS_DDL'
             and    src.type like 'PACKAGE%' 
             and    src.text like '%$Header%'
            ) apps,
           (
            select fou.oracle_username owner,
                   substr(trim(substr(substr(src.text, instr(src.text, '$Header')+9),
                   instr(substr(src.text, instr(src.text, '$Header')+9), ' '))),  1,
                   instr(trim(substr(substr(src.text, instr(src.text, '$Header')+9),
                   instr(substr(src.text, instr(src.text, '$Header')+9), ' '))), ' ')-1) version,
                   src.name name, src.type type
            from   system.fnd_oracle_userid fou ,
                   dba_source src
            where  src.owner(+)    = fou.oracle_username
            and    src.name(+) ='APPS_DDL'
            and    src.type like 'PACKAGE%' 
            and    src.text(+) like '%$Header%'
            and    fou.read_only_flag in ('E', 'A', 'Z', 'B')
            and    fou.oracle_username not in ('ABM', 'AHM', 'AMF', 'AMW', 'BIL', 'BIV',
                                               'BIX', 'BSC', 'CSS', 'CUE', 'CUF', 'CUI',
                                               'CUN', 'CUP', 'CUS', 'DMS', 'DDD', 'EAA',
                                               'EVM', 'FEM', 'FII', 'FPT', 'FTP', 'GCS', 
                                               'HCC', 'IBA', 'IBP', 'IGF', 'IGS', 'IGW',  
                                               'IMT', 'IPD', 'ISC', 'ITA', 'JTI', 'JTR',  
                                               'JTS', 'ME', 'MST', 'OKB', 'OKI', 'OKO', 
                                               'OKR', 'OZP', 'OZS', 'PFT', 'POA', 'PSB', 
                                               'RCM', 'RHX', 'RLA', 'VEH', 'WH', 'XNC',  
                                               'XNI', 'XNM', 'XNS', 'ZFA', 'ZPB', 'ZSA')
           ) ebs_schema
      where (ebs_schema.name=apps.name or ebs_schema.name is null)
      and   (ebs_schema.type=apps.type or ebs_schema.type is null)
     ) schema_list
where obj.owner(+)       = schema_list.owner
  and obj.object_name(+) = schema_list.object_name
  and obj.object_type(+) = schema_list.object_type
  and (schema_list.version <> schema_list.apps_version or 
       status is null or
       status='INVALID')
order by 1,2,3;
/

DOC
   **********************************************************************
   SECTION-90  [full]
   **********************************************************************
   "Revoke unnecessary grants granted on SYS.DUAL by SYS."
   
    - Please execute ADFIXUSER.sql if one or more records exist.
#

select   count(grantee) "Count"
from     dba_tab_privs
where    table_name ='DUAL' and owner = 'SYS' and grantor = 'SYS'
and      privilege    <> 'SELECT'
/

DOC
   **********************************************************************
   SECTION-91  [full] Bugs 26137712 and 26314055 , jwsmith
   **********************************************************************
   "Revoke unnecessary grants granted on DBMS_SYS_SQL."

    - If a record exists from below sql, please connect to sqlplus via apps and run
    - the following sql script: $AD_TOP/patch/115/sql/adrevokegrants.sql.
    - Example - sqlplus apps/apps @adrevokegrants.sql 
    - Then run the select again and verify 0 rows are returned.
    - 
    - If you are in pre EBR Enablement Stage or pre Oracle E-Business Suite 
    - Release 12.2 level, please run "exec sys.ad_grants.cleanup;"
    - manually from sqlplus as APPS user.
#
select count(1)
from dba_tab_privs
where table_name='DBMS_SYS_SQL'
 and privilege='EXECUTE'
 and grantee in (select oracle_username from fnd_oracle_userid where 
    read_only_flag = 'U')
/

DOC
  **********************************************************************
  SECTION-92 [full] Bug 29797364 - IMP_FULL_DATABASE can be granted to APPS
  **********************************************************************
  "'IMP_FULL_DATABASE' privilege must not be granted to APPS."

   - P1: This violation will prevent Online Patching tools from
         operating correctly, resulting in system corruption.
   - Fix: revoke imp_full_database from apps;
#

select 'ERROR - IMP_FULL_DATABASE role must not be granted to '||grantee "IMP FULL DATABASE Role"
from dba_role_privs
where grantee in
        ( select oracle_username from fnd_oracle_userid
          where  read_only_flag = 'U' )
  and granted_role='IMP_FULL_DATABASE'
/

DOC
  ********************************* End ******************************
#
set timing off
set head off
set feedback off
select 'End Time: ' || to_char(sysdate,'DD-MM-YYYY HH24:MI:SS') from dual;
exec :n_Elapsed_Time := (dbms_utility.get_time - :n_Elapsed_Time)
select 'Total Elapsed Time:  ' ||
  to_char(trunc((:n_Elapsed_Time/360000)),'FM9900') || ':' ||
  to_char(trunc(mod((:n_Elapsed_Time/6000),60)),'FM00') || ':' ||
  to_char(trunc(mod((:n_Elapsed_Time/100),60)),'FM00') || ':' ||
  to_char( mod(:n_Elapsed_Time,100),'FM00')
from dual;

spool off;
exit;
/

