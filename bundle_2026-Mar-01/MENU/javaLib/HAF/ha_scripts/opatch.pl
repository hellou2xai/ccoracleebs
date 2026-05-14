
my $oh = $ARGV[0];

$ENV{ORACLE_HOME}=$oh;
my $patchCheck="$ENV{ORACLE_HOME}/OPatch/opatch lsinventory";

my $applied=`$patchCheck`;

print $applied;
