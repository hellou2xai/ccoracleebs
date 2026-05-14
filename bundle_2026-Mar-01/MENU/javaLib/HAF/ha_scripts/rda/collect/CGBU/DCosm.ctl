# DCosm.ctl:487:Collects Order and Service Management Information
# $Id: DCosm.ctl,v 1.5 2014/03/13 11:24:53 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCosm.ctl,v 1.5 2014/03/13 11:24:53 RDA Exp $
#
# Change History
# 20140312  KRA  Improve description.

=head1 NAME

CGBU:DCosm - Collects Order and Service Management Information

=head1 DESCRIPTION

This module collects Oracle Communications Order and Service Management-related
information.

The following reports can be generated and are regrouped under
C<Order and Service Management>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.OSM module ...',tput('off')

# Initialization
var $OSM_DOMAIN = ${D_DOMAIN:''}
var $OSM_LIMIT  = ${N_LIMIT:5000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
toc '1:Order and Service Management'

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

debug ' Inside OSM module, listing domain directory structure'
report domain_directories
title '---+ Adminserver Domain Listing'
title '---## Recursively Searched from ',encode($OSM_DOMAIN)
call stat_tree($OSM_DOMAIN)
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Domain Directory Listing]]'

=head2 domain_logs - Domain Log Files

Collects domain log files.

=cut

debug ' Inside OSM module, getting domain log files'
report domain_logs

title '---+!! Domain Log Files (',$OSM_LIMIT,' lines of each type)'
title '---## From ',$OSM_DOMAIN
title $TOC

loop $fil (grepDir($OSM_DOMAIN,'log$','np'))
{prefix
 {if isCreated()
   write '---'
  write '---+',encode($fil)
 }
 call writeTail($fil,$OSM_LIMIT)
 if hasOutput(true)
  write $TOP
}

loop $dir (grepDir($OSM_DOMAIN,'logs','dr'))
{loop $log (grepDir($dir,'log$','dr'))
 {var $max = $OSM_LIMIT
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
