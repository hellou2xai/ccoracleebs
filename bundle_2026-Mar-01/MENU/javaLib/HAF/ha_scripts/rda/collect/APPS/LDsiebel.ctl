# LDsiebel.ctl: Collects Siebel Crash Reports
# $Id: LDsiebel.ctl,v 1.5 2013/10/30 07:18:21 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/LDsiebel.ctl,v 1.5 2013/10/30 07:18:21 RDA Exp $
#
# Change History
# 20130821  KRA  Improve abbreviation management.

=head1 NAME

APPS:LDsiebel - Collects Siebel Crash Reports

=head1 DESCRIPTION

This module retrieves the Siebel crash reports.

=cut

# Set the abbreviation and purge old reports
call setAbbr('APPS_SIEBEL_')
call purge('C','.',15,0)

# Collect recent files
debug ' Inside LOAD module, gathering Siebel crash reports'
report siebel
prefix
{write '---+ Siebel Crash Reports'
 write 'Limited to Siebel crash reports produced in last 15 days%BR%&nbsp;'
 write '| *Report*|*Enterprise*|*Server*|*PID*|*Core Dump*|'
}
var $pat = concat('^',${CUR.W_PREFIX},'c(\d+)_crash\.htm$')
loop $fil (grepDir(${OUT.C},$pat,'ipt'))
{next !grepFile($fil,'CRASH:\|','f')
 var (undef,$hom,$ent,$srv,$pid,$dmp) = split('\|',last)
 var ($uid) = match($bas = basename($fil),$pat)
 write '| [[',$bas,'][_blank][',$uid,']]|',$ent,' |',$srv,' |',$pid,' |',\
       $dmp,' |'
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Siebel Crash Reports]]'

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
