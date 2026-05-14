# DCocomc.ctl:498:Collects Offline Mediation Controller Information
# $Id: DCocomc.ctl,v 1.5 2014/03/07 08:33:40 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCocomc.ctl,v 1.5 2014/03/07 08:33:40 RDA Exp $
#
# Change History
# 20140307  KRA  Improve description.

=head1 NAME

CGBU:DCocomc - Collects Offline Mediation Controller Information

=head1 DESCRIPTION

This module collects information related to Oracle Communications Offline
Mediation Controller.

The following reports can be generated and are regrouped under C<Offline
Mediation Controller>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.OCOMC module ...',tput('off')

# Initialization
var $HOME = ${D_HOME:catDir(${SET.RDA.BEGIN.D_ORACLE_HOME},'ocomc')}
var $TAIL = ${N_TAIL:1000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Offline Mediation Controller'

# Load the common macros
run RDA:library()

=head2 Log Files

Gathers Oracle Communications Offline Mediation Controller-related log files.

=cut

debug ' Inside OCOMC module, collecting the log files'
pretoc '2:Log Files'
call sort_files(3,$TAIL,grepDir(catDir($HOME,'log'),'\.lck$','drv'))
unpretoc 2

=head1 SEE ALSO

L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
