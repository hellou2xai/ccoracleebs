# DCni.ctl:483:Collects Oracle Communications Network Integrity Information
# $Id: DCni.ctl,v 1.4 2013/10/30 07:18:23 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCni.ctl,v 1.4 2013/10/30 07:18:23 RDA Exp $
#
# Change History
# 20130610  MSC  Improve validation.

=head1 NAME

CGBU:DCni - Collect Oracle Communications Network Integrity Information

=head1 DESCRIPTION

This module collects Oracle Communications Network Integrity-related
information.

The following reports can be generated and are regrouped under
C<Network Integrity>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.NI module ...',tput('off')

# Initialization
var $NI_DOMAIN = ${D_DOMAIN:''}
var $NI_LIMIT  = ${N_LIMIT:2000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
toc '1:Network Integrity'

=head2 domain_directories - Domain Directory Listing

Lists the content of the domain.

=cut

macro stat_tree
{var ($dir) = @arg
 import $TOP
 keep $TOP

 prefix
 {
 }
 call statDir('n',$dir)
 if hasOutput(true)
  write $TOP

 loop $pth (grepDir($dir,'^\.+$','npv'))
 {if ?testFile('dr',$pth)
  {next ?testFile('l',$pth)
   call stat_tree($pth)
  }
 }
}

debug ' Inside NI module, listing domain directory structure'
report domain_directories
title '---+ Adminserver Domain Listing'
title '---## Recursively Searched from ',encode($NI_DOMAIN)
call stat_tree($NI_DOMAIN)
if isCreated()
 toc '2:[[',getFile(),'][rda_report][Domain Directory Listing]]'

=head2 domain_logs - Domain Log Files

Collects domain log files.

=cut

debug ' Inside NI module, getting domain log files'
report domain_logs

title '---+!! Domain Log Files (',$NI_LIMIT,' lines of each type)'
title '---## From ',$NI_DOMAIN
title $TOC

loop $fil (grepDir($NI_DOMAIN,'log$','np'))
{prefix
 {if isCreated()
   write '---'
  write '---+',encode($fil)
 }
 call writeTail($fil,$NI_LIMIT)
 if hasOutput(true)
  write $TOP
}

loop $dir (grepDir($NI_DOMAIN,'logs','dr'))
{loop $log (grepDir($dir,'log$','dr'))
 {var $max = $NI_LIMIT
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

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
