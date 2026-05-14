# DChwa.ctl:586:Collects Oracle Hyperion Web Analysis Information
# $Id: DChwa.ctl,v 1.11 2015/08/21 16:04:40 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DChwa.ctl,v 1.11 2015/08/21 16:04:40 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

BI:DChwa - Collects Oracle Hyperion Web Analysis Information

=head1 DESCRIPTION

This module collects information for Oracle Hyperion Web Analysis.

The following reports can be generated and are regrouped under C<Hyperion
Web Analysis>:

=cut

echo tput('bold'),'Processing BI.HWA module ...',tput('off')

# Initialization
var $EPM_HOME = ${GRP.EPM.D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}
var $TAIL     = ${DFT.N_TAIL:1000}

var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Hyperion Web Analysis'

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

Displays the RDA abbreviations defined for the Hyperion Web Analysis home
collection.

=cut

debug ' Inside HWA module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Hyperion Web Analysis Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 registry - Registry Information

For Windows, collects Hyperion Web Analysis-related Registry information.

=cut

if or(isWindows(),isCygwin())
{debug ' Inside HWA module, gathering HWA registry information'
 report registry
 title '---+!! Registry Information'
 title $TOC
 if hasRegOption()
 {prefix
   write '---+ Hyperion Web Analysis 64-Bit Registry Settings'
  if writeRegistry64('HKLM\SOFTWARE\Hyperion Solutions\WebAnalysis0')
   write $TOP
  prefix
   write '---+ Hyperion Web Analysis 32-Bit Registry Settings'
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Solutions\WebAnalysis0')
   write $TOP
  unprefix
 }
 else
 {prefix
   write '---+ Hyperion Web Analysis Registry Settings'
  if writeRegistry('HKLM\SOFTWARE\Hyperion Solutions\WebAnalysis0')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions\WebAnalysis0')
   write $TOP
  unprefix
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Registry Information]]'

=head2 Log Files

Gets log files.

=cut

 if ?nvl(testDir('d',catDir(getEnv('USERPROFILE'),'AppData','LocalLow')),\
         testDir('d',catDir(getEnv('APPDATA'))))
 {debug ' Inside HWA module, gathering log files'
  pretoc '2:Log Files'
  call sort_files(3,$TAIL,\
    grepDir(catDir(lastDir(),'Sun','Java','Deployment','log'),'.*','np'))
  unpretoc
 }
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

Displays the RDA abbreviations defined for the Hyperion Web Analysis instance
collection.

=cut

  debug ' Inside HWA module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Hyperion Web Analysis Instance Abbreviations'
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

  debug ' Inside HWA module, getting instance start scripts'
  pretoc '2:Start Scripts'
  call sort_files(3,0,catFile($ins,'bin','deploymentScripts',\
                              ${AS.BAT:'setCustomParamsWebAnalysis'}))
  unpretoc

=head2 CSS Configuration

Exports the CSS Configuration using
F<$INSTANCE_HOME/bin/epmsys_registry.sh> or
F<$INSTANCE_HOME/bin/epmsys_registry.bat>.

=cut

  debug ' Inside HWA module, getting the CSS Configuration'
  call collect_cssconfig(2,catDir($ins,'bin'),$epm)

=head2 Configuration Files

Collects the logging configuration files from the F<$INSTANCE_HOME/config>
directory.

=cut

  debug ' Inside HWA module, getting the logging configuration files'
  pretoc '2:Configuration Files'
  call sort_files(3,0,\
    catFile($ins,'config','foundation','11.1.2.0','reg.properties'))
  unpretoc

=head2 diaglogs - Diagnostic Log Files

Collects the diagnostic log files from the F<$INSTANCE_HOME/diagnostics/logs>
directory.

=cut

  debug ' Inside HWA module, getting the diagnostic log files'
  report diaglogs
  var $log = catDir($ins,'diagnostics','logs')
  var %pat = (\
    services => '^HyS9WebAnalysis-sys(err|out)\.log$',\
    starter  => '^(start|stop)-HyS9WebAnalysis-out\.log$',\
    catDir('upgrades','WebAnalysis') => '^wa_reg_update\.log$',\
    validation => '\.log$')
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
  loop $sub ('services','starter',catDir('upgrades','WebAnalysis'),'validation')
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

  if ${CUR.O_SETUP}->search(concat('^WREQ_BI_HWA_',replace($uid,'^OI','DOM')))
  {var ($req) = last
   var $dom = $req->get_first('I_DOMAIN')
   var $oid = $dom->get_first('I_WL_HOME')->get_oid
   var $nam = $dom->get_first('T_DOMAIN_NAME')
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
   toc '%INCLUDE("OFM_WREQ_BI_HWA_',$oid,'_TF.toc",1)%'
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
{debug ' Inside HWA module, getting the CSS Configuration'
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
  toc '%INCLUDE("OFM_WREQ_BI_HWA_WH_TF.toc")%'
  toc '%POP2%'
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:',"'",$dom,"'",' Domain")%'
  toc '%INCLUDE("OFM_WREQ_BI_HWA_DOM_TF.toc")%'
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
