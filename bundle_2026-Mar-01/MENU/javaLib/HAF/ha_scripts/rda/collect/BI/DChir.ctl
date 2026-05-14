# DChir.ctl:555:Collects Oracle Hyperion Interactive Reporting Information
# $Id: DChir.ctl,v 1.22 2015/08/21 16:04:40 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DChir.ctl,v 1.22 2015/08/21 16:04:40 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

BI:DChir - Collects Oracle Hyperion Interactive Reporting Information

=head1 DESCRIPTION

This module collects information for Oracle Hyperion Interactive Reporting.

The following reports can be generated and are regrouped under C<Hyperion
Interactive Reporting>:

=cut

use Type
use Java

echo tput('bold'),'Processing BI.HIR module ...',tput('off')

# Initialization
var $AGE      = ${R_LOG_AGE/T:15}
var $EPM_HOME = ${GRP.EPM.D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}
var $TAIL     = ${DFT.N_TAIL:1000}

var $MOD = cond(isWindows(),'f',\
                isCygwin(), 'f',\
                            'fx')
var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Hyperion Interactive Reporting'

# Load the common macros
run RDA:library()

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Hyperion Interactive Reporting
home collection.

=cut

debug ' Inside HIR module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Hyperion Interactive Reporting Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 dbver - Generic Database Information

Collects generic information for Hyperion Interactive Reporting from Database.

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
 debug ' Inside HIR module, getting generic information'
 report dbver
 write '---+!! Generic Database Information'
 toc '2:[[',getFile(),'][rda_report][Generic Database Information]]'

 if testDb()
 {echo ''
  echo tput('bold'),\
       'The database containing HIR repository is not accessible.',tput('off')
  if $msg = getDbMessage()
   echo $msg
  echo ''

  write 'HIR repository not accessible (',$msg,')'
 }
 else
 {# Display database provider and version
  write '---+ Database Repository Provider and Version'
  write '|*Database Provider*|*Database Version*|'
  write '|',getDbProvider(),'|',getDbVersion(),'|'

=head2 config_db - Repository Information

Collects information from the Repository database.

=cut

  report config_db
  debug ' Inside HIR module, getting Repository database information'
  var $TTL = '---+!! Repository'
  var @TTL = ('',\
               '---+ Configuration from V8_HOST',\
               '---+ Configuration from V8_SA_PROPS',\
               '---+ Configuration from V8_PROP_VALUE',\
               '---+ Configuration from V8_SERVICEAGENT',\
               '---+ Events from V8_ETE_TRIGGER',\
               '---+ Events from V8_EXTTRIGEVENT',\
               '---+ Orphaned Jobs from V8_CONT_VERSION',\
               '---+ Orphaned Jobs from V8_TASK',\
               '---+ Orphaned Jobs from V8_SCHEDULEDTASK',\
               '---+ Hyperion Intelligence Data Sources',\
               '---+ Failed Jobs from V8_SCHEDULEQUEUE')
  var @HDR = ()
  var ($HDR[1],$col1) = getDbColumns('IR','V8_HOST','HOSTNAME')
  call clearDbColumns('IR')
  var ($HDR[2],$col2) = getDbColumns('IR','V8_SA_PROPS')
  call clearDbColumns('IR')
  var ($HDR[3],$col3) = getDbColumns('IR','V8_PROP_VALUE','PROP_NAME','VALUE0')
  call clearDbColumns('IR')
  var ($HDR[4],$col4) = getDbColumns('IR','V8_SERVICEAGENT','NAME',\
                                                            'PORT_NUMBER')
  call clearDbColumns('IR')
  var ($HDR[5],$col5) = getDbColumns('IR','V8_ETE_TRIGGER')
  call clearDbColumns('IR')
  var ($HDR[6],$col6) = getDbColumns('IR','V8_EXTTRIGEVENT')
  call clearDbColumns('IR')
  var ($HDR[7],$col7) = getDbColumns('IR','V8_CONT_VERSION')
  call clearDbColumns('IR')
  var ($HDR[8],$col8) = getDbColumns('IR','V8_TASK')
  call clearDbColumns('IR')
  var ($HDR[9],$col9) = getDbColumns('IR','V8_SCHEDULEDTASK')
  call clearDbColumns('IR')
  var ($HDR[10],$col10) = getDbView({a=>'v8_oce',\
                                     b=>'v8_qry_db_conn',\
                                     c=>'v8_container'},\
    {fct=>'SEL',tid=>'a',col=>'container_uuid',hdr=>' *Container*'},\
    'b.query_name','b.query_type',\
    'c.name','c.description')
  call clearDbColumns('a')
  call clearDbColumns('b')
  call clearDbColumns('c')
  var ($HDR[11],$col11) = getDbView({},\
    {fct=>'NUM',val=>'count(*)',hdr=>' *Count*'})

  set $sql
  {# SQL1
  "SELECT :1
  " FROM v8_host
  "/
  "# MACRO separator(2)
  "# SQL2
  "SELECT :2
  " FROM v8_sa_props
  " ORDER BY agent_uuid,prop_name
  "/
  "# MACRO separator(3)
  "# SQL3
  "SELECT :3
  " FROM v8_prop_value
  " ORDER BY prop_name
  "/
  "# MACRO separator(4)
  "# SQL4
  "SELECT :4
  " FROM v8_serviceagent
  " ORDER BY name
  "/
  "# MACRO separator(5)
  "# SQL5
  "SELECT :5
  " FROM v8_ete_trigger
  "/
  "# MACRO separator(6)
  "# SQL6
  "SELECT :6
  " FROM v8_exttrigevent
  "/
  "# MACRO separator(7)
  "# SQL7
  "SELECT :7
  " FROM v8_cont_version
  " WHERE container_uuid NOT IN (SELECT container_uuid
  "                              FROM v8_container)
  "/
  "# MACRO separator(8)
  "# SQL8
  "SELECT :8
  " FROM v8_task
  " WHERE owner NOT IN (SELECT subject_id
  "                     FROM v8_css_user)
  "/
  "# MACRO separator(9)
  "# SQL9
  "SELECT :9
  " FROM v8_scheduledtask
  " WHERE owner NOT IN (SELECT subject_id
  "                     FROM v8_css_user)
  "/
  "# MACRO separator(10)
  "# SQL10
  "SELECT :10
  " FROM v8_oce a,
  "      v8_qry_db_conn b,
  "      v8_container c
  " WHERE a.container_uuid=b.container_uuid
  "   AND a.container_uuid=c.container_uuid
  " ORDER BY a.container_uuid
  "/
  "# MACRO separator(11)
  "# SQL11
  "SELECT :11
  " FROM v8_schedulequeue
  "/
  }

  call separator(1)
  call writeDb(bindDb($sql,$col1,$col2,$col3,$col4,$col5,$col6,$col7,$col8,\
                      $col9,$col10,$col11))
  call separator(0,'Repository Information')
 }
}

=head2 registry - Windows Registry Information

Collects Windows registry information.

=cut

if or(isWindows(),isCygwin())
{debug ' Inside HIR module, gathering Windows registry information'
 report registry
 prefix
 {write '---+!! Windows Registry Information'
  write $TOC
  write '---+ Hyperion Interactive Reporting Product Information'
 }
 if hasRegOption()
 {if writeRegistry64('HKLM\SOFTWARE\Hyperion Solutions')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Solutions')
   write $TOP
  if writeRegistry64('HKCU\SOFTWARE\Hyperion Solutions')
   write $TOP
  if writeRegistry32('HKCU\SOFTWARE\Hyperion Solutions')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\Brio Software\Interactive Reporting Studio')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Brio Software\Interactive Reporting Studio')
   write $TOP
  if writeRegistry64('HKCU\Software\Brio Software')
   write $TOP
  if writeRegistry32('HKCU\Software\Brio Software')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\ODBC')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\ODBC')
   write $TOP
  if writeRegistry64('HKCU\SOFTWARE\ODBC')
   write $TOP
  if writeRegistry32('HKCU\SOFTWARE\ODBC')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\ORACLE')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\ORACLE')
   write $TOP
 }
 else
 {if writeRegistry('HKLM\SOFTWARE\Hyperion Solutions')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions')
   write $TOP
  if writeRegistry('HKCU\SOFTWARE\Hyperion Solutions')
   write $TOP
  if writeRegistry('HKCU\SOFTWARE\Wow6432Node\Hyperion Solutions')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Brio Software\Interactive Reporting Studio')
   write $TOP
  if writeRegistry(\
       'HKLM\SOFTWARE\Wow6432Node\Brio Software\Interactive Reporting Studio')
   write $TOP
  if writeRegistry('HKCU\Software\Brio Software')
   write $TOP
  if writeRegistry('HKCU\Software\Wow6432Node\Brio Software')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\ODBC')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\ODBC')
   write $TOP
  if writeRegistry('HKCU\SOFTWARE\ODBC')
   write $TOP
  if writeRegistry('HKCU\SOFTWARE\Wow6432Node\ODBC')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\ORACLE')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\ORACLE')
   write $TOP
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Windows Registry Information]]'

=head2 eventx - HIR Events

Extracts Hyperion Interactive Reporting events from the application
event log using the F<wevtutil> command (only available for Windows Vista,
Windows Server 2008, and Windows 7).

=cut

 debug ' Inside HIR module, gathering event log information'
 var $osv = cond(hasRegOption(),\
   nvl(getReg64Value('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion',\
                     'CurrentVersion'),\
       getReg32Value('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion',\
                     'CurrentVersion')),\
   nvl(getRegValue('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion',\
                   'CurrentVersion'),\
       getRegValue('HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows NT\\
                    CurrentVersion','CurrentVersion')))
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
    write '---+!! Hyperion Interactive Reporting Events'
   prefix
    call beginBlock(true)
   if createBuffer('EVT','R',$tmp)
   {call parseReset()
    call parseBegin('TOP','^<Event.*<System>\
       <Provider Name=.*?(HyS9RaFramework|\
                          HyS9RaFrameworkAgent).*/>','Event')
    call parseEnd('Event','.*</Event>$')
    call parseInfo('Event','buf',-1)
    call parseInfo('Event','end',&write_data)
    call parseInfo('Event','llp',false)
    call parse('EVT')
    call deleteBuffer('EVT')
   }
   if hasOutput(true)
    call endBlock(['C','wevtutil qe Application | grep -i \
      HyS9RaFramework|\
      HyS9RaFrameworkAgent'])
   else
    write '**No Hyperion Interactive Reporting events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][HIR Events]]'
   call unlinkTemp('dat')
  }
 }

=head2 events - HIR Events

Extracts Hyperion Interactive Reporting events from the application
event log (only available for Windows NT, Windows 2000, Windows XP, and
Windows 2003).

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

  # Extract the Hyperion Interactive Reporting events
  if ?testFile('r',$evt)
  {report events
   write '---+ Application Events'
   if !writeEvents($evt,'(HyS9RaFramework|\
                          HyS9RaFrameworkAgent)',$AGE)
    write '**No Hyperion Interactive Reporting events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][HIR Events]]'
  }
  if $flg
   call unlinkTemp('evt')
 }
}

=head2 Log Files

Gets log files.

=cut

debug ' Inside HIR module, gathering log files'
pretoc '2:Log Files'
call sort_files(3,$TAIL,\
  grepDir(catDir($EPM_HOME,'diagnostics','logs','ohs'),\
          '^(installSummary.*\.txt|oraInstall.*\.out)$','np'),\
  grepDir(catDir($EPM_HOME,'diagnostics','logs','install'),\
          '^(biplus|i([rm]client|rservices))-(install|fontreg-std(err|out))\
           \.log$','np'),\
  grepDir(catDir($EPM_HOME,'products','BiPlus','bin'),\
          '^(0_((default_(ir(bi|das|job|log)|workspace)_[A-Fa-f0-9]+\
           _std(err|out))|IRJob(StartUp)?))\.log|dbgprint$','np'))
unpretoc

=head2 Configuration Files

Collects configuration files.

=cut

debug ' Inside HIR module, getting configuration files'
pretoc '2:Configuration Files'
call sort_files(3,0,\
  catFile($EPM_HOME,'common','config','11.1.2.0','reg.properties'),\
  catFile($EPM_HOME,'common','config','11.1.2.0','resources','registry',\
          'RegistryLogger.properties'))

# Report attributes of the brioqry.tlb file(s)
report brioqry
write '---+ brioqry.tlb version information'
loop $dir ('System32','SysWOW64')
{if ?testFile('r',catFile(${ENV.SYSTEMROOT:'C:\Windows'},$dir,'brioqry.tlb'))
 {call statFile('p',lastFile())
  write '%BR%'
  var $inf = getVersionInfo(lastFile())
  loop $key (keys($inf))
   write '|*',replace($key,'\012',' ',true),' *|',\
              replace($inf->{$key},'\012','%BR%',true),' |'
 }
}
if isCreated()
 toc '3:[[',getFile(),'][rda_report][brioqry]]'
unpretoc

=head2 filetype - File Type Information

Collects the file type of executable files in Hyperion Interactive Reporting
Information program directory
F<$EPM_HOME/products/Foundation/workspace/MigrationUtility/bin>.

=cut

debug ' Inside HIR module, gathering file type information'

if ?testDir('d',$dir = catDir($EPM_HOME,'products','Foundation','workspace',\
                              'MigrationUtility','bin'))
{report filetype
 title  '---+!! File Type Information'
 title $TOC
 prefix
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
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][File Type Information]]'
}

=head1 DEPLOYMENT REPORTS

Available on version 11.1.2 and later.

=cut

if @ins = ${CUR.O_MODULE}->search('^OI')
{var $CNT = 0
 loop $itm (@ins)
 {var ($ins,$uid) = ($itm->get_first('D_HOME'),$itm->get_oid)
  call setSymbol('$EPM_INSTANCE',$ins)
  call setPrefix(concat($PRE,'i',incr($CNT)))
  toc '%SPLIT%'
  toc "1+:'",basename($ins),"' Deployment"

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Hyperion Interactive Reporting
instance collection.

=cut

  debug ' Inside HIR module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Hyperion Interactive Reporting Instance Abbreviations'
   write '|*Abbreviation*|*Location*|'
  }
  var %hsh = getSymbols()
  loop $key (keys(%hsh))
   write '|',$key,' |',$hsh{$key},' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Abbreviations]]'


=head2 Start Scripts

Collects the start scripts from the F<$INSTANCE_HOME/bin> directory.

=cut

  debug ' Inside EPM module, getting instance start scripts'
  pretoc '2:Start Scripts'
  call sort_files(3,0,\
    catFile($ins,'bin','deploymentScripts',\
            ${AS.BAT:'setCustomParamsEPMSystem'}))
  unpretoc


=head2 Configuration Files

Collects the logging configuration files from the F<$INSTANCE_HOME/config>
directory.

=cut

  debug ' Inside HIR module, getting the logging configuration files'
  pretoc '2:Configuration Files'
  call sort_files(3,0,\
    catFile($ins,'config','config.xml'),\
    catFile($ins,'config','foundation','11.1.2.0','reg.properties'),\
    catFile($ins,'config','foundation','11.1.2.0','epm.xml'),\
    catFile($ins,'config','foundation','11.1.2.0','instance.version'),\
    catFile($ins,'config','FoundationServices',\
            'LCMRegistryDisplay.properties'),\
    catFile($ins,'config','FoundationServices','logging.xml'),\
    catFile($ins,'config','ReportingAnalysis','logging','logging_ir.xml'),\
    catFile($ins,'config','starter','EPMServer.properties'),\
    catFile($ins,'httpConfig','ant-properties','add-alias.properties'),\
    catFile($ins,'httpConfig','autogenerated','ohs',\
            'HYSL-WebLogic-autogenerated.conf'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component',\
            'httpd.conf'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component',\
            'mod_wl_ohs.conf'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component',\
            'mime.types'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component','ssl.conf'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component',\
            'epm_online_help.conf'))
  unpretoc

=head2 diaglogs - Diagnostic Log Files

Collects the diagnostic log files from the F<$INSTANCE_HOME/diagnostics/logs>
directory.

=cut

  debug ' Inside HIR module, getting the diagnostic log files'
  report diaglogs
  var $log = catDir($ins,'diagnostics','logs')
  var %pat = (\
    install    => '^irclient-fontreg-std(err|out)\.log$',\
    ReportingAnalysis => '\.log$',\
    services   => '^HyS9RaFramework(Agent(Err|Out)|-sys(err|out))\.log$',\
    starter    => '^((start|stop)-(HyS9RaFramework(Agent)?|\
                   -HyperionStudioBPMSbpms1)-out|stopAgent.bat)\.log$',\
    validation => '^(validation((-\d+)?|Tool-std(err|out))|velocity)\.log$')
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
  loop $sub ('install','ReportingAnalysis','services','starter','validation')
  {loop $fil (grepDir(catDir($log,$sub),nvl($pat{$sub},'\.log$'),'pt'))
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

Includes the Oracle WebLogic Server reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain.

=cut

  if ${CUR.O_SETUP}->search(concat('^WREQ_BI_HIR_',replace($uid,'^OI','DOM')))
  {var ($req) = last
   var $dom = $req->get_first('I_DOMAIN')
   var $oid = $dom->get_first('I_WL_HOME')->get_oid
   var $nam = $dom->get_first('T_DOMAIN_NAME')
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
   toc '%INCLUDE("OFM_WREQ_BI_HIR_',$oid,'_TF.toc",1)%'
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

=head1 PRODUCT REPORTS

Collects the following reports on versions earlier than 11.1.2:

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic Server reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain (on versions having a product registry).

=cut

elsif ?${GRP.EPM.D_DOMAIN}
{var $dom = basename(last)
 toc '%PUSH("%SPLIT%")%'
 toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
 toc '%INCLUDE("OFM_WREQ_BI_HIR_WH_TF.toc")%'
 toc '%POP2%'
 toc '%PUSH("%SPLIT%")%'
 toc '%PUSH("1+:',"'",$dom,"'",' Domain")%'
 toc '%INCLUDE("OFM_WREQ_BI_HIR_DOM_TF.toc")%'
 toc '%POP2%'
}
unpretoc

=head1 SEE ALSO

L<OFM:DCwreq|collect::OFM:DCwreq>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
