# OFMcgbu.ctl: Collects Oracle Fusion Middleware Plug-in Information
# $Id: OFMcgbu.ctl,v 1.9 2015/05/29 05:36:53 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/OFMcgbu.ctl,v 1.9 2015/05/29 05:36:53 RDA Exp $
#
# Change History
# 20150526  KRA  Improve the documentation.

=head1 NAME

CGBU:OFMcgbu - Collects Oracle Fusion Middleware Plug-in Information

=head1 DESCRIPTION

This module collects Oracle Fusion Middleware Plug-in-related information.

=head1 REPORTS

=cut

keep $KEEP_BLOCK

return

# --- begin section -----------------------------------------------------------
section begin

# Load the common macros
run RDA:library()

# -----------------------------------------------------------------------------
# Section Init: Define the plugin capabilities
# -----------------------------------------------------------------------------

section Init

# Define the plugin capabilities
var $plg = $arg[0]
var $ctl = {\
  WLS => {srvlog => {CGBU_OCCAS => 'CGBU:OFMcgbu-WLS_OCCAS_Log',\
                     CGBU_OCSG  => 'CGBU:OFMcgbu-WLS_OCSG_Log',\
                     CGBU_PDC   => 'CGBU:OFMcgbu-WLS_PDC_Log'}}}
loop $key (keys($ctl,'*'))
 var $plg->{@{$key}} = $ctl->{@{$key}}

# -----------------------------------------------------------------------------
# Section WLS_OCCAS_Log: Collect OCCAS log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_OCCAS_Log

=head2 OCCAS Local Log Files

Collects the Oracle Communications Converged Application Server-related local
log files for Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMcgbu module, gathering OCCAS log files'
pretoc '3:OCCAS Local Log Files'
call sort_files(4,${SET.CGBU.OCCAS.N_TAIL:$lim},\
  grepDir(catDir($dir,'logs'),'\.(std)?out$','inp'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_OCSG_Log: Collect OCSG log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_OCSG_Log

=head2 OCSG Local Log Files

Collects the Oracle Communications Service Gatekeeper-related local log files
for Oracle WebLogic Server.

=head3 Java Flight Recorder Files

Collects the Oracle Communications Service Gatekeeper-related Java flight
recorder files.

=cut

var ($dir,$lim) = @arg
import $FCP,%FCP,%LOG

debug '   - Inside OFMofm module, gathering OCSG log files'
var ($max,@tbl) = (${SET.OFM.WREQ.N_ROTATED_LOGS:2})
var $cnt = $max
loop $nam (grepDir(catDir($dir,'trace'),'\.log\.?\d*$','it'))
{call push(@tbl,$fil = catFile($dir,'trace',$nam))
 var $FCP{$fil} = $FCP
 var $LOG{$fil} = 0
 if match($nam,'\.log$',true)
 {break !$cnt
  next
 }
 break !decr($cnt)
}
loop $fil (grepDir(catDir($dir,'data','ldap','log'),'^\.+$','pv'))
{call push(@tbl,$fil)
 var $FCP{$fil} = $FCP
}

pretoc '3:OCSG Local Log Files'
call sort_files(4,$lim,@tbl)

# Collect Java flight recorder files
pretoc '4:Java Flight Recorder Files'
call sort_all_files(5,0,\
  grepDir(catDir($dir,'logs','diagnostic_images'),'\.jfr$','np'))
unpretoc 2

# -----------------------------------------------------------------------------
# Section WLS_PDC_Log: Collect PDC log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_PDC_Log

=head2 PDC Local Log Files

Collects the Pricing Design Center-related local log files for Oracle
WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMcgbu module, gathering PDC log files'
pretoc '3:PDC Local Log Files'
call sort_files(4,$lim,\
  grepDir(catDir($dir,'logs'),'^PricingAppServer\d*\.log\.\d+$','inp'))
unpretoc

=head1 SEE ALSO

L<OFM:WASlib|collect::OFM:WASlib>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
