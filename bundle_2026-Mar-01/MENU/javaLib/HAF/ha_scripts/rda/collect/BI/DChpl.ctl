# DChpl.ctl:563:Collects Oracle Hyperion Planning Information
# $Id: DChpl.ctl,v 1.12 2015/08/21 16:04:40 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DChpl.ctl,v 1.12 2015/08/21 16:04:40 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

BI:DChpl - Collects Oracle Hyperion Planning Information

=head1 DESCRIPTION

This module collects information for Oracle Hyperion Planning.

The following reports can be generated and are regrouped under C<Planning>:

=cut

use Type

echo tput('bold'),'Processing BI.HPL module ...',tput('off')

# Initialization
var $AGE         = ${R_AGE/T:15}
var $EPM_HOME    = \
  ${GRP.EPM.D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}
var $ORACLE_HOME = ${SET.RDA.BEGIN.D_ORACLE_HOME:${ENV.ORACLE_HOME:''}}
var $TAIL        = ${N_TAIL:1000}

var $MOD = cond(isWindows(),'f',\
                isCygwin(), 'f',\
                            'fx')
var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Planning'

# Load the common library
run RDA:library()

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Planning home collection.

=cut

debug ' Inside HPL module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Planning Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 plan_files - Planning Home Files

Reports the contents of F<$EPM_HOME/Planning> directory.

=cut

report plan_files
debug ' Inside HPL module, getting contents of Planning directory'
prefix
{write '---+!! Contents of Planning directory'
 write '---## Information Taken from ',encode($dir)
 write $TOC
}
if ?testDir('d',catDir($EPM_HOME,'Planning'))
{loop $fil (lastDir(),findDir(lastDir(),'^\.+$','drv'))
 {write '---++ Contents of ',encode($fil)
  call statDir('an',$fil)
  write $TOP
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Planning Home Files]]'

=head2 Configuration Files

Collects configuration files.

=cut

pretoc '2:Configuration Files'
debug ' Inside HPL module, getting configuration files'
call sort_files(3,0,\
  catFile($EPM_HOME,'Planning','Planning.SystemDBproperties'),\
  catFile($EPM_HOME,'Planning','HBRServer.properties'),\
  catFile($EPM_HOME,'Planning','config','essbase.properties'),\
  catFile($EPM_HOME,'deployments','WebLogic9','config','config.xml'),\
  grepDir(catDir($EPM_HOME,'deployments','Tomcat5'),\
          'Deploy\.properties$','p'),\
  grepDir(catDir($EPM_HOME,'deployments'),'CSS\.xml','r'),\
  grepDir(catDir($EPM_HOME,'common','config','product','planning',\
                 '9.3.1.0'),\
          '\.(xml|properties)$','p'),\
  grepDir(catDir($EMP_HOME,'common','config','9.5.0.0','product',\
                 'planning','9.5.0.0'),\
          '\.(xml|properties)$','p'),\
  grepDir(catDir($EPM_HOME,'deployments','Tomcat5','HyperionPlanning',\
                 'webapps','HyperionPlanning','WEB-INF','classes'),\
          '\.(xml|properties)$','p'),\
  grepDir(catDir($EPM_HOME,'deployments','WebLogic9','servers',\
                 'HyperionPlanning','webapps','HyperionPlanning','WEB-INF',\
                 'classes'),\
          '\.(xml|properties)$','p'),\
  grepDir(catDir($EPM_HOME,'deployments','WebSphere6','profile',\
                 'installedApps','hyslCell','HyperionPlanning.ear',\
                 'HyperionPlanning.war','WEB-INF','classes'),\
          '\.(xml|properties)$','p'),\
  grepDir(catDir($ORACLE_HOME,'j2ee','HyperionPlanning','applib'),\
          '\.(xml|properties)$','p'))

=head2 filetype - File Type Information

Collects the file type of executable files in several Hyperion Planning
Information program directories inside the F<$EPM_HOME/products/Planning>
directory structure.

=cut

debug ' Inside HPL module, gathering file type information'
report filetype
title  '---+!! File Type Information'
title $TOC
var ($dir,@dir) = (catDir($EPM_HOME,'products','Planning'))
loop $sub ('bin','lib','lib64')
{if ?testDir('d',catDir($dir,$sub))
  call push(@dir,lastDir())
}
if or(isWindows(),isCygwin())
 var ($pat,$opt) = ('\.(exe|dll)$','in')
else
 var ($pat,$opt) = ('^\.+$','nv')
loop $dir (@dir)
{prefix
 {write '---+ Files from ',encode($dir)
  write '|*File Name*|*Type*|'
 }
 loop $fil (grepDir($dir,$pat,$opt))
 {if ?testFile($MOD,catFile($dir,$fil))
   write '|',$fil,'|',nvl(file(lastTestFile(),true),'N/A'),' |'
 }
 write $TOP
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][File Type Information]]'

=head2 Business Rules log files

Collects business rules log files.

=cut

pretoc '2:Business Rules Log Files'
debug ' Inside HPL module, getting business rule log files'
call sort_files(3,$TAIL,\
  catFile($EPM_HOME,'AnalyticAdministrationServices','console','bin',\
          'hbrclient.log'),\
  catFile($EPM_HOME,'deployments','Tomcat5','bin','hbrserver.log'),\
  catFile($EPM_HOME,'deployments','WebSphere6','profile',\
          'hbrserver.log'),\
  catFile($EPM_HOME,'AnalyticAdministrationServices','AppServer',\
          'InstalledApps','WebLogic','8.1','aasDomain','hbrserver.log'),\
  catFile($EPM_HOME,'deployments','WebLogic9','hbrserver.log'),\
  catFile($EPM_HOME,'deployments','Tomcat5','bin','hbrlaunch.log'),\
  catFile($EPM_HOME,'deployments','WebSphere6','profile',\
          'hbrlaunch.log'),\
  catFile($EPM_HOME,'AnalyticAdministrationServices','AppServer',\
          'InstalledApps','WebLogic','8.1','aasDomain','hbrlaunch.log'),\
  catFile($EPM_HOME,'deployments','WebLogic9','hbrlaunch.log'))

=head2 Other log Files

Collects other log files.

=cut

pretoc '2:Other log Files'
debug ' Inside HPL module, getting other log files'
var $opt = concat('pm',$AGE)
call sort_files(3,$TAIL,\
  catFile($EPM_HOME,'deployments','WebSphere6','profile','logs',\
          'HyperionPlanning','SystemErr.log'),\
  catFile($EPM_HOME,'deployments','WebSphere6','profile','logs',\
          'HyperionPlanning','SystemOut.log'),\
  catFile($EPM_HOME,'deployments','Tomcat5','HyperionPlanning',\
          'logs','Planning_log.txt'),\
  catFile($EPM_HOME,'deployments','WebLogic9','servers',\
          'HyperionPlanning','logs','HyperionPlanning.log'),\
  grepDir(catDir($EPM_HOME,'logs'),\
          '\.log$',$opt),\
  grepDir(catDir($EPM_HOME,'Planning','logs'),\
          '\.log$',$opt),\
  grepDir(catDir($ORACLE_HOME,'j2ee','HyperionPlanning',\
                 'application-deployments','HyperionPlanning'),\
          '\.log$',$opt),\
  grepDir(catDir($EPM_HOME,'deployments','Tomcat5','HyperionPlanning',\
          'logs'),\
          '\.log$',$opt),\
  grepDir(catDir($EPM_HOME,'WebSphere6','profile','logs',\
                 'HyperionPlanning'),\
          '\.log$',$opt),\
  grepDir(catDir($EPM_HOME,'deployments','Tomcat5','HyperionPlanning',\
                 'webapps','HyperionPlanning','WEB-INF','classes'),\
          '\.log$',$opt),\
  grepDir(catDir($EPM_HOME,'deployments','WebLogic9','servers',\
                 'HyperionPlanning','webapps','HyperionPlanning','WEB-INF',\
                 'classes'),\
          '\.log$',$opt),\
  grepDir(catDir($EPM_HOME,'deployments','WebSphere6','profile',\
                 'installedApps','hyslCell','HyperionPlanning.ear',\
                 'HyperionPlanning.war','WEB-INF','classes'),\
          '\.log$',$opt),\
  grepDir(catDir($ORACLE_HOME,'j2ee','HyperionPlanning','applib'),\
          '\.log$',$opt),\
  grepDir(catDir($ORACLE_HOME,'opmn','logs'),\
          '.',$opt))

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

Displays the RDA abbreviations defined for the Planning instance collection.

=cut

  debug ' Inside HPL module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Planning Instance Abbreviations'
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

  debug ' Inside HPL module, getting instance start scripts'
  pretoc '2:Start Scripts'
  call sort_files(3,0,\
    catFile($ins,'bin',${AS.BAT:'startPlanning'}),\
    catFile($ins,'bin',${AS.BAT:'stopPlanning'}),\
    catFile($ins,'bin','deploymentScripts',${AS.BAT:'setCustomParamsPlanning'}))
  unpretoc

=head2 diaglogs - Diagnostic Log Files

Collects the diagnostic log files from F<$INSTANCE_HOME/diagnostics/logs>
directory.

=cut

  report diaglogs
  var $log = catDir($ins,'diagnostics','logs')
  prefix
  {write '---+!! Diagnostic Log Files'
   write '---## From: ',$log
   write '   * Last ',$TAIL,' lines from the log files captured'
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               risks. To prevent them, access the file outside the browser or \
               use the link to save them and use an adequate viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  loop $fil (grepDir(catDir($log,'planning'),'\.log$','irt'))
  {var $lnk = encode($fil)
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
   toc '2:[[',getFile(),'][rda_report][Diagnostic Log Files]]'

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain.

=cut

  if ${CUR.O_SETUP}->search(concat('^WREQ_BI_HPL_',replace($uid,'^OI','DOM')))
  {var ($req) = last
   var $dom = $req->get_first('I_DOMAIN')
   var $oid = $dom->get_first('I_WL_HOME')->get_oid
   var $nam = $dom->get_first('T_DOMAIN_NAME')
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
   toc '%INCLUDE("OFM_WREQ_BI_HPL_',$oid,'_TF.toc",1)%'
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
 toc '%INCLUDE("OFM_WREQ_BI_HPL_WH_TF.toc")%'
 toc '%POP2%'
 toc '%PUSH("%SPLIT%")%'
 toc '%PUSH("1+:',"'",$dom,"'",' Domain")%'
 toc '%INCLUDE("OFM_WREQ_BI_HPL_DOM_TF.toc")%'
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
