# DCnd.ctl:482:Collects Oracle Communications Network Discovery Information
# $Id: DCnd.ctl,v 1.3 2013/10/30 07:18:23 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCnd.ctl,v 1.3 2013/10/30 07:18:23 RDA Exp $
#
# Change History
# 20130422  MSC  Improve the validation.

=head1 NAME

CGBU:DCnd - Collect Oracle Communications Network Discovery Software Information

=head1 DESCRIPTION

This module collects Oracle Communications Network Discovery-related
information.

The following reports can be generated and are regrouped under
C<Network Discovery>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.ND module ...',tput('off')

# Initialization
var $ND_HOME = ${D_HOME:''}
var $TAIL    = ${N_TAIL:1000}

var $AS_LOG = catFile($ND_HOME,'log','adminserver','adminserver.log')

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
toc '1:Network Discovery'

=head2 ifconfig - Network Configuration

Gets the network interface configuration.

=cut

debug ' Inside ND module, getting network interface configuration'
report ifconfig
var $cmd = 'ifconfig -a'
prefix
{write '---+ Interfaces'
 write '---## Using: ',$cmd
}
call writeCommand($cmd)
if isCreated(true)
{write $TOP
 toc '2:[[',getFile(),'][rda_report][Network Configuration]]'
}

=head2 product_info - Product Information

Collects a variety of relevant Oracle Communications Network Discovery product
information.

=cut

debug ' Inside ND module, getting product information'
report product_info
title '---+!! Product Information'
title $TOC

var $cmd = catCommand($ND_HOME,'bin','tools','eFixTool')
prefix
{write '---+ Build and EFix Level'
 write '---## Using: ',encode($cmd),' -info'
}
call writeCommand(concat($cmd,' -info'))
if hasOutput(true)
 write $TOP

if or(\
  testFile('e',catFile('/var/opt/OracleCommunicationsNetworkDiscovery/\
                        ProcessControl.conf')),\
  testFile('e',catFile('/var/opt/metasolvMediation/metasolv_mediation.conf')))
{prefix
 {write '---+ ProcessControl Config File'
  write '---## From: ',encode(lastFile())
 }
 call writeFile(lastFile())
 if hasOutput(true)
  write $TOP
}

prefix
 write '---+ Installed Cartridge Packs'
call statDir('t',catDir($ND_HOME,'cartridges'))
if hasOutput(true)
 write $TOP

var $cmd = catCommand($ND_HOME,'jre','bin','java')
prefix
{write '---+ JRE Version'
 write '---## Using: ',encode($cmd),' -version'
}
call writeCommand(concat($cmd,' -version 2>&1'))
if hasOutput(true)
 write $TOP

prefix
{write '---+ Running Network Discovery Processes'
 write '---## Using: ps -ef | grep ',encode($ND_HOME)
 write '<verbatim>'
}
loop $lin (grepCommand('ps -ef',$ND_HOME))
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

debug ' Inside ND module, getting environment variables'
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

=head2 discovery_info - Discovery Information

Gets Discovery information.

=cut

debug ' Inside ND module, getting discovery information'
report discovery_info
title '---+!! Discovery Information'
title $TOC

var $fil = catFile($ND_HOME,'config','discovery','scans.cfg')
prefix
{write '---+ Discovery Scan Information'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $dir = catDir($ND_HOME,'log','adminserver','discovery')
loop $fil (grepDir($dir,'log','r'))
{if ?testFile('T',$fil)
 {prefix
   write '---+ Admin Server Discovery Logs: ',encode($fil)
  call writeTail($fil,$TAIL)
  if hasOutput(true)
   write $TOP
 }
}

var $dir = catDir($ND_HOME,'log','discovery')
loop $fil (grepDir($dir,'log','p'))
{if ?testFile('T',$fil)
 {prefix
   write '---+ Discovery Log: ',encode($fil)
  call writeTail($fil,$TAIL)
  if hasOutput(true)
   write $TOP
 }
}

var $dir = catDir($ND_HOME,'log','discovery','results')
loop $fil (grepDir($dir,'log','p'))
{if ?testFile('T',$fil)
 {prefix
   write '---+ Discovery Result Log: ',encode($fil)
  call writeTail($fil,$TAIL)
  if hasOutput(true)
   write $TOP
 }
}
if isCreated()
 toc '2:[[',getFile(),'][rda_report][Discovery Information]]'

=head2 scan_history - Scan History

Gets Scan History information. The results will only be available from the
last of each scan.

=cut

debug ' Inside ND modile, getting Scan History information'
report scan_history_info
title '---+!! Scan History Information'
title $TOC

# Look in the discovery log file and find each dispatched scan
var $dir = catDir($ND_HOME,'log','adminserver','discovery')
loop $fil (grepDir($dir,'log','r'))
{if ?testFile('fT',$fil)
 {var $prv = undef
  prefix
  {write '---++ From ',encode($fil)
   write '|*Scan Name*|*Scan ID*|*Scan Start*|*Device *|*Device Scan Start*|\
           *Device Scan End*|'
  }
  loop $lin (reverse(grepFile($fil,'has been dispatched to')))
  {var $tim = substr($lin,0,19)
   call match($lin,'(.{19}).has been dispatched to')
   var $scn = (last)
   var $log = catFile($ND_HOME,'log','discovery','results',concat($scn,'.log'))
   var $sav = catFile($ND_HOME,'log','discovery','results',concat($scn,'.sav'))

   # Select the file
   if compare('eq',$prv,$scn)
   {if compare('eq',$src,$sav)
    {write '|',$scanName,'|',$scn,'|',$tim,\
           '|details unavailable|details unavailable|details unavailable|'
     next
    }
    var $src = $sav
   }
   else
    var $src = $log

   # Extract the scan details
   if grepFile($src,'Starting discovery scan')
   {var ($nam,$nxt) = (substr(last,46,30))
    loop $det (grepFile($src,'Starting discovery for'))
    {var ($dev,$beg) = (substr($det,45,20),substr($det,0,19))
     if grepFile($src,concat('Finished discovery for: ',$dev),'f')
     {# Handle success case
      var $end = substr(last,0,19)
      if $nxt
       write '| | | |',$dev,'|',$beg,'|',$end,'|'
      else
       write '|',$nam,'|',$scn,'|',$tim,'|',$dev,'|',$beg,'|',$end,'|'
      var $nxt = true
     }
     elsif grepFile($src,'Failed to do discovery for device','f')
     {write '|',$nam,'|',$scn,'|',$tim,'|',$dev,'|',$beg,'|device scan failed|'
      var $nxt = true
     }
    }
   }
   var $prv = $scn
  }
  if hasOutput(true)
   write $TOP
 }
}
if isCreated()
 toc '2:[[',getFile(),'][rda_report][Scan History]]'

=head2 node_mgr_info - Node Manager Information

Gets Node Manager information.

=cut

debug ' Inside ND module, getting Node Manager information'
report node_mgr_info
title '---+!! Node Manager Information'
title $TOC

var $fil = catFile($ND_HOME,'config','nodemgr','nmPort')
prefix
{write '---+ Port Number'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($ND_HOME,'config','nodemgr','nodemgr.cfg')
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

var $fil = catFile($ND_HOME,'config','nodemgr','nodemgr.var.reference')
prefix
{write '---+ Var Reference'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($ND_HOME,'config','nodemgr','nodetable.cfg')
prefix
{write '---+ Node Table'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($ND_HOME,'log','nodemgr','nodemgr.log')
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

debug ' Inside ND module, getting Admin Server information'
report adm_server_info
title '---+!! Admin Server Information'
title $TOC

var $fil = catFile($ND_HOME,'config','adminserver','firewallportnumbers.cfg')
prefix
{write '---+ Port Number'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($ND_HOME,'config','adminserver','general.cfg')
prefix
{write '---+ general.cfg'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($ND_HOME,'config','adminserver','SystemModel.cfg')
prefix
{write '---+ SystemModel.cfg'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($ND_HOME,'log','adminserver','adminserver.log')
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

debug ' Inside ND module, getting GUI information'
report gui_info
title '---+!! GUI Information'
title $TOC
var $fil = catFile($ND_HOME,'config','GUI','firewallportnumbers.cfg')
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

Gets the content of various security-related files.

=cut

debug ' Inside ND module, getting security info'
report security_info
title '---+!! Security Information'
title $TOC

var $fil = catFile($ND_HOME,'config','GUI','firewallportnumbers.cfg')
prefix
{write '---+ GUI firewallportnumbers.cfg'
 write '---## From: ',encode($fil)
}
call writeFile($fil)
if hasOutput(true)
 write $TOP

var $fil = catFile($ND_HOME,'config','adminserver','firewallportnumbers.cfg')
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

var $fil = catFile($ND_HOME,'config','nodemgr','nodemgr_allow.cfg')
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

toc '2:Discovery Component Log Analysis'

debug ' Inside ND module, analyzing node manager log'
report node_mgr_log
var $fil = catFile($ND_HOME,'log','nodemgr','nodemgr.log')
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

debug ' Inside ND module, analyzing admin server log'
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

Gets basic information about the Oracle Communications Network Discovery nodes.

=cut

debug ' Inside ND module, getting Node information'
pretoc '2:Node Information'

var $tbl = catFile($ND_HOME,'config','nodemgr','nodetable.cfg')
loop $lin (grepFile($tbl,'.'))
{var $nod = trim(substr($lin,0,20))

 var $dir = catDir($ND_HOME,'config',$nod)
 if ?testDir('dr',$dir)
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

  var $log = catFile($ND_HOME,'log',$nod,concat($nod,'.log'))
  prefix
  {write '---+ Last ',$TAIL,' Lines of the Node Log File'
   write '---## From: ',encode($log)
  }
  call writeTail($log,$TAIL)
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
