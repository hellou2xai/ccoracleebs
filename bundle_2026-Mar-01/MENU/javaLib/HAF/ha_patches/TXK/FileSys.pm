
# +===========================================================================+
# |   Copyright (c) 2003 Oracle Corporation, Redwood Shores, California, USA
# |                         All Rights Reserved
# |                        Applications Division
# +===========================================================================+
# |
# | FILENAME
# |   FileSys.pm
# |
# | DESCRIPTION
# |      TXK FileSys package
# |
# | USAGE
# |       See FileSys.html
# |
# | PLATFORM
# |
# | NOTES
# |
# +===========================================================================+

# $Header: FileSys.pm 120.0.12020000.2 2014/10/30 10:33:29 sbandla ship $

package TXK::FileSys;

@ISA = qw( TXK::Common );

######################################
# Standard Modules
######################################

use strict;
use English;
use Carp;

require 5.005;

######################################
# Package Specific Modules
######################################

use TXK::Common();
use TXK::Error();
use TXK::Util();
use TXK::IO();
use TXK::OSD();

######################################
# Public Constants
######################################

use constant READ_ACCESS 	=> 0;
use constant CREATE_ACCESS 	=> 1;
use constant WRITE_ACCESS 	=> 2;

use constant FILE               => 10;
use constant DIRECTORY		=> 20;

use constant NO_IDENT           => "<<NO_IDENT>>";
use constant MULTIPLE_IDENTS    => "<<MULTIPLE_IDENTS>>";

use constant IDENT_VERSION      => "version";
use constant IDENT_NAME         => "name";


######################################
# Private Constants
######################################

use constant ACCESS_CHECK_ONLY  => 0;
use constant CREATE_ON_ACCESS   => 1;

use constant DEFAULT_PATTERN    => "Header";

######################################
# Package Variables 
######################################

my $PACKAGE_ID = "TXK::FileSys";

######################################
# Object Keys
######################################

my $SOURCE_FILE    = "source";
my $DEST_FILE      = "dest";
my $SOURCE_DIR     = "source";
my $DEST_DIR       = "dest";
my $APPEND         = "append";
my $BUFFER_SIZE    = "bufferSize";
my $ACCESS_FILE	   = "fileName";
my $ACCESS_DIR 	   = "dirName";
my $ACCESS_TYPE	   = "type";
my $ACCESS_CHECK   = "checkMode";
my $ACCESS_FILETAB = "fileTable";
my $ACCESS_DIRTAB  = "dirTable";
my $DEFAULT_CALLER_LEVEL
		   = "defaultCallerLevel";
my $IDENT_PATTERN  = "pattern";
my $IDENT_DATA     = "identData";
my $RECURSIVE_COPY = "recursive";
my $ABORT_FLAG     = "abortFlag";

######################################
#
# Object Structure
# ----------------
#
#  Hash Array
#
######################################

######################################
# Package Methods 
#
# Public
#
#	new 	- build empty object
#
######################################

sub new;
sub DESTROY;
sub copy;
sub copydir;
sub access;
sub create;
sub ident;
sub findFile;
sub getDirList;
sub rmdir;
sub rmfile;
sub isDirectory;
sub isSymLink;

######################################
# Package Methods
# 
# Private
#       All private methods are marked with a leading underscore.
#
######################################

sub _do_access;

######################################
# Constructor
######################################

sub new {
  my $type = $ARG[0];

  my $self = TXK::Common->new();
 
  bless $self, $PACKAGE_ID ;

  my $key;

  my %INIT_OBJ = (
                   PACKAGE_IDENT   	=> $PACKAGE_ID,
	           $SOURCE_FILE		=> undef,
                   $DEST_FILE		=> undef,
		   $APPEND		=> TXK::Util::FALSE,
	           $RECURSIVE_COPY 	=> TXK::Util::FALSE,
	           $BUFFER_SIZE		=> 4096,
		   $DEFAULT_CALLER_LEVEL=> 3,
                  );

  foreach $key (keys %INIT_OBJ)
   {
     $self->{$key} = $INIT_OBJ{$key};
   }

  return $self;
}

######################################
# Destructor
######################################

sub DESTROY
{
}

######################################
# copy
######################################

sub copy
{   
  my $self  = $ARG[0];
  my $args  = $ARG[1];

  TXK::Util->isValidObj({obj=>$self,package=>$PACKAGE_ID,args=>$args});

  TXK::Util->isValidArgs({args=>$args,reqd=>["$SOURCE_FILE","$DEST_FILE"]});

  $self->{$SOURCE_FILE} = $args->{$SOURCE_FILE};
  $self->{$DEST_FILE}   = $args->{$DEST_FILE};
  $self->{$APPEND}      = TXK::Util::FALSE;

  my $key;

  foreach $key ("$APPEND")
   {
     $self->{$key} = ( exists $args->{$key}
                          ? TXK::Util->getBooleanArg($key,$args->{$key})
                          : $self->{$key}
                     );
   }

  $self->access({ fileName=>$self->{$DEST_FILE},
                  type=>TXK::FileSys::FILE,
                  checkMode=>TXK::FileSys::CREATE_ACCESS,
                }) 
         or return $self->setError("No create access for $self->{$DEST_FILE}");

  $self->access({ fileName=>$self->{$SOURCE_FILE},
                  type=>TXK::FileSys::FILE,
                  checkMode=>TXK::FileSys::READ_ACCESS,
                })
         or return $self->setError("No read access for $self->{$SOURCE_FILE}");

  my $fileAge = -M $self->{$SOURCE_FILE};
  my $isINST_TOP = 0;
  if ($self->{$SOURCE_FILE} =~ /^$ENV{INST_TOP}/ )
  {
    $isINST_TOP=1;
  }

  if ((! defined $PSDGlobalVars::psdFileAgeThreshold) || (! $isINST_TOP) || ($fileAge <= $PSDGlobalVars::psdFileAgeThreshold))
  {
    #print "$self->{$SOURCE_FILE} - age:$fileAge, isINST_TOP:$isINST_TOP, psdFileAgeThreshold:$PSDGlobalVars::psdFileAgeThreshold\n";

#	All OK , so create the target file in case we need intermediate
#	directories.

  $self->create({ fileName=>$self->{$DEST_FILE},
                  type=>TXK::FileSys::FILE,
                })
         or return $self->setError("Cannot create $self->{$DEST_FILE}");

  _setBufferSize($self,$args->{$BUFFER_SIZE}) 
			if (exists($args->{$BUFFER_SIZE}));

  my $src_io = TXK::IO->new();
  my $dest_io= TXK::IO->new();
  my $buffer;

  $src_io->open({ mode => TXK::IO::READ,
                  binaryMode => "true",
                  fileName => $self->{$SOURCE_FILE}
                });

  $dest_io->open({mode => ($self->{$APPEND} ? TXK::IO::APPEND : TXK::IO::WRITE),
                  binaryMode => "true",
                  fileName => $self->{$DEST_FILE}
                });

#	The default for the src/dest IO objects is to abortOnError.
#	If this is disabled, then the while loop needs to distinguish
#	between (0 - EOF) and (undef - ERROR)

  $dest_io->print($buffer)
      while ( $src_io->read({ IOBUFFER=>\$buffer, 
                              bufferSize=>$self->{$BUFFER_SIZE} } ) );

#
#	Set permissions
#

  $dest_io->chmod($src_io->getmod()) unless ( $self->{$APPEND} );

  $src_io->close();
  $dest_io->close();
  }

  return TXK::Error::SUCCESS;
}                  

######################################
# copydir
######################################

sub copydir
{   
  my $self  = $ARG[0];
  my $args  = $ARG[1];

  TXK::Util->isValidObj({obj=>$self,package=>$PACKAGE_ID,args=>$args});

  TXK::Util->isValidArgs({args=>$args,reqd=>["$SOURCE_DIR","$DEST_DIR"]});

  $self->{$SOURCE_DIR} = TXK::Util->getScalarArg($SOURCE_DIR,
                                                 $args->{$SOURCE_DIR});
  $self->{$DEST_DIR}   = TXK::Util->getScalarArg($DEST_DIR,
                                                 $args->{$DEST_DIR});
  $self->{$RECURSIVE_COPY}  = TXK::Util::FALSE;

  my $key;

  foreach $key ("$RECURSIVE_COPY")
   {
     $self->{$key} = ( exists $args->{$key}
                          ? TXK::Util->getBooleanArg($key,$args->{$key})
                          : $self->{$key}
                     );
   }

  $self->access({ dirName=>$self->{$DEST_DIR},
                  type=>TXK::FileSys::DIRECTORY,
                  checkMode=>TXK::FileSys::WRITE_ACCESS,
                }) 
         or return $self->setError("No create access for $self->{$DEST_DIR}");

  $self->access({ dirName=>$self->{$SOURCE_DIR},
                  type=>TXK::FileSys::DIRECTORY,
                  checkMode=>TXK::FileSys::READ_ACCESS,
                })
         or return $self->setError("No read access for $self->{$SOURCE_DIR}");

#
#	Do the copy
#

  return _docopydir($self,$self->{$SOURCE_DIR},$self->{$DEST_DIR},
                    $self->{$RECURSIVE_COPY},0);
}                  
######################################
# create
###################################### 

sub create
{
  my $self  = $ARG[0];
  my $args  = $ARG[1];

  my $type;

  TXK::Util->isValidObj({obj=>$self,package=>$PACKAGE_ID,args=>$args});

  TXK::Util->isValidArgs({args=>$args,reqd=>[]});

  $type = TXK::FileSys::FILE;

  $type = $args->{$ACCESS_TYPE} if ( exists($args->{$ACCESS_TYPE}) );

  return $self->setError("$ACCESS_TYPE must be either FILE or DIRECTORY")
                     unless (  $type == TXK::FileSys::FILE ||
                               $type == TXK::FileSys::DIRECTORY 
                            );

  if ( $type == TXK::FileSys::FILE )
   {
     TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_FILE"]});
   }
  else
   {
     TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_DIR"]});
   }

  my $fileId;
  my $abort_flag=1;

  $fileId = TXK::OSD->trFileDir($args->{$ACCESS_FILE},$args->{$ACCESS_DIR});
  $abort_flag = $args->{$ABORT_FLAG} if ( exists($args->{$ABORT_FLAG}) );

  _processAccessList($self,$fileId,$type,
	             TXK::FileSys::CREATE_ON_ACCESS,3,$abort_flag)
         or  return $self->setError("Unable to create $fileId");

  return TXK::Error::SUCCESS;
}

######################################
# access
###################################### 

sub access
{     
  my $self  = $ARG[0];        
  my $args  = $ARG[1];

  my $type;

  $self->getError()->{'message'} = "";

  TXK::Util->isValidObj({obj=>$self,package=>$PACKAGE_ID,args=>$args});

  TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_CHECK"]});

  $type = TXK::FileSys::FILE;

  $type  = $args->{$ACCESS_TYPE}  if ( exists($args->{$ACCESS_TYPE}) );

  return $self->setAbort("$ACCESS_TYPE must be either FILE or DIRECTORY")
                     unless (  $type == TXK::FileSys::FILE ||
                               $type == TXK::FileSys::DIRECTORY 
                            );

  my $hashTab = undef;

  if ( $type == TXK::FileSys::FILE )
   {
     TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_FILE"]});

     $hashTab = $args->{$ACCESS_FILE} 
                    if ( ref($args->{$ACCESS_FILE}) eq "HASH" );
   }
  else
   {
     TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_DIR"]});

     $hashTab = $args->{$ACCESS_DIR}
                    if ( ref($args->{$ACCESS_DIR}) eq "HASH" );
   }

  if ( defined $hashTab )
   {
     my $key;
     my $fileId;

     foreach $key (keys %$hashTab)
      {
        $fileId = TXK::OSD->trFileDir($hashTab->{$key});

        _do_access($self,$args,$type,$fileId)
            or return $self->setErrorNoAbort("Access permission error on $key");
      }
   }
  else
   {
     my $fileId;

     $fileId = TXK::OSD->trFileDir($args->{$ACCESS_FILE},$args->{$ACCESS_DIR});

     _do_access($self,$args,$type,$fileId)
            or return $self->setErrorNoAbort(
					"Access permission error on $fileId");
   }

  return TXK::Error::SUCCESS;
}

######################################
# isDirectory
#####################################

sub isDirectory
{
  my $self  = $ARG[0];
  my $args  = $ARG[1];

  TXK::Util->isValidObj({obj=>$self,package=>$PACKAGE_ID,args=>$args});

  TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_DIR"]});

  $self->access({ dirName =>$args->{$ACCESS_DIR},
                  type=>TXK::FileSys::DIRECTORY,
                  checkMode=>TXK::FileSys::READ_ACCESS,
                })
      or return TXK::Util::FALSE;

  return TXK::Util::TRUE;
}

######################################
# isSymLink
#####################################

sub isSymLink
{
  my $self  = $ARG[0];
  my $args  = $ARG[1];

  TXK::Util->isValidObj({obj=>$self,package=>$PACKAGE_ID,args=>$args});

  TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_FILE"]});

  return TXK::Util::FALSE if ( TXK::OSD->isNT() );

  return TXK::Util::TRUE if ( -l $args->{$ACCESS_FILE} );

  return TXK::Util::FALSE;
}


######################################
# ident
###################################### 

sub ident
{
  my $self  = $ARG[0];
  my $args  = $ARG[1];

  TXK::Util->isValidObj({obj=>$self,package=>$PACKAGE_ID,args=>$args});

  TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_FILE"]});

  my $file = TXK::Util->getScalarArg($ACCESS_FILE,$args->{$ACCESS_FILE});

  my $dir  = TXK::Util->getScalarArg($ACCESS_DIR,$args->{$ACCESS_DIR})
                          if ( exists $args->{$ACCESS_DIR} );

  my $fileId = TXK::OSD->trFileDir($file,$dir);

  my ($pattern,$identDataRef);

  $pattern = DEFAULT_PATTERN;

  $pattern    = TXK::Util->getScalarArg($IDENT_PATTERN,$args->{$IDENT_PATTERN})
                          if ( exists $args->{$IDENT_PATTERN} );

  $identDataRef = TXK::Util->getArrayRef($IDENT_DATA,$args->{$IDENT_DATA})
                          if ( exists $args->{$IDENT_DATA} );

  $self->access({ fileName=>$file,
                  dirName =>$dir,
                  type=>TXK::FileSys::FILE,
                  checkMode=>TXK::FileSys::READ_ACCESS,
                })
         or return $self->setError("No read access for $fileId");

  my $ident_io = TXK::IO->new();

  $ident_io->open({ mode => TXK::IO::READ,
                    binaryMode => TXK::Util::TRUE,
                    fileName => $file,
		    dirName  => $dir,
                  });

#       The default for the IO object is to abortOnError.
#       If this is disabled, then the while loop needs to distinguish
#       between (0 - EOF) and (undef - ERROR)

  my @identData = ();

  my ($ident_name,$ident_version) = (IDENT_NAME,IDENT_VERSION);

  my $IOSize = 64000;
  my $headerSize = 255;

  my ($buffer,$fillBuffer);

  while ( TXK::Util::TRUE )
   {
     my $rc = $ident_io->read({ IOBUFFER=>\$buffer,
                                bufferSize=>$IOSize } ) ;

     last unless ($rc);

     my $pos = 0;

     while ( TXK::Util::TRUE )
      {
        $pos = index($buffer,'$',$pos);     

        last if ($pos<0);

#	It's possible that the buffer could just keep growing under certain
#	small buffer conditions. To prevent this get rid of everything before
#       the $ char.

        substr($buffer,0,$pos) = "";

        $pos = 0;   # pos is zero due to the substr() reset above.
        
        if ( length($buffer) < $headerSize && $rc )
         {
           $rc = $ident_io->read({ IOBUFFER=>\$fillBuffer,
                                   bufferSize=>$IOSize } ) ;

           $buffer .= $fillBuffer if ( $rc );
         }

#	
#	Ok, it's time for those wacky regular expressions..
#
#       Match :   [One or more dollar characters] 
#                 [Pattern String] 
#                 [colon]
#                 [space]
#                 [One or more non-whitespace - ident name]
#                 [space]
#                 [One or more non-whitespace - ident version]
#                 [space]
#                 [Zero or more valid header characters]
#                 [dollar]
#

#
#	If pattern is the default , then don't recompile match expression.
#

        my ($name,$version,$dollar_chars,$found);

        $found = 0;

        if ( $pattern eq DEFAULT_PATTERN )
         {
           if ( substr($buffer,$pos) =~ 
                 m/^(\$+)${pattern}: (\S+) (\S+) [a-zA-Z0-9:\/\. ]*\$/o )
            {
              $dollar_chars = $1, $name = $2, $version = $3, $found = 1;

              $pos += length($dollar_chars);
            }
         }
        else
         {
           if ( substr($buffer,$pos) =~
                 m/^(\$+)${pattern}: (\S+) (\S+) [a-zA-Z0-9:\/\. ]*\$/ )
            {
              $dollar_chars = $1, $name = $2, $version = $3, $found =1;

              $pos += length($dollar_chars);
            }
         }

	push @identData, { $ident_version      => $version,
                           $ident_name         => $name }  if ( $found );

        $pos++;
      }

     last unless ($rc);
   }

  $ident_io->close();

  @$identDataRef = ( @identData ) if ( defined $identDataRef );

  return TXK::FileSys::MULTIPLE_IDENTS  if ( scalar(@identData) > 1 );

  return TXK::FileSys::NO_IDENT         if ( scalar(@identData) == 0 );

  return $identDataRef->[0]->{$ident_version};
}

######################################
# findFile
######################################

sub findFile
{
  my $self  = $ARG[0];
  my $args  = $ARG[1];

  my $type;

  $self->getError()->{'message'} = "";

  TXK::Util->isValidObj({obj=>$self,package=>$PACKAGE_ID,args=>$args});

  TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_FILE","$ACCESS_DIR"]});

  my $file = TXK::Util->getScalarArg($ACCESS_FILE,$args->{$ACCESS_FILE});
  my $dir  = TXK::Util->getScalarArg($ACCESS_DIR,$args->{$ACCESS_DIR});

  $self->access({ dirName =>$dir,
                  type=>TXK::FileSys::DIRECTORY,
                  checkMode=>TXK::FileSys::READ_ACCESS,
                })
         or return $self->setError("No read access for directory $dir");

  return _doFindFile($self,TXK::OSD->trDirPath($dir),$file,0);
}


######################################
# rmdir
######################################

sub rmdir
{
  my $self  = $ARG[0];
  my $args  = $ARG[1];

  my $type;

  $self->getError()->{'message'} = "";

  TXK::Util->isValidObj({obj=>$self,package=>$PACKAGE_ID,args=>$args});

  TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_DIR"]});

  my $dir  = TXK::Util->getScalarArg($ACCESS_DIR,$args->{$ACCESS_DIR});

  $self->access({ dirName =>$dir,
                  type=>TXK::FileSys::DIRECTORY,
                  checkMode=>TXK::FileSys::READ_ACCESS,
                })
         or return $self->setError("No read access for directory $dir");

  return _dormdir($self,TXK::OSD->trDirPath($dir),0);
}

######################################
# rmfile
######################################

sub rmfile
{
  my $self  = $ARG[0];
  my $args  = $ARG[1];

  my $type;

  $self->getError()->{'message'} = "";

  TXK::Util->isValidObj({obj=>$self,package=>$PACKAGE_ID,args=>$args});

  TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_FILE"]});

  my $file = TXK::Util->getScalarArg($ACCESS_FILE,$args->{$ACCESS_FILE});

  if ( -d $file  && ! -l $file )
   {
     return $self->rmdir({ dirName => $file });
   }
  else
   {
     unlink $file or return TXK::Error::FAIL;
   }

  return TXK::Error::SUCCESS;
}

######################################
# getDirList
######################################

sub getDirList
{
  my $self  = $ARG[0];
  my $args  = $ARG[1];

  my $type;

  $self->getError()->{'message'} = "";

  TXK::Util->isValidObj({obj=>$self,package=>$PACKAGE_ID,args=>$args});

  TXK::Util->isValidArgs({args=>$args,reqd=>["$ACCESS_DIR"]});

  my $dir  = TXK::Util->getScalarArg($ACCESS_DIR,$args->{$ACCESS_DIR});

  $self->access({ dirName =>$dir,
                  type=>TXK::FileSys::DIRECTORY,
                  checkMode=>TXK::FileSys::READ_ACCESS,
                })
         or return $self->setError("No read access for directory $dir");

  my @dirList;

  opendir FSYS_HANDLE, TXK::OSD->trDirPath($dir) or return @dirList;

  @dirList = grep(!/^\.\.?$/, readdir(FSYS_HANDLE));

  closedir FSYS_HANDLE or return @dirList;

  return @dirList;
}

######################################
# End of Public methods
######################################

# ==========================================================================

sub _processAccessList
{
  my $self    = $ARG[0];
  my $fileid  = $ARG[1];
  my $type    = $ARG[2];
  my $mode    = $ARG[3];
  my $caller_level
	      = $ARG[4];
  my $abort_flag
	      = $ARG[5];

#	We only really care about \ and / separators but access may be called
#	with either. We'll assume that these chars are only ever dir
#	separators. So we convert from base before splitting.

  $fileid = TXK::OSD->trDirPathFromBase($fileid);

  my $sep = TXK::OSD->getDirSeparator();
  my @elements = reverse split(m#$sep#,$fileid);
  my $entry;
  my @dir;
  my %status;
  my $fstatus;

  my $name = shift @elements if ( $type == TXK::FileSys::FILE );

  while ( scalar(@elements) )
   {
     push @dir,join($sep,reverse @elements);
     shift @elements;
   }

  $dir[$#dir] = $sep if (scalar(@dir) && $dir[$#dir] eq "");

  my $i;

  for ($i=0; $i<scalar(@dir); $i++)
   {
     my $entry = $dir[$i];

     $status{$entry} = 0,next unless (-e $entry);
     $status{$entry} = 1 if (-w $entry && -d $entry);
     $status{$entry} = 2 unless (-d $entry);
     $status{$entry} = 3 if (-d $entry && ! -w $entry );
      
   }

  $fstatus = 0;

  if ( $type == TXK::FileSys::FILE )
   {
     SWITCH: {
               $fstatus = 0,last unless (-e $fileid);
               $fstatus = 1 if ( -w $fileid && -f $fileid);
               $fstatus = 2 unless (-f $fileid);
               $fstatus = 3 if (-f $fileid && ! -w $fileid );
             }
   }

  my ($dir_ok,$ok);

  for ($i=0,$dir_ok=0 ; $i<=$#dir ; )
   {
     my $entry = $dir[$i];

     $dir_ok = 1, last if ($status{$entry} == 1);

     $i++, next if ($status{$entry} == 0 && 
                    (   ( $i+1<$#dir && $status{$dir[$i+1]} <= 1)
                     || ( $i+1==$#dir && $status{$dir[$i+1]} == 1)
                    ) );
     last;
   }

  $ok = ( ( $dir_ok || scalar(@dir)==0 ) && $fstatus<=1 ? 1 : 0 );

#  print "ok=$dir_ok $ok\n";

  if ( $ok && $mode==TXK::FileSys::CREATE_ON_ACCESS)
   {
     foreach $entry (reverse @dir)
      {
#        print "OK: $entry $status{$entry}\n";

        # Fix for Bug # 19793749
        # If ABORT_FLAG is FALSE, then do not error out. Used only in ADOP
        # At all other places existing functionality is preserved (ABORT_FLAG is TRUE)
        if (!$abort_flag)
        {
          mkdir($entry,0777) or
                 $self->setErrorNoAbort("Unable to mkdir",
                                         $caller_level)
           if ($status{$entry} == 0 );
        }
        else
        {
          mkdir($entry,0777) or
                 $self->setAbort({error => "Unable to mkdir",
                                  dir => $entry,
                                  errorno=>$ERRNO } , $caller_level)
           if ($status{$entry} == 0 );
        }
      }

     if ( $type == TXK::FileSys::FILE )
      {

#	IO Object will abort on fail so no need to check for errors.

        my $f_io = TXK::IO->new();

        $f_io->open({ mode => TXK::IO::APPEND,
                      fileName => $fileid
                    });

        $f_io->close();
      }
   }

  if ( ! $ok )
   {
     my $errormsg;

     $errormsg = "Cannot confirm access permissions - REASON stack:\n" ; 


     $errormsg .= "*FILE* $name " .
                   ( $fstatus == 0 
                       ? " file does not exist or directory not accessible"
                       : ( $fstatus == 1
                            ? " file with write permission "
                            : ( $fstatus == 2
                                 ? " exists but not a file"
                                 : ( $fstatus == 3
                                     ? " file exists but no write permission"
                                     : " unknown status "
                                   )
                              )
                         )
                   ) . "\n"
           if ($type == TXK::FileSys::FILE);

     foreach $entry (@dir)
      {
        $errormsg .= 
            "*DIR* $entry " .
              ( $status{$entry} == 0 
                  ? " does not exist"
                  : ( $status{$entry} == 1
                       ? " directory with write permission" 
                       : ( $status{$entry} == 2 
                            ? " exists but not a directory "
                            : ( $status{$entry} == 3 
                                 ? " directory with no write permission "
                                 : " **unknown status** "
                              )
                         )
                    )
              ) 
             . "\n";
      }

     return $self->setErrorNoAbort($errormsg,$caller_level);
  }

  return TXK::Error::SUCCESS;
}

# ==========================================================================

sub _setBufferSize
{
  my $self  = $ARG[0];
  my $args  = $ARG[1];

  $self->{$BUFFER_SIZE} = $args if ( $args >= 4096 && $args <= 128000 );
}

# ==========================================================================

sub _do_access
{     
  my $self  = $ARG[0];        
  my $args  = $ARG[1];
  my $type  = $ARG[2];
  my $fileId= $ARG[3];

  my $caller_level = $self->{$DEFAULT_CALLER_LEVEL} + 1;

  if ( $args->{$ACCESS_CHECK} == TXK::FileSys::READ_ACCESS )
   {
     if ( $type == TXK::FileSys::FILE )
      {
        return $self->setErrorNoAbort("File $fileId not readable",$caller_level)
                   unless ( -r  $fileId && -f $fileId );
      }
     else
      {
        return $self->setErrorNoAbort("Directory $fileId not readable",$caller_level)
                   unless ( -r  $fileId && -d $fileId );
      }
   }
  elsif ( $args->{$ACCESS_CHECK} == TXK::FileSys::WRITE_ACCESS )
   {
     if ( $type == TXK::FileSys::FILE )
      {
        return $self->setErrorNoAbort("File $fileId not writable",$caller_level)
                   unless ( -w  $fileId && -f $fileId );
      }
     else
      {
        return $self->setErrorNoAbort("Directory $fileId not writable",$caller_level)
                   unless ( -w  $fileId && -d $fileId );
      }
   }
  elsif ( $args->{$ACCESS_CHECK} == TXK::FileSys::CREATE_ACCESS )
   {
     return _processAccessList($self,$fileId,$type,
                               TXK::FileSys::ACCESS_CHECK_ONLY,$caller_level);
   }
  else
   {
     return $self->setError("Invalid $ACCESS_CHECK",$caller_level);
   }

  return TXK::Error::SUCCESS;
}

# ==========================================================================

sub _doFindFile
{
  my $self  = $ARG[0];
  my $dir   = $ARG[1];
  my $file  = $ARG[2];
  my $level = $ARG[3];

#  print "Dir  ", ">" x $level , " ", $dir , "\n";

  opendir FSYS_HANDLE, $dir  or return TXK::Error::FAIL;

  my @dirList = readdir FSYS_HANDLE;

  closedir FSYS_HANDLE or return TXK::Error::FAIL;

  my $entry;
  my $nextDir;
  my $found = "" ;

  foreach $entry (@dirList)
   {
#     print "File ", ">" x $level , " ", $entry, "\n";

     next if ($entry eq '.' || $entry eq '..' );

     return TXK::OSD->trFileDir($entry,$dir) 
                   if ( -f TXK::OSD->trFileDir($entry,$dir) &&
                           ( $entry eq $file  ||
                             ( uc($entry) eq uc($file) && TXK::OSD->isNT() )
                           ) );

     $nextDir = TXK::OSD->trDirPath("$dir/$entry");

     $found = _doFindFile($self,$nextDir,$file,$level+1) 
				if ( -d $nextDir  && ! -l $nextDir );

     return $found if $found;
   }

  return TXK::Error::FAIL;
}

# ==========================================================================

sub _dormdir
{
  my $self  = $ARG[0];
  my $dir   = $ARG[1];
  my $level = $ARG[2];

#  print "Dir  ", ">" x $level , " ", $dir , "\n";

  return TXK::Error::SUCCESS if ($dir eq '.' || $dir eq '..' );

  opendir FSYS_HANDLE, $dir  or return TXK::Error::FAIL;

  my @dirList = readdir FSYS_HANDLE;

  closedir FSYS_HANDLE or return TXK::Error::FAIL;

  my $entry;
  my $nextDir;
  my $found = "" ;

  foreach $entry (@dirList)
   {
#     print "File ", ">" x $level , " ", $entry, "\n";

     next if ($entry eq '.' || $entry eq '..' );

     $nextDir = TXK::OSD->trDirPath("$dir/$entry");

     if ( -d $nextDir  && ! -l $nextDir )
      {
        $found = _dormdir($self,$nextDir,$level+1) ;

        return $found if ( $found == TXK::Error::FAIL );
      }
     else
      {
        unlink($nextDir) or return TXK::Error::FAIL ;
      }
   }

  rmdir $dir or return TXK::Error::FAIL ;

  return TXK::Error::SUCCESS;
}

# ==========================================================================

sub _docopydir
{
  my $self      = $ARG[0];
  my $src       = $ARG[1];
  my $dest      = $ARG[2];
  my $recursive = $ARG[3];
  my $level     = $ARG[4];

#  print "Dir  ", ">" x $level , " ", $src , " <=> " , $dest, "\n";

  return TXK::Error::SUCCESS if ($src eq '.' || $src eq '..' );

  opendir FSYS_HANDLE, $src  
          or return $self->setError("copydir: Unable to opendir - $src");

  my @dirList = readdir FSYS_HANDLE;

  closedir FSYS_HANDLE or return TXK::Error::FAIL;

  my $entry;
  my ($nextSrc,$nextDest);
  my $found = "" ;

  foreach $entry (@dirList)
   {
#     print "File ", ">" x $level , " ", $entry, "\n";

     next if ($entry eq '.' || $entry eq '..' );

     $nextSrc = TXK::OSD->trDirPath("$src/$entry");
     $nextDest= TXK::OSD->trDirPath("$dest/$entry");

     if ( -d $nextSrc  && ! -l $nextSrc )
      {
        if ( $recursive )
         {
           $found = _docopydir($self,$nextSrc,$nextDest,$recursive,$level+1) ;

           return $found if ( $found == TXK::Error::FAIL );
         }
      }
     else
      {
        $self->copy({ source=> $nextSrc,
                      dest  => $nextDest,
                    } ) 
              if ( -f $nextSrc ) ;
      }
   }

  return TXK::Error::SUCCESS;
}

# ==========================================================================

1;


