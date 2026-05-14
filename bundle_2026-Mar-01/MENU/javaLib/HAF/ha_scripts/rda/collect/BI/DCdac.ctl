# DCdac.ctl:398:Collects Data Warehouse Administration Console Information
# $Id: DCdac.ctl,v 1.2 2013/10/30 07:18:22 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DCdac.ctl,v 1.2 2013/10/30 07:18:22 RDA Exp $
#
# Change History
# 20130111  KRA  Initial RDA 8 version.

=head1 NAME

BI:DCdac - Collects Data Warehouse Administration Console Information

=head1 DESCRIPTION

This module collects the Oracle Business Intelligence Data Warehouse
Administration Console-related diagnostic information.

The following reports can be generated and are regrouped under
C<Data Warehouse Administration Console>:

=cut

echo tput('bold'),'Processing BI.DAC module ...',tput('off')

# Initialization
var $DAC_HOME = ${D_HOME:''}
var $BI_HOME  = ${D_BI_HOME:''}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Data Warehouse Administration Console'

# Load the common macros
run RDA:library()

=head2 apps_version - Application Version Information

Gathers application version information.

=cut

debug ' Inside DAC module, getting application version information'
report apps_version
call cat_file(catDir($BI_HOME,'Document'),'version_apps.txt')
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Application Version Information]]'

=head2 Configuration Files

Gathers the following configuration files from F<$DAC_HOME/DAC> directory:

=over 3

=item o F<config.bat> (For Windows)

=item o F<dac_env.bat> (For Windows)

=item o F<config.sh> (For UNIX)

=item o F<dac_env.sh> (For UNIX)

=back

=cut

debug ' Inside DAC module, collecting the configuration files'
pretoc '2:Configuration Files'
var $dir = catDir($DAC_HOME,'DAC')
call sort_files(3,0,catFile($dir,'config.bat'),\
                    catFile($dir,'dac_env.bat'),\
                    catFile($dir,'config.sh'),\
                    catFile($dir,'dac_env.sh'))
unpretoc

=head2 Log Files

Gathers the following log files from F<$DAC_HOME/DAC/log> directory:

=over 3

=item o F<ServerTXT.log>

=item o F<ping.log>

=item o F<etl_summary.txt>

=item o Latest F<E<lt>numberE<gt>.log> file

=back

=cut

debug ' Inside DAC module, collecting the log files'
pretoc '2:Log Files'
var $dir = catDir($DAC_HOME,'DAC','log')
call sort_files(3,0,catFile($dir,'ServerTXT.log'),\
                    catFile($dir,'ping.log'),\
                    catFile($dir,'etl_summary.txt'),\
                    first(grepDir($dir,'^\d+\.log$','pt')))
unpretoc 2

=head1 SEE ALSO

L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
