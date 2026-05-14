# DCasap.ctl:484:Collects Automated Service Activation Program Information
# $Id: DCasap.ctl,v 1.9 2015/08/21 16:15:16 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCasap.ctl,v 1.9 2015/08/21 16:15:16 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

CGBU:DCasap - Collect Automated Service Activation Program Software Information

=head1 DESCRIPTION

This module collects Oracle Communications Automated Service Activation Program
(ASAP)-related information.

The following reports can be generated and are regrouped under C<ASAP>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.ASAP module ...',tput('off')

# Initialization
var $ASAP_DOMAIN = ${D_DOMAIN:''}
var $ASAP_HOME   = ${D_HOME:''}
var $ASAP_LIMIT  = ${N_LIMIT:5000}
var $ASAP_SHELL  = ${F_SHELL}
var $ASAP_VOLUME = ${N_VOLUME:25}
var $TAIL        = ${N_TAIL:5000}

var $TOC  = '%TOC%'
var $TOC2 = '%TOC2%'
var $TOP  = '[[#Top][Back to top]]'
toc '1:ASAP'

macro asap_separator
{var $cur = $arg[0]
 import $TOC,$TOP,$TTL,@DBG,@HDR,@TTL,@TXT
 keep $cur,$sep,$TOC,$TOP,$TTL,@DBG,@HDR,@TTL,@TXT
 if $cur
 {if hasOutput(true)
  {write '</verbatim>'
   write $TOP
  }
  var $sep = $cur
  if ?$DBG[$sep]
   debug last
  prefix
  {if !isCreated()
   {write $TTL
    write $TOC
   }
   if ?$TTL[$sep]
    write last
   if ?$TXT[$sep]
    write last,'%BR%&nbsp;'
   if ?$HDR[$sep]
    write last
   write '<verbatim>'
  }
  return 1
 }
 if getSqlMessage()
  write last,'%BR%'
 if hasOutput(true)
 {write '</verbatim>'
  write $TOP
 }
 if isCreated()
  toc nvl($arg[2],2),':[[',getFile(),'][rda_report][',$arg[1],']]'
}

# Define the directory analysis macro
macro stat_tree
{var ($dir) = @arg
 import $TOP

 prefix
 {
 }
 call statDir('n',$dir)
 if hasOutput(true)
  write $TOP

 loop $pth (findDir($dir,'^\.+$','npv'))
 {next ?testFile('l',$pth)
  call stat_tree($pth)
 }
}

# Source the profile
call sourceContext(catCommand($ASAP_HOME,'Environment_Profile'),$ASAP_SHELL)
if !getEnv('ASAP_BASE')
{echo tput('bold'),'Application environment must be set up before running \
      this script, execute source $ASAP_HOME/Environment_Profile first',\
      tput('off')
 return
}

=head2 product_info - Product Information

Collects a variety of Oracle Communications Automated Service Activation
Program product information.

=cut

debug ' Inside ASAP module, getting product information'
report product_info
title '---+!! Application Information'
title $TOC

if ?testFile('f',catFile(getEnv('SCRIPTS'),'status'))
{prefix
 {write '---++ ASAP Applications Running'
  write '---### Using: ',encode(lastFile())
 }
 call writeCommand(lastTestCommand())
 if hasOutput(true)
  write $TOP
}

var $dir = getEnv('PROGRAMS')
if ?testFile('f',catFile($dir,'sarm'))
{var $cmd = concat(lastTestCommand(),' -i')
 prefix
 {write '---++ sarm'
  write '---### Using: ',encode($cmd)
 }
 call writeCommand($cmd)
 if hasOutput(true)
  write $TOP
}

if ?testFile('f',catFile($dir,'ctrl_svr'))
{var $cmd = concat(lastTestCommand(),' -i')
 prefix
 {write '---++ ctrl_svr'
  write '---### Using: ',encode($cmd)
 }
 call writeCommand($cmd)
 if hasOutput(true)
  write $TOP
}

if ?testFile('f',catFile($dir,'fork_agent'))
{var $cmd = concat(lastTestCommand(),' -i')
 prefix
 {write '---++ fork_agent'
  write '---### Using: ',encode($cmd)
 }
 call writeCommand($cmd)
 if hasOutput(true)
  write $TOP
}

if ?testFile('f',catFile($dir,'admn_svr'))
{var $cmd = concat(lastTestCommand(),' -i')
 prefix
 {write '---++ admn_svr'
  write '---### Using: ',encode($cmd)
 }
 call writeCommand($cmd)
 if hasOutput(true)
  write $TOP
}

if ?testFile('f',catFile($dir,'asc_nep'))
{var $cmd = concat(lastTestCommand(),' -i')
 prefix
 {write '---++ asc_nep'
  write '---### Using: ',encode($cmd)
 }
 call writeCommand($cmd)
 if hasOutput(true)
  write $TOP
}

if ?testFile('f',catFile($dir,'srp_emul'))
{var $cmd = concat(lastTestCommand(),' -i')
 prefix
 {write '---++ srp_emul'
  write '---### Using: ',encode($cmd)
 }
 call writeCommand($cmd)
 if hasOutput(true)
  write $TOP
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Product Information]]'

=head2 environment_profile - Environment Profile

Reports the environment profile.

=cut

debug ' Inside ASAP module, getting the environment profile'
report environment_profile
var $fil = catFile($ASAP_HOME,'Environment_Profile')
prefix
{write '---+ Oracle Communications ASAP Environment Profile'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Environment Profile]]'

=head2 properties - ASAP.Properties File

Reports Oracle Communications Automated Service Activation Program properties.

=cut

debug ' Inside ASAP module, getting property information'

report properties
var $fil = catFile($ASAP_HOME,'ASAP.properties')
prefix
{write '---+ Oracle Communications ASAP Properties File'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][ASAP.Properties File]]'

=head2 configs - Configuration Files

Collects Oracle Communications Automated Service Activation Program
configuration files.

=cut

debug ' Inside ASAP module, getting configuration information'
report configs
var $dir = getEnv('ASAP_CFG')
prefix
{write '---+!! Oracle Communications ASAP Configuration Files'
 write '---## Recursively Searched from ',encode($dir)
 write $TOC2
}
loop $fil (grepDir($dir,'^\.+$','drv'))
{if ?testFile('fT',$fil)
 {write '---'
  write '---+',encode($fil)
  call writeFile($fil)
  write $TOP
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Configuration Files]]'

=head2 misc_files - Miscellaneous Files

Collects miscellaneous Oracle Communications Automated Service Activation
Program files.

=cut

debug ' Inside ASAP module, getting miscellaneous files'
report misc_files
prefix
{write '---+!! Miscellaneous Oracle Communications ASAP Files'
 write $TOC2
}
var $dir = catDir(getEnv('ORBIX_BASE'),'config','Repositories','ImpRep')
loop $fil (catFile($ASAP_HOME,'.profile'),\
           catFile(getEnv('ASAP_CFG'),'ASAP.cfg'),\
           catFile(getEnv('PROGRAMS'),'JInterpreter'),\
           catFile(getEnv('SYBASE'),'interfaces'),\
           catFile(getEnv('ORACLE_HOME'),'network','admin','tnsnames.ora'),\
           grepDir($dir,'imp$','dr'))
{if ?testFile('fT',$fil)
 {write '---'
  write '---+',encode($fil)
  call writeFile($fil)
  write $TOP
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Miscellaneous Files]]'

=head2 core_file_analysis - Product Information

Analyzes core files.

=cut

debug ' Inside ASAP module, analyzing core files'
report core_file_analysis
prefix
{write '---+!! Core Files'
 write '---## Recursively Searched from ',encode($ASAP_HOME)
 write $TOC
}
loop $fil (grepDir($ASAP_HOME,'core','dr'))
{if ?testFile('fB',$fil)
 {write '---+',encode($fil)
  call writeCommand(concat('pstack ',quote($fil)))
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Core Files]]'

=head2 install_info - Installation Files

Collects Oracle Communications Automated Service Activation Program
installation files.

=cut

debug ' Inside ASAP module, getting installation files'
report install_info
var $dir = catDir($ASAP_HOME,'install')
prefix
{write '---+ Oracle Communications ASAP Installation Information'
 write '---## Recursively Searched from ',encode($dir)
 write $TOC2
}
loop $fil (grepDir($dir,'^\.+$','drv'))
{if ?testFile('fT',$fil)
 {write '---'
  write '---+',encode($fil)
  call writeFile($fil)
  write $TOP
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Installation Files]]'

=head2 log_files - Log Files

Collects Oracle Communications Automated Service Activation Program log files.

=cut

debug ' Inside ASAP module, getting log files'
report log_files
prefix
{write '---+!! Oracle Communications ASAP Log Files'
 write '---## Recursively from ',encode($ASAP_HOME)
 write $TOC2
}
loop $fil (grepDir($ASAP_HOME,'log$','dr'))
{if ?testFile('fT',$fil)
 {write '---+ ',encode($fil)
  write '---## (',getSize($fil),' bytes)'
  call writeTail($fil,$TAIL)
  write $TOP
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Log Files]]'

=head2 script_files - Script Files

Collects Oracle Communications Automated Service Activation Program script
files.

=cut

debug ' Inside ASAP module, getting script files'
report script_files
var $dir = catDir($ASAP_HOME,'scripts')
prefix
{write '---+!! Oracle Communications ASAP Script Files'
 write '---## Recursively from ',encode($dir)
 write $TOC2
}
loop $fil (grepDir($dir,'.*','dr'))
{if ?testFile('fT',$fil)
 {write '---+ ',encode($fil)
  write '---## (',getSize($fil),' bytes)'
  call writeFile($fil)
  write $TOP
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Script Files]]'

=head2 diag_files - Diagnostic Files

Collects Oracle Communications Automated Service Activation Program diagnostic
files.

=cut

debug ' Inside ASAP module, getting diagnostic files (can take time)'
report diag_files
var $dir = getEnv('LOGDIR')
prefix
{write '---+!! Oracle Communications ASAP Diagnostic Files'
 write '---## Recursively from ',encode($dir)
 write '   * File size lower than ',$ASAP_VOLUME,' MB'
 write '   * Links point to files that have been collected in their original \
             format. Opening them directly in your browser can present risks. \
             To prevent them, access the file outside the browser or use \
             the link to save them and use an adequate viewer.'
 write '%BR%'
 write '|*File Name*| *Size*|*Last Modification*|'
}
var $max = expr('*',1000000,$ASAP_VOLUME)
loop $fil (grepDir($dir,'diag','tr'))
{next !?testFile('fT',$fil)
 var $lnk = encode($fil)
 decr $max,getSize($fil)
 if expr('>',$max,0)
 {output d,concat('diag_',basename($fil))
  if ${CUR.O_LAST}->write_data($fil)
   var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,']]')
  end ${CUR.O_LAST}
 }
 write '|',$lnk,' | ',getSize($fil),'|',getLastModify($fil,'<UTC>'),' |'
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Diagnostic Files]]'

=head2 object_files - Object Information

Lists Oracle Communications Automated Service Activation Program object files.

=cut

debug ' Inside ASAP module, listing object information'
report object_files
var $objectDir = getEnv('OBJECT_DIRS')
var $dir = catDir($ASAP_HOME,'objects')
prefix
{write '---+ Oracle Communications ASAP Object Information'
 write '---## Recursively Searched from ',encode($objectDir)
}
loop $fil (grepDir($objectDir,'^\.+$','drv'))
 write $fil,'%BR%'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Object Information]]'

=head2 all_directories - ASAP Directory Listing

Lists the content of the Oracle Communications Automated Service Activation
Program directory structure.

=cut

debug ' Inside ASAP module, listing ASAP directory structure'
report asap_directories
title '---+ Oracle Communications ASAP Directory Structure Content'
title '---## Recursively Searched from ',encode($ASAP_HOME)
call stat_tree($ASAP_HOME)
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][ASAP Directory Listing]]'

=head2 domain_directories - Domain Directory Listing

Lists the content of the domain.

=cut

debug ' Inside ASAP module, listing Domain directory structure'
report domain_directory_listig
title '---+ Adminserver Domain Listing'
title '---## Recursively Searched from ',encode($ASAP_DOMAIN)
call stat_tree($ASAP_DOMAIN)
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Domain Directory Listing]]'

=head2 domain_logs - Domain Log Files

Collects domain log files.

=cut

debug ' Inside ASAP module, getting domain log files'
report domain_logs
title '---+!! Domain Log Files (',$ASAP_LIMIT,' lines of each type)'
title '---## From ',$ASAP_DOMAIN
title $TOC

loop $fil (grepDir($ASAP_DOMAIN,'log$','np'))
{prefix
 {if isCreated()
   write '---'
  write '---+',encode($fil)
 }
 call writeTail($fil,$ASAP_LIMIT)
 if hasOutput(true)
  write $TOP
}

loop $dir (grepDir($ASAP_DOMAIN,'logs','dr'))
{loop $log (grepDir($dir,'log$','dr'))
 {var $max = $ASAP_LIMIT
  loop $fil (grepDir(dirname($log),concat('^',verbatim(basename($log))),'tr'))
  {break expr('<=',$max,0)
   prefix
   {if isCreated()
     write '---'
    write '---+',encode($fil)
   }
   call writeTail($fil,$max)
   decr $max,getWriteLength()
   if hasOutput(true)
    write $TOP
  }
 }
}
if isCreated()
 toc '2:[[',getFile(),'][rda_report][Domain Log Files]]'

=head2 control_db - Control Database Tables

Lists the contents of several important control database tables.

=cut

debug ' Inside ASAP module, getting control database tables'
report control_tables

call setSqlTarget(${I_CTRL_DB})
if !testSql()
{var $TTL = '---+!! Control Database'
 var @TTL = ('',\
             '---+ TBL_SYSTEM_ALARM',\
             '---+ TBL_APPL_PROC',\
             '---+ TBL_CLASSA_SECU',\
             '---+ TBL_CLASSB_SECU',\
             '---+ TBL_CODE_LIST',\
             '---+ TBL_COMPONENT',\
             '---+ TBL_LISTENERS',\
             '---+ TBL_PROCESS_INFO',\
             '---+ TBL_SERVER_INFO')
 set $sql
 {SELECT *
 " FROM tbl_system_alarm
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(2)___
 "SELECT *
 " FROM tbl_appl_proc
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(3)___
 "SELECT *
 " FROM tbl_classa_secu
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(4)___
 "SELECT *
 " FROM tbl_classb_secu
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(5)___
 "SELECT *
 " FROM tbl_code_list
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(6)___
 "SELECT *
 " FROM tbl_component
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(7)___
 "SELECT *
 " FROM tbl_listeners
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(8)___
 "SELECT *
 " FROM tbl_process_info
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(9)___
 "SELECT *
 " FROM tbl_server_info
 " WHERE ROWNUM < 500;
 }
 call asap_separator(1)
 call writeSql($sql)
 call asap_separator(0,'Control Database Tables')
}

=for stopwords Sarm

=head2 sarm_db - Sarm Database Tables

Lists the contents of several important Sarm database tables.

=cut

debug ' Inside ASAP module, getting Sarm database information'
report sarm_db

call setSqlTarget(${I_SARM_DB})
if !testSql()
{var $TTL = '---+!! Sarm Database'
 var @TTL = ('',\
             '---+ TBL_ASAP_SRP',\
             '---+ TBL_CLLI_ROUTE',\
             '---+ TBL_COMM_PARAM',\
             '---+ TBL_HOST_CLLI',\
             '---+ TBL_ID_ROUTING',\
             '---+ TBL_NEP',\
             '---+ TBL_NEP_ADSL_PROG',\
             '---+ TBL_NE_CONFIG',\
             '---+ TBL_RESOURCE_POOL')
 set $sql
 {SELECT *
 " FROM tbl_asap_srp
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(2)___
 "SELECT *
 " FROM tbl_clli_route
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(3)___
 "SELECT *
 " FROM tbl_comm_param
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(4)___
 "SELECT *
 " FROM tbl_host_clli
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(5)___
 "SELECT *
 " FROM tbl_id_routing
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(6)___
 "SELECT *
 " FROM tbl_nep
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(7)___
 "SELECT *
 " FROM tbl_nep_adsl_prog
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(8)___
 "SELECT *
 " FROM tbl_ne_config
 " WHERE ROWNUM < 500;
 "PROMPT ___Macro_asap_separator(9)___
 "SELECT *
 " FROM tbl_resource_pool
 " WHERE ROWNUM < 500;
 }
 call asap_separator(1)
 call writeSql($sql)
 call asap_separator(0,'Sarm Database Tables')
}

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
