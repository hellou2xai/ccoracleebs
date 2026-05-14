# $Id: Analyzer.pm 200.4 1:21 PM 2/28/2018 kjharris $
# +===========================================================================+
# |  Copyright (c) 2017 Oracle Corporation, Redwood Shores, California, USA  
# |  All rights reserved 
# |  Created by Oracle Support Proactive Services
# +===========================================================================+
# |
# | FILENAME: Analyzer.pm
# |
# | Creates an analyzer object out of an analyzer SQL so that the attribs of  
# | the analyzer can be easily accessed  
# | 
# | PLATFORM
# |   Unix Generic 
# |
# | NOTES
# |
# | HISTORY
# | 200.0 Creation (Nov-5-2014) 
# | 200.1 Updated to get Analyzer Update Date from SQL Header 
# | 200.2 Fix for 12.2 Product: 
# |           >=12.2.3: Product Hub
# |             <12.2.2: Advanced Product Catalog 
# | 200.3 Fix for 11i LDT specificity 
# | 200.4 Removed extra unneeded "get" sub 
# +===========================================================================+

package MENU::AnalyzerXML;
use File::Find;
use Cwd;
use File::Basename;

sub analyzer
{
  my $class = shift;
  my ($file) = @_; 
  my $analyzer = {@help, @menu, @fload, @deps ,@runOpts, $compat, $title, $defReqGrp, $prodTop, $prodShortName, $progTemplate, $CCPName, $fileVer, $CPFile, $appName, $fam, $headerDate}; 

  #because the user may toggle in & out of a menu, we need to undefine these vars 
  undef @menu;
  undef @fload;
  undef @help;
  undef @deps;
  undef @runOpts;
  #undef this otherwise the class holds the previous value of the last file where it was defined. 
  undef $CPFile; 
  my $relVer = getRelVer();
  my $countDepth = $file =~ tr/\///;
  #if the file passed was simply a file not a full path 
  
  if ($countDepth == 0 ) 
  {
    find( sub {return unless /\.xml$/; $file = $File::Find::name if "$file" eq "$_" }, 'analyzers/SQL' );
  }
  
  open (my $fh, '<', $file ) || die "AnalyzerXML.pm: Cannot open \'$file\' $! \n"; 
  my @a = <$fh>; 
  close $fh; 
  
  #FAM 
  $fam = 'ATG' if $file =~ /01_/;
  $fam = 'FIN' if $file =~ /02_/;
  $fam = 'MFG' if $file =~ /03_/;
  $fam = 'HCM' if $file =~ /04_/;
  $fam = 'CRM' if $file =~ /05_/;
  
  #12:41 PM 8/25/2017 
  #v. 200.1 changes 
  ($headerDate) = grep(/\$Id:.+?\s(\d{4}\/\d{2}\/\d{2})\s\d{2}/,@a);
  $headerDate = $+ if $headerDate =~ /\$Id:.+?\s(\d{4}\/\d{2}\/\d{2})\s\d{2}/;
  
  #version 
  ($fileVer) = grep(/<version>/,@a); 
  ($fileVer) = $+ if $fileVer =~ />(.+?)</;
  chomp($fileVer); 
  
  #Compat 
  # 7:02 AM 6/19/2019 
  # compatible_apps_release 
  ($compat) = grep(/\<compatible_apps_release\>/, @a);
  $compat = $+ if $compat =~ />(.+?)</;
  #remove spaces to match other "compat" output from .sql analyzer 
  $compat =~ s/\|/ /g; 
  chomp($compat); 
  
  #title
  ($title) = grep(/^<title>/, @a); 
  $title = $+ if $title =~ />(.+?)</;
  chomp($title); 
  
  #help (new design for HA XML Analyzer) 
  ($help) = grep(/<description>/, @a);
  $help = $+ if $help =~ />(.+?)</;
  formatHelp($help); 
  
  @menu = "JAVA: Run " . $title;
  
  #Output Type
  #8:53 AM 6/19/2019 not needed for HA 
  # ($outputType) = grep(/OUTPUT_TYPE:/, @a);
  # $outputType =~ s/^REM\s+OUTPUT_TYPE:\s*//g; 
  # chomp($outputType);

  #help #FNDLOAD Opts #Dependencies #Run Opts
  #commented entire section for HA  
  # for my $i (0 ..$#a) 
  # {  
    # if ($a[$i] =~ /MENU_START/) 
    # { $i++;
      # my $done = 'n';
      # until ( $a[$i] =~ /MENU_END/ )
      # {
        # $a[$i] = trim($a[$i]); 
        # ($i++, next) if length $a[$i] < 3;  
        # chomp($a[$i]); 
        
        ##if the length of the line is greater than 60 chars, insert a newline \n in the next space after 50 chars
        # my $count = 0;
        # my $string2; 
         
        # my @words; 
        # if (length($a[$i]) > 65) 
        # {
          # @words = split / /, $a[$i];
          # foreach my $word(@words)
          # {
            # $count += length($word);
            # $word .= " ";
            # if ($count > 55 && $done eq 'n')
            # {
              # $done = 'y';
              # $word .= "\n";
              # next;
            # }
            # if ($done eq 'y')
            # {
              # $word = '      ' . $word;
              # $done = 'DONE';
            # }
          # }
          # foreach (@words)
          # {
            # $string2 .= $_; 
          # } 
          # push @menu, $string2;
        # }
        # push @menu, $a[$i] if (length($a[$i]) <= 65); 
        # $i++; 
      # }
    # }
    
    # if ($a[$i] =~ /HELP_START/) 
    # { $i++;
      # until ( $a[$i] =~ /HELP_END/ )
      # {
        # $a[$i] = trim($a[$i]); 
        # ($i++, next) if length $a[$i] < 3; 
        # chomp($a[$i]); 
        # push @help, $a[$i]; 
        # $i++; 
      # }
    # }
      
 
    # if ($a[$i] =~ /FNDLOAD_START/) 
    # { $i++;
      # until ( $a[$i] =~ /FNDLOAD_END/ )
      # {
        # $a[$i] = trim($a[$i]); 
        # ($i++, next) if length $a[$i] < 3;
        # chomp($a[$i]); 
        # push @fload, $a[$i]; 
        # $i++; 
      # }
    # }
      
    # if ($a[$i] =~ /DEPENDENCIES_START/) 
    # { $i++;
      # until ( $a[$i] =~ /DEPENDENCIES_END/ )
      # {
        # $a[$i] = trim($a[$i]); 
        # ($i++, next) if length $a[$i] < 3;
        # chomp($a[$i]);
        ##strip the filename off the full path to use the full path for the dep file 
        # $a[$i] = dirname($file) . '/' . $a[$i];  
        # push @deps, $a[$i]; 
        # $i++; 
      # }
    # }
      
    # if ($a[$i] =~ /RUN_OPTS_START/) 
    # { $i++;
      # until ( $a[$i] =~ /RUN_OPTS_END/ )
      # {
      # $a[$i] = trim($a[$i]); 
      # ($i++, next) if length $a[$i] < 3;
      # chomp($a[$i]);
      # push @runOpts, $a[$i]; 
      # $i++; 
      # }
    # }
  # }

  #8:57 AM 6/19/2019 
  # not required for HA 
  # foreach my $line (@fload)
  # {
    # my ($param, $value)= split /:/, $line; 
    # $param=trim($param); 
    # $value=trim($value); 
    # $defReqGrp = $value if $param =~ /DEF_REQ_GROUP/; 
    # $prodTop = $value if $param =~ /PROD_TOP/; 
    # $prodShortName = $value if $param =~ /PROD_SHORT_NAME/;
    
    #3:19 PM 12/14/2017 
    # differentiate 11i LDT templates from R12: 
    # fixed in 200.3 
    # if ($relVer =~ /^12/) 
    # {
      # $progTemplate = $value if $param =~ /PROG_TEMPLATE$/;
    # }
    # else #11i 
    # {
      # $progTemplate = $value if $param =~ /PROG_TEMPLATE_11i/;
    # }
    
    # $CCPName = $value if $param =~ /PROG_NAME/;
    # $CPFile = $value if $param =~ /CP_FILE/;
    # $appName = $value if $param =~ /APP_NAME/;
    
    #Fix Development Bug in 12.2 with CRM: Install Base vs Installed Base
    # 12.2: Installed Base 
    # 12.1: Install Base     
    # if ($appName =~ /Install\w*\sBase/) 
    # {
      # if ($relVer =~ /^12\.2/) 
      # {
        # $appName = 'Installed Base';
      # }
      # else 
      # {
        # $appName = 'Install Base';
      # }
    # }
	#hack for Product Hub 
	# 12.2.3+: Product Hub
    # 12.2.2<: Advanced Product Catalog   
    # if ($appName eq 'Advanced Product Catalog' || $appName eq 'Product Hub') 
    # {
		# my ($maj, $min, $min1) = split(/\./, $relVer); 
		 # if ($maj == 12 && $min >= 2 && $min1 > 2)
		  # {
			# $appName = 'Product Hub';
		  # }
		  # else 
		  # {
			# $appName = 'Advanced Product Catalog';
		  # }
    # } #end Product Hub fix 
	
  # }
  bless $analyzer, $class; 
  return $analyzer; 
}

# +------------
# | sub getHeaderDate
# | 
# + ------------
sub getHeaderDate 
  {
    my( $analyzer ) = @_;
    return $headerDate; 
  }

# +------------
# | sub getFam
# | 
# + ------------
sub getFam 
  {
    my( $analyzer ) = @_;
    return $fam; 
  }


# +------------
# | sub getFileVer
# | 
# + ------------
sub getFileVer 
  {
    my( $analyzer ) = @_;
    return $fileVer; 
  }

# +------------
# | sub getFNDLOADOpts 
# | 
# + ------------
# sub getFNDLOADOpts 
  # {
    # my( $analyzer ) = @_;
    # return \@fload; 
  # }

# +------------
# | sub getCCPName
# | 
# + ------------
# sub getCCPName
  # {
    # my( $analyzer ) = @_;
    # return $CCPName;
  # }
  
# +------------
# | sub getReqGroup
# | 
# + ------------
# sub getReqGroup 
  # {
    # my( $analyzer ) = @_;
    # return $defReqGrp;
  # }
  
# +------------
# | sub getProdTop
# | 
# + ------------
sub getProdTop
  {
    my( $analyzer ) = @_;
    return $prodTop; 
  }
  
# +------------
# | sub getProgTemplate
# | 
# + ------------
# sub getProgTemplate
  # {
    # my( $analyzer ) = @_;
    # return $progTemplate; 
  # }
  
# +------------
# | sub getProdShortName
# | 
# + ------------
# sub getProdShortName
  # {
    # my( $analyzer ) = @_;
    # return $prodShortName; 
  # }
  
# +------------
# | sub getMenu
# | 
# + ------------
sub getMenu
  {
    my( $analyzer ) = @_;
    return \@menu;
  }

# +------------
# | sub getTitle
# | 
# + ------------
sub getTitle
  {
    my( $analyzer ) = @_;
    return $title;
  }
  
# +------------
# | sub getOutputType
# | 
# | Not required for HA 
# + ------------
# sub getOutputType
  # {
    # my( $analyzer ) = @_;
    # return $outputType;
  # }
  
# +------------
# | sub getCompat
# | 
# + ------------
sub getCompat
  {
    my( $analyzer ) = @_;
    return $compat;
  }
  
# +------------
# | sub getHelp
# | 
# | 11:13 AM 6/19/2019 
# | returning string vs "\@help" as in prev versions 
# + ------------
sub getHelp
  {
    my( $analyzer ) = @_;
    return $help; 
  }
  
# +------------
# | sub getDeps
# | 
# + ------------
sub getDeps
  {
    my( $analyzer ) = @_;
    return \@deps;  
  }
  
# +------------
# | sub getRunOpts
# | 
# + ------------
sub getRunOpts
  {
    my( $analyzer ) = @_;
    return \@runOpts; 
  }

# +------------
# | sub getCPFile
# | 
# + ------------
sub getCPFile
  {
    my( $analyzer ) = @_;
    return $CPFile; 
  }

# +------------
# | sub getAppName
# | 
# + ------------
sub getAppName 
{
  my( $analyzer ) = @_;
  return $appName; 
}
  
  
# +------------
# | sub trim
# | 
# + ------------
sub trim
{
  my ($v) = @_; 
  chomp($v); 
  $v =~ s/REM//ig; 
  $v =~ s/^\s+//g; 
  $v =~ s/\s+$//g;
  return $v; 
}


# +--------------------------------------------------------------------------+
# | sub: formatHelp 
# +--------------------------------------------------------------------------+
# | Desc: format help to have \n before 80 chars 
# +--------------------------------------------------------------------------+
# | Args: nebytiye
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+
sub formatHelp 
{
  my ($h) = @_; 
  my @arr = split //, $h;
  my $break = 0; 
  
  $h = ''; 
  my $cnt = 0; 
  foreach my $c (@arr) 
  {
    $cnt++; 
    $h = $h . $c; 
    
    if ($cnt % 67 == 0) 
    {
      $break = 1; 
    }
  
    if ($break && $c =~ /\s/) 
    {
      $break = 0; 
      $h = $h . "\n"; 
    }
  }
  $help = $h; 
}



# +---------------------------
# | sub getRelVer() 
# | Determine Release from Context File 
# +---------------------------
sub getRelVer
{
  my $contextFile = $ENV{"CONTEXT_FILE"}; 
  my $relVer; 
  open my $fh, '<', $contextFile or die "   ERROR: Could not open $contextFile: $!";

  while (<$fh>) 
    {
      $relVer = $1 if $_ =~ /s_apps_version\">(\d{2}.+)<\/config_option\>/;
      last if defined $relVer; 
    }
  close $fh; 

  #Validate Release Version 
  die "   ERROR: Unable to determine Release Version from Context File\n" if $relVer !~ /^11\.5|^12\.0|^12\.1|^12.2/;  
  return ($relVer); 
}
#END getRelVer 

1;

__END__ 
