# DCpschfil.ctl:729:Collects specified PeopleSoft files from Process Scheduler
# $Id: DCpschfil.ctl,v 1.1 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/DCpschfil.ctl,v 1.1 RDA Exp $
#
# Change History
# 20180102  DXM  Initial creation

=head1 NAME

APPS:DCpschfil - Collects specified PeopleSoft files from Process Scheduler

=head1 DESCRIPTION

This module specified PeopleSoft files from Process Scheduler

=cut

echo tput('bold'),'Processing APPS.PSCHFIL module ...',tput('off')

# Initialization
var $AGE       = ${GRP.PSFT.R_AGE/T:1}
var $TAIL      = ${GRP.PSFT.N_TAIL:1000}
var $PSCH_CFG_FIL  = ${T_CFG_FIL:${ENV.PSCH_CFG_FIL:''}}
var $PSCH_LOG_FIL  = ${T_LOG_FIL:${ENV.PSCH_LOG_FIL:''}}
var $PSCH_CFG  = ${GRP.PSFT.D_CFG_HOME:${ENV.PS_CFG_HOME:''}}
var $PSCH_HOME = ${GRP.PSFT.D_HOME:${ENV.PS_HOME:''}}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

# Initialize the table of content
pretoc '^1:PeopleSoft - Process Scheduler'
pretoc '1+:Specified Files'

# Load the common macros
run RDA:library()

# Create array of specified cfg files
if length($PSCH_CFG_FIL)
 @cfg_tbl = split(':',trim($PSCH_CFG_FIL))

if length($PSCH_LOG_FIL)
 @log_tbl = split(':',trim($PSCH_LOG_FIL))

# Set the PSCH symbols
call setSymbol('$PS_HOME',$PSCH_HOME)
if length($PSCH_CFG)
 call setSymbol('$PS_CFG_HOME',$PSCH_CFG)
else
 var $PSCH_CFG = $PSCH_HOME

=head1 FOR PROCESS SCHEDULER

Collects PeopleSoft information from process scheduler domains. It looks for
all domains containing a file F<psprcs.cfg>. For each of them, it collects the
specified configuration and log files.

=cut

debug ' Inside PSCHFIL module, getting configuration and log files'

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
 if @cfg_tbl
 {pretoc '2:Configuration Files'
  loop $fil (@cfg_tbl)
  {call sort_files(3,0,grepDir($dir,$fil,'p'))
  }
 }
 unpretoc

 # Collect log files
 if @log_tbl
 {report concat('d_',$dom,'_log')
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
  loop $logfil (@log_tbl)
  {loop $pth (grepDir(catDir($dir,'LOGS'),$logfil,concat('npm',$AGE)))
   {next !?testDir('f',$pth)
    output d,concat('d_',$dom,'_l_',$fil = basename($pth))
    if ${CUR.O_LAST}->write_tail($pth,$TAIL)
     write '|[[',${CUR.O_LAST}->get_raw(true),'][_blank][',encode($fil),']]| ',getSize($pth),\
          '| ',expr('-',getSize(${CUR.O_LAST}->get_file()),'23'),'|',getLastModify($pth,'<UTC>'),' |'
    end ${CUR.O_LAST}
   }
  }
  if hasOutput(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][Log Files]]'
  }
  unpretoc
  pretoc '%SPLIT%'
 }
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