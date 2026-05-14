# DCpr.ctl:556:Collects Oracle Hyperion SQR Production Reporting Information
# $Id: DCpr.ctl,v 1.9 2015/07/03 11:49:17 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DCpr.ctl,v 1.9 2015/07/03 11:49:17 RDA Exp $
#
# Change History
# 20150703  MSC  Improve the documentation.

=head1 NAME

BI:DCpr - Collects Oracle Hyperion SQR Production Reporting Information

=head1 DESCRIPTION

This module collects information for Oracle Hyperion SQR Production Reporting.

The following reports can be generated and are regrouped under C<Hyperion SQR
Production Reporting>:

=cut

use Type

echo tput('bold'),'Processing BI.PR module ...',tput('off')

# Initialization
var $EPM_HOME = ${GRP.EPM.D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}
var $MOD = cond(isWindows(),'f',\
                isCygwin(), 'f',\
                            'fx')
var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

# Load the common macros
run RDA:library()

pretoc '1:Hyperion SQR Production Reporting'

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Hyperion SQR Production
Reporting home collection.

=cut

debug ' Inside PR module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Hyperion SQR Production Reporting Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 registry - Windows Registry Information

Collects Windows registry information.

=cut

if or(isWindows(),isCygwin())
{debug ' Inside PR module, gathering Windows registry information'
 report registry
 prefix
 {write '---+!! Windows Registry Information'
  write $TOC
  write '---+ Hyperion SQR Production Reporting Product Information'
 }
 if hasRegOption()
 {if writeRegistry64('HKLM\SOFTWARE\Brio Software\SQR Developer')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Brio Software\SQR Developer')
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
 }
 else
 {if writeRegistry('HKLM\SOFTWARE\Brio Software\SQR Developer')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Brio Software\SQR Developer')
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
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Windows Registry Information]]'

=head2 sqr - SQR Initialization File

For Windows, collects the SQR Initialization files from Windows root directory.

=cut

 debug ' Inside PR module, getting SQR initialization files'
 report sqr
 title  '---+!! Windows SQR initialization files'
 title $TOC
 loop $fil (grepDir(${ENV.SYSTEMROOT:'C:\Windows'},\
                    '^sqr((64)?\.ini(\.[0-9]+)?|\sDeveloper)$','inp'))
 {write '---++ ',encode($fil),' file contents'
  call writeFile($fil)
  write $TOP
 }
 if isCreated()
  toc '2:[[',getFile(),'][rda_report][Windows SQR Initialization Files]]'
}

=head2 Log Files

Gets log files.

=cut

debug ' Inside PR module, gathering log files'
pretoc '2:Log Files'
call sort_files(3,$TAIL,\
  grepDir(catDir($EPM_HOME,'diagnostics','logs','install'),\
          '^(pr(client|serverboth))-install\.log$','np'))
unpretoc

=head2 Configuration Files

Collects configuration files.

=cut

debug ' Inside PR module, getting configuration files'
pretoc '2:Configuration Files'
call sort_files(3,0,\
  catFile($EPM_HOME,'products','biplus','bin','SQR','Studio','bin',\
          'inschart.sqi'),\
  grepDir(catDir($EPM_HOME,'products','biplus','bin','Translations'),\
          '^briottbl\.xliff$','inrp',1))
unpretoc

=for stopwords bdprovider

=head2 bdprovider - SQR Database Provider Configuration Files

Collects the SQR Database Provider Configuration related files.

=cut

debug ' Inside PR module, gathering database provider files'

report dbprovider
title  '---+!! Database Provider Configuration'
title $TOC
loop $dir (findDir(catDir($EPM_HOME,'products','biplus','bin','SQR','Server'),\
                   '^\.+$','pnv'))
{prefix
  write '---+ Files for ',encode(basename($dir))
 loop $fil (grepDir(catDir($dir,'bin'),'^(sqr_en\.ini|VERSION)$','np'),\
            grepDir(catDir($dir,'bin64'),'^(sqr_en\.ini|VERSION)$','np'))
 {write '---++ ',encode($fil),' file contents'
  call writeFile($fil)
  write $TOP
 }
}
if isCreated()
 toc '2:[[',getFile(),'][rda_report][Database Provider Configuration]]'
unpretoc

=head2 filetype - File Type Information

Collects the file type of executable files for Hyperion SQR Production Reporting
Information under F<$EPM_HOME/products/biplus/bin/SQR/Server> directory.

=cut

debug ' Inside PR module, gathering file type information'

report filetype
title  '---+!! File Type Information'
title $TOC
loop $dir (findDir(catDir($EPM_HOME,'products','biplus','bin','SQR','Server'),\
                   '^\.+$','pnv'))
{prefix
 {write '---+ Files from ',encode($dir)
  write '|*File Name*|*Type*|'
 }
 if or(isWindows(),isCygwin())
  var ($pat,$opt) = ('\.(exe|dll)$','inp')
 else
  var ($pat,$opt) = ('^\.+$','nvp')
 loop $fil (grepDir(catDir($dir,'bin'),$pat,$opt),\
            grepDir(catDir($dir,'bin64'),$pat,$opt))
 {if ?testFile($MOD,$fil)
   write '|',$fil,'|',nvl(file(lastTestFile(),true),'N/A'),' |'
 }
 write $TOP
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][File Type Information]]'

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

Displays the RDA abbreviations defined for the Hyperion SQR Production
Reporting instance collection.

=cut

  debug ' Inside PR module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Hyperion SQR Production Reporting Instance Abbreviations'
   write '|*Abbreviation*|*Location*|'
  }
  var %hsh = getSymbols()
  loop $key (keys(%hsh))
   write '|',$key,' |',$hsh{$key},' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic Server reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain.

=cut

  if ${CUR.O_SETUP}->search(concat('^WREQ_BI_PR_',replace($uid,'^OI','DOM')))
  {var ($req) = last
   var $dom = $req->get_first('I_DOMAIN')
   var $oid = $dom->get_first('I_WL_HOME')->get_oid
   var $nam = $dom->get_first('T_DOMAIN_NAME')
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
   toc '%INCLUDE("OFM_WREQ_BI_PR_',$oid,'_TF.toc",1)%'
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
 toc '%INCLUDE("OFM_WREQ_BI_PR_WH_TF.toc")%'
 toc '%POP2%'
 toc '%PUSH("%SPLIT%")%'
 toc '%PUSH("1+:',"'",$dom,"'",' Domain")%'
 toc '%INCLUDE("OFM_WREQ_BI_PR_DOM_TF.toc")%'
 toc '%POP2%'
}
unpretoc

=head1 SEE ALSO

L<OFM:DCwreq|collect::OFM:DCwreq>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
