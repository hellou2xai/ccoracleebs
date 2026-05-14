# DCnm.ctl:480:Collects Oracle Communications Network Mediation Information
# $Id: DCnm.ctl,v 1.3 2013/10/30 07:18:23 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCnm.ctl,v 1.3 2013/10/30 07:18:23 RDA Exp $
#
# Change History
# 20130422  MSC  Improve the validation.

=head1 NAME

CGBU:DCnm - Collect Oracle Communications Network Mediation Software Information

=head1 DESCRIPTION

This module collects Oracle Communications Network Mediation-related
information.

The following reports can be generated and are regrouped under
C<Network Mediation>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.NM module ...',tput('off')

# Initialization
var $NM_HOME = ${D_HOME:''}
var $TAIL    = ${N_TAIL:1000}

var $AS_LOG = catFile($NM_HOME,'log','adminserver','adminserver.log')

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
toc '1:Network Mediation'

=head2 ifconfig - Network Configuration

Gets the network interface configuration.

=cut

debug ' Inside NM module, getting network interface configuration'
report ifconfig
var $cmd = 'ifconfig -a'
prefix
{write '---+ Interfaces'
 write '---## Using: ',encode($cmd)
}
call writeCommand($cmd)
if isCreated(true)
{write $TOP
 toc '2:[[',getFile(),'][rda_report][Network Configuration]]'
}

=head2 product_info - Product Information

Collects a variety of relevant Oracle Communications Network Mediation product
information.

=cut

debug ' Inside NM module, getting product information'
report product_info
title '---+!! Product Information'
title $TOC

var $cmd = catCommand($NM_HOME,'bin','tools','eFixTool')
prefix
{write '---+ Build and EFix Level'
 write '---## Using: ',encode($cmd),' -info'
}
call writeCommand(concat($cmd,' -info'))
if hasOutput(true)
 write $TOP

prefix
 write '---+ Installed Cartridge Packs'
call statDir('t',catDir($NM_HOME,'cartridges'))
if hasOutput(true)
 write $TOP

var $cmd = catCommand($NM_HOME,'jre','bin','java')
prefix
{write '---+ JRE Version'
 write '---## Using: ',encode($cmd),' -version'
}
call writeCommand(concat($cmd,' -version 2>&1'))
if hasOutput(true)
 write $TOP

prefix
{write '---+ Running Network Mediation Processes'
 write '---## Using: ps -ef | grep udcModule'
 write '<verbatim>'
}
loop $lin (grepCommand('ps -ef','udcModule'))
 write $lin
if hasOutput(true)
{write '</verbatim>'
 write $TOP
}
if isCreated()
 toc '2:[[',getFile(),'][rda_report][Product Information]]'

=head2 export - Environment Variables

Lists defined environment variables.

=cut

debug ' Inside NM module, getting environment variables'
report export
prefix
{write '---+ Environment Variables'
 write '|*Variable*|*Value*|'
}
loop $key (grepEnv('.'))
 write '|',$key,'|',replace(replace(getEnv($key),'\|','&#x7C;',true),\
                            '[\012\015]+','%BR%',true),' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Environment Variables]]'

=head2 node_mgr_info - Node Manager Information

Gets Node Manager information.

=cut

debug ' Inside NM module, getting Node Manager information'
report node_mgr_info
title '---+!! Node Manager Information'
title $TOC

var $fil = catFile($NM_HOME,'config','nodemgr','nmPort')
prefix
{write '---+ Port Number'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($NM_HOME,'config','nodemgr','nodemgr.cfg')
prefix
{write '---+ Configuration Parameters'
 write '---## From: ',encode($fil)
 write '|*Parameter*|*Value*|'
}
loop $lin (grepFile($fil,'.'))
{if match($lin,"^(\S+)\s+'(.*)'")
  write '|',join('|',last),' |'
 else
  write '|',$lin,' ||'
}
if hasOutput(true)
 write $TOP

var $fil = catFile($NM_HOME,'config','nodemgr','nodemgr.var.reference')
prefix
{write '---+ Var Reference'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($NM_HOME,'log','nodemgr','nodemgr.log')
prefix
{write '---+ Log File'
 write '---## Last ',$TAIL,' Lines of ',encode($fil),' File'
}
call writeTail($fil,$TAIL)
if hasOutput(true)
 write $TOP
if isCreated()
 toc '2:[[',getFile(),'][rda_report][Node Manager Information]]'

=head2 adm_server_info - Admin Server Information

Gets Admin Server information.

=cut

debug ' Inside NM module, getting Admin Server information'
report adm_server_info
title '---+!! Admin Server Information'
title $TOC

var $fil = catFile($NM_HOME,'config','adminserver','firewallportnumbers.cfg')
prefix
{write '---+ Port Number'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($NM_HOME,'config','adminserver','general.cfg')
prefix
{write '---+ Configuration Parameters'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($NM_HOME,'log','adminserver','adminserver.log')
prefix
{write '---+ Log File'
 write '---## Last ',$TAIL,' Lines of ',encode($fil),' File'
}
call writeTail($fil,$TAIL)
if hasOutput(true)
 write $TOP
if isCreated()
 toc '2:[[',getFile(),'][rda_report][Admin Server Information]]'

=head2 gui_info - GUI Information

Gets GUI information.

=cut

debug ' Inside NM module, getting GUI information'
report gui_info
title '---+!! GUI Information'
title $TOC
var $fil = catFile($NM_HOME,'config','GUI','firewallportnumbers.cfg')
prefix
{write '---+ firewallportnumbers.cfg'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if isCreated(true)
{write $TOP
 toc '2:[[',getFile(),'][rda_report][GUI Configuration Information]]'
}

=head2 security_info - Security Information

Gets the content of various security-related files

=cut

debug ' Inside NM module, getting security info'
report security_info
title '---+!! Security Information'
title $TOC

var $fil = catFile($NM_HOME,'config','GUI','firewallportnumbers.cfg')
prefix
{write '---+ GUI firewallportnumbers.cfg'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($NM_HOME,'config','adminserver','firewallportnumbers.cfg')
prefix
{write '---+ Admin Server firewallportnumbers.cfg'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

prefix
{write '---+ Admin Server Security Logs'
 write '---## From: ',encode($AS_LOG)
 write '<verbatim>'
}
loop $lin (grepFile($AS_LOG,'User'))
 write $lin
if hasOutput(true)
{write '</verbatim>'
 write $TOP
}

var $fil = catFile($NM_HOME,'config','nodemgr','nodemgr_allow.cfg')
prefix
{write '---+ Admin Servers Allowed to Control this Node Manager'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP
if isCreated()
 toc '2:[[',getFile(),'][rda_report][Security Info]]'

=head2 node_mgr_log - Node Manager Log Analysis

Extracts information from the Node Manager log file.

=cut

toc '2:Component Log Analyses'

debug ' Inside NM module, analyzing node manager log'
report node_mgr_log
var $fil = catFile($NM_HOME,'log','nodemgr','nodemgr.log')
write '---+!! Node Manager Log Analysis'
write '---## From: ',encode($fil)
write $TOC

write '---+ Exceptions'
prefix
 write '<verbatim>'
loop $lin (grepFile($fil,'Exception trace'))
 write $lin
if hasOutput(true)
 write '</verbatim>'
else
 write 'No exceptions found%BR%'
write $TOP

prefix
 write '---+ Last ',$TAIL,' Lines of the Log File'
call writeTail($fil,$TAIL)
if hasOutput(true)
 write $TOP

toc '3:[[',getFile(),'][rda_report][Node Manager Log Analysis]]'

=head2 adm_server_log - Admin Server Log Analysis

Extracts information from the Admin Server log file.

=cut

debug ' Inside NM module, analyzing admin server log'
report adm_server_log
write '---+!! Admin Server Log Analysis'
write '---## From: ',encode($AS_LOG)
write $TOC

write '---+ Exceptions'
prefix
 write '<verbatim>'
loop $lin (grepFile($AS_LOG,'Exception trace'))
 write $lin
if hasOutput(true)
 write '</verbatim>'
else
 write 'No exceptions found%BR%'
write $TOP

prefix
 write '---+ Last ',$TAIL,' Lines of the Log File'
call writeTail($AS_LOG,$TAIL)
if hasOutput(true)
 write $TOP

toc '3:[[',getFile(),'][rda_report][Admin Server Log Analysis]]'

=head2 Node Analyses

Gets basic information about the Oracle Communications Network Mediation nodes.

=cut

debug ' Inside NM module, getting Node information'
pretoc '2:Node Information'

var $tbl = catFile($NM_HOME,'config','nodemgr','nodetable.cfg')
loop $lin (grepFile($tbl,'.'))
{var $nod = substr($lin,0,20)
 var $dir = catDir($NM_HOME,'config',$nod)
 if ?testDir('d',$dir)
 {debug ' - ',$nod
  report concat('node_',$nod)
  title '---+!! Information for Node ',encode($nod)
  title $TOC

  var $fil = catFile($dir,'general.cfg')
  prefix
  {write '---+ Configuration Parameters'
   write '---## From: ',encode($fil)
   write '|*Parameter*|*Value*|'
  }
  loop $lin (grepFile($fil,'.'))
  {if match($lin,"^(\S+)\s+'(.*)'")
    write '|',join('|',last),' |'
   else
    write '|',$lin,' ||'
  }
  if hasOutput(true)
   write $TOP

  var $fil = catFile($NM_HOME,'log',$nod,concat($nod,'.log'))
  prefix
  {write '---+ Last ',$TAIL,' Lines of the Node Log File'
   write '---## From: ',encode($fil)
  }
  call writeTail($fil,$TAIL)
  if hasOutput(true)
   write $TOP
  if isCreated()
   toc '3:[[',getFile(),"][rda_report]['",encode($nod),"' Node]]"
 }
}
unpretoc

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
