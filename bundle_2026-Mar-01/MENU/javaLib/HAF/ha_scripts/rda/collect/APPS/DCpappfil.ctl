# DCpappfil.ctl:728:Collects specified PeopleSoft files from Tuxedo Application Server
# $Id: DCpappfil.ctl,v 1.2 RDA Exp $
# ARCS: $Header: /RDA_8/src/scripting/lib/collect/APPS/DCpappfil.ctl,v 1.1 RDA Exp $
#
# Change History
# 20180502  SJC  Correct ARCS and Id lines.
# 20180102  DXM  Initial creation.

=head1 NAME

APPS:DCpappfil - Collects specified PeopleSoft files from Tuxedo Application Server

=head1 DESCRIPTION

This module collects specified PeopleSoft files from Tuxedo Application Server

=cut

echo tput('bold'),'Processing APPS.PAPPFIL module ...',tput('off')

# Initialization
var $AGE       = ${GRP.PSFT.R_AGE/T:1}
var $TAIL      = ${GRP.PSFT.N_TAIL:1000}
var $PAPP_CFG_FIL  = ${T_CFG_FIL:${ENV.PAPP_CFG_FIL:''}}
var $PAPP_LOG_FIL  = ${T_LOG_FIL:${ENV.PAPP_LOG_FIL:''}}
var $PAPP_CFG  = ${GRP.PSFT.D_CFG_HOME:${ENV.PS_CFG_HOME:''}}
var $PAPP_HOME = ${GRP.PSFT.D_HOME:${ENV.PS_HOME:''}}
var $TUX_HOME  = ${D_TUX_HOME:${ENV.TUXDIR:''}}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

# Initialize the table of content
pretoc '^1:PeopleSoft - Application Server'
pretoc '1+:Specified Files'

# Load the common macros
run RDA:library()

# Create array of specified cfg files
if length($PAPP_CFG_FIL)
 @cfg_tbl = split(':',trim($PAPP_CFG_FIL))

if length($PAPP_LOG_FIL)
 @log_tbl = split(':',trim($PAPP_LOG_FIL))

# Set the PAPP symbols
call setSymbol('$PS_HOME',$PAPP_HOME)
call setSymbol('$TUXDIR',$TUX_HOME)
if length($PAPP_CFG)
 call setSymbol('$PS_CFG_HOME',$PAPP_CFG)
else
 var $PAPP_CFG = $PAPP_HOME

=head1 FOR TUXEDO APPLICATION SERVER

Collects PeopleSoft information from Tuxedo Application Server domains. It
looks for all domains containing a file F<psappsrv.cfg>. For each of them, it
collects the related configuration and log files.

=cut

# Identify the relevant domains
var @dom = ()
loop $dom (findDir(catDir($PAPP_CFG,'appserv'),'^\.+$','nv'))
{if ?testFile('f',catFile($PAPP_CFG,'appserv',$dom,'psappsrv.cfg'))
  call push(@dom,$dom)
}

# Get domain information
loop $dom (@dom)
{var $dir = catDir($PAPP_CFG,'appserv',$dom)
 pretoc '%SPLIT%'
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
  unpretoc 3
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
