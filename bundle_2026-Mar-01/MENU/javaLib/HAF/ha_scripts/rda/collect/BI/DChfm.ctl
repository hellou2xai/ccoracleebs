# DChfm.ctl:564:Collects Oracle Hyperion Financial Management Information
# $Id: DChfm.ctl,v 1.28 2017/02/15 13:47:14 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DChfm.ctl,v 1.28 2017/02/15 13:47:14 RDA Exp $
#
# Change History
# 20170106  PCW  Bug 25333273 Additional logs collected for HFM

=head1 NAME

BI:DChfm - Collects Oracle Hyperion Financial Management Information

=head1 DESCRIPTION

This module collects information for Oracle Hyperion Financial Management. This
module is applicable for Microsoft Windows and UNIX only.

The following reports can be generated and are regrouped under C<Hyperion
Financial Management>:

=cut

use Type
use Xml

echo tput('bold'),'Processing BI.HFM module ...',tput('off')

# Initialization
var $AGE         = ${R_AGE/T:3}
var $EPM_HOME    = \
  ${GRP.EPM.D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}
var $ORACLE_HOME = ${SET.RDA.BEGIN.D_ORACLE_HOME:''}
var $TAIL        = ${DFT.N_TAIL:1000}

var $MOD = cond(isWindows(),'f',\
                isCygwin(), 'f',\
                            'fx')

var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
toc '1:Hyperion Financial Management'

# Validate the time settings
var $START_TIME = trim(${T_START_TIME:''},'-')
var $END_TIME = trim(${T_END_TIME:''},'-')
var $pat = '^([0-3]\d\-[A-Za-z]{3}\-[12]\d{3}_[0-2]\d:[0-5]\d)?$'
if !match($START_TIME,$pat)
{echo 'Start time format should be DD-Mon-YYYY_HH24:MI. Task audit and \
       HsvEventLog information information will be gathered for the last 14 \
       days.'
 var $START_TIME = ''
}
if !match($END_TIME,$pat)
{echo 'End time format should be DD-Mon-YYYY_HH24:MI. Task audit and \
       HsvEventLog information information will be gathered from ',\
       nvl($START_TIME,'last 14 days'),' to the current time'
 var $END_TIME = ''
}

# Load the common macros
run RDA:library()

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Hyperion Financial Management
home collection.

=cut

debug ' Inside HFM module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Hyperion Financial Management Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 dbver - Generic Database Information

Collects generic information for Hyperion Financial Management from the
Database.

=cut

if ${I_DB}
{var $tgt = last

 # Set the database and domain context
 run DB:DBinfo()
 var $dom = first(values(%{${GRP.EPM.D_DOMAINS}}))
 call setDbTarget({T_TYPE=>        'JDBC',\
                   T_USER=>        $tgt->get_first('T_USER'),\
                   T_SOURCE=>      $tgt->get_first('T_SOURCE'),\
                   D_DOMAIN_HOME=> $dom,\
                   B_SYSDBA=>      $tgt->get_first('B_SYSDBA')})

 # Test the database connection and collect information
 debug ' Inside HFM module, getting generic database information'
 report dbinfo
 write '---+!! Generic Database Information'
 toc '2:[[',getFile(),'][rda_report][Generic Database Information]]'

 if testDb()
 {echo ''
  echo tput('bold'),\
       'The schema containing HFM repository is not accessible.',tput('off')
  if $msg = getDbMessage()
   echo $msg
  echo ''
  write 'HFM repository not accessible (',$msg,')'
 }
 else
 {# Display database provider and version
  write '---+ Database Repository Provider and Version'
  write '|*Database Provider*|*Database Version*|'
  write '|', getDbProvider(),'|',getDbVersion(),'|'

  # Set a constant to true when database is Microsoft SQL Server type
  var $MSS = match(getDbProvider(),'Microsoft SQL Server')

=head2 errorcount - Error Count

Collect the error count for Hyperion Financial Management from the Database.

=cut

  debug ' Inside HFM module, collecting error count'
  report errorcount
  var $TTL = '---+!! Error Log'
  var @TTL = ('',\
              '---+ Error Count')
  var @HDR = ()
  var ($HDR[1],$col) = getDbView({},\
    {fct=>'VRB',val=>'HFM_ErrorLog',hdr=>'*Table Name*'},\
    {fct=>'NUM',val=>'COUNT(1)'    ,hdr=>' *Count*'})
  set $sql
  {# CAPTURE err
  "# SQL1
  "SELECT :1
  " FROM hfm_errorlog
  "/
  "# END
  }
  call separator(1)
  call writeDb(bindDb($sql,$col))
  call separator(0,'Error Log')

=head2 parameters - Parameters Information

Collects C<parameters> information for Hyperion Financial Management from the
Database.

=cut

  debug ' Inside HFM module, collecting parameters information'
  report parameters
  var $TTL = '---+!! Parameters Information'
  var @TTL = ('',\
               '---+ Parameters from XFM_PARAMETERS',\
               '---+ Parameters from XFM_PARAMETERS_DEFAULTS')
  var @HDR = ()
  var ($HDR[1],$col1) = getDbColumns('RDA','XFM_PARAMETERS')
  call clearDbColumns('RDA')
  var ($HDR[2],$col2) = getDbColumns('RDA','XFM_PARAMETERS_DEFAULTS')
  call clearDbColumns('RDA')
  if $col1
  {set $sql
   {# SQL1
   "SELECT :1
   " FROM xfm_parameters
   "/
   "# MACRO separator(2)
   "# SQL2
   "SELECT :2
   " FROM xfm_parameters_defaults
   "/
   }
   call separator(1)
   call writeDb(bindDb($sql,$col1,$col2))
   call separator(0,'Parameters Information')
  }

=head2 taskaudit - Task Audit Information

Collects task audit information for Hyperion Financial Management from the
Database.

=cut

  debug ' Inside HFM module, collecting task audit information'
  report taskaudit

  # Define the DECODE values
  # - Item #72 is the last one for versions later than 11.1.2
  var @DCD = ('ADMINISTRATION',\
              'CELL_HISTORY',\
              'CLOSE_APPLICATION',\
              'CONSOLIDATION',\
              'CREATE_APPLICATION',\
              'DATABASE_MANAGEMENT',\
              'DATA_AUDIT',\
              'DATA_ENTRY_FORMS',\
              'DELETE_APPLICATION',\
              'DOCUMENT_EXTRACT',\
              \
              'DOCUMENTS',\
              'EDIT_INTERCOMPANY_TRANSACTION',\
              'EMPTY_WORKSPACE',\
              'ERROR',\
              'EXPLORE_DATA',\
              'EXTENDED_ANALYTICS',\
              'EXTRACT_DATA',\
              'EXTRACT_JOURNALS',\
              'EXTRACT_MEMBERLISTS',\
              'EXTRACT_METADATA',\
              \
              'EXTRACT_RULES',\
              'EXTRACT_SECURITY',\
              'EXTRACT_TRANSACTIONS',\
              'FAVORITES',\
              'HAL',\
              'HFM',\
              'HOME',\
              'ICTRANS_MATCHING_REPORT_BY_ACCOUNT',\
              'ICTRANS_MATCHING_REPORT_BY_TRANSACTION_ID',\
              'IC_TRANSACTIONS',\
              \
              'JOURNALS',\
              'LINK',\
              'LOAD_DATA',\
              'LOAD_JOURNALS',\
              'LOAD_MEMBERLISTS',\
              'LOAD_METADATA',\
              'LOAD_RULES',\
              'LOAD_SECURITY',\
              'LOAD_TRANSACTIONS',\
              'LOCK_AND_UNLOCK_ENTITIES',\
              \
              'LOGOFF',\
              'LOGON',\
              'MANAGE_GROUPS',\
              'MANAGE_IC_REASON_CODES',\
              'MANAGE_PERIODS',\
              'MANAGE_SERVERS_AND_APPLICATIONS',\
              'MEMBER_SELECTOR',\
              'MONITOR_INTERCOMPANY_TRANSACTIONS',\
              'NEW_INTERCOMPANY_TRANSACTION',\
              'OFFICE_ADDIN',\
              \
              'OWNERSHIP_MANAGEMENT',\
              'PREFERENCES',\
              'PROCESS_CONTROL_PANEL',\
              'PROCESS_INTERCOMPANY_TRANSACTIONS',\
              'PROCESS_MANAGEMENT',\
              'REGISTER_APPLICATION',\
              'REGISTER_SMARTVIEW_PROVIDER',\
              'RELATED_CONTENT',\
              'REPORTS',\
              'RUNNING_TASKS',\
              \
              'SCAN_ICTRANSACTIONS',\
              'SELECT_APPLICATION',\
              'SELECT_CLUSTER',\
              'SYSTEM_MESSAGES',\
              'SYSTEM_MESSAGE_DETAILS',\
              'TASK_AUDIT',\
              'TASK_AUTOMATION',\
              'UNKNOWN',\
              'USERS_ON_SYSTEM',\
              'WEB_DATA_ENTRY_FORM_BUILDER',\
              \
              'WORKSPACE',\
              'WORKSPACE_PREFERENCES',\
              'MANAGE_EPU',\
              'LCM',\
              'MANAGE_TASKFLOWS',\
              'VIEW_TASKFLOW_STATUS',\
              'LOAD_REGIONS',\
              'EXTRACT_REGIONS',\
              'IMPORT_FROM_EXCEL',\
              'NEW_FOLDER',\
              \
              'LOAD_DOCUMENTS',\
              'SAVE_DOCUMENTS',\
              'AUTO_MATCH',\
              'UNMATCH_TRANSACTION',\
              'ICT_FILTER',\
              'SAVE_REPORT_LOCAL',\
              'ICT_REPORT',\
              'MANAGE_IC_PERIODS',\
              'PROCESS_JOURNALS',\
              'MANAGE_JOURNAL_TEMPLATES',\
              \
              'JOURNAL_FILTERS',\
              'EDIT_JOURNAL_PAGE',\
              'EDIT_TEMPLATE_PAGE',\
              'JOURNALS_CREATE_NEW_JOURNAL',\
              'LOAD_LOCAL_REPORT',\
              'JOURNAL_REPORT',\
              'SUBMISSION_PHASE')

  # Transform module name according to the version
  var $lim = \
    cond(defined(testFile('f',catFile(catDir($EPM_HOME,'common',\
                                             'config','9.5.0.0'),\
                                      'epmsys_registry.bat'))),96,72)
  if $MSS
  {var $sub = "CASE CAST(SUBSTRING(strmodulename,LEN(strmodulename) \
               + 2 - CHARINDEX('#',REVERSE(strmodulename)),\
               LEN(strmodulename)) as NUMERIC)"
   for $cnt (0,$lim)
    var $sub = concat($sub,"\012  WHEN ",$cnt," THEN '",$DCD[$cnt],"'")
   var $sub = concat($sub,"\012  ELSE strmodulename END")
  }
  else
  {var $sub = "DECODE(TO_NUMBER(SUBSTR(strmodulename,\
               INSTR(strmodulename,'#',-1) + 1,LENGTH(strmodulename))),"
   for $cnt (0,$lim)
    var $sub = concat($sub,"\012  ",$cnt,",'",$DCD[$cnt],"',")
   var $sub = concat($sub,"\012  strmodulename)")
  }

  # Collect the audit information
  var $col = concatDb("'tab='",'appname')
  set $job
  {# SQL1
  "SELECT :1
  " FROM hsx_datasources
  "/
  }
  var ($cnt,$sql,@TTL,@TXT,@HDR) = (0)
  var $TTL = '---+!! Task Audit Information'

  if $MSS
  {call setDbColumns('RDA','starttime',"REPLACE(CONVERT(VARCHAR(11), \
     CAST('01-JAN-1900' as DATETIME) + starttime - 2,106),' ','-') + ' ' + \
     CONVERT(VARCHAR(8),CAST('01-JAN-1900' as DATETIME) + starttime - 2,114)")
   call setDbColumns('RDA','endtime',"REPLACE(CONVERT(VARCHAR(11), \
     CAST('01-JAN-1900' as DATETIME) + endtime - 2,106),' ','-') + ' ' + \
     CONVERT(VARCHAR(8),CAST('01-JAN-1900' as DATETIME) + endtime - 2,114)")
  }
  else
  {call setDbColumns('RDA','starttime',"TO_CHAR(TO_DATE('01-JAN-1900',\
                     'DD-MON-YYYY') + starttime - 2,'DD-Mon-YYYY HH24:MI:SS')")
   call setDbColumns('RDA','endtime',"TO_CHAR(TO_DATE('01-JAN-1900',\
                     'DD-MON-YYYY') + endtime - 2,'DD-Mon-YYYY HH24:MI:SS')")
  }
  call setDbColumns('RDA','strmodulename',$sub)
  call setDbHeader('RDA','strmodulename','*Module Name*')

  loop $lin (grepDb(bindDb($job,$col),'^tab='))
  {var $tbl = concat(value($lin),'_task_audit')
   call push(@app,value($lin))
   call setDbColumns('RDA','strmodulename',$sub)
   var ($hdr,$col) = getDbColumns('RDA',$tbl)
   if $col
   {incr $cnt
    var $TTL[$cnt] = concat('---+ Task Audit Information from ',$tbl)
    var $HDR[$cnt] = $hdr
    set $str
    {# MACRO separator(:1)
    "# SQL:1
    "SELECT :2
    " FROM :3
    " WHERE :4 + starttime - 2 >= :5
    "   AND :4 + starttime - 2 <= :6
    "/
    }
    if $START_TIME
    {var $beg = cond($MSS,concat("CAST('",replace($START_TIME,'_',' '),\
                                 "' as DATETIME)"),\
                          concat("TO_DATE('",$START_TIME,\
                                 "','DD-Mon-YYYY_HH24:MI')"))
     if $END_TIME
     {var $end = cond($MSS,concat("CAST('",replace($END_TIME,'_',' '),\
                                  "' as DATETIME)"),\
                           concat("TO_DATE('",$ENDT_TIME,\
                                  "','DD-Mon-YYYY_HH24:MI')"))
      var $txt = concat('   * Start time: ``',$START_TIME,\
                  "``\012   * End time: ``",$END_TIME,'``')
     }
     else
     {var $end = cond($MSS,'GETDATE()','SYSDATE')
      var $txt = concat('   * Start time: ``',$START_TIME,\
                  "``\012   * End time: Current time")
     }
    }
    else
    {var $beg = cond($MSS,'GETDATE() - 14','SYSDATE - 14')
     var $end = cond($MSS,'GETDATE()','SYSDATE')
     var $txt = '   * From last day'
    }
    var $whr = cond($MSS,"CAST('01-JAN-1900' as DATETIME)",\
                         "TO_DATE('01-JAN-1900','DD-MON-YYYY')")
    var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$tbl,$whr,$beg,$end))
    var $TXT[$cnt] = $txt
   }
   call clearDbColumns('RDA')
  }
  call separator(1)
  call writeDb($sql)
  call separator(0,'Task Audit Information')

=head2 metadata - Metadata Statistics

Collects metadata statistics information for Hyperion Financial Management from
the Database.

=cut

  debug ' Inside HFM module, collecting metadata statistics'
  report metadata
  var ($cnt,$grp,$sql,@GRP,@HDR,@TTL,@TXT,%GRP) = (0,0)
  var $TTL = '---+!! Metadata Statistics'
  code write_header
  {var ($sep) = last
   return join("\012",delete($GRP{$GRP[$sep]}),$ttl[$sep])
  }
  loop $app (@app)
  {var $GRP{incr($grp)} = concat('---+ Metadata Statistics for ',$app)
   var $ttl[incr($cnt)] = '---++ Number of Rows in Tables'
   var $GRP[$cnt] = $grp
   var $TTL[$cnt] = &write_header(eval:$cnt)
   set $str
   {# MACRO separator(:1)
   }
   var $sql = join("\012",$sql,bindDb($str,$cnt))
   loop $typ ('_ACCOUNT_ITEM','_CURRENCIES','_CUSTOM1_ITEM','_CUSTOM2_ITEM',\
              '_CUSTOM3_ITEM','_CUSTOM4_ITEM','_ENTITY_ITEM','_ICP_ITEM',\
              '_SCENARIO_ITEM')
   {var $tbl = concat($app,$typ)
    if getDbColumns('RDA',$tbl)
    {var ($HDR[$cnt],$col) = getDbView({},\
       {fct=>'VRB',val=>$tbl,      hdr=>'*Table Name*'},\
       {fct=>'NUM',val=>'COUNT(1)',hdr=>' *Count*'})
     set $str
     {# SQL:1
     "SELECT :2
     " FROM :3
     "/
     }
     var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$tbl))
    }
    call clearDbColumns('RDA')
   }

   # Get children counts
   loop $dim ('ACCOUNT','CUSTOM1','CUSTOM2','CUSTOM3','CUSTOM4','ENTITY',\
              'SCENARIO')
   {var $tbl = concat($app,'_',$dim)
    var $ttl[incr($cnt)] = concat(\
             '---++ Number of Children for a Given Parent for ',$tbl)
    var $GRP[$cnt] = $grp
    var $TTL[$cnt] = &write_header(eval:$cnt)
    var $lay = concat($tbl,'_layout')
    var $itm = concat($tbl,'_item')
    var ($HDR[$cnt],$col) = getDbView({a=>$lay,b=>$itm},\
      {fct=>'VRB',val=>$app,               hdr=>'*Application*'},\
      {fct=>'VRB',val=>$dim,               hdr=>'*Dimension*'},\
      {fct=>'SEL',tid=>'a',col=>'parentid',hdr=>' *Parent ID*'},\
      {fct=>'SEL',tid=>'b',col=>'label',   hdr=>'*Parent Label*'},\
      {fct=>'NUM',tid=>'a',val=>'kount',   hdr=>' *Children*'})
    if $col
    {set $str
     {# MACRO separator(:1)
     "# CAPTURE dim
     "# SQL:1
     "SELECT :2
     " FROM (SELECT p.parentid parentid,
     "              COUNT(c.parentid) kount
     "        FROM :3 p
     "        LEFT OUTER JOIN :3 c ON p.parentid = c.itemid
     "        GROUP BY p.parentid) a
     " LEFT OUTER JOIN :4 b ON a.parentid = b.itemid
     "/
     "# END
     }
     var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$lay,$itm))
    }
    call clearDbColumns('a')
    call clearDbColumns('b')
   }
  }
  call writeDb($sql)
  call separator(0,'Metadata Statistics')



=for stopwords CalcRules

=head2 calcrules - CalcRules Information

Collects C<CalcRules> information for Hyperion Financial Management from the
Database.

=cut

  debug ' Inside HFM module, collecting CalcRules information'
  report calcrules
  title '---+!! CalcRules Information'
  title $TOC
  if $MSS
   var $col = concatDb('CAST(BINARYFILE AS VARCHAR (2000))',"'|'")
  else
   var $col = concatDb('UTL_RAW.CAST_TO_VARCHAR2(BINARYFILE)',"'|'")
  loop $app (@app)
  {var $tbl = concat($app,'_BINARYFILES')
   set $job
   {# SQL1
   "SELECT :1
   " FROM :2
   " WHERE label = 'CalcRules'
   " ORDER BY entryidx
   "/
   }
   if loadDb(bindDb($job,$col,$tbl))
   {var ($beg,@buf) = ()
    loop $lin (getDbLines(),'')
    {if ?$beg
     {var $lin = concat($beg,$lin)
      var $beg = undef
     }
     if match($lin,'\000\|$')
      var $beg = substr($lin,0,-1)
     else
      call push(@buf,$lin)
    }
    if scalar(@buf)
    {write concat('---+ CalcRules Information from ',$tbl)
     write '|*Content:*|%NOWRAP%^^',\
       join('%BR%',map(convertUtf16(join("\012",@buf)),code(encode(last)))),\
       '^^|'
     write $TOP
    }
   }
  }
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][CalcRules Information]]'

=for stopwords MemberListRules

=head2 memberlistrules - MemberListRules Information

Collects C<MemberListRules> information for Hyperion Financial Management from
the Database.

=cut

  debug ' Inside HFM module, collecting memberlistrules information'
  report memberlistrules
  title '---+!! MemberListRules Information'
  title $TOC
  if $MSS
   var $col = concatDb('CAST(BINARYFILE AS VARCHAR (2000))',"'|'")
  else
   var $col = concatDb('UTL_RAW.CAST_TO_VARCHAR2(BINARYFILE)',"'|'")
  loop $app (@app)
  {var $tbl = concat($app,'_BINARYFILES')
   set $job
   {# SQL1
   "SELECT :1
   " FROM :2
   " WHERE label = 'MemberListRules'
   " ORDER BY entryidx
   "/
   }
   if loadDb(bindDb($job,$col,$tbl))
   {var ($beg,@buf) = ()
    loop $lin (getDbLines(),'')
    {if ?$beg
     {var $lin = concat($beg,$lin)
      var $beg = undef
     }
     if match($lin,'\000\|$')
      var $beg = substr($lin,0,-1)
     else
      call push(@buf,$lin)
    }
    if scalar(@buf)
    {write concat('---+ MemberListRules Information from ',$tbl)
     write '|*Content:*|%NOWRAP%^^',\
       join('%BR%',map(convertUtf16(join("\012",@buf)),code(encode(last)))),\
       '^^|'
     write $TOP
    }
   }
  }
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][MemberListRules Information]]'

=head2 currency - Currency Information

Collects C<currency> information for Hyperion Financial Management from
the Database.

=cut

  debug ' Inside HFM module, collecting currency information'
  report currency
  var ($cnt,$grp,$sql,@GRP,@HDR,@TTL,@TXT,%GRP) = (0,0)
  var $TTL = '---+!! Currency Information'
  loop $app (@app)
  {var $GRP{incr($grp)} = concat('---+ Currency Information for ',$app)
   loop $tab ('_CURRENCIES','_CURRENCIES_DESC','_CURRENCIES_HEADER')
   {var $tbl = concat($app,$tab)
    var ($hdr,$col) = getDbColumns('RDA',$tbl)
    if $col
    {var $ttl[incr($cnt)] = concat('---++ Information from ',$tbl)
     var $GRP[$cnt] = $grp
     var $TTL[$cnt] = &write_header(eval:$cnt)
     var $HDR[$cnt] = $hdr
     set $str
     {# MACRO separator(:1)
     "# SQL:1
     "SELECT :2
     " FROM :3
     "/
     }
     var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$tbl))
    }
    call clearDbColumns('RDA')
   }
  }
  call writeDb($sql)
  call separator(0,'Currency Information')

=head2 dataanalysis - Data Analysis

When requested, performs a data analysis for a specific application.

=cut

  if ${B_ANALYZE}
  {var $APPNAME    = ${T_APPNAME}
   var $START_YEAR = ${T_START_YEAR}
   var $END_YEAR   = ${T_END_YEAR}

   if !grep(@app,concat('^',verbatim($APPNAME),'$'),'if')
   {echo 'Application name is not found in the list of applications.'
    echo 'The data analysis is skipped'
   }
   elsif or(not(match($START_YEAR,'^[1-2]\d{3}$')),\
            not(match($END_YEAR,  '^[1-2]\d{3}$')))
   {echo 'Year is not in a four-digit format.'
    echo 'The data analysis is skipped'
   }
   elsif expr('<',$END_YEAR,$START_YEAR)
   {echo 'End year should be greater than start year.'
    echo 'The data analysis is skipped'
   }
   else
   {# Perform the data analysis
    report dataanalysis
    var ($sql,@HDR,@TTL,@TXT) = ()
    var $TTL = concat('---+!! Data Analysis for ',$APPNAME)
    var $TTL[1] = '---++ Number of rows in tables'
    set $sql
    {# CAPTURE aud
    }
    loop $typ ('_DATA_AUDIT','_TASK_AUDIT','_PFLOW','_ICT_PERIODS',\
               '_ICT_REASONCODES','_ICT_TRANSACTIONS','_ICT_VERSION')
    {var $tbl = concat($APPNAME,$typ)
     var ($HDR[1],$col) = getDbView({a=>$tbl},\
       {fct=>'VRB',val=>$tbl,      hdr=>'*Table Name*'},\
       {fct=>'NUM',val=>'COUNT(1)',hdr=>' *Count*'})
     if $col
     {set $str
      {# SQL1
      "SELECT :1
      " FROM :2
      "/
      }
      var $sql = join("\012",$sql,bindDb($str,$col,$tbl))
     }
     call clearDbColumns('a')
    }
    append $sql
    {# END
    }

    # Analyze table content per item and next per year
    var $tbl = concat($APPNAME,'_SCENARIO_ITEM')
    var $col = concatDb("'itm='",cond($MSS,'CAST(itemid as VARCHAR)',\
                                           'itemid'))
    set $job
    {# SQL1
    "SELECT :1
    " FROM :2
    "/
    }
    var @itm
    loop $lin (grepDb(bindDb($job,$col,$tbl),'^itm='))
    {call push(@itm,$itm = value($lin))
     for $yea ($START_YEAR,$END_YEAR)
     {loop $typ ('_RTD_','_RTS_','_PFLOW_','_CSE_','_CSN_','_DCT_','_ETX_',\
                 '_LID_','_TXT_','_TXTITEM_')
      {var $tbl = concat($APPNAME,$typ,$itm,'_',$yea)
       var (undef,$col) = getDbView({a=>$tbl},\
         {fct=>'VRB',val=>$tbl,      hdr=>'*Table Name*'},\
         {fct=>'NUM',val=>'COUNT(1)',hdr=>' *Count*'})
       if $col
       {set $str
        {# SQL1
        "SELECT :1
        " FROM :2
        "/
        }
        var $sql = join("\012",$sql,bindDb($str,$col,$tbl))
       }
       call clearDbColumns('a')
      }
     }
    }

    # Analyze data structure per item and next per year
    var $cnt = 2
    loop $itm (@itm)
    {for $yea ($START_YEAR,$END_YEAR)
     {# Analyze DCE table
      incr $cnt
      var $tbl = concat($APPNAME,'_dce_',$itm,'_',$yea)
      var $TTL[$cnt] = concat('---++ Data from ',$tbl)
      var ($HDR[$cnt],$col) = getDbView({a=>$tbl},\
        {fct=>'VRB',val=>$tbl,              hdr=>'*Table Name*'},\
        {fct=>'SEL',tid=>'a',col=>'lentity',hdr=>'*Entity*'},\
        {fct=>'SEL',tid=>'a',col=>'lvalue', hdr=>'*Value*'},\
        {fct=>'NUM',val=>'COUNT(1)',        hdr=>' *Count*'})
      if $col
      {set $str
       {# CAPTURE dce
       "# MACRO separator(:1)
       "# SQL:1
       "SELECT :2
       " FROM :3 a
       " GROUP BY a.lentity, a.lvalue
       "/
       "# END
       }
       var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$tbl))

       incr $cnt
       var $TTL[$cnt] = '---+++ Number of Groups'
       var ($HDR[$cnt],$col) = getDbView({},\
         {fct=>'VRB',val=>$tbl,           hdr=>'*Table Name*'},\
         {fct=>'VRB',val=>'Entity, Value',hdr=>'*Group By*'},\
         {fct=>'NUM',val=>'COUNT(1)',     hdr=>' *Number of Group Records*'})
       set $str
       {# MACRO separator(:1)
       "# SQL:1
       "SELECT :2
       " FROM (SELECT lentity, lvalue
       "        FROM :3
       "        GROUP BY lentity, lvalue) a
       " HAVING COUNT(1) > 0
       "/
       }
       var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$tbl))
      }
      call clearDbColumns('a')

      # Analyze DCN table
      incr $cnt
      var $tbl = concat($APPNAME,'_dcn_',$itm,'_',$yea)
      var $TTL[$cnt] = concat('---++ Data from ',$tbl)
      var ($HDR[$cnt],$col) = getDbView({a=>$tbl},\
        {fct=>'VRB',val=>$tbl,              hdr=>'*Table Name*'},\
        {fct=>'SEL',tid=>'a',col=>'lentity',hdr=>'*Entity*'},\
        {fct=>'SEL',tid=>'a',col=>'lparent',hdr=>'*Parent*'},\
        {fct=>'SEL',tid=>'a',col=>'lvalue', hdr=>'*Value*'},\
        {fct=>'NUM',val=>'COUNT(1)',        hdr=>' *Count*'})
      if $col
      {set $str
       {# CAPTURE dcn
       "# MACRO separator(:1)
       "# SQL:1
       "SELECT :2
       " FROM :3 a
       " GROUP BY a.lentity, a.lparent, a.lvalue
       "/
       "# END
       }
       var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$tbl))
       call clearDbColumns('a')

       incr $cnt
       var $TTL[$cnt] = '---+++ Number of Groups'
       var ($HDR[$cnt],$col) = getDbView({},\
         {fct=>'VRB',val=>$tbl,      hdr=>'*Table Name*'},\
         {fct=>'VRB',val=>'Entity, Parent, Value',\
                                     hdr=>'*Group By*'},\
         {fct=>'NUM',val=>'COUNT(1)',hdr=>' *Number of Group Records*'})
       set $str
       {# MACRO separator(:1)
       "# SQL:1
       "SELECT :2
       " FROM (SELECT lentity, lparent, lvalue
       "        FROM :3
       "        GROUP BY lentity, lparent, lvalue) a
       " HAVING COUNT(1) > 0
       "/
       }
       var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$tbl))
      }
      call clearDbColumns('a')

      # Analyze CSE table
      incr $cnt
      var $tbl = concat($APPNAME,'_cse_',$itm,'_',$yea)
      var $TTL[$cnt] = concat('---++ Data from ',$tbl)
      var ($HDR[$cnt],$col) = getDbView({a=>$tbl},\
        {fct=>'VRB',val=>$tbl,              hdr=>'*Table Name*'},\
        {fct=>'SEL',tid=>'a',col=>'lentity',hdr=>'*Entity*'},\
        {fct=>'NUM',val=>'COUNT(1)',        hdr=>' *Count*'})
      if $col
      {set $str
       {# CAPTURE cse
       "# MACRO separator(:1)
       "# SQL:1
       "SELECT :2
       " FROM :3 a
       " GROUP BY a.lentity
       "/
       "# END
       }
       var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$tbl))
       call clearDbColumns('a')

       incr $cnt
       var $TTL[$cnt] = '---+++ Number of Groups'
       var ($HDR[$cnt],$col) = getDbView({},\
         {fct=>'VRB',val=>$tbl,      hdr=>'*Table Name*'},\
         {fct=>'VRB',val=>'Entity',  hdr=>'*Group By*'},\
         {fct=>'NUM',val=>'COUNT(1)',hdr=>' *Number of Group Records*'})
       set $str
       {# MACRO separator(:1)
       "# SQL:1
       "SELECT :2
       " FROM (SELECT lentity
       "        FROM :3
       "        GROUP BY lentity) a
       " HAVING COUNT(1) > 0
       "/
       }
       var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$tbl))
      }
      call clearDbColumns('a')
      incr $cnt

      # Analyze CSN table
      incr $cnt
      var $tbl = concat($APPNAME,'_csn_',$itm,'_',$yea)
      var $TTL[$cnt] = concat('---++ Data from ',$tbl)
      var ($HDR[$cnt],$col) = getDbView({a=>$tbl},\
        {fct=>'VRB',val=>$tbl,              hdr=>'*Table Name*'},\
        {fct=>'SEL',tid=>'a',col=>'lentity',hdr=>'*Entity*'},\
        {fct=>'SEL',tid=>'a',col=>'lparent',hdr=>'*Parent*'},\
        {fct=>'NUM',val=>'COUNT(1)',        hdr=>' *Count*'})
      if $col
      {set $str
       {# CAPTURE csn
       "# MACRO separator(:1)
       "# SQL:1
       "SELECT :2
       " FROM :3 a
       " GROUP BY a.lentity, a.lparent
       "/
       "# END
       }
       var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$tbl))
       call clearDbColumns('a')

       incr $cnt
       var $TTL[$cnt] = '---+++ Number of Groups'
       var ($HDR[$cnt],$col) = getDbView({},\
         {fct=>'VRB',val=>$tbl,            hdr=>'*Table Name*'},\
         {fct=>'VRB',val=>'Entity, Parent',hdr=>'*Group By*'},\
         {fct=>'NUM',val=>'COUNT(1)',      hdr=>' *Number of Group Records*'})
       set $str
       {# MACRO separator(:1)
       "# SQL:1
       "SELECT :2
       " FROM (SELECT lentity, lparent
       "        FROM :3
       "        GROUP BY lentity, lparent) a
       " HAVING COUNT(1) > 0
       "/
       }
       var $sql = join("\012",$sql,bindDb($str,$cnt,$col,$tbl))
      }
      call clearDbColumns('a')
     }
    }
    call separator(1)
    call writeDb($sql)
    call separator(0,'Data Analysis')
   }
  }

=head2 validate - Validation

Collects validation information for the following conditions:

=over 3

=item o C<HFM_ErrorLog> table has more than 200000 records.

=item o C<ENTITY> dimension has more than 500 child records.

=item o C<ACCOUNT> dimension has more than 1000 child records.

=item o C<DATA_AUDIT> and C<TASK_AUDIT> tables have more than 200000 records.

=item o C<DCE> tables have more than 100000 group records.

=item o C<DCN> tables have more than 100000 group records.

=item o C<CSE> tables have more than 100000 group records.

=item o C<CSN> tables have more than 100000 group records.

=back

=cut

  report validate
  title '---+!! Validation Information'
  title $TOC

  if grepDbBuffer('err','HFM_ErrorLog')
  {prefix
   {write '---++ Error Count Validation'
    write '   * Reports when the HFM_ErrorLog table has more than 200000 \
                records'
    write '|*Table Name*| *Count*|'
   }
   var ($lin) = (last)
   var $cnt = field('\|',2,$lin)
   if expr('>=',$cnt,200000)
    write $lin
   if hasOutput(true)
    write $TOP
  }
  call clearDbBuffer('err')

  prefix
  {write '---++ Dimension Count Validation'
   write '   * Reports the application and dimension details when'
   write '      * ENTITY dimension has more than 500 child records'
   write '      * ACCOUNT dimension has more than 1000 child records'
   write '|*Application*|*Dimension*| *Parent ID*|*Parent Label*| *Children*|'
  }
  loop $lin (grepDbBuffer('dim','ACCOUNT|ENTITY'))
  {var $dim = trim(field('\|',2,$lin))
   if compare('eq',$dim,'ACCOUNT')
    var $val = 1000
   elsif compare('eq',$dim,'ENTITY')
    var $val = 500
   else
    next
   var $cnt = field('\|',5,$lin)
   if expr('>=',$cnt,$val)
    write $lin
  }
  if hasOutput(true)
   write $TOP
  call clearDbBuffer('dim')

  prefix
  {write '---++ Audit Table Count Validation'
   write '   * Reports when the DATA_AUDIT and TASK_AUDIT tables have more \
               than 200000 records'
   write '|*Table Name*| *Count*|'
  }
  loop $lin (grepDbBuffer('aud','_(DATA|TASK)_AUDIT'))
  {var $tbl = field('\|',1,$lin)
   if match($tbl,'_(DATA|TASK)_AUDIT$')
   {var $cnt = field('\|',2,$lin)
    if expr('>=',$cnt,200000)
     write $lin
   }
  }

  prefix
  {write '---++ DCE Tables'
   write '   * Reports when the DCE tables have more than 100000 group records'
   write '|*Table Name*|*Entity*|*Value*| *Count*|'
  }
  loop $lin (grepDbBuffer('dce','\|'))
  {var $cnt = field('\|',4,$lin)
   if expr('>=',$cnt,100000)
    write $lin
  }
  if hasOutput(true)
   write $TOP
  call clearDbBuffer('dce')

  prefix
  {write '---++ DCN Tables'
   write '   * Reports when the DCN tables have more than 100000 group records'
   write '|*Table Name*|*Entity*|*Parent*|*Value*| *Count*|'
  }
  loop $lin (grepDbBuffer('dcn','\|'))
  {var $cnt = field('\|',5,$lin)
   if expr('>=',$cnt,100000)
    write $lin
  }
  if hasOutput(true)
   write $TOP
  call clearDbBuffer('dcn')

  prefix
  {write '---++ CSE Tables'
   write '   * Reports when the CSE tables have more than 100000 group records'
   write '|*Table Name*|*Entity*| *Count*|'
  }
  loop $lin (grepDbBuffer('cse','\|'))
  {var $cnt = field('\|',3,$lin)
   if expr('>=',$cnt,100000)
    write $lin
  }
  if hasOutput(true)
   write $TOP
  call clearDbBuffer('cse')

  prefix
  {write '---++ CSN Tables'
   write '   * Reports when the CSN tables have more than 100000 group records'
   write '|*Table Name*|*Entity*|*Parent*| *Count*|'
  }
  loop $lin (grepDbBuffer('csn','\|'))
  {var $cnt = field('\|',4,$lin)
   if expr('>=',$cnt,100000)
    write $lin
  }
  if hasOutput(true)
   write $TOP
  call clearDbBuffer('csn')

  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Validation]]'
 }
}

=head2 registry - Registry Information

Collects Windows registry information.

=cut

if or(isWindows(),isCygwin())
{debug ' Inside HFM module, gathering registry information'
 report registry
 title '---+!! Registry Information'
 title $TOC
 if hasRegOption()
 {prefix
   write '---+ Hyperion Financial Management 64-Bit Registry Settings'
  if writeRegistry64('HKLM\SOFTWARE\Hyperion Solutions')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\ORACLE\HFM')
   write $TOP
  if writeRegistry64('HKCU\Software\Hyperion Solutions\\
                      Hyperion Financial Management')
   write $TOP
  prefix
   write '---+ Hyperion Financial Management 32-Bit Registry Settings'
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Solutions')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\ORACLE\HFM')
   write $TOP
  if writeRegistry32('HKCU\Software\Hyperion Solutions\\
                      Hyperion Financial Management')
   write $TOP
  unprefix
 }
 else
 {prefix
   write '---+ Hyperion Financial Management Registry Settings'
  if writeRegistry('HKLM\SOFTWARE\Hyperion Solutions')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\ORACLE\HFM')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\ORACLE\HFM')
   write $TOP
  if writeRegistry('HKCU\Software\Hyperion Solutions\\
                    Hyperion Financial Management')
   write $TOP
  unprefix
 }
 prefix
  write '---+ ASP.NET Registry Information'
 if writeRegistry('HKLM\SOFTWARE\Microsoft\ASP.NET\2.0.50727.0')
  write $TOP
 prefix
  write '---+ Remote Procedure Call (RPC) Registry Information'
 if writeRegistry('HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Rpc')
  write $TOP
 prefix
  write '---+ TCP/IP Registry Information'
 if writeRegistry('HKLM\SYSTEM\currentcontrolset\services\tcpip\Parameters')
  write $TOP
 prefix
  write '---+ Data Access Registry Information'
 if writeRegistry('HKLM\SOFTWARE\Microsoft\DataAccess')
  write $TOP
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Registry Information]]'

=head2 eventx - HFM Events

Extracts Hyperion Financial Management events from the application event log
using the F<wevtutil> command. (Only available for Windows Vista,
Windows Server 2008, and Windows 7)

=cut

 debug ' Inside HFM module, gathering event log information'
 var $osv = getRegValue('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion',\
                        'CurrentVersion')
 if compare('valid',$osv,'6')
 {if ?findCommand('wevtutil')
  {var $evt = last
   var $msc = expr('*',$AGE,86400000)
   var $tmp = getTemp('dat')
   call command(concat($evt,' qe Application ',\
         '"/q:*[System[TimeCreated[timediff(@SystemTime) <= ',$msc,\
         ']]]" /f:xml >',$tmp))
   code write_data
   {loop $lin (parseBuffer())
     write replace(replace($lin,'&lt;','<',true),'&gt;','>',true)
   }
   report eventx
    write '---+!! Hyperion Financial Management Events'
   prefix
    call beginBlock(true)
   if createBuffer('EVT','R',$tmp)
   {call parseReset()
    call parseBegin('TOP','^<Event.*<System>\
       <Provider Name=.*?(HFMWebServiceManager|\
                          Hyperion Financial Management|\
                          Hyperion S9 Financial Management Service|\
                          HyS9FinancialManagementWebSvcs).*/>','Event')
    call parseEnd('Event','.*</Event>$')
    call parseInfo('Event','buf',-1)
    call parseInfo('Event','end',&write_data)
    call parseInfo('Event','llp',false)
    call parse('EVT')
    call deleteBuffer('EVT')
   }
   if hasOutput(true)
    call endBlock(['C','wevtutil qe Application | grep -i \
      HFMWebServiceManager|\
      Hyperion Financial Management|\
      Hyperion S9 Financial Management Service|\
      HyS9FinancialManagementWebSvcs'])
   else
    write '**No Hyperion Financial Management events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][HFM Events]]'
   call unlinkTemp('dat')
  }
 }

=head2 events - HFM Events

Extracts Hyperion Financial Management events from the application event log.
(Only available for Windows NT, Windows 2000, Windows XP, and Windows 2003)

=cut

 else
 {# Get the event file
  var $fil = replaceEnv(\
    getRegValue('HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application',\
                'File'))

  # If the file is not readable try to copy to a temporary file
  var $flg = false
  if ?testFile('r',$fil)
   var $evt = $fil
  else
  {if ?testFile('f',$cmd = getGroupFile('D_CWD','cmd.exe'))
   {var $cmd = quote($cmd)
    if grepCommand(concat($cmd,' /c if exist mode.com echo 32to64'),'^32to64')
    {var $flg = true
     var $evt = getTemp('evt','.evt')
     call system(concat($cmd,' /c copy ',quote($fil),' ',$evt,' >NUL 2>NUL'))
    }
   }
  }

  # Extract the Hyperion Financial Management events
  if ?testFile('r',$evt)
  {report events
   write '---+ Application Events'
   if !writeEvents($evt,'(HFMWebServiceManager|\
                          Hyperion Financial Management|\
                          Hyperion S9 Financial Management Service|\
                          HyS9FinancialManagementWebSvcs)',$AGE)
    write '**No Hyperion Financial Management events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][HFM Events]]'
  }
  if $flg
   call unlinkTemp('evt')
 }
}

=head2 Configuration Files

Gets configuration files.

=cut

debug ' Inside HFM module, gathering configuration files'
pretoc '2:Configuration Files'
call sort_files(3,0,\
  catFile($EPM_HOME,'products','FinancialManagement','logging',\
          'InteropLogging.xml'),\
  catFile($EPM_HOME,'products','FinancialManagement','logging','logging.xml'),\
  catFile($EPM_HOME,'products','FinancialManagement','Server','setHfmEnv.sh'),\
  catFile($EPM_HOME,'products','FinancialManagement','Utilities',\
          'HFMAuditExtractSchemaDefs.xml'),\
  catFile($EPM_HOME,'products','FinancialManagement','Utilities',\
          'HFMErrorLogViewer_x64.xml'))
unpretoc

=head2 iiscfg - IIS Configuration Files

Gathers Internet Information Services (IIS) configuration files on Windows.
This is applicable for IIS 7 only.

=cut

if or(isWindows(),isCygwin())
{if getEnv('SYSTEMROOT')      # Get SystemRoot
  var $dir = last
 else
  var ($dir) = command('echo %SystemRoot%')

 # Get IIS version
 var $ver = cond(hasRegOption(),\
   nvl(getReg64Value('HKLM\SOFTWARE\Microsoft\InetMgr\Parameters',\
                     'MajorVersion'),\
       getReg32Value('HKLM\SOFTWARE\Microsoft\InetMgr\Parameters',\
                     'MajorVersion')),\
   nvl(getRegValue('HKLM\SOFTWARE\Microsoft\InetMgr\Parameters',\
                   'MajorVersion'),\
       getRegValue('HKLM\SOFTWARE\Wow6432Node\Microsoft\InetMgr\Parameters',\
                   'MajorVersion')))
 if ?$ver
  var $ver = hex2dec(last)

 if expr('==',$ver,7)
 {debug ' Inside HFM module, gathering IIS configuration files'
  pretoc '2:Configuration Files'
  call sort_files(3,0,\
    catFile($dir,'system32','inetsrv','config','Administration.conf'),\
    catFile($dir,'system32','inetsrv','config','ApplicationHost.config'),\
    catFile($dir,'system32','inetsrv','config','web.config'),\
    catFile($EPM_HOME,'products','FinancialManagement','Web',\
            'HFMApplicationService','web.config'),\
    catFile($EPM_HOME,'products','FinancialManagement','Web','HFMLCMService',\
            'web.config'),\
    catFile($EPM_HOME,'products','FinancialManagement','Web',\
            'HFMOfficeProvider','web.config'),\
    grepDir(catDir(getEnv('SystemDrive','C:'),'inetpub','logs','LogFiles'),\
            '^web\.config$','dr'))
  unpretoc
 }

=head2 iislog - IIS Log Files

Gathers recent Internet Information Services (IIS) log files on Windows. This
is applicable for IIS version 6 or 7 only.

=cut

 debug ' Inside HFM module, gathering recent IIS log files'

 # Determine the IIS log directory
 var $log
 if expr('==',$ver,6)
 {if ?nvl(testFile('r',catFile($dir,'system32','inetsrv','MetaBase.xml')),\
          testFile('r',catFile($dir,'Sysnative','inetsrv','MetaBase.xml')))
  {var $xml = xmlLoadFile(last,xmlDisable(xmlParser(),'DR'))
   if $xml->find('.../IIsWebServer')->get_value('LogFileDirectory')
    var $log = catDir(last,'W3SVC1')
   elsif $xml->find('.../IIsWebService')->get_value('LogFileDirectory')
    var $log = catDir(last,'W3SVC1')
  }
  elsif ?testFile('f',$cmd = getGroupFile('D_CWD','cmd.exe'))
  {var $fil = catFile($dir,'system32','inetsrv','MetaBase.xml')
   var $xml = xmlLoadCommand(concat(quote($cmd),' /c type ',quote($fil)),\
              xmlDisable(xmlParser(),'DR'))
   if $xml->find('.../IIsWebServer')->get_value('LogFileDirectory')
    var $log = catDir(last,'W3SVC1')
   elsif $xml->find('.../IIsWebService')->get_value('LogFileDirectory')
    var $log = catDir(last,'W3SVC1')
  }
  if !$log
  {if ?nvl(testDir('d',catDir($dir,'system32','LogFiles','W3SVC1')),\
           testDir('d',catDir($dir,'Sysnative','LogFiles','W3SVC1')))
   var $log = last
  }
 }
 elsif expr('==',$ver,7)
 {if ?nvl(testFile('r',catFile($dir,'system32','inetsrv',\
                               'Applicationhost.config')),\
          testFile('r',catFile($dir,'Sysnative','inetsrv',\
                               'Applicationhost.config')),\
          testFile('r',catFile($dir,'system32','inetsrv','config',\
                               'Applicationhost.config')),\
          testFile('r',catFile($dir,'Sysnative','inetsrv','config',\
                               'Applicationhost.config')))
  {var $xml = xmlLoadFile(last,xmlDisable(xmlParser(),'DR'))
   if $xml->find('.../logFile')->get_value('directory')
    var $log = catDir(replaceEnv(last))
   elsif $xml->find('.../log/centralW3CLogFile')->get_value('directory')
    var $log = catDir(replaceEnv(last))
   if ?testDir('d',catDir($log,'W3SVC1'))
    var $log = lastDir()
  }
  elsif ?testFile('f',$cmd = getGroupFile('D_CWD','cmd.exe'))
  {loop $fil (catFile($dir,'system32','inetsrv','Applicationhost.config'),\
     catFile($dir,'system32','inetsrv','config','Applicationhost.config'))
   {var $xml = xmlLoadCommand(concat(quote($cmd),' /c type ',quote($fil)),\
               xmlDisable(xmlParser(),'DR'))
    next xmlStatCommand()
    if $xml->find('.../log/centralW3CLogFile')->get_value('directory')
     var $log = catDir(replaceEnv(last))
    elsif $xml->find('.../logFile')->get_value('directory')
     var $log = catDir(replaceEnv(last))
    if ?testDir('d',catDir($log,'W3SVC1'))
     var $log = lastDir()
    break
   }
  }
  if !$log
  {if ?nvl(testDir('d',catDir($dir,'system32','inetpub','logs','LogFiles')),\
           testDir('d',catDir($dir,'Sysnative','inetpub','logs','LogFiles')))
   var $log = last
  }
 }

 # Collect recent log files
 if $log
 {report iislog
  prefix
  {write '---+!! IIS Log Files'
   write '---## From: ',$log
   write '   * Limited to last ',$AGE,' days'
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               risks. To prevent them, access the file outside the browser or \
               use the link to save them and use an adequate viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  loop $fil (grepDir($log,'\.log$','ipt'))
  {break isOlder($fil,$AGE)
   var $lnk = encode($fil)
   var $siz = getSize($fil)
   if $siz
   {output => d,concat('L_',basename($fil))
    if ${CUR.O_LAST}->write_tail($fil,$TAIL)
     var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,']]')
    end ${CUR.O_LAST}
   }
   write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
  }
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][IIS Log Files]]'
 }

=head2 ruleslog - Rules Log Files

Collects the rules log files based on the key F<SystemPath> from
F<HKLM\SOFTWARE\Hyperion Solutions\Hyperion Financial Management\Server>
registry.

=cut

 pretoc '2: Rules Log Files'
 var $dir = cond(hasRegOption(),\
   nvl(getReg64Value('HKLM\SOFTWARE\Hyperion Solutions\\
                      Hyperion Financial Management\Server','SystemPath'),\
       getReg32Value('HKLM\SOFTWARE\Hyperion Solutions\\
                      Hyperion Financial Management\Server','SystemPath')),\
   nvl(getRegValue('HKLM\SOFTWARE\Hyperion Solutions\\
                    Hyperion Financial Management\Server','SystemPath'),\
       getRegValue('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions\\
                    Hyperion Financial Management\Server','SystemPath')))
 if ?testDir('d',$dir)
 {loop $app (@app)
  {report concat('ruleslog_',$app)
   var $log = catDir($dir,concat($app,'_RulesLogFiles'))
   prefix
   {write '---+!! Rules Log Files'
    write '---## From: ',$log
    write '   * Last ',$TAIL,' lines from the log files captured'
    write '   * Links point to files that have been collected in their \
                original format. Opening them directly in your browser can \
                present risks. To prevent them, access the file outside the \
                browser or use the link to save them and use an adequate \
                viewer.'
    write '|*File Name*| *Size*|*Last Modified Date*|'
   }
   loop $fil (grepDir($log,'\.log$','irt'))
   {var $lnk = encode($fil)
    var $siz = getSize($fil)
    if $siz
    {output => d,concat('L_',basename($fil))
     if ${CUR.O_LAST}->write_tail($fil,$TAIL)
      var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,\
                        ']]')
     end ${CUR.O_LAST}
    }
    write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
   }
   if isCreated(true)
    toc '3:[[',getFile(),'][rda_report][For ',$app,']]'
  }
 }
 unpretoc
}

=head2 Log Files

Gets log files.

=cut

debug ' Inside HFM module, gathering log files'
pretoc '2:Log Files'
call sort_files(3,$TAIL,grepDir(\
  catDir($EPM_HOME,'products','FinancialManagement','logging'),'\.log$','np'))
unpretoc

=head2 filetype - File Type Information

Collects the file type of executable files in several Hyperion Financial
Management program directories inside the F<$EPM_HOME> directory structure.

=cut

debug ' Inside HFM module, gathering file type information'
report filetype
title  '---+!! File Type Information'
title $TOC
var ($dir,@dir) = (catDir($EPM_HOME,'products','FinancialManagement'))
loop $sub ('Common','Client','ConsultantUtilities','install\config','Server',\
           'Server\lib','Utilities','Utilities\ApplicationToolbox',\
           'Web\HFMApplicationService\bin','Web\HFMLCMService\bin',\
           'Web\HFMOfficeProvider\bin','Web\WebServer','WebServices')
{if ?testDir('d',catDir($dir,$sub))
  call push(@dir,lastDir())
}
if ?testDir('d',catDir($EPM_HOME,'products','financialreporting','bin'))
 call push(@dir,lastDir())
loop $dir (@dir)
{prefix
 {write '---+ Files from ',encode($dir)
  write '|*File Name*|*Type*|'
 }
 if or(isWindows(),isCygwin())
  var ($pat,$opt) = ('\.(exe|dll)$','in')
 else
  var ($pat,$opt) = ('^\.+$','nv')
 loop $fil (grepDir($dir,$pat,$opt))
 {if ?testFile($MOD,catFile($dir,$fil))
   write '|',$fil,'|',nvl(file(lastTestFile(),true),'N/A'),' |'
 }
 write $TOP
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][File Type Information]]'

=head2 Executable, Library, and Java Archive Versions

Collects the executable, library, and Java archive versions from
F<$EPM_HOME/FinancialManagement> and
F<$EPM_HOME/products/FinancialManagement> directory structures. When
F<unzip> is available, it extracts the manifest from Java archives.

=cut

debug ' Inside HFM module, gathering file versions'
pretoc '2:Executable, Library, and Java Archive Versions'

macro dsp_versions
{var ($rpt,$lvl,$dir,$opt,$dpt) = @arg
 import $EPM_HOME,$TOC,$TOP,$UNZIP
 keep $EPM_HOME,$TOC,$TOP,$UNZIP

 call $[OUT]->add_report('C',$rpt,0)
 prefix
 {write '---+!! Version Information from ',encode($dir),' Directory'
  write $TOC
 }
 loop $fil (grepDir(catDir($EPM_HOME,$dir),\
                    '\.(a|asp|ass|cs|css|dll|exe|jar|js|ocx|so|xml|xslt)$',\
                    $opt,$dpt))
 {write '---+ Version Information from ',encode(basename($fil))
  call statFile('p',$fil)
  write '%BR%'
  if or(isWindows(),isCygwin())
  {var $inf = getVersionInfo($fil)
   loop $key (keys($inf))
    write '|*',$key,' *|',replace($inf->{$key},'\012','%BR%',true),' |'
  }
  write $TOP
  if and(match($fil,'\.jar$',true),$UNZIP)
  {prefix
    write '---++ Manifest Information'
   var $cmd = concat($UNZIP,' -p ',quote($fil),' META-INF/MANIFEST.MF')
   call writeCommand($cmd)
   if hasOutput(true)
    write $TOP
  }
 }
 if isCreated(true)
  toc $lvl,':[[',getFile(),'][rda_report][In ',encode($dir),']]'
}

var $UNZIP = findCommand('unzip')

pretoc '3:$EPM_HOME/HyperFinancialManagement'
var $cnt = 0
call dsp_versions('ver_fin',4,'FinancialManagement','dip')
loop $sub (grepDir(catDir($EPM_HOME,'FinancialManagement'),'^\.+$','nv'))
{if ?testDir('d',catDir($EPM_HOME,'FinancialManagement',$sub))
  call dsp_versions(concat('ver_fin',incr($cnt)),4,\
                    catDir('FinancialManagement',$sub),'dir')
}
unpretoc

pretoc '3:$EPM_HOME/products/FinancialManagement'
var $cnt = 0
call dsp_versions('ver_prd',4,catDir('products','FinancialManagement'),'dip')
loop $sub (grepDir(catDir($EPM_HOME,'products','FinancialManagement'),\
                   '^\.+$','nv'))
{if ?testDir('d',catDir($EPM_HOME,'products','FinancialManagement',$sub))
  call dsp_versions(concat('ver_prd_fin',incr($cnt)),4,\
                    catDir('products','FinancialManagement',$sub),'dir',\
                    check(lc($sub),'web',10,8))
}
unpretoc 2

=head2 oraoledb - Oracle Provider for OLE DB

Gets Oracle Provider for OLE DB versions.

=cut

if or(isWindows(),isCygwin())
{debug ' Inside HFM module, getting Oracle OLE DB versions'

 # Scan registry to get all Oracle Homes
 var @hom = ()
 if hasRegOption()
 {loop $hom (grepReg64Value('HKLM\SOFTWARE\ORACLE','ORACLE_HOME'))
   call push(@hom,getReg64Value($hom,'ORACLE_HOME'))
  if !@hom
  {loop $hom (grepReg32Value('HKLM\SOFTWARE\ORACLE','ORACLE_HOME'))
    call push(@hom,getReg32Value($hom,'ORACLE_HOME'))
  }
 }
 else
 {loop $hom (grepRegValue('HKLM\SOFTWARE\ORACLE','ORACLE_HOME'))
   call push(@hom,getRegValue($hom,'ORACLE_HOME'))
  if !@hom
  {loop $hom (grepRegValue('HKLM\SOFTWARE\Wow6432Node\ORACLE','ORACLE_HOME'))
    call push(@hom,getRegValue($hom,'ORACLE_HOME'))
  }
 }

 # Produce the report
 report oraoledb
 title '---+!! Oracle Provider for OLE DB Versions'
 loop $hom (@hom)
 {var ($fil) = (grepDir(catDir($hom,'bin'),\
                       '^oraoledb(1[012])?\.dll$','ip'))
  if ?testFile('f',$fil)
  {write '---++ From ',encode($fil)
   call statFile('b',$fil)
   write '%BR%'
   var $inf = getVersionInfo($fil)
   loop $key (keys($inf))
    write '|*',replace($key,'\012','',true),' *|',\
               replace($inf->{$key},'\012','',true),' |'
  }
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Oracle Provider for OLE DB]]'

=head2 cssxml - CSS.xml File

Collects the CSS.xml file in use. It first tries to get the information from
the registry entry C<ConnectionInfo>. Otherwise, it looks successively in the
F<%WINDIR%\Temp> and F<%HOMEPATH%\Localsettings\Temp> directory. This is
applicable for versions 9.3.1 to 11.1.1.3 only.

=cut

 var $url = cond(hasRegOption(),\
   nvl(getReg64Value('HKLM\SOFTWARE\Hyperion Solutions\\
                      Hyperion Financial Management\Server\Authentication',\
                     'ConnectionInfo'),\
       getReg32Value('HKLM\SOFTWARE\Hyperion Solutions\\
                      Hyperion Financial Management\Server\Authentication',\
                     'ConnectionInfo')),\
   nvl(getRegValue('HKLM\SOFTWARE\Hyperion Solutions\\
                    Hyperion Financial Management\Server\Authentication',\
                   'ConnectionInfo'),\
       getRegValue('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions\\
                    Hyperion Financial Management\Server\Authentication',\
                   'ConnectionInfo')))
 var $req = createRequest('GET',$url)
 var $rsp = submitRequest($req)
 report cssxml
 if isSuccess($rsp)
 {prefix
  {write '---+!! CSS.xml File in Use'
   write '---## Using: ',encode($url)
   write '<verbatim>'
  }
  call writeResponse($rsp)
  if hasOutput(true)
   write '</verbatim>'
 }
 elsif ?nvl(testFile('r',catFile(${ENV.WINDIR:''},'Temp','CSS.xml')),\
            testFile('r',catFile(${ENV.HOMEPATH:''},'Localsettings','Temp',\
                                 'CSS.xml')))
 {var $fil = last
  prefix
  {write '---+!! CSS.xml File in Use'
   write '---## From ',encode($fil)
   write '  * This is a cache version and may not be the version currently in \
              use.'
  }
  call writeFile($fil)
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][CSS.xml File]]'
}

=for stopwords procstate

=head2 procstate - Process State

For UNIX, collects process information for C<xfmdatasource> processes.

=cut

if isUnix()
{debug ' Inside HFM module, getting process information'
 if ?nvl(testFile('x','/bin/ps'),testFile('x','/usr/bin/ps'))
 {var $cmd = concat(last,' auxww')
  report procstate
  prefix
  {write '---+ xfmdatasource Processes State'
   write '---## Information Taken from Running ',encode($cmd)
   call beginBlock(true)
   write getHeader()
  }
  loop $lin (grepCommand($cmd,'xfmdatasource','i'))
   write $lin
  if isCreated(true)
  {call endBlock(['C',concat($cmd,' | grep -i xfmdatasource')])
   toc '2:[[',getFile(),'][rda_report][xfmdatasource Processes State]]'
  }
 }
}

=head2 version - Version Information

Collects the latest version information from the
F<$EPM_HOME/logs/hfm/HsvEventLog.log> file (on versions earlier than 11.1.2).

=cut

if !@ins = ${CUR.O_MODULE}->search('^OI')
{debug ' Inside HFM module, getting version information'
 report version
 prefix
 {write '---+ Applications Version'
  write '---## Information Taken from ',encode(lastFile())
  write '   * Only latest version reported'
  write '|*File Name*|*Version*|'
 }
 var %ver = ()
 if ?testFile('f',catFile($EPM_HOME,'logs','hfm','HsvEventLog.log'))
 {var $hsv = lastFile()
  loop $lin (grepFile($hsv,\
                      '^<EStr'))
  {if match($lin,'.*<File>(.*)</File>.*<Ver>(.*)</Ver>.*')
   {var ($key,$val) = last
    var $ver{$key} = $val
   }
  }
 }
 loop $key (keys(%ver))
  write '|',$key,' |',replace($ver{$key},'\.','&#46;',true),' |'
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Version Information]]'

=head2 hsvevent - HsvEventLog File

Collects the F<$EPM_HOME/logs/hfm/HsvEventLog.log> file
(on versions earlier than 11.1.2).

=cut

 debug ' Inside HFM module, gathering HsvEventLog file'
 if createBuffer('HSV','R',$hsv)
 {# Determine the time interval
  if $START_TIME
  {var ($day,$mon,$yea,$hou,$min,$sec) = split('[\-\_\:]',$START_TIME)
   var $beg = mktime($sec,$min,$hou,$day,$mon,$yea)
   if $END_TIME
    var ($day,$mon,$yea,$hou,$min,$sec) = split('[\-\_\:]',$END_TIME)
   else
    var ($day,$mon,$yea,$hou,$min,$sec) = split('[\-\_\: ]',getLocalTime())
   var $end = mktime($sec,$min,$hou,$day,$mon,$yea)
   var $max = difftime($end,$beg)
  }
  else
  {var ($day,$mon,$yea,$hou,$min,$sec) = split('[\-\_\: ]',getLocalTime())
   var $end = mktime($sec,$min,$hou,$day,$mon,$yea)
   var $max = 1209600
  }

  # Extract relevant fragment
  report hsvevent
  prefix
  {write '---+ HsvEventLog File'
   write '---## Information Extracted from ',encode($hsv)
   call beginBlock(true)
  }
  var $flg = false
  while ?getLine('HSV')
  {var $lin = chomp(last)
   if match($lin,'^<EStr.*<DTime>(.*)</DTime>.*')
   {var ($cur) = last
    if match($cur,'^\d+\.\d+\.\d+\s+\d+:')
     var ($day,$mon,$yea,$hou,$min,$sec,$hlf) = split('[\.\: ]',$cur)
    else
     var ($mon,$day,$yea,$hou,$min,$sec,$hlf) = split('[\/\_\: ]',$cur)
    decr $mon
    if compare('eq',$hou,'12')
     decr $hou,12
    if compare('eq',$hlf,'PM')
     incr $hou,12
    var $dur = difftime($end,mktime($sec,$min,$hou,$day,$mon,$yea))
    break expr('<',$dur,0)
    if expr('<=',$dur,$max)
    {var $flg = true
     write $lin
    }
   }
   elsif $flg
    write $lin
  }
  if isCreated(true)
  {call endBlock(['F',$hsv,'P','T'])
   toc '2:[[',getFile(),'][rda_report][HsvEventLog File]]'
  }
  call deleteBuffer('HSV')
 }

=for stopwords interopJava

=head2 inopjava - interopJava.log File

Collects the F<$EPM_HOME/logs/hfm/interopJava.log> file
(on versions earlier than 11.1.2).

=cut

 debug ' Inside HFM module, gathering interopJava.log file'
 report inopjava
 if ?testFile('f',catFile(catDir($EPM_HOME,'logs','hfm'),'interopJava.log'))
 {call tail_file(lastDir(),'interopJava.log',$TAIL)
  if isCreated()
   toc '2:[[',getFile(),'][rda_report][interopJava.log File]]'
 }

=for stopwords SharedServices

=head2 sssecclt - SharedServices_Security_Client.log File

Collects the F<$EPM_HOME/logs/hfm/SharedServices_Security_Client.log> file
(on versions earlier than 11.1.2).

=cut

 debug ' Inside HFM module, gathering SharedServices_Security_Client.log file'
 report sssecclt
 if ?testFile('f',catFile(catDir($EPM_HOME,'logs','hfm'),\
                         'SharedServices_Security_Client.log'))
 {call tail_file(lastDir(),'SharedServices_Security_Client.log',$TAIL)
  if isCreated()
   toc '2:[[',getFile(),\
       '][rda_report][SharedServices_Security_Client.log File]]'
 }

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain (on versions earlier than 11.1.2 having a product registry).

=cut

 if ?${GRP.EPM.D_DOMAIN}
 {var $dom = basename(last)
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
  toc '%INCLUDE("OFM_WREQ_BI_HFM_WH_TF.toc")%'
  toc '%POP2%'
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:',"'",$dom,"'",' Domain")%'
  toc '%INCLUDE("OFM_WREQ_BI_HFM_DOM_TF.toc")%'
  toc '%POP2%'
 }
}

=head1 DEPLOYMENT REPORTS

Available on version 11.1.2 and later.

=cut

else
{var $CNT = 0
 loop $itm (@ins)
 {var ($ins,$uid) = ($itm->get_first('D_HOME'),$itm->get_oid)
  call setSymbol('$EPM_INSTANCE',$ins)
  call setPrefix(concat($PRE,'i',incr($CNT)))
  toc '%SPLIT%'
  toc "1+:'",basename($ins),"' Deployment"

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Hyperion Financial Management
instance collection.

=cut

  debug ' Inside HFM module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Hyperion Financial Management Instance Abbreviations'
   write '|*Abbreviation*|*Location*|'
  }
  var %hsh = getSymbols()
  loop $key (keys(%hsh))
   write '|',$key,' |',$hsh{$key},' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 Version Information

Collects the latest version information from the
F<$INSTANCE_HOME/diagnostics/logs/hfm/HsvEventLog.log> file.

=cut

  debug ' Inside HFM module, getting version information'
  report version
  prefix
  {write '---+ Applications Version'
   write '---## Information Taken from ',encode(lastFile())
   write '   * Only latest version reported'
   write '|*File Name*|*Version*|'
  }
  var %ver = ()
  var $hsv = undef
  if ?testFile('f',catFile($ins,'diagnostics','logs','hfm','HsvEventLog.log'))
  {var $hsv = lastFile()
   loop $lin (grepFile($hsv,\
                       '^<EStr'))
   {if match($lin,'.*<File>(.*)</File>.*<Ver>(.*)</Ver>.*')
    {var ($key,$val) = last
     var $ver{$key} = $val
    }
   }
  }
  loop $key (keys(%ver))
   write '|',$key,' |',replace($ver{$key},'\.','&#46;',true),' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Version Information]]'

=head2 Start Scripts

Collects the start scripts from the F<$INSTANCE_HOME/bin> directory.

=cut

  debug ' Inside HFM module, getting instance start scripts'
  pretoc '2:Start Scripts'
  call sort_files(3,0,catFile($ins,'bin','deploymentScripts',\
                              ${AS.BAT:'setCustomParamsFMWebServices'}))
  unpretoc

=head2 core_analysis - Core Dump Analysis

For UNIX, it analyzes core dumps present in the F<$INSTANCE_HOME/bin> directory.

=cut

  if isUnix()
  {if @dmp = grepDir(catDir($ins,'bin'),'(^core|.*xfmdatasource.*\.core)','ip')
   {debug ' Inside HFM module, analyzing core dumps'

    # Include the core analyzer on first use
    if !isImplemented('can_analyze_core')
     run OS:COREinfo()

    # When a debugger is found, analyze the core dumps
    if can_analyze_core()
    {var $dbg = last
     report core_analysis
     write '---+!! Core Dump Stack Trace Extraction'
     write '---## Using: ',$dbg
     write $TOC
     call analyze_core(@dmp)
     if isCreated(true)
      toc '2:[[',getFile(),'][rda_report][Core Dump Analysis]]'
    }
   }
  }

=head2 transfer_files - File Transfer Data Files

List the files present in the
F<$INSTANCE_HOME/products/FinancialManagement/FileTransferData> directory tree.

=cut

  debug ' Inside HFM module, listing transfer files'
  report transfer_files
  var $dir = catDir($ins,'products','FinancialManagement','FileTransferData')
  title '---+ File Transfer Data Files Listing'
  title '---+ Information from ',encode($dir)
  loop $sub (findDir([$dir],'^\.+$','drv'))
  {prefix
    write '---++ Files from ',encode($sub)
   call statFile('b',grepDir(catDir($dir,$sub),'^\.+$','pnv'))
   if hasOutput(true)
    write $TOP
  }
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][File Transfer Data Files Listing]]'

=for stopwords HsvEventLog

=head2 HsvEventLog File

Collects the F<$INSTANCE_HOME/diagnostics/logs/hfm/HsvEventLog.log> file.

=cut

  debug ' Inside HFM module, gathering HsvEventLog file'
  if createBuffer('HSV','R',$hsv)
  {# Determine the time interval
   if $START_TIME
   {var ($day,$mon,$yea,$hou,$min,$sec) = split('[\-\_\:]',$START_TIME)
    var $beg = mktime($sec,$min,$hou,$day,$mon,$yea)
    if $END_TIME
     var ($day,$mon,$yea,$hou,$min,$sec) = split('[\-\_\:]',$END_TIME)
    else
     var ($day,$mon,$yea,$hou,$min,$sec) = split('[\-\_\: ]',getLocalTime())
    var $end = mktime($sec,$min,$hou,$day,$mon,$yea)
    var $max = difftime($end,$beg)
   }
   else
   {var ($day,$mon,$yea,$hou,$min,$sec) = split('[\-\_\: ]',getLocalTime())
    var $end = mktime($sec,$min,$hou,$day,$mon,$yea)
    var $max = 1209600
   }

   # Extract relevant fragment
   report hsvevent
   prefix
   {write '---+ HsvEventLog File'
    write '---## Information Extracted from ',encode($hsv)
    call beginBlock(true)
   }
   var $flg = false
   while ?getLine('HSV')
   {var $lin = chomp(last)
    if match($lin,'^<EStr.*<DTime>(.*)</DTime>.*')
    {var ($cur) = last
     if match($cur,'^\d+\.\d+\.\d+\s+\d+:')
      var ($day,$mon,$yea,$hou,$min,$sec,$hlf) = split('[\.\: ]',$cur)
     else
      var ($mon,$day,$yea,$hou,$min,$sec,$hlf) = split('[\/\_\: ]',$cur)
     decr $mon
     if compare('eq',$hou,'12')
      decr $hou,12
     if compare('eq',$hlf,'PM')
      incr $hou,12
     var $dur = difftime($end,mktime($sec,$min,$hou,$day,$mon,$yea))
     break expr('<',$dur,0)
     if expr('<=',$dur,$max)
     {var $flg = true
      write $lin
     }
    }
    elsif $flg
     write $lin
   }
   if isCreated(true)
   {call endBlock(['F',$hsv,'P','T'])
    toc '2:[[',getFile(),'][rda_report][HsvEventLog File]]'
   }
   call deleteBuffer('HSV')
  }

=head2 Configuration Files

Collects the logging configuration files from the F<$INSTANCE_HOME/config> and
F<$INSTANCE_HOME/products/FinancialManagement> directory.

=cut

  debug ' Inside HFM module, getting the logging configuration files'
  pretoc '2:Configuration Files'
  call sort_files(3,0,\
    catFile($ins,'config','hfm','configom.properties'),\
    catFile($ins,'products','FinancialManagement','logging',\
            'InteropLogging.xml'),\
    catFile($ins,'products','FinancialManagement','logging','HsxServer',\
            'logging.xml'),\
    catFile($ins,'products','FinancialManagement','logging','xfmdatasource',\
            'logging.xml'))
  unpretoc

=head2 Configuration Files

Collects additional configuration files their original format from the
F<$INSTANCE_HOME/products/FinancialManagement> directory.

=cut

  debug ' Inside HFM module, getting the additional configuration binary files'
  report additional_bin
  var $fil = catFile($ins,'products','FinancialManagement','Server',\
                     '.RunningDatasourcesInfo')
  prefix
  {write '---+ Additional Configuration Files'
   write '   * Links point to files that have been collected in their \
               original format. Opening them directly in your browser can \
               present risks. To prevent them, access the file outside the \
               browser or use the link to save them and use an adequate \
               viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  var $nam = basename($fil)
  var $siz = getSize($fil)
  var $lnk = encode($fil)
  if $siz
  {var $rpt = $[OUT]->add_report('b',concat('b_',$nam),0,'_bin')
   if $rpt->write_data($fil)
    var $lnk = concat('[[',$rpt->get_raw(true),'][_blank][',$lnk,']]')
   end $rpt
  }
  write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Additional Configuration Files]]'

=head2 diaglogs - Diagnostic Log Files

Collects the diagnostic log files from the F<$INSTANCE_HOME/diagnostics/logs>
directory.

=cut

  debug ' Inside HFM module, getting the diagnostic log files'
  report diaglogs
  var $log = catDir($ins,'diagnostics','logs')
  var %pat = (\
    config => ['hfm-registercomcommon','hfm-registercomweb'],\
    install  => [\
      'hfm-cacls-filetransfer-stderr','hfm-cacls-filetransfer-stdout',\
      'hfm-cacls-lcmservice-stderr','hfm-cacls-lcmservice-stdout',\
      'hfm-registerclientdlls64','hfm-registerclientdlls',\
      'hfm-registercommondlls','hfm-registerdlladmclient-stderr',\
      'hfm-registerdlladmclient-stdout','hfm-registerdllclient-stderr',\
      'hfm-registerdllclient-stdout','hfm-registerdllcommon-stderr',\
      'hfm-registerdllcommon-stdout','hfm-registerserverdlls',\
      'hfm-regWinHttpErr','hfm-regWinHttpOut',\
      'hfmsvcs-regAsyncCallback-stderr','hfmsvcs-regAsyncCallback-stdout',\
      'hfm-updatereg-stderr','hfm-updatereg-stdout'],\
    scripts => ['jrfws-async-createUDDs-HFMWeb'],\
    services => [\
      'HyS9FinancialManagementJavaServer-syserr',\
      'HyS9FinancialManagementJavaServer-sysout',\
      'HyS9FinancialManagementWebSvcs-syserr',\
      'HyS9FinancialManagementWebSvcs-sysout',\
      'HyS9FinancialManagementWeb-sysout','HyS9FinancialManagementWeb-syserr'],\
    starter => [\
      'startHsxServer.sh',\
      'start-HFMWebServiceManager-out',\
      'start-HyS9FinancialManagementWebSvcs-out',\
      'stop-HFMWebServiceManager-out',\
      'stop-HyS9FinancialManagementWebSvcs-out',\
      'start-HyperionS9FinancialManagementDMEListener-out',\
      'start-HyperionS9FinancialManagementService-out',\
      'stop-HyperionS9FinancialManagementService-out',\
      'stop-HyperionS9FinancialManagementDMEListener-out'],\
    upgrades => ['HFMApplicationUpgrade'])
  prefix
  {write '---+!! Diagnostic Log Files'
   write '---## From: ',$log
   if $TAIL
    write '   * Last ',$TAIL,' lines from the log files captured'
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               risks. To prevent them, access the file outside the browser or \
               use the link to save them and use an adequate viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  loop $sub ('config','hfm','install','scripts','services','starter','upgrades')
  {loop $fil (grepDir(catDir($log,$sub),\
     cond(exists($pat{$sub}),concat('^(',join("|",@{$pat{$sub}}),')\.log$'),\
                             '(\.log$|\.Log$)'),'pt'))
   {var $lnk = encode($fil)
    var $siz = getSize($fil)
    if $siz
    {output => d,concat('L_',basename($fil))
     if cond($TAIL,${CUR.O_LAST}->write_tail($fil,$TAIL),\
                   ${CUR.O_LAST}->write_data($fil))
      var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),\
                        '][_blank][',$lnk,']]')
     end ${CUR.O_LAST}
    }
    write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
   }
  }
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Diagnostic Log Files]]'

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain.

=cut

  if ${CUR.O_SETUP}->search(concat('^WREQ_BI_HFM_',replace($uid,'^OI','DOM')))
  {var ($req) = last
   var $dom = $req->get_first('I_DOMAIN')
   var $oid = $dom->get_first('I_WL_HOME')->get_oid
   var $nam = $dom->get_first('T_DOMAIN_NAME')
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
   toc '%INCLUDE("OFM_WREQ_BI_HFM_',$oid,'_TF.toc",1)%'
   toc '%POP2%'
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:',"'",$nam,"'",' Domain")%'
   toc '%INCLUDE("OFM_',$req->get_oid,'_TF.toc",1)%'
   toc '%POP2%'
  }

  # Restore module prefix
  call setPrefix($PRE)
 }
}

=head1 SEE ALSO

L<DB:DBinfo|collect::DB:DBinfo>,
L<OFM:DCwreq|collect::OFM:DCwreq>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
