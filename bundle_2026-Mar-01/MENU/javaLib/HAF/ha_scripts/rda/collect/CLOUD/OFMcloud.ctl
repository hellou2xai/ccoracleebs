# OFMcloud.ctl: Collects Oracle Fusion Middleware Plug-in Information
# $Id: OFMcloud.ctl,v 1.1 RDA Exp $
# ARCS: $Header: /RDA_8/src/scripting/lib/collect/CLOUD/OFMcloud.ctl,v 1.1 RDA Exp $
#
# Change History
# 20181128  PCW  Initial version.

=head1 NAME

CLOUD:OFMcloud - Collects Oracle Fusion Middleware Plug-in Information

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
  WLS => {srvlog => {CLOUD_MCS => 'CLOUD:OFMcloud-WLS_MCS_Log'}}}
loop $key (keys($ctl,'*'))
 var $plg->{@{$key}} = $ctl->{@{$key}}

# -----------------------------------------------------------------------------
# Section WLS_MCS_Log: Collect MCS log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_MCS_Log

=head2 MCS Local Log Files

Collects the Mobile Cloud Service-related local log files for Oracle
WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMcloud module, gathering MCS log files'
pretoc '3:MCS Local Log Files'
var $max = ${GRP.WREQ.N_ROTATED_LOGS:2}
var @tbl = ()

# Get the rotating logs
loop $pat ('^api-history-?\d*\.log$','^ccc-agent-status-?\d*\.log$',\
           '^connector-outbound-history-?\d*\.log$',\
           '^mobile-cloud-exception-?\d*\.log$',\
           '^tooling-api-history-?\d*\.log$')
{var $cnt = $max
 loop $nam (grepDir(catDir($dir,'logs'),$pat,'t'))
 {call push(@tbl,catFile($dir,'logs',$nam))
  if match($nam,concat('(^api-history\.log$|^ccc-agent-status\.log$|',\
                       '^connector-outbound-history\.log$|',\
                       '^mobile-cloud-exception\.log$|',\
                       '^tooling-api-history\.log$)'))
  {break !$cnt
   next
  }
  break !decr($cnt)
 }
}
call sort_files(4,0,@tbl)
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
