# DCpsch.ctl:729:Collects PeopleSoft Information from Process Scheduler
# $Id: DCpsch.ctl,v 1.8 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/DCpsch.ctl,v 1.7 2015/08/21 15:33:37 RDA Exp $
#
# Change History
# 20171207  DXM  Collect tail rather than full log file.
# 20150821  MSC  Improve time consistency.

=head1 NAME

APPS:DCpsch - Collects PeopleSoft Information from Process Scheduler

=head1 DESCRIPTION

This module collects PeopleSoft diagnostic information from process scheduler.

The following reports can be generated and are regrouped under
C<PeopleSoft/Process Scheduler>:

=cut

echo tput('bold'),'Processing APPS.PSCH module ...',tput('off')

# Initialization
var $AGE       = ${GRP.PSFT.R_AGE/T:1}
var $TAIL      = ${GRP.PSFT.N_TAIL:1000}
var $PSCH_CFG  = ${GRP.PSFT.D_CFG_HOME:${ENV.PS_CFG_HOME:''}}
var $PSCH_HOME = ${GRP.PSFT.D_HOME:${ENV.PS_HOME:''}}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

# Initialize the table of content
pretoc '^1:PeopleSoft'
pretoc '1+:Process Scheduler'

# Load the common macros
run RDA:library()

# Set the PSCH symbols
call setSymbol('$PS_HOME',$PSCH_HOME)
if length($PSCH_CFG)
 call setSymbol('$PS_CFG_HOME',$PSCH_CFG)
else
 var $PSCH_CFG = $PSCH_HOME

=head1 FOR PROCESS SCHEDULER

Collects PeopleSoft information from process scheduler domains. It looks for
all domains containing a file F<psprcs.cfg>. For each of them, it collects the
related configuration and log files.

=cut

debug ' Inside PSCH module, getting configuration and log files'

# Identify the relevant domains
var @dom = ()
loop $dom (findDir(catDir($PSCH_CFG,'appserv','prcs'),'^\.+$','nv'))
{if ?testFile('f',catFile($PSCH_CFG,'appserv','prcs',$dom,'psprcs.cfg'))
  call push(@dom,$dom)
}

# Get domain information
loop $dom (@dom)
{var $dir = catDir($PSCH_CFG,'appserv','prcs',$dom)
 pretoc "1++:'",$dom,"' Domain"

 # Collect configuration files
 pretoc '2:Configuration Files'
 call sort_files(3,0,grepDir($dir,'ps.*','p'))
 unpretoc

 # Collect std.* files
 pretoc '2:Std Out and Err'
 call sort_files(3,$TAIL,grepDir($dir,'std.*',concat('npm',$AGE)),\
                   grepDir(catDir($dir,'LOGS'),'std.*',\
                   concat('npm',$AGE)))
 unpretoc

 # Collect log files
 report concat('d_',$dom,'_log')
 prefix
 {write '---+ Collected Files'
  write '   * Limited to last ',$AGE,' days modified and last ',$TAIL,' lines'
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              security risks. To prevent them, access the file outside the \
              browser or use the link to save them and use an adequate viewer.'
  write '|*File Name*| *Original Size*| *Tailed Size*|*Last Modification*|'
 }
 # For size of tailed file, we minus off the verbatim tag characters which RDA adds
 loop $pth (grepDir(catDir($dir,'LOGS'),'^\.+$',concat('npvm',$AGE)))
 {next !?testDir('f',$pth)
  output d,concat('d_',$dom,'_l_',$fil = basename($pth))
  if ${CUR.O_LAST}->write_tail($pth,$TAIL)
   write '|[[',${CUR.O_LAST}->get_raw(true),'][_blank][',encode($fil),']]| ',getSize($pth),\
         '| ',expr('-',getSize(${CUR.O_LAST}->get_file()),'23'),'|',getLastModify($pth,'<UTC>'),' |'
  end ${CUR.O_LAST}
 }
 if hasOutput(true)
 {write $TOP
  toc '2:[[',getFile(),'][rda_report][Log Files]]'
 }
 unpretoc
 pretoc '%SPLIT%'
}

# Disable the group title in next index
if isTocCreated(true)
 toc '-:PeopleSoft'

=head1 SEE ALSO

L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
