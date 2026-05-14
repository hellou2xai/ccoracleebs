#!/usr/bin/perl
#use warnings;
use strict;

my $scriptName = $ARGV[0];
my $out_file = "ha_scripts/" . $scriptName . ".out";
my $summaryFile = "ha_scripts/" . $scriptName . "_CheckSummary.txt";
my $phase="NONE";
my @linesForRule;
my $lineCnt;
my $ruleName;
my $rowsCnt;

print "\n================================================================\n";

#my $APPSCRED=$ARGV[0];
#my $SQLOUT=`(echo '%'; echo '10';) | sqlplus $APPSCRED @$ENV{'FND_TOP'}/sql/afffcdff.sql`;
#system("(echo '%'; echo '10';) | sqlplus $APPSCRED \@$ENV{'FND_TOP'}/sql/afffcdff.sql");

open(my $opH, '>', $summaryFile) or die $!;

  open(FH, '<', $out_file) or die $!;
  
  while(<FH>){
    my $line = $_;
    my $iter=0;

    my $line2 = uc $line;

    if ($line =~ /^= (Rule [A-Z]\.[0-9]+)/) {
      $phase="COLLECT";
      @linesForRule = ();
      $lineCnt=0;

      $ruleName = $1;
    }

    if (($phase eq "COLLECT") && ($line =~ /^=/))  {
      $lineCnt++;
      $linesForRule[ $lineCnt ] = $line;
    }

    if (($phase eq "COLLECT") && ($line =~ /(?i)([0-9]+)\s+rows?\s+selected/)) {  
      $phase="NONE";
      $lineCnt++;
      $linesForRule[ $lineCnt ] = $line;

      $rowsCnt = $1;

      print $opH "============= $ruleName: $rowsCnt rows ===============\n";
      for(@linesForRule){
        my $prLine = $_;
        print $opH "$prLine";
      }
      print $opH "\n";
    }
    if ($line =~ /^no rows\sselected/) {
      $phase="NONE";
    }

  }
  close(FH);

close $opH;

