# DCinfa.ctl:396:Collects Informatica Information
# $Id: DCinfa.ctl,v 1.5 2015/05/29 05:23:59 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DCinfa.ctl,v 1.5 2015/05/29 05:23:59 RDA Exp $
#
# Change History
# 20150527  KRA  Improve the documentation.

=head1 NAME

BI:DCinfa - Collects Informatica Information

=head1 DESCRIPTION

This module collects the Informatica-related information for Oracle Business
Intelligence Applications.

The following reports can be generated and are regrouped under C<Informatica>:

=cut

echo tput('bold'),'Processing BI.INFA module ...',tput('off')

# Initialization
var $INFA_HOME   = ${D_HOME:''}
var $INFA_DOMAIN = ${T_DOMAIN}
var $INFA_USER   = ${T_USER}
var $INFA_REPOS  = ${T_REPOSITORY}
var $TAIL        = ${DFT.N_TAIL:1000}

var $MOD = cond(isUnix(),'fx','f')
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

pretoc '1:Informatica'

# Load the common macros
run RDA:library()

=head2 domain_log - Domain Log

Collect domain log using the command F<$INFA_HOME/server/bin/infacmd.sh> for
UNIX and F<$INFA_HOME\server\bin\infacmd.bat> for Windows.

=cut

if and($INFA_DOMAIN,\
       $INFA_USER,\
       testFile($MOD,catFile($INFA_HOME,'server','bin',${AS.BAT:'infacmd'})))
{var $pgm = lastCommand()
 var $PWD = ['host','BI:INFA',$INFA_USER,\
   "Enter the Administration Console password for user ${VAR.INFA_USER}:",'']
 report domain_log
 var $cmd = concat($pgm,' getlog -dn ',quote($INFA_DOMAIN),' -un ',\
                   quote($INFA_USER),' -pd %s -fm TEXT -ro')
 prefix
 {write '---+!! Domain Log Information'
  write '---## Using: infacmd getlog'
 }
 call writeCommand({cmd => $cmd,pwd => $PWD})
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Domain Log]]'

=head2 service_log - Repository Service Log

Collect repository service log using the command
F<$INFA_HOME/server/bin/infacmd.sh> for UNIX and
F<$INFA_HOME\server\bin\infacmd.bat> for Windows.

=cut

 if $INFA_REPOS
 {report service_log
  var $cmd = concat($pgm,' getlog -dn ',quote($INFA_DOMAIN),' -un ',\
                    quote($INFA_USER),' -pd %s -fm TEXT -ro -st RS -sn ',\
                    quote($INFA_REPOS))
  prefix
  {write '---+!! Repository Service Log Information'
   write '---## Using: infacmd getlog'
  }
  call writeCommand({cmd => $cmd,pwd => $PWD})
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Repository Service Log]]'
 }
}

=head2 Workflow Logs

Gathers F<$INFA_HOME/server/infa_shared/WorkflowLogs/*.log> files.

=cut

debug ' Inside INFA module, collecting the workflow log files'
pretoc '2:Workflow Logs'
call sort_files(3,$TAIL,\
  grepDir(catDir($INFA_HOME,'server','infa_shared','WorkflowLogs'),'\.log$',\
          'ip'))
unpretoc

=head2 Session Logs

Gathers F<$INFA_HOME/server/infa_shared/SessLogs/*.log> files.

=cut

debug ' Inside INFA module, collecting the session log files'
pretoc '2:Session Logs'
call sort_files(3,$TAIL,\
  grepDir(catDir($INFA_HOME,'server','infa_shared','SessLogs'),'\.log$','ip'))
unpretoc

=head2 Tomcat Logs

Collects the F<catalina.out>, F<exceptions.log>, F<node.log>, and
F<localhost_log> files from the F<$INFA_HOME/server/tomcat/logs> directory.

=cut

debug ' Inside INFA module, collecting the tomcat log files'
if ?nvl(testDir('d',catDir($INFA_HOME,'tomcat')),\
        testDir('d',catDir($INFA_HOME,'server','tomcat')))
{var $dir = last
 pretoc '2:Tomcat Logs'
 call sort_files(3,$TAIL,\
   catFile($dir,'logs','catalina.out'),\
   catFile($dir,'logs','exceptions.log'),\
   catFile($dir,'logs','node.log'),\
   grepDir(catDir($dir,'logs'),'^localhost_log.*\.txt$','ipt'))
 unpretoc
}

unpretoc

=head1 SEE ALSO

L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut

