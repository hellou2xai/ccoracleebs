# DCadba.ctl:700:Collects ACS Oracle Database Assessment
# $Id: DCadba.ctl,v 1.16 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/DB/DCadba.ctl,v 1.13 2016/08/17 16:23:05 RDA Exp $
#
# Change History
# 20190326  SJC  Add default value to get_db_version in case d/b is not running.
# 20190226  SJC  Change logic for database version checks to allow for >=.
# 20181205  TSO  Add support for ASSM and for DB version 18c.
# 20160707  PCW  Updates for multitenant database.

=head1 NAME

DB:DCadba - Collects ACS Oracle Database Assessment

=head1 DESCRIPTION

This module collects information for ACS Oracle Database Assessment. This
collection can request to create database links temporarily for testing
purposes.

The assessment is only applicable to Oracle Database 8i, 9i, and later.

The following report can be generated and is regrouped under C<ACS Database
Assessment>:

=cut

if !${I_DBC/E}
 return

echo tput('bold'),'Processing DB.ADBA module ...',tput('off')

# Initialization
var $ASM_DGS     = ${B_ASM_DGS:false}
var $ASSESS_ALL  = ${B_ASSESS_ALL}
var $ORACLE_HOME = ${D_ORACLE_HOME/P:''}
var $ORACLE_SID  = ${T_ORACLE_SID/P}

var $DG_TBL = cond($ASM_DGS,'v$asm_diskgroup_stat','v$asm_diskgroup')

var $MNU = '1:ACS Database Assessment'
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc $MNU

# Load the common macros
run DB:DBinfo()

=head2 ACS - ACS Database Assessment

Collects information for ACS Oracle Database assessment.

=cut

var $DBVER = get_db_version(true,'80')
if compare('older',$DBVER,'81')
{report not_applicable
 write 'The ACS Oracle Database Assessment requires a database connection and \
        can only be executed on 8i or higher.'
 toc '2:[[',getFile(),'][rda_report][Not Applicable]]'
 return
}

var $STD_USR = "'ANONYMOUS','APEX_PUBLIC_USER','APPQOSSYS','AURORA$','AURORA',\
                'BI','CTXSYS','DBSNMP','DIP','DMSYS','DVF','DVSYS','EXFSYS',\
                'FLOWS_30000','FLOWS_FILES','HR','IX','LBACSYS','MDDATA',\
                'MDSYS','MGMT_VIEW','MTSSYS','ODM','ODM_MTR','OE','OLAPSYS',\
                'ORACLE_OCM','ORAWSM','ORDPLUGINS','ORDSYS','OSE','OUTLN',\
                'OWBSYS','PA_AWR_USER','PERFSTAT','PM','QS','QS_ADM','QS_CB',\
                'QS_CBADM','QS_CS','QS_ES','QS_OS','QS_WS','REPADMIN','SCOTT',\
                'SH','SI_INFORMTN_SCHEMA','SPATIAL_CSW_ADMIN_USR',\
                'SPATIAL_WFS_ADMIN_USR','SYS','SYSMAN','SYSTEM','TRACESVR',\
                'TSMSYS','WKPROXY','WKSYS','WK_TEST','WKUSER','WMSYS','XDB',\
                'XS$NULL'"

macro dsp_title
{var ($ttl,@lin) = @arg

 write '---+ ',$ttl
 loop $lin (@lin)
  write $lin
}

macro dsp_title_header
{var ($ttl,@lin) = @arg
 import $TOC,$TTL
 if $TTL
 {write '---+!! ',$TTL
  write $TOC
  var $TTL = undef
 }
 write '---+ ',$ttl
 loop $lin (@lin)
  write $lin
}

macro wrt_report
{var ($sql,$rpt) = @arg
 import $TOP
 keep $TOP

 call writeSql($sql)
 if hasOutput(true)
  write $TOP
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][',$rpt,']]'
}

macro wrt_sql
{var ($sql) = @arg
 import $TOP
 keep $TOP

 call writeSql($sql)
 if hasOutput(true)
  write $TOP
}

# --- Configuration -----------------------------------------------------------

pretoc '1+:Configuration'
debug ' Inside ADBA module, getting configuration information'

# Database
report database
var $ttl = 'Database'
var $hdr = '|*Name*|*Log Mode*|*Created*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       (select sys_context('userenv','db_name') from dual) || ' |' ||
"       log_mode || ' |' ||
"       TO_CHAR(created,'DD-Mon-YYYY"&nbsp;"HH24:MI') || ' |'
" FROM v$database;
}
call wrt_report($sql,$ttl)

# Instance
report instance
var $ttl = 'Instance'
var $hdr = '| *Instance*|*Instance Name*|*Host Name*|*Startup*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '| ' ||
"       instance_number || '|' ||
"       instance_name || ' |' ||
"       host_name || ' |' ||
"       TO_CHAR(startup_time,'DD-Mon-YYYY"&nbsp;"HH24:MI') || ' |'
" FROM v$instance;
}
call wrt_report($sql,$ttl)

# Version
report version
var $ttl = 'Version'
var $hdr = '|*Banner*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       banner || ' |'
" FROM v$version;
}
call wrt_report($sql,$ttl)

# Database Options
report dboption
var $ttl = 'Database Options'
var $hdr = '|*Option*|*Installed?*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       parameter || ' |' ||
"       value || ' |'
" FROM v$option;
}
call wrt_report($sql,$ttl)

# Nondefault init.ora parameters
report init_nondef
var $ttl = 'Nondefault init.ora Parameters'
var $hdr = '|*Parameter*|*Value*|*Description*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       a.ksppinm || ' |' ||
"       REPLACE(REPLACE(b.ksppstvl,'|','&#124;'),CHR(10),'%BR%') || ' |' ||
"       a.ksppdesc || ' |'
" FROM sys.x$ksppi a,sys.x$ksppsv b
" WHERE a.indx = b.indx
"   AND UPPER(b.ksppstdf) = 'FALSE'
" ORDER BY a.ksppinm;
}
call wrt_report($sql,$ttl)

# Database configuration parameter
report dbparameter_config
var $ttl = 'Database Configuration Parameters'
var $hdr = '|*Parameter Name*|*Non Default Value*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       name || ' |' ||
"       value || ' |'
" FROM v$parameter a
" WHERE a.isdefault = 'FALSE'
"   AND a.name not like '\_\_%' ESCAPE '\'
" ORDER BY 1;
}
call wrt_report($sql,$ttl)

# Redolog files
report redo_log_files_doc
var $ttl = 'Redo Log Files'
if match($DBVER,'^(81|90)')
{var $hdr = '|*Redo Log File*| *Group*| *Instance*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       a.member || ' | ' ||
 "       a.Group# || '| ' ||
 "       b.thread# || '|'
 " FROM v$logfile a,v$log b
 " WHERE a.group# = b.group#
 " ORDER BY b.thread#,a.Group#;
 }
}
else
{var $hdr = '|*Redo Log File*| *Group*| *Instance*|*Type*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       a.member || ' | ' ||
 "       a.Group# || '| ' ||
 "       b.thread# || '|' ||
 "       a.type || ' |'
 " FROM v$logfile a,v$log b
 " WHERE a.group# = b.group#
 " ORDER BY b.thread#,a.Type,a.Group#;
 }
}
call wrt_report($sql,$ttl)

# Undo parameters
report parameter_undo
var $ttl = 'Undo Parameters'
var $hdr = '|*Initialization Parameter*|*Value*|*IsDefault*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       a.ksppinm || ' |' ||
"       REPLACE(REPLACE(b.ksppstvl,'|','&#124;'),CHR(10),'%BR%') || ' |' ||
"       b.ksppstdf || ' |'
" FROM sys.x$ksppi a,sys.x$ksppsv b
" WHERE a.ksppinm like '%undo%'
"   AND SUBSTR(a.ksppinm,1,1) != '_'
"   AND a.indx = b.indx
" ORDER BY a.ksppinm;
}
call wrt_report($sql,$ttl)

# Parameter parallelism
report parameter_parallelism
var $ttl = 'Parallelism Parameters'
var $hdr = '|*Initialization Parameter*|*Value*|*IsDefault*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       a.ksppinm || ' |' ||
"       REPLACE(REPLACE(b.ksppstvl,'|','&#124;'),CHR(10),'%BR%') || ' |' ||
"       b.ksppstdf || ' |'
" FROM sys.x$ksppi a,sys.x$ksppsv b
" WHERE a.ksppinm like 'parallel%'
"   AND a.indx = b.indx
" ORDER BY a.ksppinm;
}
call wrt_report($sql,$ttl)

# Job queue parameters
report parameter_jobqueue
var $ttl = 'Job Queue Parameters'
var $hdr = '|*Initialization Parameter*| *Value*|*IsDefault*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       a.ksppinm || ' | ' ||
"       b.ksppstvl || '|' ||
"       b.ksppstdf || ' |'
" FROM sys.x$ksppi a,sys.x$ksppsv b
" WHERE a.ksppinm like 'job_queue_%'
"   AND a.indx = b.indx
" ORDER BY a.ksppinm;
}
call wrt_report($sql,$ttl)

# Init.ora parameters (including hidden)

report init_all
var $ttl = 'Init.ora Parameters'
var $hdr = '|*Initialization Parameter*|*Value*|*IsDefault*|*Description*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SET linesize 32766
"SELECT '|' ||
"       a.ksppinm || ' |' ||
"       REPLACE(REPLACE(b.ksppstvl,'|','&#124;'),CHR(10),'%BR%') || ' |' ||
"       b.ksppstdf || ' |' ||
"       a.ksppdesc || ' |'
" FROM sys.x$ksppi a,sys.x$ksppsv b
" WHERE a.indx = b.indx
" ORDER BY a.ksppinm;
}
call wrt_report($sql,$ttl)

# Hidden init.ora parameters
report init_hidden
var $ttl = 'Hidden init.ora Parameters'
var $hdr = '|*Parameter Name*|*Value*|*Description*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       a.ksppinm || ' |' ||
"       REPLACE(REPLACE(b.ksppstvl,'|','&#124;'),CHR(10),'%BR%') || ' |' ||
"       a.ksppdesc || ' |'
" FROM sys.x$ksppi a,sys.x$ksppsv b
" WHERE a.indx = b.indx
"   AND b.ksppstdf = 'FALSE'
"   AND SUBSTR(a.ksppinm,1,1) = '_'
" ORDER BY a.ksppinm;
}
call wrt_report($sql,$ttl)

# Database facts
report db_facts
prefix
 call dsp_title('Database Facts')
set $sql
{SELECT '|*Version*|' ||
"       version || ' |'
" FROM v$instance;
"SELECT '|*Charset*|' ||
"       value || ' |'
" FROM nls_database_parameters
" WHERE parameter = 'NLS_CHARACTERSET';
"SELECT '|*Ncharset*|' ||
"       value || ' |'
" FROM nls_database_parameters
" WHERE parameter = 'NLS_NCHAR_CHARACTERSET';
"SELECT '|*Hostname*|' ||
"       host_name || ' |'
" FROM v$instance;
"SELECT '|*DB Status*|' ||
"       database_status || ' |'
" FROM v$instance;
"SELECT '|*Log Mode*|' ||
"       log_mode || ' |'
" FROM v$database;
"SELECT '|*Cpu Count*| ' ||
"       value || '|'
" FROM v$parameter
" WHERE name like 'CPU_COUNT';
"SELECT '|*Optimizer*|' ||
"       value || ' |'
" FROM v$parameter
" WHERE name like 'OPTIMIZER_MODE';
"SELECT '|*Parallel Force Local*|' ||
"       value || ' |'
" FROM v$parameter
" WHERE name like 'parallel_force_local';
"SELECT '|*Datafiles*|' ||
"       TO_CHAR(ROUND(SUM(bytes) / 1048576,0)) || ' |'
" FROM v$dataFile;
"SELECT '|*Tempfiles*|' ||
"       TO_CHAR(ROUND(SUM(bytes) / 1048576,0)) || ' |'
" FROM v$tempFile;
}
call wrt_report($sql,"Database Facts")

# Operating system facts (UNIX only)
if isUnix()
{report os_facts
 var $ttl = 'Operating System Facts'
 call dsp_title($ttl)
 write '|Uname|',uname('a'),'|'
 write '|OS Release|',uname('r'),'|'
 write '|OS Plattform|',uname(),'|'
 write '|Hardware|',uname('m'),'|'
 var $cnt = grepCommand('ps -ef','pmon','i')
 write '|Instance Count|',$cnt,'|'
 write $TOP
 toc '2:[[',getFile(),'][rda_report][',$ttl,']]'
}

# Current number of roles assigned (Only for Oracle Database 9i)
if $ASSESS_ALL
{if match($DBVER,'^9')
 {report enabled_roles
  var $ttl = 'Enabled Roles'
  var $hdr = '|*Grantee*| *Number of Roles*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       grantee || ' | ' ||
  "       COUNT(*) || '|'
  " FROM (SELECT grantee,
  "              granted_role
  "        FROM dba_role_privs
  "        CONNECT BY PRIOR grantee = granted_role)
  " GROUP BY grantee
  " HAVING COUNT(*) = (SELECT MAX(COUNT(*))
  "                     FROM (SELECT grantee,
  "                                  granted_role
  "                            FROM dba_role_privs
  "                            CONNECT BY PRIOR grantee = granted_role)
  "                     GROUP BY grantee);
  }
  call wrt_report($sql,$ttl)
 }

# --- Problems ----------------------------------------------------------------

 if isTocCreated(true)
  pretoc '%SPLIT%'
 else
  pretoc $MNU
 pretoc '1+:Problems'

 debug ' Inside ADBA module, getting objects with problems'

 # Normal indexes that should be rebuilt
 report sparse_index
 var $ttl = 'Sparse Indexes - Dictionary Managed'
 set $sql
 {SELECT user#
 " FROM sys.user$
 " WHERE name IN (:1);
 }
 call loadSql(bindSql($sql,$STD_USR))
 var $usr = join(',',getSqlLines())
 var $den = '75'
 var $obj = 'NVL(isp.obj#,NVL(ip.obj#,i.obj#))'
 var $lan = "NVL(DECODE(NVL(isp.obj#,NVL(ip.obj#,i.obj#)),isp.obj#,\
            isp.analyzetime,ip.obj#,ip.analyzetime,i.analyzetime),\
            TO_DATE('01.01.1900','dd.mm.yyyy'))"
 var $cpr = "DECODE(NVL(isp.obj#,NVL(ip.obj#,i.obj#)),isp.obj#,'N/A',\
            ip.obj#,DECODE(BITAND(ip.flags,1024),0,'DISABLED',1024,\
            'ENABLED','N/A'),DECODE(BITAND(i.flags,32),0,'DISABLED',32,\
            'ENABLED','N/A'))"
 var $objp = 'NVL(ip.obj#,i.obj#)'
 var $rcnt = 'DECODE(NVL(isp.obj#,NVL(ip.obj#,i.obj#)),isp.obj#,isp.rowcnt,\
             ip.obj#,ip.rowcnt,i.rowcnt)'
 var $lcnt = 'DECODE(NVL(isp.obj#,NVL(ip.obj#,i.obj#)),isp.obj#,isp.leafcnt,\
             ip.obj#,ip.leafcnt,i.leafcnt)'
 var $pctf = 'DECODE(NVL(isp.obj#,NVL(ip.obj#,i.obj#)),isp.obj#,isp.pctfree$,\
             ip.obj#,ip.pctfree$,i.pctfree$)'
 var $inir = 'DECODE(NVL(isp.obj#,NVL(ip.obj#,i.obj#)),isp.obj#,isp.initrans,\
             ip.obj#,ip.initrans,i.initrans)'
 if match($DBVER,'^81')
 {var $hdr = '|*Index Name*|*Part Name*|*Subpart Name*| *Density (%)*| \
               *Extra Blocks*|*Last Ddl Time*|*Last Analyzed*|*Compression*|\
               *Func Idx*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT 'sind=' || '|' ||
  "       u.name ||'.'|| o.name || ' |' ||
  "       op.subname || ' |' ||
  "       DECODE(:1,isp.obj#,o.subname,'') || ' | ' ||
  "       TO_CHAR(100*(1 - FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) / ((p.value -
  "               66 - :6 * 24)*(1 - :5 / 100))) / :4),'999.00') || '| ' ||
  "       FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) / ((p.value - 66 - :6 * 24) *
  "              (1 - :5 / 100))) || '|' ||
  "       MAX(o.mtime) || ' |' ||
  "       DECODE(MAX(:7),TO_DATE('01.01.1900','dd.mm.yyyy'),'not analyzed',
  "         TO_CHAR(MAX(:7),'DD-Mon-YYYY')) || ' |' ||
  "       TO_CHAR(MAX(:8),'DD-Mon-YYYY') || ' |' ||
  "       MAX(DECODE(BITAND(i.property,16),0,'NO','YES')) || ' |'
  " FROM sys.ind$ i,
  "      sys.icol$ ic,
  "      (SELECT obj#,
  "              part#,
  "              bo#,
  "              rowcnt,
  "              leafcnt,
  "              initrans,
  "              pctfree$,
  "              analyzetime,
  "              flags
  "        FROM sys.indpart$
  "        UNION ALL
  "        SELECT obj#,
  "               part#,
  "               bo#,
  "               rowcnt,
  "               leafcnt,
  "               definitrans,
  "               defpctfree,
  "               analyzetime,
  "               flags
  "         FROM sys.indcompart$) ip,
  "      sys.indsubpart$ isp,
  "      sys.hist_head$ h,
  "      (SELECT kvisval VALUE
  "        FROM x$kvis
  "        WHERE kvistag = 'kcbbkl') p,
  "      sys.obj$ o,
  "      sys.user$ u,
  "      sys.obj$ op
  " WHERE i.obj# = ip.bo#(+)
  "   AND ip.obj# = isp.pobj#(+)
  "   AND :4 > 1
  "   AND i.type# IN (1)
  "   AND i.pctthres$ IS NULL
  "   AND ic.obj# = i.obj#
  "   AND h.obj# = i.bo#
  "   AND h.intcol# = ic.intcol#
  "   AND o.obj# = :1
  "   AND o.owner# NOT IN (:10)
  "   AND u.user# = o.owner#
  "   AND op.obj# = :2
  "   AND u.name NOT IN ('SYSMAN','XDB')
  " GROUP BY u.NAME,
  "          o.NAME,
  "          op.subname,
  "          DECODE(:1,isp.obj#,o.subname,''),
  "          :3,
  "          :4,
  "          :6,
  "          :5,
  "          p.VALUE
  " HAVING 100 * (1 - FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) / ((p.value - 66 -
  "        :6 * 24) * (1 - :5 / 100))) / :4) <= NVL(':9','75')
  "    AND FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) / ((p.value - 66 - :6 * 24) *
  "        (1 - :5 / 100))) > 0
  " ORDER BY FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) / ((p.value - 66 - :6 * 24) *
  "                 (1 - :5 / 100))) DESC,
  "          TO_CHAR(100 * (1 - FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) /
  "                  ((p.value - 66 - :6 * 24) * (1 - :5 / 100))) / :4),
  "                  '999.00');
  }
  loop $lin (grepSql(bindSql($sql,$obj,$objp,$rcnt,$lcnt,$pctf,$inir,\
                                  $lan,$cpr,$den,$usr),'^sind='))
   write value($lin)
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][',$ttl,']]'
  }
 }
 else
 {var $hdr = '|*Index Name*|*Part Name*|*Subpart Name*| *Density (%)*| \
               *Extra Blocks*|*Last DDL Time*|*Last Analyzed*|*Compression*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       u.name ||'.'|| o.name || ' |' ||
  "       op.subname || ' |' ||
  "       DECODE(:1,isp.obj#,o.subname,'') || ' | ' ||
  "       TO_CHAR(100*(1 - FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) / ((p.value -
  "               66 - :6 * 24) * (1 - :5 / 100))) / :4),'999.00') || '| ' ||
  "       FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) / ((p.value - 66 - :6 * 24) *
  "             (1 - :5 / 100))) || '|' ||
  "       TO_CHAR(MAX(o.mtime),'DD-Mon-YYYY') || ' |' ||
  "       DECODE(MAX(:7),TO_DATE('01.01.1900','dd.mm.yyyy'),'not analyzed',
  "         TO_CHAR(MAX(:7),'DD-Mon-YYYY')) || ' |' ||
  "       MAX(:8) || ' |'
  " FROM sys.ind$ i,
  "      sys.icol$ ic,
  "      (SELECT obj#,
  "              part#,
  "              bo#,
  "              ts#,
  "              rowcnt,
  "              leafcnt,
  "              initrans,
  "              pctfree$,
  "              analyzetime,
  "              flags
  "        FROM sys.indpart$
  "        UNION ALL
  "        SELECT obj#,
  "               part#,
  "               bo#,
  "               defts#,
  "               rowcnt,
  "               leafcnt,
  "               definitrans,
  "               defpctfree,
  "               analyzetime,
  "               flags
  "         FROM sys.indcompart$) ip,
  "      sys.indsubpart$ isp,
  "      (SELECT ts#,
  "              blocksize value
  "        FROM sys.ts$) p,
  "      sys.hist_head$ h,
  "      sys.obj$ o,
  "      sys.user$ u,
  "      sys.obj$  op
  " WHERE i.obj# = ip.bo#(+)
  "   AND ip.obj# = isp.pobj#(+)
  "   AND :4 > 1
  "   AND i.type# in (1)
  "   AND i.pctthres$ is null
  "   AND DECODE(:1,isp.obj#,isp.ts#,ip.obj#,ip.ts#,i.ts#) = p.ts#
  "   AND ic.obj# = i.obj#
  "   AND h.obj# = i.bo#
  "   AND h.intcol# = ic.intcol#
  "   AND o.obj# = :1
  "   AND o.owner# NOT IN (:10)
  "   AND u.user# = o.owner#
  "   AND op.obj# = :2
  " GROUP BY u.name,
  "          o.name,
  "          op.subname,
  "          DECODE(:1,isp.obj#,o.subname,''),
  "          :3,
  "          :4,
  "          :6,
  "          :5,
  "          p.value
  " HAVING 100*(1 - FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) / ((p.value - 66 -
  "        :6 * 24)*(1 - :5 / 100))) / :4) <= NVL(':9','75')
  "    AND FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) / ((p.value - 66 - :6 * 24) *
  "        (1 - :5 / 100))) > 0
  " ORDER BY FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) / ((p.value - 66 - :6 * 24)
  "                *(1 - :5 / 100))) desc,
  "          TO_CHAR(100*(1 - FLOOR(:4 - :3 * (SUM(h.avgcln) + 10) / ((p.value
  "                  - 66 - :6 * 24)*(1 - :5 / 100)))/:4),'999.00');
  }
  call wrt_report(bindSql($sql,$obj,$objp,$rcnt,$lcnt,$pctf,$inir,\
                               $lan,$cpr,$den,$usr),$ttl)
 }

 # List all sparse Tables
 report sparse_tables
 var $ttl = 'Sparse Tables - Dictionary Managed'
 var $hdr = '|*Owner*|*Table*|*Partition*| *Avg KiB/Block*| *Blocks*| \
              *Row Count*| *Empty Blk*| *Free Space*| *Avg Row Length*| *HWM*| \
              *Used (KiB)*| *Used (%)*| *Free (%)*| *Freelists*|\
              *Last Analyzed*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       r.own || ' |' ||
 "       r.tbl || ' |' ||
 "       r.prt || ' | ' ||
 "       ROUND(r.rwc * r.avl / r.blk / 1024,2) || '| ' ||
 "       r.blk || '| ' ||
 "       r.rwc || '| ' ||
 "       r.ebl || '| ' ||
 "       r.avs || '| ' ||
 "       r.avl || '| ' ||
 "       r.hwm || '| ' ||
 "       ROUND(r.rwc * r.avl / 1024,2) || '| ' ||
 "       NVL(TO_CHAR(r.pcu,999),'-') || '| ' ||
 "       NVL(TO_CHAR(r.pcf,999),'-') || '| ' ||
 "       NVL(TO_CHAR(r.frl,9999),'-') || '|' ||
 "       NVL(TO_CHAR(r.dat,'DD-Mon-YYYY HH24:MI:SS'),'not analyzed') || ' |'
 " FROM (SELECT table_owner own,
 "              table_name tbl,
 "              a.partition_name prt,
 "              a.blocks blk,
 "              a.num_rows rwc,
 "              a.empty_blocks ebl,
 "              a.avg_space avs,
 "              a.avg_row_len avl,
 "              (b.blocks - a.empty_blocks - 1) hwm,
 "              a.pct_used pcu,
 "              a.pct_free pcf,
 "              a.freelists frl,
 "              a.last_analyzed dat
 "        FROM dba_tab_partitions a,dba_segments b
 "        WHERE a.num_rows * a.avg_row_len / a.blocks <
 "               (SELECT value / 2
 "                 FROM v$parameter
 "                 WHERE LOWER(NAME) = 'db_block_size')
 "          AND extents > 1
 "          AND a.table_owner = b.owner
 "          AND b.owner NOT IN (:1)
 "          AND a.table_name = b.segment_name
 "          AND a.partition_name = b.partition_name
 "          AND a.blocks > 100
 "          AND a.num_rows > 0
 "          AND a.last_analyzed IS NOT NULL
 "       UNION ALL
 "       SELECT a.owner own,
 "              table_name tbl,
 "              'N/A' prt,
 "              a.blocks blk,
 "              a.num_rows rwc,
 "              a.empty_blocks ebl,
 "              a.avg_space avs,
 "              a.avg_row_len avl,
 "              (b.blocks - a.empty_blocks - 1) hwm,
 "              a.pct_used pcu,
 "              a.pct_free pcf,
 "              a.freelists frl,
 "              a.last_analyzed dat
 "        FROM dba_tables a,dba_segments b
 "        WHERE a.num_rows * a.avg_row_len / a.blocks <
 "               (SELECT VALUE / 2
 "                FROM v$parameter
 "                WHERE LOWER(NAME) = 'db_block_size')
 "          AND extents > 1
 "          AND a.owner = b.owner
 "          AND b.owner NOT IN (:1)
 "          AND a.table_name = b.segment_name
 "          AND a.blocks > 100
 "          AND a.num_rows > 0
 "          AND a.tablespace_name <> ' '
 "          AND a.last_analyzed IS NOT NULL) r
 " ORDER BY (r.rwc * r.avl / r.blk) DESC;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # ASSM indexes which have over 1G bytes in fs3 and fs4
 if compare('valid',$DBVER,'102')
 {report chk_assm_indexes
  var $ttl = 'ASSM Indexes with more than 1Gb Free Space'
  var $hdr = '|*Owner*|*Index Name*|*Bytes in Blocks > 50% Free*|'
  prefix
   call dsp_title($ttl,$hdr)

  set $sql
  {SET serverout on
   "DECLARE
   "  v_unformatted_blocks number;
   "  v_unformatted_bytes number;
   "  v_fs1_blocks number;
   "  v_fs1_bytes number;
   "  v_fs2_blocks number;
   "  v_fs2_bytes number;
   "  v_fs3_blocks number;
   "  v_fs3_bytes number;
   "  v_fs4_blocks number;
   "  v_fs4_bytes number;
   "  v_full_blocks number;
   "  v_full_bytes number;
   "  l_user all_indexes.owner%TYPE;
   "  l_index all_indexes.index_name%TYPE;
   "  BEGIN
   "   FOR c in (SELECT owner, index_name
   "             FROM all_indexes
   "             WHERE tablespace_name IN
   "              (SELECT tablespace_name
   "               FROM dba_tablespaces
   "               WHERE segment_space_management = 'AUTO')
   "              )
   "   LOOP
   "    BEGIN
   "     l_user  := c.owner;
   "     l_index := c.index_name;
   "     dbms_space.space_usage(l_user,
   "                            l_index,
   "                            'INDEX',
   "                            v_unformatted_blocks,
   "                            v_unformatted_bytes,
   "                            v_fs1_blocks,
   "                            v_fs1_bytes,
   "                            v_fs2_blocks,
   "                            v_fs2_bytes,
   "                            v_fs3_blocks,
   "                            v_fs3_bytes,
   "                            v_fs4_blocks,
   "                            v_fs4_bytes,
   "                            v_full_blocks,
   "                            v_full_bytes);
   "     IF v_fs4_bytes + v_fs3_bytes > 1073741824
   "     THEN
   "      dbms_output.put_line(' | ' || l_user || ' | ' ||
   "                           l_index || ' | ' ||
   "                           to_char(v_fs4_bytes + v_fs3_bytes) || ' | ');
   "     END IF;
   "    END;
   "   END LOOP;
   "  END;
   " /
   }
  call wrt_report($sql,$ttl)
 }

 # ASSM tables which have over 1G bytes in fs3 and fs4
 if compare('valid',$DBVER,'102')
 {report chk_assm_tables
  var $ttl = 'ASSM Tables with more than 1Gb Free Space'
  var $hdr = '|*Owner*|*Table Name*|*Bytes in Blocks > 50% Free*|'
  prefix
   call dsp_title($ttl,$hdr)

  set $sql
  {SET serverout on
   "DECLARE
   "  v_unformatted_blocks number;
   "  v_unformatted_bytes number;
   "  v_fs1_blocks number;
   "  v_fs1_bytes number;
   "  v_fs2_blocks number;
   "  v_fs2_bytes number;
   "  v_fs3_blocks number;
   "  v_fs3_bytes number;
   "  v_fs4_blocks number;
   "  v_fs4_bytes number;
   "  v_full_blocks number;
   "  v_full_bytes number;
   "  l_user all_tables.owner%TYPE;
   "  l_table all_tables.table_name%TYPE;
   "  BEGIN
   "   FOR c in (SELECT owner, table_name
   "             FROM all_tables
   "             WHERE tablespace_name IN
   "              (SELECT tablespace_name
   "               FROM dba_tablespaces
   "               WHERE segment_space_management = 'AUTO')
   "              )
   "   LOOP
   "    BEGIN
   "     l_user  := c.owner;
   "     l_table := c.table_name;
   "     dbms_space.space_usage(l_user,
   "                            l_table,
   "                            'TABLE',
   "                            v_unformatted_blocks,
   "                            v_unformatted_bytes,
   "                            v_fs1_blocks,
   "                            v_fs1_bytes,
   "                            v_fs2_blocks,
   "                            v_fs2_bytes,
   "                            v_fs3_blocks,
   "                            v_fs3_bytes,
   "                            v_fs4_blocks,
   "                            v_fs4_bytes,
   "                            v_full_blocks,
   "                            v_full_bytes);
   "     IF v_fs4_bytes + v_fs3_bytes > 1073741824
   "     THEN
   "      dbms_output.put_line(' | '|| l_user || ' | ' ||
   "                           l_table || ' | ' ||
   "                           to_char(v_fs4_bytes + v_fs3_bytes) || ' | ' );
   "     END IF;
   "    END;
   "   END LOOP;
   "  END;
   " /
   }
  call wrt_report($sql,$ttl)
 }

 # Objects with MAXTRANS set low
 # Hint: can lead to enqueue waits (TX shared mode)
 report low_maxtrans
 var $ttl = 'Objects with MAXTRANS set low'
 var $hdr = '|*Name*|*Owner*|*Max Trans*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       table_name || ' |' ||
 "       owner || ' |' ||
 "       max_trans || ' |'
 " FROM dba_tables
 " WHERE owner NOT IN (:1)
 "   AND max_trans BETWEEN 1 AND 20;
 "SELECT '|' ||
 "       index_name || ' |' ||
 "       owner || ' |' ||
 "       max_trans || ' |'
 " FROM dba_indexes
 " WHERE owner NOT IN (:1)
 "   AND max_trans BETWEEN 1 AND 20;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Chained and migrated rows
 # Hint: Output only valid if tables have been analyzed
 report row_migration
 var $ttl = 'Chained and Migrated Rows'
 var $hdr = '|*Owner*|*Table Name*|*Free (%)*|*Used (%)*|*Number of Rows*|\
              *Chain Count*|*Avg Row Length*| *Migrated (%)*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' |' ||
 "       pct_free || ' |' ||
 "       pct_used || ' |' ||
 "       pct_free || ' |' ||
 "       num_rows || ' |' ||
 "       chain_cnt || ' |' ||
 "       avg_row_len || ' |' ||
 "       ROUND(100 * chain_cnt / num_rows,2) || ' |'
 " FROM dba_tables
 " WHERE owner NOT IN (:1)
 "   AND num_rows > 0
 "   AND chain_cnt > 0
 " ORDER BY chain_cnt / num_rows;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Objects with many extents in dict. managed tablespaces
 # Hint: Can have a major impact when dropping the object
 report many_extents
 var $ttl = 'Objects with Many Extents'
 var $hdr = '|*Owner*|*Segment Name*|*Segment Type*|*Extents*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       a.owner || ' |' ||
 "       a.segment_name || ' |' ||
 "       a.segment_type || ' |' ||
 "       a.extents || ' |'
 " FROM dba_segments a,dba_tablespaces b
 " WHERE a.tablespace_name = b.tablespace_name
 "   AND a.owner NOT IN (:1)
 "   AND b.extent_management = 'DICTIONARY'
 "   AND a.extents > 200
 " ORDER BY a.extents DESC;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Segments with more than 75% of max extents
 report extents_used_75
 var $ttl = 'Extents Used 75% of Max Extents'
 var $hdr = '|*Owner*|*Tablespace*|*Segment*|*Segment Type*| *Size*| \
              *Extents*| *Max Extents*| *Max Extents Used (%)*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       tablespace_name || ' |' ||
 "       segment_name || ' |' ||
 "       segment_type || ' |' ||
 "       bytes || ' |' ||
 "       extents || ' |' ||
 "       max_extents || ' |' ||
 "       ROUND(100 * extents / max_extents,2) || ' |'
 " FROM dba_segments
 " WHERE segment_type IN ('TABLE','INDEX')
 "   AND extents > max_extents / 4 * 3
 "   AND owner NOT IN (:1)
 " ORDER BY (EXTENTS / MAX_EXTENTS) DESC;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Objects that cannot extend
 report unextendible_objects
 var $ttl = 'Objects that Cannot Extend'
 var $hdr = '|*Owner*|*Segment*|*Partition*| Extents*| *Next Extent (KiB)*|\
              *Tablespace*|*Max Extents*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       s.owner || ' |' ||
 "       s.segment_name || ' |' ||
 "       s.partition_name || ' | ' ||
 "       s.extents || '| ' ||
 "       TO_CHAR(DECODE(t.extent_management,'LOCAL',
 "                      t.min_extlen,s.next_extent) / 1024,
 "               '9999999999.99') || '|' ||
 "       s.tablespace_name || ' | ' ||
 "       DECODE(t.extent_management,'LOCAL','',s.max_extents) || '|'
 " FROM sys.dba_tablespaces t,sys.dba_segments s
 " WHERE s.owner NOT IN (:1)
 "   AND s.tablespace_name = t.tablespace_name
 "   AND t.status = 'ONLINE'
 "   AND ((DECODE(t.extent_management,'LOCAL',t.min_extlen,s.next_extent) >
 "           (SELECT MAX(bytes)
 "             FROM sys.dba_free_space
 "             WHERE tablespace_name = s.tablespace_name)
 "   AND NOT EXISTS (SELECT *
 "                    FROM dba_data_files
 "                    WHERE tablespace_name = s.tablespace_name
 "                      AND autoextensible = 'YES'
 "                      AND (maxbytes - bytes) >= DECODE(t.extent_management,
 "                              'LOCAL',t.min_extlen,s.next_extent)))
 "    OR s.extents = DECODE(t.extent_management,'LOCAL',0,s.max_extents))
 " ORDER BY s.tablespace_name,s.segment_name,s.partition_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Invalid objects count
 report invalid_objects_count
 var $ttl = 'Invalid Objects Count'
 var $hdr = '|*Owner*| *Number of Invalid Objects*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' | ' ||
 "       COUNT(*) || '|'
 " FROM dba_objects
 " WHERE status = 'INVALID'
 "   AND owner NOT IN (:1)
 " GROUP BY owner;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Invalid objects
 report invalid_objects
 var $ttl = 'Invalid Objects'
 var $hdr = '|*Owner*|*Object Type*|*Object Name*|*Status*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       object_type || ' |' ||
 "       object_name || ' |' ||
 "       status || ' |'
 " FROM dba_objects
 " WHERE status = 'INVALID'
 "   AND owner NOT IN (:1)
 " ORDER BY owner,object_type,object_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # ALL_ERRORS to add information for invalid objects
 report all_errors
 var $ttl = 'All Errors'
 var $hdr = '|*Owner*|*Name*|*Type*|*Text*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       name || ' |' ||
 "       type || ' |' ||
 "       REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(text),
 "        '|','&#124;'),
 "        '<','&lt;'),
 "        '>','&gt;'),
 "        CHR(10),'%BR%') || '|'
 " FROM all_errors
 " WHERE owner NOT IN (:1)
 " ORDER BY owner,name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Analyzed data dictionary tables
 report analyzed_dict
 var $ttl = 'Analyzed Data Dictionary Tables'
 var $hdr = '|*Dictionary*| *Number of Objects*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       'Analyzed Objects' || ' | ' ||
 "       COUNT(*) || '|'
 " FROM all_tables
 " WHERE owner NOT IN (:1)
 "   AND num_rows > 0;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Users with objects in the SYSTEM tablespace
 report system_users
 var $ttl = 'Users with Objects in the SYSTEM Tablespace'
 var $hdr = '|*User*| *Segment Name*|*Type*|*Tablespace*| *Size (MiB)*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       segment_name || ' |' ||
 "       segment_type || ' |' ||
 "       tablespace_name || ' |' ||
 "       TO_CHAR(bytes / 1048576) || ' |'
 " FROM dba_segments
 " WHERE tablespace_name = 'SYSTEM'
 "   AND owner NOT IN (:1)
 " ORDER BY owner,segment_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Tablespaces in hot backup mode
 report hot_backup_mode
 var $ttl = 'Tablespaces in Hot Backup Mode'
 var $hdr = '|*File*|*Status*| *Change#*| *Time*|'
 prefix
 call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       f.name || ' |' ||
 "       b.status || ' |' ||
 "       b.change# || ' |' ||
 "       b.time || ' |'
 " FROM v$backup b,v$datafile f
 " WHERE b.status = 'ACTIVE'
 "   AND b.file# = f.file#;
 }
 call wrt_report($sql,$ttl)

 # Corruptions found during RMAN Backup / Copy

 # v$backup_corruption,v$copy_corruption describe
 # corrupt blocks which existed in some particular backup.  The backup in which
 # the corrupt blocks were found is identified by the set_stamp and set_count
 # columns.  Even if the block is fixed later, that does not change the fact
 # that the block is corrupt in *that particular* backup.
 # In 9.2, we are introducing a new view, v$database_block_corruption,
 # which recognizes that a block is no longer corrupt if another backup, or
 # copy, done with RMAN has scanned the file and found that the block is OK.

 report rman_corruptions
 var $TTL = 'RMAN Corruptions'

 var $ttl = 'Backup Corruption'
 var $hdr = '| *File#*| *Block#*| *RecID*| *Stamp*|'
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       file# || ' |' ||
 "       block# || ' |' ||
 "       recid || ' |' ||
 "       stamp || ' |'
 " FROM v$backup_corruption;
 }
 call wrt_sql($sql)

 var $ttl = 'Copy Corruption'
 var $hdr = '| *File#*| *Block#*| *RecID*| *Stamp*|'
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       file# || ' |' ||
 "       block# || ' |' ||
 "       recid || ' |' ||
 "       stamp || ' |'
 " FROM v$copy_corruption;
 }
 call wrt_sql($sql)

 if compare('valid',$DBVER,'90')
 {var $ttl = 'Corruptions not recovered so far'
  var $hdr = '| *File#*| *Block#*| *Blocks*|*Corruption Type*|'
  prefix
   call dsp_title_header($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       file# || ' |' ||
  "       block# || ' |' ||
  "       blocks || ' |' ||
  "       corruption_type || ' |'
  " FROM v$database_block_corruption;
  }
  call wrt_sql($sql)
 }

 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][RMAN Corruptions]]'

 # User default tablespaces SYSTEM or temporary tablespace not correct
 report user_default_tbs_system
 var $ttl = 'User Default Tbs System or Temp Tbs not Correct'
 var $hdr = '|*User*|*Status*|*Default Tablespace*| *Temp Tablespace*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       username || ' |' ||
 "       account_status || ' |' ||
 "       default_tablespace || ' |' ||
 "       temporary_tablespace || ' |'
 " FROM dba_users
 " WHERE username NOT IN (:1)
 "   AND (temporary_tablespace NOT IN (SELECT tablespace_name
 "                                      FROM dba_tablespaces
 "                                      WHERE contents = 'TEMPORARY')
 "    OR default_tablespace = 'SYSTEM')
 " ORDER BY account_status,default_tablespace,temporary_tablespace,username;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 if ${B_DBLINKS}
 {# Database link
  report chk_dblinks
  var $ttl = 'Database Link'
  var $hdr = '|*Link Owner*|*Name*|*Status*|'
  prefix
   call dsp_title($ttl,$hdr)
  if compare('valid',$DBVER,'102')
  {set $sql
   {SET termout off;
   "SET serveroutput on size 1000000
   "DECLARE
   " l_flg BOOLEAN;
   " l_suc BOOLEAN := TRUE;
   " l_cnt NUMBER;
   " l_cre VARCHAR2(4000);
   " l_del VARCHAR2(800);
   " l_sel VARCHAR2(800);
   " l_own user$.name%TYPE;
   "BEGIN
   " FOR c IN (SELECT *
   "            FROM link$
   "            WHERE userid IS NOT NULL
   "              AND passwordx IS NOT NULL)
   " LOOP
   "  BEGIN
   "   l_cre := 'CREATE DATABASE LINK ' || c.name ||
   "            ' CONNECT TO ' || c.userid ||
   "            ' IDENTIFIED BY VALUES '''|| c.passwordx ||'''';
   "   IF c.host IS NOT NULL
   "   THEN
   "    l_cre := l_cre || ' USING ''' || c.host || '''';
   "   END IF;
   "   EXECUTE IMMEDIATE l_cre;
   "   l_flg := TRUE;
   "   EXCEPTION
   "    WHEN OTHERS THEN
   "     l_flg := FALSE;
   "  END;
   "  BEGIN
   "   SELECT name INTO l_own
   "    FROM user$
   "    WHERE user# = c.owner#;
   "          l_sel := 'SELECT COUNT(*)
   "                    FROM tab@' || c.name;
   "   EXECUTE IMMEDIATE l_sel INTO l_cnt;
   "   dbms_output.put_line('|' || l_own || ' |' || c.name || ' |OK|');
   "   EXCEPTION
   "    WHEN OTHERS THEN
   "     dbms_output.put_line('|' || l_own || ' |' || c.name || ' |Error: ' ||
   "                     REPLACE(SUBSTR(sqlerrm,1,100),CHR(10),'%BR%') || '|');
   "     l_suc := FALSE;
   "  END;
   "  BEGIN
   "   IF l_suc
   "   THEN
   "    ROLLBACK;
   "    DBMS_SESSION.CLOSE_DATABASE_LINK(c.name);
   "   ELSE
   "    l_suc := TRUE;
   "   END IF;
   "   IF l_flg
   "   THEN
   "    l_del := 'DROP DATABASE LINK ' || c.name;
   "    EXECUTE IMMEDIATE l_del;
   "   END IF;
   "  END;
   " END LOOP;
   "END;
   "/
   }
  }
  else
  {set $sql
   {SET termout off;
   "SET serveroutput on size 1000000
   "DECLARE
   " l_flg BOOLEAN;
   " l_cnt NUMBER;
   " l_cre VARCHAR2(4000);
   " l_del VARCHAR2(800);
   " l_sel VARCHAR2(800);
   " l_own user$.name%TYPE;
   "BEGIN
   " FOR c IN (SELECT *
   "            FROM link$
   "            WHERE userid IS NOT NULL
   "              AND password IS NOT NULL)
   " LOOP
   "  BEGIN
   "   l_cre := 'CREATE DATABASE LINK ' || c.name ||
   "            ' CONNECT TO ' || c.userid ||
   "            ' IDENTIFIED BY ' || c.password;
   "   IF c.host IS NOT NULL
   "   THEN
   "    l_cre := l_cre || ' USING ''' || c.host || '''';
   "   END IF;
   "   EXECUTE IMMEDIATE l_cre;
   "   l_flg := TRUE;
   "   EXCEPTION
   "    WHEN OTHERS THEN
   "     l_flg := FALSE;
   "  END;
   "  BEGIN
   "   SELECT name INTO l_own
   "    FROM user$
   "    WHERE user# = c.owner#;
   "          l_sel := 'SELECT COUNT(*)
   "                    FROM tab@' || c.name;
   "   EXECUTE IMMEDIATE l_sel INTO l_cnt;
   "   dbms_output.put_line('|' || l_own || ' |' || c.name || ' |OK|');
   "   EXCEPTION
   "    WHEN OTHERS THEN
   "     dbms_output.put_line('|' || l_own || ' |' || c.name || ' |Error: ' ||
   "                     REPLACE(SUBSTR(sqlerrm,1,100),CHR(10),'%BR%') || '|');
   "  END;
   "  BEGIN
   "   IF l_flg
   "   THEN
   "    l_del := 'DROP DATABASE LINK ' || c.name;
   "    EXECUTE IMMEDIATE l_del;
   "   END IF;
   "  END;
   " END LOOP;
   "END;
   "/
   }
  }
  call wrt_report($sql,$ttl)
 }
}

# --- Tablespace Files --------------------------------------------------------

# Tablespace files
if isTocCreated(true)
 pretoc '%SPLIT%'
else
 pretoc $MNU
pretoc '1+:Tablespace Files'
debug ' Inside ADBA module, getting tablespace files'

if $ASSESS_ALL
{# Tablespace summary
 report tablespaces
 var $ttl = 'Tablespace Summary'
 if match($DBVER,'^81')
 {var $hdr = '|*Tablespace*| *Initial Extent*| *Next Extent*| *Min Extents*| \
               *Max Extents*| *Increase (%)*| *Min Extent*|*Status*|*Content*|\
               *Logging*|*Extent Management*|*Allocation Type*|*Plugged In*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       tablespace_name || ' | ' ||
  "       initial_extent || '| ' ||
  "       next_extent || '| ' ||
  "       min_extents || '| ' ||
  "       max_extents || '| ' ||
  "       pct_increase || '| ' ||
  "       min_extlen || '|' ||
  "       status || ' |' ||
  "       DECODE(contents,'PERMANENT','PERM','TEMPORARY','TEMP',
  "              CONTENTS) || ' |' ||
  "       DECODE(logging,'LOGGING','YES','NOLOGGING','NO',LOGGING) || ' |' ||
  "       DECODE(extent_management,'DICTIONARY','DICT',
  "              EXTENT_MANAGEMENT) || ' |' ||
  "       allocation_type || ' |' ||
  "       plugged_in || ' |'
  " FROM dba_tablespaces
  " ORDER BY tablespace_name;
  }
 }
 else
 {var $hdr = '|*Tablespace*| *Initial Extent*| *Next Extent*| *Min Extents*| \
               *Max Extents*| *Increase (%)*| *Min Extent*|*Status*|*Content*|\
               *Logging*|*Extent Management*|*Segment Space Management*| \
               *Block Size*|*Allocation Type*|*Plugged In*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       tablespace_name || ' | ' ||
  "       initial_extent || '| ' ||
  "       next_extent || '| ' ||
  "       min_extents || '| ' ||
  "       max_extents || '| ' ||
  "       pct_increase || '| ' ||
  "       min_extlen || '|' ||
  "       status || ' |' ||
  "       DECODE(contents,'PERMANENT','PERM','TEMPORARY','TEMP',
  "              CONTENTS) || ' |' ||
  "       DECODE(logging,'LOGGING','YES','NOLOGGING','NO',LOGGING) || ' |' ||
  "       DECODE(extent_management,'DICTIONARY','DICT',
  "              EXTENT_MANAGEMENT) || ' |' ||
  "       segment_space_management || ' | ' ||
  "       block_size || '|' ||
  "       allocation_type || ' |' ||
  "       plugged_in || ' |'
  " FROM dba_tablespaces
  " ORDER BY tablespace_name;
  }
 }
 call wrt_report($sql,$ttl)

 # Tablespace usage
 report tablespace_usage
 var $ttl = 'Tablespace Usage'
 var $hdr = '|*Tablespace*| *Size (MiB)*| *Used Space (MiB)*| \
              *Free Space (MiB)*| *Filled (%)*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       a.tablespace_name || ' | ' ||
 "       ROUND(a.bytes / 1048576,2) || '| ' ||
 "       ROUND((a.bytes-b.bytes) / 1048576,2) || '| ' ||
 "       ROUND(b.bytes / 1048576,2) || '| ' ||
 "       ROUND(((a.bytes-b.bytes)/a.bytes)*100,2) || '|'
 " FROM (SELECT tablespace_name,SUM(bytes) bytes
 "        FROM dba_data_files
 "        GROUP BY tablespace_name) a,
 "      (SELECT tablespace_name,SUM(bytes) bytes
 "        FROM dba_free_space
 "        GROUP BY tablespace_name) b
 " WHERE a.tablespace_name = b.tablespace_name
 " ORDER BY ((a.bytes-b.bytes)/a.bytes) DESC;
 }
 call wrt_report($sql,$ttl)

 # Tablespace free space and largest extent
 report tablespace_free_space
 var $ttl = 'Tablespace Free Space'
 var $hdr = '|*Tablespace*| *Free Space (B)*| *Largest Extent (B)*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       tablespace_name || ' | ' ||
 "       SUM(bytes) || '| ' ||
 "       MAX(bytes) || '| '
 " FROM dba_free_space
 " GROUP BY tablespace_name;
 }
 call wrt_report($sql,$ttl)

 # Datafiles
 report datafiles
 var $ttl = 'Datafiles'
 var $hdr = '|*File Name*|*Tablespace*| *File ID*| *Rel. Fileno*|*Status*| \
              *Size*| *Size (MiB)*|*Auto Ext.*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       file_name || ' |' ||
 "       tablespace_name || ' | ' ||
 "       file_id || '| ' ||
 "       relative_fno || '|' ||
 "       status || ' | ' ||
 "       bytes || '| ' ||
 "       TO_CHAR(bytes / 1048576,'999999999.99') || '| ' ||
 "       autoextensible || '|'
 " FROM dba_data_files;
 }
 call wrt_report($sql,$ttl)

 # Temporary datafiles
 report tempfiles
 var $ttl = 'Temporary Datafiles'
 var $hdr = '|*File Name*|*Tablespace*| *File ID*| *Rel. Fileno*|*Status*| \
              *Size*| *Size (MiB)*|*Auto Ext.*|'
 prefix
  call dsp_title($ttl,$hdr)

 set $sql
 {SELECT '|' ||
 "       file_name || ' |' ||
 "       tablespace_name || ' | ' ||
 "       file_id || '| ' ||
 "       relative_fno || '|' ||
 "       status || ' | ' ||
 "       bytes || '| ' ||
 "       TO_CHAR(bytes / 1048576,'999999999.99') || '| ' ||
 "       autoextensible || '|'
 " FROM dba_temp_files;
 }
 call wrt_report($sql,$ttl)

 # Tablespace TEMPORARY
 report temp_datafiles
 var $ttl = 'Tablespace TEMPORARY'
 var $hdr = '|*File Name*|*Tablespace*| *File ID*| *Rel. Fileno*|*Status*| \
              *Size*| *Size (MiB)*|*Auto Ext.*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       file_name || ' |' ||
 "       tablespace_name || ' | ' ||
 "       file_id || '| ' ||
 "       relative_fno || '|' ||
 "       status || ' | ' ||
 "       bytes || '| ' ||
 "       TO_CHAR(bytes / 1048576,'999999999.99') || '| ' ||
 "       autoextensible || '|'
 " FROM dba_data_files df
 " WHERE  EXISTS (SELECT 'X'
 "                 FROM dba_tablespaces dt
 "                 WHERE dt.tablespace_name = df.tablespace_name
 "                   AND dt.contents = 'TEMPORARY');
 }
 call wrt_report($sql,$ttl)

 # Autoextensible datafiles
 report autoextension
 var $ttl = 'Autoextensible Datafiles'
 var $hdr = '|*File Name*|*Tablespace*| *Size*|*Status*| *Max (B)*| \
              *Increment By*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       file_name || ' |' ||
 "       tablespace_name || ' | ' ||
 "       bytes || '| ' ||
 "       status || '|' ||
 "       maxbytes || ' | ' ||
 "       increment_by || '| '
 " FROM dba_data_files
 " WHERE  autoextensible = 'YES'
 " ORDER BY tablespace_name,file_name;
 }
 call wrt_report($sql,$ttl)

 # Logfiles
 report logfiles
 var $ttl = 'Log Files'
 var $hdr = '|*Member*| *Group*| *Thread*|*Sequence*| *Size*| *Size (MiB)*| \
              *Members*|*Archived*|*Status*| *First Change*|*First Time*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       a.member || ' | ' ||
 "       b.group# || '| ' ||
 "       b.thread# || '| ' ||
 "       b.sequence# || '| ' ||
 "       b.bytes || '| ' ||
 "       TO_CHAR(b.bytes / 1048576,'999999999.99') || '| ' ||
 "       b.members || '|' ||
 "       b.archived || ' |' ||
 "       b.status || ' | ' ||
 "       b.first_change# || '|' ||
 "       TO_CHAR(b.first_time,'DD-Mon-YYYY HH24:MI:SS') || ' |'
 " FROM sys.v_$logfile a,sys.v_$log b
 " WHERE a.group# = b.group#
 " ORDER BY a.member;
 }
 call wrt_report($sql,$ttl)

 # Controlfiles
 report controlfiles
 var $ttl = 'Control Files'
 var $hdr = '|*File name*|*Status*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       name || ' |' ||
 "       status || ' |'
 " FROM v$controlfile;
 }
 call wrt_report($sql,$ttl)
}

# Rollback segments
report rollback_segments
var $ttl = 'Rollback Segments'
var $hdr = '|*Segment*|*Owner*|*Tablespace*| *Segment ID*| *File ID*| \
             *Block ID*| *Initial Extent*| *Next Extent*| *Min Extents*| \
             *Max Extents*| *Increase (%)*|*Status*| *Instance*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       segment_name || ' |' ||
"       owner || ' |' ||
"       tablespace_name || ' | ' ||
"       segment_id || '| ' ||
"       file_id || '| ' ||
"       block_id || '| ' ||
"       DECODE(SIGN(initial_extent-524288),1,
"              TO_CHAR(initial_extent / 1048576) || ' MiB',
"              TO_CHAR(initial_extent) || ' B') || '| ' ||
"       DECODE(SIGN(next_extent-524288),1,
"              TO_CHAR(next_extent / 1048576) || ' MiB',
"              TO_CHAR(next_extent) ||' B') || '| ' ||
"       min_extents || '| ' ||
"       max_extents || '| ' ||
"       pct_increase || '|' ||
"       status || ' | ' ||
"       instance_num || '|'
" FROM dba_rollback_segs
" WHERE owner NOT IN (:1)
" ORDER BY segment_name;
}
call wrt_report(bindSql($sql,$STD_USR),$ttl)

# Rollback segment usage
report rollback_segments_usage
var $ttl = 'Rollback Segment Usage'
var $hdr = '|*Name*| *Number*| *Gets*| *Waits*| *Successful Gets (%)*| \
             *Transactions*| *Writes*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       b.name || ' | ' ||
"       a.usn || '| ' ||
"       gets || '| ' ||
"       waits || '| ' ||
"       ROUND(((gets-waits)*100)/gets,2) || '| ' ||
"       xacts || '| ' ||
"       writes || '|'
" FROM sys.v_$rollstat a,sys.v_$rollname b
" WHERE a.usn = b.usn;
}
call wrt_report($sql,$ttl)

# Rollback growth
report rollback_growth
var $ttl = 'Rollback Growth'
var $hdr = '|*Segment*| *Segment Nr*| *Size*| *Optimal Size*| \
             *Highwater Mark*| *Extents*| *Wraps*| *Shrinks*| *Avg Shrink*| \
             *Avg Active*|*Status*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       name || ' | ' ||
"       a.usn || '| ' ||
"       rssize || '| ' ||
"       optsize || '| ' ||
"       hwmsize || '| ' ||
"       extends || '| ' ||
"       wraps || '| ' ||
"       shrinks || '| ' ||
"       aveshrink || '| ' ||
"       aveactive || '|' ||
"       status || ' |'
" FROM sys.v_$rollstat a,sys.v_$rollname b
" WHERE a.usn = b.usn
" ORDER BY name;
}
call wrt_report($sql,$ttl)

# --- Processes ---------------------------------------------------------------

if isTocCreated(true)
 pretoc '%SPLIT%'
else
 pretoc $MNU
pretoc '1+:Processes'
debug ' Inside ADBA module, getting process information'

# Processes
report processes
var $ttl = 'Background Processes'
var $hdr = '| *Sid*|*Process*| *OS Pid*|*Description*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '| ' ||
"       s.sid || '|' ||
"       b.name || ' | ' ||
"       p.spid || '|' ||
"       b.description || ' |'
" FROM v$session s,v$bgprocess b,v$process p
" WHERE s.paddr = b.paddr
"   AND s.paddr = p.addr
" ORDER BY sid;
}
call wrt_report($sql,$ttl)

# --- User related ------------------------------------------------------------

if isTocCreated(true)
 pretoc '%SPLIT%'
else
 pretoc $MNU
pretoc '1+:User Related'
debug ' Inside ADBA module, getting user related information'

# User sessions
report user_sessions
var $ttl = 'User Sessions'
var $hdr = '|*User Name*|*Program*|*Server*| *Sessions*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       NVL(username,'background') || ' |' ||
"       program || ' | ' ||
"       server || '| ' ||
"       COUNT(*) || '|'
" FROM sys.v_$session
" WHERE type = 'USER'
"   AND program not like '%QMN%'
"   AND program not like '%CJQ%'
" GROUP BY username,program,server
" ORDER BY COUNT(*) DESC;
}
call wrt_report($sql,$ttl)

if $ASSESS_ALL
{# User default tablespaces
 report user_default_tablespaces
 var $ttl = 'User Default Tablespaces'
 var $hdr = '|*User*|*Status*|*Default Tablespace*| *Temp Tablespace*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       username || ' |' ||
 "       account_status || ' |' ||
 "       default_tablespace || ' |' ||
 "       temporary_tablespace || ' |'
 " FROM dba_users
 " WHERE username NOT IN (:1)
 "   AND (temporary_tablespace NOT IN (SELECT tablespace_name
 "                                      FROM dba_tablespaces
 "                                      WHERE contents = 'TEMPORARY')
 "    OR default_tablespace = 'SYSTEM')
 " ORDER BY account_status,default_tablespace,temporary_tablespace,username;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # User object overview
 report user_object_overview
 var $ttl = 'User Object Overview'
 var $hdr = '|*User*| *Tables*| *Indexes*| *Synonyms*| *Views*| *Sequences*| \
              *Procedures*| *Functions*| *Packages*| *Triggers*| *Nonexistant*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       username || ' | ' ||
 "       COUNT(DECODE(o.type#,2,o.obj#,'')) || '| ' ||
 "       COUNT(DECODE(o.type#,1,o.obj#,'')) || '| ' ||
 "       COUNT(DECODE(o.type#,5,o.obj#,'')) || '| ' ||
 "       COUNT(DECODE(o.type#,4,o.obj#,'')) || '| ' ||
 "       COUNT(DECODE(o.type#,6,o.obj#,'')) || '| ' ||
 "       COUNT(DECODE(o.type#,7,o.obj#,'')) || '| ' ||
 "       COUNT(DECODE(o.type#,8,o.obj#,'')) || '| ' ||
 "       COUNT(DECODE(o.type#,9,o.obj#,'')) || '| ' ||
 "       COUNT(DECODE(o.type#,12,o.obj#,'')) || '| ' ||
 "       COUNT(DECODE(o.type#,10,o.obj#,'')) || '|'
 " FROM sys.obj$ o,dba_users u
 " WHERE u.username NOT IN (:1)
 "   AND u.user_id = o.owner# (+)
 "   AND o.type# is NOT NULL
 " GROUP BY username
 " ORDER BY username;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # User space allocated
 report user_space_allocated
 var $ttl = 'User Space Allocated'
 var $hdr = '|*Owner*|*Segment Type*| *Total (MiB)*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       segment_type || ' | ' ||
 "       ROUND(SUM(bytes) / 1048576,2) || '|'
 " FROM dba_segments
 " WHERE owner NOT IN (:1)
 " GROUP BY owner,segment_type;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # User tablespace quotas
 report user_tablespace_quotas
 var $ttl = 'User Tablespace Quotas'
 var $hdr = '|*Tablespace*|*User*| *Size*| *Max size*| *Blocks*| *Max blocks*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       tablespace_name || ' |' ||
 "       username || ' | ' ||
 "       bytes || '| ' ||
 "       max_bytes || '| ' ||
 "       blocks || '| ' ||
 "       max_blocks || '|'
 " FROM dba_ts_quotas
 " WHERE username NOT IN (:1)
 " ORDER BY tablespace_name,username;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Users with many privileges
 report user_privs
 var $ttl = 'Users with Many Privileges'
 var $hdr = '|*User*|*Privilege*|*Admin Option*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       dummy.usr || ' |' ||
 "       dummy.prv || ' |' ||
 "       dummy.adm || ' |'
 " FROM (SELECT grantee      usr,
 "              granted_role prv,
 "              admin_option adm
 "        FROM dba_role_privs
 "        WHERE granted_role = 'DBA'
 "       UNION
 "       SELECT Grantee      usr,
 "              privilege    prv,
 "              admin_option adm
 "        FROM dba_sys_privs
 "        WHERE privilege IN ('GRANT ANY PRIVILEGE','GRANT ANY ROLE')
 "          AND grantee <> 'DBA'
 "       UNION
 "       SELECT username usr,
 "              DECODE(sysdba||sysoper,'TRUETRUE','SYSDBA,SYSOPER',
 "                                     'TRUEFALSE','SYSDBA',
 "                                     'FALSETRUE','SYSOPER',
 "                                     'FALSEFALSE','n/a') prv,
 "              'NO' adm
 "        FROM v$pwfile_users) dummy
 " ORDER BY dummy.usr;
 }
 call wrt_report($sql,$ttl)
}

# --- Redo Log ----------------------------------------------------------------

if isTocCreated(true)
 pretoc '%SPLIT%'
else
 pretoc $MNU
pretoc '1+:Redo Log'
debug ' Inside ADBA module, getting redo log information'

# Redo log switch history
report redo_log_history
var $ttl = 'Redo Log History'
var $hdr = '|*Day*| *00*| *01*| *02*| *03*| *04*| *05*| *06*| *07*| *08*| \
             *09*| *10*| *11*| *12*| *13*| *14*| *15*| *16*| *17*| *18*| *19*| \
             *20*| *21*| *22*| *23*| *Per Day*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       SUBSTR(TO_CHAR(first_time,'YYYY/MM/DD'),1,10) || ' | ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'00',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '00',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'01',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '01',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'02',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '02',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'03',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '03',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'04',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '04',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'05',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '05',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'06',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '06',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'07',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '07',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'08',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '08',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'09',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '09',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'10',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '10',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'11',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '11',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'12',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '12',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'13',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '13',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'14',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '14',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'15',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '15',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'16',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '16',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'17',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '17',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'18',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '18',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'19',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '19',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'20',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '20',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'21',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '21',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'22',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '22',1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'23',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),
"              '23',1,0))) || '| ' ||
"       DECODE(SUM(1),0,'-',SUM(1)) || '|'
" FROM v$log_history
" WHERE thread# = SYS_CONTEXT('USERENV','INSTANCE')
" GROUP BY SUBSTR(TO_CHAR(first_time,'YYYY/MM/DD'),1,10)
" ORDER BY SUBSTR(TO_CHAR(first_time,'YYYY/MM/DD'),1,10) DESC;
}
call wrt_report($sql,$ttl)

# Redo log doc
report redo_log_history_recent
var $ttl = 'Recent Redo Log History'
var $hdr = '|*Day*| *00*| *01*| *02*| *03*| *04*| *05*| *06*| *07*| *08*| \
             *09*| *10*| *11*| *12*| *13*| *14*| *15*| *16*| *17*| *18*| *19*| \
             *20*| *21*| *22*| *23*| *Per Day*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       SUBSTR(TO_CHAR(first_time,'YYYY/MM/DD'),1,10) || ' | ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'00',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'00',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'01',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'01',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'02',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'02',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'03',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'03',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'04',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'04',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'05',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'05',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'06',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'06',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'07',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'07',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'08',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'08',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'09',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'09',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'10',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'10',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'11',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'11',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'12',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'12',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'13',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'13',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'14',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'14',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'15',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'15',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'16',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'16',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'17',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'17',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'18',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'18',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'19',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'19',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'20',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'20',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'21',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'21',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'22',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'22',
"              1,0))) || '| ' ||
"       DECODE(SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'23',1,0)),
"              0,'-',SUM(DECODE(SUBSTR(TO_CHAR(first_time,'HH24'),1,2),'23',
"              1,0))) || '| ' ||
"       DECODE(SUM(1),0,'-',SUM(1)) || '|'
" FROM v$log_history
" WHERE first_time > SYSDATE - 45
"   AND thread# = SYS_CONTEXT('USERENV','INSTANCE')
" GROUP BY SUBSTR(TO_CHAR(first_time,'YYYY/MM/DD'),1,10)
" ORDER BY SUBSTR(TO_CHAR(first_time,'YYYY/MM/DD'),1,10) DESC;
}
call wrt_report($sql,$ttl)

# Logswitches last week
report logsw_last_week
var $ttl = 'Log Switches Last Week'
var $hdr = '| *Logswitch&nbsp;&lt;&nbsp;2 Min*| *Between 2 and 5 Min*| \
              *Between 6 and 15 Min*| *Between 16 and 30 Min*| \
              *Between 31 and 60 Min*| *Logswitch&nbsp;&gt;&nbsp;60 Min*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '| ' ||
"       SUM(CASE WHEN ROUND((lh2.first_time - lh1.first_time) * 1440) < 2
"           THEN 1 ELSE 0 END) || '| ' ||
"       SUM(CASE WHEN ROUND((lh2.first_time - lh1.first_time) * 1440)
"           BETWEEN 2 AND 5 THEN 1 ELSE 0 END) || '| ' ||
"       SUM(CASE WHEN ROUND((lh2.first_time - lh1.first_time) * 1440)
"           BETWEEN 6 AND 15 THEN 1 ELSE 0 END) || '| ' ||
"       SUM(CASE WHEN ROUND((lh2.first_time - lh1.first_time) * 1440)
"           BETWEEN 16 AND 30 THEN 1 ELSE 0 END) || '| ' ||
"       SUM(CASE WHEN ROUND((lh2.first_time - lh1.first_time) * 1440)
"           BETWEEN 31 AND 60 THEN 1 ELSE 0 END) || '| ' ||
"       SUM(CASE WHEN ROUND((lh2.first_time - lh1.first_time) * 1440) > 60
"           THEN 1 ELSE 0 END) || '|'
" FROM v$log_history lh1,v$log_history lh2
" WHERE lh1.sequence# + 1 = lh2.sequence#
"   AND lh1.sequence# < (SELECT MAX(sequence#)
"                         FROM v$log_history)
"   AND lh1.first_time > SYSDATE - 7
"   AND lh1.thread# = SYS_CONTEXT('USERENV','INSTANCE')
"   AND lh1.thread# = lh2.thread#;
}
call wrt_report($sql,$ttl)

# Check Point interval (minutes)

report checkpoint_interval
var $ttl = 'Check Point Interval'
var $hdr = '| *Minimum*| *Maximum*| *Average*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '| ' ||
"       ROUND(MIN(lh2.first_time - lh1.first_time) * 1440,2) || '| ' ||
"       ROUND(MAX(lh2.first_time - lh1.first_time) * 1440,2) || '| ' ||
"       ROUND(AVG(lh2.first_time - lh1.first_time) * 1440,2) || '| '
" FROM v$log_history lh1,v$log_history lh2
" WHERE lh1.sequence# + 1 = lh2.sequence#
"   AND lh1.sequence# < (SELECT MAX(sequence#)
"                         FROM v$log_history)
"   AND lh1.thread# = SYS_CONTEXT('USERENV','INSTANCE')
"   AND lh1.thread# = lh2.thread#;
}
call wrt_report($sql,$ttl)

# Undo statistics
if compare('valid',$DBVER,'90')
{report undo_stats
 var $ttl = 'Undo Statistics'
 var $hdr = '|*Begin Time*|*End Time*| *Undo  Blocks  Consumed*| \
              *Transactions*| *Longest Query (Sec.)*| \
              *Max Concurrent Transactions*| *Unexpired Stealing Count*| \
              *Unexpired Blocks Removed*| *Unexpired Blocks Reused*| \
              *Errors*| *Errors In Instance*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       TO_CHAR(begin_time,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
 "       TO_CHAR(end_time,'DD-Mon-YYYY HH24:MI:SS') || ' | ' ||
 "       undoblks || '| ' ||
 "       txncount || '| ' ||
 "       maxquerylen || '| ' ||
 "       maxconcurrency || '| ' ||
 "       unxpstealcnt || '| ' ||
 "       unxpblkrelcnt || '| ' ||
 "       unxpblkreucnt || '| ' ||
 "       ssolderrcnt || '| ' ||
 "       nospaceerrcnt || '|'
 " FROM v$undostat
 " WHERE unxpstealcnt > 0
 "    OR unxpblkrelcnt > 0
 "    OR unxpblkreucnt > 0
 "    OR ssolderrcnt > 0
 "    OR nospaceerrcnt > 0
 " ORDER BY 1;
 }
 call wrt_report($sql,$ttl)
}

# --- Memory ------------------------------------------------------------------

if isTocCreated(true)
 pretoc '%SPLIT%'
else
 pretoc $MNU
pretoc '1+:Memory'
debug ' Inside ADBA module, getting memory information'

# Memory initialization parameters
report memparams
var $ttl = 'Memory Initialization Parameters'
var $hdr = '|*Parameter Name*| *Size*|'
prefix
 call dsp_title($ttl,$hdr)
if match($DBVER,'^81')
{set $sql
 {SELECT '|' ||
 "       name || ' | ' ||
 "       value || '|'
 " FROM v$parameter
 " WHERE LOWER(name) IN ('shared_pool_size','shared_pool_reserved_size',
 "                       'large_pool_size','java_pool_size','sort_area_size',
 "                       'sort_area_retained_size','bitmap_merge_area_size',
 "                       'hash_area_size','db_block_size','db_block_buffers');
 }
}
else
{set $sql
 {SELECT '|' ||
 "       name || ' | ' ||
 "       value || '|'
 " FROM v$parameter
 " WHERE LOWER(name) IN ('sga_max_size','shared_pool_size',
 "                       'shared_pool_reserved_size','large_pool_size',
 "                       'java_pool_size','sort_area_size',
 "                       'sort_area_retained_size','bitmap_merge_area_size',
 "                       'hash_area_size','db_block_size','db_block_buffers',
 "                       'db_cache_size','db_2k_cache_size','db_4k_cache_size',
 "                       'db_8k_cache_size','db_16k_cache_size',
 "                       'db_32k_cache_size','db_keep_cache_size',
 "                       'db_recycle_cache_size');
 }
}
call wrt_report($sql,$ttl)

# Shared pool chunks on LRU list
report shared_pool
var $ttl = 'Shared Pool Chunks on LRU List'
if match($DBVER,'^81')
{var $hdr = '| *Recurrent*| *Transient Chunks*| *Flushed Chunks*| \
               *Changes to LRU List*| *ORA&ndash;4031 Errors*| \
               *Last Error Size*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT 'spl=' || '| ' ||
 "       kghlurcr || '| ' ||
 "       kghlutrn || '| ' ||
 "       kghlufsh || '| ' ||
 "       kghluops || '| ' ||
 "       kghlunfu || '| ' ||
 "       kghlunfs || '|'
 " FROM x$kghlu
 " WHERE inst_id = USERENV('Instance');
 }
}
else
{var $hdr = '| *Subheap*| *Recurrent*| *Transient Chunks*| *Flushed Chunks*| \
               *Changes to LRU List*| *ORA-4031 Errors*| *Last Error Size*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT 'spl=' || '| ' ||
 "       kghluidx || '| ' ||
 "       kghlurcr || '| ' ||
 "       kghlutrn || '| ' ||
 "       kghlufsh || '| ' ||
 "       kghluops || '| ' ||
 "       kghlunfu || '| ' ||
 "       kghlunfs || '|'
 " FROM x$kghlu
 " WHERE inst_id = USERENV('Instance')
 " ORDER BY kghluidx;
 }
}
loop $lin (grepSql($sql,'^spl='))
 write value($lin)
if isCreated(true)
{write $TOP
 toc '2:[[',getFile(),'][rda_report][',$ttl,']]'
}

# Reserved pool
report reserved_pool
var $ttl = 'Reserved Pool'
var $hdr = '| *Total*| *Free*| *Used*| *Requests*| *Request Failures*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '| ' ||
"       (free_space+used_space) || '| ' ||
"       free_space || '| ' ||
"       used_space || '| ' ||
"       requests || '| ' ||
"       request_failures || '|'
" FROM v$shared_pool_reserved;
}
call wrt_report($sql,$ttl)

# SGA allocation
report sga
var $ttl = 'SGA'
var $hdr = '|*Region*| *Size*| *Size (MiB)*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|SGA Total| ' ||
"       SUM(value) || '| ' ||
"       TO_CHAR(SUM(value) / 1048576,'999999999.99') || '|'
" FROM v$sga
"UNION
"SELECT '|' ||
"       name || ' | ' ||
"       value || '| ' ||
"       TO_CHAR(value / 1048576,'999999999.99') || '|'
" FROM v$sga;
}
call wrt_report($sql,$ttl)

# --- Performance -------------------------------------------------------------

if isTocCreated(true)
 pretoc '%SPLIT%'
else
 pretoc $MNU
pretoc '1+:Performance'
debug ' Inside ADBA module, getting performance information'

# Top 10 latches
report latches

var $ttl = 'Top 10 Latches'
var $hdr = '|*Latch*| *Gets*| *Misses*| *Sleeps*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT *
" FROM (SELECT '|' ||
"              name || ' | ' ||
"              gets || '| ' ||
"              misses || '| ' ||
"              sleeps || '|'
"        FROM v$latch
"        WHERE misses > 0 OR sleeps > 0
"        ORDER BY sleeps DESC)
" WHERE ROWNUM < 11;
}
call wrt_report($sql,$ttl)

# Non Idle wait events
report no_idle_waits
var $ttl = 'Non Idle Wait Events'
var $hdr = '|*Major*|*Minor*|*Wait Event*| *Seconds*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       SUBSTR(dummy.n_major,3) || ' |' ||
"       SUBSTR(dummy.n_minor,3) || ' |' ||
"       dummy.wait_event || ' | ' ||
"       ROUND(dummy.time / 100,2) || '|'
" FROM (SELECT stat_num,
"              DECODE(n_minor,
"                     '1 normal I/O','2 disk I/O',
"                     '2 full scans','2 disk I/O',
"                     '3 direct I/O','2 disk I/O',
"                     '4 BFILE reads','2 disk I/O',
"                     '5 other I/O','2 disk I/O',
"                     '1 DBWn writes','3 waits',
"                     '2 LGWR writes','3 waits',
"                     '3 ARCn writes','3 waits',
"                     '4 enqueue locks','3 waits',
"                     '5 PCM locks','3 waits',
"                     '6 other locks','3 waits',
"                     '1 commits','4 latency',
"                     '2 network','4 latency',
"                     '3 file ops','4 latency',
"                     '4 process ctl','4 latency',
"                     '5 global locks','4 latency',
"                     '6 misc','4 latency') n_major,
"              n_minor,
"              wait_event,
"              time
"        FROM (SELECT n.event# stat_num,
"                     DECODE(e.event,
"                            'db file sequential read','1 normal I/O',
"                            'db file scattered read','2 full scans',
"                            'BFILE read','4 BFILE reads',
"                            'KOLF: Register LFI read','4 BFILE reads',
"                            'log file sequential read','5 other I/O',
"                            'log file single write','5 other I/O',
"                            'checkpoint completed','1 DBWn writes',
"                            'free buffer waits','1 DBWn writes',
"                            'write complete waits','1 DBWn writes',
"                            'local write wait','1 DBWn writes',
"                            'log file switch (checkpoint incomplete)',
"                              '1 DBWn writes',
"                            'rdbms ipc reply','1 DBWn writes',
"                            'log file switch (archiving needed)',
"                              '3 ARCn writes',
"                            'enqueue','4 enqueue locks',
"                            'buffer busy due to global cache','5 PCM locks',
"                            'global cache cr request','5 PCM locks',
"                            'global cache lock cleanup','5 PCM locks',
"                            'global cache lock null to s','5 PCM locks',
"                            'global cache lock null to x','5 PCM locks',
"                            'global cache lock s to x','5 PCM locks',
"                            'lock element cleanup','5 PCM locks',
"                            'checkpoint range buffer not saved',
"                              '6 other locks',
"                            'dupl. cluster key','6 other locks',
"                            'PX Deq Credit: free buffer','6 other locks',
"                            'PX Deq Credit: need buffer','6 other locks',
"                            'PX Deq Credit: send blkd','6 other locks',
"                            'PX qref latch','6 other locks',
"                            'Wait for credit - free buffer','6 other locks',
"                            'Wait for credit - need buffer to send',
"                              '6 other locks',
"                            'Wait for credit - send blocked','6 other locks',
"                            'global cache freelist wait','6 other locks',
"                            'global cache lock busy','6 other locks',
"                            'index block split','6 other locks',
"                            'lock element waits','6 other locks',
"                            'parallel query qref latch','6 other locks',
"                            'pipe put','6 other locks',
"                            'rdbms ipc message block','6 other locks',
"                            'row cache lock','6 other locks',
"                            'sort segment request','6 other locks',
"                            'transaction','6 other locks',
"                            'unbound tx','6 other locks',
"                            'log file sync','1 commits',
"                            'name-service call wait','2 network',
"                            'Test if message present','4 process ctl',
"                            'process startup','4 process ctl',
"                            'read SCN lock','5 global locks',
"                     DECODE(SUBSTR(e.event,1,INSTR(e.event,' ')),
"                            'direct ','3 direct I/O',
"                            'control ','5 other I/O',
"                            'db ','5 other I/O',
"                            'log ','2 LGWR writes',
"                            'buffer ','6 other locks',
"                            'free ','6 other locks',
"                            'latch ','6 other locks',
"                            'library ','6 other locks',
"                            'undo ','6 other locks',
"                            'SQL*Net ','2 network',
"                            'BFILE ','3 file ops',
"                            'KOLF: ','3 file ops',
"                            'file ','3 file ops',
"                            'KXFQ: ','4 process ctl',
"                            'KXFX: ','4 process ctl',
"                            'PX ','4 process ctl',
"                            'Wait ','4 process ctl',
"                            'inactive ','4 process ctl',
"                            'multiple ','4 process ctl',
"                            'parallel ','4 process ctl',
"                            'DFS ','5 global locks',
"                            'batched ','5 global locks',
"                            'on-going ','5 global locks',
"                            'global ','5 global locks',
"                            'wait ','5 global locks',
"                            'writes ','5 global locks',
"                            '6 misc'))  n_minor,
"                     e.event  wait_event,
"                     e.time_waited   time
"               FROM  sys.v_$system_event e,sys.v_$event_name n
"               WHERE n.name = e.event
"                 AND e.time_waited > 0
"                 AND e.event NOT IN (
"                       'Null event',
"                       'pmon timer',
"                       'smon timer',
"                       'rdbms ipc reply',
"                       'KXFQ: Dequeue Range Keys - Slave',
"                       'KXFQ: Dequeuing samples',
"                       'KXFQ: kxfqdeq - dequeue from specific qref',
"                       'KXFQ: kxfqdeq - normal deqeue',
"                       'KXFX: Execution Message Dequeue - Slave',
"                       'KXFX: Parse Reply Dequeue - Query Coord',
"                       'KXFX: Reply Message Dequeue - Query Coord',
"                       'PAR RECOV : Dequeue msg - Slave',
"                       'PAR RECOV : Wait for reply - Query Coord',
"                       'Parallel Query Idle Wait - Slaves',
"                       'PL/SQL lock timer',
"                       'PX Deq: Execute Reply',
"                       'PX Deq: Execution Msg',
"                       'PX Deq: Index Merge Execute',
"                       'PX Deq: Index Merge Reply',
"                       'PX Deq: Par Recov Change Vector',
"                       'PX Deq: Par Recov Execute',
"                       'PX Deq: Par Recov Reply',
"                       'PX Deq: Parse Reply',
"                       'PX Deq: Table Q Get Keys',
"                       'PX Deq: Table Q Normal',
"                       'PX Deq: Table Q Sample',
"                       'PX Deq: Table Q qref',
"                       'PX Deq: Txn Recovery Reply',
"                       'PX Deq: Txn Recovery Start',
"                       'PX Deque wait',
"                       'PX Idle Wait',
"                       'Replication Dequeue',
"                       'Replication Dequeue ',
"                       'SQL*Net message from client',
"                       'SQL*Net message from dblink',
"                       'debugger command',
"                       'dispatcher timer',
"                       'parallel query dequeue wait',
"                       'pipe get',
"                       'queue messages',
"                       'rdbms ipc message',
"                       'secondary event',
"                       'single-task message',
"                       'slave wait',
"                       'lock manager wait for remote message',
"                       'wakeup time manager',
"                       'virtual circuit status',
"                       'control file heartbeat')
"                 AND e.event NOT LIKE 'resmgr:%')) dummy
" ORDER BY dummy.time DESC;
}
call wrt_report($sql,$ttl)

# Non shared SQL
report non_shared_sql
var $ttl = 'Non Shared SQL'
var $hdr = '|*SQL*| *Count in Cache*| *Memory Usage (MiB)*| *Total Executions*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       SUBSTR(sql_text,1,40) || ' | ' ||
"       COUNT(*) || '| ' ||
"       ROUND(SUM(sharable_mem) / 1048576,2) || '| ' ||
"       SUM(executions) || '|'
" FROM v$sqlarea
" WHERE executions < 5
"   AND sql_text NOT LIKE '%||%'
" GROUP BY SUBSTR(sql_text,1,40)
" HAVING COUNT(*) > 10
" ORDER BY SUM(sharable_mem) DESC;
}
call wrt_report($sql,$ttl)

# SQL with version_count > 10
report high_version_count
var $ttl = 'SQL with High Version Count'
var $hdr = '| *Sharable Mem*| *Persisitent Mem*| *Runtime Mem*| \
              *Version Count*| *Executions*|*Sql*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SET linesize 32766
"SELECT '| ' ||
"       sharable_mem || '| ' ||
"       persistent_mem || '| ' ||
"       runtime_mem || '| ' ||
"       version_count || '| ' ||
"       executions || '|' ||
"       sql_text || ' |'
" FROM v$sqlarea
" WHERE version_count > 10
" ORDER BY version_count;
}
call wrt_report($sql,$ttl)

# Library cache details
report library_cache
var $ttl = 'Library Cache'
var $hdr = '|*Namespace*| *Gets*| *Get Hit Ratio*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       namespace || ' | ' ||
"       gets || '| ' ||
"       TO_CHAR(gethitratio,'999.99') || '|'
" FROM v$librarycache;
}
call wrt_report($sql,$ttl)

# Library cache miss rate
report library_cache_miss_rate
var $ttl = 'Library Cache Miss Rate'
var $hdr = '| *Executions*| *Cache Misses While Execution*| *Misses (%)*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '| ' ||
"       SUM(pins) || '| ' ||
"       SUM(reloads) || '| ' ||
"       TO_CHAR(SUM(reloads)/SUM(pins)*100,'999.99') || '|'
" FROM v$librarycache;
}
call wrt_report($sql,$ttl)

# --- Advanced Queuing --------------------------------------------------------

if $ASSESS_ALL
{if isTocCreated(true)
  pretoc '%SPLIT%'
 else
  pretoc $MNU
 pretoc '1+:Advanced Queuing'
 debug ' Inside ADBA module, getting advanced queuing information'

 # Queue tables
 report queue_tables
 var $ttl = 'Queue Tables'
 var $hdr = '|*Schema*|*Queue Table*| *Compatible*|*Type*|*Object Type*|\
              *Sort order*|*Comment*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       queue_table || ' | ' ||
 "       compatible || '|' ||
 "       type || ' |' ||
 "       object_type || ' |' ||
 "       sort_order || ' |' ||
 "       user_comment || ' |'
 " FROM dba_queue_tables
 " WHERE owner NOT IN (:1)
 " ORDER BY owner,queue_table;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Queue tables with more than 1 queues
 report multiqueue_tables
 var $ttl = 'Multiqueue Tables'
 var $hdr = '|*Schema*|*Queue Table*| *Number of Queues*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       name || ' |' ||
 "       queue_table || ' | ' ||
 "       COUNT(name) || '|'
 " FROM dba_queues
 " GROUP BY name,queue_table
 " HAVING COUNT(name) > 1;
 }
 call wrt_report($sql,$ttl)

 # Queue Tables with compatible < 8.1
 report old_queue_tables
 var $ttl = 'Old Queue Tables'
 var $hdr = '|*Schema*|*Queue Table*|*Compatible*|*Type*|*Object Type*|\
              *Sort order*|*Comment*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       queue_table || ' |' ||
 "       compatible || ' |' ||
 "       type || ' |' ||
 "       object_type || ' |' ||
 "       sort_order || ' |' ||
 "       user_comment || ' |'
 " FROM dba_queue_tables
 " WHERE TO_NUMBER(TRANSLATE(compatible,'.','0')) < 80100
 "   AND owner NOT IN (:1)
 " ORDER BY owner,queue_table;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # List of queues
 report queues
 var $ttl = 'Queues'
 var $hdr = '|*Owner*|*Queue*|*Type*| *Max Retries*| *Retry Delay*|*EnQ*|\
              *DeQ*| *Retention*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       name || ' |' ||
 "       queue_type || ' | ' ||
 "       max_retries || '| ' ||
 "       retry_delay || '|' ||
 "       enqueue_enabled || ' |' ||
 "       dequeue_enabled || ' | ' ||
 "       retention || '|'
 " FROM dba_queues
 " WHERE owner NOT IN (:1)
 " ORDER BY owner,name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Propagation schedules without errors
 report propagation_without_errors
 var $ttl = 'Propagation Schedules without Errors'
 if compare('valid',$DBVER,'100')
 {var $hdr = '|*Schema*|*Process*|*Start Date*|*Start Time*|*Next Run Time*|\
               *Queue Name*|*Destination*| *Latency*|*Next Time*| \
               *Propagation Window*|*Message Deliver Mode*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       schema || ' |' ||
  "       process_name || ' |' ||
  "       start_date || ' |' ||
  "       start_time || ' |' ||
  "       next_run_time || ' |' ||
  "       qname || ' |' ||
  "       destination || ' | ' ||
  "       latency || '|' ||
  "       next_time || ' | ' ||
  "       propagation_window || '|' ||
  "       message_delivery_mode || ' |'
  " FROM dba_queue_schedules
  " WHERE last_error_msg IS NULL
  " ORDER BY schema,qname;
  }
 }
 else
 {var $hdr = '|*Schema*|*Process*|*Start Date*|*Start Time*|*Next Run Time*|\
               *Queue Name*|*Destination*| *Latency*|*Next Time*| \
               *Propagation Window*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       schema || ' |' ||
  "       process_name || ' |' ||
  "       start_date || ' |' ||
  "       start_time || ' |' ||
  "       next_run_time || ' |' ||
  "       qname || ' |' ||
  "       destination || ' | ' ||
  "       latency || '|' ||
  "       next_time || ' | ' ||
  "       propagation_window || '|'
  " FROM dba_queue_schedules
  " WHERE last_error_msg IS NULL
  " ORDER BY schema,qname;
  }
 }
 call wrt_report($sql,$ttl)

 # Propagation schedules with errors
 report propagation_with_errors
 var $ttl = 'Propagation Schedules with Errors'
 if compare('valid',$DBVER,'100')
 {var $hdr = '|*Schema*|*Queue*|*Destination*|*Last Error Date*|\
               *Last Error Time*|*Error*|*Message Deliver Mode*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       schema || ' |' ||
  "       qname || ' |' ||
  "       destination || ' |' ||
  "       last_error_date || ' |' ||
  "       last_error_time || ' |' ||
  "       last_error_msg || ' |' ||
  "       message_delivery_mode || ' |'
  " FROM dba_queue_schedules
  " WHERE last_error_msg IS NOT NULL
  " ORDER BY schema,qname;
  }
 }
 else
 {var $hdr = '|*Schema*|*Queue*|*Destination*|*Last Error Date*|\
               *Last Error Time*|*Error*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       schema || ' |' ||
  "       qname || ' |' ||
  "       destination || ' |' ||
  "       last_error_date || ' |' ||
  "       last_error_time || ' |' ||
  "       last_error_msg || ' |'
  " FROM dba_queue_schedules
  " WHERE last_error_msg IS NOT NULL
  " ORDER BY schema,qname;
  }
 }
 call wrt_report($sql,$ttl)

 # UDT with the same name in different Schemas
 report udt_in_different_schema
 var $ttl = 'UDT in Different Schemas'
 var $hdr = '|*Type*| *Number of Schemas*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       type_name || ' | ' ||
 "       COUNT(*) || '|'
 " FROM dba_types
 " GROUP BY type_name
 " HAVING COUNT(*) > 1;
 }
 call wrt_report($sql,$ttl)
}

# --- Network -----------------------------------------------------------------

if $ASSESS_ALL
{if isTocCreated(true)
  pretoc '%SPLIT%'
 else
  pretoc $MNU
 pretoc '1+:Network'
 debug ' Inside ADBA module, getting network information'

# Database links
 report db_links

 var $ttl = 'Database Links'
 var $hdr = '|*Owner*|*Database Link*|*Username*|*Host*|*Created*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       db_link || ' |' ||
 "       username || ' |' ||
 "       host || ' |' ||
 "       TO_CHAR(created,'DD-Mon-YYYY HH24:MI:SS') || ' |'
 " FROM dba_db_links
 " ORDER BY owner,db_link;
 }
 call wrt_report($sql,$ttl)

 # Two phase commit pending information
 report tpc_pending
 var $ttl = 'TCP Pending'
 var $hdr = '|*Local Tran ID*|*Global Tran ID*|*State*|*Mixed*|*Advice*|\
              *Comment*|*Fail Time*|*Force Time*|*Retry Time*|*OS User*|\
              *OS Terminal*|*Host*|*DB User*|*Commit#*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       local_tran_id || ' |' ||
 "       global_tran_id || ' |' ||
 "       state || ' |' ||
 "       mixed || ' |' ||
 "       advice || ' |' ||
 "       tran_comment || ' |' ||
 "       fail_time || ' |' ||
 "       force_time || ' |' ||
 "       retry_time || ' |' ||
 "       os_user || ' |' ||
 "       os_terminal || ' |' ||
 "       host || ' |' ||
 "       db_user || ' |' ||
 "       commit# || ' |'
 " FROM dba_2pc_pending
 " ORDER BY local_tran_id,global_tran_id;
 }
 call wrt_report($sql,$ttl)

 # Two phase commit neighbor information
 report tpc_neighbor
 var $ttl = 'TCP Pending'
 var $hdr = '|*Local Tran ID*|*In/Out*|*Database*|*Database User*|\
              *Interface*|*DB ID*|*Session#*|*Branch*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       local_tran_id || ' |' ||
 "       in_out || ' |' ||
 "       database || ' |' ||
 "       dbuser_owner || ' |' ||
 "       interface || ' |' ||
 "       dbid || ' |' ||
 "       sess# || ' |' ||
 "       branch || ' |'
 " FROM dba_2pc_neighbors
 " ORDER BY local_tran_id,in_out;
 }
 call wrt_report($sql,$ttl)
}

# --- RAC ---------------------------------------------------------------------

if isTocCreated(true)
 pretoc '%SPLIT%'
else
 pretoc $MNU
pretoc '1+:RAC'
debug ' Inside ADBA module, getting rac information'

if $ASSESS_ALL
{# DLM Traffic Controller
 report traffic_controller
 var $ttl = 'DLM Traffic Controller'
 var $hdr = '|*Instance*|*Local Node*|*Rem. Node*|*Tickets*|*Limit*|\
              *Wait*|*Send seq*|*Recv seq*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       inst_id || ' |' ||
 "       local_nid || ' |' ||
 "       remote_nid || ' |' ||
 "       tckt_avail || ' |' ||
 "       tckt_limit || ' |' ||
 "       SUBSTR(tckt_wait,1,4) || ' |' ||
 "       snd_seq_no || ' |' ||
 "       rcv_seq_no || ' |'
 " FROM gv$dlm_traffic_controller;
 }
 call wrt_report($sql,$ttl)
}

# Lock conversions
report lock_conversions
var $ttl = 'Lock Conversions'
var $hdr = '|*From*|*To*|*Action*| *Count*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       from_val || ' |' ||
"       to_val || ' |' ||
"       action_val || ' | ' ||
"       counter || '|'
" FROM v$lock_activity;
}
call wrt_report($sql,$ttl)

# Ping on block level
# v$ping is created only if it is RAC
report block_pings
var $ttl = 'Ping on Block Level'
var $hdr = '|*File*|*Block*|*Class*|*Status*|*XNC*|*Forces Reads*|\
             *Forced Writes*|*Object*|*Partition*|*Type*|*Owner*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT 'png=' || '|' ||
"       file# || ' |' ||
"       block# || ' |' ||
"       class# || ' |' ||
"       status || ' |' ||
"       xnc || ' |' ||
"       forced_reads || ' |' ||
"       forced_writes || ' |' ||
"       name || ' |' ||
"       partition_name || ' |' ||
"       kind || ' |' ||
"       owner# || ' |'
" FROM v$ping
" WHERE xnc > 0.5 * (SELECT MAX(xnc)
"                     FROM v$ping)
" ORDER BY xnc DESC;
}
loop $lin (grepSql($sql,'^png='))
 write value($lin)
if isCreated(true)
{write $TOP
 toc '2:[[',getFile(),'][rda_report][',$ttl,']]'
}

# Ping on object level
# v$ping is created only if it is RAC
report object_pings
var $ttl = 'Ping on Object Level'
var $hdr = '|*Name*|*File Number*|*Class Number*|*Max XNC*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT *
" FROM (SELECT 'obj=' || '|' ||
"              name || ' |' ||
"              file# || ' |' ||
"              class# || ' |' ||
"              MAX(xnc) || ' |'
"        FROM v$ping
"        GROUP BY name,file#,class#
"        ORDER BY MAX(xnc))
" WHERE ROWNUM < 11;
}
loop $lin (grepSql($sql,'^obj='))
 write value($lin)
if isCreated(true)
{write $TOP
 toc '2:[[',getFile(),'][rda_report][',$ttl,']]'
}

# Pings per file

report pings_per_file
var $ttl = 'Pings per file'
var $hdr = '| *File number*| *X -> NULL*| *X -> S*| *X -> SSX*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '| ' ||
"       file_number || '| ' ||
"       x_2_null || '| ' ||
"       x_2_s || '| ' ||
"       x_2_ssx || '|'
" FROM v$file_ping;
}
call wrt_report($sql,$ttl)

if $ASSESS_ALL
{# Lock distribution
 # v$ping view is created for RAC only
 report lock_distribution
 var $ttl = 'Lock Distribution'
 var $hdr = '|*File*| *Start Lock*| *Number of Locks*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT 'lck=' || '|' ||
 "       file_name || ' | ' ||
 "       start_lk || '| ' ||
 "       nlocks || '|'
 " FROM file_lock
 " ORDER BY start_lk;
 }
 loop $lin (grepSql($sql,'^lck='))
  write value($lin)
 if isCreated(true)
 {write $TOP
  toc '2:[[',getFile(),'][rda_report][',$ttl,']]'
 }
}

# --- Job Control -------------------------------------------------------------

if isTocCreated(true)
 pretoc '%SPLIT%'
else
 pretoc $MNU
pretoc '1+:Job Control'
debug ' Inside ADBA module, getting job control information'

if $ASSESS_ALL
{# Database jobs
 report jobs
 var $ttl = 'Database Jobs'
 var $hdr = '| *ID*|*Submitter*|*Job*|*Last OK Date*|*Last OK Time*|\
               *Next Run Date*|*Next Run Time*| *Errs*|*Job OK*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '| ' ||
 "       job || '|' ||
 "       log_user || ' |' ||
 "       REPLACE(REPLACE(what,'|','&#124;'),CHR(10),'%BR%') || ' |' ||
 "       TO_CHAR(last_date,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
 "       SUBSTR(last_sec,1,5) || ' |' ||
 "       TO_CHAR(next_date,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
 "       SUBSTR(next_sec,1,5) || ' | ' ||
 "       failures || '|' ||
 "       DECODE(broken,'Y','N','Y') || ' |'
 " FROM sys.dba_jobs;
 }
 call wrt_report($sql,$ttl)
}

# Database job instance
report jobs_inst
var $ttl = 'Database Job Instance'
var $hdr = '| *ID*|*Submitter*|*Job*|*Last OK Date*|*Last OK Time*|\
              *Next Run Date*|*Next Run Time*| *Errors*|*Job OK*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '| ' ||
"       job || '|' ||
"       log_user || ' |' ||
"       REPLACE(REPLACE(what,'|','&#124;'),CHR(10),'%BR%') || ' |' ||
"       TO_CHAR(last_date,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
"       SUBSTR(last_sec,1,5) || ' |' ||
"       TO_CHAR(next_date,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
"       SUBSTR(next_sec,1,5) || ' | ' ||
"       failures || '|' ||
"       DECODE(broken,'Y','N','Y') || ' |'
" FROM sys.dba_jobs
" WHERE instance = (SELECT instance_number
"                    FROM v$instance);
}
call wrt_report($sql,$ttl)

# Crontab jobs (UNIX only)
if isUnix()
{report cron_jobs
 var $ttl = 'Crontab Jobs'
 call dsp_title($ttl)
 call writeCommand('crontab -l')
 if isCreated(true)
 {write $TOP
  toc '2:[[',getFile(),'][rda_report][',$ttl,']]'
 }
}

if $ASSESS_ALL
{# dba_scheduler_job
 if compare('valid',$DBVER,'100')
 {# dba_scheduler_jobs details
  report dba_scheduler_jobs_details
  var $ttl = 'Detail Information dba_scheduler_jobs'
  call setSqlColumns('RDA','actual_start_date','TO_CHAR(actual_start_date)')
  call setSqlColumns('RDA','additional_info',\
    "REPLACE(additional_info,CHR(10),'%BR%')")
  call setSqlColumns('RDA','cpu_used','TO_CHAR(cpu_used)')
  call setSqlColumns('RDA','log_date','TO_CHAR(log_date)')
  call setSqlColumns('RDA','req_start_date','TO_CHAR(req_start_date)')
  call setSqlColumns('RDA','run_duration','TO_CHAR(run_duration)')
  call setSqlColumns('RDA','errors',\
    "REPLACE(errors,CHR(10),'%BR%')")
  var ($hdr,$col) = getSqlColumns('RDA','','dba_scheduler_job_run_details')
  call clearSqlColumns('RDA')
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT *
  " FROM (SELECT :1
  "        FROM dba_scheduler_job_run_details
  "        ORDER BY log_date DESC)
  " WHERE ROWNUM < 21;
  }
  call wrt_report(bindSql($sql,$col),$ttl)

  # dba_scheduler_jobs external program
  report dba_scheduler_jobs_ext_prog
  var $ttl = 'External Program dba_scheduler_jobs'
  var $hdr = '| *Job Name*|*Job Type*|*Job Action*| *Failure Count*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "        job_name || ' |' ||
  "        job_type || ' |' ||
  "        job_action || ' | ' ||
  "        failure_count || '|'
  " FROM dba_scheduler_jobs
  " WHERE job_type = 'EXECUTABLE';
  }
  call wrt_report($sql,$ttl)

  # dba_scheduler_jobs program
  report dba_scheduler_jobs_prog
  var $ttl = 'Program Information dba_scheduler_jobs '
  var $hdr = '|*Job Name*|*Job Type*|*Program Owner*|*Program Name*| \
               *Failure Count*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "        job_name || ' |' ||
  "        job_type || ' |' ||
  "        program_owner || ' |' ||
  "        program_name || ' | ' ||
  "        failure_count || '|'
  " FROM dba_scheduler_jobs;
  }
  call wrt_report($sql,$ttl)

  # General information dba_scheduler_jobs
  report dba_scheduler_jobs
  var $ttl = 'General Information dba_scheduler_jobs'
  var $hdr = '|*Job Name*| *Run Count*| *Failure Count*|*Enabled*|\
               *Start Date*|*Repeat Interval*|*Run Time*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "        job_name || ' | ' ||
  "        run_count || '| ' ||
  "        failure_count || '|' ||
  "        enabled || ' |' ||
  "        TO_CHAR(start_date,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
  "        repeat_interval || ' |' ||
  "        TO_CHAR(last_run_duration,'hh:mm:ss') || ' |'
  " FROM dba_scheduler_jobs
  " ORDER BY owner;
  }
  call wrt_report($sql,$ttl)

  # dba_scheduler_jobs unsuccessful jobs
  report dba_scheduler_jobs_unsuc
  var $ttl = 'Unsuccessful Jobs dba_scheduler_jobs'
  call setSqlColumns('RDA','actual_start_date','TO_CHAR(actual_start_date)')
  call setSqlColumns('RDA','additional_info',\
    "REPLACE(additional_info,CHR(10),'%BR%')")
  call setSqlColumns('RDA','cpu_used','TO_CHAR(cpu_used)')
  call setSqlColumns('RDA','log_date','TO_CHAR(log_date)')
  call setSqlColumns('RDA','req_start_date','TO_CHAR(req_start_date)')
  call setSqlColumns('RDA','run_duration','TO_CHAR(run_duration)')
  call setSqlColumns('RDA','errors',\
    "REPLACE(errors,CHR(10),'%BR%')")
  var ($hdr,$col) = getSqlColumns('RDA','','dba_scheduler_job_run_details')
  call clearSqlColumns('RDA')
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT *
  " FROM (SELECT :1
  " FROM dba_scheduler_job_run_details
  " WHERE status <> 'SUCCEEDED'
  " ORDER BY log_date DESC)
  " WHERE ROWNUM < 21;
  }
  call wrt_report(bindSql($sql,$col),$ttl)
 }
}

# --- Resource Manager --------------------------------------------------------

if $ASSESS_ALL
{if isTocCreated(true)
  pretoc '%SPLIT%'
 else
  pretoc $MNU
 pretoc '1+:Resource Manager'
 debug ' Inside ADBA module, getting resource manager information'
 report resource_mgr
 var $TTL = 'Resource Manager'

 # Defined resource plans
 var $ttl = 'Defined Resource Plans'
 var $hdr = '|*Plan*|*Status*|*Comments*|'
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       plan || ' |' ||
 "       status || ' |' ||
 "       comments || ' |'
 " FROM dba_rsrc_plans;
 }
 call wrt_sql($sql)

 # Defined resource consumer groups
 var $ttl = 'Defined Resource Consumer Groups'
 var $hdr = '|*Granted Group*| *Status*| *User Count*|*Comments*|'
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       b.granted_group || ' |' ||
 "       a.status || ' | ' ||
 "       COUNT(b.grantee) || '|' ||
 "       a.comments || ' |'
 " FROM dba_rsrc_consumer_groups a,dba_rsrc_consumer_group_privs b
 " WHERE a.consumer_group = b.granted_group
 " GROUP BY b.granted_group,a.status,a.comments;
 }
 call wrt_sql($sql)

 # Plans for consumer groups
 var $ttl = 'Plans for Consumer Groups'
 var ($hdr,$col) = getSqlColumns('RDA','','dba_rsrc_plan_directives')
 call clearSqlColumns('RDA')
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT :1
 " FROM dba_rsrc_plan_directives;
 }
 call wrt_sql(bindSql($sql,$col))

 # Currently active plans
 var $ttl = 'Currently Active Plans'
 var ($hdr,$col) = getSqlColumns('RDA','','v$rsrc_plan')
 call clearSqlColumns('RDA')
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT :1
 " FROM v$rsrc_plan;
 }
 call wrt_sql(bindSql($sql,$col))

 # Currently active consumer groups
 var $ttl = 'Currently Active Plans'
 var $hdr = '|*Resource Consumer Group*| *Current Sessions*|'
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       resource_consumer_group || ' | ' ||
 "       COUNT(*) || '|'
 " FROM v$session
 " WHERE resource_consumer_group IS NOT NULL
 " GROUP BY resource_consumer_group;
 }
 call wrt_sql($sql)

 # Current status of consumer groups
 var $ttl = 'Currently Active Plans'
 var ($hdr,$col) = getSqlColumns('RDA','','v$rsrc_consumer_group')
 call clearSqlColumns('RDA')
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT :1
 " FROM v$rsrc_consumer_group;
 }
 call wrt_sql(bindSql($sql,$col))

 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Resource Manager]]'
}

# --- Database Objects --------------------------------------------------------

if isTocCreated(true)
 pretoc '%SPLIT%'
else
 pretoc $MNU
pretoc '1+:Database Objects'
debug ' Inside ADBA module, getting database object information'

if $ASSESS_ALL
{# Summary of analyzed tables
 report analyzed_tables
 var $ttl = 'Analyzed Tables'
 var $hdr = '|*Table Owner*| *Analyzed*| *Not Analyzed*|*Oldest Analysis*| \
            *Total Tables*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "        owner || ' | ' ||
 "        SUM(DECODE(NVL(num_rows,999999999),999999999,0,1)) || '| ' ||
 "        SUM(DECODE(NVL(num_rows,999999999),999999999,1,0)) || '|' ||
 "        NVL(TO_CHAR(MIN(last_analyzed),'DD-Mon-YYYY'),
 "            'not available') || ' | ' ||
 "        COUNT(table_name) || '|'
 " FROM dba_tables
 " WHERE owner NOT IN (:1)
 " GROUP BY owner;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Summary of analyzed indexes
 report analyzed_indexes
 var $ttl = 'Analyzed Indexes'
 var $hdr = '|*Index Owner*| *Analyzed*| *Not Analyzed*|*Oldest Analysis*| \
              *Total Indexes*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "        owner || ' | ' ||
 "        SUM(DECODE(NVL(num_rows,999999999),999999999,0,1)) || '| ' ||
 "        SUM(DECODE(NVL(num_rows,999999999),999999999,1,0)) || '|' ||
 "        NVL(TO_CHAR(MIN(last_analyzed),'DD-Mon-YYYY'),
 "            'not available') || ' | ' ||
 "        COUNT(INDEX_NAME) || '|'
 " FROM dba_indexes
 " WHERE owner NOT IN (:1)
 "   AND index_type <> 'LOB'
 " GROUP BY OWNER;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Tables with more than 5 indexes
 # SYS and SYSTEM and Oracle product users are excluded
 report table_indexes
 var $ttl = 'Table Indexes'
 var $hdr = '|*Owner*|*Table*| *Number of Indexes*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '| ' ||
 "        owner || '|' ||
 "        table_name || ' | ' ||
 "        COUNT(*) || '|'
 " FROM dba_indexes
 " WHERE owner NOT IN (:1)
 "   AND index_type <> 'LOB'
 " GROUP BY owner,table_name
 " HAVING COUNT(*) > 5
 " ORDER BY COUNT(*) DESC,owner,table_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Large tables without indexes
 report tables_without_indexes
 var $ttl = 'Tables without Indexes'
 var $hdr = '|*Table Owner*|*Table*| *Size (MiB)*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT /*+rule*/ '| ' ||
 "        t.owner || '|' ||
 "        t.table_name || ' | ' ||
 "        ROUND(SUM(e.bytes) / 1048576,2) || '|'
 " FROM (SELECT owner,
 "        table_name
 " FROM dba_tables
 "MINUS SELECT /*+rule*/ table_owner,table_name
 " FROM dba_indexes) t,dba_extents e
 " WHERE  t.owner NOT IN (:1)
 "   AND t.owner = e.owner
 "   AND t.table_name = e.segment_name
 "   AND t.table_name NOT LIKE 'SYS_IOT_OVER%'
 " GROUP BY t.owner,t.table_name
 " HAVING SUM(e.blocks) >= (SELECT /*+rule*/ b.ksppstvl
 "                           FROM x$ksppi  a,x$ksppsv b
 "                           WHERE a.indx = b.indx
 "                             AND a.ksppinm = '_small_table_threshold')
 " ORDER BY SUM(e.bytes),t.owner,t.table_name DESC;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Table and index locations
 report table_index_locations
 var $ttl = 'Table and Index Locations'
 var $hdr = '|*Owner*|*Tablespace*| *Tables*| *Indexes*|'
 prefix
 call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "        owner || ' |' ||
 "        tablespace_name || ' | ' ||
 "        SUM(DECODE(segment_type,'TABLE',1,0)) || '| ' ||
 "        SUM(DECODE(segment_type,'INDEX',1,0)) || '|'
 " FROM dba_segments
 " WHERE segment_type IN ('TABLE','INDEX')
 "   AND owner NOT IN (:1)
 " GROUP BY owner,tablespace_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Effective table and index locations
 report table_index_effective_locations
 var $ttl = 'Effective Table and Index Locations'
 var $hdr = '|*Owner*|*Tablespace*| *Tables*| *Indexes*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT  '|' ||
 "        a.owner || ' |' ||
 "        a.tablespace_name || ' | ' ||
 "        a.tables || '| ' ||
 "        a.indexes || '|'
 " FROM (SELECT owner,
 "              tablespace_name,
 "              SUM(DECODE(segment_type,'TABLE',1,0)) tables,
 "              SUM(DECODE(segment_type,'INDEX',1,0)) indexes
 "        FROM dba_segments
 "        WHERE segment_type IN ('TABLE','INDEX')
 "          AND owner NOT IN (:1)
 "        GROUP BY owner,tablespace_name) a
 " WHERE a.tables != 0
 "   AND a.indexes != 0;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Partitioned indexes
 report partitioned_indexes
 var $ttl = 'Partitioned Indexes'
 var $hdr = '|*Owner*|*Index*|*Table*|*Part. Type*| *Part. Count*|\
              *Subpart. Type*|*Subpart. Count*|*Locality*|\
              *Default Tablespace*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       index_name || ' |' ||
 "       table_name || ' |' ||
 "       partitioning_type || ' | ' ||
 "       partition_count || '|' ||
 "       subpartitioning_type || ' | ' ||
 "       def_subpartition_count || '|' ||
 "       locality || ' |' ||
 "       def_tablespace_name || ' |'
 " FROM dba_part_indexes
 " WHERE owner NOT IN (:1)
 " ORDER BY owner,index_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Partitioned tables
 # SYS and SYSTEM and Oracle product users are excluded
 report partitioned_tables
 var $ttl = 'Partitioned Tables'
 var $hdr = '|*Owner*|*Table*|*Partition Type*| *Partition Count*|\
              *Subpartition Type*| *Subpartition Count*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' |' ||
 "       partitioning_type || ' |' ||
 "       partition_count || ' | ' ||
 "       subpartitioning_type || '|' ||
 "       def_subpartition_count || ' | '
 " FROM dba_part_tables
 " WHERE owner NOT IN (:1)
 " ORDER BY owner,table_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # NON Partitioned tables larger than 2GB
 # SYS, SYSTEM and Oracle product users are excluded.
 report non_partitioned_tables
 var $ttl = 'Non Partitioned Tables'
 var $hdr = '|*Owner*|*Table Name*|*Tablespace Name*| *Size (MiB)*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' |' ||
 "       tablespace_name || ' | ' ||
 "       ROUND(total_bytes/POWER(2,20)) || '|'
 " FROM ( SELECT dt.owner,
 "               dt.table_name,
 "               ds.tablespace_name,
 "               SUM(ds.bytes) total_bytes
 "         FROM dba_segments ds,dba_tables dt
 "         WHERE ds.owner = dt.owner
 "           AND ds.segment_name = dt.table_name
 "           AND ds.segment_type = 'TABLE'
 "           AND ds.owner NOT IN (:1)
 "         GROUP BY dt.owner,dt.table_name,ds.tablespace_name )
 " WHERE total_bytes > POWER(2,31)
 " ORDER BY owner,table_name,tablespace_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # NON Partitioned table segments larger than 2GB
 # SYS, SYSTEM and Oracle product users are excluded.
 if compare('valid',$DBVER,'92')
 {report non_partitioned_segments
  var $ttl = 'Non Partitioned Table Segments'
  var $hdr = '|*Owner*|*Table Name*|*Column Name*|*Data Type*|*Segment Type*|\
               *Segment Name*|*Tablespace Name*| *Size (MiB)*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       owner || ' |' ||
  "       segment_type || ' |' ||
  "       segment_name || ' |' ||
  "       tablespace_name || ' | ' ||
  "       megabytes || '|'
  " FROM (SELECT DISTINCT owner,
  "                       segment_type,
  "                       segment_name,
  "                       tablespace_name,
  "                       ROUND(bytes / POWER(2,20)) megabytes
  "        FROM dba_segments
  "        WHERE segment_type IN ('TABLE','LOBSEGMENT')
  "          AND owner NOT IN (:1)
  "          AND partition_name IS NULL
  "          AND bytes > POWER(2,31)
  "          ORDER BY owner
  "      );
  }
  call wrt_report(bindSql($sql,$STD_USR),$ttl)
 }

 # Sequences information
 # Oracle users are excluded.
 report sequences_count
 var $ttl = 'Number of Sequences'
 var $hdr = '|*Owner*| *Number*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       sequence_owner || ' | ' ||
 "       COUNT(*) || '|'
 " FROM dba_sequences
 " WHERE sequence_owner NOT IN (:1)
 " GROUP BY sequence_owner
 " ORDER BY sequence_owner;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Large objects information
 # Oracle users are excluded.
 report lobs
 var $ttl = 'LOBs'
 if match($DBVER,'^(81|90)')
 {var $hdr = '|*Owner*|*Table Name*|*Column Name*|\
               *Segment Name*|*Index Name*| *Chunk (KiB)*| \
               *Segment size (KiB)*|*Cache*|*In Row*| *Pctversion*|*Logging*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       dl.owner || ' |' ||
  "       dl.table_name || ' |' ||
  "       dl.column_name || ' |' ||
  "       dl.segment_name || ' |' ||
  "       dl.index_name || ' | ' ||
  "       dl.chunk/1024 || '| ' ||
  "       ds.bytes/1024 || '|' ||
  "       dl.cache || ' |' ||
  "       dl.in_row || ' | ' ||
  "       dl.pctversion || '|' ||
  "       dl.logging || ' |'
  " FROM dba_lobs dl,dba_segments ds
  " WHERE dl.segment_name = ds.segment_name
  "   AND dl.owner NOT IN (:1)
  " ORDER BY dl.owner,dl.table_name,dl.column_name;
  }
 }
 elsif match($DBVER,'^92')
 {var $hdr = '|*Owner*|*Table Name*|*Column Name*|\
               *Segment Name*|*Index Name*| *Chunk (KiB)*| \
               *Segment size (KiB)*|*Cache*|*In Row*| *Pctversion*| \
               *Retention*|*Logging*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       u.name || ' |' ||
  "       o.name || ' |' ||
  "       DECODE(BITAND(c.property,1),1,ac.name,c.name) || ' |' ||
  "       lo.name || ' |' ||
  "       io.name || ' | ' ||
  "       l.chunk*p.value / 1024 || '| ' ||
  "       DECODE(BITAND(l.flags,27),1,'NO',2,'NO',8,'CACHEREADS',16,
  "              'CACHEREADS','YES') || '|' ||
  "       DECODE(BITAND(l.property,2),2,'YES','NO') || ' | ' ||
  "       DECODE(BITAND(l.flags,32),0,l.pctversion$,TO_NUMBER(NULL)) || '|' ||
  "       DECODE(BITAND(l.flags,32),32,l.retention,TO_NUMBER(NULL)) || ' |' ||
  "       DECODE(BITAND(l.flags,18),2,'NO',16,'NO','YES') || ' |'
  " FROM sys.obj$ o,sys.col$ c,sys.attrcol$ ac,sys.lob$ l,
  "      sys.user$ u,sys.obj$ lo,sys.obj$ io,v$parameter p
  " WHERE o.owner# = u.user#
  "   AND o.obj# = c.obj#
  "   AND c.obj# = l.obj#
  "   AND c.intcol# = l.intcol#
  "   AND l.lobj# = lo.obj#
  "   AND l.ind# = io.obj#
  "   AND c.obj# = ac.obj#(+)
  "   AND c.intcol# = ac.intcol#(+)
  "   AND BITAND(c.property,32768) != 32768
  "   AND p.name = 'db_block_size'
  "   AND u.name NOT IN (:1)
  " ORDER BY u.name,o.name,DECODE(BITAND(c.property,1),1,ac.name,c.name);
  }
 }
 else
 {var $hdr = '|*Owner*|*Table Name*|*Column Name*|*Tablespace Name*|\
               *Segment Name*|*Index Name*| *Chunk (KiB)*| \
               *Segment size (KiB)*|*Cache*|*In Row*| *Retention*| \
               *Pctversion*|*Logging*|*Partitioned*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       dl.owner || ' |' ||
  "       dl.table_name || ' |' ||
  "       dl.column_name || ' |' ||
  "       dl.tablespace_name || ' | ' ||
  "       dl.segment_name || '|' ||
  "       dl.index_name || ' | ' ||
  "       TO_CHAR(dl.chunk / 1024) || '| ' ||
  "       TO_CHAR(ds.bytes / 1024) || '|' ||
  "       dl.cache || ' |' ||
  "       dl.in_row || ' | ' ||
  "       dl.retention || '|' ||
  "       dl.pctversion || ' |' ||
  "       dl.logging || ' |' ||
  "       dl.partitioned || ' |'
  " FROM dba_lobs dl,dba_Segments ds
  " WHERE dl.segment_name = ds.segment_name
  "   AND dl.owner NOT IN (:1)
  " ORDER BY dl.owner,dl.table_name,dl.column_name;
  }
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # FK constraints without index on child table
 report fk_without_index
 var $ttl = 'FK Constraints without Index'
 var $hdr = '|*Owner*|*Constraint*|*Table*|*Column*| *Position*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       acc.owner || ' |' ||
 "       acc.constraint_name || ' |' ||
 "       acc.table_name || ' |' ||
 "       acc.column_name || ' | ' ||
 "       acc.position || '|'
 " FROM dba_cons_columns acc,dba_constraints ac
 " WHERE ac.constraint_name = acc.constraint_name
 "   AND ac.constraint_type = 'R'
 "   AND acc.owner NOT IN (:1)
 "   AND acc.owner = ac.owner
 "   AND NOT EXISTS (SELECT 'TRUE'
 "                    FROM dba_ind_columns b
 "                    WHERE b.table_owner = acc.owner
 "                      AND b.table_name = acc.table_name
 "                      AND b.column_name = acc.column_name
 "                      AND b.column_position = acc.position)
 " ORDER BY acc.owner,acc.constraint_name,acc.column_name,acc.position;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Degree and instances of tables and indexes
 # Degree 0 and 1 excluded
 report degree
 var $ttl = 'Degree'
 var $hdr = '|*Owner*|*Degree*|*Instances*| *Number of Tabs*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       out.owner || ' |' ||
 "       out.degree || ' |' ||
 "       out.instances || ' | ' ||
 "       out.objs || '|'
 " FROM (SELECT owner,
 "              degree,
 "              instances,
 "              COUNT(*)||' Table(s)' Objs
 "        FROM dba_tables
 "        WHERE instances NOT IN ('         0','         1')
 "           OR degree NOT IN ('         0','         1')
 "          AND owner NOT IN (:1)
 "        GROUP BY owner,degree,instances
 "       UNION
 "       SELECT owner,
 "              degree,
 "              instances,
 "              COUNT(*)||' Index(es)' Objs
 "        FROM dba_indexes
 "        WHERE instances NOT IN ('0','1')
 "           OR degree NOT IN ('0','1')
 "          AND owner NOT IN (:1)
 " GROUP BY owner,degree,instances) out
 " ORDER BY out.owner,out.degree;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Tables without primary key constraint
 # SYS, SYSTEM and Oracle product users are excluded
 report tables_without_pk
 var $ttl = 'Tables without Primary Key'
 var $hdr = '|*Owner*|*Table*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' |'
 " FROM (SELECT owner,
 "              table_name
 "        FROM dba_tables
 "        WHERE table_name NOT LIKE 'SYS_IOT_OVER%'
 "          AND table_name NOT LIKE 'MLOG$%'
 "          AND table_name NOT LIKE 'RUPD$%'
 "          AND table_name NOT LIKE 'PLAN_TABLE'
 "       MINUS
 "       SELECT owner,
 "              table_name
 "        FROM dba_constraints
 "        WHERE constraint_type = 'P')
 " WHERE owner NOT IN (:1)
 " ORDER BY owner,table_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Tables without primary key constraint
 # SYS and SYSTEM users are excluded
 report tables_without_pk_count
 var $ttl = 'Count of Tables without Primary Key'
 var $hdr = '|*Owner*| *Count*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' | ' ||
 "       COUNT(*) || '|'
 " FROM (SELECT owner,
 "              table_name
 "        FROM dba_tables
 "        WHERE table_name NOT LIKE 'SYS_IOT_OVER%'
 "          AND table_name NOT LIKE 'MLOG$%'
 "          AND table_name NOT LIKE 'RUPD$%'
 "          AND table_name NOT LIKE 'PLAN_TABLE'
 "       MINUS
 "       SELECT owner,
 "              table_name
 "        FROM dba_constraints
 "        WHERE constraint_type = 'P')
 " WHERE owner NOT IN (:1)
 " GROUP BY owner
 " ORDER BY owner;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Disabled constraints
 report disabled_constraints
 var $ttl = 'Disabled Constraints'
 var $hdr = '|*Owner*|*Table*|*Name*|*Type*|*Status*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' |' ||
 "       constraint_name || ' |' ||
 "       DECODE(constraint_type,'C','Check','P','Primary Key','U','Unique',
 "              'R','Foreign Key','V','With Check Option') || ' |' ||
 "       status || ' |'
 " FROM dba_constraints
 " WHERE owner NOT IN (:1)
 "   AND status = 'DISABLED'
 "   AND table_name NOT LIKE 'LOGMNR_%'
 " ORDER BY owner,table_name,constraint_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)
}

# Large objects not pinned
# Sharable memory larger than 10000 bytes
report large_unpinned
var $ttl = 'Large Objects not Pinned'
var $hdr = '|*Owner*|*Object Name*| *Sharable Memory (KiB)*|*Object Type*| \
             *Loads*| *Executions*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       owner || ' |' ||
"       name || ' | ' ||
"       TO_CHAR(ROUND(sharable_mem / 1024)) || '|' ||
"       type || ' | ' ||
"       loads || '| ' ||
"       executions || '|'
" FROM v$db_object_cache
" WHERE sharable_mem > 10000
"   AND owner NOT IN (:1)
"   AND type IN ('PACKAGE','PROCEDURE','FUNCTION','TRIGGER')
"   AND kept = 'NO';
}
call wrt_report(bindSql($sql,$STD_USR),$ttl)

# Pinned objects
report pinned_objects
var $ttl = 'Pinned Objects'
var $hdr = '|*Owner*|*Object Name*| *Sharable Memory (KiB)*|*Object Type*| \
             *Loads*| *Executions*|'
prefix
 call dsp_title($ttl,$hdr)
set $sql
{SELECT '|' ||
"       owner || ' |' ||
"       name || ' |' ||
"       TO_CHAR(ROUND(sharable_mem / 1024)) || ' |' ||
"       type || ' |' ||
"       loads || ' |' ||
"       executions || ' |'
" FROM v$db_object_cache
" WHERE owner NOT IN (:1)
"   AND type NOT IN ('TABLE','INDEX','CLUSTER','JAVA CLASS')
"   AND kept = 'YES';
}
call wrt_report(bindSql($sql,$STD_USR),$ttl)

if $ASSESS_ALL
{# Cached tables
 report cached_tables
 var $ttl = 'Cached Tables'
 var $hdr = '|*Owner*|*Table*|*Cache*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' |' ||
 "       cache || ' |'
 " FROM dba_tables
 " WHERE owner NOT IN (:1)
 "   AND cache LIKE '%Y'
 " ORDER BY owner,table_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Special objects
 report special_objects
 var $TTL = 'Special Objects'

 # Index organized tables
 var $ttl = 'Index Organized Tables'
 var $hdr = '|*Name*|*Owner*|*Type*|'
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       table_name || ' |' ||
 "       owner || ' |' ||
 "       iot_type || ' |'
 " FROM dba_tables
 " WHERE iot_type IS NOT NULL
 "   AND owner NOT IN (:1);
 }
 call wrt_sql(bindSql($sql,$STD_USR))

 # Nested tables
 var $ttl = 'Index Organized Tables'
 var $hdr = '|*Owner*|*Nested Tables*|'
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' |'
 " FROM dba_nested_tables
 " WHERE owner NOT IN (:1);
 }
 call wrt_sql(bindSql($sql,$STD_USR))

 # Tables with VARRAYS
 var $ttl = 'Tables with VARRAYS'
 var $hdr = '|*Owner*|*Tables with Varrays*|'
 prefix
 call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       parent_table_name || ' |'
 " FROM dba_varrays
 " WHERE owner NOT IN (:1);
 }
 call wrt_sql(bindSql($sql,$STD_USR))

 # Compressed tables
 if compare('valid',$DBVER,'92')
 {var $ttl = 'Compressed Tables'
  var $hdr = '|*Table*|*Owner*|'
  prefix
   call dsp_title_header($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       table_name || ' |' ||
  "       owner || ' |'
  " FROM dba_tables
  " WHERE compression = 'ENABLED'
  "   AND owner NOT IN (:1);
  }
  call wrt_sql(bindSql($sql,$STD_USR))
 }

 # Compressed indexes
 var $ttl = 'Compressed Indexes'
 var $hdr = '|*Index*|*Table*|*Owner*|'
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       index_name || ' |' ||
 "       table_name || ' |' ||
 "       owner || ' |'
 " FROM dba_indexes
 " WHERE compression = 'ENABLED'
 "   AND owner NOT IN (:1);
 }
 call wrt_sql(bindSql($sql,$STD_USR))

 # Tables with LOB columns
 var $ttl = 'Tables with LOBs'
 var $hdr = '|*Owner*|*Table*| *Number of LOB Columns*|'
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' | ' ||
 "       COUNT(DISTINCT (column_name)) || '|'
 " FROM dba_lobs
 " WHERE owner NOT IN (:1)
 " GROUP BY owner,table_name;
 }
 call wrt_sql(bindSql($sql,$STD_USR))

 # Table monitoring
 var $ttl = 'Table Monitoring'
 var $hdr = '|*Table*|*Owner*|'
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       table_name || ' |' ||
 "       owner || ' |'
 " FROM dba_tables
 " WHERE monitoring = 'YES'
 "   AND owner NOT IN (:1);
 }
 call wrt_sql(bindSql($sql,$STD_USR))

 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Special Objects]]'

 # Snapshots
 report snapshots
 var $ttl = 'Snapshots'
 var $hdr = '|*Name*|*Type*| *Error*|*Master*|*Next*|*Last Refresh*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       name || ' |' ||
 "       type || ' | ' ||
 "       error || '|' ||
 "       master || ' |' ||
 "       next || ' |' ||
 "       TO_CHAR(last_refresh,'DD-Mon-YYYY HH24:MI:SS') || ' |'
 " FROM sys.dba_snapshots;
 }
 call wrt_report($sql,$ttl)

 # Registered Snapshots
 report registered_snapshots
 var $ttl = 'Registered Snapshots'
 if match($DBVER,'^81')
 {var $hdr = '|*Owner*|*Name*|*Snapshot Site*|*Can Use Log*|*Updatable*|\
               *Refresh Method*|*Version*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       owner || ' |' ||
  "       name || ' |' ||
  "       snapshot_site || ' |' ||
  "       can_use_log || ' |' ||
  "       updatable || ' |' ||
  "       refresh_method || ' |' ||
  "       version || ' |'
  " FROM dba_registered_snapshots
  " WHERE owner NOT IN (:1);
  }
 }
 else
 {var $hdr = '|*Owner*|*Name*|*Mview Site*|*Can Use Log*|*Updatable*|\
               *Refresh Method*|*Version*|'
  prefix
   call dsp_title($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       owner || ' |' ||
  "       name || ' |' ||
  "       mview_site || ' |' ||
  "       can_use_log || ' |' ||
  "       updatable || ' |' ||
  "       refresh_method || ' |' ||
  "       version || ' |'
  " FROM dba_registered_mviews
  " WHERE owner NOT IN (:1);
  }
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Snapshot_Logs
 report snapshot_logs
 var $ttl = 'Snapshot Logs'
 var $hdr = '|*Log Owner*|*Master*|*Log Table*| *Rowids*|*Primary Key*|\
              *Filter Columns*| *Snapshot ID*|*Current Snapshots*| \
              *Size(MiB)*|*Freelists*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       log_owner || ' |' ||
 "       master || ' |' ||
 "       log_table || ' | ' ||
 "       rowids || '|' ||
 "       primary_key || ' |' ||
 "       filter_columns || ' | ' ||
 "       snapshot_id || '| ' ||
 "       TO_CHAR(current_snapshots,'DD-Mon-YYYY HH24:MI:SS') || '| ' ||
 "       TO_CHAR(bytes / 1048576) || '|' ||
 "       freelists || ' |'
 " FROM sys.dba_snapshot_logs a,sys.dba_segments b
 " WHERE a.log_owner = b.owner
 "   AND b.owner NOT IN (:1)
 "   AND a.log_table = b.segment_name;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Snapshot_Refreshes
 report snapshot_refreshes
 var $ttl = 'snapshot_refreshes'
 var $hdr = '|*Owner*|*Master*|*Master Link*|*Updatable*|*Refresh Method*|\
              *Name*|*Type*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       a.owner || ' |' ||
 "       master || ' |' ||
 "       master_link || ' |' ||
 "       updatable || ' |' ||
 "       refresh_method || ' |' ||
 "       b.name || ' |' ||
 "       type || ' |'
 " FROM dba_snapshots a,dba_rgroup b
 " WHERE a.refresh_group = b.refgroup
 "   AND a.owner NOT IN (:1)
 " ORDER BY a.owner,b.name,a.master;
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Refresh Groups
 report refresh_groups
 var $ttl = 'Refresh Groups'
 var $hdr = '|*Name*|*Refgroup*|*Job*|*What*|*Interval*|*Last_Date*|\
              *Last Sec*|*Next Date*|*Next Sec*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       a.name || ' |' ||
 "       refgroup || ' |' ||
 "       a.job || ' |' ||
 "       REPLACE(REPLACE(b.what,'|','&#124;'),CHR(10),'%BR%') || ' |' ||
 "       b.interval || ' |' ||
 "       last_date || ' |' ||
 "       last_sec || ' |' ||
 "       next_date || ' |' ||
 "       next_sec || ' |'
 " FROM dba_rgroup a,dba_jobs b
 " WHERE a.job = b.job;
 }
 call wrt_report($sql,$ttl)

 # Nologging Indexes
 report index_nolog
 var $ttl = 'Index Nolog'
 var $hdr = '|*Owner*|*Index Name*|*Table Name*|*Logging*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       index_name || ' |' ||
 "       table_name || ' |' ||
 "       logging || ' |'
 " FROM dba_indexes
 " WHERE logging = 'NO'
 "   AND owner NOT IN (:1);
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Nologging Tables
 report table_nolog
 var $ttl = 'Table Nolog'
 var $hdr = '|*Owner*|*Table Name*|*Logging*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' |' ||
 "       logging || ' |'
 " FROM dba_tables
 " WHERE logging = 'NO'
 "   AND temporary <> 'Y'
 "   AND owner NOT IN (:1);
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Nologging Object Tables
 report object_tables_nolog
 var $ttl = 'Object Tables Nolog'
 var $hdr = '|*Owner*|*Table Name*|*Logging*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' |' ||
 "       logging || ' |'
 " FROM dba_object_tables
 " WHERE logging = 'NO'
 "   AND owner NOT IN (:1);
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Nologging LOBs
 report lobs_nolog
 var $ttl = 'LOBs Nolog'
 var $hdr = '|*Owner*|*Table Name*|*Logging*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       owner || ' |' ||
 "       table_name || ' |' ||
 "       logging || ' |'
 " FROM dba_lobs
 " WHERE logging = 'NO'
 "   AND owner NOT IN (:1);
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Nologging Partitioned Tables
 report tab_part_nolog
 var $ttl = 'Partitioned Tables Nologging'
 var $hdr = '|*Table Owner*|*Table Name*|*Partition Name*| \
              *Subpartition Count*|*Logging*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       table_owner || ' |' ||
 "       table_name || ' |' ||
 "       partition_name || ' | ' ||
 "       subpartition_count || '|' ||
 "       logging || ' |'
 " FROM dba_tab_partitions
 " WHERE logging = 'NO'
 "   AND table_owner NOT IN (:1);
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Nologging Partitioned Indexes
 report ind_part_nolog
 var $ttl = 'Partitioned Indexes Nologging'
 var $hdr = '|*Index Owner*|*Index Name*|*Partition Name*| \
              *Subpartition Count*|*Logging*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       index_owner || ' |' ||
 "       index_name || ' |' ||
 "       partition_name || ' | ' ||
 "       subpartition_count || '|' ||
 "       logging || ' |'
 " FROM dba_ind_partitions
 " WHERE logging = 'NO'
 "   AND index_owner NOT IN (:1);
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Nologging Subpartitioned Tables
 report tab_subpart_nolog
 var $ttl = 'Subpartitioned Tables Nologging'
 var $hdr = '|*Table Owner*|*Table Name*|*Partition Name*| \
              *Subpartition Name*|*Logging*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       table_owner || ' |' ||
 "       table_name || ' |' ||
 "       partition_name || ' | ' ||
 "       subpartition_name || '|' ||
 "       logging || ' |'
 " FROM dba_tab_subpartitions
 " WHERE logging = 'NO'
 "   AND table_owner NOT IN (:1);
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Nologging Subpartitioned Indexes
 report ind_subpart_nolog
 var $ttl = 'Subpartitioned Indexes Nologging'
 var $hdr = '|*Index Owner*|*Index Name*|*Partition Name*| \
              *Subpartition Name*|*Logging*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       index_owner || ' |' ||
 "       index_name || ' |' ||
 "       partition_name || ' | ' ||
 "       subpartition_name || '|' ||
 "       logging || ' |'
 " FROM dba_ind_subpartitions
 " WHERE logging = 'NO'
 "   AND index_owner NOT IN (:1);
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Nologging Partitioned LOBs
 report lobs_part_nolog
 var $ttl = 'Partitioned LOBs Nologging'
 var $hdr = '|*Table Owner*|*Table Name*|*Partition Name*| \
              *LOB Partition Name*|*Logging*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       table_owner || ' |' ||
 "       table_name || ' |' ||
 "       partition_name || ' | ' ||
 "       lob_partition_name || '|' ||
 "       logging || ' |'
 " FROM dba_lob_partitions
 " WHERE logging = 'NO'
 "   AND table_owner NOT IN (:1);
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)

 # Nologging Subpartitioned LOBs
 report lobs_subpart_nolog
 var $ttl = 'Subpartitioned LOBs Nologging'
 var $hdr = '|*Table Owner*|*Table Name*|*LOB Name*|*LOB Partition Name*|\
              *Subpartition Name*|*Logging*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       table_owner || ' |' ||
 "       table_name || ' |' ||
 "       lob_name || ' | ' ||
 "       lob_partition_name || '|' ||
 "       subpartition_name || '|' ||
 "       logging || ' |'
 " FROM dba_lob_subpartitions
 " WHERE logging = 'NO'
 "   AND table_owner NOT IN (:1);
 }
 call wrt_report(bindSql($sql,$STD_USR),$ttl)
}

# Alert log dump
if match($DBVER,'^(81|9)')
{set $sql
 {SELECT 'log=' ||
 "       value
 " FROM v$parameter
 " WHERE name like 'background_dump_dest';
 }
 var $fil = catFile(value(grepLastSql('^tps=','f')),concat('alert_',\
                    $ORACLE_SID,'.log'))
 if ?testFile('r',$fil)
 {report alert_log
  prefix
   call dsp_title('Alert Log (last 5000 lines)')
  call writeTail($fil,5000)
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][Alert Log]]'
  }
 }
}

# --- ASM ---------------------------------------------------------------------

if and(compare('valid',$DBVER,'100'),$ASSESS_ALL)
{if isTocCreated(true)
  pretoc '%SPLIT%'
 else
  pretoc $MNU
 pretoc '1+:ASM'
 debug ' Inside ADBA module, getting ASM information'

 # ASM Alias
 report asm_alias
 var $ttl = 'ASM Alias'
 var $hdr = '|*Name*|*Group Number*|*File Number*|*File Incarnation*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       name || ' |' ||
 "       group_number || ' |' ||
 "       file_number || ' | ' ||
 "       file_incarnation || '|'
 " FROM v$asm_alias;
 }
 call wrt_report($sql,$ttl)

 # ASM clients
 report asm_clients
 var $ttl = 'ASM Clients'
 if compare('valid',$DBVER,'102')
 {var $hdr = '| *Group Number*|*Instance Name*|*DB Name*|*Status*|\
                *Software Version*|*Compatible Version*|'
  set $sql
  {SELECT '| ' ||
  "       group_number || '|' ||
  "       instance_name || ' |' ||
  "       db_name || ' |' ||
  "       status || ' |' ||
  "       software_version || ' |' ||
  "       compatible_version || ' |'
  " FROM v$asm_client;
  }
 }
 else
 {var $hdr = '| *Group Number*|*Instance Name*|*DB Name*|*Status*|'
  set $sql
  {SELECT '| ' ||
  "       group_number || '|' ||
  "       instance_name || ' |' ||
  "       db_name || ' |' ||
  "       status || ' |'
  " FROM v$asm_client;
  }
 }
 prefix
  call dsp_title($ttl,$hdr)
 call wrt_report($sql,$ttl)

 # ASM disk (part 1)
 report asm_disk1
 var $ttl = 'ASM Disk1'
 var $hdr = '| *Disk Number*| *Group Number*|*Name*|*Path*|*Header Status*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '| ' ||
 "       disk_number || '| ' ||
 "       group_number || '|' ||
 "       name || ' |' ||
 "       path || ' |' ||
 "       header_status || ' |'
 " FROM v$asm_disk;
 }
 call wrt_report($sql,$ttl)

 # ASM disk (part 2)
 report asm_disk2
 var $ttl = 'ASM Disk2'
 var $hdr = '| *Group Number*| *Disk Number*|*Mount Status*|*State*|\
              *Redundancy*| *Total (MiB)*| *Free (MiB)*|*Name*|*Failgroup*|\
              *Path*| *Read Errs*| *Write Errs*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '| ' ||
 "       group_number || '| ' ||
 "       disk_number || '|' ||
 "       mount_status || ' |' ||
 "       state || ' |' ||
 "       redundancy || ' | ' ||
 "       total_mb || '| ' ||
 "       free_mb || '| ' ||
 "       name || ' |' ||
 "       failgroup || ' |' ||
 "       path || ' | ' ||
 "       read_errs || '| ' ||
 "       write_errs || '|'
 " FROM v$asm_disk;
 }
 call wrt_report($sql,$ttl)

 # ASM Disk Tree
 report asm_disk_tree
 var $ttl = 'ASM Disk Tree'
 var $hdr = '|*Full Alias Path*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       CONCAT('+'||gname,sys_connect_by_path(aname,'/')) || ' |'
 " FROM
 "(SELECT g.name gname,
 "        a.parent_index pindex,
 "        a.name aname,
 "        a.reference_index rindex
 " FROM v$asm_alias a,:1 g
 " WHERE a.group_number = g.group_number)
 " START WITH (MOD(pindex,POWER(2,24))) = 0
 " CONNECT BY PRIOR rindex = pindex;
 }
 call wrt_report(bindSql($sql,$DG_TBL),$ttl)

 # ASM file
 report asm_file
 var $ttl = 'ASM File'
 var $hdr = '| *Group Number*| *File Number*| *Incarnation*| *Block Size*| \
               *Blocks*|*Type*|*Redundancy*|*Striped*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '| ' ||
 "       group_number || '| ' ||
 "       file_number || '| ' ||
 "       incarnation || '| ' ||
 "       block_size || '| ' ||
 "       blocks || '|' ||
 "       type || ' |' ||
 "       redundancy || ' |' ||
 "       striped || ' |'
 " FROM v$asm_file;
 }
 call wrt_report($sql,$ttl)

 # ASM operations
 report asm_operations
 var $ttl = 'ASM Operations'
 var ($hdr,$col) = getSqlColumns('RDA','','v$asm_operation')
 call clearSqlColumns('RDA')
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT *
 " FROM v$asm_operation;
 }
 call wrt_report(bindSql($sql,$col),$ttl)

 # ASM Disk Groups (part 1)
 report disk_groups1
 var $ttl = 'Disk Groups1'
 var $hdr = '|*Name*|*State*|*Type*| *Total (MiB)*| *Free (MiB)*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       name || ' |' ||
 "       state || ' |' ||
 "       type || ' | ' ||
 "       total_mb || '| ' ||
 "       free_mb || '|'
 " FROM :1;
 }
 call wrt_report(bindSql($sql,$DG_TBL),$ttl)

 # ASM disk groups (part 2)
 report disk_groups2

 var $ttl = 'Disk Groups2'
 var $hdr = '|*Name*|*Path*|*Mode Status*|*State*| *Disk Number*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '|' ||
 "       name || ' |' ||
 "       path || ' |' ||
 "       mode_status || ' |' ||
 "       state || ' | ' ||
 "       disk_number || '|'
 " FROM v$asm_disk;
 }
 call wrt_report($sql,$ttl)

 var $ttl = replace($DG_TBL,'^v\$')
 if compare('valid',$DBVER,'102')
 {var $hdr = '|*Name*| *Sector Size*| *Block Size*| *Allocation Unit Size*| \
               *Offline Disks*|*Compatibility*|*Database Compatibility*|'
  set $sql
  {SELECT '|' ||
  "       name || ' |' ||
  "       sector_size || ' |' ||
  "       block_size || ' | ' ||
  "       allocation_unit_size || '| ' ||
  "       offline_disks || '|' ||
  "       compatibility || ' |' ||
  "       database_compatibility || ' |'
  " FROM :1;
  }
 }
 else
 {var $hdr = '|*Name*| *Sector Size*| *Block Size*| *Allocation Unit Size*|'
  set $sql
  {SELECT '|' ||
  "       name || ' |' ||
  "       sector_size || ' |' ||
  "       block_size || ' | ' ||
  "       allocation_unit_size || '|'
  " FROM :1;
  }
 }
 prefix
  call dsp_title_header($ttl,$hdr)
 call wrt_sql(bindSql($sql,$DG_TBL))

 # Disk partner
 report disk_partner
 var $ttl = 'Disk Partner'
 var $hdr = '| *Dg#*| *Disk*| *Partner*| *Parity*| *Active*|'
 prefix
  call dsp_title($ttl,$hdr)
 set $sql
 {SELECT '| ' ||
 "       grp || '| ' ||
 "       disk || '| ' ||
 "       number_kfdpartner || '| ' ||
 "       parity_kfdpartner || '| ' ||
 "       active_kfdpartner || '|'
 " FROM x$kfdpartner;
 }
 call wrt_report($sql,$ttl)
}

# --- User configuration guide -----------------------------------------

if isTocCreated(true)
 pretoc '%SPLIT%'
else
 pretoc $MNU
pretoc '1+:User Configuration Guide'
debug ' Inside ADBA module, getting user configuration guide'

# unix.rgs file
if isUnix()
{var $fil = catFile($ORACLE_HOME,'install','unix.rgs')
 if ?testFile('r',$fil)
 {report unix_rgs
  prefix
   call dsp_title('unix.rgs File')
  call writeFile($fil)

  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][unix.rgs File]]'
  }
 }

 # Env ulimit
 if ?$shl = shell('SHELL')
 {report env_ulimit
  loop $cmd (concat($shl,' -f -c "ulimit -a"'),\
             'csh -f -c limit',\
             concat($shl,' -f -c ulimit'))
  {prefix
   {call dsp_title('Ulimit')
    write '---## Using: ',encode($cmd)
   }
   break writeCommand($cmd)
  }
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][Ulimit]]'
  }
 }
}

if $ASSESS_ALL
{# Check user security
 report chk_user_security
 var $TTL = 'User Security'

 #Users with default password
 var $ttl = 'Users with Default Password'
 var $hdr = '|*User Name*|'
 prefix
  call dsp_title_header($ttl,$hdr)
 set $sql
 {SELECT '|' ||
  "       name || ' |'
 " FROM sys.user$
 " WHERE password IN ('E066D214D5421CCC',
 "                    '24ABAB8B06281B4C',
 "                    '72979A94BAD2AF80',
 "                    'C252E8FA117AF049',
 "                    'A7A32CD03D3CE8D5',
 "                    '88A2B2C183431F00',
 "                    '7EFA02EC7EA6B86F',
 "                    '4A3BA55E08595C81',
 "                    'F894844C34402B67',
 "                    '3F9FBD883D787341',
 "                    '79DF7A1BD138CF11',
 "                    '7C9BA362F8314299',
 "                    '88D8364765FCE6AF',
 "                    'F9DA8977092B7B81',
 "                    '9300C0977D7DC75E',
 "                    'A97282CE3D94E29E',
 "                    'AC9700FD3F1410EB',
 "                    'E7B5D92911C831E1',
 "                    'AC98877DE1297365',
 "                    '66F4EF5650C20355',
 "                    '84B8CBCA4D477FA3',
 "                    'D4C5016086B2DC6A',
 "                    'D4DF7931AB130E37')
 "   AND astatus = 0
 "   AND (exptime > SYSDATE OR exptime IS NULL)
 " ORDER BY 1;
 }
 call wrt_sql($sql)

 if ${B_LOGINS}
 {# Users with password same as user name or oracle
  set $sql
  {SET serveroutput on size 1000000 FORMAT WRAPPED
  "DECLARE
  " l_cnt NUMBER;
  " l_max dba_profiles.limit%TYPE;
  " l_sta dba_users.account_status%TYPE;
  " l_usr dba_users.username%TYPE;
  " CURSOR c1 IS
  "  SELECT u.username
  "   FROM dba_users u
  "   WHERE u.account_status = 'OPEN'
  "     AND (u.expiry_date > SYSDATE OR u.expiry_date IS NULL);
  "BEGIN
  " FOR r_c1 IN c1
  " LOOP
  "  l_usr := r_c1.username;
  "  SELECT p.limit,
  "         s.lcount,
  "         u.account_status
  "   INTO l_max,
  "        l_cnt,
  "        l_sta
  "   FROM dba_profiles p,dba_users u,user$ s
  "   WHERE u.profile = p.profile
  "     AND s.user# = u.user_id
  "     AND p.resource_name = 'FAILED_LOGIN_ATTEMPTS'
  "     AND u.username = l_usr;
  "  IF l_max = 'DEFAULT'
  "  THEN
  "   SELECT limit
  "    INTO l_max
  "    FROM dba_profiles
  "    WHERE resource_name = 'FAILED_LOGIN_ATTEMPTS'
  "      AND profile = 'DEFAULT';
  "  END IF;
  "  IF l_cnt = 0 OR
  "     l_max = 'UNLIMITED' OR
  "     l_max IS NULL
  "  THEN
  "   dbms_output.put_line('usr=' || l_usr);
  "  ELSIF l_cnt < l_max - 2
  "  THEN
  "   dbms_output.put_line('usr=' || l_usr);
  "  ELSE
  "   dbms_output.put_line('lck=|' || l_usr || ' | ' ||
  "                         l_cnt || '| ' ||
  "                         l_max || '|' ||
  "                         l_sta || ' |');
  "  END IF;
  " END LOOP;
  "END;
  "/
  }
  call loadSql($sql)
  var @lck = grepLastSql('^lck=')
  var @usr = grepLastSql('^usr=')
  var $sql
  loop $usr (@usr)
  {var $usr = value($usr)
   append $sql
   {CONNECT :1/:1
   "SELECT 'usr=' || user FROM dual;
   "CONNECT :1/oracle
   "SELECT 'ora=' || user FROM dual;
   }
   var $sql = bindSql($sql,$usr)
  }
  call loadSql($sql)

  var $ttl = 'Users with Password Same as User Name'
  var $hdr = '|*User Name*|'
  prefix
   call dsp_title_header($ttl,$hdr)
  loop $lin (grepLastSql('usr='))
   write '|',value($lin),'|'
  if hasOutput(true)
   write $TOP
  var $ttl = 'Users with Password "oracle"'
  var $hdr = '|*User Name*|'
  prefix
   call dsp_title_header($ttl,$hdr)
  loop $lin (grepLastSql('ora='))
   write '|',value($lin),'|'
  if hasOutput(true)
   write $TOP

  var $ttl = 'Users not Tested because Account can be Locked in Next Attempt'
  var $hdr = '|*User Name*| *Login Attempts*|*Limit Attempts*|*Account Status*|'
  prefix
   call dsp_title_header($ttl,$hdr)
  loop $lin (@lck)
   write value($lin)
  if hasOutput(true)
   write $TOP

  var $ttl = 'Users not Tested (Password has Expired or Status is not OPEN)'
  var $hdr = '|*User Name*|*Expired Date*|*Account Status*|'
  prefix
   call dsp_title_header($ttl,$hdr)
  set $sql
  {SELECT '|' ||
  "       u.username || ' |' ||
  "       expiry_date || ' |' ||
  "       account_status || ' |'
  " FROM dba_users u
  " WHERE (u.account_status = 'OPEN' AND expiry_date < SYSDATE)
  "    OR u.account_status <> 'OPEN';
  }
  call wrt_sql($sql)
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][User Security]]'
}

# Check all potential risks
test TOOL:TLsecure('ALL')

# --- AWR ---------------------------------------------------------------------

if compare('valid',$DBVER,'100')
{if isTocCreated(true)
  pretoc '%SPLIT%'
 else
  pretoc $MNU
 pretoc '1+:AWR'
 debug ' Inside ADBA module, getting AWR information'

 # AWR information
 var $fil = catFile($ORACLE_HOME,'rdbms','admin','awrinfo.sql')
 if ?testFile('r',$fil)
 {report awr
  prefix
   call dsp_title('AWR Information')
  set $sql
  {SET define on
   "DEFINE REPORT_NAME = :1;
   "DEFINE REPORT_TYPE = 'text';
   "@@:2
  }
  var $tmp = getTemp('awr')
  call loadSql(bindSql($sql,$tmp,$fil),false,2)
  if ?testFile('r',$tmp)
   call writeFile($tmp,['B','rdbms/admin/awrinfo.sql'])
  elsif getSqlMessage()
   write last
  call unlinkTemp('awr')
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][AWR Information]]'
  }
 }
}
unpretoc 2

=head1 SEE ALSO

L<DB:DBinfo|collect::DB:DBinfo>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
