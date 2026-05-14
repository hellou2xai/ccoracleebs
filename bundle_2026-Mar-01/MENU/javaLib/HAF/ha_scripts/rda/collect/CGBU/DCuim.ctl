# DCuim.ctl:490:Collects Unified Inventory Management Information
# $Id: DCuim.ctl,v 1.7 2015/08/21 16:15:16 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCuim.ctl,v 1.7 2015/08/21 16:15:16 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

CGBU:DCuim - Collects Unified Inventory Management Information

=head1 DESCRIPTION

This module collects Oracle Communications Unified Inventory Management-related
information.

The following reports can be generated and are regrouped under
C<Unified Inventory Management>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.UIM module ...',tput('off')

# Initialization
var $UIM_DOMAIN = ${D_DOMAIN:''}
var $UIM_LIMIT  = ${N_LIMIT:5000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
toc '1:Unified Inventory Management'

=head2 domain_directories - Domain Directory Listing

Lists the content of the domain.

=cut

# Define the directory analysis macro
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

debug ' Inside UIM module, listing domain directory structure'
report domain_directories
title '---+ Adminserver Domain Listing'
title '---## Recursively Searched from ',encode($UIM_DOMAIN)
call stat_tree($UIM_DOMAIN)
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Domain Directory Listing]]'

=head2 Inventory.ear Information

Gets information from the C<inventory*ear> files.

=cut

debug ' Inside UIM module, getting inventory.ear file information'
report inventory_ear_details
var $jar = findCommand('jar')
prefix
{write '---+!! Inventory.ear File'
 write $TOC
}
loop $fil (grepDir($UIM_DOMAIN,'inventory.*ear$','dr'))
{if ?testFile('fr',$fil)
 {# Take a copy of the ear file
  var $lnk = encode($fil)
  suspend report
  output B,'ear'
  if writeData($fil)
   var $lnk = concat('[[',getRawLink(true),'][_blank][',$lnk,']]')
  resume report

  # Report the ear file details
  write '---++ From ',$fil
  write '|*File*|',$lnk,'|'
  write '|*Size*|',getSize($fil),'|'
  write '|*Last Inode Change*|',getLastChange($fil,'<UTC>'),'|'
  write '|*Last Modify*|',getLastModify($fil,'<UTC>'),'|'
  write '|*Last Access*|',getLastAccess($fil,'<UTC>'),'|'
  if $jar
  {debug ' Inside UIM module, getting inventory.ear content'
   write '---+++!! Contents'
   call writeCommand(concat($jar,' tvf ',quote($fil)))
  }
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Inventory.ear Information]]'

=head2 domain_logs - Domain Log Files

Collects domain log files.

=cut

debug ' Inside UIM module, getting domain log files'
report domain_logs
title '---+!! Domain Log Files (',$UIM_LIMIT,' lines of each type)'
title '---## From ',$UIM_DOMAIN
title $TOC

loop $fil (grepDir($UIM_DOMAIN,'log$','np'))
{prefix
 {if isCreated()
   write '---'
  write '---+' , encode($fil)
 }
 call writeTail($fil, $UIM_LIMIT)
 if hasOutput(true)
  write $TOP
}

loop $dir (grepDir($UIM_DOMAIN,'logs','dr'))
{loop $log (grepDir($dir,'log$','dr'))
 {var $max = $UIM_LIMIT
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
