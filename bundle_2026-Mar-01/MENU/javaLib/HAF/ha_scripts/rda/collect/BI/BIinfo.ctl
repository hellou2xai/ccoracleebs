# BIinfo.ctl: Collects Oracle Business Intelligence Repositories
# $Id: BIinfo.ctl,v 1.3 2015/08/21 16:04:40 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/BIinfo.ctl,v 1.3 2015/08/21 16:04:40 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

BI:BIinfo - Collects Oracle Business Intelligence Repositories Information

=head1 DESCRIPTION

This module collects Oracle Business Intelligence Repositories information.

The following report is available:

=cut

# Initialization
var ($lvl,@fil) = @arg

=head2 repository - Repositories

Gathers repositories.

=cut

debug ' Inside BI module, getting repositories'
report repository
prefix
{write '---+ Collected Repositories'
 write '   * Links point to files that have been collected in their original \
             format. Opening them directly in your browser can present \
             security risks. To prevent them, access the file outside the \
             browser or use the link to save them and use an adequate viewer.'
 write '|*Repository Name*| *Size*|*Last Modification*|'
}
suspend report
loop $fil (@fil)
{data concat('rep_',basename($fil))
 if writeData($fil)
 {var $rpt = getRawLink(true)
  resume report
  write '|[[',$rpt,'][_blank][',encode($fil),']]| ',getSize($fil),'|',\
        getLastModify($fil,'<UTC>'),' |'
  suspend report
 }
}
resume report
if isCreated(true)
 toc $lvl,':[[',getFile(),'][rda_report][Repositories]]'

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
