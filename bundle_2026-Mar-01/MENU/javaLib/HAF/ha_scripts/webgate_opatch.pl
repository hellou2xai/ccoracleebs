
my $oh = $ARGV[0];
my $option = $ARGV[1];

my @patchList = ( 33290860, 31710235, 29309637, 29170743, 27953548,
    27393427,26999492, 26540269, 25753018, 25491910, 24916846, 24323167, 22595401, 21118593);
my @patchLevel = (15, 14, 13, 12, 11, 10,9, 8, 7, 6, 5, 4, 2, 1);
my @patchType = ("W", "W", "W", "W", "W", "E", "E", "E", "E", "E", "E", "E", "E");
my @bundle = ('11.1.2.3.210825 (BP15) Webgate', '11.1.2.3.200804 (BP14) Webgate', '11.1.2.3.190204 (BP13) Webgate','11.1.2.3.190103 (BP12) Webgate', '11.1.2.3.180717 (BP11) Webgate',
              '11.1.2.3.180417 (BP10) Webgate', '11.1.2.3.180116 (BP09) Webgate', '11.1.2.3.171017 (BP08) Webgate', '11.1.2.3.170718 (BP07) Webgate',
              '11.1.2.3.170418 (BP06) Webgate', '11.1.2.3.170117 (BP05) Webgate', '11.1.2.3.161018 (BP04) Webgate', '11.1.2.3.160419 (BP02) Webgate',
              '11.1.2.3.1 (BP01) Webgate');

my $topLevel=0;
$ENV{ORACLE_HOME}=$oh;
my $patchCheck="$ENV{ORACLE_HOME}/OPatch/opatch lspatches";

my $applied=`$patchCheck`;
#print "cmd o/p: $applied\n";

my $wgPatchFile="wg_opatch_w.txt";
my $lastLine = 4;

if ($option eq "E") {
  $wgPatchFile="wg_opatch_e.txt";
  $lastLine = 12;
}

open(my $fh, '>', $wgPatchFile) or die $!;

my $i=0;
my $tail =" union all";

for(@patchLevel){
  my $ind = $_;
  my $patch=$patchList[$i];
  my $level=$patchLevel[$i];
  my $type=$patchType[$i];
  my $bundleName = $bundle[$i];

  if ($i==$lastLine) {
    $tail ="";
  }
  if( $applied =~ /$patch/ && $level>$topLevel ){
    $topLevel=$level;
  }

  if( $applied =~ /$patch/ && $type eq $option){
    print $fh "select $patch patch_number, 'applied' patch_status, '$bundleName' Bundle from dual $tail ";
  }
  elsif ($topLevel>$level && $type eq $option) {
    print $fh "select $patch patch_number, 'applied' patch_status, '$bundleName' Bundle from dual $tail ";
  }
  elsif ( $type eq $option ) {
    
    print $fh "select $patch patch_number, 'NOT applied' patch_status, '$bundleName' Bundle from dual $tail ";
  }

  $i++;
}
close $fh;
