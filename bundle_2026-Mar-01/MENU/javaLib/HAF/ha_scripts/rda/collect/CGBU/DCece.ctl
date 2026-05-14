# DCece.ctl:500:Collects Elastic Charging Engine Information
# $Id: DCece.ctl,v 1.5 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCece.ctl,v 1.4 2015/08/21 16:15:16 RDA Exp $
#
# Change History
# 20230314  DXM  Remove jar and zip extensions from add_report specifications.
# 20150821  MSC  Improve time consistency.

=head1 NAME

CGBU:DCece - Collects Elastic Charging Engine Information

=head1 DESCRIPTION

This module collects information related to Oracle Communications Elastic
Charging Engine.

The following reports can be generated and are regrouped under C<Elastic
Charging Engine>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.ECE module ...',tput('off')

# Initialization
var $ALL   = ${B_ALL_LOG:false}
var $HOME  = ${D_HOME:${SET.RDA.BEGIN.D_ORACLE_HOME}}
var @EXTRA = @{D_EXTRA}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Elastic Charging Engine'

=for stopwords infoCollector

=head2 info_collector - infoCollector Results

Gathers Oracle Communications Elastic Charging Engine-related configuration and
log files information using C<infoCollector>.

=cut

debug ' Inside ECE module, collecting the configuration and log files'
if ?testFile('fx',catFile($HOME,'bin','ecc'))
{ var ($flg,$ext) = (false)

 # Set the required environment
 if ?${SYS.GROOVY_HOME}
 {if ?isRestricted(catDir(last,'bin'))
   var $flg = unshift(@{SYS.PATH},last)
 }
 elsif findDir(${ENV.HOME},'^groovy-','fp')
 {if ?isRestricted(catDir(first(last),'bin'))
   var $flg = unshift(@{SYS.PATH},last)
 }

 # Perform the collection using ecc shell
 var $box = getGroupDir('D_CWD',cleanBox())
 if @EXTRA
  var $ext = concat('-e ',join(',',map(@EXTRA,code(quote(determine(last))))))
 output | concat('(cd ',quote(catDir($HOME,'bin')),' && ./ecc) >/dev/null 2>&1')
 write join(' ','infoCollector','-d',quote($box),cond($ALL,'-l'),$ext)
 write 'exit'
 close
 report info_collector
 prefix
 {write '---+ Elastic Charging Engine Configuration and Log Files'
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              risks. To prevent them, access the file outside the browser or \
              use the link to save them and use an adequate viewer.'
  write '|*File Name*| *Size*|*Last Modified Date*|'
 }
 if grepDir($box,'^info_collector\.','f')
 {var ($nam) = last
  var $lnk = encode($nam)
  var $siz = getSize($fil = catFile($box,$nam))
  var $rpt = $[OUT]->add_report('d',basename($fil,'.tar.gz'),0)
  if $rpt->write_data($fil,['C','echo infoCollector | ./ecc'])
   var $lnk = concat('[[',$rpt->get_raw(true),'][_blank][',$lnk,']]')
  end $rpt
  write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
 }
 call cleanBox()
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][infoCollector Results]]'

 # Restore the previous environment
 if $flg
  call shift(@{SYS.PATH})
}

unpretoc

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
