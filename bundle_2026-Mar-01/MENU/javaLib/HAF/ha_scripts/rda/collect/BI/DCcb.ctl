# DCcb.ctl:585:Collects Oracle Crystal Ball Information
# $Id: DCcb.ctl,v 1.5 2013/11/19 08:34:03 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DCcb.ctl,v 1.5 2013/11/19 08:34:03 RDA Exp $
#
# Change History
# 20131115  JGS  Fix spell.

=head1 NAME

BI:DCcb - Collects Oracle Crystal Ball Information

=head1 DESCRIPTION

This module collects information for Oracle Crystal Ball.

The following reports can be generated and are regrouped under C<Oracle Crystal
Ball>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing BI.CB module ...',tput('off')

# Initialization
var $ROTATED_LOGS = ${N_ROTATED_LOGS:3}
var $TAIL         = ${DFT.N_TAIL:1000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Oracle Crystal Ball'

# Load the common library
run RDA:library()

=head2 registry - Registry Information

Collects Crystal Ball-related Registry information.

=cut

debug ' Inside CB module, gathering CB registry information'
report registry
prefix
{write '---+!! Crystal Ball-Related Registry Information'
 write $TOC
}
if writeRegistry('HKCU\Software\Oracle')
 write $TOP
if writeRegistry('HKCU\Software\Microsoft\Office\Excel\Addins')
 write $TOP

if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Registry Information]]'

=head2 excel - Microsoft Office Excel

Gathers Microsoft Office Excel configuration.

=cut

debug ' Inside CB module, gathering the Microsoft Excel configuration'

macro get_excel
{loop $key (@arg)
 {if match($key,'\\1[1245]\.0\\Excel\\InstallRoot$')
   return $key
 }
 return undef
}

var $dir = undef
if hasRegOption()
{if ?get_excel(grepReg64Value('HKLM\SOFTWARE\Microsoft\Office','Path'))
  var $dir = getReg64Value(last,'Path')
 elsif ?get_excel(grepReg32Value('HKLM\SOFTWARE\Microsoft\Office','Path'))
  var $dir = getReg32Value(last,'Path')
}
else
{if ?get_excel(grepRegValue('HKLM\SOFTWARE\Microsoft\Office','Path'))
  var $dir = getRegValue(last,'Path')
 elsif ?get_excel(grepRegValue('HKLM\SOFTWARE\Wow6432Node\Microsoft\Office',\
                               'Path'))
  var $dir = getRegValue(last,'Path')
}
if ?$dir
{report excel
 loop $fil (grepDir($dir,'excel\.exe\.config','ir'))
 {prefix
   write '---+!! ',$fil
  call writeFile($fil)
  write $TOP
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Microsoft Office Excel Configuration]]'
}

=head2 framework - .NET Framework Versions

Extracts which .NET framework versions are installed from the
F<%SYSTEMROOT%\Microsoft.NET\Framework> directory.

=cut

debug ' Inside CB module, gathering .NET Framework versions'
report framework
prefix
{write '---+!! .NET Framework Versions'
 write '|*Version*|*Installation Directory*|'
}
var $dir = catDir(${ENV.SYSTEMROOT:'C:\WINDOWS'},'Microsoft.NET','Framework')
loop $nam (findDir($dir,'^v\d+(\.\d+)+','i'))
  write '|',substr($nam,1),'|',catDir($dir,$nam),'|'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][.NET Framework Versions]]'

=head2 Installation Log Files

Gathers Oracle Crystal Ball installation log files.

=cut

debug ' Inside CB module, gathering install log files'
pretoc '2:Installation Log Files'
call tail_report(${ENV.TEMP},'cbmsiinstall.txt',$TAIL)
call tail_report(${ENV.TEMP},'SystemAnalyzer.log',$TAIL)
unpretoc

=head2 Application Log Files

Gathers Oracle Crystal Ball application log files.

=cut

debug ' Inside CB module, gathering application log files'
var ($dir,%log) = (catDir(${ENV.APPDATA},'Oracle','Crystal Ball'))
loop $sub (findDir($dir,'^\d+','n'))
{next !?testDir('d',$log = catDir($dir,$sub,'Logs'))
 loop $fil (grepDir($log,'^(AppMgr\s+log|CB\s+Log|PSI\s+Log)\.txt$','np'))
  var $log{$sub,$fil} = true
 if $ROTATED_LOGS
 {loop $pat ('^AppMgr\s+log_\d+\.txt$',\
             '^CB\s+Log_\d+\.txt$',\
             '^PSI\s+Log_\d+\.txt$')
  {var $cnt = $ROTATED_LOGS
   loop $fil (grepDir($log,$pat,'pt'))
   {var $log{$sub,$fil} = true
    break !decr($cnt)
   }
  }
 }
 if grepDir($log,'^\d{1,2}-\d{1,2}-\d{4}_\d+\.txt$','p')
  var $log{$sub,first(last)} = true
}
pretoc '2:Application Log Files'
loop $ver (keys(%log))
{pretoc "3:'",$ver,"' Version"
 call sort_files(4,0,keys($log{$ver}))
 unpretoc
}
unpretoc 2

=head1 SEE ALSO

L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
