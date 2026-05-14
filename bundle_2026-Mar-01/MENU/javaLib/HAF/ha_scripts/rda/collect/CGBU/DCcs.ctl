# DCcs.ctl:495:Collects Oracle Communications Calendar Server Information
# $Id: DCcs.ctl,v 1.3 2013/10/30 07:18:22 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCcs.ctl,v 1.3 2013/10/30 07:18:22 RDA Exp $
#
# Change History
# 20130422  MSC  Improve the validation.

=head1 NAME

CGBU:DCcs - Collects Oracle Communications Calendar Server Information

=head1 DESCRIPTION

This module collects information related to Oracle Communications Calendar
Server, formerly known as Sun Java System Calendar Server.

The following reports can be generated and are regrouped under C<Calendar
Server>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.CS module ...',tput('off')

# Initialization
var $HOME = undef
var $TAIL = ${DFT.N_TAIL:1000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Calendar Server'

# Identify the installation home
if ${OS.linux}
{if ?nvl(testDir('d',catDir(first(command(\
           'rpm -q --queryformat "%{INSTALLPREFIX}" sun-davserver')))),\
         testDir('d',catDir(first(command(\
           'rpm -q --queryformat "%{INSTALLPREFIX}" sun-calendar-server')))))
  var $HOME = last
}
elsif ${OS.solaris}
{if ?nvl(testDir('d',catDir('/opt/sun/comms/davserver')),\
         testDir('d',catDir('/opt/sun/comms/calendar/SUNWics5/cal')),\
         testDir('d',catDir('/opt/SUNWics5/cal')),\
         testDir('d',catDir(first(command('pkginfo -r SUNWdavserver')))),\
         testDir('d',catDir(first(command('pkginfo -r SUNWics5')))))
  var $HOME = last
}
if ?$HOME
{# Load the common macros
 run RDA:library()

=head2 Configuration Files

Gathers Oracle Communications Calendar Server-related configuration files.

=cut

 debug ' Inside CS module, collecting the configuration files'
 pretoc '2:Configuration Files'
 call sort_files(3,0,grepDir(catDir($HOME,'config'),'^\.+$','npv'))
 unpretoc

=head2 Log Files

Gathers Oracle Communications Calendar Server-related log files.

=cut

 debug ' Inside CS module, collecting the log files'
 pretoc '2:Log Files'
 if ?nvl(testDir('d',catDir($HOME,'logs')),\
         testDir('d',catDir($HOME,'data')),\
         testDir('d',catDir('/var/opt/SUNWics5/logs')))
  call sort_files(3,$TAIL,grepDir(last,'^\.+$','npv'))
 unpretoc
}
unpretoc

=head1 SEE ALSO

L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
