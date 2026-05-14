# LDepm.ctl: Collects Enterprise Performance Management Validation Reports
# $Id: LDepm.ctl,v 1.4 2013/10/30 07:18:22 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/LDepm.ctl,v 1.4 2013/10/30 07:18:22 RDA Exp $
#
# Change History
# 20130821  KRA  Improve abbreviation management.

=head1 NAME

BI:LDepm - Collects Enterprise Performance Management Validation Reports

=head1 DESCRIPTION

This module retrieves the Enterprise Performance Management validation reports.

=cut

# Set the abbreviation and purge old reports
call setAbbr('BI_EPMVAL_')
call purge('C','.',15,0)

# Collect recent files
debug ' Inside LOAD module, gathering EPM validation reports'
report results
prefix
{write '---+ Enterprise Performance Management Validation Reports'
 write 'Limited to EPM validation reports produced in last 15 days%BR%&nbsp;'
 write '| *Report*|'
}
var $pat = concat('^',${CUR.W_PREFIX},'c(\d+)_validate\.htm$')
loop $fil (grepDir(${OUT.C},$pat,'ipt'))
{var ($uid) = match($bas = basename($fil),$pat)
 write '| [[',$bas,'][_blank][',$uid,']]|'
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][EPM Validation Reports]]'

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
