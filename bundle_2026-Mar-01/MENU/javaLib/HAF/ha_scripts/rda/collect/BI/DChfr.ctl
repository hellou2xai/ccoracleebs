# DChfr.ctl:557:Collects Oracle Hyperion Financial Reporting Information
# $Id: DChfr.ctl,v 1.15 2015/08/21 16:04:40 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DChfr.ctl,v 1.15 2015/08/21 16:04:40 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

BI:DChfr - Collects Oracle Hyperion Financial Reporting Information

=head1 DESCRIPTION

This module collects information for Oracle Hyperion Financial Reporting.

The following reports can be generated and are regrouped under C<Hyperion
Financial Reporting>:

=cut

use Type

echo tput('bold'),'Processing BI.HFR module ...',tput('off')

# Initialization
var $AGE           = ${R_LOG_AGE/T:15}
var $EPM_HOME      = \
  ${GRP.EPM.D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}
var $ORACLE_PARENT = ${SET.RDA.BEGIN.D_ORACLE_PARENT:''}
var $TAIL          = ${N_TAIL:1000}

var $MOD = cond(isWindows(),'f',\
                isCygwin(), 'f',\
                            'fx')
var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Hyperion Financial Reporting'

# Load the common macros
run BI:EPMlib()
run RDA:library()

# Limit password file request
var $EPM_VERSION = get_epm_version($EPM_HOME)
if and(compare('SAME',$EPM_VERSION,'11.1.2.2'),\
       compare('OLDER',$EPM_VERSION,'11.1.2.2.300'))
{var $epm = createTemp('EPMPWD','.tmp',false)
 call derivePassword('host','BI:EPM','epmsys_registry','EPM_REGISTRY')
 call writeTempPassword('EPMPWD',"%s\012",'host','BI:EPM','epmsys_registry',\
   'Enter Shared Services database password:','')
 call closeTemp('EPMPWD')
}

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Hyperion Financial Reporting
home collection.

=cut

debug ' Inside HFR module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Hyperion Financial Reporting Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 registry - Registry Information

For Windows, collects Hyperion Financial Reporting-related Registry information.

=cut

if or(isWindows(),isCygwin())
{debug ' Inside HFR module, gathering HFR registry information'
 report registry
 prefix
 {write '---+!! Hyperion Financial Reporting Registry Information'
  write $TOC
 }
 if hasRegOption()
 {if writeRegistry64('HKLM\SOFTWARE\Hyperion Solutions\FinancialReporting')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Solutions\FinancialReporting')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\Hyperion Solutions\FinancialReporting0')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Solutions\FinancialReporting0')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\Hyperion Solutions\Hyperion Reports')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Solutions\Hyperion Reports')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\AFPL Ghostscript')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\AFPL Ghostscript')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\GPL Ghostscript')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\GPL Ghostscript')
   write $TOP
 }
 else
 {if writeRegistry('HKLM\SOFTWARE\Hyperion Solutions\FinancialReporting')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions\\
                    FinancialReporting')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Hyperion Solutions\FinancialReporting0')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions\\
                    FinancialReporting0')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Hyperion Solutions\Hyperion Reports')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions\\
                    Hyperion Reports')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\AFPL Ghostscript')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\AFPL Ghostscript')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\GPL Ghostscript')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\GPL Ghostscript')
   write $TOP
 }
 if writeRegistry('HKCU\Software\Hyperion Analytic Reporter')
  write $TOP
 if writeRegistry('HKLM\SOFTWARE\Oracle Corporation\Financial Reporting Studio')
  write $TOP
 if writeRegistry(\
   'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment')
  write $TOP
 if writeRegistry('HKLM\SYSTEM\CurrentControlSet\Services\HyS9FRReport')
  write $TOP
 if writeRegistry('HKEY_CLASSES_ROOT\CLSID\\
                   {58B2D776-93D0-11D3-9FA7-006008B6FCFD}\LocalServer32')
  write $TOP
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Registry Information]]'

=head2 tcpip_registry - TCP/IP Registry Information

For Windows, collects TCP/IP Registry information.

=cut

 debug ' Inside HFR module, gathering TCP/IP registry information'
 report tcpip_registry
 prefix
 {write '---+!! TCP/IP Registry Information'
  write $TOC
 }
 if writeRegistry('HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters')
  write $TOP
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][TCP/IP Registry Information]]'

=head2 eventx - HFR Events

Extracts Oracle Hyperion Financial Reporting events from the application event
log using the F<wevtutil> command (only available for Windows Vista,
Windows Server 2008, and Windows 7).

=cut

 debug ' Inside HFR module, gathering event log information'
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
    write '---+!! Oracle Hyperion Financial Reporting Events'
   prefix
    call beginBlock(true)
   if createBuffer('EVT','R',$tmp)
   {call parseReset()
    call parseBegin('TOP',\
      '^<Event.*<System><Provider Name=.*?HyS9FRReports.*/>','Event')
    call parseEnd('Event','.*</Event>$')
    call parseInfo('Event','buf',-1)
    call parseInfo('Event','end',&write_data)
    call parseInfo('Event','llp',false)
    call parse('EVT')
    call deleteBuffer('EVT')
   }
   if hasOutput(true)
    call endBlock(['C','wevtutil qe Application | grep -i HyS9FRReports'])
   else
    write '**No Oracle Hyperion Financial Reporting events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][HFR Events]]'
   call unlinkTemp('dat')
  }
 }

=head2 events - HFR Events

Extracts Oracle Hyperion Financial Reporting events from the application event
log (only available for Windows NT, Windows 2000, Windows XP, and Windows 2003).

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

  # Extract the Oracle Hyperion Financial Reporting events
  if ?testFile('r',$evt)
  {report events
   write '---+ Application Events'
   if !writeEvents($evt,'HyS9FRReports',$AGE)
    write '**No Oracle Hyperion Financial Reporting events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][HFR Events]]'
  }
  if $flg
   call unlinkTemp('evt')
 }
}

=head2 Start Scripts

Gets start scripts.

=cut

debug ' Inside HFR module, gathering start scripts'
pretoc '2:Start Scripts'
call sort_files(3,0,\
  catFile($EPM_HOME,'BiPlus','bin',${AS.CMD:'FRSetenv'}),\
  catFile($EPM_HOME,'BiPlus','bin',${AS.BAT:'start_BIPlus'}),\
  catFile($EPM_HOME,'BiPlus','bin',${AS.BAT:'set_common_env'}),\
  catFile($EPM_HOME,'products','BiPlus','bin',${AS.CMD:'FRSetenv'}),\
  catFile($EPM_HOME,'products','BiPlus','bin',${AS.BAT:'start_BIPlus'}),\
  catFile($EPM_HOME,'products','BiPlus','bin',${AS.BAT:'set_common_env'}),\
  catFile($EPM_HOME,'products','BiPlus','bin',${AS.BAT:'start'}),\
  catFile($EPM_HOME,'products','FinancialReportingStudio','products',\
          'financialreporting','bin',${AS.CMD:'FRSetenv'}),\
  catFile($EPM_HOME,'products','FinancialReportingStudio','products',\
          'financialreporting','bin',${AS.CMD:'hrcmd'}),\
  catFile($EPM_HOME,'products','FinancialReportingStudio','products',\
          'financialreporting','bin',${AS.CMD:'ManageUserPov'}),\
  catFile($EPM_HOME,'products','FinancialReportingStudio','products',\
          'financialreporting','bin',${AS.CMD:'SchedulerJobsCopier'}),\
  catFile($EPM_HOME,'deployments','WebSphere6','bin',\
                          ${AS.BAT:'startFinancialReporting'}))
unpretoc

=head2 Configuration Files

Gets configuration files.

=cut

var @fil = ()
loop $sub (findDir(catDir($EPM_HOME,'common','httpServers','Apache'),\
                   '^conf$','ir',2))
 call push(@fil,\
   catFile($sub,'httpd.conf'),\
   catFile($sub,'HYSL-Weblogic.conf'))

debug ' Inside HFR module, gathering configuration files'
pretoc '2:Configuration Files'
call sort_files(3,0,\
  grepDir(catDir($EPM_HOME,'BiPlus','lib'),\
          '^(fr_.*\.properties|fr\.env|EnvSetup\.properties)$','np'),\
  grepDir(catDir($EPM_HOME,'products','BiPlus','lib'),\
          '^(fr_.*\.properties|fr\.env|EnvSetup\.properties)$','np'),\
  catFile($EPM_HOME,'common','config','product','biplus','9.3.1.0',\
          'biplus_1_config.xml'),\
  catFile($EPM_HOME,'common','config','9.5.0.0','product','biplus','9.5.0.0',\
          'biplus_1_config.xml'),\
  catFile($EPM_HOME,'products','financialreporting','lib',\
          'clientlogging.xml'),\
  catFile($EPM_HOME,'products','financialreporting','lib',\
          'printserverlogging.xml'),\
  catFile($EPM_HOME,'products','FinancialReportingStudio','products',\
          'financialreporting','bin','ManageUserPov.properties'),\
  catFile($EPM_HOME,'products','FinancialReportingStudio','products',\
          'financialreporting','bin','SchedulerJobsCopier.properties'),\
  catFile($EPM_HOME,'products','FinancialReportingStudio','products',\
          'financialreporting','bin','SchedulerJobsCopierlogging.xml'),\
  catFile($EPM_HOME,'products','FinancialReportingStudio','products',\
          'financialreporting','bin','ManageUserPovlogging.xml'),\
  catFile($EPM_HOME,'products','FinancialReportingStudio','products',\
          'financialreporting','bin','ManageUserPovSample.xml'),\
  catFile($ORACLE_PARENT,'ohs','diagnostics','config','registration',\
          'OUI.xml'),\
  @fil)
unpretoc

=head2 filetype - File Type Information

Collects the file type of executable files in Hyperion Financial Reporting
program directory F<$EPM_HOME/products/financialreporting/install/bin>.

=cut

debug ' Inside HFR module, gathering file type information'
if ?testDir('d',$dir = catDir($EPM_HOME,'products','financialreporting',\
                              'install','bin'))
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

=head2 ver_hfr - Java Archive Versions

Collects the Java archive versions for the following files:

From F<HYPERION_HOME/BiPlus/lib> directory,

=over 4

=item o F<HReports.jar>

=item o F<foundation.jar>

=back

From F<HYPERION_HOME/products/BiPlus/lib> directory,

=over 4

=item o F<HReports.jar>

=item o F<foundation.jar>

=back

From F<HYPERION_HOME/deployments> directory,

=over 4

=item o F<Tomcat5/FinancialReporting/webapps/hr/WEB-INF/lib/HReports.jar>

=item o F<WebSphere6/profile/installedApps/hyslCell/HReports.ear/hr.war/
WEB-INF/lib/HReports.jar>

=item o F<WebLogic/FinancialReporting/webapps/hr/WEB-INF/lib/HReports.jar>

=item o F<OAS/FinancialReporting/webapps/hr/WEB-INF/lib/HReports.jar>

=back

From F<HYPERION_HOME/common/workspacert/9.5.0.0/lib> directory,

=over 4

=item o F<annotation.jar>

=item o F<foundation.jar>

=back

When F<unzip> is available, it extracts the manifest from Java archives.

=cut

var $UNZIP = findCommand('unzip')
debug ' Inside HFR module, gathering java archive versions'
report ver_hfr
prefix
{write '---+!! Java Archive Version Information'
 write $TOC
}
loop $fil (\
  catFile($EPM_HOME,'BiPlus','lib','HReports.jar'),\
  catFile($EPM_HOME,'BiPlus','lib','foundation.jar'),\
  catFile($EPM_HOME,'products','BiPlus','lib','HReports.jar'),\
  catFile($EPM_HOME,'products','BiPlus','lib','foundation.jar'),\
  catFile($EPM_HOME,'deployments','Tomcat5','FinancialReporting','webapps',\
          'hr','WEB-INF','lib','HReports.jar'),\
  catFile($EPM_HOME,'deployments','OAS','FinancialReporting','webapps',\
          'hr','WEB-INF','lib','HReports.jar'),\
  catFile($EPM_HOME,'deployments','WebLogic','FinancialReporting','webapps',\
          'hr','WEB-INF','lib','HReports.jar'),\
  catFile($EPM_HOME,'deployments','WebSphere6','profile','installedApps',\
          'hyslCell','HReports.ear','hr.war','WEB-INF','lib','HReports.jar'),\
  catFile($EPM_HOME,'common','workspacert','9.5.0.0','lib','annotation.jar'),\
  catFile($EPM_HOME,'common','workspacert','9.5.0.0','lib','foundation.jar'))
{if ?testFile('f',$fil)
 {write '---+ Version Information from ',encode($fil)
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
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Java Archive Versions]]'

=head2 Log Files

Gets log files.

=cut

var @fil = ()
loop $sub (findDir(catDir($EPM_HOME,'common','httpServers','Apache'),\
                   '^logs$','ir',2))
 call push(@fil,catFile($sub,'error.log'))

debug ' Inside HFR module, gathering log files'
pretoc '2:Log Files'
call sort_files(3,$TAIL,\
  grepDir(catDir($EPM_HOME,'BiPlus','logs'),\
          '^(FRReportSrv|FRClient|FRSchedSrv|FRPrintSrv|FRWebApp)\.log',\
          'np'),\
  grepDir(catDir($EPM_HOME,'logs','BiPlus'),\
          '^(FRReportSrv|FRClient|FRSchedSrv|FRPrintSrv|FRWebApp)\.log',\
          'np'),\
  grepDir(catDir($EPM_HOME,'logs','config'),'^configtool\.log','np'),\
  catFile($EPM_HOME,'logs','install','biplus-install.log'),\
  catFile($EPM_HOME,'logs','install','common-install.log'),\
  catFile($EPM_HOME,'logs','install','common-product-install.log'),\
  catFile($EPM_HOME,'logs','config','configtool_err.log'),\
  catFile($EPM_HOME,'logs','workspace','workspace.log'),\
  catFile($EPM_HOME,'logs','workspace','stdout_console.log'),\
  catFile($EPM_HOME,'logs','workspace','servlets_backupMessages.log'),\
  catFile($EPM_HOME,'deployments','WebLogic9','servers','Workspace','logs',\
          'workspace.log'),\
  @fil)
unpretoc

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

Displays the RDA abbreviations defined for the Hyperion Financial Reporting
instance collection.

=cut

  debug ' Inside HFR module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Hyperion Financial Reporting Instance Abbreviations'
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

  debug ' Inside HFR module, getting instance start scripts'
  pretoc '2:Start Scripts'
  call sort_files(3,0,\
    catFile($ins,'bin',${AS.BAT:'startFinancialReporting'}),\
    catFile($ins,'bin','deploymentScripts',\
            ${AS.BAT:'setCustomParamsFinancialReporting'}))
  unpretoc

=head2 CSS Configuration

Exports the CSS Configuration using
F<$INSTANCE_HOME/bin/epmsys_registry.sh> or
F<$INSTANCE_HOME/bin/epmsys_registry.bat>.

=cut

  debug ' Inside HFR module, getting the CSS Configuration'
  call collect_cssconfig(2,catDir($ins,'bin'),$epm)

=head2 Configuration Files

Collects the logging configuration files from the F<$INSTANCE_HOME/config>
directory.

=cut

  debug ' Inside HFR module, getting the logging configuration files'
  pretoc '2:Configuration Files'
  call sort_files(3,0,\
    catFile($ins,'config','FinancialReporting.properties'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component',\
            'httpd.conf'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component',\
            'mod_wl_ohs.conf'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component',\
            'fr_client.properties'))
  unpretoc

=head2 diaglogs - Diagnostic Log Files

Collects the diagnostic log files from the F<$INSTANCE_HOME/diagnostics/logs>
directory.

=cut

  debug ' Inside HFR module, getting the diagnostic log files'
  report diaglogs
  var $log = catDir($ins,'diagnostics','logs')
  var %pat = (\
    FinancialReporting => '^(Adm|AdmAccess|AdmPerformance|FRAccess|\
                             FRClientAccess|FRClientLogging|\
                             FRClientPerformance|FRPerformance|FRPrintAccess|\
                             FRPrintLogging|FRPrintPerformance)\.log$',\
    services => '^HyS9FRReports-sys(err|out)\.log$',\
    starter  => '^(start|stop)-(HyS9FRReports|HyperionRMIRegistry)-out\.log$')
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
  loop $sub ('FinancialReporting','services','starter')
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

  if ${CUR.O_SETUP}->search(concat('^WREQ_BI_HFR_',replace($uid,'^OI','DOM')))
  {var ($req) = last
   var $dom = $req->get_first('I_DOMAIN')
   var $oid = $dom->get_first('I_WL_HOME')->get_oid
   var $nam = $dom->get_first('T_DOMAIN_NAME')
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
   toc '%INCLUDE("OFM_WREQ_BI_HFR_',$oid,'_TF.toc",1)%'
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

=head2 cssconfig - CSS Configuration

Exports the CSS Configuration using
F<$HYPERION_HOME/common/config/9.5.0.0/epmsys_registry.sh> or
F<$HYPERION_HOME/common/config/9.5.0.0/epmsys_registry.bat> (on versions
earlier than 11.1.2).

=cut

else
{debug ' Inside HFR module, getting the CSS Configuration'
 call collect_cssconfig(2,catDir($EPM_HOME,'common','config','9.5.0.0'),$epm)

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic Server reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain (on versions having a product registry).

=cut

 if ?${GRP.EPM.D_DOMAIN}
 {var $dom = basename(last)
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
  toc '%INCLUDE("OFM_WREQ_BI_HFR_WH_TF.toc")%'
  toc '%POP2%'
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:',"'",$dom,"'",' Domain")%'
  toc '%INCLUDE("OFM_WREQ_BI_HFR_DOM_TF.toc")%'
  toc '%POP2%'
 }
}

# Unlink the temporary password file when existing
if ?$epm
 call unlinkTemp('EPMPWD')

unpretoc

=head1 SEE ALSO

L<BI:EPMlib|collect::BI:EPMlib>,
L<OFM:DCwreq|collect::OFM:DCwreq>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
