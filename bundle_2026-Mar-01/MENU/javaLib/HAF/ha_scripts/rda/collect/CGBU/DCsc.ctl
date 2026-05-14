# DCsc.ctl:497:Collects Oracle Communications Service Controller Information
# $Id: DCsc.ctl,v 1.10 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCsc.ctl,v 1.9 2015/08/21 16:15:16 RDA Exp $
#
# Change History
# 20230314  DXM  Remove jar and zip extensions from add_report specifications.
# 20150821  MSC  Improve time consistency.

=head1 NAME

CGBU:DCsc - Collects Oracle Communications Service Controller Information

=head1 DESCRIPTION

This module collects Oracle Communications Service Controller-related
information.

The following reports can be generated and are regrouped under C<Service
Controller>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.SC module ...',tput('off')

# Initialization
var $HOME = ${D_HOME:''}
var $TAIL = ${DFT.N_TAIL:1000}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Service Controller'

# Set the symbols
call setSymbol('$HOM',$HOME)

# Load the common macros
run RDA:library()

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Service Controller home
collection.

=cut

debug ' Inside SC module, collecting defined abbreviations'
report abbr
prefix
{write '---+ Service Controller Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 alias - Alias Information

Gathers aliases defined in an interactive shell.

=cut

if ?shell()
{var $cmd = concat(last,' -ic alias')
 debug ' Inside SC module, gathering alias information'
 report alias
 prefix
  write '---+ Alias Information'
 call writeCommand({cmd=>$cmd,flg=>true})
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Alias Information]]'
}

=head2 Start Scripts

Gathers Service Controller-related start scripts.

=cut

debug ' Inside SC module, gathering start scripts'
pretoc '2:Start Scripts'
call sort_files(3,0,grepDir($HOME,'(common|host|start).*?\.sh$','dir'))
unpretoc

=head2 Configuration Files

Gathers Service Controller-related configuration files.

=cut

debug ' Inside SC module, gathering configuration files'
var @cfg = ()
loop $fil (grepDir($HOME,'\.(properties|xml)$','dir'))
{next match($fil,'\bmissioncontrol\b',true)
 next match($fil,'\/jre\/lib\/',true)
 next match($fil,'\/(da|hcve)\/')
 call push(@cfg,$fil)
}
pretoc '2:Configuration Files'
call sort_files(3,0,@cfg)
unpretoc

=head2 cfg_bundle - Configuration Bundle

Gathers Service Controller-related configuration bundled files.

=cut

debug ' Inside SC module, gathering configuration bundled files'
report cfg_bundle
prefix
{write '---+ Configuration Bundled Files'
 write '   * Links point to files that have been collected in their original \
             format. Opening them directly in your browser can present \
             risks. To prevent them, access the file outside the browser or \
             use the link to save them and use an adequate viewer.'
 write '|*File Name*| *Size*|*Last Modified Date*|'
}
loop $fil (grepDir($HOME,'^oracle\.axia\.cm\.config-.*?\.jar$','dr'))
{var $lnk = encode($fil)
 if $siz = getSize($fil)
 {var $rpt = $[OUT]->add_report('d',basename($fil,'.jar'),0)
  if $rpt->write_data($fil)
   var $lnk = concat('[[',$rpt->get_raw(true),'][_blank][',$lnk,']]')
  end $rpt
 }
 write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Configuration Bundle]]'

=head2 Log Files

Gathers Service Controller-related log files.

=cut

debug ' Inside SC module, gathering log files'
var @log = ()
loop $fil (grepDir($HOME,'\.log$','dir'))
{next compare('eq',basename($fil),'RDA.log')
 call push(@log,$fil)
}
pretoc '2:Log Files'
call sort_files(3,$TAIL,@log)
unpretoc

=for stopwords Init init

=head2 dom_initfiles - Domain Init Files

Gathers Service Controller-related domain init files.

=cut

debug ' Inside SC module, collecting domain init files'
report dom_initfiles
prefix
{write '---+ Domain Init Files'
 write '   * Links point to files that have been collected in their original \
             format. Opening them directly in your browser can present \
             risks. To prevent them, access the file outside the browser or \
             use the link to save them and use an adequate viewer.'
 write '|*File Name*| *Size*|*Last Modified Date*|'
}
loop $fil (grepDir($HOME,'^initial\.zip$','dr'))
{var $lnk = encode($fil)
 if $siz = getSize($fil)
 {var $rpt = $[OUT]->add_report('d',basename($fil,'.zip'),0,'.zip')
  if $rpt->write_data($fil)
   var $lnk = concat('[[',$rpt->get_raw(true),'][_blank][',$lnk,']]')
  end $rpt
 }
 write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Domain Init Files]]'

unpretoc

=head1 SEE ALSO

L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
