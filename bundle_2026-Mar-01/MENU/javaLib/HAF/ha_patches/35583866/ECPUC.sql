REM $Header: ECPUC.sql 120.0.12020000.13 2025/10/21 10:04:57 spullach noship $
REM dbdrv: none
REM +=============================================================================+
REM | 		Copyright (c) 2023 Oracle and/or its affiliates
REM |				 All rights reserved.                                                  
REM | 			Oracle E-Business Suite Release 12.2
REM +=============================================================================+
REM | FILENAME
REM |   ECPUC.sql
REM |
REM | DESCRIPTION
REM |   EBS CPU Checker (ECPUC)
REM |
REM |   sqlplus apps@DB @ECPUC.sql
REM |


DEFINE ebs_cpu_checker_level = '2025.10'

set echo   off
set verify off
set linesize  220
set pagesize  1000
set tab       off
set trimspool on
set numwidth 10

column ebs_cpu_checker_level format a25     heading 'EBS CPU Checker Version'
column instance_name         format a16     heading 'Instance Name'
column database_name         format a16     heading 'Database'
column version_full          format a18     heading 'Database Version'
column version               format a18     heading 'Database Version'
column release_name          format a11     heading 'EBS Release'
column cpu_level             format a13     heading 'EBS CPU Level'
column abbreviation          format a12     heading 'ATG Product Code'
column prod_name             format a40     heading 'Product Name'
column codelevel             format a10     heading 'Code Level'
column patch_to_apply        format a62     heading 'The following patches are required for this EBS CPU'
COLUMN current_date 	     NEW_VALUE 	    current_date_var

SET TERMOUT OFF
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD_HH24-MI') AS current_date FROM DUAL;
SET TERMOUT ON

SPOOL ECPUC_&current_date_var..lst

set feedback off
set head off
select 'Start Time: ' || to_char(sysdate,'DD-MM-YYYY HH24:MI:SS') from dual;
set head on
SET NEWPAGE NONE
prompt  ****************************************************************************
prompt  E-Business Suite Critical Patch Update Checker (ECPUC)
prompt
prompt  ECPUC.sql may be run on any EBS 12.2 environment to identify missing
prompt  patches that are in the latest EBS CPU.
prompt
prompt  You can download the latest version of ECPUC via Patch 35583866.
prompt
prompt  Refer to the README.txt in Patch 35583866 for instructions for running
prompt  ECPUC and information regarding the generated ECPUC.lst report.
prompt  
prompt  The checker generates the report ECPUC_YYYY-MM-DD_HH24-MI.lst that lists
prompt  recommended EBS CPU patches and security fixes for your environment
prompt  per Table 1 'CPU Patches for Oracle E-Business Suite' and 
prompt  Table 2 'Additional Patches Required' documented in the 
prompt  quarterly EBS CPU MOS Note.
prompt
prompt  Each quarterly EBS CPU MOS Note ID is unique. Refer to 
prompt  My Oracle Support (MOS) Knowledge Document 2484000.1,
prompt  'Identifying the Latest Critical Patch Update for Oracle E-Business Suite
prompt  Release 12' which includes a link to the current EBS CPU MOS document.                                                                                                  
prompt  ****************************************************************************

prompt ============================================================================
prompt SECTION-1 ECPUC Version
prompt ============================================================================
prompt 
SELECT '&ebs_cpu_checker_level' AS ebs_cpu_checker_level
FROM   dual;
/*
**    ---- Header ----
*/
prompt 
prompt ============================================================================
prompt SECTION-2 Oracle E-Business Suite (EBS): Instance Information
prompt ============================================================================ 
prompt 

prompt ****************************************************************************
prompt  Instance Summary 
prompt ****************************************************************************
prompt 
REM select instance_name, host_name, sys_context('userenv','db_name') database_name, version_full
REM   from v$instance ;

select release_name, 
       nvl((select codelevel from ad_trackable_entities where abbreviation = 'ebscpu'),'pre 2020.01') cpu_level 
  from   FND_PRODUCT_GROUPS
/
prompt
variable c_db_ver_sql refcursor;
declare
   l_19c_ver_sql            varchar2(2000) :=' select instance_name,
      sys_context(''userenv'', ''db_name'') as database_name,
      version_full
      from   v$instance';
   l_less_than_19c_ver_sql  varchar2(2000) :=' select instance_name,
      sys_context(''userenv'', ''db_name'') as database_name,
      version
      from   v$instance';
   l_ver_stmt               varchar2(2000);
 begin
   $if DBMS_DB_VERSION.VER_LE_11_2 $THEN
     l_ver_stmt :=l_less_than_19c_ver_sql;
   $elsif DBMS_DB_VERSION.VER_LE_12 $THEN
     l_ver_stmt :=l_less_than_19c_ver_sql;
   $elsif DBMS_DB_VERSION.VER_LE_12_2 $THEN
     l_ver_stmt :=l_less_than_19c_ver_sql;
   $else
     l_ver_stmt :=l_19c_ver_sql;
   $end
 open :c_db_ver_sql for l_ver_stmt;
end;
/
REM Now execute the cursor with the db specific statement
print c_db_ver_sql;
prompt
select abbreviation, name prod_name, codelevel
  from ad_trackable_entities
 where abbreviation in ('txk','ad', 'atg_pf','fwk')
order by decode( abbreviation, 'atg_pf',3, 'fwk',4, 'ad',1, 'txk',2)
/


prompt

REM exit this script if the database says that it has a CPU later than this one

WHENEVER SQLERROR EXIT


declare
    is_old_patch BOOLEAN := false;
    patch_name varchar2(100);
begin
  begin
   select codelevel
   into   patch_name
   from   ad_trackable_entities
   where  abbreviation = ('ebscpu')
   and    CODELEVEL > &ebs_cpu_checker_level;
 exception
      when no_data_found then --CPU is Older than CUrrent CPU
          is_old_patch:= true;
      when others then
	raise;
      end;
 if not is_old_patch then
    RAISE_APPLICATION_ERROR(-20001, 'Environment EBS CPU level '||patch_name||' is later than the EBS CPU checker version '||&ebs_cpu_checker_level||'. Please download Patch '||35583866||' again to get the latest version of the ECPUC.');
  end if;
end;
/

WHENEVER SQLERROR CONTINUE
#
prompt ==============================================================================
prompt SECTION-3 Required EBS CPU and Security Fixes
prompt ============================================================================== 
prompt 
prompt ******************************************************************************
prompt The following output is a list of required patches and security fixes
prompt that are missing in your environment.
prompt 
prompt It is strongly recommended that you apply all of the listed patches as soon as possible.
prompt  
prompt If no patches (no rows) are listed then no additional action is required
prompt at this time as your environment includes all patches for this EBS CPU.
prompt ******************************************************************************
prompt 
set feedback 1
SELECT PATCH_TO_APPLY FROM( 
 SELECT '38298685:12.2.0' PATCH_TO_APPLY from dual where ad_patch.is_patch_applied('12.2.0',-1,'38298685') = 'NOT_APPLIED'
 UNION ALL  SELECT '38261439:R12.FWK.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'38261439') = 'NOT_APPLIED'
 UNION ALL  SELECT '38261427:R12.FWK.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'38261427') = 'NOT_APPLIED'
 UNION ALL  SELECT '38261420:R12.FWK.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'38261420') = 'NOT_APPLIED'
 UNION ALL  SELECT '38261413:R12.FWK.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'38261413') = 'NOT_APPLIED'
 UNION ALL  SELECT '38261405:R12.FWK.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'38261405') = 'NOT_APPLIED'
 UNION ALL  SELECT '38261399:R12.FWK.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'38261399') = 'NOT_APPLIED'
 UNION ALL  SELECT '38261387:R12.FWK.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'38261387') = 'NOT_APPLIED'
 UNION ALL  SELECT '38261387:R12.FWK.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'38261387') = 'NOT_APPLIED' AND ad_patch.is_patch_applied('12.2.0',-1,'26924701') <> 'NOT_APPLIED'
 UNION ALL  SELECT '38261530:R12.FWK.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'38261530') = 'NOT_APPLIED'
 UNION ALL  SELECT '38261383:R12.FWK.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'38261383') = 'NOT_APPLIED'
 UNION ALL  SELECT '38261373:R12.FWK.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.4' and ad_patch.is_patch_applied('12.2.0',-1,'38261373') = 'NOT_APPLIED'
UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.14' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED' 
UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED'
 UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED'
 UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED'
 UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED'
 UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED'
 UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED'
 UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED'
 UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED'
 UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED'
 UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.4' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED'
 UNION ALL  SELECT '37450688:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.3' and ad_patch.is_patch_applied('12.2.0',-1,'37450688') = 'NOT_APPLIED'
 UNION ALL  SELECT '38180394:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'38180394') = 'NOT_APPLIED'
 UNION ALL  SELECT '38180394:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'38180394') = 'NOT_APPLIED'
 UNION ALL  SELECT '38180394:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'38180394') = 'NOT_APPLIED'
 UNION ALL  SELECT '38180394:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'38180394') = 'NOT_APPLIED'
 UNION ALL  SELECT '38180394:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'38180394') = 'NOT_APPLIED'
 UNION ALL  SELECT '38180394:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'38180394') = 'NOT_APPLIED'
 UNION ALL  SELECT '38180394:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'38180394') = 'NOT_APPLIED'
 UNION ALL  SELECT '38180394:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'38180394') = 'NOT_APPLIED'
 UNION ALL  SELECT '38180394:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'38180394') = 'NOT_APPLIED'
 UNION ALL  SELECT '38500628:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.14' and ad_patch.is_patch_applied('12.2.0',-1,'38500628') = 'NOT_APPLIED'
 UNION ALL  SELECT '38500628:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'38500628') = 'NOT_APPLIED'
 UNION ALL  SELECT '38510732:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'38510732') = 'NOT_APPLIED'
 UNION ALL  SELECT '38510732:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'38510732') = 'NOT_APPLIED'
 UNION ALL  SELECT '38510732:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'38510732') = 'NOT_APPLIED'
 UNION ALL  SELECT '38510732:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'38510732') = 'NOT_APPLIED'
 UNION ALL  SELECT '38510732:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'38510732') = 'NOT_APPLIED'
 UNION ALL  SELECT '38510732:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'38510732') = 'NOT_APPLIED'
 UNION ALL  SELECT '38510732:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'38510732') = 'NOT_APPLIED'
 UNION ALL  SELECT '38510732:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'38510732') = 'NOT_APPLIED'
 UNION ALL  SELECT '38510732:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.4' and ad_patch.is_patch_applied('12.2.0',-1,'38510732') = 'NOT_APPLIED'
 UNION ALL  SELECT '38510732:R12.XDO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.3' and ad_patch.is_patch_applied('12.2.0',-1,'38510732') = 'NOT_APPLIED'
 UNION ALL  SELECT '36589745:R12.IBE.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.14' and ad_patch.is_patch_applied('12.2.0',-1,'36589745') = 'NOT_APPLIED'
 UNION ALL  SELECT '36589745:R12.IBE.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'36589745') = 'NOT_APPLIED'
 UNION ALL  SELECT '36589745:R12.IBE.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'36589745') = 'NOT_APPLIED'
 UNION ALL  SELECT '36589745:R12.IBE.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'36589745') = 'NOT_APPLIED'
 UNION ALL  SELECT '36589745:R12.IBE.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'36589745') = 'NOT_APPLIED'
 UNION ALL  SELECT '36589745:R12.IBE.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'36589745') = 'NOT_APPLIED'
 UNION ALL  SELECT '36589745:R12.IBE.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'36589745') = 'NOT_APPLIED'
 UNION ALL  SELECT '36589745:R12.IBE.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'36589745') = 'NOT_APPLIED'
 UNION ALL  SELECT '36589745:R12.IBE.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'36589745') = 'NOT_APPLIED'
 UNION ALL  SELECT '36589745:R12.IBE.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'36589745') = 'NOT_APPLIED'
 UNION ALL  SELECT '38050166:R12.IEU.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.14' and ad_patch.is_patch_applied('12.2.0',-1,'38050166') = 'NOT_APPLIED'
 UNION ALL  SELECT '38050166:R12.IEU.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'38050166') = 'NOT_APPLIED'
 UNION ALL  SELECT '38050166:R12.IEU.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'38050166') = 'NOT_APPLIED'
 UNION ALL  SELECT '38050166:R12.IEU.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'38050166') = 'NOT_APPLIED'
 UNION ALL  SELECT '38050166:R12.IEU.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'38050166') = 'NOT_APPLIED'
 UNION ALL  SELECT '38050166:R12.IEU.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'38050166') = 'NOT_APPLIED'
 UNION ALL  SELECT '38056382:R12.IEU.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'38056382') = 'NOT_APPLIED'
 UNION ALL  SELECT '38056373:R12.IEU.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'38056373') = 'NOT_APPLIED'
 UNION ALL  SELECT '38056373:R12.IEU.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'38056373') = 'NOT_APPLIED'
 UNION ALL  SELECT '38056364:R12.IEU.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'38056364') = 'NOT_APPLIED'
 UNION ALL  SELECT '36097561:R12.OKL.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'FIN_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'36097561') = 'NOT_APPLIED'
 UNION ALL  SELECT '36569441:R12.GMO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'36569441') = 'NOT_APPLIED'
 UNION ALL  SELECT '36569441:R12.GMO.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'36569441') = 'NOT_APPLIED'
 UNION ALL  SELECT '36111966:R12.CSM.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'36111966') = 'NOT_APPLIED'
 UNION ALL  SELECT '36111966:R12.CSM.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'36111966') = 'NOT_APPLIED'
 UNION ALL  SELECT '36111966:R12.CSM.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'36111966') = 'NOT_APPLIED'
 UNION ALL  SELECT '36075627:R12.JTT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'36075627') = 'NOT_APPLIED'
 UNION ALL  SELECT '36075627:R12.JTT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'36075627') = 'NOT_APPLIED'
 UNION ALL  SELECT '36075627:R12.JTT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'36075627') = 'NOT_APPLIED'
 UNION ALL  SELECT '37327694:R12.UMX.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'37327694') = 'NOT_APPLIED'
 UNION ALL  SELECT '37327694:R12.UMX.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'37327694') = 'NOT_APPLIED'
 UNION ALL  SELECT '37327694:R12.UMX.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'37327694') = 'NOT_APPLIED'
 UNION ALL  SELECT '37327694:R12.UMX.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'37327694') = 'NOT_APPLIED'
 UNION ALL  SELECT '37327694:R12.UMX.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'37327694') = 'NOT_APPLIED'
 UNION ALL  SELECT '37327694:R12.UMX.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'37327694') = 'NOT_APPLIED'
 UNION ALL  SELECT '37327694:R12.UMX.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'37327694') = 'NOT_APPLIED'
 UNION ALL  SELECT '37327694:R12.UMX.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'37327694') = 'NOT_APPLIED'
 UNION ALL  SELECT '37327694:R12.UMX.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'37327694') = 'NOT_APPLIED'
 UNION ALL  SELECT '37327694:R12.UMX.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.4' and ad_patch.is_patch_applied('12.2.0',-1,'37327694') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078895:R12.ATG_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'37078895') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078893:R12.ATG_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'37078893') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078884:R12.ATG_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'37078884') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078877:R12.ATG_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'37078877') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078855:R12.ATG_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'37078855') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078843:R12.ATG_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'37078843') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078836:R12.ATG_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'37078836') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078836:R12.ATG_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'37078836') = 'NOT_APPLIED' AND ad_patch.is_patch_applied('12.2.0',-1,'26924701') <> 'NOT_APPLIED'
 UNION ALL  SELECT '37078823:R12.ATG_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'37078823') = 'NOT_APPLIED'
 UNION ALL  SELECT '37033978:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'37033978') = 'NOT_APPLIED' AND ad_patch.is_patch_applied('12.2.0',-1,'25380324') <> 'NOT_APPLIED'
 UNION ALL  SELECT '37078813:R12.ATG_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'37078813') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078798:R12.ATG_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.4' and ad_patch.is_patch_applied('12.2.0',-1,'37078798') = 'NOT_APPLIED'
 UNION ALL  SELECT '36957442:R12.OWF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.3' and ad_patch.is_patch_applied('12.2.0',-1,'36957442') = 'NOT_APPLIED'
 UNION ALL  SELECT '37068559:R12.GMD.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.14' and ad_patch.is_patch_applied('12.2.0',-1,'37068559') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078943:R12.SCM_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'37078943') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078919:R12.SCM_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'37078919') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078917:R12.SCM_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'37078917') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078915:R12.SCM_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'37078915') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078914:R12.SCM_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'37078914') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078912:R12.SCM_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'37078912') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078911:R12.SCM_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'37078911') = 'NOT_APPLIED'
 UNION ALL  SELECT '37078910:R12.SCM_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'37078910') = 'NOT_APPLIED'
 UNION ALL  SELECT '36949119:R12.OKS.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCM_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'36949119') = 'NOT_APPLIED'
 UNION ALL  SELECT '37120495:R12.CC_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'37120495') = 'NOT_APPLIED'
 UNION ALL  SELECT '37120482:R12.CC_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'37120482') = 'NOT_APPLIED'
 UNION ALL  SELECT '37120482:R12.CC_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'37120482') = 'NOT_APPLIED'
 UNION ALL  SELECT '37120463:R12.CC_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'37120463') = 'NOT_APPLIED'
 UNION ALL  SELECT '37120448:R12.CC_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'37120448') = 'NOT_APPLIED'
 UNION ALL  SELECT '37120448:R12.CC_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'37120448') = 'NOT_APPLIED'
 UNION ALL  SELECT '37120430:R12.CC_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'37120430') = 'NOT_APPLIED'
 UNION ALL  SELECT '37120399:R12.CC_PF.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'37120399') = 'NOT_APPLIED'
 UNION ALL  SELECT '32636352:R12.HZ.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.4' and ad_patch.is_patch_applied('12.2.0',-1,'32636352') = 'NOT_APPLIED'
 UNION ALL  SELECT '32636352:R12.HZ.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'CC_PF' and  codelevel = 'C.3' and ad_patch.is_patch_applied('12.2.0',-1,'32636352') = 'NOT_APPLIED' AND ad_patch.is_patch_applied('12.2.0',-1,'27120099') <> 'NOT_APPLIED'
 UNION ALL  SELECT '35362524:R12.IGI.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'FIN_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'35362524') = 'NOT_APPLIED'
 UNION ALL  SELECT '35362524:R12.IGI.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'FIN_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'35362524') = 'NOT_APPLIED'
 UNION ALL  SELECT '35362524:R12.IGI.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'FIN_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'35362524') = 'NOT_APPLIED'
 UNION ALL  SELECT '35362524:R12.IGI.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'FIN_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'35362524') = 'NOT_APPLIED'
 UNION ALL  SELECT '35362524:R12.IGI.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'FIN_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'35362524') = 'NOT_APPLIED'
 UNION ALL  SELECT '35362524:R12.IGI.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'FIN_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'35362524') = 'NOT_APPLIED'
 UNION ALL  SELECT '34979060:R12.MSC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCP_PF' and  codelevel = 'C.14' and ad_patch.is_patch_applied('12.2.0',-1,'34979060') = 'NOT_APPLIED'
 UNION ALL  SELECT '34979060:R12.MSC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCP_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'34979060') = 'NOT_APPLIED'
 UNION ALL  SELECT '34979060:R12.MSC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCP_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'34979060') = 'NOT_APPLIED'
 UNION ALL  SELECT '34979060:R12.MSC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCP_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'34979060') = 'NOT_APPLIED'
 UNION ALL  SELECT '34979060:R12.MSC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCP_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'34979060') = 'NOT_APPLIED'
 UNION ALL  SELECT '34979060:R12.MSC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCP_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'34979060') = 'NOT_APPLIED'
 UNION ALL  SELECT '34979060:R12.MSC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCP_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'34979060') = 'NOT_APPLIED'
 UNION ALL  SELECT '34979060:R12.MSC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCP_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'34979060') = 'NOT_APPLIED'
 UNION ALL  SELECT '34979060:R12.MSC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCP_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'34979060') = 'NOT_APPLIED'
 UNION ALL  SELECT '34979060:R12.MSC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCP_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'34979060') = 'NOT_APPLIED'
 UNION ALL  SELECT '34979060:R12.MSC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'SCP_PF' and  codelevel = 'C.4' and ad_patch.is_patch_applied('12.2.0',-1,'34979060') = 'NOT_APPLIED'
 UNION ALL  SELECT '33457157:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.15' and ad_patch.is_patch_applied('12.2.0',-1,'33457157') = 'NOT_APPLIED'
 UNION ALL  SELECT '33457157:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.14' and ad_patch.is_patch_applied('12.2.0',-1,'33457157') = 'NOT_APPLIED'
 UNION ALL  SELECT '33457157:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'33457157') = 'NOT_APPLIED'
 UNION ALL  SELECT '33457157:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'33457157') = 'NOT_APPLIED'
 UNION ALL  SELECT '33457157:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'33457157') = 'NOT_APPLIED'
 UNION ALL  SELECT '33457157:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'33457157') = 'NOT_APPLIED'
 UNION ALL  SELECT '33457157:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'33457157') = 'NOT_APPLIED'
 UNION ALL  SELECT '30448458:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.15' and ad_patch.is_patch_applied('12.2.0',-1,'30448458') = 'NOT_APPLIED'
 UNION ALL  SELECT '30448458:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.14' and ad_patch.is_patch_applied('12.2.0',-1,'30448458') = 'NOT_APPLIED'
 UNION ALL  SELECT '30448458:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'30448458') = 'NOT_APPLIED'
 UNION ALL  SELECT '30448458:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'30448458') = 'NOT_APPLIED'
 UNION ALL  SELECT '30448458:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'30448458') = 'NOT_APPLIED'
 UNION ALL  SELECT '30448458:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'30448458') = 'NOT_APPLIED'
 UNION ALL  SELECT '30448458:R12.HXT.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'30448458') = 'NOT_APPLIED'
 UNION ALL  SELECT '25229413:R12.PAY.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'25229413') = 'NOT_APPLIED'
 UNION ALL  SELECT '25229413:R12.PAY.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'HR_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'25229413') = 'NOT_APPLIED'
 UNION ALL  SELECT '36560216:R12.PO.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'36560216') = 'NOT_APPLIED'
 UNION ALL  SELECT '36560216:R12.PO.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'36560216') = 'NOT_APPLIED'
 UNION ALL  SELECT '36560216:R12.PO.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.11' and ad_patch.is_patch_applied('12.2.0',-1,'36560216') = 'NOT_APPLIED'
 UNION ALL  SELECT '36560216:R12.PO.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.10' and ad_patch.is_patch_applied('12.2.0',-1,'36560216') = 'NOT_APPLIED'
 UNION ALL  SELECT '36560216:R12.PO.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.9' and ad_patch.is_patch_applied('12.2.0',-1,'36560216') = 'NOT_APPLIED'
 UNION ALL  SELECT '34870379:R12.POS.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'34870379') = 'NOT_APPLIED'
 UNION ALL  SELECT '36560216:R12.PO.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'36560216') = 'NOT_APPLIED'
 UNION ALL  SELECT '34870379:R12.POS.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'34870379') = 'NOT_APPLIED'
 UNION ALL  SELECT '36560216:R12.PO.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'36560216') = 'NOT_APPLIED'
 UNION ALL  SELECT '34870379:R12.POS.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'34870379') = 'NOT_APPLIED'
 UNION ALL  SELECT '36560216:R12.PO.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'36560216') = 'NOT_APPLIED'
 UNION ALL  SELECT '32750949:R12.POS.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'32750949') = 'NOT_APPLIED'
 UNION ALL  SELECT '36453170:R12.PO.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'36453170') = 'NOT_APPLIED'
 UNION ALL  SELECT '32750949:R12.POS.D' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PRC_PF' and  codelevel = 'C.4' and ad_patch.is_patch_applied('12.2.0',-1,'32750949') = 'NOT_APPLIED'
 UNION ALL  SELECT '33623398:R12.PJC.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PJ_PF' and  codelevel = 'C.8' and ad_patch.is_patch_applied('12.2.0',-1,'33623398') = 'NOT_APPLIED'
 UNION ALL  SELECT '37288039:R12.PA.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PJ_PF' and  codelevel = 'C.12' and ad_patch.is_patch_applied('12.2.0',-1,'37288039') = 'NOT_APPLIED'
 UNION ALL  SELECT '37287000:R12.PA.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'PJ_PF' and  codelevel = 'C.13' and ad_patch.is_patch_applied('12.2.0',-1,'37287000') = 'NOT_APPLIED'
 UNION ALL  SELECT '28481343:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.7' and ad_patch.is_patch_applied('12.2.0',-1,'28481343') = 'NOT_APPLIED' AND ad_patch.is_patch_applied('12.2.0',-1,'27429118') <> 'NOT_APPLIED'
 UNION ALL  SELECT '28481343:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.6' and ad_patch.is_patch_applied('12.2.0',-1,'28481343') = 'NOT_APPLIED' AND ad_patch.is_patch_applied('12.2.0',-1,'27429118') <> 'NOT_APPLIED'
 UNION ALL  SELECT '28481343:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.5' and ad_patch.is_patch_applied('12.2.0',-1,'28481343') = 'NOT_APPLIED' AND ad_patch.is_patch_applied('12.2.0',-1,'27429118') <> 'NOT_APPLIED'
 UNION ALL  SELECT '28481343:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.4' and ad_patch.is_patch_applied('12.2.0',-1,'28481343') = 'NOT_APPLIED' AND ad_patch.is_patch_applied('12.2.0',-1,'27429118') <> 'NOT_APPLIED'
 UNION ALL  SELECT '28481343:R12.FND.C' PATCH_TO_APPLY from ad_trackable_entities where upper(abbreviation) = 'ATG_PF' and  codelevel = 'C.3' and ad_patch.is_patch_applied('12.2.0',-1,'28481343') = 'NOT_APPLIED' AND ad_patch.is_patch_applied('12.2.0',-1,'27429118') <> 'NOT_APPLIED'
 UNION ALL  SELECT '30058115:R12.OIE.C' PATCH_TO_APPLY from dual where ad_patch.is_patch_applied('12.2.0',-1,'27429118') <> 'NOT_APPLIED' and ad_patch.is_patch_applied('12.2.0',-1,'30058115') = 'NOT_APPLIED'
);

spool
spool off 
exit 
