# OFMapps.ctl: Collects Oracle Fusion Middleware Plug-in Information
# $Id: OFMapps.ctl,v 1.6 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/OFMapps.ctl,v 1.5 2015/05/29 05:41:22 RDA Exp $
#
# Change History
# 20181112  PCW  Add Server-level plugins for JDE E1 log and config files.
# 20150526  KRA  Improve the documentation.

=head1 NAME

APPS:OFMapps - Collects Oracle Fusion Middleware Plug-in Information

=head1 DESCRIPTION

This module collects Oracle Fusion Middleware Plug-in-related information.

=head1 REPORTS

=cut

keep $KEEP_BLOCK

return

# --- begin section -----------------------------------------------------------
section begin

# Load the common macros
run OFM:WLSlib()
run RDA:library()

# -----------------------------------------------------------------------------
# Section Init: Define the plugin capabilities
# -----------------------------------------------------------------------------

section Init

# Define the plugin capabilities
var $plg = $arg[0]
var $ctl = {\
  WLS => {domprd => {APPS_OFA => 'APPS:OFMapps-WLS_OFA_Config'},\
          srvlog => {APPS_JDE => 'APPS:OFMapps-WLS_JDE_Log',\
                     APPS_OFA => 'APPS:OFMapps-WLS_OFA_Log'},\
          srvprd => {APPS_JDE => 'APPS:OFMapps-WLS_JDE_SrvCfg_Config',\
                     APPS_OFA => 'APPS:OFMapps-WLS_OFA_SrvCfg_Config'}}}
loop $key (keys($ctl,'*'))
 var $plg->{@{$key}} = $ctl->{@{$key}}

# -----------------------------------------------------------------------------
# Section WLS_OFA_Config: Collect OFA config files from Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_OFA_Config

=head2 OFA Domain Configuration Files

Gathers domain-wide Oracle Fusion Applications-related Oracle WebLogic
Server configuration files.

=cut

var ($dir) = @arg

debug '   - Inside OFMapps module, gathering OFA domain configuration files'

# Macro to get the OFA-related configuration files
macro get_ofa_config
{var (\@tbl,$dir,$pat,$flg) = @arg

 # Analyze the directory
 loop $nam (grepDir($dir,'^\.+$','nv'))
 {next match($nam,$pat,true)
  var $pth = catFile($dir,$nam)
  if ?testDir('d',$pth)
   call push(@sub,$pth)
  elsif $flg
   next
  else
   call push(@tbl,$pth)
 }

 # Treat the subdirectories
 loop $sub (@sub)
  call get_ofa_config(\@tbl,$sub,'^servers$',false)
}

var @tbl = ()
call get_config(\@tbl,catDir($dir,'config'),\
  '^(backup|(deployments|fmwconfig|servers|bipublisher)$)',true)
call push(@tbl,\
  catFile($dir,'config','fmwconfig','jps-config-jse.xml'),\
  catFile($dir,'config','fmwconfig','jps-config.xml'),\
  catFile($dir,'config','fmwconfig','keystores.xml'),\
  catFile($dir,'config','fmwconfig','logging-template.xml'),\
  catFile($dir,'config','fmwconfig','opss-resource-types.xml'),\
  catFile($dir,'config','fmwconfig','policy-accessor-config.xml'),\
  catFile($dir,'config','fmwconfig','system-jazn-data.xml'),\
  catFile($dir,'config','fmwconfig','usermessagingconfig.xml'))
call get_ofa_config(\@tbl,catDir($dir,'config','fmwconfig'),\
  '^(arisidprovider|carml|jboss|ovd|servers|server-config-template)$',true)
pretoc '2:OFA Domain Configuration Files'
call sort_files(3,0,@tbl)
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_JDE_SrvCfg_Config: Collect JDE config files for Oracle WebLogic
#                                Server
# -----------------------------------------------------------------------------

section WLS_JDE_SrvCfg_Config

=head2 JDE Domain Server Configuration Files

Collects the JD Edwards-related configuration files for Oracle WebLogic Server.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMapps module, gathering JDE configuration files'
var $cfg = catDir($dir,'stage')
var @tbl = ()
loop $sub (findDir($cfg,'^classes$','npr'))
 call push(@tbl,grepDir($sub,'(^\.|\.properties$|\.xml$)','npv'))
pretoc '2:JDE Domain Server Configuration Files'
call sort_files(3,0,@tbl)
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_OFA_SrvCfg_Config: Collect OFA config files for Oracle WebLogic
#                                Server
# -----------------------------------------------------------------------------

section WLS_OFA_SrvCfg_Config

=head2 OFA Domain Server Configuration Files

Collects the Oracle Fusion Applications-related configuration files for Oracle
WebLogic Server.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMapps module, gathering OFA configuration files'
var $cfg = catDir($top,'config','fmwconfig','servers',$srv)
pretoc '2:OFA Domain Server Configuration Files'
call sort_files(3,0,\
  grepDir($cfg,'backup','npv'),\
  grepDir(catDir($cfg,'applications'),'^oracle-webservices.xml$','dr'),\
  catFile($cfg,'applications','ESSAPP','config','ess.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_JDE_Log: Collect JDE log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_JDE_Log

=head2 JDE Local Log Files

Collects the JD Edwards e1root*.log file(s) pointed to by the FILE tag in
any C<jdelog.properties> file(s) for the current WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMapps module, gathering JDE e1root.log files'
var @tbl = ()
loop $sub (findDir($dir,'^classes$','npr'))
{if ?testFile('f',catFile($sub,'jdelog.properties'))
 {loop $lin (grepFile(last,'^FILE='))
  {var $fil = substr($lin,5)
   var $dir = dirname($fil)
   call push(@tbl,grepDir($dir,'^e1root.*\.log$','np'))
  }
 }
}
pretoc '3:JDE Local Log Files'
call sort_files(4,$lim,@tbl)
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_OFA_Log: Collect OFA log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_OFA_Log

=head2 OFA Local Log Files

Collects the Oracle Fusion Applications-related local log files for Oracle
WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMapps module, gathering OFA log files'
pretoc '3:OFA Local Log Files'
call sort_files(4,$lim,grepDir(catDir($dir,'logs','apps'),'^[^\.]','p'))
unpretoc

=head1 SEE ALSO

L<OFM:WLSlib|collect::OFM:WLSlib>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
