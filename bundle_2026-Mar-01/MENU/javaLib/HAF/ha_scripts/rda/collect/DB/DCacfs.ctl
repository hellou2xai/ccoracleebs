# DCacfs.ctl:403:Collects ASM Cluster File System Information
# $Id: DCacfs.ctl,v 1.6 2013/11/20 11:30:47 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/DB/DCacfs.ctl,v 1.6 2013/11/20 11:30:47 RDA Exp $
#
# Change History
# 20131119  KRA  Extend collections.

=head1 NAME

DB:DCacfs - Collects ASM Cluster File System Information

=head1 DESCRIPTION

This module collects ASM Cluster File System-related information.

The following reports can be generated and are regrouped under C<ASM Cluster
File System>:

=cut

echo tput('bold'),'Processing DB.ACFS module ...',tput('off')

# Initialisation
var $AGE         = ${R_AGE/T:15}
var $ORACLE_HOME = ${GRP.ASM.D_ORACLE_HOME:''}
var $ORACLE_SID  = ${GRP.ASM.T_ORACLE_SID:'+ASM'}
var $TAIL        = ${N_TAIL:1000}

var $MOD = cond(isUnix(),'fx','f')
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:ASM Cluster File System'

# Load the common macros
run RDA:library()

# Auto detect the ASM_ORACLE_HOME in a cluster
if compare('eq',$ORACLE_SID,'*')
 run DB:ASMinit(\$ORACLE_HOME,\$ORACLE_SID)

=for stopwords acfsutil

=head2 acfsutil - acfsutil Output

Collects F<acfsutil> command output.

=cut

if !isUnix()
 var $cmd = findCommand('acfsutil')
elsif ?testFile($MOD,catFile('/sbin','acfsutil'))
 var $cmd = lastCommand()
else
 var $cmd = undef
if ?$cmd
{debug ' Inside ACFS module, gathering acfsutil information'
 report acfsutil
 var $cmd = concat($cmd,' info fs 2>/dev/null')
 prefix
 {write '---+!! acfsutil Command Output'
  write '---## Using: ',encode($cmd)
 }
 call writeCommand($cmd)
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][acfsutil Output]]'
}

=for stopwords crsctl

=head2 crsctl - crsctl Output

Collects F<crsctl> command output.

=cut

if ?testFile($MOD,catFile($ORACLE_HOME,'bin',${AS.EXE:'crsctl'}))
{debug ' Inside ACFS module, gathering crsctl information'
 report crsctl
 title '---+!! crsctl Command Output'
 title $TOC
 var $pgm = lastCommand()
 loop $arg (' stat res',' stat res -init',' stat res -p',' stat res -p -init',\
            ' stat res -t -init',' stat res -dependency')
 {prefix
   write '---+ ',encode($cmd)
  var $cmd = concat($pgm,$arg)
  call writeCommand($cmd)
  if hasOutput(true)
   write $TOP
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][crsctl Output]]'
}

=for stopwords modinfo

=head2 modinfo - Module Information

For Linux, it reports ACFS, ADVM, and OKS module information.

=cut

if ${OS.linux}
{debug ' Inside ACFS module, gathering modinfo information'
 report modinfo
 title '---+!! Module Information'
 title $TOC
 loop $lin (grepFile('/proc/modules','^(oracle)?(acfs|advm|oks)\s','i'))
 {var $mod = field('\s',0,$lin)
  prefix
   write '---+ Module ',uc($mod)
  call writeCommand(concat('/sbin/modinfo ',quote($mod),' 2>&1'))
  if hasOutput(true)
   write $TOP
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Module Information]]'
}

=head2 OKS Log Files

Collects Oracle Kernel Service (OKS) log files.

=cut

pretoc '2:OKS Log Files'
debug ' Inside ACFS module, gathering log files'
if isUnix()
 call sort_files(3,$TAIL,'/proc/oks/log',\
                 grepDir('/var/log','^[FV]oks\.log\.\d+$',concat('ipm',$AGE)))
elsif or(isWindows(),isCygwin())
{if getEnv('SYSTEMROOT')
  var $sys = last
 else
  var ($sys) = command('echo %SystemRoot%')
 call sort_files(3,$TAIL,\
   grepDir(catDir($sys,'system32','drivers','acfs'),'okslog',\
           concat('ipm',$AGE)))
}

=head1 SEE ALSO

L<DB:ASMinit|collect::DB:ASMinit>,
L<DB:CRSinit|collect::DB:CRSinit>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
