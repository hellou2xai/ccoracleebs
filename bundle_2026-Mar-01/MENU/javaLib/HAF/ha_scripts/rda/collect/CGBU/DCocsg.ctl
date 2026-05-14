# DCocsg.ctl:501:Collects Oracle Communications Service Gatekeeper Information
# $Id: DCocsg.ctl,v 1.7 2015/07/03 11:30:36 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCocsg.ctl,v 1.7 2015/07/03 11:30:36 RDA Exp $
#
# Change History
# 20150703  MSC  Improve the documentation.

=head1 NAME

CGBU:DCocsg - Collects Oracle Communications Service Gatekeeper Information

=head1 DESCRIPTION

This module collects Oracle Communications Service Gatekeeper-related
information. The following reports can be generated and are regrouped under
C<Service Gatekeeper>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.OCSG module ...',tput('off')

# Initialization
var $DOMAIN = ${D_DOMAIN_HOME:''}
var $HOME   = ${D_HOME:''}
var $TAIL   = ${DFT.N_TAIL:1000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Service Gatekeeper'

# Set the symbols
call setSymbol('$DOM',$DOMAIN)
call setSymbol('$MH',cleanPath([$HOME,upDir(),''],true))
call setSymbol('$OCSG_HOME',$HOME)

# Load the common macros
run OFM:WLSlib()
run RDA:INVinfo()
run RDA:library()

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Service Gatekeeper home
collection.

=cut

debug ' Inside OCSG module, collecting defined abbreviations'
report abbr
prefix
{write '---+ Service Gatekeeper Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 product_info - Product Information

Gathers the product information when it is available.

=cut

if ?testDir('d',catDir($HOME,'inventory'))
{debug ' Inside OCSG module, processing Product Information (can take time)'
 report product_info
 prefix
 {write '---+!! Oracle Communications Service Gatekeeper Product Information'
  write '---## From ',encode($HOME),' '
  write $TOC
 }
 call inventory_details(lastDir(),true)
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Product Information]]'
}

=head2 Patches Information

Gathers the patches information.

=cut

debug ' Inside OCSG module, getting patches information (can take time)'
pretoc '2:Patches Information'
call dsp_manifest(3,[grepDir(catDir($HOME,'applications'),'\.ear$','inp')])
unpretoc

=head2 Configuration Files

Gathers Service Gatekeeper-related configuration files.

=cut

debug ' Inside OCSG module, gathering configuration files'
pretoc '2:Configuration Files'
call cat_report(catDir($HOME,'server','bin'),'build.xml')
unpretoc

=head2 Application Files

Gathers all C<*.ear> files and C<*.jar> files located in the common directory.

=cut

debug ' Inside OCSG module, gathering the application files'
pretoc '2:Application Files'
call sort_all_files(3,0,\
  grepDir(catDir($HOME,'applications'),'\.[ej]ar$','dir'),\
  grepDir(cleanPath([$HOME,upDir(),'modules',''],true),'\.[ej]ar$','dir'),\
  grepDir(catDir($DOMAIN,'config','store_schema'),'\.[ej]ar$','dir'))
unpretoc

=head2 Oracle WebLogic Server Domain Information

It includes all reports produced by the L<abr:WREQ|collect::OFM:DCwreq> module
for the specified Oracle WebLogic Server domain.

=cut

toc '%PUSH("%SPLIT%")%'
toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
toc '%INCLUDE("OFM_WREQ_CGBU_OCSG_WH_TF.toc")%'
toc '%POP2%'
toc '%PUSH("%SPLIT%")%'
toc '%PUSH("1+:Oracle WebLogic Server Domain")%'
toc '%INCLUDE("OFM_WREQ_CGBU_OCSG_DOM_TF.toc")%'
toc '%POP2%'

unpretoc

=head1 SEE ALSO

L<OFM:DCwreq|collect::OFM:DCwreq>,
L<OFM:WLSlib|collect::OFM:WLSlib>,
L<RDA:INVinfo|collect::RDA:INVinfo>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
