# DCcm.ctl:489:Collects Configuration Management Information
# $Id: DCcm.ctl,v 1.5 2014/03/12 11:49:12 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCcm.ctl,v 1.5 2014/03/12 11:49:12 RDA Exp $
#
# Change History
# 20140312  MSC  Improve descriptions.

=head1 NAME

CGBU:DCcm - Collect Oracle Communications Configuration Management Information

=head1 DESCRIPTION

This module collects Oracle Communications Configuration Management-related
information.

The following reports can be generated and are regrouped under
C<Configuration Management>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.CM module ...',tput('off')

# Initialization
var $CM_DOMAIN = ${D_DOMAIN:''}
var $CM_LIMIT  = ${N_LIMIT:2000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
toc '1:Configuration Management'

=head2 domain_directories - Domain Directory Listing

Lists the content of the domain.

=cut

macro stat_tree
{var ($dir) = @arg
 import $TOP

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

debug ' Inside CM module, listing domain directory structure'
report domain_directories
title '---+ Adminserver Domain Listing'
title '---## Recursively Searched from ',encode($CM_DOMAIN)
call stat_tree($CM_DOMAIN)
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Domain Directory Listing]]'

=head2 domain_logs - Domain Log Files

Collects domain log files.

=cut

debug ' Inside CM module, getting domain log files'
report domain_logs
title '---+!! Domain Log Files (',$CM_LIMIT,' lines of each type)'
title '---## From ',$CM_DOMAIN
title $TOC

loop $fil (grepDir($CM_DOMAIN, '.*log$', 'p'))
{prefix
 {if isCreated()
   write '---'
  write '---+',encode($fil)
 }
 call writeTail($fil,$CM_LIMIT)
 if hasOutput(true)
  write $TOP
}

loop $dir (grepDir($CM_DOMAIN,'logs','dr'))
{loop $log (grepDir($dir,'log$','dr'))
 {var $max = $CM_LIMIT
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
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Domain Log Files]]'

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
