# DCexltcs.ctl:400:Collects Oracle Exalytics Information
# $Id: DCexltcs.ctl,v 1.7 2015/07/03 11:49:17 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DCexltcs.ctl,v 1.7 2015/07/03 11:49:17 RDA Exp $
#
# Change History
# 20150703  MSC  Improve the documentation.

=head1 NAME

BI:DCexltcs - Collects Oracle Exalytics Information

=head1 DESCRIPTION

This module collects Oracle Exalytics-related information.

The following reports can be generated and are regrouped under
C<Oracle Exalytics>:

=head1 REPORTS

=cut

use Mrc

echo tput('bold'),'Processing BI.EXLTCS module ...',tput('off')

# Initialization
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
toc '%TITLE("1:Oracle Exalytics")%'

=head2 version - Version Information

Gets the version information using the F</usr/sbin/imageinfo> command (C<root>
privileges required).

=cut

collect BI:MCexltcs|EXLTCS()

=head2 Oracle WebLogic Server Domain Information

It includes all reports produced by the L<abr:WREQ|collect::OFM:DCwreq> module
for the specified Oracle WebLogic Server domain.

=cut

toc '%PUSH("%SPLIT%")%'
toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
toc '%INCLUDE("OFM_WREQ_BI_EXLTCS_WH_TF.toc")%'
toc '%POP2%'
toc '%PUSH("%SPLIT%")%'
toc '%PUSH("1+:Oracle WebLogic Server Domain")%'
toc '%INCLUDE("OFM_WREQ_BI_EXLTCS_DOM_TF.toc")%'
toc '%POP2%'

toc '%UNTITLE%'

=head1 SEE ALSO

L<BI:MCexltcs|collect::BI:MCexltcs>,
L<OFM:DCwreq|collect::OFM:DCwreq>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
