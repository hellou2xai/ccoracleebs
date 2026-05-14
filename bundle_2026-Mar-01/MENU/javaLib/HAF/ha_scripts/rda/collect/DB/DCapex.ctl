# DCapex.ctl:292:Collects APEX Information
# $Id: DCapex.ctl,v 1.5 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/DB/DCapex.ctl,v 1.4 2013/11/05 13:51:08 RDA Exp $
#
# Change History
# 20190218  SJC  Collect only query information; update queries to run.
# 20131105  MSC  Improve code consistency.

=head1 NAME

DB:DCapex - Collects APEX Information

=head1 DESCRIPTION

This module collects APEX-related information.

=cut

echo tput('bold'),'Processing DB.APEX module ...',tput('off')

toc '1:APEX Information'
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

# Load the common macros
run DB:DBinfo()
run RDA:library()

# Define a macro to get database information
macro get_db_info
{var ($ver) = @arg
 import $TOP,$TOC,$TTL,@TTL,@HDR
 keep $TOP,$TOC,$TTL,@TTL,@HDR

 debug ' Inside APEX module, getting database information'
 set $sql
 {SELECT 'usr=' || schema
 " FROM dba_registry
 " WHERE comp_id = 'APEX';
 }
 var $usr = nvl(value(grepSql($sql,'^usr=','f')),'APEX_IS_NOT_INSTALLED')

 set $sql
 {SELECT 'tbs=' || u.default_tablespace ||
 "       ' ext=' || DECODE(SUM(DECODE(d.autoextensible,null,null,'YES',1,0)),
 "                             null,'N/A',0,'NO','YES')
 " FROM dba_users u, dba_data_files d
 " WHERE u.username = ':1'
 "   AND u.default_tablespace = d.tablespace_name(+)
 " GROUP BY u.default_tablespace;
 }
 var $tbs = value(grepSql(bindSql($sql,$usr),'^tbs=','f'))
 var ($adt,$ade) = match($tbs,'^(.+)\sext=(.+)$')
 $adt = nvl($adt,'NO_TABLESPACE')
 $ade = nvl($ade,'N/A')

 set $sql
 {SELECT 'tbs=' || u.default_tablespace ||
 "       ' ext=' || DECODE(SUM(DECODE(d.autoextensible,null,null,'YES',1,0)),
 "                             null,'N/A',0,'NO','YES')
 " FROM dba_users u, dba_data_files d
 " WHERE u.username = 'FLOWS_FILES'
 "   AND u.default_tablespace = d.tablespace_name(+)
 " GROUP BY u.default_tablespace;
 }
 var $tbs = value(grepSql($sql,'^tbs=','f'))
 var ($fdt,$fde) = match($tbs,'^(.+)\sext=(.+)$')
 $fdt = nvl($fdt,'NO_TABLESPACE')
 $fde = nvl($fde,'N/A')

 report db_info
 var $TTL = '---+!! Database Information'
 var @TTL = ('',\
             '---+ APEX Database Information',\
             '---+ APEX Version Registered in DBA Registry',\
             concat('---+ Number of Valid and Invalid Objects in the ',$usr,\
                    ' and FLOWS_FILES Schemas'),\
             concat('---+ List of ',$usr,' and FLOWS_FILES Invalid Objects'),\
             '---+ Virtual Image Directory',\
             '---+ APEX Related Schemas',\
             '---+ ORDS Related Schemas',\
             '---+ Proxy Users',\
             '---+ ORDS Version',\
             '---+ Prior APEX Versions Which May Be Cleaned Up',\
             '---+ APEX Account Related Information',\
             '---+ APEX Instance Administrator Account Information',\
             '---+ PL/SQL Toolkit Version',\
             '---+ Duplicate OWA Packages?',\
             '---+ Shared Pool Size',\
             '---+ NLS Character Set Information',\
             '---+ Free Space in SYSTEM Tablespace',\
             concat('---+ Free Space in ',$adt,' Tablespace (AUTOEXTEND=',\
                    $ade,') Used By ',$usr),\
             concat('---+ Free Space in ',$fdt,' Tablespace (AUTOEXTEND=',\
                    $fde,') Used By FLOWS_FILES'),\
             concat('---+ Default Temporary Tablespace for ',$usr,\
                    ' and FLOWS_FILES'),\
             '---+ Number of Job Queue Processes',\
             '---+ XDB HTTP Port',\
             '---+ XDB Status',\
             '---+ APEX Installation Type',\
             '---+ Workspaces',\
             '---+ Applications',\
             '---+ Database Service Name',\
             '---+ Database SID',\
             '---+ DBA Registry Info',\
             '---+ APEX Instance Settings',\
             concat('---+ ',$usr,' Object Grant Information'),\
             concat('---+ Object Privileges Granted to the ',$usr,' Schema'),\
             concat('---+ System Privileges Granted to the ',$usr,' Schema'),\
             concat('---+ Roles Granted to the ',$usr,' Schema'),\
             '---+ Schema Granted APEX_ADMINISTRATOR_ROLE',\
             '---+ Number of Invalid Objects in the DB',\
             '---+ List of ALL Invalid Objects in the DB',\
             '---+ Number of Invalid Synonyms in the DB',\
             '---+ List of ALL Invalid Synonyms in the DB')

 var @HDR = ('',\
             '|*DB Information*|',\
             '|*Version*|*API Compatibility*|',\
             '|*Schema*| *Total Valid*| *Total Invalid*|',\
             '|*Schema*|*Object Name*|*Object Type*|',\
             '|*Virtual Image Directory*|',\
             '|*APEX Related Schemas*|',\
             '|*ORDS Related Schemas*|',\
             '|*Proxy*|*Client*|',\
             '|*ORDS Version*|',\
             '|*Consider Removing All Listed*|',\
             '|*Username*|*Account Status*|*Default Tablespace*|\
               *Temporary Tablespace*|',\
             '|*Username*|*Default Schema*|*Account Locked?*|',\
             '|*Version*|',\
             '|*Owner*|*Object Name*|*Object Type*|',\
             '| *Shared Pool Size (MB)*|',\
             '|*Parameter*|*Parameter Value*|',\
             '| *Free Space (MB)*|',\
             '| *Free Space (MB)*|',\
             '| *Free Space (MB)*|',\
             '|*Username*|*Tablespace*|',\
             '| *Number of Job Queue Processes*|',\
             '| *Port Number*|',\
             '|*Owner*|*Object Name*|*Object Type*|*Status*|',\
             '|*Installation Type*|',\
             '| *Workspace ID*|*Workspace Name*|',\
             '| *Workspace ID*|*Workspace Name*| *Application ID*|\
               *Application Name*|',\
             '|*DB Service Name*|',\
             '|*DB SID*|',\
             '|*Component ID*|*Component Name*|*Version*|*Schema*|*Status*|',\
             '|*Name*|*Value*|*Description*|',\
             concat('| *Total Objects Granted to ',$usr,'*|'),\
             '|*Owner*|*Object Name*|*Privilege*|',\
             '|*Privilege*|',\
             '|*Granted Role*|',\
             '|*Grantee*|',\
             '| *Total Invalid Objects in DB*|',\
             '|*Owner*|*Object Name*|*Object Type*|',\
             '| *Total Invalid Synonyms in DB*|',\
             '|*Synonym Owner*|*Synonym Name*|*Object Owner*|*Object Name*|')

 if compare('valid',$ver,'110')
 {$TTL[40] = '---+ Enabling of Network Services'
  $HDR[40] = '|*Host*| *Lower Port*| *Upper Port*|*Principal*|*Privilege*|'
 }

 set $sql
 {SET serveroutput on;
 "SELECT '|' ||
 "       banner || ' |'
 " FROM v$version;
 "PROMPT ___Macro_separator(2)___
 "SELECT '|' ||
 "       version_no || ' |' ||
 "       api_compatibility || ' |'
 " FROM :1.APEX_RELEASE;
 "PROMPT ___Macro_separator(3)___
 "SELECT '|' ||
 "       owner || ' | ' ||
 "       SUM(DECODE(status,'VALID',1,0)) || '| ' ||
 "       SUM(DECODE(status,'INVALID',1,0)) || '|'
 " FROM dba_objects
 " WHERE owner IN (':1','FLOWS_FILES')
 " GROUP BY owner
 " ORDER BY owner;
 "PROMPT ___Macro_separator(4)___
 "SELECT '|' ||
 "       owner || ' |' ||
 "       object_name || ' |' ||
 "       object_type || ' |'
 " FROM dba_objects
 " WHERE owner IN (':1','FLOWS_FILES')
 "   AND status = 'INVALID'
 " ORDER BY owner, object_type, object_name;
 "PROMPT ___Macro_separator(5)___
 "BEGIN
 " dbms_output.put_line('|' || :1.wwv_flow_image_prefix.g_image_prefix || ' |');
 "END;
 "/
 "PROMPT ___Macro_separator(6)___
 "SELECT '|' ||
 "       username || ' |'
 " FROM dba_users
 " WHERE (username LIKE 'APEX%' OR username = 'FLOWS_FILES')
 "   AND username NOT IN (SELECT username
 "                         FROM dba_users
 "                         WHERE (username LIKE 'APEX\_0%' ESCAPE '\' OR
 "                                username LIKE 'FLOWS\_0%' ESCAPE '\')
 "                           AND username <> ':1')
 " ORDER BY username;
 "PROMPT ___Macro_separator(7)___
 "SELECT '|' ||
 "       username || ' |'
 " FROM dba_users
 " WHERE username IN ('ORDS_PUBLIC_USER','ORDS_METADATA')
 " ORDER BY username;
 "PROMPT ___Macro_separator(8)___
 "SELECT '|' ||
 "       proxy || ' |' ||
 "       client || ' |'
 " FROM proxy_users
 " WHERE proxy IN ('APEX_REST_PUBLIC_USER','ORDS_REST_PUBLIC_USER')
 " ORDER BY proxy, client;
 "PROMPT ___Macro_separator(9)___
 "DECLARE
 " vers VARCHAR2(30);
 "BEGIN
 " EXECUTE IMMEDIATE 'SELECT version FROM ords_metadata.ords_version'
 "  INTO vers;
 " dbms_output.put_line('|' || vers || ' |');
 "EXCEPTION
 " WHEN OTHERS THEN
 "  dbms_output.put_line('|N/A |');
 "END;
 "/
 "PROMPT ___Macro_separator(10)___
 "SELECT '|' ||
 "       username || ' |'
 " FROM dba_users
 " WHERE (username LIKE 'APEX\_0%' ESCAPE '\' OR
 "        username LIKE 'FLOWS\_0%' ESCAPE '\')
 "   AND (username <> ':1')
 " ORDER BY username;
 "PROMPT ___Macro_separator(11)___
 "SELECT '|' ||
 "       username || ' |' ||
 "       account_status || ' |' ||
 "       default_tablespace || ' |' ||
 "       temporary_tablespace || ' |'
 " FROM dba_users
 " WHERE username IN ('APEX_PUBLIC_USER','ANONYMOUS')
 " ORDER BY username;
 "PROMPT ___Macro_separator(12)___
 "SELECT '|' ||
 "       user_name || ' |' ||
 "       default_schema || ' |' ||
 "       account_locked || ' |'
 " FROM :1.wwv_flow_fnd_user
 " WHERE user_name = 'ADMIN'
 "   AND (default_schema = ':1'  OR
 "        default_schema IS NULL OR
 "        default_schema = 'APEX_INSTANCE_ADMIN_USER');
 "PROMPT ___Macro_separator(13)___
 "DECLARE
 " vers VARCHAR2(30);
 "BEGIN
 " EXECUTE IMMEDIATE 'SELECT owa_util.get_version FROM dual'
 "  INTO vers;
 " dbms_output.put_line('|' || vers || ' |');
 "EXCEPTION
 " WHEN OTHERS THEN
 "  dbms_output.put_line('|N/A |');
 "END;
 "/
 "PROMPT ___Macro_separator(14)___
 "SELECT '|' ||
 "       owner || ' |' ||
 "       object_name || ' |' ||
 "       object_type || ' |'
 " FROM dba_objects
 " WHERE object_name = 'OWA'
 " ORDER BY owner, object_type;
 "PROMPT ___Macro_separator(15)___
 "SELECT '| ' ||
 "       value/1024/1024 || '|'
 " FROM v$parameter
 " WHERE name = 'shared_pool_size';
 "PROMPT ___Macro_separator(16)___
 "SELECT '|' ||
 "       parameter || ' |' ||
 "       value || ' |'
 " FROM nls_database_parameters
 " WHERE parameter IN ('NLS_CHARACTERSET','NLS_NCHAR_CHARACTERSET')
 " ORDER BY parameter;
 "PROMPT ___Macro_separator(17)___
 "SELECT '| ' ||
 "       DECODE(SUM(bytes),null,0,SUM(bytes))/1024/1024 || '|'
 " FROM dba_free_space
 " WHERE tablespace_name ='SYSTEM';
 "PROMPT ___Macro_separator(18)___
 "SELECT '| ' ||
 "       DECODE(SUM(bytes),null,0,SUM(bytes))/1024/1024 || '|'
 " FROM dba_free_space
 " WHERE tablespace_name = ':2';
 "PROMPT ___Macro_separator(19)___
 "SELECT '| ' ||
 "       DECODE(SUM(bytes),null,0,SUM(bytes))/1024/1024 || '|'
 " FROM dba_free_space
 " WHERE tablespace_name = ':3';
 "PROMPT ___Macro_separator(20)___
 "SELECT '|' ||
 "       username || ' |' ||
         temporary_tablespace || ' |'
 " FROM dba_users
 " WHERE username IN (':1','FLOWS_FILES')
 " ORDER BY username;
 "PROMPT ___Macro_separator(21)___
 "SELECT '| ' ||
 "       value || '|'
 " FROM v$parameter
 " WHERE name = 'job_queue_processes';
 "PROMPT ___Macro_separator(22)___
 "SELECT '| ' ||
 "       dbms_xdb.gethttpport || '|'
 " FROM sys.dual;
 "PROMPT ___Macro_separator(23)___
 "SELECT '|' ||
 "       owner || ' |' ||
 "       object_name || ' |' ||
 "       object_type || ' |' ||
 "       status || ' |'
 " FROM dba_objects
 " WHERE object_name = 'DBMS_XMLPARSER'
 " ORDER BY owner, object_type;
 "PROMPT ___Macro_separator(24)___
 "SELECT '|' ||
 "       DECODE(COUNT(1),0,'Runtime',1,'Development','Unknown') || ' |'
 " FROM :1.wwv_flows
 " WHERE id = 4000;
 "PROMPT ___Macro_separator(25)___
 "SELECT '| ' ||
 "       workspace_id || '|' ||
 "       NVL(workspace_display_name,workspace) || ' |'
 " FROM apex_workspaces
 " ORDER BY workspace_id;
 "PROMPT ___Macro_separator(26)___
 "SELECT '| ' ||
 "       workspace_id || '|' ||
 "       NVL(workspace_display_name,workspace) || ' | ' ||
 "       application_id || '|' ||
 "       application_name || ' |'
 " FROM apex_applications
 " ORDER BY workspace_id, application_id;
 "PROMPT ___Macro_separator(27)___
 "SELECT '|' ||
 "       value || ' |'
 " FROM v$parameter
 " WHERE name = 'service_names';
 "PROMPT ___Macro_separator(28)___
 "SELECT '|' ||
 "       instance || ' |'
 " FROM v$thread;
 "PROMPT ___Macro_separator(29)___
 "SELECT '|' ||
 "       comp_id || ' |' ||
 "       comp_name || ' |' ||
 "       version || ' |' ||
 "       schema || ' |' ||
 "       status || ' |'
 " FROM dba_registry
 " ORDER BY comp_id;
 "PROMPT ___Macro_separator(30)___
 "SELECT '|' ||
 "       name || ' |' ||
 "       value || ' |' ||
 "       pref_desc || ' |'
 " FROM :1.wwv_flow_platform_prefs
 " ORDER BY name;
 "PROMPT ___Macro_separator(31)___
 "SELECT '| ' ||
 "       COUNT(1) || '|'
 " FROM dba_tab_privs
 " WHERE grantee = ':1';
 "PROMPT ___Macro_separator(32)___
 "SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' |' ||
 "       privilege || ' |'
 " FROM dba_tab_privs
 " WHERE grantee = ':1'
 " ORDER BY owner,table_name, privilege;
 "PROMPT ___Macro_separator(33)___
 "SELECT '|' ||
 "       privilege || ' |'
 " FROM dba_sys_privs
 " WHERE grantee = ':1'
 " ORDER BY privilege;
 "PROMPT ___Macro_separator(34)___
 "SELECT '|' ||
 "       granted_role || ' |'
 " FROM dba_role_privs
 " WHERE grantee = ':1'
 " ORDER BY granted_role;
 "PROMPT ___Macro_separator(35)___
 "SELECT '|' ||
 "       grantee || ' |'
 " FROM dba_role_privs
 " WHERE granted_role = 'APEX_ADMINISTRATOR_ROLE';
 "PROMPT ___Macro_separator(36)___
 "SELECT '| ' ||
 "       COUNT(1) || '|'
 " FROM dba_objects
 " WHERE status = 'INVALID';
 "PROMPT ___Macro_separator(37)___
 "SELECT '|' ||
 "       owner || ' |' ||
 "       object_name || ' |' ||
 "       object_type || ' |'
 " FROM dba_objects
 " WHERE status = 'INVALID'
 " ORDER BY owner, object_type, object_name;
 "PROMPT ___Macro_separator(38)___
 "SELECT '| ' ||
 "       COUNT(1) || '|'
 " FROM dba_objects
 " WHERE status = 'INVALID'
 "   AND object_type = 'SYNONYM';
 "PROMPT ___Macro_separator(39)___
 "SELECT '|' ||
 "       a.owner || ' |' ||
 "       a.synonym_name || ' |' ||
 "       a.table_owner || ' |' ||
 "       a.table_name || ' |'
 " FROM dba_synonyms a, dba_objects b
 " WHERE a.synonym_name = b.object_name
 "   AND a.owner = b.owner
 "   AND b.status = 'INVALID'
 " ORDER BY a.owner, a.synonym_name;
 }
 if match($ver,'^11')
 {append $sql
  {PROMPT ___Macro_separator(40)___
  "SELECT '|' ||
  "       a.host || ' | ' ||
  "       a.lower_port || '| ' ||
  "       a.upper_port || '|' ||
  "       p.principal || ' |' ||
  "       p.privilege || ' |'
  " FROM dba_network_acl_privileges p, dba_network_acls a
  " WHERE p.aclid = a.aclid
  " ORDER BY a.host, p.principal;
  }
 }
 elsif compare('valid',$ver,'120')
 {append $sql
  {PROMPT ___Macro_separator(40)___
  "SELECT '|' ||
  "       host || ' | ' ||
  "       lower_port || '| ' ||
  "       upper_port || '|' ||
  "       principal || ' |' ||
  "       privilege || ' |'
  " FROM dba_host_aces
  " ORDER BY host, principal;
  }
 }
 call separator(1)
 call writeSql(bindSql($sql,$usr,$adt,$fdt))
 call separator(0,'Database Information')
}

=head2 Database Information

Gathers APEX information from the database.

=cut

var ($TTL,@TTL,@HDR) = (undef)

call setSqlTarget(${I_DB})
# Test the database connection
if !testSql()
 var $ver = get_db_version(true)

# Collect the database information
if compare('valid',$ver,'92')
 call get_db_info($ver)
else
{report not_applicable
 write 'This section requires a database connection and can only be executed \
        on 9i Release 2 or later.'
 toc '2:[[',getFile(),'][rda_report][Database Information]]'
}

=head1 SEE ALSO

L<DB:DBinfo|collect::DB:DBinfo>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
