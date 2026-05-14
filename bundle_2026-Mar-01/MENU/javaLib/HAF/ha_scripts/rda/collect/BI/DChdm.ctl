# DChdm.ctl:581:Collects Oracle Hyperion Disclosure Management Information
# $Id: DChdm.ctl,v 1.7 2015/08/21 16:04:40 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DChdm.ctl,v 1.7 2015/08/21 16:04:40 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

BI:DChdm - Collects Oracle Hyperion Disclosure Management Information

=head1 DESCRIPTION

This module collects information for Oracle Hyperion Disclosure Management.

The following reports can be generated and are regrouped under C<Hyperion
Disclosure Management>:

=cut

echo tput('bold'),'Processing BI.HDM module ...',tput('off')

# Initialization
var $AGE           = ${R_LOG_AGE/T:15}
var $EPM_HOME      = \
  ${GRP.EPM.D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}
var $ORACLE_PARENT = ${SET.RDA.BEGIN.D_ORACLE_PARENT:''}
var $TAIL          = ${N_TAIL:1000}

var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Hyperion Disclosure Management'

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

Displays the RDA abbreviations defined for the Hyperion Disclosure Management
home collection.

=cut

debug ' Inside HDM module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Hyperion Disclosure Management Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 registry - Registry Information

For Windows, collects Hyperion Disclosure Management-related Registry
information.

=cut

if or(isWindows(),isCygwin())
{debug ' Inside HDM module, gathering HDM registry information'
 report registry
 prefix
 {write '---+!! Hyperion Disclosure Management Registry Information'
  write $TOC
 }
 if hasRegOption()
 {if writeRegistry64('HKLM\SOFTWARE\Hyperion Solutions\DisclosureManagement0\\
                      HyS9Disclosure')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Solutions\DisclosureManagement0\\
                      HyS9Disclosure')
   write $TOP
 }
 else
 {if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions\\
                    DisclosureManagement0\HyS9Disclosure')
   write $TOP
 }
 if writeRegistry('HKLM\SYSTEM\CurrentControlSet\Services\HyS9Disclosure')
  write $TOP
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Registry Information]]'

=head2 eventx - HDM Events

Extracts Oracle Hyperion Disclosure Management events from the application event
log using the F<wevtutil> command (only available for Windows Vista,
Windows Server 2008, and Windows 7).

=cut

 debug ' Inside HDM module, gathering event log information'
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
    write '---+!! Oracle Hyperion Disclosure Management Events'
   prefix
    call beginBlock(true)
   if createBuffer('EVT','R',$tmp)
   {call parseReset()
    call parseBegin('TOP',\
      '^<Event.*<System><Provider Name=.*?HyS9Disclosure.*/>','Event')
    call parseEnd('Event','.*</Event>$')
    call parseInfo('Event','buf',-1)
    call parseInfo('Event','end',&write_data)
    call parseInfo('Event','llp',false)
    call parse('EVT')
    call deleteBuffer('EVT')
   }
   if hasOutput(true)
    call endBlock(['C',\
                   'wevtutil qe Application | grep -i HyS9Disclosure'])
   else
    write '**No Oracle Hyperion Disclosure Management events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][HDM Events]]'
   call unlinkTemp('dat')
  }
 }

=head2 events - HDM Events

Extracts Oracle Hyperion Disclosure Management events from the application event
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

  # Extract the Oracle Hyperion Disclosure Management events
  if ?testFile('r',$evt)
  {report events
   write '---+ Application Events'
   if !writeEvents($evt,'HyS9Disclosure',$AGE)
    write '**No Oracle Hyperion Disclosure Management events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][HDM Events]]'
  }
  if $flg
   call unlinkTemp('evt')
 }
}

=head2 Start Scripts

Collects the start scripts from the F<$INSTANCE_HOME/bin> directory.

=cut

debug ' Inside HDM module, getting instance start scripts'
pretoc '2:Start Scripts'
call sort_files(3,0,\
  catFile($ins,'bin','deploymentScripts',\
          ${AS.BAT:'setCustomParamsDisclosureManagement'}),\
  catFile($ins,'DisclosureManagement','discman1','config',\
          'mappingtool.properties'))
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
  catFile($EPM_HOME,'products','hdm','cfg','logging.xml'),\
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

Displays the RDA abbreviations defined for the Hyperion Disclosure Management
instance collection.

=cut

  debug ' Inside HDM module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Hyperion Disclosure Management Instance Abbreviations'
   write '|*Abbreviation*|*Location*|'
  }
  var %hsh = getSymbols()
  loop $key (keys(%hsh))
   write '|',$key,' |',$hsh{$key},' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 CSS Configuration

Exports the CSS Configuration using
F<$INSTANCE_HOME/bin/epmsys_registry.sh> or
F<$INSTANCE_HOME/bin/epmsys_registry.bat>.

=cut

  debug ' Inside HDM module, getting the CSS Configuration'
  call collect_cssconfig(2,catDir($ins,'bin'),$epm)

=head2 Configuration Files

Collects the logging configuration files from the F<$INSTANCE_HOME/config>
directory.

=cut

  debug ' Inside HDM module, getting the logging configuration files'
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

  debug ' Inside HDM module, getting the diagnostic log files'
  report diaglogs
  var $log = catDir($ins,'diagnostics','logs')
  var %pat = (\
    fdqm => '^(server|taskmanager-install)\.log$',\
    hdm => '^interop\.log$',\
    starter  => '^(start|stop)-HyHDMSrv-out\.log$')
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
  loop $sub ('fdqm','hdm','starter')
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

  if ${CUR.O_SETUP}->search(concat('^WREQ_BI_HDM_',replace($uid,'^OI','DOM')))
  {var ($req) = last
   var $dom = $req->get_first('I_DOMAIN')
   var $oid = $dom->get_first('I_WL_HOME')->get_oid
   var $nam = $dom->get_first('T_DOMAIN_NAME')
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
   toc '%INCLUDE("OFM_WREQ_BI_HDM_',$oid,'_TF.toc",1)%'
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
F<$HYPERION_HOME/common/config/9.5.0.0/epmsys_registry.bat>.

=cut

else
{debug ' Inside HDM module, getting the CSS Configuration'
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
  toc '%INCLUDE("OFM_WREQ_BI_HDM_WH_TF.toc")%'
  toc '%POP2%'
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:',"'",$dom,"'",' Domain")%'
  toc '%INCLUDE("OFM_WREQ_BI_HDM_DOM_TF.toc")%'
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
