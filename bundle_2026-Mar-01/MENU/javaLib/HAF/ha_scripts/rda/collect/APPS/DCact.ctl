# DCact.ctl:500:Collects Oracle E-Business Suite Application Information
# $Id: DCact.ctl,v 1.13 2016/02/24 12:22:55 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/DCact.ctl,v 1.13 2016/02/24 12:22:55 RDA Exp $
#
# Change History
# 20160224  PCW  Fixed taint error in JDBC Version section

=head1 NAME

APPS:DCact - Collects Oracle Applications Information

=head1 DESCRIPTION

This module collects basic information for a specified list of Oracle
Applications products and for a specified user and responsibility.

The following reports can be generated and are regrouped under C<ACT>:

=cut

echo tput('bold'),'Processing APPS.ACT module ...',tput('off')

# Initialization
var $ORACLE_HOME = ${SET.RDA.BEGIN.D_ORACLE_HOME:''}
var $ORACLE_SID  = ${SET.DB.DB.T_ORACLE_SID/P:${ENV.ORACLE_SID}}

var $APPL_DB_SID   = ${T_DB_SID}
var $APPL_LOGIN_ID = ${T_LOGIN_ID}
var $APPL_LOGIN_PW = ${T_LOGIN_PW}
var $APPL_TOP      = ${D_TOP:''}
var $RDA           = ${B_RDA_FORMAT:false}
var $RESP_ID       = ${N_RESP_ID:20420}
var $USER_ID       = ${N_USER_ID}
var $USER_NAME     = ${T_USER_NAME:'SYSADMIN'}
var @SHORT         = @{T_SHORTS}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
var $TTL = undef
pretoc '1:ACT'

# Define some global variables
var %ADCONFIG   = ()
var %ALL_IDS    = ()
var %ALL_NAMES  = ()
var $DB_ACCESS  = true
var $FILTERED   = isFiltered()
var $MULTI_NODE = true
var $REL107     = false
var $REL110     = false
var $REL115     = false
var $REL120     = false
var $REL121     = false

# Include common macros
run APPS:APPSinfo()

# Define the file formating macro
macro act_file
{if or(isWindows(),isCygwin())
 {var $off = scalar(@arg)
  while $off
  {decr $off
   if match($arg[$off],'^\$(.*)$')
    var $arg[$off] = concat('%',last,'%')
  }
 }
 return catFile(@arg)
}

# Define the separator macro
macro act_separator
{var ($cur) = @arg
 import $RDA,$TOC,$TOP,$TTL,@TTL,@HDR
 keep $cur,$sep,$RDA,$TOC,$TOP,$TTL,@TTL,@HDR
 if $cur
 {if expr('>',$cur,1)
  {if hasOutput(true)
    write $TOP
  }
  var $sep = $cur
  prefix
  {if $TTL
   {write $TTL
    if $RDA
     write $TOC
    var $TTL = undef
   }
   if $TTL[$sep]
    write $TTL[$sep]
   if $HDR[$sep]
    write $HDR[$sep]
  }
 }
 else
 {if getSqlMessage()
   write last,'%BR%'
  if hasOutput(true)
   write $TOP
 }
}

# Define the report control macros
macro act_anchor
{var ($rpt,$ttl) = @arg

 return concat('[[#',$rpt,'][',$ttl,']]')
}

macro act_report
{var ($rpt,$ttl) = @arg
 import $RDA
 keep $RDA

 if $RDA
 {report $rpt
  if $ttl
   write '---+!! ',$ttl
 }
 elsif $ttl
  write '---+ ',$ttl
}

macro act_toc
{var ($ttl) = @arg
 import $RDA,$TOC
 keep $RDA,$TOC

 if $RDA
 {if $ttl
   write '---+!! ',$ttl
  write $TOC
 }
}

macro act_menu
{var ($lvl,$txt,$flg) = @arg
 import $RDA,$TOP
 keep $RDA,$TOP

 if $RDA
 {if isCreated(true)
   toc $lvl,':[[',getFile(),'][rda_report][',$txt,']]'
 }
 elsif $flg
  write $TOP
}

macro act_title
{var ($str) = @arg
 import $RDA,$TOC
 keep $RDA,$TOC

 return cond($RDA,concat('---+!! ',$str,"\012",$TOC),concat('---+ ',$str))
}

# Initiate the report
debug ' Inside ACT, generating report ...'
report report

# Get the environment
if !${ENV.APPLFENV}
{# Source the environment file
 if or(isWindows(),isCygwin())
  var $env = catFile($APPL_TOP,'APPSORA.cmd')
 else
  var $env = catFile($APPL_TOP,'APPSORA.env')
 call sourceContext($env)

 # Check if the environment is now set
 if !${ENV.APPLFENV}
 {echo tput('bold'),'Application environment must be set up before running \
       this script',tput('off')
  return
 }
}

# Get some key environment variables
var $AD_TOP          = ${ENV.AD_TOP:''}
var $FND_TOP         = ${ENV.FND_TOP:''}
var $IAS_ORACLE_HOME = ${ENV.IAS_ORACLE_HOME:''}
var $INST_TOP        = ${ENV.INST_TOP:''}
var $IZU_TOP         = ${ENV.IZU_TOP:''}
var $JAVA_TOP        = ${ENV.JAVA_TOP:''}
var $OA_HTML         = ${ENV.OA_HTML:''}
var $OA_JAVA         = ${ENV.OA_JAVA:''}
var $OAD_TOP         = ${ENV.OAD_TOP:''}
var $OAH_TOP         = ${ENV.OAH_TOP:''}
var $TNS_ADMIN       = ${ENV.TNS_ADMIN:\
                              catDir($ORACLE_HOME,'network','admin')}

# When not defined, derive the database SID from environment variables
if !$APPL_DB_SID
 var $APPL_DB_SID  = ${ENV.TWO_TASK:${ENV.LOCAL:$ORACLE_SID}}

# Determine the 'adident' syntax
if or(isWindows(),isCygwin())
 var $cmd = 'adident.exe'
else
 var $cmd = 'adident'
if ?testFile('f',catFile($AD_TOP,'bin',$cmd))
{var $ADIDENT = catCommand($AD_TOP,'bin','adident')
 if grepCommand(concat($ADIDENT,' 2>&1'),'adident id_pattern','f')
  var $ADIDENT=concat($ADIDENT,' Header')
}
else
 var $ADIDENT = undef

# Determine which tier files are present
var $fil = catFile($APPL_TOP,'admin','adconfig.txt')
if loadFile($fil)
{# Parse the config file
 var ($tok,$val,%tbl) = (0,0)
 loop $lin (getLines())
 {if match($lin,'%%START_OF_TOKEN%%')
   var ($tok,$val) = (1,0)
  elsif match($lin,'%%START_OF_VALUE%%')
   var ($tok,$val) = (0,1)
  elsif match($lin,'%%END_OF_.*%%')
   var ($tok,$val) = (0,0)
  elsif $tok
   var ($tok,$key) = (0,trim($lin))
  elsif $val
   var ($val,$ADCONFIG{$key}) = (0,trim($lin))
 }

 # Determine the tier presence
 var $TIER_ADMIN = compare('eq','YES',uc($ADCONFIG{'TIER_ADMIN'}))
 var $TIER_FORMS = compare('eq','YES',uc($ADCONFIG{'TIER_FORMS'}))
 var $TIER_NODE  = compare('eq','YES',uc($ADCONFIG{'TIER_NODE'}))
 var $TIER_WEB   = compare('eq','YES',uc($ADCONFIG{'TIER_WEB'}))
 var @TIERS = ()
 if $TIER_ADMIN
  call push(@TIERS,'Admin')
 if $TIER_WEB
  call push(@TIERS,'Web')
 if $TIER_FORMS
  call push(@TIERS,'Forms')
 if $TIER_NODE
  call push(@TIERS,'Concurrent')
 var $TIERS = join(', ',@TIERS)
}
else
{var $TIERS = 'N/A (adconfig.txt file does not exist)'
 var $TIER_ADMIN = true
 var $TIER_WEB = true
 var $TIER_FORMS = true
 var $TIER_NODE = true
}

# Try resolving the apps un/pw from the wdbsvr.app file (only on Web tier)
if and($TIER_WEB,match($FND_TOP,'(11\.5\.0$|12\.0\.0$)'))
{if match($FND_TOP,'12\.0\.0')
  var $XML_FILE = catFile($INST_TOP,'appl','admin',\
                          concat($APPL_DB_SID,'_',${RDA.T_NODE},'.xml'))
 else
  var $XML_FILE = catFile($APPL_TOP,'admin',\
                          concat($APPL_DB_SID,'_',${RDA.T_NODE},'.xml'))
 if or(isWindows(),isCygwin())
 {if ?testFile('r',$XML_FILE)
  {# Extract the start command from the configuration file
   var $xml = xmlLoadFile($XML_FILE)
   var $cmd = xmlData(xmlFind($xml,'.../start_cmd oa_var="s_apcstart"'))
  }
  else
  {# Extract the start command from the registry (MSC: Must verify on a box)
   var $cmd = ''
   var $reg = 'HKLM\SYSTEM\CurrentControlSet\Services'
   loop $key (grepRegValue($reg,'DisplayName'))
   {if match($key,concat($APPL_DB_SID,'.*HTTP'),'i')
    {var $cmd = getRegValue(join('\',$reg,$key,'Parameters'),'ConfigArg')
     break
    }
   }
  }

  # Extract the HTTP_FILE from the '-f' option and derive IAS_HOME
  var ($fil) = match($cmd,'-f\s*(.*?)\.conf','i')
  var $HTTP_FILE = $fil
  var $IAS_HOME = dirname(dirname(dirname(dirname($fil))))
 }
 else
 {var $ver = match($FND_TOP,'12\.0\.0')
  if and(not($ver),testDir('d',$IAS_ORACLE_HOME))
   var $IAS_HOME = $IAS_ORACLE_HOME
  else
  {# For UNIX, get information from Apache startup file
   var $top = cond($ver,$INST_TOP,$OAD_TOP)
   var $fil = nvl(\
     testFile('r',catFile($top,'admin','scripts',\
                    concat($APPL_DB_SID,'_',${RDA.T_NODE}),'adapcctl.sh')),\
     testFile('r',catFile($top,'admin','scripts',$APPL_DB_SID,'adapcctl.sh')),\
     testFile('r',catFile($top,'admin','scripts','adapcctl.sh')),\
     '')
   if grepFile($fil,'^ORAENV_FILE','f')
    var $IAS_HOME = dirname(trim(value(last),'"'))
  }

  # Latest templates have multiple HTTPD entries based on techstack variable
  if ?testFile('r',$XML_FILE)
  {var $xml = xmlLoadFile($XML_FILE)
   var $typ = xmlData(xmlFind($xml,'.../config_option oa_var="s_techstack"'))
   if match($typ,'(ias1022|as1013)')
    var $off = 0
   elsif match($typ,'http1312')
    var $off = 1
   else
    var $off = 2
  }
  else
   var $off = 0
  if ?testFile('f',catFile($IAS_HOME,'Apache','Apache','bin','apachectl'))
  {var @tbl = grepFile(lastFile(),'^\s*HTTPD=')
   var $HTTP_FILE = value($tbl[$off])
  }
 }

 # Get the APPS username and password from config file
 if !$APPL_LOGIN_ID
 {if $IAS_HOME
  {var $fil = catFile($IAS_HOME,'Apache','modplsql','cfg','wdbsvr.app')
   var $beg = field(':',0,\
                    grepFile($fil,concat('\[DAD_',$APPL_DB_SID,'\]'),'fn'))
   incr $beg
   var $end = field(':',0,\
                    grepFile($fil,'^;\s*$','fn',1,$beg))
   decr $end
   var $LOGIN_ID = \
     isUser(trim(value(grepFile($fil,'username\s*=','f',1,$beg,$end))),true)
   var $LOGIN_PW = trim(value(grepFile($fil,'password\s*=','f',1,$beg,$end)))
  }
 }
}

# Determine the Java location
if $IAS_HOME
{var $fil = value(grepFile(catFile($IAS_HOME,'Apache','Jserv','etc',\
                                   'jserv.properties'),'^wrapper\.bin=','f'))
 if match($fil,'\.(bat|cmd|sh)$',true)
  var $JAVA_EXE = value(grepFile($fil,'JSERVJAVA=','f'))
 else
  var $JAVA_EXE = $fil
}
if !?testFile('x',$JAVA_EXE)
 var $JAVA_EXE = ${ENV.AFJVAPRG:findCommand('java',true)}
var $JAVA_CMD = quote($JAVA_EXE)

# Set the login information
if $APPL_LOGIN_ID
 var $LOGIN_ID = uc($APPL_LOGIN_ID)
else
 var $LOGIN_ID = uc($LOGIN_ID)

if and($LOGIN_ID,compare('ne',$LOGIN_ID,'-'))
{# Determine the database password
 if $APPL_LOGIN_PW
  var $LOGIN_PW = $APPL_LOGIN_PW

 # Set the database context
 call setSqlTarget({T_ORACLE_SID=>$APPL_DB_SID,\
                    T_USER      =>join('/',$LOGIN_ID,$LOGIN_PW)})

 # Check the database access
 if testSql()
  var $DB_ACCESS = false
}
else
 var $DB_ACCESS = false

# Check Oracle Applications version
if $DB_ACCESS
 call get_apps_version()

# Assign a default product if none has been supplied
if !@SHORT
 call push(@SHORT,'IZU')

# Set short list variables for use further on
# e.g. changes "AP+INV+GL" to "'AP','SQLAP','INV','GL','SQLGL'" for use in SQL
var (%ALL_SHORT,%DSP_SHORT,%SEL_SHORT) = ()
var %TB_VAL = ('OFA','FA','SQLAP','AP','SQLGL','GL','SYSADMIN','FND')
var %TB_SYN = ('BOM','CST','CST','BOM','INV','WMS','OE','ONT','ONT','OE',\
               'PO','RCV','RCV','PO','WMS','INV')
var %tb_all = (%TB_SYN,%TB_VAL)
var %tb_cnv = ('ALR','FND','SYSADMIN','FND')
var %tb_sel = ('AP','SQLAP','AR','HZ','FA','OFA','FND','APPLSYS',\
               'GL','SQLGL',%TB_SYN)
loop $nam (@SHORT)
{var $nam = uc($nam)
 if $DB_ACCESS
  next missing($ALL_NAMES{nvl($TB_VAL{$nam},$nam)})
 var $DSP_SHORT{$nam} = 1
 if exists($tb_all{$nam})
  var $ALL_SHORT{$tb_all{$nam}} = 2
 var $ALL_SHORT{$nam} = 1
 var $nam = nvl($tb_cnv{$nam},$nam)
 if exists($tb_sel{$nam})
  var $SEL_SHORT{$tb_sel{$nam}} = 2
 var $SEL_SHORT{$nam} = 1
}
var $SHORT_LIST = concat("'",join("','",keys(%SEL_SHORT)),"'")

# Produce the report summary
toc '2:[[',getFile(),'][rda_report][ACT Report]]'
write '---+!! Application Collection Tool (ACT) Report'
write '|*Report File*|',getFile(),' |'
write '|*Date*       |',${RDA.T_LOCALTIME},' |'
write '|*Machine*    |',${RDA.T_NODE},' |'
write '|*Domain*     |',${RDA.T_DOMAIN},' |'
var $osn = ${RDA.T_OS}
write '|*OS*         |',$osn,' |'
write '|*OS/Version* |',\
      check($osn,'aix',            command('oslevel'),\
                 'darwin',         uname('r'),\
                 'dec_osf',        field('V',1,uname('r')),\
                 'dynixptx',       uname('r'),\
                 'hpux',           substr(uname('r'),2,5),\
                 'linux',          field('-',0,uname('r')),\
                 'solaris',        replace(uname('r'),'^5','2'),\
                 cond(isCygwin(),  'OSwin32',\
                      isUnix(),    uname('r'),\
                      isVms(),     uname('v'),\
                      isWindows(), 'OSwin32')),' |'
write '|*Oracle Home*|',encode($ORACLE_HOME),' |'
write '|*APPL_TOP*   |',encode($APPL_TOP),' |'
write '|*Tiers*      |',$TIERS,' |'
write '|*Products*   |',join(', ',keys(%DSP_SHORT)),' |'
if !and($TIER_ADMIN,$TIER_WEB,$TIER_FORMS,$TIER_NODE)
{write '%BR%\
        This node does not have all tiers installed.%BR%\
        Run ACT on each tier for complete information.%BR%'
 var $MULTI_NODE = true
}

if !$RDA
{write '---+!! Summary'
 write '%TOC3%'
}

=head2 apps_info - Application Information

Gives an overview of the Applications instance including release, multi-org,
and multi-currency information.

=cut

if $DB_ACCESS
{debug ' Inside ACT module, gathering Application information ...'
 call act_report('apps_info','Application Information')

 # Determine $APPLSYS
 set $sql
 {SELECT DISTINCT oracle_username
 " FROM fnd_application fa,fnd_oracle_userid fu,fnd_product_installations fi
 " WHERE fa.application_short_name = 'FND'
 "   AND fa.application_id = fi.application_id
 "   AND fi.oracle_id = fu.oracle_id;
 }
 call loadSql($sql)
 var ($APPLSYS) = grepSql($sql,'\S','f')

 # Determine release, multi-org, multi-currency information
 var @col = ('release_name','multi_org_flag','multi_currency_flag',\
             'applications_system_name')
 var (undef,$col) = getSqlColumns('ACT',$APPLSYS,'FND_PRODUCT_GROUPS',@col)
 call clearSqlColumns('ACT')
 if $col
 {set $sql
  {SELECT :1
  " FROM fnd_product_groups;
  }
  var ($lin) = grepSql(bindSql($sql,$col),'\S','f')
  var ($rel,$mof,$mcf,$nam) = split('\|',trim($lin,'\s*\|'),4)
  write '|*Release*|',cond($FILTERED,fmt_version($rel),$rel),' |'
  if $nam
   write '|*Applications System Name*|',$nam,' |'
  write '|*Multi Org*|',$mof,' |'
  write '|*Multi Currency*|',$mcf,' |'
 }

 # Determine the responsibility name
 if $RESP_ID
 {set $sql
  {SELECT responsibility_name
  " FROM fnd_responsibility_tl
  " WHERE responsibility_id = :1
  "   AND language = 'US';
  }
  var ($RESP_NAME) = grepSql(bindSql($sql,$RESP_ID),'\S','f')
  if $RESP_NAME
   write '|*Responsibility*|',$RESP_NAME,' (',$RESP_ID,')|'
 }

 # Determine the user identifier/name
 if or($USER_ID,$USER_NAME)
 {if $USER_NAME
  {set $sql
   {SELECT user_id
   " FROM fnd_user
   " WHERE user_name = UPPER(':1');
   }
   var ($USER_ID) = grepSql(bindSql($sql,$USER_NAME),'\S','f')
  }
  else
  {set $sql
   {SELECT user_name
   " FROM fnd_user
   " WHERE user_id = :1;
   }
   var ($USER_NAME) = grepSql(bindSql($sql,$USER_ID),'\S','f')
  }
 }

 # When possible, determine the application, its status and the operating unit
 if and($USER_ID,$RESP_ID)
 {# Determine the application and its status
  if or($REL107,$REL110)
  {set $sql
   {SELECT r.application_id
   " FROM fnd_user_responsibility r
   " WHERE r.responsibility_id = :1
   "   AND r.user_id = :2;
   }
  }
  else
  {set $sql
   {SELECT rg.responsibility_application_id
   " FROM fnd_user_resp_groups rg
   " WHERE rg.responsibility_id = :1
   "   AND rg.user_id = :2;
   }
  }
  var ($APPL_ID) = grepSql(bindSql($sql,$RESP_ID,$USER_ID),'\S','f')
  var $APPL_ID = trim($APPL_ID)
  set $sql
  {SELECT a.application_name
  " FROM fnd_application_vl a
  " WHERE a.application_id = :1;
  }
  var ($nam) = grepSql(bindSql($sql,$APPL_ID),'\S','f')
  set $sql
  {SELECT DECODE(pi.status,'I','Installed',
  "                        'S','Shared',
  "                        'N','Not Installed',
  "                        'L','Custom',
  "                        '')
  " FROM fnd_product_installations pi
  " WHERE pi.application_id = :1;
  }
  var ($sta) = grepSql(bindSql($sql,$APPL_ID),'\S','f')
  write '|*Application*|',$nam,' (',$APPL_ID,') with status of ',\
        $sta,'|'

  # Determine the operating unit
  var $oid = get_profile_value('ORG_ID',$USER_ID,$RESP_ID,$APPL_ID)
  if isNumber(trim($oid))
  {set $sql
   {SELECT name
   " FROM hr_all_organization_units
   " WHERE organization_id = :1;
   }
   var ($ORG_NAME) = grepSql(bindSql($sql,$oid),'\S','f')
   write '|*Operating Unit*|',$ORG_NAME,' (',$oid,')|'
  }
 }

 # Predetermine owner names for performance reasons (speeds index query)
 set $sql
 {SELECT DISTINCT oracle_username
 " FROM fnd_application fa,fnd_oracle_userid fu,fnd_product_installations fi
 " WHERE (fa.application_short_name IN (:1) OR fu.oracle_username in (:1))
 "   AND fa.application_id = fi.application_id
 "   AND fi.oracle_id = fu.oracle_id;
 }
 var $OWNERS = concat("'",\
                      join("','",grepSql(bindSql($sql,$SHORT_LIST),'\S')),\
                      "'")
 call act_menu(3,'Application Information',true)

=for stopwords patchset

=head2 apps_details - Application Installation Details

Lists the installed Applications products with the installation status and
patchset level.

=cut

 debug ' Inside ACT module, gathering Application installation details ...'
 call act_report('apps_details','Application Installation Details')

 # Check the existence of the patch level command
 set $sql
 {SELECT column_name
 " FROM all_tab_columns
 " WHERE owner = ':1'
 " AND table_name = 'FND_PRODUCT_INSTALLATIONS'
 " AND column_name = 'PATCH_LEVEL';
 }
 if grepSql(bindSql($sql,$APPLSYS),'PATCH_LEVEL')
 {var $col = " ||\012       fpi.patch_level || ' |'"
  var $hdr = '|*Application Name*|*Short Name*| *Application ID*|*Status*|\
               *Patch Level*|'
 }
 else
 {var $col = ''
  var $hdr = '|*Application Name*|*Short Name*| *Application ID*|*Status*|'
 }

 # Get the installation details
 set $sql
 {SELECT '|' ||
 "       fav.application_name || '|' ||
 "       fav.application_short_name || '| ' ||
 "       fav.application_id || '|' ||
 "       DECODE(fpi.status,'I','Installed',
 "                         'L','Custom',
 "                         'N','Not Installed',
 "                         'S','Shared',
 "                         fpi.status) || '|':1
 " FROM fnd_application_vl fav,fnd_product_installations fpi
 " WHERE fav.application_id = fpi.application_id
 " ORDER BY LOWER(fav.application_name);
 }
 prefix
  write $hdr
 call writeSql(bindSql($sql,$col))
 unprefix
 write "Check the 'Patches of not Registered Products' section for patch \
        levels of Procurement, iReceivables etc.%BR%"
 write $TOP
 call act_menu(3,'Application Installation Details')

=head2 db_details - Database Instance Details

Provides details about the underlying database including the database version,
and archive log state.

=cut

 debug ' Inside ACT module, gathering database instance details ...'
 call act_report('db_details','Database Instance Details')
 var @TTL = ()
 var @HDR = ()
 if or($REL107,$REL110)
 {# Columns are missing in 8.0 databases
  var $HDR[1] = '|*Instance Number*|*Instance Name*|*Creation Date*|*Hostname*\
                 |*Version*|*Startup Time*|*Status*|*Parallel*|*Archiver*|'
  set $sql
  {SELECT '|' ||
  "       i.instance_number || '|' ||
  "       i.instance_name || '|' ||
  "       TO_CHAR(d.created,'DD-Mon-YYYY') || '|' ||
  "       i.host_name || '|' ||
  "       i.version || '|' ||
  "       TO_CHAR(i.startup_time,'DD-Mon-YYYY HH24:MI:SS') || '|' ||
  "       i.status || '|' ||
  "       i.parallel || '|' ||
  "       i.archiver || '|'
  " FROM gv$instance i,gv$database d
  " WHERE i.inst_id = d.inst_id;
  }
 }
 elsif $REL115
 {var $HDR[1] = '|*Instance Number*|*Instance Name*|*Creation Date*|*Hostname*\
                 |*Version*|*Startup Time*|*Status*|*Parallel*\
                 |*Archiver*|*Database Status*|*Instance Role*|'
  set $sql
  {SELECT '|' ||
  "       i.instance_number || '|' ||
  "       i.instance_name || '|' ||
  "       TO_CHAR(d.created,'DD-Mon-YYYY') || '|' ||
  "       i.host_name || '|' ||
  "       i.version || '|' ||
  "       TO_CHAR(i.startup_time,'DD-Mon-YYYY HH24:MI:SS') || '|' ||
  "       i.status || '|' ||
  "       i.parallel || '|' ||
  "       i.archiver || '|' ||
  "       i.database_status || '|' ||
  "       i.instance_role || '|'
  " FROM gv$instance i,gv$database d
  " WHERE i.inst_id = d.inst_id;
  }
 }
 else
 {var $HDR[1] = '|*Instance Number*|*Instance Name*|*Hostname*\
                 |*Version*|*Startup Time*|*Status*|*Parallel*\
                 |*Archiver*|*Database Status*|*Instance Role*|'
  set $sql
  {SELECT '|' ||
  "       i.instance_number || '|' ||
  "       i.instance_name || '|' ||
  "       i.host_name || '|' ||
  "       i.version || '|' ||
  "       TO_CHAR(i.startup_time,'DD-Mon-YYYY HH24:MI:SS') || '|' ||
  "       i.status || '|' ||
  "       i.parallel || '|' ||
  "       i.archiver || '|' ||
  "       i.database_status || '|' ||
  "       i.instance_role || '|'
  " FROM gv$instance i;
  }
 }
 call act_separator(1)
 call writeSql($sql)
 call act_separator(0)
 call act_menu(3,'Database Instance Details')

=head2 rdbms_ver - Oracle RDBMS Versions

Lists the version of products in the underlying database such as SQL*Net and
PL/SQL.

=cut

 debug ' Inside ACT module, gathering Oracle RDBMS versions ...'
 call act_report('rdbms_ver','Oracle RDBMS Versions')
 var @TTL = ()
 var @HDR = ('',\
   '|*Instance Number*|*Instance Name*|*RDBMS/Tools Version*|'\
   )
 set $sql
 {SELECT '|' ||
 "       i.instance_number  || '|' ||
 "       i.instance_name || '|' ||
 "       v.banner || '|'
 " FROM gv$instance i,gv$version v
 " WHERE i.inst_id = v.inst_id;
 }
 call act_separator(1)
 call writeSql($sql)
 call act_separator(0)
 call act_menu(3,'Oracle RDBMS Versions')

=head2 nls - NLS Settings

Gets the NLS parameter settings of the Applications tiers. Lists the installed
and base languages.

=cut

 debug ' Inside ACT module, gathering NLS parameter settings ...'
 call act_report('nls','NLS Settings')
 call act_toc()
 var @TTL = ('',\
   '---++ NLS Parameters',\
   '---++ Installed and Base Languages')
 var @HDR = ('',\
   '|*NLS Parameter Name*|*Currently Set Value*|',\
   '|*Installed Flag*|*Code*|*Language*|')
 set $sql
 {SELECT '|' ||
 "       parameter || '|' ||
 "       value || ' |'
 " FROM nls_session_parameters
 "UNION
 "SELECT '|' ||
 "       parameter || '|' ||
 "       value || ' |'
 " FROM v$nls_parameters
 " WHERE parameter IN ('NLS_CHARACTERSET','NLS_NCHAR_CHARACTERSET');
 "PROMPT ___Macro_act_separator(2)___
 "SELECT '|' ||
 "       DECODE(installed_flag,'I','Installed','B','Base') || '|' ||
 "       language_code || '|' ||
 "       nls_language || '|'
 " FROM fnd_languages
 " WHERE installed_flag IN ('I','B')
 " ORDER BY installed_flag;
 }
 call act_separator(1)
 call writeSql($sql)
 call act_separator(0)
 call act_menu(3,'NLS Settings')

=head2 vparameters - Non Default V$Parameter Settings

Gets the non-default C<V$Parameter> settings of the underlying database.

=cut

 debug ' Inside ACT module, gathering non-default V$Parameter settings ...'
 call act_report('vparameters','Non Default V$Parameter Settings')
 var @TTL = ()
 var @HDR = ('',\
  '|*Parameter Name*|*Parameter Value*|')
 set $sql
 {SELECT '|' ||
 "       name || '|' ||
 "       value || ' |'
 " FROM v$parameter
 " WHERE isdefault = 'FALSE'
 " ORDER BY name;
 }
 call act_separator(1)
 call writeSql($sql)
 call act_separator(0)
 call act_menu(3,'Non Default V$Parameter Settings')

=head2 managers - Concurrent and Interface Managers

Gets information about concurrent, transaction, and interface managers. Not
all products have managers.
(Applicable for Oracle Applications 11.5 and later.)

=cut

 if or($REL115,$REL120,$REL121)
 {debug ' Inside ACT module, getting concurrent managers information ...'
  call act_report('managers')
  var $TTL = '---+!! Concurrent and Interface Managers'
  var @TTL = ('',\
              '---++ Concurrent Managers',\
              '---++ Interface Managers')
  var @HDR = ('',\
              '|*Short%BR%Name*|*Internal%BR%Name*|*Manager*|*Node*| *Actual*| \
                *Target*|',\
              '|*Short%BR%Name*|*Internal%BR%Name*|*Manager*|*Worker%BR%Rows*|\
                *Timeout*|*Process%BR%Interval*| *Manager%BR%Priority*| \
                *Worker%BR%Priority*| *Processing%BR%Timeout*| \
                *Process%BR%Code*|')
  set $sql
  {SELECT  '|' ||
  "        fa.application_short_name || ' |' ||
  "        fcp.concurrent_processor_name || ' |' ||
  "        fcq.user_concurrent_queue_name || ' |' ||
  "        NVL( fcq.target_node,'n/a') || ' | ' ||
  "        fcq.running_processes || '| ' ||
  "        fcq.max_processes || '|'
  " FROM fnd_concurrent_queues_vl fcq,
  "      fnd_application_vl fa,
  "      fnd_concurrent_processors fcp
  " WHERE fa.application_id = fcq.application_id
  "   AND fcq.application_id = fcp.application_id
  "   AND fcq.concurrent_processor_id = fcp.concurrent_processor_id
  "   AND fa.application_short_name IN (:1)
  " ORDER BY fa.application_short_name,
  "          fcp.concurrent_processor_id,
  "          fcp.concurrent_processor_name;
  }
  if or($ALL_SHORT{'BOM'},$ALL_SHORT{'CST'},$ALL_SHORT{'INV'},\
        $ALL_SHORT{'WIP'},$ALL_SHORT{'WMS'})
  {append $sql
   {PROMPT ___Macro_act_separator(2)___
   "SELECT  '|' ||
   "        mtl.process_app_short_name || ' |' ||
   "        mtl.process_name || ' |' ||
   "        mtl.process_type || ' | ' ||
   "        mtl.worker_rows  || '|' ||
   "        mtl.timeout_hours || 'hr ' || mtl.timeout_minutes || 'min|' ||
   "        mtl.process_hours || 'hr ' || mtl.process_minutes || 'min ' ||
   "        mtl.process_seconds || 'sec| ' ||
   "        mtl.manager_priority || '| ' ||
   "        mtl.worker_priority || '| ' ||
   "        mtl.processing_timeout || '| ' ||
   "        mtl.process_code || '|'
   " FROM mtl_interface_proc_controls_v mtl
   " ORDER BY mtl.process_app_short_name,
   "          mtl.process_name;
   }
  }
  call act_separator(1)
  call writeSql(bindSql($sql,$SHORT_LIST))
  call act_separator(0)
  call act_menu(3,'Concurrent and Interface Managers')
  var $TTL = undef
 }

=head2 stat_req - Gather Schema Statistics Requests

Displays information about the last two executions of the
C<Gather Schema Statistics> concurrent program.

=cut

 if !or($REL107,$REL110)
 {debug ' Inside ACT module, getting last Gather Schema Statistics requests ...'
  call act_report('stat_req')
  set $sql
  {SELECT '|' ||
  "       r.request_id || ' |' ||
  "       p.user_concurrent_program_name || ' |' ||
  "       DECODE(r.status_code,
  "              'A','Waiting',
  "              'B','Resuming',
  "              'C','Normal',
  "              'D','Cancelled',
  "              'E','Error',
  "              'G','Warning',
  "              'H','On Hold',
  "              'I','Normal',
  "              'M','No Manager',
  "              'P','Scheduled',
  "              'Q','Standby',
  "              'R','Normal',
  "              'S','Suspended',
  "              'T','Terminating',
  "              'U','Disabled',
  "              'W','Paused',
  "              'X','Terminated',
  "              'Z','Waiting',r.status_code) || ' |' ||
  "       DECODE(r.phase_code,
  "              'C','Completed',
  "              'I','Inactive',
  "              'P','Pending',
  "              'R','Running',r.phase_code) || ' |' ||
  "      TO_CHAR(r.actual_start_date,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
  "      TO_CHAR(r.actual_completion_date,'DD-Mon-YYYY HH24:MI:SS') || ' | ' ||
  "      ROUND((r.actual_completion_date - r.actual_start_date)*1440,2) ||
  "      '|' ||
  "      TRUNC(MOD((r.actual_completion_date-r.actual_start_date)*24,24)) ||
  "      'hr ' ||
  "      TRUNC(MOD((r.actual_completion_date-r.actual_start_date)*1440,60)) ||
  "      'min ' ||
  "      TRUNC(MOD((r.actual_completion_date-r.actual_start_date)*86400,60)) ||
  "      'sec|' ||
  "      r.argument_text || ' |'
  " FROM fnd_concurrent_requests r,
  "      fnd_concurrent_programs_tl p,
  "      fnd_concurrent_programs fcp
  " WHERE r.concurrent_program_id = p.concurrent_program_id
  "   AND fcp.concurrent_program_id=p.concurrent_program_id
  "   AND fcp.concurrent_program_name ='FNDGSCST'
  "   AND p.language = 'US'
  "   AND ROWNUM < 3
  " ORDER BY r.actual_start_date DESC;
  }
  prefix
  {write '---+ Gather Schema Statistics Requests'
   write '|*Request ID*|*Program Name*|*Status*|*Phase*|*Actual Start Date*\
          |*Actual Completion Date*| *Total Minutes*|*Time To Run*|*Arguments*|'
  }
  call writeSql($sql)
  if hasOutput(true)
   call act_menu(3,'Gather Schema Statistics Requests',true)
 }

=head2 profile - Profile Option Values

Lists profile names, values, site, and user settings for the specified user and
Applications products.

=cut

 debug ' Inside ACT module, gathering profile option values ...'
 call act_report('profile','Profile Option Values')
 call act_toc()
 var @HDR = ('',\
   '|*Profile Option Name*|*Internal Name*|*Effective Value*| \
     *Site Enabled Status* |*Site Level Value*| \
     *Application Enabled Status* |*Application Level Value*| \
     *Responsibility Enabled Status* |*Responsibility Level Value*| \
     *User Enabled Status* |*User Level Value*|',\
   '|*Profile Option Name*|*Internal Name*|*Effective Value*| \
     *Site Enabled Status* |*Site Level Value*|\
     *Server Name* | *Server Enabled Status* |*Server Level Value*| \
     *User Enabled Status* |*User Level Value*|',\
   '|*Profile Option Name*|*Internal Name*|*Effective Value*| \
     *Site Enabled Status* |*Site Level Value*|\
     *Organization Name* | \
     *Organization Enabled Status* |*Organization Level Value*| \
     *User Enabled Status* |*User Level Value*|'\
   )
 write 'Logged in as user ',$USER_NAME,'(ID: ',$USER_ID,\
        ') with responsibility ',$RESP_NAME,'(ID: ',$RESP_ID,')%BR%'

 # Define the report macro
 macro act_profile
 {var ($hdr) = @arg
  import $TOP,@HDR
  keep $hdr,$TOP,@HDR

  if $hdr
  {prefix
    write $HDR[$hdr]
  }
  elsif hasOutput(true)
   write $TOP
 }

 # Get the profile options based on responsibilities
 set $sql
 {SET serveroutput on size 1000000
 "DECLARE
 " CURSOR rsp_options IS
 "  SELECT fpo.application_id,
 "         fpo.profile_option_id poi,
 "         fpo.user_profile_option_name upon
 "   FROM fnd_profile_options_vl fpo
 "   WHERE fpo.application_id IN
 "          (SELECT application_id
 "            FROM fnd_application
 "            WHERE application_short_name in (:3)
 "          )
 "     AND fpo.start_date_active <= SYSDATE
 "     AND (NVL(fpo.end_date_active,SYSDATE) >= SYSDATE)
 "   ORDER BY fpo.application_id,fpo.user_profile_option_name;
 "
 " CURSOR rsp_values(c_appl_id NUMBER,c_po_id NUMBER) IS
 "  SELECT p.profile_option_name prof_name,
 "         NVL(u.profile_option_value,
 "           NVL(r.profile_option_value,
 "            NVL(a.profile_option_value,
 "             s.profile_option_value))) prof_value,
 "         p.site_enabled_flag site_flag,
 "         s.profile_option_value site_value,
 "         p.app_enabled_flag appl_flag,
 "         a.profile_option_value appl_value,
 "         p.resp_enabled_flag resp_flag,
 "         r.profile_option_value resp_value,
 "         p.user_enabled_flag user_flag,
 "         u.profile_option_value user_value
 "   FROM fnd_profile_options_vl p,
 "        fnd_profile_option_values s,
 "        fnd_profile_option_values a,
 "        fnd_profile_option_values r,
 "        fnd_profile_option_values u
 "   WHERE p.profile_option_id = s.profile_option_id(+)
 "     AND p.application_id = s.application_id(+)
 "     AND p.profile_option_id = a.profile_option_id(+)
 "     AND p.application_id = a.application_id(+)
 "     AND p.profile_option_id = r.profile_option_id(+)
 "     AND p.application_id = r.application_id(+)
 "     AND p.profile_option_id = u.profile_option_id(+)
 "     AND p.application_id = u.application_id(+)
 "     AND p.profile_option_id = c_po_id
 "     AND p.application_id = c_appl_id
 "     AND s.level_id(+) = 10001
 "     AND a.level_id(+) = 10002
 "     AND a.level_value(+) = c_appl_id
 "     AND r.level_id(+) = 10003
 "     AND r.level_value(+) = :2
 "     AND u.level_id(+) = 10004
 "     AND u.level_value(+) = :1
 "   ORDER BY 1;
 "
 " l_appl_id NUMBER := -1;
 " r_rsp     rsp_values%ROWTYPE;
 "
 " PROCEDURE set_header(p_appl_id NUMBER,p_hdr VARCHAR2,p_ttl VARCHAR2)
 " IS
 "  CURSOR appl_name(c_appl_id NUMBER) IS
 "   SELECT application_name
 "    FROM fnd_application_vl
 "    WHERE application_id = c_appl_id;
 "  r_ttl appl_name%ROWTYPE;
 " BEGIN
 "   OPEN appl_name(p_appl_id);
 "   FETCH appl_name
 "    INTO r_ttl;
 "   IF appl_name%found
 "   THEN
 "    dbms_output.put_line('___Macro_act_profile(0)___');
 "    dbms_output.put_line('---++ ' || p_ttl || ' for Application : ' ||
 "                         r_ttl.application_name);
 "    dbms_output.put_line('___Macro_act_profile(' || p_hdr || ')___');
 "   END IF;
 "   CLOSE appl_name;
 " END set_header;
 " PROCEDURE show_output(pmv_msg_in IN VARCHAR2)
 " IS
 " BEGIN
 "  IF LENGTH(pmv_msg_in) > 255 THEN
 "   dbms_output.put_line(SUBSTR(pmv_msg_in,1,255));
 "   show_output(SUBSTR(pmv_msg_in,256,LENGTH(pmv_msg_in)));
 "  ELSE
 "   dbms_output.put_line(pmv_msg_in);
 "  END IF;
 " EXCEPTION
 "  WHEN OTHERS THEN
 "   dbms_output.enable(1000000);
 "   show_output(SUBSTR(pmv_msg_in,256,LENGTH(pmv_msg_in)));
 " END show_output;
 "BEGIN
 " FOR r_opt IN rsp_options
 " LOOP
 "  IF r_opt.application_id != l_appl_id
 "  THEN
 "   l_appl_id := r_opt.application_id;
 "   set_header(l_appl_id,'1','Profile Option Values');
 "  END IF;
 "  OPEN rsp_values(r_opt.application_id,r_opt.poi);
 "  FETCH rsp_values
 "   INTO r_rsp;
 "  IF rsp_values%notfound
 "  THEN
 "   dbms_output.put_line('|' || r_opt.upon ||
 "    '|N/A|Not set at any level| - |N/A| - |N/A| - |N/A| - |N/A|');
 "  ELSE
 "   IF (r_rsp.prof_name LIKE '%\_PASS' ESCAPE '\') OR
 "      (r_rsp.prof_name LIKE '%\_PASSWD' ESCAPE '\') OR
 "      (r_rsp.prof_name LIKE '%\_PASSWORD' ESCAPE '\') OR
 "      (r_rsp.prof_name LIKE '%PWD')
 "   THEN
 "    IF r_rsp.appl_value IS NOT NULL
 "    THEN
 "     r_rsp.appl_value := '%R:PASSWORD%';
 "    END IF;
 "    IF r_rsp.prof_value IS NOT NULL
 "    THEN
 "     r_rsp.prof_value := '%R:PASSWORD%';
 "    END IF;
 "    IF r_rsp.resp_value IS NOT NULL
 "    THEN
 "     r_rsp.resp_value := '%R:PASSWORD%';
 "    END IF;
 "    IF r_rsp.site_value IS NOT NULL
 "    THEN
 "     r_rsp.site_value := '%R:PASSWORD%';
 "    END IF;
 "    IF r_rsp.user_value IS NOT NULL
 "    THEN
 "     r_rsp.user_value := '%R:PASSWORD%';
 "    END IF;
 "   ELSE
 "    r_rsp.appl_value := REPLACE(r_rsp.appl_value,'.','&#46;');
 "    r_rsp.prof_value := REPLACE(r_rsp.prof_value,'.','&#46;');
 "    r_rsp.resp_value := REPLACE(r_rsp.resp_value,'.','&#46;');
 "    r_rsp.site_value := REPLACE(r_rsp.site_value,'.','&#46;');
 "    r_rsp.user_value := REPLACE(r_rsp.user_value,'.','&#46;');
 "   END IF;
 "   dbms_output.put_line('[[[');
 "   show_output('|' ||
 "               REPLACE(r_opt.upon,' ','&nbsp;') || '|' ||
 "               r_rsp.prof_name || '|' ||
 "               r_rsp.prof_value || ' | ' ||
 "               r_rsp.site_flag || ' |' ||
 "               r_rsp.site_value || ' | ' ||
 "               r_rsp.appl_flag || ' |' ||
 "               r_rsp.appl_value || ' | ' ||
 "               r_rsp.resp_flag || ' |' ||
 "               r_rsp.resp_value || ' | ' ||
 "               r_rsp.user_flag || ' |' ||
 "               r_rsp.user_value || ' |');
 "   dbms_output.put_line(']]]');
 "  END IF;
 "  CLOSE rsp_values;
 " END LOOP;
 "END;
 "/
 }
 prefix
  write
 call writeSql(bindSql($sql,$USER_ID,$RESP_ID,$SHORT_LIST))
 if hasOutput(true)
  write $TOP

 # Get the profile options based on nodes
 if chk_apps_column($APPLSYS,'FND_PROFILE_OPTIONS','SERVER_ENABLED_FLAG')
 {set $sql
  {SET serveroutput on size 1000000
  "DECLARE
  " CURSOR nod_options IS
  "  SELECT fpo.application_id,
  "         fpo.profile_option_id poi,
  "         fpo.user_profile_option_name upon
  "   FROM fnd_profile_options_vl fpo
  "   WHERE fpo.application_id IN
  "          (SELECT application_id
  "            FROM fnd_application
  "            WHERE application_short_name in (:2)
  "          )
  "     AND fpo.start_date_active <= SYSDATE
  "     AND (NVL(fpo.end_date_active,SYSDATE) >= SYSDATE)
  "     AND fpo.profile_option_id IN
  "          (SELECT z.profile_option_id
  "            FROM fnd_profile_options z
  "            WHERE z.server_enabled_flag = 'Y'
  "              AND z.application_id = fpo.application_id)
  "   ORDER BY fpo.application_id,fpo.user_profile_option_name;
  "
  " CURSOR nod_values(c_appl_id NUMBER,c_po_id NUMBER) IS
  "  SELECT p.profile_option_name prof_name,
  "         NVL(u.profile_option_value,
  "          NVL(svr.profile_option_value,
  "           s.profile_option_value)) prof_value,
  "         p.site_enabled_flag site_flag,
  "         s.profile_option_value site_value,
  "         fn.node_name node_name,
  "         p.server_enabled_flag node_flag,
  "         svr.profile_option_value node_value,
  "         p.user_enabled_flag user_flag,
  "         u.profile_option_value user_value
  "   FROM fnd_profile_options_vl p,
  "        fnd_profile_option_values s,
  "        fnd_profile_option_values svr,
  "        fnd_profile_option_values u,
  "        fnd_nodes fn
  "   WHERE p.application_id = c_appl_id
  "     AND p.profile_option_id = c_po_id
  "     AND p.profile_option_id = s.profile_option_id(+)
  "     AND p.application_id = s.application_id(+)
  "     AND s.level_id(+) = 10001
  "     AND p.profile_option_id = svr.profile_option_id(+)
  "     AND p.application_id = svr.application_id(+)
  "     AND svr.level_id(+) = 10005
  "     AND fn.node_id = svr.level_value
  "     AND p.profile_option_id = u.profile_option_id(+)
  "     AND p.application_id = u.application_id(+)
  "     AND u.level_id(+) = 10004
  "     AND u.level_value(+) = :1
  "   ORDER BY 1;
  "
  " l_appl_id NUMBER := -1;
  " r_nod     nod_values%ROWTYPE;
  "
  " PROCEDURE set_header(p_appl_id NUMBER,p_hdr VARCHAR2,p_ttl VARCHAR2)
  " IS
  "  CURSOR appl_name(c_appl_id NUMBER) IS
  "   SELECT application_name
  "    FROM fnd_application_vl
  "    WHERE application_id = c_appl_id;
  "  r_ttl appl_name%ROWTYPE;
  " BEGIN
  "   OPEN appl_name(p_appl_id);
  "   FETCH appl_name
  "    INTO r_ttl;
  "   IF appl_name%found
  "   THEN
  "    dbms_output.put_line('___Macro_act_profile(0)___');
  "    dbms_output.put_line('---++ ' || p_ttl || ' for Application : ' ||
  "                         r_ttl.application_name);
  "    dbms_output.put_line('___Macro_act_profile(' || p_hdr || ')___');
  "   END IF;
  "   CLOSE appl_name;
  " END set_header;
  " PROCEDURE show_output(pmv_msg_in IN VARCHAR2)
  " IS
  " BEGIN
  "  IF LENGTH(pmv_msg_in) > 255 THEN
  "   dbms_output.put_line(SUBSTR(pmv_msg_in,1,255));
  "   show_output(SUBSTR(pmv_msg_in,256,LENGTH(pmv_msg_in)));
  "  ELSE
  "   dbms_output.put_line(pmv_msg_in);
  "  END IF;
  " EXCEPTION
  "  WHEN OTHERS THEN
  "   dbms_output.enable(1000000);
  "   show_output(SUBSTR(pmv_msg_in,256,LENGTH(pmv_msg_in)));
  " END show_output;
  "BEGIN
  " FOR r_opt IN nod_options
  " LOOP
  "  IF r_opt.application_id != l_appl_id
  "  THEN
  "   l_appl_id := r_opt.application_id;
  "   set_header(l_appl_id,'2','Active Server Profile Options');
  "  END IF;
  "  OPEN nod_values(r_opt.application_id,r_opt.poi);
  "  FETCH nod_values
  "   INTO r_nod;
  "  IF nod_values%found
  "  THEN
  "   IF (r_nod.prof_name LIKE '%\_PASS' ESCAPE '\') OR
  "      (r_nod.prof_name LIKE '%\_PASSWD' ESCAPE '\') OR
  "      (r_nod.prof_name LIKE '%\_PASSWORD' ESCAPE '\') OR
  "      (r_nod.prof_name LIKE '%PWD')
  "   THEN
  "    IF r_nod.node_value IS NOT NULL
  "    THEN
  "     r_nod.node_value := '%R:PASSWORD%';
  "    END IF;
  "    IF r_nod.prof_value IS NOT NULL
  "    THEN
  "     r_nod.prof_value := '%R:PASSWORD%';
  "    END IF;
  "    IF r_nod.site_value IS NOT NULL
  "    THEN
  "     r_nod.site_value := '%R:PASSWORD%';
  "    END IF;
  "    IF r_nod.user_value IS NOT NULL
  "    THEN
  "     r_nod.user_value := '%R:PASSWORD%';
  "    END IF;
  "   ELSE
  "    r_nod.node_value := REPLACE(r_nod.node_value,'.','&#46;');
  "    r_nod.prof_value := REPLACE(r_nod.prof_value,'.','&#46;');
  "    r_nod.site_value := REPLACE(r_nod.site_value,'.','&#46;');
  "    r_nod.user_value := REPLACE(r_nod.user_value,'.','&#46;');
  "   END IF;
  "   dbms_output.put_line('[[[');
  "   show_output('|' ||
  "               REPLACE(r_opt.upon,' ','&nbsp;') || '|' ||
  "               r_nod.prof_name || '|' ||
  "               r_nod.prof_value || ' | ' ||
  "               r_nod.site_flag || ' |' ||
  "               r_nod.site_value || ' |' ||
  "               r_nod.node_name || ' | ' ||
  "               r_nod.node_flag || ' |' ||
  "               r_nod.node_value || ' | ' ||
  "               r_nod.user_flag || ' |' ||
  "               r_nod.user_value || ' |');
  "   dbms_output.put_line(']]]');
  "  END IF;
  "  CLOSE nod_values;
  " END LOOP;
  "END;
  "/
  }
  prefix
   write
  call writeSql(bindSql($sql,$USER_ID,$SHORT_LIST))
  if hasOutput(true)
   write $TOP
 }

 # Get the profile options based on organizations
 if chk_apps_column($APPLSYS,'FND_PROFILE_OPTIONS','ORG_ENABLED_FLAG')
 {set $sql
  {SET serveroutput on size 1000000
  "DECLARE
  " CURSOR org_options IS
  "  SELECT fpo.application_id,
  "         fpo.profile_option_id poi,
  "         fpo.user_profile_option_name upon
  "   FROM fnd_profile_options_vl fpo
  "   WHERE fpo.application_id IN
  "          (SELECT application_id
  "            FROM fnd_application
  "            WHERE application_short_name in (:2)
  "          )
  "     AND fpo.start_date_active <= SYSDATE
  "     AND (NVL(fpo.end_date_active,SYSDATE) >= SYSDATE)
  "     AND fpo.profile_option_id IN
  "           (SELECT z.profile_option_id
  "             FROM fnd_profile_options z
  "             WHERE z.org_enabled_flag = 'Y'
  "               AND z.application_id = fpo.application_id)
  "   ORDER BY fpo.application_id,fpo.user_profile_option_name;
  "
  " CURSOR org_values(c_appl_id NUMBER,c_po_id NUMBER) IS
  "  SELECT p.profile_option_name prof_name,
  "         NVL(u.profile_option_value,
  "          NVL(org.profile_option_value,
  "           s.profile_option_value)) prof_value,
  "         p.site_enabled_flag site_flag,
  "         s.profile_option_value site_value,
  "         hru.name org_name,
  "         p.org_enabled_flag org_flag,
  "         org.profile_option_value org_value,
  "         p.user_enabled_flag user_flag,
  "         u.profile_option_value user_value
  "   FROM fnd_profile_options_vl p,
  "        fnd_profile_option_values s,
  "        fnd_profile_option_values org,
  "        fnd_profile_option_values u,
  "        hr_operating_units hru
  "   WHERE p.application_id = c_appl_id
  "     AND p.profile_option_id = c_po_id
  "     AND p.profile_option_id = s.profile_option_id(+)
  "     AND p.application_id = s.application_id(+)
  "     AND s.level_id(+) = 10001
  "     AND p.profile_option_id = org.profile_option_id(+)
  "     AND p.application_id = org.application_id (+)
  "     AND hru.organization_id = org.level_value
  "     AND org.level_id(+) = 10006
  "     AND p.profile_option_id = u.profile_option_id(+)
  "     AND p.application_id = u.application_id(+)
  "     AND u.level_id(+) = 10004
  "     AND u.level_value(+) = :1
  "   ORDER BY 1;
  "
  " l_appl_id NUMBER := -1;
  " r_org     org_values%ROWTYPE;
  "
  " PROCEDURE set_header(p_appl_id NUMBER,p_hdr VARCHAR2,p_ttl VARCHAR2)
  " IS
  "  CURSOR appl_name(c_appl_id NUMBER) IS
  "   SELECT application_name
  "    FROM fnd_application_vl
  "    WHERE application_id = c_appl_id;
  "  r_ttl appl_name%ROWTYPE;
  " BEGIN
  "   OPEN appl_name(p_appl_id);
  "   FETCH appl_name
  "    INTO r_ttl;
  "   IF appl_name%found
  "   THEN
  "    dbms_output.put_line('___Macro_act_profile(0)___');
  "    dbms_output.put_line('---++ ' || p_ttl || ' for Application : ' ||
  "                         r_ttl.application_name);
  "    dbms_output.put_line('___Macro_act_profile(' || p_hdr || ')___');
  "   END IF;
  "   CLOSE appl_name;
  " END set_header;
  " PROCEDURE show_output(pmv_msg_in IN VARCHAR2)
  " IS
  " BEGIN
  "  IF LENGTH(pmv_msg_in) > 255 THEN
  "   dbms_output.put_line(SUBSTR(pmv_msg_in,1,255));
  "   show_output(SUBSTR(pmv_msg_in,256,LENGTH(pmv_msg_in)));
  "  ELSE
  "   dbms_output.put_line(pmv_msg_in);
  "  END IF;
  " EXCEPTION
  "  WHEN OTHERS THEN
  "   dbms_output.enable(1000000);
  "   show_output(SUBSTR(pmv_msg_in,256,LENGTH(pmv_msg_in)));
  " END show_output;
  "BEGIN
  " FOR r_opt IN org_options
  " LOOP
  "  IF r_opt.application_id != l_appl_id
  "  THEN
  "   l_appl_id := r_opt.application_id;
  "   set_header(l_appl_id,'3','Active Organization Profile Options');
  "  END IF;
  "  OPEN org_values(r_opt.application_id,r_opt.poi);
  "  FETCH org_values
  "   INTO r_org;
  "  IF org_values%found
  "  THEN
  "   IF (r_org.prof_name LIKE '%\_PASS' ESCAPE '\') OR
  "      (r_org.prof_name LIKE '%\_PASSWD' ESCAPE '\') OR
  "      (r_org.prof_name LIKE '%\_PASSWORD' ESCAPE '\') OR
  "      (r_org.prof_name LIKE '%PWD')
  "   THEN
  "    IF r_org.org_value IS NOT NULL
  "    THEN
  "     r_org.org_value := '%R:PASSWORD%';
  "    END IF;
  "    IF r_org.prof_value IS NOT NULL
  "    THEN
  "     r_org.prof_value := '%R:PASSWORD%';
  "    END IF;
  "    IF r_org.site_value IS NOT NULL
  "    THEN
  "     r_org.site_value := '%R:PASSWORD%';
  "    END IF;
  "    IF r_org.user_value IS NOT NULL
  "    THEN
  "     r_org.user_value := '%R:PASSWORD%';
  "    END IF;
  "   ELSE
  "    r_org.org_value  := REPLACE(r_org.org_value,'.','&#46;');
  "    r_org.prof_value := REPLACE(r_org.prof_value,'.','&#46;');
  "    r_org.site_value := REPLACE(r_org.site_value,'.','&#46;');
  "    r_org.user_value := REPLACE(r_org.user_value,'.','&#46;');
  "   END IF;
  "   dbms_output.put_line('[[[');
  "   show_output('|' ||
  "               REPLACE(r_opt.upon,' ','&nbsp;') || '|' ||
  "               r_org.prof_name || '|' ||
  "               r_org.prof_value || ' | ' ||
  "               r_org.site_flag || ' |' ||
  "               r_org.site_value || ' |' ||
  "               r_org.org_name || ' | ' ||
  "               r_org.org_flag || ' |' ||
  "               r_org.org_value || ' | ' ||
  "               r_org.user_flag || ' |' ||
  "               r_org.user_value || ' |');
  "   dbms_output.put_line(']]]');
  "  END IF;
  "  CLOSE org_values;
  " END LOOP;
  "END;
  "/
  }
  prefix
   write
  call writeSql(bindSql($sql,$USER_ID,$SHORT_LIST))
  if hasOutput(true)
   write $TOP
 }

 # Get the profile options for OAM_DIAG_%TIME%
 set $sql
 {SELECT '|' ||
 "       b.user_profile_option_name || ' |' ||
 "       a.profile_option_name || ' |' ||
 "       DECODE(TO_CHAR(c.level_id),'10001','Site',
 "                                  '10002','Appl',
 "                                  '10003','Resp',
 "                                  '10004','User',
 "                                  'Unknown') || ' |' ||
 "       DECODE(TO_CHAR(c.level_id),
 "          '10001','Site',
 "          '10002',NVL(h.application_short_name,TO_CHAR(c.level_value)),
 "          '10003',NVL(g.responsibility_name,TO_CHAR(c.level_value)),
 "          '10004',NVL(e.user_name,TO_CHAR(c.level_value)),
 "          'Unknown') || ' |' ||
 "       c.profile_option_value || ' |' ||
 "       TO_CHAR(c.last_update_date,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
 "       NVL(d.user_name,TO_CHAR(c.last_updated_by)) || ' |'
 " FROM fnd_profile_options a,fnd_profile_options_vl b,
 "      fnd_profile_option_values c,fnd_user d,fnd_user e,
 "      fnd_responsibility_vl g,fnd_application h
 " WHERE a.profile_option_name LIKE 'OAM_DIAG_%TIME%'
 "   AND a.profile_option_name = b.profile_option_name
 "   AND a.profile_option_id = c.profile_option_id
 "   AND a.application_id = c.application_id
 "   AND c.last_updated_by = d.user_id (+)
 "   AND c.level_value = e.user_id (+)
 "   AND c.level_value = g.responsibility_id (+)
 "   AND c.level_value = h.application_id (+)
 " ORDER BY b.user_profile_option_name,c.level_id,
 "          DECODE(TO_CHAR(c.level_id),
 "            '10001','Site',
 "            '10002',NVL(h.application_short_name,TO_CHAR(c.level_value)),
 "            '10003',NVL(g.responsibility_name,TO_CHAR(c.level_value)),
 "            '10004',NVL(e.user_name,TO_CHAR(c.level_value)),
 "            'Unknown');
 }
 prefix
 {write '---++ Profile Option Values for OAM_DIAG_%TIME%'
  write '|*Profile Option Name*|*Internal Name*|*Level*|*Level Value*|\
          *Effective Value*|*Updated Date*|*Updated By*|'
 }
 call writeSql($sql)
 if hasOutput(true)
  write $TOP

 # Termine the profile report
 call act_menu(3,'Profile Option Values')

=head2 triggers - Database Triggers

Lists the database triggers on tables of the specified Applications products.

=cut

 debug ' Inside ACT module, gathering database triggers ...'
 var (@TTL,@HDR) = ()
 call act_report('triggers')
 var $TTL[1] = '---+ Database Triggers'
 var @col = ('table_owner','table_name','trigger_name','trigger_type',\
             'triggering_event','status')
 call setSqlHeader('ACT','triggering_event','*Event* ')
 call setSqlColumns('ACT',\
                    'trigger_type',    "REPLACE(trigger_type,' ','&nbsp;')",\
                    'triggering_event',"REPLACE(triggering_event,' ','&nbsp;')")
 var ($HDR[1],$col) = getSqlColumns('ACT','SYS','ALL_TRIGGERS',@col)
 call clearSqlColumns('ACT')
 set $sql
 {SELECT :1
 " FROM sys.all_triggers
 " WHERE table_owner IN (:2)
 " ORDER BY table_owner,table_name,trigger_name;
 }
 call act_separator(1)
 call writeSql(bindSql($sql,$col,$OWNERS))
 call act_separator(0)
 call act_menu(3,'Database Triggers')

=head2 indexes - Table Indexes

Lists the database indexes on tables of the specified Applications products.

=cut

 debug ' Inside ACT module, gathering table indexes ...'
 var (@TTL,@HDR) = ()
 call act_report('indexes')
 var $TTL[1] = '---+ Table Indexes'
 var @col = ('table_owner','table_name','index_name','index_type','status',\
             'last_analyzed')
 call setSqlColumns('ACT','last_analyzed',\
        "TO_CHAR(last_analyzed,'DD-Mon-YYYY\042&nbsp;\042HH24:MI:SS')")
 var ($HDR[1],$col) = getSqlColumns('ACT','SYS','ALL_INDEXES',@col)
 call clearSqlColumns('ACT')
 set $sql
 {SELECT :1
 " FROM sys.all_indexes
 " WHERE table_owner IN (:2)
 " ORDER BY table_owner,table_name,index_name;
 }
 call act_separator(1)
 call writeSql(bindSql($sql,$col,$OWNERS))
 call act_separator(0)
 call act_menu(3,'Table Indexes')

=head2 packages - Package Versions

Lists the versions of the package specifications and bodies for the specified
Applications products.

=cut

 debug ' Inside ACT module, gathering package versions ...'
 call act_report('packages')

 # Get dictionary information
 set $sql
 {SELECT column_name
 " FROM all_tab_columns
 " WHERE owner = 'SYS'
 " AND table_name = 'OBJ$'
 " AND column_name IN ('TYPE','TYPE#')
 " AND ROWNUM = 1;
 "SELECT DISTINCT SUBSTR(o.name,1,INSTR(o.name,'_') - 1)
 " FROM sys.obj$ o,sys.tab$ t,sys.user$ u
 " WHERE u.name in (:1)
 "   AND o.owner# = u.user#
 "   AND t.obj# = o.obj#
 "   AND INSTR(o.name,'_') !=  0
 "   AND o.name LIKE DECODE(u.name,'GL','GL%','%');
 }
 var ($typ,@tbl) = grepSql(bindSql($sql,$OWNERS),'\S')

 # Collect the package
 set $sql
 {SELECT '|' ||
 "       o.name || '|' ||
 "       LTRIM(RTRIM(SUBSTRB(SUBSTR(s.source,INSTR(s.source,'Header: ')),
 "        INSTR(SUBSTR(s.source,INSTR(s.source,'Header: ')),' ',1,1),
 "        INSTR(SUBSTR(s.source,INSTR(s.source,'Header: ')),' ',1,2) -
 "        INSTR(SUBSTR(s.source,INSTR(s.source,'Header: ')),' ',1,1))))
 "        || '|' ||
 "       REPLACE(LTRIM(RTRIM(SUBSTRB(
 "        SUBSTR(s.source,INSTR(s.source,'Header: ')),
 "        INSTR(SUBSTR(s.source,INSTR(s.source,'Header: ')),' ',1,2),
 "        INSTR(SUBSTR(s.source,INSTR(s.source,'Header: ')),' ',1,3) -
 "        INSTR(SUBSTR(s.source,INSTR(s.source,'Header: ')),' ',1,2)))),
 "        '.','&#46;')
 "        || '|' ||
 "       DECODE(o.:1,9,'SPEC',11,'BODY',o.:1) || '|' ||
 "       DECODE(o.status,0,'N/A',1,'VALID','INVALID') || '|' ||
 "       TO_CHAR(o.mtime,'DD-Mon-YYYY HH24:MI:SS') || '|'
 " FROM sys.source$ s,sys.obj$ o,sys.user$ u
 " WHERE u.name LIKE UPPER(':2%')
 "   AND o.owner# = u.user#
 "   AND s.obj# = o.obj#
 "   AND s.line BETWEEN 2 AND 5
 "   AND s.source LIKE '%Header: %'
 "   AND (o.:1 = 9 OR o.:1 = 11)
 "   AND (o.name LIKE ':3%')
 " ORDER BY o.name,
 "          DECODE(o.:1,9,'SPEC',11,'BODY',o.:1);
 }
 if @tbl
 {prefix
  {write '---+ Package Versions'
   write '|*Name*|*File Name*|*Version*|*Type*|*Status*|*Compiled*|'
  }
  call writeSql(bindSql($sql,$typ,$LOGIN_ID,\
                        cond(grep(@tbl,'^PA$','i'),\
                             concat(join("%' OR o.name LIKE '",@tbl),\
                                    "%') AND (o.name NOT LIKE 'PAY"),\
                             join("%' OR o.name LIKE '",@tbl))))
  if hasOutput(true)
  {write $TOP
   call act_menu(3,'Package Versions')
  }
 }

=head2 invalid_objs - Invalid Objects/Errors

Lists the invalid objects or errors for the specified Applications products.

=cut

 debug ' Inside ACT module, gathering Invalid objects/errors ...'
 call act_report('invalid_objs')
 set $sql
 {SELECT '|' ||
 "       o.name || '|' ||
 "       DECODE(o.type#,4,'VIEW',
 "                      7,'PROCEDURE',
 "                      8,'FUNCTION',
 "                      12,'TRIGGER',
 "                      13,'TYPE',
 "                      14,'TYPE BODY',
 "                      28,'JAVA SOURCE',
 "                      29,'JAVA CLASS',
 "                      43,'DIMENSIONS',
 "                      'UNDEFINED') || '| ' ||
 "       e.sequence# || '|' ||
 "       NVL(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(e.text),
 "        '|','&#124;'),
 "        '<','&lt;'),
 "        '>','&gt;'),
 "        CHR(10),'%BR%'),
 "        'No Errors') || '|'
 " FROM sys.obj$ o,sys.error$ e,sys.user$ u
 " WHERE u.name LIKE UPPER(':1%')
 "   AND o.owner# = u.user#
 "   AND o.obj#   = e.obj#(+)
 "   AND o.status NOT IN (0,1)
 "   AND o.type# IN (4,7,8,12,13,14,28,29,43)
 "   AND (o.name LIKE ':2%')
 " ORDER BY o.name,e.sequence#;
 }
 if @tbl
 {prefix
  {write '---+ Invalid Objects/Errors'
   write '|*Name*|*Type*| *Sequence*|*Error*|'
  }
  call writeSql(bindSql($sql,$LOGIN_ID,join("%' OR o.name LIKE '",@tbl)))
  if hasOutput(true)
  {write $TOP
   call act_menu(3,'Invalid Objects/Errors')
  }
 }

=head2 invalid_refobjs - Invalid Referenced Objects

Lists the invalid referenced objects for the specified Applications products.

=cut

 debug ' Inside ACT module, gathering Invalid Referenced objects ...'
 call act_report('invalid_refobjs')
 set $sql
 {SELECT '|' ||
 "       r.name || '|' ||
 "       DECODE(r.type#,4,'VIEW',
 "                      7,'PROCEDURE',
 "                      8,'FUNCTION',
 "                      9,'PACKAGE',
 "                      11,'PACKAGE BODY',
 "                      12,'TRIGGER',
 "                      13,'TYPE',
 "                      14,'TYPE BODY',
 "                      28,'JAVA SOURCE',
 "                      29,'JAVA CLASS',
 "                      43,'DIMENSIONS',
 "                      'UNDEFINED') || '| ' ||
 "       e.sequence# || '|' ||
 "       NVL(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(e.text),
 "        '|','&#124;'),
 "        '<','&lt;'),
 "        '>','&gt;'),
 "        CHR(10),'%BR%'),
 "        'No Errors') || '|'
 " FROM sys.obj$ o,sys.error$ e,sys.user$ u,sys.dependency$ d,sys.obj$ r
 " WHERE u.name LIKE UPPER(':1%')
 "   AND o.owner# = u.user#
 "   AND o.obj#   = d.d_obj#
 "   AND r.obj#   = d.p_obj#
 "   AND r.status NOT IN (0,1)
 "   AND r.obj#   = e.obj#(+)
 "   AND o.type# IN (4,7,8,9,11,12,13,14,28,29,43)
 "   AND (r.name NOT LIKE ':2%')
 " ORDER BY r.name,e.sequence#;
 }
 if @tbl
 {prefix
  {write '---+ Invalid Referenced Objects'
   write '|*Name*|*Type*| *Sequence*|*Error*|'
  }
  call writeSql(bindSql($sql,$LOGIN_ID,join("%' AND r.name NOT LIKE '",@tbl)))
  if hasOutput(true)
  {write $TOP
   call act_menu(3,'Invalid Referenced Objects')
  }
 }
}

# Parsing the patch list file
var $fil = 'PatchList.xml'
var $fil = nvl(testFile('f',catFile(${CFG.D_RDA},$fil)),\
               testFile('f',catFile(${CFG.D_RDA},upDir(),upDir(),'html',$fil)),\
               testFile('f',catFile($IZU_TOP,'html',$fil)),\
               $fil)
var $PATCH_LIST = xmlLoadFile($fil)

# Determine which patches have been installed
var %PATCH_LIST = ()
loop $itm (xmlFind($PATCH_LIST,'.../patchset/number'))
 var $PATCH_LIST{xmlData($itm)} = 0
var $str = join("',\012'",keys(%PATCH_LIST))
if $str
{set $sql
 {SELECT bug_number
 " FROM ad_bugs
 " WHERE bug_number IN (':1');
 }
 loop $itm (grepSql(bindSql($sql,$str),'^\d+\s*$'))
  var $PATCH_LIST{trim($itm)} = 1
}
if ?testFile('r',catFile($APPL_TOP,'admin',$APPL_DB_SID,'applptch.txt'))
{loop $lin (grepFile(lastFile(),'^\s*begin\s+(aru|bug)\s+'))
 {if match($lin,'(\d+)')
  {var ($key) = (last)
   var $PATCH_LIST{$key} = 2
  }
 }
}

# Get list of installed and base languages to be used for Forms and Reports
set $sql
{SELECT installed_flag || '|' || language_code
" FROM fnd_languages
" WHERE installed_flag IN ('I','B');
}
if loadSql($sql)
{var (@BASE_LANG_CODE,@INST_LANG_CODE) = ()
 loop $lin (grepLastSql('^[IB]'))
 {if match($lin,'^B\|(.*)$')
   call push(@BASE_LANG_CODE,last)
  elsif match($lin,'^I\|(.*)$')
   call push(@INST_LANG_CODE,last)
 }
 var @ALL_LANG = (@BASE_LANG_CODE,@INST_LANG_CODE)
 var $INST_LANG = join(' ',@ALL_LANG)
}
elsif @{T_LANGS}
 var @ALL_LANG = last
else
 var @ALL_LANG = ('US')

=head2 tops - Product Tops

Reports the directories containing all code for the specified Applications
products.

=cut

if $DB_ACCESS
{debug ' Inside ACT module, gathering product tops ...'
 call act_report('tops','Product Tops')
 set $sql
 {SELECT DISTINCT application_short_name || '|' ||
 "       application_id || '|' ||
 "       basepath
 " FROM fnd_application
 " WHERE application_id IN
 "        (SELECT application_id
 "          FROM fnd_application
 "          WHERE application_short_name IN (:1)
 "        );
 }
 call loadSql(bindSql($sql,$SHORT_LIST))
 write '|*Short Name*|*Base Path*| *Application ID*|*File System Path*|'
 loop $lin (grepLastSql('_TOP'))
 {var ($abr,$aid,$bas) = split('\|',$lin,3)
  write '|',$abr,'|',$bas,' | ',$aid,'|',\
        getEnv(concat(nvl($TB_VAL{$abr},$abr),'_TOP')),' |'
 }
 write 'Note that the date stamps after the versions represent the \
        modifications of the files and not the dates from the version lines. \
        Date stamps are listed only in those sections where modified date is \
        relevant (eg. linked or compiled files).%BR%'
 call act_menu(3,'Product Tops',true)
}

=head2 custom_lib - Custom Library Information

Reports the custom library information for the specified Applications
products.

=cut

debug ' Inside ACT module, gathering Custom Library Information ...'
call act_report('custom_lib')
var $TTL = act_title('Custom Library Information')
var $cnt = 0
var $fil = catFile(${ENV.AU_TOP:''},'resource','CUSTOM.plx')
if ?testFile('r',$fil)
{prefix
 {if $TTL
  {write $TTL
   var $TTL = undef
  }
  write '---++ Strings from ',encode($fil)
 }
 loop $pat ('[Ee][Vv][Ee][Nn][Tt]','[Bb][Ll][Oo][Cc][Kk]','[Ff][Oo][Rr][Mm]')
 {call loadString($fil,concat('[\040-\176]*',$pat,\
                              '_[Nn][Aa][Mm][Ee][\040-\176]*'))
  call writeLastFile()
 }
 if hasOutput(true)
  incr $cnt
}
if $DB_ACCESS
{set $sql
 {SELECT fa.basepath || '|' ||
 "       NVL(fe.execution_file_name,fe.executable_name)
 " FROM fnd_application fa,fnd_executables fe
 " WHERE fa.application_id IN
 "        (SELECT application_id
 "          FROM fnd_application
 "          WHERE application_short_name IN (:1)
 "        )
 " AND fa.application_id not in (660,661,665)
 " AND fa.application_id = fe.application_id
 " AND fe.execution_method_code in ('A','H','S');
 }
 call loadSql(bindSql($sql,$SHORT_LIST))
 var %tbl = ()
 loop $lin (grepLastSql('_TOP'))
 {var ($bas,$fil) = split('\|',$lin,2)
  var $tbl{$bas} = join('|',$tbl{$bas},verbatim($fil))
 }
 loop $bas (keys(%tbl))
 {incr $cnt,get_prod_version(false,field('_',0,$bas),'bin',$tbl{$bas},false,'',\
                             true,false,@ALL_LANG)
 }
}
if $cnt
 write $TOP
call act_menu(3,'Custom Library Information')

=head2 bom_info - Bill of Materials Information

Gathers information for the Bill of Materials when requested.

=cut

if $DB_ACCESS
{if $ALL_SHORT{'BOM'}
 {debug ' Inside ACT module, gathering Bill of Materials information ...'
  call act_report('bom_info','Bill of Materials Information')
  call act_toc()
  var @TTL = ('',\
    '---++ Item Attributes',\
    '---++ Organization Parameters',\
    '---++ Enabled System Items Segments',\
    '---++ Enabled Stock Locators Segments',\
    '---++ BOM Parameters')

  var @HDR = ('',\
    '|*Attribute Name*|*User Attribute Name Gui*|*Control Level*\
     |*Status Control Code*|*Level Updateable Flag*|',\
    '|*Organization ID*|*Organization Code*|*Master Organization ID*\
     |*Primary Cost Method*|*Cost Organization ID*|*Calendar Code*\
     |*Material Account*|*Material Overhead Account*|*Mtl Ovhd Absorption Acct*\
     |*Resource Account*|*Purchase Price Var Account*|*Ap Accrual Account*\
     |*Overhead Account*|*Outside Processing Account*|*Intransit Inv Account*\
     |*Interorg Receivables Account*|*Interorg Price Var Account*\
     |*Interorg Payables Account*|*Cost Of Sales Account*|*Encumbrance Account*\
     |*Project Cost Account*|*Interorg Transfer Cr Account*\
     |*Matl Interorg Transfer Code*|*Interorg Trnsfr Charge Percent*\
     |*Source Organization ID*|*Source Subinventory*|*Source Type*\
     |*Invoice Price Var Account*|*Average Cost Var Account*|*Sales Account*\
     |*Expense Account*|*Avg Rates Cost Type ID*|*Process Enabled Flag*\
     |*Process Orgn Code*|*Wsm Enabled Flag*|*Default Cost Group ID*\
     |*Wms Enabled Flag*|*Cartonization Flag*|*Eam Enabled Flag*\
     |*Stock Locator Control*|*Starting Revision*|*Lot Number Uniqueness*\
     |*Lot Number Generation*|*Lot Number Zero Padding*|*Lot Number Length*\
     |*Auto Lot Alpha Prefix*|*Serial Number Type*|*Serial Number Generation*\
     |*Auto Serial Alpha Prefix*|*Starting Serial Number*|*Allocate Serial Flg*\
     |*Default Picking Rule*|*Default Subinv Order Value*\
     |*Default Locator Order Value*|*Mo Pick Confirm Required*|',\
    '|*Segment Number*|*Segment Name*|*Column Name*|*Required Flag*|',\
    '|*Segment Number*|*Segment Name*|*Column Name*|*Required Flag*|',\
    '|*Organization ID*|*Last Update Date*|*Last Updated By*|*Creation Date*\
     |*Created By*|*Last Update Login*|*Maximum Bom Level*|*Config Segmnt Name*\
     |*BOM Delete Status Code*|*Config Number Method Type*|*Attribute Category*\
     |*Attribute1*|*Attribute2*|*Attribute3*|*Attribute4*|*Attribute5*\
     |*Attribute6*|*Attribute7*|*Attribute8*|*Attribute9*|*Attribute10*\
     |*Attribute11*|*Attribute12*|*Attribute13*|*Attribute14*|*Attribute15*\
     |*Request ID*|*Program Application ID*|*Program ID*|*Program Update Date*\
     |*Global Attribute Category*|*Global Attribute1*|*Global Attribute2*\
     |*Global Attribute3*|*Global Attribute4*|*Global Attribute5*\
     |*Global Attribute6*|*Global Attribute7*|*Global Attribute8*\
     |*Global Attribute9*|*Global Attribute10*|*Global Attribute11*\
     |*Global Attribute12*|*Global Attribute13*|*Global Attribute14*\
     |*Global Attribute15*|*Global Attribute16*|*Global Attribute17*\
     |*Global Attribute18*|*Global Attribute19*|*Global Attribute20*\
     |*Use Phantom Routings*|*Inherit Phantom Op Seq*|')
  set $sql
  {SELECT '|' ||
  "       SUBSTR(mia.attribute_name,18) || ' |' ||
  "       mia.user_attribute_name_gui || ' |' ||
  "       DECODE(mia.control_level,
  "              1,'MASTER',
  "              2,'ORG',
  "              3,'VIEWABLE') || ' |' ||
  "       DECODE(mia.status_control_code,
  "              1,'SETS VALUE',
  "              2,'DEFAULTS VALUE',
  "              3,'NOT USED') || ' |' ||
  "       mia.level_updateable_flag || ' |'
  " FROM mtl_item_attributes mia
  " ORDER BY mia.attribute_group_id_gui, mia.user_attribute_name_gui;
  "PROMPT ___Macro_act_separator(2)___
  "SELECT '|' ||
  "       mp.organization_id || ' |' ||
  "       mp.organization_code || ' |' ||
  "       mp.master_organization_id || ' |' ||
  "       mp.primary_cost_method || ' |' ||
  "       mp.cost_organization_id || ' |' ||
  "       mp.calendar_code || ' |' ||
  "       mp.material_account || ' |' ||
  "       mp.material_overhead_account || ' |' ||
  "       mp.matl_ovhd_absorption_acct || ' |' ||
  "       mp.resource_account || ' |' ||
  "       mp.purchase_price_var_account || ' |' ||
  "       mp.ap_accrual_account || ' |' ||
  "       mp.overhead_account || ' |' ||
  "       mp.outside_processing_account || ' |' ||
  "       mp.intransit_inv_account || ' |' ||
  "       mp.interorg_receivables_account || ' |' ||
  "       mp.interorg_price_var_account || ' |' ||
  "       mp.interorg_payables_account || ' |' ||
  "       mp.cost_of_sales_account || ' |' ||
  "       mp.encumbrance_account || ' |' ||
  "       mp.project_cost_account || ' |' ||
  "       mp.interorg_transfer_cr_account || ' |' ||
  "       mp.matl_interorg_transfer_code || ' |' ||
  "       mp.interorg_trnsfr_charge_percent || ' |' ||
  "       mp.source_organization_id || ' |' ||
  "       mp.source_subinventory || ' |' ||
  "       mp.source_type || ' |' ||
  "       mp.invoice_price_var_account || ' |' ||
  "       mp.average_cost_var_account || ' |' ||
  "       mp.sales_account || ' |' ||
  "       mp.expense_account || ' |' ||
  "       mp.avg_rates_cost_type_id || ' |' ||
  "       mp.process_enabled_flag || ' |' ||
  "       mp.process_orgn_code || ' |' ||
  "       mp.wsm_enabled_flag || ' |' ||
  "       mp.default_cost_group_id || ' |' ||
  "       mp.wms_enabled_flag || ' |' ||
  "       mp.cartonization_flag || ' |' ||
  "       mp.eam_enabled_flag || ' |' ||
  "       DECODE(mp.stock_locator_control_code,
  "              1,'None',
  "              2,'Prespecified Only',
  "              3,'Dynamic entry allowed',
  "              4,'Determined at subinventory level') || ' |' ||
  "       mp.starting_revision || ' |' ||
  "       DECODE(mp.lot_number_uniqueness,
  "              2,'None',
  "              1,'Across Items') || ' |' ||
  "       DECODE(mp.lot_number_generation,
  "              1,'At Organization Level',
  "              2,'At Item Level',
  "              3,'User Defined') || ' |' ||
  "       DECODE(mp.lot_number_zero_padding,
  "              1,'Yes',
  "              2,'No') || ' |' ||
  "       mp.lot_number_length || ' |' ||
  "       mp.auto_lot_alpha_prefix || ' |' ||
  "       DECODE(mp.serial_number_type,
  "              1,'Within Inventory model and items',
  "              2,'Within Organization',
  "              3,'Across Organizations',
  "              4,'Within Inventory Items') || ' |' ||
  "       DECODE(mp.serial_number_generation,
  "              1,'At Organization Level',
  "              2,'At Item Level',
  "              3,'User Defined') || ' |' ||
  "       mp.auto_serial_alpha_prefix || ' |' ||
  "       mp.start_auto_serial_number || ' |' ||
  "       DECODE(mp.allocate_serial_flag,
  "              'Y','Yes',
  "              'N','No',
  "              'C','Yes - User Defined') || ' |' ||
  "       mp.default_picking_rule || ' |' ||
  "       mp.default_subinv_order_value || ' |' ||
  "       mp.default_locator_order_value || ' |' ||
  "       DECODE(mp.mo_pick_confirm_required,
  "              1,'Yes',
  "              2,'No')  || ' ' ||
  "       :1
  " FROM mtl_parameters_view mp
  " ORDER BY  mp.master_organization_id ,mp.organization_id;
  "PROMPT ___Macro_act_separator(3)___
  "SELECT '|' ||
  "       segment_num || ' |' ||
  "       segment_name || ' |' ||
  "       application_column_name || ' |' ||
  "       required_flag || ' |'
  " FROM  fnd_id_flex_segments_vl
  " WHERE application_id = 401
  "   AND id_flex_code = 'MSTK'
  "   AND id_flex_num = 101
  "   AND enabled_flag = 'Y'
  " ORDER BY segment_num;
  "PROMPT ___Macro_act_separator(4)___
  "SELECT '|' ||
  "       segment_num || ' |' ||
  "       segment_name || ' |' ||
  "       application_column_name || ' |' ||
  "       required_flag || ' |'
  " FROM  fnd_id_flex_segments_vl
  " WHERE application_id = 401
  "   AND id_flex_code = 'MTLL'
  "   AND id_flex_num = 101
  "   AND enabled_flag = 'Y'
  " ORDER BY segment_num;
  "PROMPT ___Macro_act_separator(5)___
  "SELECT '|' ||
  "       bp.organization_id || ' |' ||
  "       bp.last_update_date || ' |' ||
  "       bp.last_updated_by || ' |' ||
  "       bp.creation_date || ' |' ||
  "       bp.created_by || ' |' ||
  "       bp.last_update_login || ' |' ||
  "       bp.maximum_bom_level || ' |' ||
  "       bp.config_segment_name || ' |' ||
  "       bp.bom_delete_status_code || ' |' ||
  "       bp.config_number_method_type || ' |' ||
  "       bp.attribute_category || ' |' ||
  "       bp.attribute1 || ' |' ||
  "       bp.attribute2 || ' |' ||
  "       bp.attribute3 || ' |' ||
  "       bp.attribute4 || ' |' ||
  "       bp.attribute5 || ' |' ||
  "       bp.attribute6 || ' |' ||
  "       bp.attribute7 || ' |' ||
  "       bp.attribute8 || ' |' ||
  "       bp.attribute9 || ' |' ||
  "       bp.attribute10 || ' |' ||
  "       bp.attribute11 || ' |' ||
  "       bp.attribute12 || ' |' ||
  "       bp.attribute13 || ' |' ||
  "       bp.attribute14 || ' |' ||
  "       bp.attribute15 || ' |' ||
  "       bp.request_id || ' |' ||
  "       bp.program_application_id || ' |' ||
  "       bp.program_id || ' |' ||
  "       bp.program_update_date || ' |' ||
  "       bp.global_attribute_category || ' |' ||
  "       bp.global_attribute1 || ' |' ||
  "       bp.global_attribute2 || ' |' ||
  "       bp.global_attribute3 || ' |' ||
  "       bp.global_attribute4 || ' |' ||
  "       bp.global_attribute5 || ' |' ||
  "       bp.global_attribute6 || ' |' ||
  "       bp.global_attribute7 || ' |' ||
  "       bp.global_attribute8 || ' |' ||
  "       bp.global_attribute9 || ' |' ||
  "       bp.global_attribute10 || ' |' ||
  "       bp.global_attribute11 || ' |' ||
  "       bp.global_attribute12 || ' |' ||
  "       bp.global_attribute13 || ' |' ||
  "       bp.global_attribute14 || ' |' ||
  "       bp.global_attribute15 || ' |' ||
  "       bp.global_attribute16 || ' |' ||
  "       bp.global_attribute17 || ' |' ||
  "       bp.global_attribute18 || ' |' ||
  "       bp.global_attribute19 || ' |' ||
  "       bp.global_attribute20 || ' |' ||
  "       bp.use_phantom_routings || ' |' ||
  "       bp.inherit_phantom_op_seq || ' ' ||
  "       :2
  " FROM bom_parameters bp;
  }
  var ($hdr1,$col1) = getSqlColumns('ACT','','MTL_PARAMETERS_VIEW',\
                                    'WIP_OVERPICK_ENABLED',\
                                    'OVPK_TRANSFER_ORDERS_ENABLED')
  call clearSqlColumns('ACT')
  var ($hdr2,$col2) = getSqlColumns('ACT','','BOM_PARAMETERS',\
                                    'ENABLE_LOWER_LEVEL_SUPPLY',\
                                    'CREATE_CONFIG_BOM',\
                                    'INCLUDE_MODELS_IN_ROLLUP')
  call clearSqlColumns('ACT')
  if $hdr1
   var $HDR[2] = replace($HDR[2],'\|$',$hdr1)
  else
   var $col1   = "'|'"
  if $hdr2
   var $HDR[5] = replace($HDR[5],'\|$',$hdr2)
  else
   var $col2   = "'|'"
  call act_separator(1)
  call writeSql(bindSql($sql,$col1,$col2))
  call act_separator(0)
  call act_menu(3,'Bill of Materials Information')
 }
}

=head2 ldt_ver - LDT File Versions

Lists the version of the Loader Data Files for the specified Applications
products.

=cut

if or($TIER_ADMIN,not($MULTI_NODE))
{debug ' Inside ACT module, gathering Loader Data (LDT) File versions ...'
 call act_report('ldt_ver')
 var $TTL = act_title('LDT File Versions')
 var $cnt = 0
 loop $prd (keys(%ALL_SHORT))
 {loop $dir (find_prod_dir2($prd,'patch','import'))
   incr $cnt,get_prod_version(false,$prd,$dir,'*.ldt',false,'',false,\
                              false,@ALL_LANG)
 }
 if $cnt
  write $TOP
 call act_menu(3,'LDT File Versions')
}

=head2 frm_ver - Form Versions

Lists the version of the forms for the specified Applications products.

=cut

if or($TIER_FORMS,not($MULTI_NODE))
{debug ' Inside ACT module, gathering form versions ...'
 call act_report('frm_ver')
 var $TTL = act_title('Form Versions')
 var $cnt = 0
 loop $prd (keys(%ALL_SHORT))
 {incr $cnt,get_prod_version(false,$prd,'forms','*.fmx',true,'fm[bx]',false,\
                             false,@ALL_LANG)
  incr $cnt,get_prod_version(false,$prd,'forms','*.inp',true,'',false,\
                             false,@ALL_LANG)
 }
 if $cnt
  write $TOP
 call act_menu(3,'Form Versions')
}

=head2 frm_lib_ver - Form Library Versions

Lists the version of the form libraries for the specified Applications products.

=cut

if or($TIER_FORMS,not($MULTI_NODE))
{debug ' Inside ACT module, gathering Form library versions ...'
 call act_report('frm_lib_ver')
 var $TTL = act_title('Form Library Versions')
 var $cnt = 0
 loop $prd (keys(%ALL_SHORT))
 {incr $cnt,get_prod_version(false,'AU','resource',concat($prd,'*.plx'),true,\
                             'pl[dx]')
  if compare('eq',$prd,'ONT')
   incr $cnt,get_prod_version(false,'AU','resource','OE*.plx',true,'pl[dx]')
  if compare('eq',$prd,'PO')
   incr $cnt,get_prod_version(false,'AU','resource','RCV*.plx',true,'pl[dx]')
 }
 if $cnt
  write $TOP
 call act_menu(3,'Form Library Versions')
}

=head2 rpt_ver - Report Versions

Lists the version of the reports for the specified Applications products.

=cut

if or($TIER_NODE,not($MULTI_NODE))
{debug ' Inside ACT module, gathering report versions ...'
 call act_report('rpt_ver')
 var $TTL = act_title('Report Versions')
 var $cnt = 0
 loop $prd (keys(%ALL_SHORT))
 {incr $cnt,get_prod_version(false,$prd,'srw','*.rdf',true,'',false,\
                             false,@ALL_LANG)
  incr $cnt,get_prod_version(false,$prd,'reports','*.rdf',true,'',false,\
                             false,@ALL_LANG)
 }
 if $cnt
  write $TOP
 call act_menu(3,'Report Versions')
}

=head2 rpt_lib_ver - Report Library Versions

Lists the version of the report libraries for the specified Applications
products.

=cut

if or($TIER_NODE,not($MULTI_NODE))
{debug ' Inside ACT module, gathering report library versions ...'
 call act_report('rpt_lib_ver')
 var $TTL = act_title('Report Library Versions')
 var $cnt = 0
 loop $prd (keys(%ALL_SHORT))
 {incr $cnt,get_prod_version(false,'AU','plsql',concat($prd,'*.pll'),true,\
                             'pl[dl]')
  if compare('eq',$prd,'ONT')
   incr $cnt,get_prod_version(false,'AU','plsql','OE*.pll',true,'pl[dl]')
 }
 if $cnt
  write $TOP
 call act_menu(3,'Report Library Versions')
}

=head2 wf_ver - Workflow File Versions

Lists the version of the workflow files for the specified Applications products.

=cut

if or($TIER_ADMIN,not($MULTI_NODE))
{debug ' Inside ACT module, gathering workflow file versions ...'
 call act_report('wf_ver')
 var $TTL = act_title('Workflow File Versions')
 var $cnt = 0
 loop $prd (keys(%ALL_SHORT))
 {loop $dir (find_prod_dir2($prd,'patch','import'))
   incr $cnt,get_prod_version(false,$prd,$dir,'*.wft',false,'',false,\
                              false,@ALL_LANG)
 }
 if $cnt
  write $TOP
 call act_menu(3,'Workflow File Versions')
}

=head2 odf_ver - ODF File Versions

Lists the version of the ODF files for the specified Applications products.

=cut

if or($TIER_ADMIN,not($MULTI_NODE))
{debug ' Inside ACT module, gathering ODF file versions ...'
 call act_report('odf_ver')
 var $TTL = act_title('ODF File Versions')
 var $cnt = 0
 loop $prd (keys(%ALL_SHORT))
 {incr $cnt,get_prod_version(false,$prd,'admin/odf','*.odf')
  if ?testDir('d',catDir(getEnv(concat($prd,'_TOP')),'patchsc'))
   incr $cnt,get_prod_version(false,$prd,'install/odf','*.odf')
  loop $dir (find_prod_dir2($prd,'patch','odf'),\
             find_prod_dir2($prd,'patchsc','odf'))
   incr $cnt,get_prod_version(false,$prd,$dir,'*.odf')
 }
 if $cnt
  write $TOP
 call act_menu(3,'ODF File Versions')
}

=head2 proc_ver - Pro*C File Versions

Lists the versions of the objects files, shared libraries, and executable files
for the specified Applications products.

=cut

if or($TIER_NODE,not($MULTI_NODE))
{debug ' Inside ACT module, gathering Pro*C file versions ... (can take time)'
 call act_report('proc_ver')
 var $TTL = act_title('Pro*C File Versions')
 var $cnt = 0
 if or(isWindows(),isCygwin())
 {loop $prd (keys(%ALL_SHORT))
  {incr $cnt,get_prod_version(false,$prd,'lib','*.obj',false,'\w+')
   incr $cnt,get_prod_version(false,$prd,'admin/odf','*.odf')
   incr $cnt,get_prod_version(false,$prd,'bin','*.exe',true,'',true)
   incr $cnt,get_prod_version(false,$prd,'bin','*.dll',true,'',true)
  }
 }
 else
 {loop $prd (keys(%ALL_SHORT))
  {incr $cnt,get_prod_version(false,$prd,'lib','lib*.a',true,'',true)
   incr $cnt,get_prod_version(false,$prd,'bin','*',true,'',true,true)
  }
 }
 if $cnt
  write $TOP
 call act_menu(3,'Pro*C File Versions')
}

=head2 extra_ver - Extra File Versions

Lists the version of the extra files for a restricted list of Applications
products.

=cut

if or($TIER_NODE,not($MULTI_NODE))
{debug ' Inside ACT module, gathering extra file versions ...'
 call act_report('extra_ver')
 var $TTL = act_title('Extra File Versions')

 # Parsing the location list file
 var $loc = 'location.xml'
 var $loc = nvl(\
   testFile('f',catFile(${CFG.D_RDA},$loc)),\
   testFile('f',catFile(${CFG.D_RDA},upDir(),upDir(),'html',$loc)),\
   testFile('f',catFile($IZU_TOP,'html',$loc)),\
   $loc)
 var $LOCATION_LIST = xmlLoadFile($loc)

 # Obtaining extra file versions
 var $cnt = 0
 loop $prd (keys(%ALL_SHORT))
 {loop $xml (xmlFind($LOCATION_LIST,\
                     concat('.../locations/product shortcode="',\
                            verbatim($prd),'"/directory')))
  {var $top = xmlValue($xml,'env')
   var $typ = xmlValue($xml,'type')
   var $dir = xmlData($xml)
   incr $cnt,get_prod_version(true,field('_',0,$top),catDir(split('\/',$dir)),\
                              concat('*.',$typ),true)
  }
 }
 if $cnt
  write $TOP
 call act_menu(3,'Extra File Versions')
}

=head2 java_ver - Java Class File Versions

Lists the version of the Java classes for the specified Applications products.

=cut

debug ' Inside ACT module, gathering Java class file versions ... \
        (can take time)'
call act_report('java_ver')
var $TTL = act_title('Java Class File Versions')
var $cnt = 0
if $JAVA_TOP
{loop $prd (keys(%ALL_SHORT))
 {next match($prd,'OFA|SQLAP|SQLGL|SYSADMIN')
  incr $cnt,get_class_version($JAVA_TOP,'oracle','apps',lc($prd))
 }
}
if $cnt
 write $TOP
call act_menu(3,'Java Class File Versions')

=head2 listener_ora - Contents of Listener.ora

Collects the content of the Applications tier F<listener.ora> file.

=cut

debug ' Inside ACT module, gathering contents of listener.ora ...'
call act_report('listener_ora')
write '---+ Contents of Listener.ora'

# Determine where listener.ora is
var $lsn = nvl(\
  testFile('f',catFile($TNS_ADMIN,'listener.ora')),\
  testFile('f',catFile($ORACLE_HOME,'net80','admin','listener.ora')),\
  testFile('f',catFile('/var','opt','oracle','listener.ora')),\
  testFile('f',catFile($ORACLE_HOME,'network','admin','listener.ora')),\
  '')

# Insert it but filter passwords out
if $lsn
{write '---## From ',encode($lsn)
 call writeFilter($lsn,'^(PASSWORDS_\w*\s*=).*$','%R:PASSWORD%')
}
else
{write 'No listener.ora file found'
 write '   * TNS_ADMIN  = ',encode($TNS_ADMIN)
 write '   * ORACLE_HOME = ',encode($ORACLE_HOME)
}
write $TOP
call act_menu(3,'Listener.ora')

=head2 jinit_ver - JInitiator Version

Collects Oracle JInitiator component versions.
(Applicable for Oracle Applications 11.5.x and earlier.)

=head2 plugin_ver - JDK Plug-in Version

Collects JDK plug-in version.
(Applicable for Oracle Applications 12.0.x and later.)

=cut

if or($TIER_WEB,not($MULTI_NODE))
{var $fil = catFile($INST_TOP,'ora','10.1.2','forms','server','appsweb.cfg')
 if ?testFile('r',$fil)
 {debug ' Inside ACT module, gathering JDK plugin version ...'
  call act_report('plugin_ver','JDK Plug-in Version')
  var $ver = field('=',1,grepFile($fil,'plugin_version','f'))
  write '   * JDK Plug-in Version=',nvl($ver,'N/A')
  call act_menu(3,'JDK Plug-in Version',true)
 }
 else
 {debug ' Inside ACT module, gathering JInitiator version ...'
  call act_report('jinit_ver','JInitiator Version')
  var $flg = false
  loop $lng (@ALL_LANG)
  {if ?testDir('dr',catDir($OA_HTML,$lng))
   {loop $fil (grepDir(lastDir(),'\.htm$','ip'))
    {next !grepFile($fil,'classid=')
     var $cls = replace(last,'<OBJECT ')
     var ($lin) = grepFile($fil,'^\s*codebase="[^/]','i')
     if and($cls,$lin)
     {if !$flg
       write ' It is not possible to determine which starting html file is in \
               use on a Release 11 system so listing all the files which have \
               jinitiator setting.%BR%'
      write '   * ',encode($fil)
      write '      * ',$cls
      write '      * ',replace($lin,'[\s\>]','',true)
      var $flg = true
     }
    }
   }
  }
  if !$flg
  {var $dir = catFile($OAH_TOP,'util','jinitiator')
   var ($exe) = grepDir($OA_HTML,'oajinit.exe','ir')
   var $fil = catFile($OA_HTML,'bin','appsweb.cfg')
   var $ver = field('=',2,grepFile($fil,'^jinit_mimetype=','f'))
   var $cls = field(':',1,grepFile($fil,'^jinit_classid=','f'))
   if match($ver,'^1\.1')
   {call loadString($exe,'AppName=[\040-\176]+')
    var $val = field('\s+',2,getLines(0,0))
   }
   else
    var $val = $ver
   write '   * Path=',encode($exe)
   write '   * Version from oajinit.exe=',cond($FILTERED,fmt_version($val),$val)
   write '   * Version from appsweb.cfg=',cond($FILTERED,fmt_version($ver),$ver)
   write '   * ClassID from appsweb.cfg=',$cls

   set $sql
   {SELECT text
   " FROM wf_resources
   " WHERE name = 'WF_PLUGIN_VERSION'
   "   AND Language = 'US';
   }
   var ($ver) = grepSql($sql,'\S','f')
   var $ver = replace($ver,' ',true)
   set $sql
   {SELECT text
   " FROM wf_resources
   " WHERE name = 'WF_CLASSID'
   "   AND language = 'US';
   }
   var ($cls) = grepSql($sql,'\S','f')
   write '   * Version from wf_resources=',\
         cond($FILTERED,fmt_version($ver),$ver)
   write '   * ClassID from wf_resources=',replace($cls,' ',true)

   prefix
    write '---++ Available JInitiator Executables in ',encode($dir)
   loop $str (grepDir($dir,'^jinit.*\.exe$','i'))
    write '   * ',$str
   unprefix
  }
  call act_menu(3,'JInitiator Version',true)
 }
}

=head2 dev_ver - Developer Version

Gets the version of the developer tools (Oracle Forms and Reports).

=cut

if or($TIER_FORMS,not($MULTI_NODE))
{debug ' Inside ACT module, gathering Developer version ...'
 call act_report('dev_ver','Developer Version')
 var $bin = catDir($ORACLE_HOME,'bin')
 if grepDir($bin,'^(rwrun60|f60runm)(\.exe)?$','i')
  var $DEV_VER = '6i'

 # Get the FORMS version
 write '   * Installed in ORACLE_HOME=',encode($ORACLE_HOME)
 if grepDir($bin,'^frmcmp_batch(\.bat|\.sh)?$','ip')
  var ($cmd) = (last)
 elsif compare('eq',$DEV_VER,'6i')
 {if or(isWindows(),isCygwin())
  {loop $lin (grepFile(catFile($ORACLE_HOME,'orainst','nt.rgs'),'854'))
   {next !match($lin,'Runtime','i')
    var $ver = trim(field('\s+',4,$lin),'"')
    break
   }
  }
  elsif grepDir($bin,'^f60runm(\.exe)?$','ip')
   var ($cmd) = (last)
 }
 elsif grepDir($bin,'^f45run(\.exe)?$','ip')
  var ($cmd) = (last)
 else
  var $cmd = undef
 if $cmd
 {var ($str) = grepCommand(concat(quote($cmd),' \?'),'\S','f')
  if match($str,'Version\s+(\S+)\s+')
   var ($ver) = (last)
 }
 write '   * Forms Version=',nvl(cond($FILTERED,fmt_version($ver),$ver),'N/A')

 # Get the REPORTS version
 var $ver = undef
 if grepDir($bin,'^rwrun(\.bat|\.sh)?$','ip')
  var ($cmd) = (last)
 elsif compare('eq',$DEV_VER,'6i')
 {if or(isWindows(),isCygwin())
  {loop $lin (grepFile(catFile($ORACLE_HOME,'orainst','nt.rgs'),'858'))
   {next !match($lin,'Runtime','i')
    var $ver = trim(field('\s+',4,$lin),'"')
    break
   }
  }
  elsif grepDir($bin,'^rwrun60(\.exe)?$','ip')
   var ($cmd) = (last)
 }
 elsif grepDir($bin,'^r25runm(\.exe)?$','ip')
  var ($cmd) = (last)
 else
  var $cmd = undef
 if $cmd
 {var ($str) = grepCommand(concat(quote($cmd),' \?'),'\S','f')
  if match($str,'Release\s+(\S+)\s+')
   var ($ver) = (last)
 }
 write '   * Reports Version=',nvl(cond($FILTERED,fmt_version($ver),$ver),'N/A')
 call act_menu(3,'Developer Version',true)
}

=head2 jdbc_ver - JDBC Version

Gets the JDBC version.

=cut

if $DB_ACCESS
{if !or($REL107,$REL110)
 {debug ' Inside ACT module, gathering JDBC version ...'
  call act_report('jdbc_ver','JDBC Version')
  if ?testFile('x',$JAVA_EXE)
  {# Check where tnsnames.ora is
   var $tns = nvl(\
     testFile('fr',catFile($TNS_ADMIN,'tnsnames.ora')),\
     testFile('fr',catFile($ORACLE_HOME,'net80','admin','tnsnames.ora')),\
     testFile('fr',catFile($ORACLE_HOME,'network','admin','tnsnames.ora')),\
     '')

   # Extract the information from tnsnames.ora
   macro get_tns_info
   {var ($tns,$beg,$key) = @arg

    var ($lin) = grepFile($tns,concat('\b',$key,'\s*='),'f',1,$beg)
    return field("\s*\\051",0,replace($lin,concat('^.*',$key,'\s*=\s*')))
   }

   var $beg = field(':',0,\
     grepFile($tns,concat('^',verbatim($APPL_DB_SID),'\b'),'fin'))
   var $HOST_MACHINE = isHost(get_tns_info($tns,$beg,'HOST'),true)
   var $HOST_PORT    = isPort(get_tns_info($tns,$beg,'PORT'),true)
   var ($HOST_SID)   = \
     match(get_tns_info($tns,$beg,'(SID|INSTANCE_NAME)'),'^(.+)$')

   # When running from patch directory, include the j*.zip in the classpath
   var @tbl = grepFile(catDir(upDir(),upDir(),upDir()),'^j.*\.zip$','i')
   if or(isWindows(),isCygwin())
    var $cls = join(';',@tbl,@{ENV.CLASSPATH})
   else
    var $cls = join(':',@tbl,@{ENV.CLASSPATH})

   # Perform the JDBC test
   suspend report
   var $tmp = getTemp('OUT','.txt')
   var $err = getTemp('ERR','.log')
   if or(isWindows(),isCygwin())
   {var $cmd = createTemp('CMD','.bat')
    call writeTemp('CMD','@echo off')
    call writeTemp('CMD','cd ',dirname($tmp))
    call writeTemp('CMD','set CLASSPATH=',$cls)
    call writeTemp('CMD',$JAVA_CMD,' oracle.apps.izu.fnd.diag.JDBCVersion ',\
                   $LOGIN_ID,' ',$HOST_MACHINE,':',$HOST_PORT,':',$HOST_SID,\
                   ' ',basename($tmp),' >',basename($err),' 2>&1')
    call closeTemp('CMD')
    output | $cmd
    call derivePassword('Oracle',$APPL_DB_SID,$LOGIN_ID,$LOGIN_ID)
    call writePassword("%s\012",'Oracle',$APPL_DB_SID,$LOGIN_ID,\
      concat('Enter ',$LOGIN_ID,' user password:'),'')
    close
    call unlinkTemp('CMD')
   }
   else
   {set $sql
    {SELECT 'count=' || COUNT(*)
    " FROM fnd_nodes
    " WHERE support_db = 'Y';
    }
    var $cnt = value(grepSql($sql,'^count\=','f'))
    if expr('>',$cnt,1)
     var ($ins) = match(get_tns_info($tns,$beg,'INSTANCE_NAME'),'^(.+)$')
    output | concat($JAVA_CMD,' -classpath ',quote($cls),\
                ' oracle.apps.izu.fnd.diag.JDBCVersion ',quote($LOGIN_ID),\
                ' ',$HOST_MACHINE,':',$HOST_PORT,':',\
                nvl($ins,$HOST_SID),' ',$tmp,' 1>',$err,' 2>&1')
    call derivePassword('Oracle',$APPL_DB_SID,$LOGIN_ID,$LOGIN_ID)
    call writePassword("%s\012",'Oracle',$APPL_DB_SID,$LOGIN_ID,\
      concat('Enter ',$LOGIN_ID,' user password:'),'')
    close
   }
   resume report
   if ?testFile('r',$tmp)
   {call writeFile($tmp)
    call unlinkTemp('OUT')
   }
   else
   {write 'Unable to read the output file from the JDBC version validation%BR%'
    call writeFile($err)
   }
   call unlinkTemp('ERR')
  }
  else
   write 'No java executable available for determining the JDBC version%BR%'
  call act_menu(3,'JDBC Version',true)
 }
}

=head2 jdk_ver - JDK Version

Gets the Java Development Kit version.

=cut

debug ' Inside ACT module, gathering JDK version ...'
call act_report('jdk_ver')
prefix
{write '---+ JDK Version'
 write '---## Using: ',encode(concat($JAVA_EXE,' -version 2>&1'))
}
call writeCommand(concat($JAVA_CMD,' -version 2>&1'))
if hasOutput(true)
 call act_menu(3,'JDK Version',true)

=head2 ssfw_ver - Self-Service Framework Version

Gets the Self-Service Framework version.

=cut

if or($TIER_WEB,not($MULTI_NODE))
{var $fil = catFile($FND_TOP,'html','OA.jsp')
 if ?testFile('e',$fil)
 {debug ' Inside ACT module, gathering self-service Framework version ...'
  call act_report('ssfw_ver','Self-Service Framework Version')
  var $dsp = act_file('$FND_TOP','html','OA.jsp')
  var $ref = get_file_version($fil)
  var $msg = ''
  if compare('eq',$ref,'N/A')
   var $msg = concat('File ',$fil,' could not be read')
  elsif !$ref
   var $msg = concat('Unable to retrieve version of ',$fil)
  else
  {var $ver = get_ssfw_version($PATCH_LIST,$ref,$DB_ACCESS)
   if !$ver
    var $msg = concat('SSFW is not installed - the version of ',$dsp,\
                      ' is too old')
  }

  if $msg
   var $ver = 'Unknown'
  if !or($REL120,$REL121)
   write '   * SSFW version = ',$ver,' (based on ',$dsp,' version)'
  if and($ref,compare('ne',$ref,'N/A'))
   write '   * ',$dsp,' version = ',cond($FILTERED,fmt_version($ref),$ref)
  else
   write '   * ',$dsp,' version = Unknown (',$msg,')'

  var $fil = catFile($OA_HTML,'OA.jsp')
  var $dsp = act_file('$OA_HTML','OA.jsp')
  var $ver = get_file_version($fil)
  if compare('eq',$ver,'N/A')
   write '   * ',$dsp,' version = Unknown (File ',encode($fil),\
         ' could not be read)'
  elsif $ver
   write '   * ',$dsp,' version = ',cond($FILTERED,fmt_version($ver),$ver)
  else
   write '   * ',$dsp,' version = Unknown (Unable to retrieve version of ',\
         encode($fil),')'
  call act_menu(3,'Self-Service Framework Version',true)
 }
}

=head2 od_ver - Oracle Diagnostics Version

Gets the Oracle Diagnostics version.

=cut

if or($TIER_WEB,not($MULTI_NODE))
{debug ' Inside ACT module, gathering Oracle Diagnostics version ...'
 call act_report('od_ver')
 prefix
  write '---+ Oracle Diagnostics Version'
 var $ref = get_file_version(catFile($OA_HTML,'jtfqasr.jsp'))
 if and($ref,compare('ne',$ref,'N/A'))
  write '   * jtfqasr.jsp version = ',cond($FILTERED,fmt_version($ref),$ref)
 if and($ref,$DB_ACCESS)
 {var $nam = dsp_patches($PATCH_LIST,'patch','Oracle Diagnostics',\
                         'DIAGNOSTICS_PATCH_LIST')
  var ($ver) = match($nam,'Diagnostics\s+(\d+\.\d+)')

  if expr('<=',$ver,2.2)
  {# Get the location of the jserv.properties from apache configuration.
   # Take the first occurence since this is supposed to be the nonrestricted
   # version.
   if ?testDir('d',$IAS_HOME)
   {var $cnf = catFile($IAS_HOME,'Apache','Jserv','etc','jserv.conf')
    var ($lin) = grepFile($cnf,'^[^#]*ApJServProperties','f')
    var $prp = field('\s+',0,replace($lin,'^.*ApJServProperties\s+'))

    # First check version as defined in support_addon.zip
    if ?testFile('f',$prp)
    {var $pck = undef
     loop $lin (grepFile($prp,'^\s*wrapper\.classpath'))
     {if match($lin,'support_addon\.zip')
      {var $pck = value($lin)
       break
      }
     }
     if $pck
     {if ?findCommand('unzip')
      {call loadCommand(concat(last,' -z ',$pck))
       write '   * File = ',encode($pck)
       write '   * Version = ',getLines(-1)
      }
      else
       write 'The command file unzip cannot be executed, therefore cannot \
              determine the version of "support_addon.zip"%BR%'
     }
     else
      write 'No "support_addon.zip" found in jserv.properties%BR%'
    }
    else
     write 'Not able to find the jserv.properties file to check the support \
            pack%BR%'
   }
   else
    write 'Not able to find the iAS home directory to check the support \
           pack%BR%'

   # Now try the oracle/support/apps/diag/base/SupportPack.class or
   # oracle/apps/diag/base/SupportPack.class
   if ?testFile('r',catFile($OA_JAVA,'oracle','apps','izu','base',\
                           'SupportPack.class'))
   {write '   * File = ',encode(lastFile())
    write '   * Version = ',get_file_version(lastFile())
   }
   if ?testFile('r',catFile($OA_JAVA,'oracle','support','apps','diag','base',\
                           'SupportPack.class'))
   {write '   * File = ',encode(lastFile())
    write '   * Version = ',get_file_version(lastFile())
   }
  }
  else
   call dsp_patches($PATCH_LIST,'','Oracle E-Business Suite Diagnostics',\
                    'SUPPORT_PACK_LIST')
 }
 if hasOutput(true)
  call act_menu(3,'Oracle Diagnostics Version',true)
}

=head2 http_server - HTTP Server Information

Gets the HTTP server version.

=cut

if or($TIER_WEB,not($MULTI_NODE))
{debug ' Inside ACT module, gathering HTTP Server information ...'
 call act_report('http_server')
 prefix
  write '---+ HTTP Server Information'
 if !$IAS_HOME
  var $cmd = undef
 elsif or(isWindows(),isCygwin())
  var $cmd = catFile($IAS_HOME,'Apache','Apache','Apache.exe')
 elsif isAbsolute($HTTP_FILE)
  var $cmd = $HTTP_FILE
 else
  var $cmd = catFile($IAS_HOME,'Apache','Apache','bin',$HTTP_FILE)
 if ?testFile('r',$cmd)
 {var @inf = command(concat(quote($cmd),' -v 2>&1'))
  if @inf
  {if or(isWindows(),isCygwin())
    var ($ver) = match($inf[0],'Apache/(\S+)\s*',true)
   else
    var ($ver) = match(field('/',1,$inf[0]),'(\S+)\s+\(Unix\)')
   if $ver
    write '   * Apache version found = ',$ver
   write '   * ',join('%BR%',@inf)
  }
 }
 elsif ?testFile('r',catFile(${ENV.APACHE_TOP:''},'bin','httpd'))
 {var @inf = command(concat(lastCommand(),' -v 2>&1'))
  var $ver = replace(field('/',1,$inf[0]),'\s+\(Unix\)')
  write '   * Apache version found = ',$ver
  write '   * ',join('%BR%',@inf)
 }
 if hasOutput(true)
  call act_menu(3,'HTTP Server Information',true)
}

=head2 patches - Patches Information

Regroups patch information.

=head3 Applications Technology Patches

Lists Applications technology patchset versions.

=cut

if $DB_ACCESS
{if !or($REL107,$REL110)
 {debug ' Inside ACT module, gathering Applications technology patches ...'
  call act_report('patches')
  call act_toc('Patches Information')
  write '---+ Applications Technology Patches'
  call dsp_patches($PATCH_LIST,'patchset','AD','AD_PATCH_LIST')
  if !or($REL120,$REL121)
   call dsp_patches($PATCH_LIST,'patchset','Rapid Install','ADX_PATCH_LIST')
  call dsp_patches($PATCH_LIST,'patch','Autoconfig Templates','TXK_RUP_LIST')
  call dsp_patches($PATCH_LIST,'patchset','FND','FND_PATCH_LIST')
  if !or($REL120,$REL121)
  {call dsp_patches($PATCH_LIST,'patchset','FND Data Security',\
                    'FND_SECURITY_PATCH_LIST')
   call dsp_patches($PATCH_LIST,'patchset','APPCORE','APPCORE_PATCH_LIST')
  }
  call dsp_patches($PATCH_LIST,'patch','WF','OWF_PATCH_LIST')
  if !or($REL120,$REL121)
   call dsp_patches($PATCH_LIST,'patch','AOL/J','AOLJ_PATCH_LIST')
  call dsp_patches($PATCH_LIST,'patch','Framework','FRAMEWORK_PATCH_LIST')
  write $TOP
 }

=head3 Patches of not Registered Products

Lists patchset versions of some products that are not registered.

=cut

 if !or($REL107,$REL110)
 {debug ' Inside ACT module, gathering patches of not registered products ...'
  write '---+ Patches of not Registered Products'
  call dsp_patches($PATCH_LIST,'patchset','DBI','DBI_PATCH_LIST')
  call dsp_patches($PATCH_LIST,'patchset','HZ','HZ_PATCH_LIST')
  call dsp_patches($PATCH_LIST,'patchset','Internet Expenses','OIE_PATCH_LIST')
  call dsp_patches($PATCH_LIST,'patchset','Oracle Credit Management',\
                   'OCM_PATCH_LIST')
  call dsp_patches($PATCH_LIST,'patchset','Oracle Customers On-line',\
                   'IMC_PATCH_LIST')
  call dsp_patches($PATCH_LIST,'patchset','Procurement','PRC_PATCH_LIST')
  call dsp_patches($PATCH_LIST,'patchset','iReceivables','OIR_PATCH_LIST')
  write $TOP
 }

=head3 Last Month Applied Patches

Displays the patch runs with driver information (that is, C, D, or G), applied
during the last month.

=cut

 if !or($REL107,$REL110)
 {debug ' Inside ACT module, gathering last month applied patches ...'
  write '---+ Last Month Applied Patches'
  if chk_apps_object($APPLSYS,'AD_BUGS')
  {if chk_apps_object($APPLSYS,'AD_COMPRISING_PATCHES')
   {set $sql
    {SELECT '|' ||
    "       TO_CHAR(TRUNC(iv.update_date),'DD-Mon-YYYY') || '|' ||
    "       iv.patch_name || '|' ||
    "       iv.driver_type || '|' ||
    "       iv.patch_top || '|' ||
    "       iv.used_options || ' |'
    " FROM (SELECT SUBSTR(ap.patch_name,1,10) patch_name,
    "              pr.patch_top patch_top,
    "              TRUNC(ap.last_update_date) update_date,
    "              DECODE(dr.driver_type_c_flag,'Y','C','')
    "               || DECODE(dr.driver_type_d_flag,'Y',' D','')
    "               || DECODE(dr.driver_type_g_flag,'Y',' G','') driver_type,
    "              pr.patch_action_options used_options
    "        FROM ad_patch_runs pr,
    "             ad_patch_drivers dr,
    "             ad_applied_patches ap
    "        WHERE pr.start_date > add_months(SYSDATE,-1)
    "          AND dr.patch_driver_id = pr.patch_driver_id
    "          AND ap.applied_patch_id = dr.applied_patch_id
    "          AND NOT EXISTS
    "                (SELECT 'x'
    "                  FROM ad_comprising_patches cp
    "                  WHERE cp.patch_driver_id = dr.patch_driver_id)
    "       UNION ALL
    "       SELECT SUBSTR(b.bug_number,1,10) patch_name,
    "              pr.patch_top patch_to,
    "              TRUNC(b.last_update_date) update_date,
    "              DECODE(dr.driver_type_c_flag,'Y','C','')
    "               || DECODE(dr.driver_type_d_flag,'Y',' D','')
    "               || DECODE(dr.driver_type_g_flag,'Y',' G','') driver_type,
    "              pr.patch_action_options used_options
    "        FROM ad_patch_runs pr,
    "             ad_patch_drivers dr,
    "             ad_comprising_patches cp,
    "             ad_bugs b
    "        WHERE pr.start_date > add_months(SYSDATE,-1)
    "          AND dr.patch_driver_id = pr.patch_driver_id
    "          AND cp.patch_driver_id = pr.patch_driver_id
    "          AND cp.bug_id = b.bug_id
    "      ) iv;
    }
   }
   else
   {set $sql
    {SELECT '|' ||
    "       TO_CHAR(TRUNC(ap.last_update_date),'DD-Mon-YYYY') || '|' ||
    "       SUBSTR(ap.patch_name,1,10) || '|' ||
    "       DECODE(dr.driver_type_c_flag,'Y','C','')
    "        || DECODE(dr.driver_type_d_flag,'Y',' D','')
    "        || DECODE(dr.driver_type_g_flag,'Y',' G','') || '|' ||
    "       pr.patch_top || '|' ||
    "       pr.patch_action_options || '|'
    " FROM ad_patch_runs pr,
    "      ad_patch_drivers dr,
    "      ad_applied_patches ap
    " WHERE pr.start_date > add_months(SYSDATE,-1)
    "   AND dr.patch_driver_id = pr.patch_driver_id
    "   AND ap.applied_patch_id = dr.applied_patch_id;
    }
   }
   prefix
    write '|*Update Date*|*Patch Name*|*Driver Type*|*Patch Top*|\
            *Used Options*|'
   call writeSql($sql)
   if !hasOutput(true)
    write 'No patches found%BR%'
  }
  else
   write 'No available information (i.e. AD_BUGS table is missing)%BR%'
  write $TOP
  call act_menu(3,'Patches Information')
 }

=for stopwords RUPs

=head2 rup - Release Update Packs

Lists all Oracle E-Business Suite Release Update Packs (RUPs).

=cut

 debug ' Inside ACT module, gathering Release Update Packs ...'
 call act_report('rup')
 prefix
  write '---+ E-Business Suite Release Update Packs'
 loop $itm (xmlFind($PATCH_LIST,'.../pack id="^EBS_RUP_PATCH_LIST$"/patchset'))
 {var $num = xmlData(xmlFind($itm,'number'))
  if $PATCH_LIST{$num}
  {var $nam = xmlData(xmlFind($itm,'name'))
   write '   * Patchset ',$nam,' (',$num,') is installed'
  }
 }
 if hasOutput(true)
 {write $TOP
  call act_menu(3,'Release Update Packs')
 }

=head2 nodes - Nodes Information

Displays information about the different middle-tier nodes of the Applications
installation.

=cut

 if !or($REL107,$REL110)
 {debug ' Inside ACT module, gathering nodes information ...'
  call act_report('nodes')
  set $sql
  {select :1
  " FROM fnd_nodes;
  }
  var @col = ('node_name','server_address','node_mode','status',\
              'support_admin','support_cp','support_forms','support_web')
  call setSqlHeader('ACT','support_admin','*Admin Running*',\
                          'support_cp',   '*Concurrent Processing Running*',\
                          'support_forms','*Forms Server Running*',\
                          'support_web',  '*Web Server Running*')
  call setSqlColumns('ACT','support_admin',"NVL(support_admin,'N')",\
                           'support_cp',   "NVL(support_cp,'N')",\
                           'support_forms',"NVL(support_forms,'N')",\
                           'support_web',  "NVL(support_web,'N')")
  var ($hdr,$col) = getSqlColumns('ACT',$APPLSYS,'FND_NODES',@col)
  call clearSqlColumns('ACT')
  if $hdr
  {prefix
   {write '---+ Nodes Information'
    write $hdr
   }
   call writeSql(bindSql($sql,$col))
   if hasOutput(true)
    call act_menu(3,'Nodes Information',true)
  }
 }

=head2 appl_top - Shared APPL_TOP Information

Reports how C<APPL_TOP> are shared between the different Applications tier
nodes.

=cut

 if !or($REL107,$REL110)
 {debug ' Inside ACT module, gathering shared APPL_TOP information ...'
  call act_report('appl_top','Shared APPL_TOP Information')
  if and(chk_apps_object($APPLSYS,'FND_APPL_TOPS'),\
         chk_apps_column($APPLSYS,'FND_NODES','NODE_ID'))
  {set $sql
   {SELECT '|' ||
   "       n.node_name || '|' ||
   "       a.name || '|' ||
   "       a.path || '|' ||
   "       TO_CHAR(a.last_update_date,'DD-Mon-YYYY HH24:MI:SS') || '|' ||
   "       a.shared || '|' ||
   "       a.file_system_guid || '|'
   " FROM fnd_appl_tops a,fnd_nodes n
   " WHERE a.node_id = n.node_id;
   }
   prefix
    write '|*Node Name*|*Top Name*|*Path*|*Last Update Date*|*Shared*|\
            *File System ID*|'
   call writeSql($sql)
   if !hasOutput(true)
    write 'No available information (i.e. No rows found in FND_APPL_TOPS)%BR%'
  }
  else
   write 'No available information (i.e. FND_APPL_TOPS table is missing or \
          the column NODE_ID is missing in table FND_NODES)%BR%'
  call act_menu(3,'Shared APPL_TOP Information',true)
 }

=head2 autoconfig - AutoConfig Information

Displays the location of the AutoConfig files for the Applications tier nodes.

=cut

 if !or($REL107,$REL110)
 {debug ' Inside ACT module, gathering Autoconfig information ...'
  call act_report('autoconfig','Autoconfig Information')
  if chk_apps_object($APPLSYS,'FND_OAM_CONTEXT_FILES')
  {set $sql
   {SELECT '|' ||
   "       name || '|' ||
   "       node_name || ' |' ||
   "       REPLACE(version,'.','&#46;') || ' |' ||
   "       path || ' |' ||
   "       TO_CHAR(last_synchronized,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
   "       status || ' |'
   " FROM fnd_oam_context_files
   " WHERE status <> 'H' OR status IS NULL
   " ORDER BY name;
   }
   prefix
    write '|*Context Name*|*Node Name*|*Version*|*Path*|*Last Synchronized*|\
            *Status*|'
   call writeSql($sql)
   if !hasOutput(true)
    write 'No available information (i.e. No rows found in \
           FND_OAM_CONTEXT_FILES)%BR%'
  }
  else
   write 'No available information (i.e. FND_OAM_CONTEXT_FILES table is \
          missing)%BR%'
  call act_menu(3,'Autoconfig Information',true)
 }
}

=head2 env - Important Environment Settings

Lists important Applications environment variable settings.

=cut

debug ' Inside ACT module, gathering important environment settings ...'
call act_report('env')

# Write the environment variables
macro get_env
{var ($key) = @arg

 var $val = getEnv($key)
 if defined($val)
  write '|',$key,'|',$val,' |'
}

prefix
{write '---+ Important Environment Settings'
 write '|*Variable*|*Value*|'
}
call get_env('APPL_TOP')
call get_env('ORACLE_HOME')
call get_env('PATH')
loop $key (@{CUR.W_SHLIB})
 call get_env($key)
call get_env('APPLFENV')
call get_env('APPLTMP')
call get_env('NLS_DATE_FORMAT')
call get_env('NLS_DATE_LANGUAGE')
call get_env('NLS_LANG')
call get_env('NLS_NUMERIC_CHARACTERS')
call get_env('NLS_SORT')
call get_env('TNS_ADMIN')
if or(isWindows(),isCygwin())
 call get_env('LOCAL')
elsif isUnix()
 call get_env('TWO_TASK')
call get_env('APPLPTMP')
call get_env('CLASSPATH')
call get_env('JAVA_TOP')
call get_env('OA_HTML')
call get_env('OA_JAVA')
call get_env('APACHE_TOP')
call get_env('FORMS45_APPSLIBS')
call get_env('FORMS45_PATH')
call get_env('ORAWEB_ADMIN')
call get_env('ORAWEB_HOME')
call get_env('REPORTS25_PATH')
call get_env('REPORTS25_TMP')
call get_env('COMMON_TOP')
call get_env('IAS_ORACLE_HOME')
call get_env('OA_JRE_TOP')
call get_env('ADJREOPTS')
call get_env('ADJVAPRG')
call get_env('AF_JRE_TOP')
call get_env('AFJVAPRG')
call get_env('AF_CLASSPATH')
call get_env('AF_LD_LIBRARY_PATH')
call get_env('CONTEXT_FILE')
call get_env('CONTEXT_NAME')
call get_env('FND_SECURE')
call get_env('FORMS60_APPSLIBS')
call get_env('FORMS60_PATH')
call get_env('FORMS60_WEB_CONFIG_FILE')
call get_env('ADPERLPRG')
call get_env('PERL5LIB')
call get_env('REPORTS60_PATH')
call get_env('REPORTS60_TMP')
if hasOutput(true)
{write $TOP
 call act_menu(3,'Environment Settings')
}

=head1 SEE ALSO

L<APPS:APPSinfo|collect::APPS:APPSinfo>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
