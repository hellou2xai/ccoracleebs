use strict;
use English;
use Carp;

require 5.005;

use TXK::AutoConfig();
use TXK::Error();
use TXK::FileSys();
use TXK::IO();
use TXK::Log();
use TXK::OSD();
use TXK::Process();
use TXK::Restart();
use TXK::Runtime();
use TXK::Util();
use TXK::XML();
use TXK::AutoBuild();
use TXK::SQLPLUS();
use TXK::ARGS();
use TXK::Validate();

# MAIN

my $appscredpwd = $ENV{'APPSPASS'};
my $appscredusr = $ENV{'APPSUSER'};
my $appscred="$appscredusr/$appscredpwd";

#my $outp = `java oracle.apps.fnd.security.AdminSecurityCfg $appscred -status DBC=$ENV{FND_SECURE}/$ENV{TWO_TASK}.dbc`;

# Per BUG 25367526 - QREP1227.1: ENHANCE ADMINSECURITYCFG TO RUN NON-INTERACTIVELY
# for class AdminSecurityCfg.class older versions less than 120.0.12020000.11, use this command
#my $outp = `java oracle.apps.fnd.security.AdminSecurityCfg $appscred -status DBC=$ENV{FND_SECURE}/$ENV{TWO_TASK}.dbc`;
#my $outp = `java oracle.apps.fnd.security.AdminSecurityCfg $appscred@$ENV{TWO_TASK} -status DBC=$ENV{FND_SECURE}/$ENV{TWO_TASK}.dbc > MyAdminSecurityCfg.log`;


#for class AdminSecurityCfg.class newer versions grater than or equal to 120.0.12020000.11  use this command

#print "appsced: $appscred";

#my $outp = ` { echo ${appscred}; } | java oracle.apps.fnd.security.AdminSecurityCfg -check DBC=$ENV{FND_SECURE}/$ENV{TWO_TASK}.dbc -nopromptmsg > MyAdminSecurityCfg.log`;
system(" stty -echo; { printf \"${appscred}\"; } | java oracle.apps.fnd.security.AdminSecurityCfg -status DBC=$ENV{FND_SECURE}/$ENV{TWO_TASK}.dbc -nopromptmsg > MyAdminSecurityCfg.log");

#print "this is the oput:\n";
#print "$outp\n";
