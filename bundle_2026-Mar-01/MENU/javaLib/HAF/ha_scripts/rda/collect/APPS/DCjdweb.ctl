# DCjdweb.ctl:540:Collects JD Edwards EnterpriseOne HTML Server Information
# $Id: DCjdweb.ctl,v 1.2 RDA Exp $
# ARCS: $Header: /RDA_8/src/scripting/lib/collect/APPS/DCjdweb.ctl,v 1.1 RDA Exp $
#
# Change History
# 20190122  PCW  Updated module description.
# 20181030  PCW  Initial version.

=head1 NAME

APPS:DCjdweb - Collects JD Edwards HTML Server Diagnostic Information

=head1 DESCRIPTION

This module collects JD Edwards HTML Server diagnostic information.
Only files which are not collected by the WebLogic Server module are
included here.

The following reports can be generated and are regrouped under
C<JD Edwards HTML Server>:

=cut

echo tput('bold'),'Processing APPS.JDWEB module ...',tput('off')

# Initialization
var $AGENT_HOME = ${D_AGENT_HOME}
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:JD Edwards HTML Server'

# Set the symbols
call setSymbol('$AGENT_HOME',$AGENT_HOME)

# Load the common macros
run RDA:library()

=head1 JD EDWARDS HTML SERVER INFORMATION

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the JD Edwards collection.

=cut

debug ' Inside JDWEB module, collecting defined abbreviations'
report abbr
prefix
{write '---+ JD Edwards Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 Server Manager Agent Configuration Files

Gathers Server Manager Agent configuration files.

=cut

debug ' Inside JDWEB module, getting Server Manager Agent config files'
var @tbl = ()
var $tgt = catDir($AGENT_HOME,'SCFHA','targets')
loop $sub (findDir($tgt,'^config$','npr','2'))
 call push(@tbl,grepDir($sub,'^[^\.]','np'))
pretoc '2:JDE Server Manager Agent Configuration Files'
call sort_files(3,0,@tbl)
unpretoc

=head1 ORACLE WEBLOGIC SERVER DOMAIN COLLECTIONS

Includes all reports produced by the L<abr:WREQ|collect::OFM:DCwreq> module
for the specified Oracle WebLogic Server domains.

=cut

# Analyze the domain requests
var %tbl = ()
loop $req (${CUR.O_SETUP}->search('^WREQ_APPS_JDWEB_DOM'))
{var $dom = $req->get_first('I_DOMAIN')
 if ?$dom->get_first('I_WL_HOME')
  var $tbl{last->get_oid,$req->get_oid} = $dom->get_first('T_DOMAIN_NAME')
 else
  var $tbl{'WH',$req->get_oid} = $dom->get_first('T_DOMAIN_NAME')
}

# Include the table of content files produced by WREQ
loop $oid (keys(%tbl))
{if $orp = compare('eq',$oid,'WH')
  toc '%PUSH("0:   * Orphan Domains")%'
 toc '%PUSH("%SPLIT%")%'
 toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
 toc '%INCLUDE("OFM_WREQ_APPS_JDWEB_',$oid,'_TF.toc")%'
 toc '%POP2%'
 loop $tid (keys($tbl = $tbl{$oid}))
 {toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:',"'",$tbl->{$tid},"'",' Domain")%'
  toc '%INCLUDE("OFM_',$tid,'_TF.toc")%'
  toc '%POP2%'
 }
 if $orp
  toc '%POP%'
}

unpretoc

=head1 SEE ALSO

L<OFM:DCwreq|collect::OFM:DCwreq>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
