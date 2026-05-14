# DCmcs.ctl:110:Collects Mobile Cloud Service Information
# $Id: DCmcs.ctl,v 1.1 RDA Exp $
# ARCS: $Header: /RDA_8/src/scripting/lib/collect/CLOUD/DCmcs.ctl,v 1.1 RDA Exp $
#
# Change History
# 20181128  PCW  Initial version.

=head1 NAME

CLOUD:DCmcs - Collects Mobile Cloud Service Information

=head1 DESCRIPTION

This module collects Mobile Cloud Service information.

The following reports can be generated and are regrouped under
C<Mobile Cloud Service>:

=cut

echo tput('bold'),'Processing CLOUD.MCS module ...',tput('off')

# Initialization
var $DOMAIN      = ${D_DOMAIN_HOME:''}
var $LOG_ROOT    = catDir('var','log')
var $TAIL        = ${DFT.N_TAIL:1000}
var $TOC         = '%TOC%'
var $TOP         = '[[#Top][Back to top]]'
pretoc '1:Mobile Cloud Service'

# Set the symbols
call setSymbol('$LOGS',$LOG_ROOT)

# Load the common macros
run RDA:library()

=head1 MOBILE CLOUD SERVICE COLLECTIONS

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Mobile Cloud Service collection.

=cut

debug ' Inside MCS module, collecting defined abbreviations'
report abbr
prefix
{write '---+ Mobile Cloud Service Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 Chef, Boot and OPC Guest Agent Log Files

Collects Mobile Cloud Service chef, boot and OPC guest agent log files.

=cut

debug ' Inside MCS module, collecting chef, boot and OPC guest agent log files'
pretoc '2:Chef, Boot and OPC Guest Agent Log Files'
call sort_files(3,$TAIL,grepDir\
  ($LOG_ROOT,'(chef\d*|.*opc.*|boot\d*)','dr',0))
unpretoc

=head2 OPC Log Files

Collects Mobile Cloud Service opc-init and opc-compute log files.

=cut

debug ' Inside MCS module, collecting the OPC log files'
pretoc '2:OPC Log Files'
call sort_files(3,$TAIL,\
  catFile($LOG_ROOT,'opc-init','opc-init.log'))
call sort_files(3,$TAIL,grepDir\
  (catDir($LOG_ROOT,'opc-compute'),'(.log\d*|.out\d*)','dr',0))
unpretoc

=head1 ORACLE WEBLOGIC SERVER DOMAIN COLLECTIONS

It includes all reports produced by the L<abr:WREQ|collect::OFM:DCwreq> module
for the specified Oracle WebLogic Server domains.

=cut

# Analyze the domain requests
var %tbl = ()
loop $req (${CUR.O_SETUP}->search('^WREQ_CLOUD_MCS_DOM'))
{var $dom = $req->get_first('I_DOMAIN')
 if ?$dom->get_first('I_WL_HOME')
  var $tbl{last->get_oid,$req->get_oid} = $dom->get_first('T_DOMAIN_NAME')
 else
  var $tbl{'WH',$req->get_oid} = $dom->get_first('T_DOMAIN_NAME')
}

# Include the table of content files produced by WREQ
loop $oid (keys(%tbl))
{toc '%PUSH("%SPLIT%")%'
 toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
 toc '%INCLUDE("OFM_WREQ_CLOUD_MCS_',$oid,'_TF.toc")%'
 toc '%POP2%'
 loop $tid (keys($tbl = $tbl{$oid}))
 {toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:',"'",$tbl->{$tid},"'",' Domain")%'
  toc '%INCLUDE("OFM_',$tid,'_TF.toc")%'
  toc '%POP2%'
 }
}

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
