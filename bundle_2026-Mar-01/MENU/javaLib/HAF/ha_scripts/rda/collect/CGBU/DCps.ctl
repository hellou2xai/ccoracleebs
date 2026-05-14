# DCps.ctl:488:Collects Oracle Communications Policy Services Information
# $Id: DCps.ctl,v 1.7 2013/10/30 07:18:23 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCps.ctl,v 1.7 2013/10/30 07:18:23 RDA Exp $
#
# Change History
# 20130610  MSC  Improve validation.

=head1 NAME

CGBU:DCps - Collect Oracle Communications Policy Services Software Information

=head1 DESCRIPTION

This module collects Oracle Communications Policy Services-related
information.

The following reports can be generated and are regrouped under
C<Policy Services>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.PS module ...',tput('off')

# Initialization
var $PS_HOME = ${D_HOME:''}
var $TAIL    = ${N_TAIL:1000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
toc '1:Policy Services'

=head2 ifconfig - Network Configuration

Gets the network interface configuration.

=cut

debug ' Inside PS module, getting network interface configuration'
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

=head2 configuration_info - Configuration Information

Collects Oracle Communications Policy Services configuration information.

=cut

toc '2:Product Information'

debug ' Inside PS module, getting configuration information'
report configuration_info
var $dir = catDir($PS_HOME,'conf')
prefix
{write '---+!! Config Directory'
 write '---## Recursively Searched from: ',encode($dir)
 write $TOC
}
loop $fil (grepDir($dir,'^\.+$','nrv'))
{if ?testFile('T',$fil)
 {write '---'
  write '---+',encode($fil)
  call writeFile($fil)
  write $TOP
 }
}
if isCreated(true)
 toc '3:[[',getFile(),'][rda_report][Configuration Information]]'

=head2 processes_info - PS Processes

Lists relevant Oracle Communications Policy Services processes.

=cut

if ?findCommand('ps')
{var $cmd = last

 debug ' Inside PS module, getting process information'
 report processes_info
 title '---+!! Policy Services Processes Currently Running'
 title $TOC
 loop $typ ('weblogic','mslv','iplanet')
 {prefix
  {write '---'
   write '---+ ',$typ,' Processes'
   write '---## Using: ps -ef | grep ',$typ
   write '<verbatim>'
  }
  loop $lin (grepCommand(concat($cmd,' -ef'),concat('\b',$typ)))
   write $lin
  if hasOutput(true)
  {write '</verbatim>'
   write $TOP
  }
 }
 if isCreated(true)
  toc '3:[[',getFile(),'][rda_report][PS Processes]]'
}

=head2 mib_info - MIB Information

Collects Oracle Communications Policy Services MIB information.

=cut

debug ' Inside PS module, getting PS MIB information'
report mib_info

var $dir = catDir($PS_HOME,'mibs')
prefix
{write '---+!! MIB Information'
 write '---## Recursively Searched from: ',encode($dir)
 write $TOC
}
loop $fil (grepDir($dir,'^\.+$','nrv'))
{if ?testFile('T',$fil)
 {write '---'
  write '---+',encode($fil)
  call writeFile($fil)
  write $TOP
 }
}
if isCreated(true)
 toc '3:[[',getFile(),'][rda_report][MIB Information]]'

=head2 properties_info - Property Files Information

Collects Oracle Communications Policy Services property files.

=cut

debug ' Inside PS module, getting Property Files information'
report properties_info
var $dir = $PS_HOME
prefix
{write '---+!! Property Files Information'
 write '---## Recursively Searched from: ',encode($dir)
 write $TOC
}
loop $fil (grepDir($dir,'properties$','nr'))
{if ?testFile('T',$fil)
 {write '---'
  write '---+',encode($fil)
  call writeFile($fil)
  write $TOP
 }
}
if isCreated(true)
 toc '3:[[',getFile(),'][rda_report][Property Files Information]]'

=head2 ps_log_info - PS Log Files

Collects the last lines of Oracle Communications Policy Services log files.

=cut

debug ' Inside PS module, getting PS Log Files information'
report ps_log_info
var $dir = $PS_HOME
prefix
{write '---+!! PS Log Files'
 write '---## Last ',$TAIL,' Lines of each File'
 write '---## Recursively Searched from: ',encode($dir)
 write $TOC
}
loop $fil (grepDir($dir,'log$','nr'))
{if ?testFile('T',$fil)
 {write '---'
  write '---+',encode($fil)
  call writeTail($fil,$TAIL)
  write $TOP
 }
}
if isCreated(true)
 toc '3:[[',getFile(),'][rda_report][PS Log Files]]'

=head2 iplanet_log_info - iPlanet Log Files

Collects the last lines of iPlanet log files.

=cut

if ${D_LDAP_INSTALL}
{var $dir = last

 debug ' Inside PS module, getting iPlanet log files information'
 report iplanet_log_info
 prefix
 {write '---+!! iPlanet Logs'
  write '---## Last ',$TAIL,' Lines of each File'
  write $TOC
 }

 loop $fil (grepDir($dir,'access$','nr'))
 {if ?testFile('T',$fil)
  {write '---'
   write '---+',encode($fil)
   call writeTail($fil,$TAIL)
   write $TOP
  }
 }

 loop $fil (grepDir($dir,'error$','nr'))
 {if ?testFile('T',$fil)
  {write '---'
   write '---+',encode($fil)
   call writeTail($fil,$TAIL)
   write $TOP
  }
 }

 loop $fil (grepDir($dir,'dse.ldif$','nr'))
 {if ?testFile('T',$fil)
  {write '---'
   write '---+',encode($fil)
   call writeFile($fil)
   write $TOP
  }
 }

 if isCreated(true)
  toc '3:[[',getFile(),'][rda_report][iPlanet Log Files]]'
}

=head2 data_files_info - Data Files Information

Collects Oracle Communications Policy Services data files.

=cut

debug ' Inside PS module, getting data files information'
report data_files_info
var $dir = catDir($PS_HOME,'data')
prefix
{write '---+!! Data Files Information'
 write '---## Recursively Searched from: ',encode($dir)
 write $TOC
}
loop $fil (grepDir($dir,'$','nr'))
{if ?testFile('T',$fil)
 {write '---'
  write '---+',encode($fil)
  call writeFile($fil)
  write $TOP
 }
}
if isCreated(true)
 toc '3:[[',getFile(),'][rda_report][Data Files Information]]'

=head2 database_files_info - Database Files Information

Collects Oracle Communications Policy Services database files.

=cut

debug ' Inside PS module, getting database files information'
report database_files_info
var $dir = $PS_HOME
prefix
{write '---+!! Database Files Information (*.db Files)'
 write '---## Recursively Searched from: ',encode($dir)
 write $TOC
}
loop $fil (grepDir($dir,'db$','nr'))
{if ?testFile('T',$fil)
 {write '---'
  write '---+',encode($fil)
  call writeFile($fil)
  write $TOP
 }
}
if isCreated(true)
 toc '3:[[',getFile(),'][rda_report][Database Files Information]]'

=head2 lib_info - Library Information

Collects information about installed libraries.

=cut

debug ' Inside PS module, getting Library information'
report lib_info
var $dir = catDir($PS_HOME,'lib')
prefix
{write '---+!! Installed Libraries'
 write '---## Recursively Searched from: ',encode($dir)
 write $TOC
 write '|*Filename*|*Size*|*Last Access*|*Last Modify*|'
}
var $fmt = '%a %b %d %Y %H:%M'
loop $fil (grepDir($dir,'^\.+$','nrv'))
{next ?testFile('T',$fil)
 write '|',encode($fil),'| ',getSize($fil),'|',getLastAccess($fil,$fmt),' |',\
       getLastModify($fil,$fmt),'|'
}
if isCreated(true)
 toc '3:[[',getFile(),'][rda_report][Library Information]]'

=head2 access_security_info - Access Security Information

Collects domain access security information.

=cut

debug ' Inside PS module, getting access security information'
report access_security_info
var $top = catDir($PS_HOME,'java')
prefix
{write '---+!! Domain Access Security Information (GUI Login Attempts)'
 write $TOC
}
loop $dom (grepDir($top,'Domain','nr'))
{next !?testFile('d',$dom)
 loop $srv (grepDir($dom,'Server','nr'))
 {next !?testFile('d',$srv)
  loop $fil (grepDir($srv,'access\.log','nr'))
  {write '---'
   write '---+',encode($fil)
   call writeFile($fil)

   prefix
   {write '---'
    write '---++ ',$srv,' Successful Logins'
    write '<verbatim>'
   }
   loop $lin (grepFile($fil,'/login.jsp HTTP'))
    write $lin,'%BR%'
   if hasOutput(true)
   {write '</verbatim>'
    write $TOP
   }
  }
 }
 loop $srv (grepDir($dom,'Server','nr'))
 {next !?testFile('d',$srv)
  loop $fil (grepDir($srv,'access\.log','nr'))
  {prefix
   {write '---'
    write '---++ ',encode($srv),' Failed Logins'
    write '<verbatim>'
   }
   loop $lin (grepFile($fil,'/badlogin.jsp HTTP'))
    write $lin,'%BR%'
   if hasOutput(true)
   {write '</verbatim>'
    write $TOP
   }
  }
 }
}
if isCreated(true)
 toc '3:[[',getFile(),'][rda_report][Access Security Information]]'

=head2 ldap_directory_info - LDAP Directory Dump

Gets a dump of the Oracle Communications Policy Services LDAP directory.

=cut

if ${B_DO_LDAP}
{if ?findCommand('ldapsearch')
 {var $pgm = last

  debug ' Inside PS module, getting directory dump information'
  report ldap_directory_dump
  prefix
  {write '---+!! LDAP Directory Dump'
   write $TOC
   write '---'
  }
  suspend report

  debug ' - Starting LDAP directory dump'
  var $dir = ${D_LDAP_INSTALL}
  var $hst = ${T_LDAP_HOST}
  var $bdn = ${T_LDAP_BASEDN}
  output D,ps_ldiff
  var $dat = getFile('.')
  var $lnk = getRawLink(true)
  var $cmd = catCommand($dir,concat('slapd-',isHost($hst,true)),'db2ldif')
  var $cmd = concat($cmd,' -s ',quote($bdn),' -a ',$dat)
  debug ' - ldapcmd=',$cmd

  resume report
  call writeCommand($cmd)
  if ?testFile('f',$dat)
  {write 'LDIF file created as [[',$lnk,'][_blank][',basename($dat),']]'
   call statFile('b',$dat)
   write '   * The link points to a dump that has been collected in their \
               original format. Opening them directly in your browser can \
               present security risks. To prevent them, access the file \
               outside the browser or use the link to save them and use an \
               adequate viewer.'
  }

  debug ' - LDAP directory dump complete'
  if isCreated(true)
   toc '3:[[',getFile(),'][rda_report][LDAP Directory Dump]]'
 }
}

=head2 radius_info - Radius Log Files

Collects the last lines of the Oracle Communications Policy Services Radius log
files.

=cut

if ${B_DO_RADIUS}
{debug ' Inside PS module, getting Radius Server log files'
 report radius_info
 var $dir = ${D_RADIUS_INSTALL}
 prefix
 {write '---+!! PS Radius Log Files'
  write '---## Last ',$TAIL,' lines of each file'
  write '---## Recursively Searched from: ',encode($dir)
  write $TOC
 }
 loop $fil (grepDir($dir,'log$','nr'))
 {if ?testFile('T',$fil)
  {write '---'
   write '---+ ',encode($fil)
   call writeTail($fil,$TAIL)
   write $TOP
  }
 }
 if isCreated(true)
  toc '3:[[',getFile(),'][rda_report][Radius Log Files]]'
}

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
