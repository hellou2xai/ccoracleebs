# MCexltcs.ctl:100:Performs Oracle Exalytics Multi-run Collections
# $Id: MCexltcs.ctl,v 1.2 2015/05/29 05:30:16 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/MCexltcs.ctl,v 1.2 2015/05/29 05:30:16 RDA Exp $
#
# Change History
# 20150527  KRA  Improve the documentation.

=head1 NAME

BI:MCexltcs - Performs Oracle Exalytics Multi-run Collections

=head1 DESCRIPTION

This module regroups multi-run collections specific to Oracle Exalytics.

=cut

use Mrc

# Initialization
var @ROOT_SECTIONS = ('EXLTCS_version')
keep @ROOT_SECTIONS

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

keep $TOC,$TOP

=head1 EXALYTICS MULTI-RUN COLLECTIONS

=head2 version - Version Information

Gets the version information using the F</usr/sbin/imageinfo> command.

=cut

section EXLTCS_version

if ?testFile('f',$cmd = '/usr/sbin/imageinfo')
{debug ' Inside EXLTCS module, getting version information'
 report version
 prefix
 {write '---+ Version Information'
  write '---## Using: ',encode($cmd)
 }
 call writeCommand($cmd)
 if isCreated(true)
 {call validate(true)
  write $TOP
  toc '2:[[',getFile(),'][rda_report][Version Information]]'
 }
}

=head1 SEE ALSO

L<BI:DCexltcs|collect::BI:DCexltcs>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
