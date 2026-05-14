# DCjdes.ctl:539:Collects JD Edwards EnterpriseOne Enterprise Server Information
# $Id: DCjdes.ctl,v 1.1 RDA Exp $
# ARCS: $Header: /RDA_8/src/scripting/lib/collect/APPS/DCjdes.ctl,v 1.1 RDA Exp $
#
# Change History
# 20190104  PCW  Initial version.

=head1 NAME

APPS:DCjdes - Collects JD Edwards Enterprise Server Diagnostic Information

=head1 DESCRIPTION

This module collects JD Edwards Enterprise Server diagnostic information.

The following reports can be generated and are regrouped under
C<JD Edwards Enterprise Server>:

=cut

echo tput('bold'),'Processing APPS.JDES module ...',tput('off')

# Initialization
var $AGENT_HOME = ${D_AGENT_HOME}
var $INSTALL_PATH = ${D_INSTALL_PATH}
var $TAIL = ${DFT.N_TAIL:1000}
if or(isWindows(),isCygwin())
 var $ini = catFile($INSTALL_PATH,'system','bin32','JDE.INI')
else
 var $ini = catFile($INSTALL_PATH,'ini','JDE.INI')
var $prp = catFile($INSTALL_PATH,'system','classes','jdelog.properties')
pretoc '1:JD Edwards Enterprise Server'

# Set the symbols
call setSymbol('$AGENT_HOME',$AGENT_HOME)
call setSymbol('$INSTALL_PATH',$INSTALL_PATH)

# Load the common macros
run RDA:library()

=head1 JD EDWARDS ENTERPRISE SERVER INFORMATION

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the JD Edwards collection.

=cut

debug ' Inside JDES module, collecting defined abbreviations'
report abbr
prefix
{write '---+ JD Edwards Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 Enterprise Server Configuration Files

Gathers Enterprise Server configuration files.

=cut

debug ' Inside JDES module, getting Enterprise Server config files'
pretoc '2:JDE Enterprise Server Configuration Files'
call sort_files(3,0,$ini,$prp)
unpretoc

=head2 Enterprise Server Log Files

Gathers Enterprise Server log files.

=cut

debug ' Inside JDES module, getting Enterprise Server log files'
var @tbl = ()
call loadFile($ini)
loop $lin (getLines())
{if match($lin,'^JobFile')
  var $lg1 = dirname(substr($lin,8))
 if match($lin,'^DebugFile')
  var $lg2 = dirname(substr($lin,10))
}
call loadFile($prp)
loop $lin (getLines())
{if match($lin,'^FILE.*debug\.log$')
  var $lg3 = dirname(substr($lin,5))
 if match($lin,'^FILE.*jas\.log$')
  var $lg4 = dirname(substr($lin,5))
 if match($lin,'^FILE.*jderoot\.log$')
  var $lg5 = dirname(substr($lin,5))
}
call push(@tbl,grepDir($lg1,'^jde_.*\.log$','np'))
call push(@tbl,grepDir($lg2,'^jdedebug_.*\.log$','np'))
call push(@tbl,grepDir($lg3,'^debug_.*\.log$','np'))
call push(@tbl,grepDir($lg4,'^jas_.*\.log$','np'))
call push(@tbl,grepDir($lg5,'^jderoot_.*\.log$','np'))
call push(@tbl,\
  grepDir(catDir($INSTALL_PATH,'system','bin32'),'^ptf\.(log|txt)$','np'))
pretoc '2:JDE Enterprise Server Log Files'
call sort_files(3,$TAIL,@tbl)
unpretoc

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
