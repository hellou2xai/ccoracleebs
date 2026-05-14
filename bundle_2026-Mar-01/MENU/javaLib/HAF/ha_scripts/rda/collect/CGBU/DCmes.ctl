# DCmes.ctl:494:Collects Oracle Messaging Exchange Server Information
# $Id: DCmes.ctl,v 1.3 2013/10/30 07:18:22 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCmes.ctl,v 1.3 2013/10/30 07:18:22 RDA Exp $
#
# Change History
# 20130422  MSC  Improve the validation.

=head1 NAME

CGBU:DCmes - Collects Oracle Messaging Exchange Server Information

=head1 DESCRIPTION

This module collects information related to Oracle Communications Messaging
Exchange Server, formerly known as Sun Java System Messaging Server.

The following reports can be generated and are regrouped under C<Messaging
Exchange Server>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.MES module ...',tput('off')

# Initialization
var $HOME = undef
var $TAIL = ${DFT.N_TAIL:1000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Messaging Exchange Server'

# Identify the install home
if ${OS.linux}
{if ?nvl(testDir('d',catDir(first(command(\
           "rpm -q --qf '%{INSTALLPREFIX}' sun-messsaging-server64")))),\
         testDir('d',catDir(first(command(\
           "rpm -q --qf '%{INSTALLPREFIX}' sun-messsaging-server")))))
  var $HOME = last
}
elsif ${OS.solaris}
{if ?nvl(testDir('d',catDir('/opt/sun/comms/messaging64')),\
         testDir('d',catDir('/opt/SUNWmsgsr')),\
         testDir('d',catDir(first(command(\
           'pkginfo -r SUNWmessaging-server-64')))),\
         testDir('d',catDir(first(command(\
           'pkginfo -r SUNWmessaging-server')))),\
         testDir('d',catDir(first(command(\
           'pkginfo -r SUNWmsgco')))))
  var $HOME = last
}
if ?$HOME
{# Load the common macros
 run RDA:library()

=head2 Configuration Files

Gathers Oracle Communications Messaging Exchange Server-related configuration
files.

=cut

 debug ' Inside MES module, collecting the configuration files'
 pretoc '2:Configuration Files'
 call sort_files(3,0,grepDir(catDir($HOME,'config'),'^\.+$','npv'))
 unpretoc

=head2 Log Files

Gathers Oracle Communications Messaging Exchange Server-related log files.

=cut

 debug ' Inside MES module, collecting the log files'
 pretoc '2:Log Files'
 call sort_files(3,$TAIL,grepDir(catDir($HOME,'log'),'^\.+$','npv'))
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
