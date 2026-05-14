# DCsebl.ctl:530:Collects Siebel Information
# $Id: DCsebl.ctl,v 1.14 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/DCsebl.ctl,v 1.13 2015/08/21 15:33:37 RDA Exp $
#
# Change History
# 20190123  DXM  Enhance web server collection.
# 20150821  MSC  Improve time consistency.

=head1 NAME

APPS:DCsebl - Collects Siebel Information

=head1 DESCRIPTION

This module collects Siebel information for any or all of the following:

=over 2

=item o Siebel Server

=item o Siebel Gateway

=item o Siebel Web Server

=back

The following reports can be generated and are regrouped under C<Siebel>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing APPS.SEBL module ...',tput('off')

# Initialization
var $ADMIN   = ${T_GATE_USER:'sadmin'}
var $APPL    = ${B_APPL}
var $APPLTOP = ${D_APPL_TOP:''}
var $ENT     = ${T_APPL_ENTERPRISE}
var $GATE    = ${B_GATE}
var $GATETOP = ${D_GATE_TOP:''}
var $NODE    = ${T_GATE_NODE:${RDA.T_NODE}}
var $PORT    = ${N_GATE_PORT:2320}
var $SVR     = ${T_APPL_SERVER}
var $TAIL    = ${DFT.N_TAIL:1000}
var $WEB     = ${B_WEB}
var $WEBTOP  = ${D_WEB_TOP:''}
var $OWNER   = uc(${T_OWNER})

var $MOD = cond(isUnix(),'fx','fr')
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Siebel'

# Define the duplicate file hash
var %DUP

# Load the common macros
run RDA:library()

# Set the required environment
var $bkp = setContext({PERL5LIB => ${ENV.PERL5LIB},\
                       PERL5OPT => ${ENV.PERL5OPT}})

# Macro to encode the version from a file
macro fmt_version
{var ($flg,@fil) = @arg
 import $TOP,%DUP
 keep $TOP,%DUP

 loop $fil (@fil)
 {if ?testFile('frT',$fil)
  {output F,concat('log_',$nam = basename($fil))
   prefix
   {write '---+ Display of ',encode($nam),' File'
    write '---## Information Taken from ',encode($fil)
    call statFile('b',$fil)
    write '<pre>'
   }
   call loadFile($fil)
   if $flg
   {loop $lin (getLines(0,1))
     write replace($lin,'\.','&#46;',true)
    loop $lin (getLines(2))
     write $lin
   }
   else
   {loop $lin (getLines())
     write replace($lin,'\.','&#46;',true)
   }
   if hasOutput(true)
   {write '</pre>'
    write $TOP
    var $DUP{$fil} = getFile()
   }
  }
 }
}

=head2 registry - ODBC Registry Information

For Windows, collects system ODBC Registry information.

=cut

if or(isWindows(),isCygwin())
{debug ' Inside SEBL module, gathering registry information'
 report registry
 prefix
  write '---+!! ODBC Registry information'
 call writeRegistry('HKLM\SOFTWARE\ODBC\ODBC.INI')
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][ODBC Registry Information]]'
}

=head2 dbinfo - Database Information

Collects Oracle Database information for Siebel.

=cut

if and(${I_DB/E},match($OWNER,'^[A-Z0-9][\w\$\#]{0,127}$'))
{run DB:DBinfo()

 # Set the database context
 call setSqlTarget(${I_DB})

 # Test the database connection and collect information
 debug ' Inside SEBL module, getting database information'
 report dbinfo

 if testSql()
 {echo ''
  echo tput('bold'),\
       'The schema containing Siebel repository is not accessible.',tput('off')
  if getSqlMessage()
  {echo last
   write '---+ Database Information'
   write 'Siebel repository not accessible (',getSqlMessage(),')'
   toc '2:[[',getFile(),'][rda_report][Database Information]]'
  }
  echo ''
 }
 else
 {var $TTL = '---+!! Database Information'
  var @TTL = ('',\
              '---+ Asynchronous Server Requests',\
              '---+ Workflow Policies',\
              '---+ Remote Mininum and Maximum Transaction Log',\
              '---+ Remote Count of Transaction Set',\
              '---+ Remote Count of Transaction Skipped',\
              '---+ Process History',\
              '---+ Running Processes',\
              '---+ System Errors',\
              '---+ Web Services Port Information',\
              '---+ Workflows',\
              '---+ Email Marketing Server Port Information',\
              '---+ Email Marketing Server Parameter Information')
  var @HDR = ('',\
              '|*Name*|*Status*|*Description*|*Display Name*|*Enterprise Name*|\
                *Exec Server Name*| *Count*|',\
              '| *Count*|*Name*|',\
              '| *Minimum Transaction Id*| *Maximum Transaction Id*| *Count*|',\
              '| *Count*|',\
              '| *Count*|',\
              '|*Component Name*|*Server Name*|',\
              '|*Component Name*|*Server Name*| *Count*|',\
              '|*Server Name*|*Component Name*|*Last Updated*|*Logfile Name*|',\
              '|*Port Address*|*Name*|',\
              '|*Name*|*Status*|',\
              '|*Port Address*|*Name*|',\
              '|*Type*|*Value*|')
  set $sql
  {SELECT '|' ||
  "       t3.name || ' |' ||
  "       t1.status || ' |' ||
  "       t3.desc_text || ' |' ||
  "       t3.display_name || ' |' ||
  "       t1.enterprise_name || ' |' ||
  "       t1.exec_srvr_name || ' | ' ||
  "       COUNT(t3.name) || '|'
  " FROM :1.s_srm_request t1,
  "      :1.s_srm_data t2,
  "      :1.s_srm_action t3
  " WHERE t1.row_id = t2.par_id(+)
  "   AND t1.ACTION_ID = t3.row_id(+)
  " GROUP BY t3.name,t1.status,t3.desc_text,t3.display_name,t1.enterprise_name,
  "          t1.exec_srvr_name;
  "PROMPT ___Macro_separator(2)___
  "SELECT '| ' ||
  "       COUNT(t1.req_id) || '|' ||
  "       t2.name || ' |'
  " FROM :1.s_escl_req t1, :1.s_escl_rule t2
  " WHERE t1.rule_id = t2.row_id
  " GROUP BY t2.name;
  "PROMPT ___Macro_separator(3)___
  "SELECT '| ' ||
  "       MIN(txn_id) || '| ' ||
  "       MAX(txn_id) || '| ' ||
  "       COUNT(1) || ' |'
  " FROM :1.s_dock_txn_log;
  "PROMPT ___Macro_separator(4)___
  "SELECT '| ' ||
  "       COUNT(1) || '|'
  " FROM :1.s_dock_txn_set;
  }
  if getSqlColumns('RDA',$OWNER,'S_DOCK_TXN_SKIP')
  {append $sql
   {PROMPT ___Macro_separator(5)___
   "SELECT '| ' ||
   "       COUNT(1) || '|'
   " FROM :1.s_dock_txn_skip;
   }
  }
  call clearSqlColumns('RDA')
  if getSqlColumns('RDA',$OWNER,'S_SRM_TASK_HIST')
  {append $sql
   {PROMPT ___Macro_separator(6)___
   "SELECT '|' ||
   "       srvr_comp_name || ' |' ||
   "       srvr_name || ' |'
   " FROM :1.s_srm_task_hist
   " WHERE srvr_end_ts IS NULL
   "   AND srvr_task_type='Process';
   "PROMPT ___Macro_separator(7)___
   "SELECT '|' ||
   "       srvr_comp_name || ' |' ||
   "       srvr_name || ' | ' ||
   "       COUNT(1) || '|'
   " FROM :1.s_srm_task_hist
   " WHERE srvr_task_type='Process'
   " GROUP BY srvr_comp_name, srvr_name;
   "PROMPT ___Macro_separator(8)___
   "SELECT '|' ||
   "       srvr_name || ' |' ||
   "       srvr_comp_name || ' |' ||
   "       last_upd || ' |' ||
   "       srvr_logfile_name || ' |'
   " FROM :1.s_srm_task_hist
   " WHERE srvr_task_type='Normal Task'
   "   AND srvr_status = 'ERROR';
   }
  }
  call clearSqlColumns('RDA')
  append $sql
  {PROMPT ___Macro_separator(9)___
  "SELECT '|' ||
  "       t1.port_address || ' |' ||
  "       t1.name || ' |'
  " FROM :1.s_ws_port t1
  " WHERE t1.web_service_id IN (SELECT row_id
  "                              FROM :1.s_ws_webservice
  "                              WHERE name IN ('WebCatalogService',
  "                                             'SAWSessionService',
  "                                             'JobManagementService',
  "                                             'SendMailingService'));
  "PROMPT ___Macro_separator(10)___
  "SELECT '|' ||
  "       t1.name || ' |' ||
  "       t1.deploy_status_cd || ' |'
  " FROM :1.s_wfa_dploy_def t1
  "  LEFT OUTER JOIN :1.s_lst_of_val t2 ON t1.deploy_status_cd = t2.name
  "  AND t2.type = 'WFA_DPLY_STAT_CD'
  "  AND t2.lang_id = 'ENU'
  " WHERE t1.type_cd = 'PROCESS'
  "   AND (t1.deploy_status_cd = 'ACTIVE'
  "   AND t1.processing_grp_cd = 'Marketing');
  "PROMPT ___Macro_separator(11)___
  "SELECT '|' ||
  "       t1.port_address || ' |' ||
  "       t1.name || ' |'
  " FROM :1.s_ws_port t1
  " WHERE t1.web_service_id IN (SELECT row_id
  "                              FROM :1.s_ws_webservice
  "                              WHERE name = 'SendMailingService');
  "PROMPT ___Macro_separator(12)___
  "SELECT '|' ||
  "       t1.type_cd || ' |' ||
  "       t1.type_val || ' |'
  " FROM :1.s_db_cnctr_svc t1
  "  INNER JOIN :1.s_dd_db_cnctr t2 ON t1.db_cnctr_id = t2.row_id
  "  LEFT OUTER JOIN :1.s_ws_port t3 ON t1.ws_port_id = t3.row_id
  " WHERE t1.db_cnctr_id IN (SELECT row_id
  "                           FROM :1.s_dd_db_cnctr
  "                           WHERE name = 'Email Marketing Server');
  "PROMPT ___Capture_Only_Url___
  "SELECT 'address=' || t1.port_address
  " FROM :1.s_ws_port t1
  " WHERE t1.name = 'JobManagementServiceSoap';
  }
  call separator(1)
  call writeSql(bindSql($sql,$OWNER))
  call separator(0,'Database Information')
  var $url = value(grepSqlBuffer('Url','^address=','f'))
 }
}

=head1 SIEBEL SERVER

Collects Siebel Server files like following:

=over 32

=item F<upgrade.txt>

Upgrade history

=item F<siebsrvr/base.txt>

Base FP information, which includes the build number

=item F<siebsrvr/enu.txt>

Language-specific build information

=item F<siebsrvr/siebenv.sh>

Environment definitions for Bourne or Korn shell

=item F<siebsrvr/siebenv.csh>

Environment definitions for C shell

=item F<siebsrvr/admin/lbconfig.txt>

Server load balancer information

=item F<siebsrvr/admin/srvrdefs.dat>

Server default definitions

=item F<siebsrvr/admin/srvrdefs_sia.dat>

SIA server default definitions

=item F<siebsrvr/bin/siebmtshw>

Collected on AIX only.

=item F<siebsrvr/sys/.odbc.ini>

=back

Collects the Enterprise log file.

=cut

if and($APPL,$APPLTOP)
{debug ' Inside SEBL Module, collecting the Siebel Server files'
 pretoc '2:Siebel Server'
 var ($dir,@tbl) = (cond(\
   isWindows(),catDir($APPLTOP,'siebsrvr','log'),\
   isCygwin(), catDir($APPLTOP,'siebsrvr','log'),\
               catDir($APPLTOP,'siebsrvr','enterprises',$ENT,$SVR,'log')))
 if ${OS.aix}
  call push(@tbl,catFile($APPLTOP,'siebsrvr','bin','siebmtshw'))
 call fmt_version(false,catFile($APPLTOP,'upgrade.txt'),\
                        catFile($APPLTOP,'siebsrvr','base.txt'),\
                        catFile($APPLTOP,'siebsrvr','enu.txt'))
 call sort_files(3,$TAIL,\
   catFile($APPLTOP,'upgrade.txt'),\
   catFile($APPLTOP,'siebsrvr','base.txt'),\
   catFile($APPLTOP,'siebsrvr','enu.txt'),\
   catFile($APPLTOP,'siebsrvr','siebenv.sh'),\
   catFile($APPLTOP,'siebsrvr','siebenv.csh'),\
   catFile($APPLTOP,'siebsrvr','admin','lbconfig.txt'),\
   catFile($APPLTOP,'siebsrvr','admin','srvrdefs.dat'),\
   catFile($APPLTOP,'siebsrvr','admin','srvrdefs_sia.dat'),\
   catFile($APPLTOP,'siebsrvr','sys','.odbc.ini'),\
   catFile($dir,concat($ENT,'.',$SVR,'.log')),\
   @tbl)

=head2 crash - Crash Files

Collects C<crash*.txt> files found in the F<siebsrvr/bin> directory.

=cut

 debug ' Inside SEBL Module, collecting the crash files'
 report crash
 prefix
 {write '---+!! Crash Files Found'
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              risks. To prevent them, access the file outside the browser or \
              use the link to save them and use an adequate viewer.'
  write '|*File Name*| *Size*|*Last Modified Date*|'
 }
 loop $fil (grepDir(catDir($APPLTOP,'siebsrvr','bin'),'^crash.*\.txt$','inp'))
 {var $siz = getSize($fil)
  var $lnk = encode($fil)
  if $siz
  {output => d,basename($fil)
   if ${CUR.O_LAST}->write_tail($fil,$TAIL)
    var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,']]')
   end ${CUR.O_LAST}
  }
  write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
 }
 if isCreated(true)
  toc '3:[[',getFile(),'][rda_report][Crash Files]]'

=head2 fdr - .fdr Files

Lists C<.fdr> files found in the F<siebsrvr/bin> directory.

=cut

 debug ' Inside SEBL Module, listing the .fdr files'
 report fdr
 prefix
  write '---+ .fdr Files Found'
 call statFile('p',grepDir(catDir($APPLTOP,'siebsrvr','bin'),'\.fdr$','inp'))
 if isCreated(true)
  toc '3:[[',getFile(),'][rda_report][.fdr Files]]'

=head2 callstack - Call Stack Files

Lists C<callstack*.*> files found in the F<siebsrvr/bin> directory.

=cut

 debug ' Inside SEBL Module, listing the call stack files'
 report callstack
 prefix
  write '---+ Call Stack Files Found'
 call statFile('p',\
   grepDir(catDir($APPLTOP,'siebsrvr','bin'),'^callstack','inp'))
 if isCreated(true)
  toc '3:[[',getFile(),'][rda_report][Call Stack Files]]'

=head2 log - Application Logs

Lists C<.log> files found in the F<siebsrvr/log> directory (on Windows) and
F<siebsrvr/enterprises/E<lt>enterpriseE<gt>/E<lt>serverE<gt>/log> directory
(on UNIX).

=cut

 debug ' Inside SEBL Module, listing the .log files'
 report log
 prefix
  write '---+ .log Files Found'
 call statFile('p',grepDir($dir,'\.log$','inp'))
 if isCreated(true)
  toc '3:[[',getFile(),'][rda_report][Application Logs]]'

=head2 dmp - XML Logs

Lists C<.dmp> files found in the F<siebsrvr/log> directory (on Windows) and
F<siebsrvr/enterprises/E<lt>enterpriseE<gt>/E<lt>serverE<gt>/log> directory
(on UNIX).

=cut

 debug ' Inside SEBL Module, listing the .dmp files'
 report dmp
 prefix
  write '---+ .dmp Files Found'
 call statFile('p',grepDir($dir,'\.dmp$','inp'))
 if isCreated(true)
  toc '3:[[',getFile(),'][rda_report][XML Logs]]'

=head2 evt_result - EVT Result

Collects the results generated using Environment Verification Tool.

=cut

 debug ' Inside SEBL Module, getting EVT result'
 if ?testFile($MOD,catFile($APPLTOP,'siebsrvr','bin',${AS.EXE:'evt'}))
 {var $pgm = concat(lastTestCommand(),' -r ',quote($APPLTOP),\
    ' -e ',quote($ENT),' -s ',quote($SVR),' -d SHOWERRORS -o TEXT -f ',\
    catCommand($APPLTOP,'siebsrvr','bin','evt.ini'))
  if isUnix()
   var $env = sourceContext(catFile($APPLTOP,'siebsrvr','siebenv.sh'))
  var $out = newTemp('EVT')
  call command(concat($pgm,' >',$out))
  report evt_result
  prefix
  {write '---+ Environment Verification Tool Result'
   write '---## Using: ',encode($pgm)
  }
  call writeFile($out)
  if hasOutput(true)
  {write $TOP
   toc '3:[[',getFile(),'][rda_report][EVT Result]]'
  }
  if isUnix()
   call restoreContext($env)
  call unlinkTemp('EVT')
 }
}

=head2 obisrvr_status - OBI Server Availability

Checks for the availability of OBI Server.

=cut

if $APPL
{if length($url)
 {debug ' Inside SEBL Module, checking OBI server availability'
  report obisrvr_status
  title '---+!! OBI Server Availability'
  title $TOC

  # Run ping test
  run &{check(getOsName(),'aix',            'OS:OSaix',\
                          'darwin',         'OS:OSdarwin',\
                          'dec_osf',        'OS:OSosf',\
                          'dynixptx',       'OS:OSptx',\
                          'hpux',           'OS:OShpux',\
                          'linux',          'OS:OSlinux',\
                          'solaris',        'OS:OSsunos',\
                          cond(isCygwin(),  'OS:OSwin32',\
                               isUnix(),    'OS:OSunix',\
                               isVms(),     'OS:OSvms',\
                               isWindows(), 'OS:OSwin32'))}('SEBL')
  var $hst = ''
  if match($url,'^http:\/\/(.*?)\/')
   var ($hst) = last
  var $cmd = ping_command($hst)
  prefix
  {write '---+ Ping ',$hst
   write '---## Using: ',encode($cmd)
  }
  call writeCommand($cmd)
  if hasOutput(true)
   write $TOP

  # HTTP request
  var $req = createRequest('GET',$url)
  var $rsp = submitRequest($req)
  prefix
  {write '---+ HTTP Request'
   write '---## Using: ',encode($url)
  }
  if isSuccess($rsp)
   write 'OBISRVR is alive%BR%'
  else
   write 'Unable to reach OBISRVR (',join(',',getRspCode($rsp)),\
         ' - ',getRspMessage($rsp),')%BR%'
  if hasOutput(true)
   write $TOP
  if isCreated(true)
   toc '3:[[',getFile(),'][rda_report][OBI Server Availability]]'
 }
 unpretoc
}

=head1 SIEBEL GATEWAY

Collects important Siebel Gateway files like following:

=over 32

=item F<upgrade.txt>

Upgrade history

=item F<gtwysrvr/base.txt>

Base FP information, which includes the build number

=item F<gtwysrvr/enu.txt>

Language-specific build information

=item F<gtwysrvr/admin/gtwydefs.dat>

Gateway default definitions

=item F<gtwysrvr/admin/siebns.dat>

Server and application definitions on Windows

=item F<gtwysrvr/admin/srvrdefs.dat>

Server default definitions

=item F<gtwysrvr/admin/srvrdefs_sia.dat>

SIA server default definitions

=item F<gtwysrvr/bin/gateway.cfg>

Gateway configuration file

=item F<gtwysrvr/log/NameSrvr.log>

Current gateway server log file

=item F<gtwysrvr/sys/siebns.dat>

Server and application definitions on UNIX

=back

=cut

if and($GATE,$GATETOP)
{debug ' Inside SEBL Module, collecting Siebel Gateway files'
 pretoc '2:Siebel Gateway'
 call fmt_version(false,catFile($GATETOP,'upgrade.txt'),\
                        catFile($GATETOP,'gtwysrvr','base.txt'),\
                        catFile($GATETOP,'gtwysrvr','enu.txt'))
 var $fil = cond(isUnix(),catFile($GATETOP,'gtwysrvr','sys','siebns.dat'),\
                          catFile($GATETOP,'gtwysrvr','admin','siebns.dat'))
 call fmt_version(true,$fil)
 call sort_files(3,$TAIL,\
   catFile($GATETOP,'upgrade.txt'),\
   catFile($GATETOP,'gtwysrvr','base.txt'),\
   catFile($GATETOP,'gtwysrvr','enu.txt'),\
   catFile($GATETOP,'gtwysrvr','admin','gtwydefs.dat'),\
   catFile($GATETOP,'gtwysrvr','admin','srvrdefs.dat'),\
   catFile($GATETOP,'gtwysrvr','admin','srvrdefs_sia.dat'),\
   catFile($GATETOP,'gtwysrvr','bin','gateway.cfg'),\
   catFile($GATETOP,'gtwysrvr','log','NameSrvr.log'),\
   $fil)

=head2 param_info - Parameter Information

Collects C<Marketing File System>, C<Maximum Tasks>, C<Maximum MT Servers>,
and C<Minimum MT Servers> parameter information using F<srvrmgr> command.

=cut

 if and($ADMIN,$APPL,$ENT,$NODE,$PORT,$SVR)
 {var $PSEUDO = 'APPS:SEBL'
  if isUnix()
   var $env = sourceContext(catFile($GATETOP,'gtwysrvr','siebenv.sh'))
  var $job = createTemp('JOB')
  var $out = getTemp('OUT')
  call writeTemp('JOB','list ent param MarketingFileSystem')
  call writeTemp('JOB','list param maxtasks for comp wfprocmgr')
  call writeTemp('JOB','list param maxmtservers for comp wfprocmgr')
  call writeTemp('JOB','list param minmtservers for comp wfprocmgr')
  call writeTemp('JOB','exit')
  call closeTemp('JOB')
  var $cmd = concat(catCommand($GATETOP,'gtwysrvr','bin',${AS.EXE:'srvrmgr'}),\
    ' /g ',quote($NODE),':',$PORT,' /e ',quote($ENT),' /s ',quote($SVR),\
    ' /u ',quote($ADMIN))
  call derivePassword('host',$PSEUDO,$ADMIN,'SEBL_GATE_USER')
  if or(isWindows(),isCygwin())
   call command({cmd => concat($cmd,' /p %s /i ',$job,' >',$out,' 2>&1'),\
                 pwd => ['host',$PSEUDO,$ADMIN,\
                         "Enter '${VAR.ADMIN}' user password:",'']})
  else
  {output | concat($cmd,' /i ',$job,' >',$out,' 2>&1')
   call writePassword("%s\012",\
     'host',$PSEUDO,$ADMIN,"Enter '${VAR.ADMIN}' user password:",'')
   close
  }
  report param_info
  prefix
  {write '---+ Parameter Information'
   write '---## Using: ',encode($cmd)
  }
  call writeFile($out)
  if hasOutput(true)
  {write $TOP
   toc '3:[[',getFile(),'][rda_report][Parameter Information]]'
  }
  if isUnix()
   call restoreContext($env)
  call unlinkTemp('JOB')
  call unlinkTemp('OUT')
 }
 unpretoc
}

=head1 SIEBEL WEB SERVER

Collects important Siebel Web Server files like following:

=over 25

=item F<WEBTOP/upgrade.txt>

Upgrade history

=item F<WEBTOP/base.txt>

Base FP information, which includes the build number

=item F<WEBTOP/enu.txt>

Language-specific build information

=item F<WEBTOP/log.txt>

Installation log

=item F<WEBTOP/bin/eapps.cfg>

Web application details

=item F<WEBTOP/bin/eapps_sia.cfg>

SIA web application details

=back

=cut

if and($WEB,$WEBTOP)
{debug ' Inside SEBL Module, collecting Siebel Web Server files'
 pretoc '2:Siebel Web Server'

 # Determine the load balancer configuration file
 var $lbf = undef
 if createBuffer('CFG','R',catFile($WEBTOP,'bin','eapps.cfg'))
 {if (grepBuffer('CFG','^\[ConnMgmt\]','f'))
  {while ?getLine('CFG')
   {var $lin = chomp(last)
    break match($lin,'^\[')
    if match($lin,'^[^\043]*\bVirtualHostsFile\s*=\s*(.*?)\s*$')
     var $lbf = first
   }
  }
  call deleteBuffer('CFG')
 }

 # Collect Product Information
 # Load the common macros
 run RDA:INVinfo()
 debug ' Inside SEBL module, processing Product Inventory (can take time)'
 report product_info
 title '---+!! Siebel Web Server Product Information'
 title '---## From ',encode($WEBTOP),' '
 title $TOC

 prefix
  write '---+ Files in Siebel Web Server Home'
 call statDir('an',$WEBTOP)
 if hasOutput(true)
  write $TOP

 call inventory_details(catDir($WEBTOP,'inventory'),${B_INTERIM})
 if isCreated()
  toc '3:[[',getFile(),'][rda_report][Product Inventory]]'

 # Collect files
 call fmt_version(false,catFile($WEBTOP,'base.txt'),\
                        catFile($WEBTOP,'enu.txt'),\
                        catFile($WEBTOP,'upgrade.txt'))
 call sort_files(3,$TAIL,\
   catFile($WEBTOP,'base.txt'),\
   catFile($WEBTOP,'enu.txt'),\
   catFile($WEBTOP,'log.txt'),\
   catFile($WEBTOP,'upgrade.log'),\
   catFile($WEBTOP,'upgrade.txt'),\
   catFile($WEBTOP,'admin','eapps.cfg'),\
   catFile($WEBTOP,'admin','t_swseapps.cfg'),\
   catFile($WEBTOP,'admin','lbconfig.cfg'),\
   catFile($WEBTOP,'bin','eapps.cfg'),\
   catFile($WEBTOP,'bin','eapps_sia.cfg'),\
   catFile($WEBTOP,'bin','enu','eapps_sia.cfg'),\
   catFile($WEBTOP,'bin','enu','t_eapps_sia.cfg'),\
   catFile($WEBTOP,'public','enu','lang.cfg'),\
   $lbf)

=head2 swselog - Extension Log Files

Gathers Siebel Web Server extension log files.

=cut

 debug ' Inside SEBL Module, collecting the Web Server Extension log files'
 report swselog
 prefix
 {write '---+!! Siebel Web Server Extension Log Files'
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              risks. To prevent them, access the file outside the browser or \
              use the link to save them and use an adequate viewer.'
  write '|*File Name*| *Size*|*Last Modified Date*|'
 }
 var $cnt = 100
 loop $dir ($APPLTOP,$WEBTOP)
 {loop $fil (grepDir(catDir($dir,'log'),'^ss\d+_\d+\.log$','ipt'))
  {var $lnk = encode($fil)
   var $siz = getSize($fil)
   if $siz
   {output => d,basename($fil)
    if ${CUR.O_LAST}->write_tail($fil,$TAIL)
     var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,']]')
    end ${CUR.O_LAST}
   }
   write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
   decr $cnt
   break !$cnt
  }
 }
 if isCreated(true)
  toc '3:[[',getFile(),'][rda_report][Extension Log Files]]'
 unpretoc
}

# Do not generate an empty table of content
unpretoc

# Restore the previous environment
call restoreContext($bkp)

=head1 SEE ALSO

L<DB:DBinfo|collect::DB:DBinfo>,
L<RDA:INVinfo|collect::RDA:INVinfo>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
