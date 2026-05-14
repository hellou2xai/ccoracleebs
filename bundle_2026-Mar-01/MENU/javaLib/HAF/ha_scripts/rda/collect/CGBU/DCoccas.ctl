# DCoccas.ctl:502:Collects Converged Application Server Information
# $Id: DCoccas.ctl,v 1.7 2015/07/03 11:30:36 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCoccas.ctl,v 1.7 2015/07/03 11:30:36 RDA Exp $
#
# Change History
# 20150703  MSC  Improve the documentation.

=head1 NAME

CGBU:DCoccas - Collects Oracle Communications Converged Application Server
Information

=head1 DESCRIPTION

This module collects Oracle Communications Converged Application Server-related
information. The following reports can be generated and are regrouped under
C<Converged Application Server>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.OCCAS module ...',tput('off')

# Initialization
var $BSU_FACTOR  = ${SET.OFM.WREQ.R_BSU_FACTOR:1}
var $DFT_TIMEOUT = ${DFT.N_TIMEOUT:30}
var $DOMAIN      = ${D_DOMAIN_HOME:''}
var $HOME        = ${D_HOME:''}
var $TAIL        = ${N_TAIL:100000}
var $WH          = ${MOD.WREQ_CGBU_OCCAS_DOM.D_WL_HOME/P}

if ?getCodePage()
 var $CODEPAGE = concat('<? CodePage:',last,' ?>')

var $MH  = cleanPath([$HOME,upDir(),''],true)
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Converged Application Server'

# Set the symbols
call setSymbol('$DOM',$DOMAIN)
call setSymbol('$MH',$MH)
call setSymbol('$OCCAS_HOME',$HOME)

# Load the common macros
run RDA:INVinfo()
run RDA:library()

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Converged Application Server
home collection.

=cut

debug ' Inside OCCAS module, collecting defined abbreviations'
report abbr
prefix
{write '---+ Converged Application Server Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 product_info - Product Information

Gathers the product information when it is available.

=cut

if ?$dir = nvl(testDir('d',catDir($HOME,'inventory')),\
               testDir('d',catDir($MH,'inventory')))
{debug ' Inside OCCAS module, processing Product Information (can take time)'
 report product_info
 prefix
 {write '---+!! Oracle Communications Converged Application Server Product \
                Information'
  write '---## From ',encode($dir),' '
  write $TOC
 }
 call inventory_details($dir,true)
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Product Information]]'
}

=head2 wls_smart_update - Applied WebLogic Server Smart Update Information

Gets the applied Oracle WebLogic Server smart update information using the
C<bsu> command (for versions earlier than Converged Application Server 7).

=cut

if ?$dir = testDir('d',catDir($MH,'utils','bsu'))
{debug ' Inside OCCAS module, gathering WebLogic server smart update details'
 var $max = expr('*',$DFT_TIMEOUT,$BSU_FACTOR)
 if expr('>=',$max,60)
  debug ' Smart update command collection can take ',expr('/',$max,60),\
        ' minute(s) to complete'
 elsif expr('<=',$max,0)
  debug ' Smart update command collection can take minutes to complete'
 report wls_smart_update
 prefix
  write '---+ Applied WebLogic Server Smart Update Information'
 if isUnix()
 {var $opt = concat(' -view -patch_download_dir=',\
    quote(catDir($dir,'cache_dir')),\
    ' -status=applied -verbose -prod_dir=',quote($WH))
  write '---## Using: ',concat(catFile($dir,'bsu.sh'),$opt)
  var $job = createTemp('PCH','.sh',true)
  call writeTemp('PCH','cd ',quote($dir))
  call writeTemp('PCH','./bsu.sh',$opt)
  call closeTemp('PCH')
  call writeCommand($job,true,$BSU_FACTOR)
  call unlinkTemp('PCH')
 }
 elsif and(or(isCygwin(),isWindows()),match($WH,'^[^"]+$'))
 {var $opt = concat(' -view -patch_download_dir="',\
    getNativePath(catDir($dir,'cache_dir')),\
    '" -status=applied -verbose -prod_dir="',getNativePath($WH),'"')
  if ?$CODEPAGE
   write last
  write '---## Using: ',concat(catFile($dir,'bsu.cmd'),$opt)
  var $job = createTemp('PCH','.bat',true)
  call writeTemp('PCH','@echo off')
  call writeTemp('PCH','cd /d "',getNativePath($dir),'"')
  call writeTemp('PCH','bsu.cmd',$opt)
  call closeTemp('PCH')
  call writeCommand($job,true,$BSU_FACTOR)
  call unlinkTemp('PCH')
 }
 if isCreated(true)
  toc '2:[[',getFile(),\
      '][rda_report][Applied WebLogic Server Smart Update Information]]'

=head2 smart_update - Applied Smart Update Information

Gets the applied Converged Application Server smart update information using
the C<bsu> command (for versions earlier than Converged Application Server 7).

=cut

 debug ' Inside OCCAS module, gathering smart update details'
 report smart_update
 prefix
  write '---+ Applied Converged Application Server Smart Update Information'
 if isUnix()
 {var $opt = concat(' -view -patch_download_dir=',\
    quote(catDir($dir,'cache_dir')),\
    ' -status=applied -verbose -prod_dir=',quote($HOME))
  write '---## Using: ',concat(catFile($dir,'bsu.sh'),$opt)
  var $job = createTemp('PCH','.sh',true)
  call writeTemp('PCH','cd ',quote($dir))
  call writeTemp('PCH','./bsu.sh',$opt)
  call closeTemp('PCH')
  call writeCommand($job,true,$BSU_FACTOR)
  call unlinkTemp('PCH')
 }
 elsif and(or(isCygwin(),isWindows()),match($HOME,'^[^"]+$'))
 {var $opt = concat(' -view -patch_download_dir="',\
    getNativePath(catDir($dir,'cache_dir')),\
    '" -status=applied -verbose -prod_dir="',getNativePath($HOME),'"')
  if ?$CODEPAGE
   write last
  write '---## Using: ',concat(catFile($dir,'bsu.cmd'),$opt)
  var $job = createTemp('PCH','.bat',true)
  call writeTemp('PCH','@echo off')
  call writeTemp('PCH','cd /d "',getNativePath($dir),'"')
  call writeTemp('PCH','bsu.cmd',$opt)
  call closeTemp('PCH')
  call writeCommand($job,true,$BSU_FACTOR)
  call unlinkTemp('PCH')
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Applied Smart Update Information]]'
}

=head2 opatch_detail - OPatch Detail

Produces a detailed inventory report when C<opatch> is available (for Converged
Application Server version 7 and later).

=cut

elsif ?testFile('f',catFile($MH,'OPatch',${AS.BATCH:'opatch'}))
{debug ' Inside OCCAS module, gathering opatch information'
 var $tgt = addTarget(${MOD.WREQ_CGBU_OCCAS_DOM.I_DOMAIN})
 if ?nvl($tgt->get_wl_home('jdk'),\
         $tgt->get_mw_home('jdk'),\
         $tgt->get_common('jdk'),\
         ${ENV.JAVA_HOME})
 {var $cmd = concat(lastTestCommand(),' lsinventory -jdk ',quote(last),\
                   ' -oh ',quote($MH),' -detail')
  report opatch_detail
  title '---+ Detailed Inventory Report'
  if ?$CODEPAGE
   title last
  title '---## Using: ',encode($cmd)
  call writeCommand($cmd)
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][OPatch Detail]]'
  }
 }
}

=head2 patch_cls - Patch Classes Information

Gets the Java archive files patch classes information.

=cut

var $env = sourceContext(catNative($WH,'server','bin',${AS.CMD:'setWLSEnv'}))
if ?findCommand('jar')
{var $pgm = last
 debug ' Inside OCCAS module, gathering patch classes information'
 report patch_cls
 title '---+!! Java Archive Files Patch Classes Information'
 title $TOC
 loop $dir (findDir($MH,'^patch','np'))
 {loop $fil (grepDir(catDir($dir,'patch_jars'),'\.jar$','np'))
  {prefix
    write '---+ ',encode($fil)
   call writeCommand(concat($pgm,' -tf ',quote($fil)))
   if hasOutput(true)
    write $TOP
  }
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Patch Classes Information]]'
}
call restoreContext($env)

=head2 mh_perms - Middleware Home File Permissions

Collects the owner and group permissions of the files used by Middleware home.

=cut

debug ' Inside OCCAS module, gathering middleware home file permissions'
if ?testDir('d',$MH)
{report mh_perms
 prefix
  write '---+ Middleware Home File Permissions'
 loop $fil ($MH,findDir($MH,'^[\.]+$','drv'))
  call statDir('an',$fil)
 if isCreated(true)
 {write $TOP
  toc '2:[[',getFile(),'][rda_report][Middleware Home File Permissions]]'
 }
}

=head2 dom_perms - Domain Home File Permissions

Collects the owner and group permissions of the files used by domain home.

=cut

debug ' Inside OCCAS module, gathering domain home file permissions'
if ?testDir('d',$DOMAIN)
{report dom_perms
 prefix
  write '---+ Domain Home File Permissions'
 loop $fil ($DOMAIN,findDir($DOMAIN,'^[\.]+$','drv'))
  call statDir('an',$fil)
 if isCreated(true)
 {write $TOP
  toc '2:[[',getFile(),'][rda_report][Domain Home File Permissions]]'
 }
}

=head2 Oracle WebLogic Server Domain Information

It includes all reports produced by the L<abr:WREQ|collect::OFM:DCwreq> module
for the specified Oracle WebLogic Server domain.

=cut

toc '%PUSH("%SPLIT%")%'
toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
toc '%INCLUDE("OFM_WREQ_CGBU_OCCAS_WH_TF.toc")%'
toc '%POP2%'
toc '%PUSH("%SPLIT%")%'
toc '%PUSH("1+:Oracle WebLogic Server Domain")%'
toc '%INCLUDE("OFM_WREQ_CGBU_OCCAS_DOM_TF.toc")%'
toc '%POP2%'

unpretoc

=head1 SEE ALSO

L<OFM:DCwreq|collect::OFM:DCwreq>,
L<RDA:INVinfo|collect::RDA:INVinfo>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
