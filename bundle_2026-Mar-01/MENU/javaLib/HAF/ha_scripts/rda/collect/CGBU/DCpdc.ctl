# DCpdc.ctl:492:Collects Oracle Communications Pricing Design Center Information
# $Id: DCpdc.ctl,v 1.7 2015/07/03 11:30:36 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCpdc.ctl,v 1.7 2015/07/03 11:30:36 RDA Exp $
#
# Change History
# 20150703  MSC  Improve the documentation.

=head1 NAME

CGBU:DCpdc - Collects Oracle Communications Pricing Design Center Information

=head1 DESCRIPTION

This module collects Oracle Communications Pricing Design Center-related
information. The following reports can be generated and are regrouped under
C<Pricing Design Center>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.PDC module ...',tput('off')

# Initialization
var $HOME = ${D_HOME:''}
var $TAIL = ${DFT.N_TAIL:1000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Pricing Design Center'

# Set the symbols
call setSymbol('$HOM',$HOME)

# Load the common macros
run RDA:library()

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Pricing Design Center home
collection.

=cut

debug ' Inside PDC module, collecting defined abbreviations'
report abbr
prefix
{write '---+ Pricing Design Center Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 Configuration Files

Gathers Pricing Design Center-related configuration files.

=cut

debug ' Inside PDC module, gathering configuration files'
pretoc '2:Configuration Files'
var $dir = catDir($HOME,'apps','transformation')
call cat_report($dir,'TransformationConfiguration.xml')
unpretoc

=head2 Log Files

Gathers Pricing Design Center-related log files.

=cut

debug ' Inside PDC module, gathering log files'
if ?testFile('fr',catFile($dir,'TransformationConfiguration.xml'))
{var (@dir,@tbl) = ()
 if xmlFind(xmlLoadFile(lastTestFile()),'Configuration/transformationLog')
 {var ($xml) = last
  if xmlFind($xml,'rreTransformLogFileLocation')
   call push(@dir,catDir(xmlData(last)))
  if xmlFind($xml,'breTransformLogFileLocation')
   call push(@dir,catDir(xmlData(last)))
 }

 # Get the log files
 loop $dir (@dir)
  call push(@tbl,grepDir($dir,'^\.+$','drv'))

 pretoc '2:Log Files'
 call sort_files(3,$TAIL,@tbl)
 unpretoc
}

=head2 Oracle WebLogic Server Domain Information

It includes all reports produced by the L<abr:WREQ|collect::OFM:DCwreq> module
for the specified Oracle WebLogic Server domain.

=cut

toc '%PUSH("%SPLIT%")%'
toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
toc '%INCLUDE("OFM_WREQ_CGBU_PDC_WH_TF.toc")%'
toc '%POP2%'
toc '%PUSH("%SPLIT%")%'
toc '%PUSH("1+:Oracle WebLogic Server Domain")%'
toc '%INCLUDE("OFM_WREQ_CGBU_PDC_DOM_TF.toc")%'
toc '%POP2%'

unpretoc

=head1 SEE ALSO

L<OFM:DCwreq|collect::OFM:DCwreq>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
