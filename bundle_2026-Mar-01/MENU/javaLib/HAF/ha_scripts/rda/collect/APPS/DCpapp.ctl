# DCpapp.ctl:728:Collects PeopleSoft Information from Tuxedo Application Server
# $Id: DCpapp.ctl,v 1.8 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/DCpapp.ctl,v 1.7 2015/08/21 15:33:37 RDA Exp $
#
# Change History
# 20171207  DXM  Collect tail rather than full log file.
# 20150821  MSC  Improve time consistency.

=head1 NAME

APPS:DCpapp - Collects PeopleSoft Information from Tuxedo Application Server

=head1 DESCRIPTION

This module collects PeopleSoft diagnostic information from Tuxedo Application
Server.

The following reports can be generated and are regrouped under
C<PeopleSoft/Application Server>:

=cut

echo tput('bold'),'Processing APPS.PAPP module ...',tput('off')

# Initialization
var $AGE       = ${GRP.PSFT.R_AGE/T:1}
var $TAIL      = ${GRP.PSFT.N_TAIL:1000}
var $PAPP_CFG  = ${GRP.PSFT.D_CFG_HOME:${ENV.PS_CFG_HOME:''}}
var $PAPP_HOME = ${GRP.PSFT.D_HOME:${ENV.PS_HOME:''}}
var $TUX_HOME  = ${D_TUX_HOME:${ENV.TUXDIR:''}}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

# Initialize the table of content
pretoc '^1:PeopleSoft'
pretoc '1+:Application Server'

# Load the common macros
run RDA:library()

# Set the PAPP symbols
call setSymbol('$PS_HOME',$PAPP_HOME)
call setSymbol('$TUXDIR',$TUX_HOME)
if length($PAPP_CFG)
 call setSymbol('$PS_CFG_HOME',$PAPP_CFG)
else
 var $PAPP_CFG = $PAPP_HOME

=head2 Application Server

Gathers PeopleSoft application server executable list.

=cut

debug ' Inside PAPP module, listing application server executables'
report appserv
var $dir = catDir($PAPP_HOME,'appserv')
prefix
 write '---+ List of Files in ',encode($dir)
call statDir('an',$dir)
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Executable List]]'

=head2 Patch Information

Gathers PeopleSoft application server patch level information.

=cut

debug ' Inside PAPP module, getting patchlev information'
pretoc '2:Patch Information'
call sort_files(3,0,catFile($TUX_HOME,'udataobj','patchlev'))
unpretoc

=head1 FOR TUXEDO APPLICATION SERVER

Collects PeopleSoft information from Tuxedo Application Server domains. It
looks for all domains containing a file F<psappsrv.cfg>. For each of them, it
collects the related configuration and log files.

=cut

debug ' Inside PAPP module, getting configuration and log files'
pretoc '2:Generic'
call sort_files(3,0,catFile($PAPP_HOME,'peopletools.properties'))
unpretoc

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
 unpretoc 3
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
